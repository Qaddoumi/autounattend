# Read the binary file into a variable and convert to a byte array
#$StartBinaryContent = [byte[]](Get-Content -Path "D:\GitHub\autounattend.xml\Empty_start2.bin" -Encoding Byte)
# Write the byte array to a new file using Out-File
#([byte[]](Get-Content -Path "D:\GitHub\autounattend.xml\Empty_start2.bin" -Encoding Byte)) | Out-File -FilePath .\start2BindaryData.ps1
