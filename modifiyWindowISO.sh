#!/usr/bin/env bash

set -e  # Exit on error

# Cleanup function to ensure proper unmounting
cleanup_on_exit() {
    local exit_code=$?
    echo ""
    echo "Performing cleanup..."
    
    # Force unmount WIM if it's still mounted
    if mountpoint -q "$wimMountPoint" 2>/dev/null || [ -d "$wimMountPoint" ]; then
        echo "  - Force unmounting WIM image..."
        sudo wimlib-imagex unmount "$wimMountPoint" --commit 2>/dev/null || true
        sudo umount -l "$wimMountPoint" 2>/dev/null || true
        sudo fusermount -uz "$wimMountPoint" 2>/dev/null || true
        sleep 1
    fi
    
    # Unmount ISOs
    if mountpoint -q "$windowsISOMount" 2>/dev/null; then
        echo "  - Unmounting Windows ISO..."
        sudo umount "$windowsISOMount" 2>/dev/null || true
    fi
    
    if mountpoint -q "$virtioISOMount" 2>/dev/null; then
        echo "  - Unmounting VirtIO ISO..."
        sudo umount "$virtioISOMount" 2>/dev/null || true
    fi
    
    # Wait a bit for unmounts to complete
    sleep 1
    
    # Remove directories
    echo "  - Removing temporary directories..."
    rm -rf "$windowsISOMount" "$virtioISOMount" "$modifiedISODir" 2>/dev/null || true
    
    # Force remove wim mount point
    if [ -d "$wimMountPoint" ]; then
        sudo rm -rf "$wimMountPoint" 2>/dev/null || true
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo "  - Cleanup completed successfully"
    else
        echo "  - Cleanup completed (script had errors)"
    fi
}

# Register cleanup function to run on script exit
trap cleanup_on_exit EXIT

echo "========================================="
echo "Windows ISO VirtIO Driver Injection Tool"
echo "========================================="

# Install dependencies
echo ""
echo "[1/10] Installing dependencies..."
sudo pacman -S cdrtools libguestfs wimlib fuse2 xorriso chntpw --needed --noconfirm

windowsISO=/home/$USER/ISOs/25h2_CLIENT_CONSUMER_x64FRE_en-us.iso
virtioISO=/home/$USER/ISOs/Windows-virtio-0.1.285.iso

windowsISOMount=/home/$USER/windows-iso
virtioISOMount=/home/$USER/virtio-iso
modifiedISODir=/home/$USER/windows-modified
wimMountPoint=/tmp/wim-mount

echo ""
echo "[2/10] Creating mount points and work directory..."
mkdir -p "$windowsISOMount" "$virtioISOMount" "$modifiedISODir"

echo ""
echo "[3/10] Mounting Windows ISO..."
sudo mount -o loop "$windowsISO" "$windowsISOMount"

echo ""
echo "[4/10] Mounting VirtIO ISO..."
sudo mount -o loop "$virtioISO" "$virtioISOMount"

echo ""
echo "[5/10] Copying Windows ISO contents (this may take a while)..."
cp -rv "$windowsISOMount"/* "$modifiedISODir"/
sudo chmod -R u+w "$modifiedISODir"

# Function to inject drivers into WIM image
inject_drivers_into_wim() {
    local wim_file=$1
    local image_index=$2
    local image_name=$3
    
    echo "  - Processing $image_name (index $image_index)..."
    wimlib-imagex mountrw "$wim_file" "$image_index" "$wimMountPoint"
    
    # Create proper driver directories
    mkdir -p "$wimMountPoint/Windows/Inf"
    mkdir -p "$wimMountPoint/Windows/System32/drivers"
    
    # Copy VirtIO storage drivers (most critical for disk detection)
    echo "    - Copying storage drivers..."
    
    # Copy viostor drivers (Storage Controller)
    if [ -d "$virtioISOMount/amd64/w11" ]; then
        find "$virtioISOMount/amd64/w11" -name "viostor.*" -type f | while read -r driver_file; do
            cp -v "$driver_file" "$wimMountPoint/Windows/System32/drivers/"
        done
    fi
    
    # Copy all amd64 drivers
    if [ -d "$virtioISOMount/amd64" ]; then
        echo "    - Copying amd64 drivers..."
        find "$virtioISOMount/amd64" -name "*.inf" -o -name "*.sys" -o -name "*.cat" | while read -r driver_file; do
            # Copy .inf files to Windows/Inf
            if [[ "$driver_file" == *.inf ]]; then
                cp -v "$driver_file" "$wimMountPoint/Windows/Inf/"
            fi
            # Copy .sys files to drivers
            if [[ "$driver_file" == *.sys ]]; then
                cp -v "$driver_file" "$wimMountPoint/Windows/System32/drivers/"
            fi
            # Copy .cat files to System32
            if [[ "$driver_file" == *.cat ]]; then
                cp -v "$driver_file" "$wimMountPoint/Windows/System32/"
            fi
        done
    fi
    
    # Add critical registry entries for VirtIO storage drivers
    echo "    - Adding registry entries..."
    
    # Create a temporary registry file
    cat > /tmp/virtio_reg.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\viostor]
"Type"=dword:00000001
"Start"=dword:00000000
"Group"="SCSI miniport"
"ErrorControl"=dword:00000001
"Tag"=dword:00000021
"ImagePath"="system32\\drivers\\viostor.sys"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\vioscsi]
"Type"=dword:00000001
"Start"=dword:00000000
"Group"="SCSI miniport"
"ErrorControl"=dword:00000001
"Tag"=dword:00000022
"ImagePath"="system32\\drivers\\vioscsi.sys"
EOF

    # Load the offline registry and import our settings
    if command -v chntpw >/dev/null 2>&1; then
        # For SYSTEM registry
        if [ -f "$wimMountPoint/Windows/System32/config/SYSTEM" ]; then
            sudo chntpw -e "$wimMountPoint/Windows/System32/config/SYSTEM" << 'END_SCRIPT'
cd ControlSet001\Services
ed viostor
create Type dword 1
create Start dword 0
create Group SCSI miniport
create ErrorControl dword 1
create Tag dword 33
create ImagePath system32\drivers\viostor.sys
y
ed vioscsi
create Type dword 1
create Start dword 0
create Group SCSI miniport
create ErrorControl dword 1
create Tag dword 34
create ImagePath system32\drivers\vioscsi.sys
y
quit
END_SCRIPT
        fi
    else
        echo "    - Warning: chntpw not installed, skipping registry edits"
        echo "    - Install with: sudo pacman -S chntpw"
    fi
    
    echo "    - Committing changes..."
    wimlib-imagex unmount "$wimMountPoint" --commit
}

echo ""
echo "[6/10] Injecting drivers into boot.wim..."
cd "$modifiedISODir/sources"

# Create mount point
mkdir -p "$wimMountPoint"

# Process boot.wim (usually 2 images: Windows PE and Setup)
echo "  - Processing boot.wim images..."
boot_image_count=$(wimlib-imagex info boot.wim | grep "Image Count:" | awk '{print $3}')
for ((i=1; i<=boot_image_count; i++)); do
    inject_drivers_into_wim "boot.wim" "$i" "boot image $i"
done

echo ""
echo "[7/10] Checking install.wim images..."
wimlib-imagex info install.wim | grep "Index"

echo ""
echo "[8/10] Injecting drivers into install.wim..."
# Get number of images
image_count=$(wimlib-imagex info install.wim | grep "Image Count:" | awk '{print $3}')
echo "  - Found $image_count image(s) in install.wim"

# Inject into each image
for ((i=1; i<=image_count; i++)); do
    inject_drivers_into_wim "install.wim" "$i" "install image $i"
done

echo ""
echo "[9/10] Creating new bootable ISO (this may take a while)..."
cd "$modifiedISODir"

# Use xorriso to create a properly bootable Windows ISO
echo "  - Creating bootable ISO with xorriso..."

# Check if boot files exist
if [ ! -f "boot/etfsboot.com" ]; then
    echo "Warning: boot/etfsboot.com not found"
fi

if [ ! -f "efi/microsoft/boot/efisys.bin" ]; then
    echo "Warning: efi/microsoft/boot/efisys.bin not found"
fi

# Create ISO with proper Windows boot structure
xorriso -as mkisofs \
  -iso-level 4 \
  -l -R -J \
  -b boot/etfsboot.com \
  -no-emul-boot -boot-load-size 8 -boot-info-table \
  -eltorito-alt-boot \
  -e efi/microsoft/boot/efisys.bin \
  -no-emul-boot \
  -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin \
  -o ~/Windows-VirtIO.iso \
  -volid "Windows_VirtIO" \
  ./

echo ""
echo "[10/10] Cleanup will run automatically..."

echo ""
echo "========================================="
echo "SUCCESS! Modified ISO created at:"
echo "~/Windows-VirtIO.iso"
echo "========================================="
