$fileContent = @"
Write-Host "``nRunning start menu cleanup script..." -ForegroundColor Green
irm https://raw.githubusercontent.com/Qaddoumi/autounattend/main/empty_start_menu.ps1 | iex -ErrorAction Continue

Write-Host "``nRunning virtual machine drivers installation script..." -ForegroundColor Green
irm https://raw.githubusercontent.com/Qaddoumi/autounattend/main/installing_virtual_drivers.ps1 | iex -ErrorAction Continue

Write-Host "``nRunning monitor resolution configuration script..." -ForegroundColor Green
irm https://raw.githubusercontent.com/Qaddoumi/autounattend/main/resolution.ps1 | iex -ErrorAction Continue

Write-Host "``nRunning WinConfig download script..." -ForegroundColor Green
irm https://raw.githubusercontent.com/Qaddoumi/winconfig/main/Download | iex -ErrorAction Continue

Write-Host "``nLaunching WinConfig..." -ForegroundColor Green
Set-Location -Path "C:\Users\admin\Desktop\winconfig-main"
& .\InstallAllTweaksWithoutTheApps.ps1 -ScriptLocation "$($env:USERPROFILE)\Desktop\winconfig-main" -ErrorAction Continue

Write-Host "``nCleaning up installation files..." -ForegroundColor Green
Remove-Item -Path "$($env:USERPROFILE)\Desktop\winconfig-main" -Recurse -Force -ErrorAction Continue
Remove-Item -Path "$($env:USERPROFILE)\Desktop\winconfig.lnk" -Force -ErrorAction Continue
Remove-Item -Path "$($env:USERPROFILE)\Desktop\RunAll.bat" -Force -ErrorAction Continue

Write-Host "`nScript completed. Removing self..." -ForegroundColor Green
Remove-Item -Path "`$PSCommandPath" -Force -ErrorAction SilentlyContinue
"@

Set-Content -Path "$($env:USERPROFILE)\Desktop\RunAll.ps1" -Value $fileContent -Encoding ASCII

$batContent = "@echo off
powershell -NoProfile -Command `"& {Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$($env:USERPROFILE)\Desktop\RunAll.ps1' -Verb RunAs}`" 
"

Set-Content -Path "$($env:USERPROFILE)\Desktop\RunAll.bat" -Value $batContent -Encoding ASCII

exit