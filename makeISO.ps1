#region powershell
function WriteIStreamToFile {
    <#
    Inspiration from
    http://blogs.msdn.com/b/opticalstorage/archive/2010/08/13/writing-optical-discs-using-imapi-2-in-powershell.aspx
    and
    http://tools.start-automating.com/Install-ExportISOCommand/
    with help from
    http://stackoverflow.com/a/9802807/223837
    ###############################################################################
    NOTE: We cannot use [System.Runtime.InteropServices.ComTypes.IStream],
    since PowerShell apparently cannot convert an IStream COM object to this
    Powershell type.  (See http://stackoverflow.com/a/9037299/223837 for
    details.)
    
    It turns out that .NET/CLR _can_ do this conversion.
    
    That is the reason why method FileUtil.WriteIStreamToFile(), below,
    takes an object, and casts it to an IStream, instead of directly
    taking an IStream inputStream argument.
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [string]$Source,

        [parameter(Mandatory = $true)]
        [string]$OutputName,

        [string]$VolumeName = "myimage",

        # Constants from http://msdn.microsoft.com/en-us/library/windows/desktop/aa364840.aspx
        $FsiFileSystemISO9660 = 1,
        $FsiFileSystemJoliet = 2
    )

    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = $FsiFileSystemISO9660 + $FsiFileSystemJoliet
    $fsi.VolumeName = $VolumeName
    $fsi.Root.AddTree($Source, $true)
    $istream = $fsi.CreateResultImage().ImageStream

    $cp = New-Object CodeDom.Compiler.CompilerParameters
    $cp.CompilerOptions = "/unsafe"
    $cp.WarningLevel = 4
    $cp.TreatWarningsAsErrors = $true

    Add-Type -CompilerParameters $cp -TypeDefinition @"
		using System;
		using System.IO;
		using System.Runtime.InteropServices.ComTypes;

		namespace My
		{

			public static class FileUtil {
				public static void WriteIStreamToFile(object i, string fileName) {
					IStream inputStream = i as IStream;
					FileStream outputFileStream = File.OpenWrite(fileName);
					int bytesRead = 0;
					int offset = 0;
					byte[] data;
					do {
						data = Read(inputStream, 2048, out bytesRead);  
						outputFileStream.Write(data, 0, bytesRead);
						offset += bytesRead;
					} while (bytesRead == 2048);
					outputFileStream.Flush();
					outputFileStream.Close();
				}

				unsafe static private byte[] Read(IStream stream, int toRead, out int read) {
				    byte[] buffer = new byte[toRead];
				    int bytesRead = 0;
				    int* ptr = &bytesRead;
				    stream.Read(buffer, toRead, (IntPtr)ptr);   
				    read = bytesRead;
				    return buffer;
				} 
			}

		}
"@

    [My.FileUtil]::WriteIStreamToFile($istream, $OutputName)
}

#region pwsh
function New-IsoFile {
    [CmdletBinding(DefaultParameterSetName = 'Source')]Param(
        [parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Source')]$Source,
        [parameter(Position = 2)][string]$Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$BootFile = $null,
        [ValidateSet('CDR', 'CDRW', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'DISK', 'DVDPLUSRW_DUALLAYER', 'BDR', 'BDRE')][string] $Media = 'DVDPLUSRW_DUALLAYER',
        [string]$Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),
        [switch]$Force,
        [parameter(ParameterSetName = 'Clipboard')][switch]$FromClipboard
    )

    Begin {
    ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe'
        if (!('ISOFile' -as [type])) {
            Add-Type -CompilerOptions "/unsafe" -TypeDefinition @'
public class ISOFile
{
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
  {
    int bytes = 0;
    byte[] buf = new byte[BlockSize];
    var ptr = (System.IntPtr)(&bytes);
    var o = System.IO.File.OpenWrite(Path);
    var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;

    if (o != null) {
      while (TotalBlocks-- > 0) {
        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
      }
      o.Flush(); o.Close();
    }
  }
}
'@
        }

        if ($BootFile) {
            if ('BDR', 'BDRE' -contains $Media) { Write-Warning "Bootable image doesn't seem to work with media type $Media" }
            ($Stream = New-Object -ComObject ADODB.Stream -Property @{Type = 1 }).Open() # adFileTypeBinary
            $Stream.LoadFromFile((Get-Item -LiteralPath $BootFile).Fullname)
            ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream)
        }

        $MediaType = @('UNKNOWN', 'CDROM', 'CDR', 'CDRW', 'DVDROM', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'DISK', 'DVDPLUSRW_DUALLAYER', 'HDDVDROM', 'HDDVDR', 'HDDVDRAM', 'BDROM', 'BDR', 'BDRE')

        Write-Verbose -Message "Selected media type is $Media with value $($MediaType.IndexOf($Media))"
        ($Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName = $Title }).ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media))

        if (!($Target = New-Item -Path $Path -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) { Write-Error -Message "Cannot create file $Path. Use -Force parameter to overwrite if the target file already exists."; break }
    }

    Process {
        if ($FromClipboard) {
            if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher'; break }
            $Source = Get-Clipboard -Format FileDropList
        }

        foreach ($item in $Source) {
            if ($item -isnot [System.IO.FileInfo] -and $item -isnot [System.IO.DirectoryInfo]) {
                $item = Get-Item -LiteralPath $item
            }

            if ($item) {
                Write-Verbose -Message "Adding item to the target image: $($item.FullName)"
                try { $Image.Root.AddTree($item.FullName, $true) } catch { Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.') }
            }
        }
    }

    End {
        if ($Boot) { $Image.BootImageOptions = $Boot }
        $Result = $Image.CreateResultImage()
        [ISOFile]::Create($Target.FullName, $Result.ImageStream, $Result.BlockSize, $Result.TotalBlocks)
        Write-Verbose -Message "Target image ($($Target.FullName)) has been created"
        $Target
    }
}

#region Excution
Write-Host "==============================================================================="
Write-Host "==============================================================================="

#Resolve-Path will get the absolute path
$Source = (Resolve-Path -Path ".\autounattend.xml").Path
$FileName = "\autounattend_$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss_ffff_tt')).iso"
$Title = "autounattend"

$Output = (Resolve-Path -Path ".").Path + $FileName
$isBuiltInWindowsPowerShell = ($PSVersionTable.PSEdition -eq 'Desktop')

if ($isBuiltInWindowsPowerShell){
    WriteIStreamToFile -Source $Source -OutputName $Output -VolumeName $Title
}else{
    New-IsoFile -Source $Source -Path $Output -Media "CDR" -Title $Title
}
