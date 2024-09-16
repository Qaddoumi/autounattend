Write-Host "███████████████████████████████████████████████████████████████████████████████"
Write-Host "==============================================================================="

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
        $CSharpCode = @'
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
        if (!('ISOFile' -as [type])) {
            if ($PSVersionTable.PSEdition -eq 'Desktop') { # Is BuiltIn Windows PowerShell
                ($cp = New-Object CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe'
                Add-Type -CompilerParameters $cp -TypeDefinition $CSharpCode
            }else{
                Add-Type -CompilerOptions "/unsafe" -TypeDefinition $CSharpCode
            }
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

#Resolve-Path will get the absolute path
$Title = "autounattend"
$Source = (Resolve-Path -Path ".\autounattend.xml").Path
$FileName = "\windows-autounattend_$((Get-Date).ToString('yyyy-MM-dd_hh-mm-ss_ffff_tt')).iso"
$Output = (Resolve-Path -Path ".").Path + $FileName

New-IsoFile -Source $Source -Path $Output -Media "CDR" -Title $Title
