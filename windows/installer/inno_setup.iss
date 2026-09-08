; =====================================================================
; AirFile - Windows Installer Script (Inno Setup 6+)
; Professional Setup Wizard for AirFile Peer-to-Peer Transfer
; =====================================================================

#define MyAppName "AirFile"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "AirFile"
#define MyAppURL "https://github.com/arunthacharuthodi/airfile"
#define MyAppExeName "AirFile.exe"

[Setup]
; Unique App ID (generated for AirFile)
AppId={{8F1D2C9B-5A3E-4B71-9E22-1D4A7F8B6C01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Destination directories
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes

; Packaging and Compression
OutputDir=..\..\build\windows\installer
OutputBaseFilename=AirFile-Setup-x64
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Modern Visual Styling
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Version info in installer binary
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=AirFile Professional Windows Installer
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start AirFile automatically when Windows starts"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Release binaries built by 'flutter build windows --release'
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; Add Windows Firewall exceptions for AirFile local network transfer and discovery
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""AirFile Peer Transfer (TCP-In)"" dir=in action=allow program=""{app}\{#MyAppExeName}"" protocol=TCP localport=53317 enable=yes"; Flags: runhidden; StatusMsg: "Configuring Windows Firewall for local discovery..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""AirFile Discovery (UDP-In)"" dir=in action=allow program=""{app}\{#MyAppExeName}"" protocol=UDP localport=53317 enable=yes"; Flags: runhidden; StatusMsg: "Configuring Windows Firewall for UDP discovery..."

; Launch application after setup
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove Windows Firewall exceptions cleanly upon uninstallation
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AirFile Peer Transfer (TCP-In)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AirFile Discovery (UDP-In)"""; Flags: runhidden
