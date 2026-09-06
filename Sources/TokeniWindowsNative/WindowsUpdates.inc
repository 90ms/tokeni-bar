static HWND tokeni_update_controls[4];
static LONG tokeni_update_requested,tokeni_install_requested,tokeni_auto_update;
static void tokeni_update_create(HWND window)
{
    const WCHAR *labels[]={L"Check for updates",L"Install update",L"Check automatically",L""};
    for(int i=0;i<4;i++)tokeni_update_controls[i]=CreateWindowExW(0,i==3?L"STATIC":L"BUTTON",labels[i],WS_CHILD|WS_TABSTOP|(i==2?BS_AUTOCHECKBOX:0),0,0,0,0,window,(HMENU)(INT_PTR)(580+i),tokeni_instance,NULL);
    DWORD value=0,size=sizeof(value);
#ifndef TOKENI_DESKTOP_TEST
    RegGetValueW(HKEY_CURRENT_USER,L"Software\\TokeniBar\\Desktop",L"AutoCheckUpdates",RRF_RT_REG_DWORD,NULL,&value,&size);
#endif
    InterlockedExchange(&tokeni_auto_update,value==1);
    SendMessageW(tokeni_update_controls[2],BM_SETCHECK,value==1?BST_CHECKED:BST_UNCHECKED,0);
    EnableWindow(tokeni_update_controls[1],FALSE);
}
static void tokeni_update_layout(int left,int top,int width,int bottom,int gap,UINT dpi)
{
    for(int i=0;i<4;i++)ShowWindow(tokeni_update_controls[i],tokeni_destination==3?SW_SHOW:SW_HIDE);
    if(tokeni_destination!=3)return;
    int row=MulDiv(38,dpi,96),start=top+MulDiv(140,dpi,96);
    MoveWindow(tokeni_update_controls[0],left,start,width/2-gap,row-6,TRUE);
    MoveWindow(tokeni_update_controls[1],left+width/2,start,width/2,row-6,TRUE);
    MoveWindow(tokeni_update_controls[2],left,start+row,width,row-6,TRUE);
    MoveWindow(tokeni_update_controls[3],left,start+row*2,width,row*2,TRUE);
    int details=start+row*4;
    MoveWindow(tokeni_dashboard_details,left,details,width,max(0,bottom-details),TRUE);
}
static void tokeni_update_command(int id)
{
    if(id==580)InterlockedExchange(&tokeni_update_requested,1);
    if(id==581) { InterlockedExchange(&tokeni_install_requested,1);EnableWindow(tokeni_update_controls[1],FALSE); }
    if(id==582) {
        DWORD value=SendMessageW(tokeni_update_controls[2],BM_GETCHECK,0,0)==BST_CHECKED;
        InterlockedExchange(&tokeni_auto_update,value);
#ifndef TOKENI_DESKTOP_TEST
        HKEY key;if(RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\TokeniBar\\Desktop",0,NULL,0,KEY_SET_VALUE,NULL,&key,NULL)==ERROR_SUCCESS) {RegSetValueExW(key,L"AutoCheckUpdates",0,REG_DWORD,(BYTE *)&value,sizeof(value));RegCloseKey(key);}
#endif
    }
}
int tokeni_windows_update_request(void) { if(InterlockedExchange(&tokeni_install_requested,0))return 2;return InterlockedExchange(&tokeni_update_requested,0); }
int tokeni_windows_update_automatic(void) { return InterlockedCompareExchange(&tokeni_auto_update,0,0)!=0; }
typedef struct { const char *text;int available; } tokeni_update_status_request;
static void tokeni_update_status_ui(void *context)
{
    tokeni_update_status_request *request=context;WCHAR text[1024];tokeni_copy_utf8(request->text,text,1024);
    SetWindowTextW(tokeni_update_controls[3],text);EnableWindow(tokeni_update_controls[1],request->available);
}
void tokeni_windows_update_status(const char *text,int available)
{
    tokeni_update_status_request request={text,available};tokeni_windows_ui_invoke(tokeni_update_status_ui,&request);
}
// Called from the Swift update task, never from the UI thread.
int tokeni_windows_update_prepare(const char *version,const char *tag)
{
    if(!version||!tag||strlen(version)>32||strlen(tag)>33)return 0;
    for(const char *p=version;*p;p++)if((*p<'0'||*p>'9')&&*p!='.')return 0;
    if(strcmp(tag,version)&&!(tag[0]=='v'&&!strcmp(tag+1,version)))return 0;
    WCHAR application[32768],powershell[32768],command[65536],v[64],t[64];
    DWORD length=GetModuleFileNameW(NULL,application,32768);if(!length||length>=32768)return 0;
    WCHAR *last=wcsrchr(application,L'\\');if(!last)return 0;*last=0;
    GetSystemDirectoryW(powershell,32768);lstrcatW(powershell,L"\\WindowsPowerShell\\v1.0\\powershell.exe");
    tokeni_copy_utf8(version,v,64);tokeni_copy_utf8(tag,t,64);
    int count=swprintf(command,65536,L"\"%ls\" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"%ls\\Tools\\Update-TokeniBar.ps1\" -Mode Prepare -Version %ls -Tag %ls -ApplicationDirectory \"%ls\" -ParentProcessId %lu",powershell,application,v,t,application,GetCurrentProcessId());
    if(count<0||count>=65536)return 0;
    STARTUPINFOW startup={sizeof(startup)};PROCESS_INFORMATION process={0};
    if(!CreateProcessW(powershell,command,NULL,NULL,FALSE,CREATE_NO_WINDOW,NULL,NULL,&startup,&process))return 0;
    DWORD waited=WaitForSingleObject(process.hProcess,240000),code=1;
    if(waited==WAIT_OBJECT_0)GetExitCodeProcess(process.hProcess,&code);
    else TerminateProcess(process.hProcess,1);
    CloseHandle(process.hThread);CloseHandle(process.hProcess);return code==0;
}
