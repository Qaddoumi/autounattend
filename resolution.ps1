# Define C# code for ChangeDisplaySettings and EnumDisplaySettings APIs
$code = @"
using System;
using System.Runtime.InteropServices;

public class DisplaySettings
{
    // Constants from winuser.h
    public const int DM_PELSWIDTH = 0x00080000;
    public const int DM_PELSHEIGHT = 0x00100000;
    public const int DM_BITSPERPEL = 0x00040000;
    public const int DM_DISPLAYFREQUENCY = 0x00400000;
    public const int CDS_UPDATEREGISTRY = 0x00000001;
    public const int CDS_GLOBAL = 0x00000008;
    public const int DISP_CHANGE_SUCCESSFUL = 0;
    public const int DISP_CHANGE_BADMODE = -2;
    public const int ENUM_CURRENT_SETTINGS = -1;

    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE
    {
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
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
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
    }

    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    // Set resolution
    public static int SetResolution(int width, int height)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));

        // Check if the resolution is supported
        bool modeFound = false;
        int modeIndex = 0;
        while (EnumDisplaySettings(null, modeIndex, ref devMode))
        {
            if (devMode.dmPelsWidth == width && devMode.dmPelsHeight == height)
            {
                modeFound = true;
                break;
            }
            modeIndex++;
        }

        if (!modeFound)
        {
            return DISP_CHANGE_BADMODE; // Mode not supported
        }

        // Apply resolution
        devMode.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
        devMode.dmPelsWidth = width;
        devMode.dmPelsHeight = height;

        return ChangeDisplaySettings(ref devMode, CDS_UPDATEREGISTRY | CDS_GLOBAL);
    }

    // Set refresh rate
    public static int SetRefreshRate(int refreshRate)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));

        // Check if the refresh rate is supported
        bool modeFound = false;
        int modeIndex = 0;
        while (EnumDisplaySettings(null, modeIndex, ref devMode))
        {
            if (devMode.dmDisplayFrequency == refreshRate)
            {
                modeFound = true;
                break;
            }
            modeIndex++;
        }

        if (!modeFound)
        {
            return DISP_CHANGE_BADMODE; // Mode not supported
        }

        // Apply refresh rate
        devMode.dmFields = DM_DISPLAYFREQUENCY;
        devMode.dmDisplayFrequency = refreshRate;

        return ChangeDisplaySettings(ref devMode, CDS_UPDATEREGISTRY | CDS_GLOBAL);
    }

    // Set color depth
    public static int SetColorDepth(int bitsPerPixel)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));

        // Check if the color depth is supported
        bool modeFound = false;
        int modeIndex = 0;
        while (EnumDisplaySettings(null, modeIndex, ref devMode))
        {
            if (devMode.dmBitsPerPel == bitsPerPixel)
            {
                modeFound = true;
                break;
            }
            modeIndex++;
        }

        if (!modeFound)
        {
            return DISP_CHANGE_BADMODE; // Mode not supported
        }

        // Apply color depth
        devMode.dmFields = DM_BITSPERPEL;
        devMode.dmBitsPerPel = bitsPerPixel;

        return ChangeDisplaySettings(ref devMode, CDS_UPDATEREGISTRY | CDS_GLOBAL);
    }
}
"@

# Add the C# code to PowerShell
try {
    Write-Host "Compiling C# code for display settings..."
    Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
}
catch {
    Write-Host "Failed to compile C# code. Error: $($_.Exception.Message)"
    exit 1
}

# Execute each setting function independently
$success = $true

# Set resolution to 1920x1080
Write-Host "Setting resolution to 1920x1080..."
try {
    $result = [DisplaySettings]::SetResolution(1920, 1080)
    if ($result -eq 0) {
        Write-Host "Successfully set resolution to 1920x1080."
    } else {
        Write-Host "Failed to set resolution. Error code: $result"
        $success = $false
    }
}
catch {
    Write-Host "Exception setting resolution: $($_.Exception.Message)"
    $success = $false
}

Write-Host "Setting refresh rate to 144Hz..."
# Set refresh rate to 144Hz
try {
    $result = [DisplaySettings]::SetRefreshRate(144)
    if ($result -eq 0) {
        Write-Host "Successfully set refresh rate to 144Hz."
    } else {
        Write-Host "Failed to set refresh rate. Error code: $result"
        $success = $false
    }
}
catch {
    Write-Host "Exception setting refresh rate: $($_.Exception.Message)"
    $success = $false
}

Write-Host "Setting color depth to 32-bit..."
# Set color depth to 32-bit
try {
    $result = [DisplaySettings]::SetColorDepth(32)
    if ($result -eq 0) {
        Write-Host "Successfully set color depth to 32-bit."
    } else {
        Write-Host "Failed to set color depth. Error code: $result"
        $success = $false
    }
}
catch {
    Write-Host "Exception setting color depth: $($_.Exception.Message)"
    $success = $false
}

# Final status
if ($success) {
    Write-Host "All display settings applied successfully."
} else {
    Write-Host "Some display settings failed to apply. Check errors above."
}