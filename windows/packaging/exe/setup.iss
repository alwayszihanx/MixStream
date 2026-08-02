[Setup]
AppId={{DA3F45DE-00B2-4EFC-81B0-BA101DCA73E8}
AppName=MixStream
AppVersion={#AppVersion}
AppPublisher=MixStream
AppPublisherURL=https://github.com/alwayszihanx/mixstream
AppSupportURL=https://github.com/alwayszihanx/mixstream
AppUpdatesURL=https://github.com/alwayszihanx/mixstream
DefaultDirName={autopf}\MixStream
DefaultGroupName=MixStream
DisableProgramGroupPage=yes
OutputBaseFilename=MixStream-Windows-{#AppArch}-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\runner\resources\app_icon.ico
#if AppArch == "x64"
  ArchitecturesAllowed=x64compatible
  ArchitecturesInstallIn64BitMode=x64compatible
#else
  ArchitecturesAllowed={#AppArch}
  ArchitecturesInstallIn64BitMode={#AppArch}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MixStream"; Filename: "{app}\mixstream.exe"
Name: "{autodesktop}\MixStream"; Filename: "{app}\mixstream.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\mixstream.exe"; Description: "{cm:LaunchProgram,MixStream}"; Flags: nowait postinstall skipifsilent
