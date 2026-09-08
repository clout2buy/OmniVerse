; Inno Setup script for OmniVerse. Built by CI: iscc installer\omniverse.iss /DVersion=0.1.0
; Installs per-user (no admin prompt) into %LOCALAPPDATA%\OmniVerse so the in-game
; auto-updater can overwrite files without elevation.

#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
AppId={{7D2C8E40-3F8B-4C1D-9C6E-0MN1V3R5E001}
AppName=OmniVerse
AppVersion={#Version}
AppPublisher=OmniVerse
DefaultDirName={localappdata}\OmniVerse
DefaultGroupName=OmniVerse
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\build
OutputBaseFilename=OmniVerse-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\OmniVerse.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "..\build\OmniVerse.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\OmniVerse.pck"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\OmniVerse"; Filename: "{app}\OmniVerse.exe"
Name: "{autodesktop}\OmniVerse"; Filename: "{app}\OmniVerse.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\OmniVerse.exe"; Description: "Launch OmniVerse"; Flags: nowait postinstall skipifsilent
