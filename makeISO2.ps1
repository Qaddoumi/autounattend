# Set CompilerOptions variable string (to be passed to Add-Type below) based on PoSH version.
if ($PSVersionTable.PSVersion.Major -eq 5) {
  ($cp = New-Object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe'
    $CompilerOptions = "-CompilerParameters $cp"
}
elseif ($PSVersionTable.PSVersion.Major -eq 7) {
    $cp = '/unsafe'
    $CompilerOptions = "-CompilerOptions '$cp'"
}

if (!('ISOFile' -as [type])) {
        
    Add-Type $CompilerOptions -TypeDefinition @'
public class ISOFile {
    public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) {
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
