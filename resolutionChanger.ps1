Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplaySettings {
    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        private const int DM_PELSWIDTH = 0x80000;
        private const int DM_PELSHEIGHT = 0x100000;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;

        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;

        public int dmColor;
        public int dmDuplex;
        public int dmYResolution;
        public int dmTTOption;
        public int dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;

        public void Initialize() {
            dmDeviceName = new string('\0', 32);
            dmFormName = new string('\0', 32);
            dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        }
    }

    [DllImport("user32.dll")]
    public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY = 0x01;
    public const int DISP_CHANGE_SUCCESSFUL = 0;
}
"@

# Desired resolution
$desiredWidth = 1920
$desiredHeight = 1080

# Initialize DEVMODE struct
$devmode = New-Object DisplaySettings+DEVMODE
$devmode.Initialize()

# Load current settings
$result = [DisplaySettings]::EnumDisplaySettings($null, [DisplaySettings]::ENUM_CURRENT_SETTINGS, [ref]$devmode)

if ($result -eq 1) {
    $devmode.dmPelsWidth = $desiredWidth
    $devmode.dmPelsHeight = $desiredHeight
    $devmode.dmFields = 0x180000  # DM_PELSWIDTH | DM_PELSHEIGHT

    $changeResult = [DisplaySettings]::ChangeDisplaySettings([ref]$devmode, [DisplaySettings]::CDS_UPDATEREGISTRY)

    if ($changeResult -eq [DisplaySettings]::DISP_CHANGE_SUCCESSFUL) {
        Write-Host "Resolution changed to ${desiredWidth}x${desiredHeight} successfully."
    } else {
        Write-Host "Failed to change resolution. Error code: $changeResult"
    }
} else {
    Write-Host "Failed to retrieve current display settings."
}








# works with .NET Framework 3.5
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayChanger {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public int dmPelsWidth, dmPelsHeight;
        public int dmDisplayFlags, dmDisplayFrequency;
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
    public struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceKey;
    }

    [DllImport("user32.dll", CharSet=CharSet.Ansi)]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet=CharSet.Ansi)]
    public static extern int EnumDisplaySettingsEx(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode, uint dwFlags);

    [DllImport("user32.dll", CharSet=CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, int dwFlags, IntPtr lParam);

    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_TEST = 2;
    public const int CDS_UPDATEREGISTRY = 1;
    public const int DISP_CHANGE_SUCCESSFUL = 0;

    public static string ChangeRes(int deviceIndex, int width, int height) {
        uint idx = (uint)deviceIndex;
        var dd = new DISPLAY_DEVICE();
        dd.cb = Marshal.SizeOf(dd);
        if (!EnumDisplayDevices(null, idx, ref dd, 0))
            return string.Format("Display device {0} not found.", deviceIndex);

        var dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(dm);

        if (EnumDisplaySettingsEx(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm, 0) == 0)
            return "EnumDisplaySettingsEx failed.";

        dm.dmPelsWidth = width;
        dm.dmPelsHeight = height;
        dm.dmFields = 0x180000; // DM_PELSWIDTH | DM_PELSHEIGHT

        int test = ChangeDisplaySettingsEx(dd.DeviceName, ref dm, IntPtr.Zero, CDS_TEST, IntPtr.Zero);
        if (test != DISP_CHANGE_SUCCESSFUL)
            return string.Format("Test failed: {0}", test);

        int ret = ChangeDisplaySettingsEx(dd.DeviceName, ref dm, IntPtr.Zero, CDS_UPDATEREGISTRY, IntPtr.Zero);
        return ret == DISP_CHANGE_SUCCESSFUL
            ? "Resolution change successful."
            : string.Format("Change failed with code {0}.", ret);
    }
}
"@

function Set-MyResolution {
    param(
        [int]$DeviceId = 0,
        [int]$Width = 1920,
        [int]$Height = 1080
    )
    [DisplayChanger]::ChangeRes($DeviceId, $Width, $Height)
}

# Example usage:
Set-MyResolution -DeviceId 0 -Width 1920 -Height 1080
