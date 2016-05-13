unit telweather;

{$APPTYPE CONSOLE}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,IniFiles,DateUtils, DB, DBTables,QDialogs, StdCtrls, Math,Registry;


type
  YMDHM=^TYMDHM;
  TYMDHM=record
    year:integer;
    month:integer;
    day:integer;
    hour:integer;
    minute:integer;
end;

type
  MDBDATA=^TMDBDATA;
  TMDBDATA=record
    value:integer;
    pname:integer;
    check:integer;
    diff:integer;
    ltype:integer;
    lvalue:integer;
end;

type
  Tfrc=record
    year:integer;
    month:integer;
    day:integer;
    hour:integer;
    minute:integer;
    index:integer;
    t:integer;
    td: Double;
    pressure:integer;
    oblaka:integer;
    pogoda:integer;
    windSpeed:integer;
    wind_dir:integer;
end;
  Function MdbOpen (hWnd:integer):integer;stdcall;
  Function MdbOpenR (szFileName: Pchar): THandle; stdcall;  
  Function MdbClose (hDB:integer):integer;stdcall;
  procedure MdbSetCodeForm (h,cf:integer);stdcall;
  procedure MdbSetObsInt (h:integer; ot:YMDHM; duration:integer);stdcall;
  Function MdbNext (h:integer):boolean;stdcall;
  Function MdbGetIndex (h:integer):integer;stdcall;
  Function MdbGetCodeForm (h:integer):integer;stdcall;
  Function MdbGetObsTime (h:integer;ot:YMDHM):boolean;stdcall;
  Function MdbGetData (h:integer; ot:MDBDATA):boolean;stdcall;

  //Function LogFileCreate(lpszName:PChar; dwRecords:integer; wRecSize:word):Bool; stdcall;
  //Function LogOpen(lpszName:PChar):THandle;stdcall;
  //Procedure LogClose(hLog:THandle);stdcall;
  //Procedure LogSetAllRoutes(hLog:THandle; bOn:LongBool);stdcall;
  //Function LogSetRoute(hLog:THandle; bRoute:byte; bOn:LongBool):LongBool;stdcall;
  //Function LogWrite(hLog:Thandle; bRoute:Integer; lpszText:PChar):LongBool;stdcall;
  //Function LogWithSign(hLog:THandle; bRoute:Integer; lpMsg:PChar; lpSign:PChar):LongBool;stdcall;


var
  ID: Variant;
  ConHandle: THandle;
  Coord: TCoord;
  MaxX,MaxY: Word;
  CCI: TConsoleCursorInfo;
  NOAW: LongInt;
  R: TSmallRect;
  mesg: TMSG;
  strPathFile,timeUpdate:string;
  masFrc:array of TFrc;
  st: TSystemTime;
  Database1: TDatabase;
  Query1:TQuery;
  Procedure Main;
  procedure OpenMDB;
  function frcTime:TYMDHM;
  function CreateTemper(var obsDate:TYMDHM;s:TStrings;k:integer):boolean;
  procedure WriteMdb(var obsDate1:TYMDHM;region:integer);
  Procedure TimerCallBack();
      procedure KillTimer(hWnd, uIDEvent: DWORD);
  stdcall; external 'user32.dll' name 'KillTimer';
  function SetTimer(hWnd, nIDEvent, uElapse: DWORD; lpTimerFunc: Pointer): DWORD;
     stdcall; external 'user32.dll' name 'SetTimer';

implementation

  Function MdbOpen; stdcall; external 'windbr32.dll';
  Function  MdbOpenR (szFileName: Pchar): THandle; stdcall; external 'WinDbr32';
  Function MdbClose; stdcall; external 'windbr32.dll';
  procedure MdbSetCodeForm;stdcall;external 'windbr32.dll';
  procedure MdbSetObsInt;stdcall; external 'windbr32.dll';
  Function MdbNext;stdcall; external 'windbr32.dll';
  Function MdbGetIndex;stdcall; external 'windbr32.dll';
  Function MdbGetCodeForm;stdcall; external 'windbr32.dll';
  Function MdbGetObsTime;stdcall; external 'windbr32.dll';
  Function MdbGetData;stdcall; external 'windbr32.dll';

  //Function LogFileCreate; external 'WMETEO32.DLL';
  //Function LogOpen; external 'WMETEO32.DLL';
  //Procedure LogClose; external 'WMETEO32.DLL';
  //Procedure LogSetAllRoutes; external 'WMETEO32.DLL';
  //Function LogSetRoute; external 'WMETEO32.DLL';
  //Function LogWrite; external 'WMETEO32.DLL';
  //Function LogWithSign; external 'WMETEO32.DLL';



procedure Main;
var k:integer; MyIniFile:TIniFile;
    buf: array[0..1024] of char;
    str:string;
    reg: TRegistry;
begin


  ConHandle:=GetStdHandle(STD_INPUT_HANDLE);
  Coord := GetLargestConsoleWindowSize(ConHandle);
  MaxX := Coord.X;
  MaxY := Coord.Y;
  r.Left:= 10;  r.Top:= 10; r.Right:= 40;  r.Bottom:= 40;
  SetConsoleWindowInfo(ConHandle, False, R);
  SetConsoleTitle('NowWeather (www.meteo.nnov.ru)');
  ShowCursor(False);

  {try
    reg := TRegistry.Create;
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.LazyWrite := false;
    reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run',false);
    str:=reg.ReadString('NowWeather');
    if (str='') then
      reg.WriteString('NowWeather', Application.ExeName);
    reg.CloseKey;
    reg.Free;
  except
    Writeln('You are not to add NowWeather in the autorun . You are not admin');
  end;}

  k:= GetModuleFilename(hInstance, @buf, SizeOf(buf));
  k:=LastDelimiter('\',buf);
  k:=k+1;
  strPathFile:=buf;
  Delete(strPathFile,k,Length(buf)-k+1);

  MyIniFile:=TIniFile.Create(strPathFile+'nowweather.ini');
  with MyIniFile do
    timeUpdate:=ReadString('meteo','timeUpdate','');
  MyIniFile.Free;
  writeln('Start successfully');

  SetTimer (0, 1,30000,@TimerCallBack);
  while GetMessage(mesg, 0, 0, 0) do begin
    DispatchMessage(mesg);
  end;
  KillTimer(0,1);
  
end;

Procedure TimerCallBack();
var  st:TSYSTEMTIME;
     Hour,Min,Sec,MSec:Word;
     s1,s2:TStrings;
     dt, newdt:TDateTime;
     i:integer;
     strTime:string;
begin
    GetSystemTime(st);
    dt:=SystemTimeToDateTime(st);
    DecodeTime(dt,Hour,Min,Sec,MSec);
    dt:=encodeTime(Hour,Min,Sec,MSec);
    
    s1:=TstringList.Create;
    s1.Add(timeUpdate);
    s2:=TstringList.Create;
    s2.CommaText:=s1[0];
    for i:=0 to s2.Count-1 do
    begin
      strTime:=s2.Strings[i];
      Hour:=strToIntDef(Copy(strTime,1,Pos(':',strTime)-1),0);
      Min:=strToIntDef(Copy(strTime,Pos(':',strTime)+1,Length(strTime)),0);
      if encodeTime(Hour,Min, Sec, MSec) = dt then
      begin
        writeln(intTostr(Hour)+':'+intTostr(Min)+':'+intTostr(Sec)+' Begin update');
        OpenMDB;
        GetSystemTime(st);
        newdt:=SystemTimeToDateTime(st);
        DecodeTime(newdt,Hour,Min,Sec,MSec);
        writeln(intTostr(Hour)+':'+intTostr(Min)+':'+intTostr(Sec)+' End update');
        break;
      end;
    end;

    s2.Free;
    s1.Free;
end;

procedure OpenMDB;
var s1,s2:TStrings;
    obsDate:TYMDHM;
    Year,Month, Day, Hour: Word;
    MyIniFile:TIniFile;
    i,j:integer;
begin
  obsDate:=frcTime;

  Year:=st.wYear;
  Month:=st.wMonth;
  Day:=st.wDay;
  Hour:=st.wHour;

  MyIniFile:=TIniFile.Create(strPathFile+'nowweather.ini');
  with MyIniFile do
  for i:=0 to 7 do
  begin
    s1:=TstringList.Create; s1.Add(ReadString('meteo',intToStr(i),''));
    s2:=Tstringlist.Create;
    s2.CommaText:=s1[0];
    setLength(masFrc,s2.Count);
    for j:=0 to length(masFrc)-1 do
    begin
      masFrc[j].year:=year;
      masFrc[j].month:=month;
      masFrc[j].day:=day;
      masFrc[j].hour:=hour;
      masFrc[j].minute:=0;
      masFrc[j].index:=strToIntdef(s2.Strings[j],0);
      masFrc[j].t:=-10000;
      masFrc[j].td := -10000;
      masFrc[j].pressure:=-10000;
      masfrc[j].oblaka:=-10000;
      masfrc[j].pogoda:=-10000;
      masfrc[j].windSpeed:=-10000;
      masfrc[j].wind_dir:=-10000;
    end;
    if CreateTemper(obsDate,s2,i) then
    begin
      DataBase1:=TDataBase.Create(nil);
      DataBase1.AliasName:=ReadString('webmdb','aliasname','');
      DataBase1.DatabaseName:=ReadString('webmdb','DatabaseName','');
      DataBase1.KeepConnection:=True;
      DataBase1.LoginPrompt:=False;
      DataBase1.Params.Clear;
      DataBase1.Params.Add('USER NAME='+ReadString('webmdb','username',''));
      DataBase1.Params.Add('PASSWORD='+ReadString('webmdb','userpasswd',''));
      try
        Database1.Connected := TRUE;
      except
        on E: EDBEngineError do
          Writeln('Date: '+intTostr(obsDate.day)+'/'+intTostr(obsDate.month)+'/'+intTostr(obsDate.year)+' '+intTostr(obsDate.hour)+':'+intTostr(obsDate.minute)+'(GMT) Connect with www.meteo.nnov.ru has not been successfully'); end;
      if Database1.Connected=True then
      begin
        Query1:=TQuery.Create(nil);
        Query1.DatabaseName:=ReadString('webmdb','DatabaseName','');
        Query1.Close;
        Query1.SQL.Clear;
        WriteMdb(obsDate,i);
        Database1.Connected:=false;
        Query1.Free;
      end;
      Database1.Free;
    end;
    s2.Free;
    s1.Free;
    masFrc:=nil;
  end;
  MyIniFile.Free;
end;

procedure WriteMdb(var obsDate1:TYMDHM;region:integer);
var strZapros,strWd,strDate,strTime:string;
    i,k, td:integer;
    MyIniFile:TIniFile;
  const masveter: array [0..7] of string=('Ñ','Ñ-Â','Â','Þ-Â','Þ','Þ-Ç','Ç','Ñ-Ç');
  const masvetegr: array [0..7] of integer=(0,45,90,135,180,225,270,315);
  var s: TStringList;
begin
  for i:=0 to length(masFrc)-1 do
  begin
    if (masfrc[i].t = -10000) then
    begin
      Writeln('Station: '+intToStr(masFrc[i].index)+' Data has not written successfully. Data is not correct');
      continue;
    end;
    if (masFrc[i].wind_dir<>-10000) then
    begin
      for k:=0 to length(masvetegr)-2 do
        if (masFrc[i].wind_dir>=masvetegr[k])and (masFrc[i].wind_dir<masvetegr[k+1])then
        begin
          strWd:=masveter[k];
          break;
        end
        else if masFrc[i].wind_dir>=masvetegr[length(masvetegr)-1] then strWd:=masveter[length(masvetegr)-1];
    end
    else strWd:='-10000';
    strDate:=intToStr(masFrc[i].month)+'/'+intToStr(masFrc[i].day)+'/'+intToStr(masFrc[i].year);
    strTime:=intToStr(masFrc[i].hour)+':'+intToStr(masFrc[i].minute);
    if Frac(masfrc[i].t/100)<=0.5 then
      masfrc[i].t:=Floor(masfrc[i].t/100)
    else masfrc[i].t:=Ceil(masfrc[i].t/100);
    if (masFrc[i].index = 27459) then
    begin
      s:=TstringList.Create;
      s.Add('{');
      s.Add('"temper":'+intToStr(masFrc[i].t));
      s.Add(',');
      s.Add('"pressure":'+intToStr(Ceil(masFrc[i].pressure*0.75)));
      s.Add(',');
      td := 100-5*(masfrc[i].t-Ceil(masfrc[i].td));
      s.Add(',');
      s.Add('"humidity":'+ intToStr(td));
      s.Add(',');
      s.add('"wind_speed":'+ intToStr(masFrc[i].windSpeed));
      s.Add(',');
      s.Add('"wind_dir":'+intToStr(masFrc[i].wind_dir));
      s.add('}');
      MyIniFile:=TIniFile.Create(strPathFile+'nowweather.ini');      
      s.SaveToFile(MyIniFile.ReadString('dataFile','folder','')+intToStr(masFrc[i].index)+'.json');
      MyIniFile.Free;
      s.Free;
    end;
    strZapros:='INSERT INTO tekweather (date,time,index,te,pressure,obl,pogoda,wind_speed,wd,region) VALUES ('+''''+strDate+''','+''''+strTime+''''+' ,'+intToStr(masFrc[i].index)+' ,'+intToStr(masFrc[i].t)+', '+intToStr(masFrc[i].pressure)+', '+intToStr(masFrc[i].oblaka)+', '+intToStr(masFrc[i].pogoda)+', '+intToStr(masFrc[i].windSpeed)+', '''+strWd+''', '+IntToStr(region+1)+')';
    Query1.Close;
    Query1.SQL.Clear;
    Query1.SQL.Add(strZapros);
    try
      Query1.ExecSQL;
      Writeln('Station: '+intToStr(masFrc[i].index)+' Data has written successfully');
    except
      Writeln(strZapros);
      Writeln('Station: '+intToStr(masFrc[i].index)+' Data has not written successfully');
    end;
    Query1.Close;
    Query1.SQL.Clear;
  end;
end;

function CreateTemper(var obsDate:TYMDHM;s:TStrings;k:integer):boolean;
var PobsDate:YMDHM;
    Date:TMDBDATA;
    PDate:MDBDATA;
    Handle,nIndex,nCode,j:integer;
    //F:TextFile;
    //str:string;
    basePath: string;
    MyIniFile: TIniFile;
begin
    Result:=false;
    MyIniFile:=TIniFile.Create(strPathFile+'nowweather.ini');
    basePath := MyIniFile.ReadString('Meteo', 'mdbfile', '');
    MyIniFile.Free;
    Handle:=MdbOpenR(Pchar(basePath));

    if(Handle<>0) then
    begin
      Writeln('Date: '+intTostr(obsDate.day)+'/'+intTostr(obsDate.month)+'/'+intTostr(obsDate.year)+' '+intTostr(obsDate.hour)+':'+intTostr(obsDate.minute)+'(GMT) Sucsess to meteo.cdb');
      MdbSetCodeForm (Handle,16);
      PobsDate:=@obsDate;
      MdbSetObsInt(Handle,PobsDate,0);
      while (MdbNext(Handle)=TRUE) do
      begin
        nIndex:=MdbGetIndex(Handle);
          for j:=0 to length(masfrc)-1 do
          begin
            if (nIndex=masfrc[j].index) then
            begin
             nCode:=MdbGetCodeForm (Handle);
             MdbGetObsTime(Handle,PobsDate);
             PDate:=@Date;
             while(MdbGetData(Handle,PDate) = TRUE) do
             begin
                if (Date.pname=2) and (Date.ltype=1) then
                begin
                  masfrc[j].t:=Date.value;
                end;
                if (Date.pname=1) and (Date.ltype=1) then
                begin
                  masfrc[j].pressure:=Date.value div 10;
                end;
                if (Date.pname=229) and (Date.ltype=1) then
                begin
                  masfrc[j].oblaka:=Date.value;
                end;
                if (Date.pname=226) and (Date.ltype=1) then
                begin
                  masfrc[j].pogoda:=Date.value;
                end;
                if (Date.pname=5) and (Date.ltype=1) then
                begin
                  masfrc[j].windSpeed:=Date.value;
                end;
                if (Date.pname=4) and (Date.ltype=1) then
                begin
                  masfrc[j].wind_dir:=Date.value;
                end;
                if (Date.pname=7) and (Date.ltype=1) then
                begin
                  masfrc[j].td:=Date.value/100;
                end;
              end;
            end;
          end;
      end;
   end
   else
   begin
    Writeln('Date: '+intTostr(obsDate.day)+'/'+intTostr(obsDate.month)+'/'+intTostr(obsDate.year)+' '+intTostr(obsDate.hour)+':'+intTostr(obsDate.minute)+'(GMT) Data has not selected successfully. Access denided to meteo.cdb');
   end;
  if(Handle<>0) then
  begin
    MdbClose(Handle);
    result:=true;
  end;

  {if (Handle<>0) then
  begin
    AssignFile(F,strPathFile+'\\otbor'+intToStr(k)+'.txt');
    Rewrite(F);
    try
      for j:=0 to length(masfrc)-1 do
      begin
        if Frac(masfrc[j].t/100)<=0.5 then
          masfrc[j].t:=Floor(masfrc[j].t/100) //str:=IntToStr(j+1)+'='+ IntToStr(Floor(strTofloat(s.strings[j])/100))
        else masfrc[j].t:=Ceil(masfrc[j].t/100);//str:=IntToStr(j+1)+'='+floatToStr(Ceil(strTofloat(s.strings[j])/100));
        str:='day='+intToStr(masfrc[j].day)+',month='+intToStr(masfrc[j].month)+',year='+intToStr(masfrc[j].year)+',hour='+intToStr(masfrc[j].hour)+',minute='+intToStr(masfrc[j].minute)+',index='+intToStr(masfrc[j].index)+','+'T='+intToStr(masfrc[j].t)+','+'Pressure='+intToStr(masfrc[j].pressure)+','+'Obl='+intToStr(masfrc[j].oblaka)+','+'Pogoda='+intTostr(masfrc[j].pogoda)+','+'ws='+intToStr(masfrc[j].windSpeed)+','+'wd='+intTostr(masfrc[j].wind_dir);
        Writeln(F,str);
      end;
      Writeln('Date: '+intTostr(obsDate.day)+'/'+intTostr(obsDate.month)+'/'+intTostr(obsDate.year)+' '+intTostr(obsDate.hour)+':'+intTostr(obsDate.minute)+'0 (GMT) File otbor'+intToStr(k)+'.txt was wrote successfully');
    finally
      CloseFile(F);
    end;
  end;}

end;

function frcTime:TYMDHM;
var
    Year,Month, Day, Hour: Word; s1,s2:Tstrings; i:integer;s:string;
    obsDate:TYMDHM;
    TZ: TTimeZoneInformation;
    dt:TdateTime;
    MyIniFile :TIniFile;
    timezone: string;
begin

  GetSystemTime(st);

  Year:=st.wYear;
  Month:=st.wMonth;
  Day:=st.wDay;
  Hour:=st.wHour;

  s:='0,3,6,9,12,15,18,21';
  s1:=TStringList.Create;
  s2:=TStringList.Create;
  s1.Add(s);
  s2.CommaText:=s1[0];

  for i:=0 to 6 do
  begin
    if(Hour>=StrToIntDef(s2[i],1))and (Hour<StrToIntDef(s2[i+1],1)) then
    begin
      obsDate.year:=Year;
      obsDate.month:=Month;
      obsDate.day:=Day;
      obsDate.hour:=StrToIntDef(s2[i],1);
      obsDate.minute:=0;
    end
  end;
  if Hour>=StrToIntDef(s2[7],1) then
  begin
      obsDate.year:=Year;
      obsDate.month:=Month;
      obsDate.day:=Day;
      obsDate.hour:=StrToIntDef(s2[7],1);
      obsDate.minute:=0;
  end;
  dt:=encodeDateTime(obsDate.year,obsDate.month,obsDate.day,obsDate.hour,obsDate.minute,0,0);
  MyIniFile:=TIniFile.Create(strPathFile+'nowweather.ini');
  timezone := MyIniFile.ReadString('Meteo', 'timezone', '');
  MyIniFile.Free;
  dt := IncMinute(dt, strToIntDef(timezone, 3));  
  dateTimeToSystemTime(dt, st);
  //GetTimeZoneInformation(TZ);
  //SystemTimeToTzSpecificLocalTime(@TZ, ST, ST);
  s2.Free;
  s1.Free;
  Result:=obsDate;
end;

function GetConInputHandle : THandle;
begin
 Result := GetStdHandle(STD_INPUT_HANDLE)
end;

function GetConOutputHandle : THandle;
begin
 Result := GetStdHandle(STD_OUTPUT_HANDLE)
end;

procedure GotoXY(X, Y : Word);
begin
 Coord.X := X; Coord.Y := Y;
 SetConsoleCursorPosition(ConHandle, Coord);
end;

procedure Cls;
begin
 Coord.X := 0; Coord.Y := 0;
 //FillConsoleOutputCharacter(ConHandle, ' ', 50*50,  Coord, 3);
 GotoXY(0, 0);
end;

procedure ShowCursor(Show : Bool);
begin
 CCI.bVisible := Show;
 SetConsoleCursorInfo(ConHandle, CCI);
end;

end.

