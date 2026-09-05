typedef struct { char id[128]; WCHAR label[256]; int group; } tokeni_inventory_option;
static tokeni_inventory_option tokeni_inventory[512], tokeni_inventory_staged[512];
static int tokeni_inventory_count, tokeni_inventory_staged_count;
static HWND tokeni_pet_extra[13]; // mode, name, rename, primary, inventory, open/buy, sell/equip, checkin, preview, move, motion, size, sell pet
static int tokeni_pet_mode;
static char tokeni_displayed_inventory_ids[512][128];
static int tokeni_action_code;
static char tokeni_action_id[128], tokeni_action_text[256];
static WCHAR tokeni_reward_summary[1024];
static void tokeni_inventory_sync(void);
static void tokeni_inventory_commit_ui(void *unused) { (void)unused; tokeni_inventory_sync(); }
void tokeni_windows_inventory_begin(void) { tokeni_inventory_staged_count=0; }
void tokeni_windows_inventory_append(int group,const char *id,const char *label)
{
    if(tokeni_inventory_staged_count>=512)return;
    tokeni_inventory_option *item=&tokeni_inventory_staged[tokeni_inventory_staged_count++];
    item->group=group;lstrcpynA(item->id,id,128);tokeni_copy_utf8(label,item->label,256);
}
void tokeni_windows_inventory_commit(const char *summary)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_inventory_count=tokeni_inventory_staged_count;
    CopyMemory(tokeni_inventory,tokeni_inventory_staged,sizeof(tokeni_inventory_option)*tokeni_inventory_count);
    tokeni_copy_utf8(summary,tokeni_reward_summary,1024);
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    tokeni_windows_ui_invoke(tokeni_inventory_commit_ui,NULL);
}
int tokeni_windows_take_action(char *id,int capacity,char *text,int text_capacity)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    int result=tokeni_action_code;
    lstrcpynA(id,tokeni_action_id,capacity);lstrcpynA(text,tokeni_action_text,text_capacity);
    tokeni_action_code=0;
    ReleaseSRWLockExclusive(&tokeni_state_lock);return result;
}
static void tokeni_inventory_sync(void)
{
    if(!tokeni_pet_extra[4])return;
    char previous[128]="";
    int selected=(int)SendMessageW(tokeni_pet_extra[4],CB_GETCURSEL,0,0);
    if(selected>=0) {
        if(selected<512)lstrcpynA(previous,tokeni_displayed_inventory_ids[selected],128);
    }
    SendMessageW(tokeni_pet_extra[4],CB_RESETCONTENT,0,0);
    int restore=0;
    AcquireSRWLockShared(&tokeni_state_lock);
    for(int i=0;i<tokeni_inventory_count;i++) {
        if(tokeni_inventory[i].group!=tokeni_pet_mode)continue;
        LRESULT row=SendMessageW(tokeni_pet_extra[4],CB_ADDSTRING,0,(LPARAM)tokeni_inventory[i].label);
        SendMessageW(tokeni_pet_extra[4],CB_SETITEMDATA,row,i);
        if(row>=0&&row<512)lstrcpynA(tokeni_displayed_inventory_ids[row],tokeni_inventory[i].id,128);
        if(!strcmp(previous,tokeni_inventory[i].id))restore=(int)row;
    }
    ReleaseSRWLockShared(&tokeni_state_lock);
    SendMessageW(tokeni_pet_extra[4],CB_SETCURSEL,restore,0);
    SetWindowTextW(tokeni_pet_extra[5],tokeni_pet_mode==1?L"Open an egg":L"Buy selected item");
    SetWindowTextW(tokeni_pet_extra[6],tokeni_pet_mode==2?L"Equip selected item":L"Sell selected item");
    InvalidateRect(tokeni_pet_extra[8],NULL,FALSE);
    PostMessageW(tokeni_dashboard_window,tokeni_details_updated_message,0,0);
}
static void tokeni_pet_extra_create(HWND window)
{
    const WCHAR *labels[]={L"Collection",L"",L"Save nickname",L"Set as desktop pet",L"",L"Open an egg",L"Sell selected item",L"Daily check-in",L"Desktop companion",L"Move desktop pet",L"Reduce motion",L"",L"Sell companion"};
    for(int i=0;i<13;i++) {
        const WCHAR *cls=i==0||i==4||i==11?L"COMBOBOX":i==1?L"EDIT":i==8?L"STATIC":L"BUTTON";
        DWORD style=WS_CHILD|WS_TABSTOP;
        if(i==0||i==4||i==11)style|=CBS_DROPDOWNLIST;
        if(i==1)style|=ES_AUTOHSCROLL|WS_BORDER;
        if(i==8)style|=SS_OWNERDRAW;
        if(i==9||i==10)style|=BS_AUTOCHECKBOX;
        tokeni_pet_extra[i]=CreateWindowExW(0,cls,labels[i],style,0,0,0,0,window,(HMENU)(INT_PTR)(550+i),tokeni_instance,NULL);
    }
    SendMessageW(tokeni_pet_extra[1],EM_SETLIMITTEXT,24,0);
    const WCHAR *modes[]={L"Collection",L"Eggs",L"Shop & rewards"};
    const WCHAR *sizes[]={L"Small",L"Medium",L"Large"};
    for(int i=0;i<3;i++) { SendMessageW(tokeni_pet_extra[0],CB_ADDSTRING,0,(LPARAM)tokeni_text(modes[i]));SendMessageW(tokeni_pet_extra[11],CB_ADDSTRING,0,(LPARAM)tokeni_text(sizes[i])); }
    SendMessageW(tokeni_pet_extra[0],CB_SETCURSEL,0,0);
    SendMessageW(tokeni_pet_extra[11],CB_SETCURSEL,1,0);
}
static void tokeni_pet_extra_layout(int left,int top,int width,int bottom,int gap,UINT dpi)
{
    for(int i=0;i<13;i++)ShowWindow(tokeni_pet_extra[i],tokeni_destination==2?SW_SHOW:SW_HIDE);
    if(tokeni_destination!=2)return;
    int row=MulDiv(40,dpi,96),preview=MulDiv(170,dpi,96),right=left+preview+gap,rest=max(0,width-preview-gap);
    MoveWindow(tokeni_pet_extra[8],left,top,preview,preview,TRUE);
    MoveWindow(tokeni_pet_extra[0],right,top,rest,200,TRUE);
    MoveWindow(tokeni_pet_picker,right,top+row,rest,240,TRUE);
    MoveWindow(tokeni_pet_extra[4],right,top+row,rest,240,TRUE);
    ShowWindow(tokeni_pet_picker,tokeni_pet_mode==0?SW_SHOW:SW_HIDE);
    ShowWindow(tokeni_pet_extra[4],tokeni_pet_mode!=0?SW_SHOW:SW_HIDE);
    ShowWindow(tokeni_pet_select,tokeni_pet_mode==0?SW_SHOW:SW_HIDE);
    ShowWindow(tokeni_pet_hatch,SW_HIDE);
    MoveWindow(tokeni_pet_select,right,top+row*2,rest/2-gap,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[3],right+rest/2,top+row*2,rest/2,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[1],right,top+row*3,rest/2-gap,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[2],right+rest/2,top+row*3,rest/2,row-6,TRUE);
    for(int i=1;i<=3;i++)ShowWindow(tokeni_pet_extra[i],tokeni_pet_mode==0?SW_SHOW:SW_HIDE);
    MoveWindow(tokeni_pet_extra[5],right,top+row*2,rest/2-gap,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[6],right+rest/2,top+row*2,rest/2,row-6,TRUE);
    ShowWindow(tokeni_pet_extra[5],tokeni_pet_mode!=0?SW_SHOW:SW_HIDE);
    ShowWindow(tokeni_pet_extra[6],tokeni_pet_mode!=0?SW_SHOW:SW_HIDE);
    MoveWindow(tokeni_pet_extra[7],right,top+row*3,rest,row-6,TRUE);
    ShowWindow(tokeni_pet_extra[7],tokeni_pet_mode==2?SW_SHOW:SW_HIDE);
    MoveWindow(tokeni_pet_extra[12],right,top+row*4,rest,row-6,TRUE);
    ShowWindow(tokeni_pet_extra[12],tokeni_pet_mode==0?SW_SHOW:SW_HIDE);
    int prefs=top+max(preview,row*5)+gap;
    MoveWindow(tokeni_service_buttons[2],left,prefs,width/2-gap,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[11],left+width/2,prefs,width/2,200,TRUE);
    MoveWindow(tokeni_pet_extra[9],left,prefs+row,width/2-gap,row-6,TRUE);
    MoveWindow(tokeni_pet_extra[10],left+width/2,prefs+row,width/2,row-6,TRUE);
    int detail=prefs+row*2;
    MoveWindow(tokeni_dashboard_details,left,detail,width,max(0,bottom-detail),TRUE);
}
static void tokeni_pet_extra_action(int id)
{
    char identifier[128]="",text[256]="";
    int code=id;
    if(id==552||id==553||id==562) {
        int selected=(int)SendMessageW(tokeni_pet_picker,CB_GETCURSEL,0,0);
        if(selected<0||selected>=tokeni_displayed_pet_count)return;
        lstrcpynA(identifier,tokeni_displayed_pets[selected].id,128);
        WCHAR name[64];GetWindowTextW(tokeni_pet_extra[1],name,64);
        WideCharToMultiByte(CP_UTF8,0,name,-1,text,256,NULL,NULL);
        if(id==562&&MessageBoxW(tokeni_dashboard_window,tokeni_text(L"Sell this companion? Active and last companions cannot be sold."),L"Tokeni Bar",MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2)!=IDYES)return;
    } else if(id==555||id==556) {
        int selected=(int)SendMessageW(tokeni_pet_extra[4],CB_GETCURSEL,0,0);
        if(selected<0)return;
        if(selected<512)lstrcpynA(identifier,tokeni_displayed_inventory_ids[selected],128);
        code=tokeni_pet_mode==1?(id==555?570:571):(id==555?572:573);
        if(code==571&&MessageBoxW(tokeni_dashboard_window,tokeni_text(L"Sell the selected egg?"),L"Tokeni Bar",MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2)!=IDYES)return;
    }
    AcquireSRWLockExclusive(&tokeni_state_lock);
    // Only one outstanding mutation; repeated clicks cannot duplicate a purchase.
    if(!tokeni_action_code) { tokeni_action_code=code;lstrcpynA(tokeni_action_id,identifier,128);lstrcpynA(tokeni_action_text,text,256); }
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}
