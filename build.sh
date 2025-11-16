tempDir="/tmp/MyScripts"
mkdir -p "$tempDir"
touch "$tempDir/scripts.ps1"

echo -e "Downloading start menu cleanup script..."
curl -s https://raw.githubusercontent.com/Qaddoumi/autounattend/main/empty_start_menu.ps1 >> "$tempDir/scripts.ps1" 2>/dev/null
echo "" >> "$tempDir/scripts.ps1"

echo -e "Downloading virtual machine drivers installation script..."
curl -s https://raw.githubusercontent.com/Qaddoumi/autounattend/main/installing_virtual_drivers.ps1 >> "$tempDir/scripts.ps1" 2>/dev/null
echo "" >> "$tempDir/scripts.ps1"

echo -e "Downloading monitor resolution configuration script..."
curl -s https://raw.githubusercontent.com/Qaddoumi/autounattend/main/resolution.ps1 >> "$tempDir/scripts.ps1" 2>/dev/null
echo "" >> "$tempDir/scripts.ps1"

winconfigPath=/tmp/MyScripts/winconfig
mkdir -p "$winconfigPath"
url="https://github.com/Qaddoumi/winconfig/archive/refs/heads/main.zip"

if [ -d "$winconfigPath/winconfig-main" ]; then
    rm -rf "$winconfigPath/winconfig-main" || {
        echo "Error: Failed to remove existing directory" >&2
        exit 1
    }
fi

wget -O "$winconfigPath.zip" "$url" || curl -L -o "$winconfigPath" "$url" || {
    echo "Error: Failed to download the file" >&2
    exit 1
}

cat >> "$tempDir/scripts.ps1" << 'EOF'

Write-Host "`nLaunching WinConfig..." -ForegroundColor Green
Set-Location -Path "C:\Users\admin\Desktop\winconfig-main"
& .\InstallAllTweaksWithoutTheApps.ps1 -ScriptLocation "$($env:USERPROFILE)\Desktop\winconfig-main" -ErrorAction Continue

EOF

echo -e "All scripts have been downloaded and combined into $tempDir/scripts.ps1"
echo -e "\n"

./make_unattend_ISO.sh -s ./autounattend.xml "$tempDir/scripts.ps1" "$winconfigPath.zip"

rm -rf /tmp/MyScripts