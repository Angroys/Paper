; Inno Setup 6 script for the Paper Windows test installer (unsigned).
;
; Built in CI (.github/workflows/ci.yml, job build-windows):
;   iscc /DAppVersion=<ver> /DSourceDir=<runner dir> /DOutputDir=<dir> ^
;        /DOutputBaseFilename=Paper-<ver>-windows-setup paper.iss
;
; Relative paths below resolve against this script's folder.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Debug"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "Paper-" + AppVersion + "-windows-setup"
#endif

; Must match BINARY_NAME in windows/CMakeLists.txt.
#define AppExeName "paper.exe"

[Setup]
; Stable AppId: keep it unchanged so upgrades replace the previous install.
AppId={{B27C2DE9-AF28-4577-AF88-EF551207B5A3}
AppName=Paper
AppVersion={#AppVersion}
AppVerName=Paper {#AppVersion}
AppPublisher=paper.college
AppPublisherURL=https://paper.college
DefaultDirName={autopf}\Paper
DefaultGroupName=Paper
DisableProgramGroupPage=yes
PrivilegesRequired=admin
; The paper:// handler is written per-user (HKCU), matching what the app
; itself writes at runtime (lib/auth/windows_protocol_registration.dart).
UsedUserAreasWarning=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName=Paper
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Paper"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Paper"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; paper:// URL protocol -> "{app}\paper.exe" "%1"
Root: HKCU; Subkey: "Software\Classes\paper"; ValueType: string; ValueName: ""; ValueData: "URL:Paper Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\paper"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\paper\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKCU; Subkey: "Software\Classes\paper\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,Paper}"; Flags: nowait postinstall skipifsilent
