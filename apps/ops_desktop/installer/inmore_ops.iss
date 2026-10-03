; Inno Setup script for the desktop app.  Built by scripts/build_windows.ps1,
; which passes AppVersion from pubspec.yaml and copies the VC++ runtime DLLs
; into the Release folder first.
;
; Installs per user (no admin prompt) into %LOCALAPPDATA%\Programs; someone
; with admin rights can pick "all users" on the first page instead.  Running a
; newer setup over an old one upgrades in place — AppId must never change.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName   "Inmore Operations"
#define AppExe    "ops_desktop.exe"
#define BuildDir  "..\build\windows\x64\runner\Release"

[Setup]
AppId={{561A3881-AE67-47F6-95FD-120621B7A36B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Inmore
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=InmoreOperations-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; Flutter's assets folder is replaced wholesale on each build; clear the old
; one so files a newer version dropped don't linger.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
