#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef PackageDirectory
  #error PackageDirectory is required
#endif
#ifndef InstallerOutput
  #error InstallerOutput is required
#endif
[Setup]
AppId={{074D1A56-8482-43A1-A3F8-2FA3C4F30B89}
AppName=Tokeni Bar
AppVersion={#AppVersion}
AppPublisher=Tokeni Bar
AppPublisherURL=https://github.com/90ms/tokeni-bar
DefaultDirName={localappdata}\Programs\Tokeni Bar
DefaultGroupName=Tokeni Bar
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
AppMutex=Local\TokeniBarDesktopInstance
CloseApplications=no
RestartApplications=no
UninstallDisplayIcon={app}\TokeniWindows.exe
OutputDir={#InstallerOutput}
OutputBaseFilename=Tokeni-Bar-Windows-{#AppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#PackageDirectory}\TokeniBar.ico
DisableProgramGroupPage=yes
VersionInfoVersion={#AppVersion}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PackageDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Tokeni Bar"; Filename: "{app}\TokeniWindows.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Tokeni Bar"; Filename: "{app}\TokeniWindows.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\TokeniBar\Installation"; ValueType: string; ValueName: "Directory"; ValueData: "{app}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\TokeniWindows.exe"; Description: "{cm:LaunchProgram,Tokeni Bar}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Entry: String;
begin
  if CurUninstallStep = usUninstall then begin
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'TokeniBar', Entry) then
      if Pos(ExpandConstant('{app}\TokeniWindows.exe'), Entry) > 0 then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'TokeniBar');
  end;
end;
