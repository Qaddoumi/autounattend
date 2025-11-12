# Install VirtualBox Guest Additions
& {
    foreach ( $letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() ) {
        $exe = "${letter}:\VBoxWindowsAdditions.exe";
        if ( Test-Path -LiteralPath $exe ) {
            $certs = "${letter}:\cert";
            Start-Process -FilePath "${certs}\VBoxCertUtil.exe" -ArgumentList "add-trusted-publisher ${certs}\vbox*.cer", "--root ${certs}\vbox*.cer"  -Wait;
            Start-Process -FilePath $exe -ArgumentList '/with_wddm', '/S' -Wait;
            return;
        }
    }
    'VBoxGuestAdditions.iso is not attached to this VM.';
} *>&1>> "$env:TEMP\VBoxGuestAdditions.log";


# Install VMware Tools
& {
    foreach ( $letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() ) {
        $exe = "${letter}:\setup.exe";
        if ( ( Get-Item -LiteralPath $exe -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty 'VersionInfo' | Select-Object -ExpandProperty 'ProductName' ) -eq 'VMware Tools' ) {
            Start-Process -FilePath $exe -ArgumentList '/s /v /qn REBOOT=R' -Wait;
            return;
        }
    }
    'VMware Tools image (windows.iso) is not attached to this VM.';
} *>&1>> "$env:TEMP\VMwareTools.log";


# Install VirtIO Guest Tools
& {
    foreach ( $letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray() ) {
        $exe = "${letter}:\virtio-win-guest-tools.exe";
        if ( Test-Path -LiteralPath $exe ) {
            Start-Process -FilePath $exe -ArgumentList '/passive', '/norestart' -Wait;
            return;
        }
    }
    'VirtIO Guest Tools image (virtio-win-*.iso) is not attached to this VM.';
} *>&1>> "$env:TEMP\VirtIoGuestTools.log";