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
sudo pacman -S cdrtools libguestfs wimlib fuse2 --needed --noconfirm

# Variables - Remove spaces and use full paths
windowsISO=/home/$USER/ISOs/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso
virtioISO=/home/$USER/ISOs/Windows-virtio-0.1.285.iso

windowsISOMount=/home/$USER/windows-iso
virtioISOMount=/home/$USER/virtio-iso
modifiedISODir=/home/$USER/windows-modified
wimMountPoint=/tmp/wim-mount-$$  # Use PID to make it unique

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

echo ""
echo "[6/10] Injecting drivers into boot.wim..."
cd "$modifiedISODir/sources"

# Create mount point
mkdir -p "$wimMountPoint"

# Mount boot.wim with write permissions
echo "  - Mounting boot.wim (index 2)..."
wimlib-imagex mountrw boot.wim 2 "$wimMountPoint"

# Create drivers directory if it doesn't exist
echo "  - Creating drivers directory..."
mkdir -p "$wimMountPoint/drivers/"

# Add VirtIO drivers
echo "  - Copying viostor drivers..."
cp -r "$virtioISOMount"/viostor "$wimMountPoint/drivers/"

echo "  - Copying NetKVM drivers..."
cp -r "$virtioISOMount"/NetKVM "$wimMountPoint/drivers/"

# Unmount and commit changes
echo "  - Committing changes to boot.wim..."
wimlib-imagex unmount "$wimMountPoint" --commit

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
    echo "  - Processing image $i of $image_count..."
    wimlib-imagex mountrw install.wim $i "$wimMountPoint"
    
    echo "    - Creating drivers directory..."
    mkdir -p "$wimMountPoint/Windows/System32/drivers/"
    
    echo "    - Copying viostor drivers..."
    cp -r "$virtioISOMount"/viostor "$wimMountPoint/Windows/System32/drivers/"
    
    echo "    - Copying NetKVM drivers..."
    cp -r "$virtioISOMount"/NetKVM "$wimMountPoint/Windows/System32/drivers/"
    
    echo "    - Committing changes..."
    wimlib-imagex unmount "$wimMountPoint" --commit
done

echo ""
echo "[9/10] Creating new bootable ISO (this may take a while)..."
cd "$modifiedISODir"

genisoimage -o ~/Windows-VirtIO.iso \
  -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 \
  -iso-level 2 -J -l -D -N -joliet-long \
  -relaxed-filenames -V "Windows_VirtIO" \
  "$modifiedISODir"

echo ""
echo "[10/10] Cleanup will run automatically..."

echo ""
echo "========================================="
echo "SUCCESS! Modified ISO created at:"
echo "~/Windows-VirtIO.iso"
echo "========================================="