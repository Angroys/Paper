; Inno Setup 6 script for the Paper Windows test installer (unsigned).
;
; Built in CI (.github/workflows/ci.yml, job build-windows):
;   iscc /DAppVersion=<ver> /DSourceDir=<runner dir, Release on tags> /DOutputDir=<dir> ^
;        /DOutputBaseFilename=Paper-<ver>-windows-setup paper.iss
;
; Relative paths below resolve against this script's folder.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
; SourceDir is required: the Flutter runner folder to package, e.g.
;   /DSourceDir=<repo>\build\windows\x64\runner\Release  (CI tag builds)
;   /DSourceDir=<repo>\build\windows\x64\runner\Debug    (CI branch builds)
#ifndef SourceDir
  #error SourceDir is not defined. Pass /DSourceDir=<path to build\windows\x64\runner\Release or Debug>.
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
; The paper:// handler is registered under HKA: HKLM\Software\Classes for
; this admin install (every user), so it is not written into the hive of
; whichever admin account approved the UAC prompt. At runtime the app also
; writes it per-user (HKCU, lib/auth/windows_protocol_registration.dart),
; pointing at the same exe; HKCU wins over HKLM when both exist.
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
Root: HKA; Subkey: "Software\Classes\paper"; ValueType: string; ValueName: ""; ValueData: "URL:Paper"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\paper"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\paper\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKA; Subkey: "Software\Classes\paper\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,Paper}"; Flags: nowait postinstall skipifsilent
