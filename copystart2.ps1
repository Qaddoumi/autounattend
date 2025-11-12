

Get-ChildItem "$Env:HomeDrive\Users\" -Attributes Directory -Force | Where-Object { $_.Name -notin "All Users", "Default User", "Default", "Public" } | ForEach-Object {
    [System.IO.DirectoryInfo]$destination = "$($_.FullName)\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    if (!$destination.Exists) {
        $destination.Create()
    }
    [System.IO.File]::WriteAllBytes("$destination\start2.bin", $StartBinaryContent)
}