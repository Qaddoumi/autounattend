# Remove Windows store apps
$app_packages = @(
    "Microsoft.Microsoft3DViewer"
    "Microsoft.AppConnector"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingTravel"
    "Microsoft.BingSearch"
    "Microsoft.WindowsCamera"
    "Microsoft.549981C3F5F10" # Cortana
    "Clipchamp.Clipchamp"
    "Microsoft.DevHome"
    "Microsoft.MinecraftUWP"
    "Microsoft.GamingServices"
    "Microsoft.GamingApp"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.NetworkSpeedTest"
    "Microsoft.News"
    "Microsoft.Office.Lens"
    "Microsoft.Office.Sway"
    "Microsoft.Office.OneNote"
    "Microsoft.OutlookForWindows"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.Wallet"
    "Microsoft.Whiteboard"
    "Microsoft.WindowsAlarms" # Windows Clock
    "microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.YourPhone"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.XboxApp"
    "Microsoft.ConnectivityStore"
    "Microsoft.ScreenSketch" # Snipping Tool
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.PowerAutomateDesktop"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.MixedReality.Portal"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "EclipseManager"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Duolingo-LearnLanguagesforFree"
    "PandoraMediaInc"
    "CandyCrush"
    "BubbleWitch3Saga"
    "Wunderlist"
    "Flipboard"
    "Twitter"
    "Facebook"
    "Royal Revolt"
    "Sway"
    "Speed Test"
    "Dolby"
    "Viber"
    "ACGMediaPlayer"
    "Netflix"
    "OneCalendar"
    "LinkedInforWindows"
    "Spotify"
    "Linkedin"
    "HiddenCityMysteryofShadows"
    "Hulu"
    "HiddenCity"
    "AdobePhotoshopExpress"
    "HotspotShieldFreeVPN"
    "Microsoft.Advertising.Xaml"
    "Microsoft.Windows.Ai.Copilot.Provider"
)
Get-AppxProvisionedPackage -Online | ? {$_.DisplayName -in "*$app_packages*"} | Remove-AppxProvisionedPackage -Online -AllUser

# Deploy an empty start layout
. '.\start2.ps1'

# Prevent OneDrive from installing
ni "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\DisableOneDrive" | New-ItemProperty -Name "StubPath" -Value 'REG DELETE "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f'

# Prevent Outlook (new) and Dev Home from installing
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" | %{
    ri $_ -force
}