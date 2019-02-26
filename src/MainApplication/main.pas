unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Configuration, StdCtrls, Vcl.Imaging.pngimage, Skins,
  MainSkinRect, volume, AppEvnts, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IniFiles;

type

  TMainForm = class(TForm)
    ApplicationEvents: TApplicationEvents;
    IdTCPClient: TIdTCPClient;
    check_connection_timer: TTimer;
    readLn: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ApplicationEventsException(Sender: TObject; E: Exception);
    procedure check_connection_timerTimer(Sender: TObject);
    procedure readLnTimer(Sender: TObject);
  private
    ScrWidth,ScrHeight: integer;
    Skin: TSkins;
    ProcList: TStringList;
    MainSkinsRect: TMainSkinsRect;
    SelectedRect: TRect;

    procedure ButtonClick(Sender: TObject; FormName,Event: string);
  public
    Settings: TSettings;
  end;

var
  MainForm: TMainForm;

implementation

uses About;

{$R *.dfm}

function WindowsExit(RebootParam: Longword): Boolean;
	var
	  TTokenHd: THandle;
	  TTokenPvg: TTokenPrivileges;
	  cbtpPrevious: DWORD;
	  rTTokenPvg: TTokenPrivileges;
	  pcbtpPreviousRequired: DWORD;
	  tpResult: Boolean;
	const
	  SE_SHUTDOWN_NAME = 'SeShutdownPrivilege';
	begin
	  if Win32Platform = VER_PLATFORM_WIN32_NT then
	  begin
	    tpResult := OpenProcessToken(GetCurrentProcess(),
	      TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY,
	      TTokenHd) ;
	    if tpResult then
	    begin
	      tpResult := LookupPrivilegeValue(nil,
	                                       SE_SHUTDOWN_NAME,
	                                       TTokenPvg.Privileges[0].Luid) ;
	      TTokenPvg.PrivilegeCount := 1;
	      TTokenPvg.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
	      cbtpPrevious := SizeOf(rTTokenPvg) ;
	      pcbtpPreviousRequired := 0;
	      if tpResult then
	        Windows.AdjustTokenPrivileges(TTokenHd,
	                                      False,
	                                      TTokenPvg,
	                                      cbtpPrevious,
	                                      rTTokenPvg,
	                                      pcbtpPreviousRequired) ;
	    end;
	  end;
	  Result := ExitWindowsEx(RebootParam, 0) ;
end;

function SetScreenResolution(Width, Height: integer): Longint;
var
  DeviceMode: TDeviceMode;
begin
try
  with DeviceMode do begin
    dmSize := SizeOf(TDeviceMode);
    dmPelsWidth := Width;
    dmPelsHeight := Height;
    dmFields := DM_PELSWIDTH or DM_PELSHEIGHT;
  end;
  Result := ChangeDisplaySettings(DeviceMode, CDS_UPDATEREGISTRY);
except

end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Left :=0;
  Top  :=0;
  ScrWidth := GetSystemMetrics(SM_CXSCREEN);
  ScrHeight := GetSystemMetrics(SM_CYSCREEN);
  SetScreenResolution(640,480);
  Width := Screen.Width;
  Height := Screen.Height;
 // Width:=Screen.Width;
 // Height:=Screen.Height;
 // ProcList:= TStringList.Create;
  Settings:= TSettings.Create(nil);
  Settings.GetSkinSettings;

  Skin   := TSkins.CreateWithSettings(nil,Settings);



  MainSkinsRect:= TMainSkinsRect.Create(nil);
  MainSkinsRect.Settings    := Settings;
  MainSkinsRect.OnClickEvent  := ButtonClick;
  MainSkinsRect.FormWidth     := Width;
  MainSkinsRect.FormHeight    := Height;
  MainSkinsRect.Skin          := Skin;

  //check_connection_timer.Enabled := true;

end;

procedure TMainForm.FormPaint(Sender: TObject);
begin
  if Skin <> nil then
    Skin.DrawSkinMainForm(Canvas,ClientRect,SelectedRect);
end;

procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Skin <> nil then
  begin
    SelectedRect := MainSkinsRect.GetMouseCoordinateWithRect(X,Y);
    Skin.DrawSkinMainForm(Canvas,ClientRect,SelectedRect);
  end;
end;

procedure TMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Skin <> nil then
  begin
    SelectedRect.Left := 0;
    SelectedRect.Top := 0;
    SelectedRect.Right := 0;
    SelectedRect.Bottom := 0;
    MainSkinsRect.ClickCoordinateButton(LowerCase(Name),X,Y);
    Skin.DrawSkinMainForm(Canvas,ClientRect,SelectedRect);
  end;
end;

procedure TMainForm.ButtonClick(Sender: TObject; FormName,Event: string);
begin
 // ShowMessage(FormName+'--'+ Event);
  if Event = 'VOLUMEDOWN' then
  begin
    DecVolume;
  end;

  if Event = 'VOLUMEUP' then
  begin
    IncVolume;
  end;

  if Event = 'VOLUMEMUTE' then
  begin
  //  ShowMessage('mute');
    Mute;
  end;

  if Event = 'NAVIGASYONNEXT' then
    Skin.NavigationPage := Skin.NavigationPage + 1;

  if Event = 'NAVIGASYONBACK' then
    Skin.NavigationPage := Skin.NavigationPage - 1;

  if Event = 'SWICHMODE' then
    frmAboutBox.ShowModal;

  if Event = 'CLOSEBUTTON' then
    Close;


end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 { Skin.Free;
  MainSkinsRect.Free;
  Settings.Free;
}
  SetScreenResolution(ScrWidth,ScrHeight);
end;

procedure TMainForm.ApplicationEventsException(Sender: TObject;
  E: Exception);
begin
  E := nil;
end;

procedure TMainForm.check_connection_timerTimer(Sender: TObject);
var
  ini: TIniFile;
  host: string;
  port: integer;
begin
try
  check_connection_timer.Enabled := false;
  if not IdTCPClient.Connected then
  begin
    ini:= TIniFile.Create(ExtractFilePath(ParamStr(0))+'config.ini');
    host := ini.ReadString('ServerOptions','IP','');
    port := ini.ReadInteger('ServerOptions','Port',15419);
    IdTCPClient.Host := host;
    IdTCPClient.Port := port;
    IdTCPClient.Connect;
    readLn.Enabled := true;
  end;
  check_connection_timer.Enabled := true;
except
  check_connection_timer.Enabled := true;
end;
end;

procedure TMainForm.readLnTimer(Sender: TObject);
var
  Msg: string;
begin
try
  readLn.Enabled := false;
  if IdTCPClient.Connected then
  begin
    Msg := IdTCPClient.IOHandler.ReadLn;
    Msg := Trim(Msg);
    if Msg = 'SHOTDOWN_PC' then
    begin
      WindowsExit(EWX_SHUTDOWN or EWX_FORCE);
    end;
  end;
  readLn.Enabled := true;
except
  readLn.Enabled := true;
end;

end;

end.
