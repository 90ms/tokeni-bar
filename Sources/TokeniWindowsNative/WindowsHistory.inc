// History contains verified observations, never differences or inferred spend.
#include <time.h>
#define TOKENI_HISTORY_LIMIT 50000
typedef struct { double timestamp, percent; WCHAR provider[128], date[80], quota[256], tokens[40], cost[40]; } tokeni_history_row;
static tokeni_history_row tokeni_history[TOKENI_HISTORY_LIMIT], tokeni_history_staged[TOKENI_HISTORY_LIMIT];
static int tokeni_history_count, tokeni_history_staged_count;
static HWND tokeni_history_mode, tokeni_history_range, tokeni_history_provider, tokeni_history_table, tokeni_history_chart;
static int tokeni_history_visible;
static int tokeni_copy_utf8(const char *, WCHAR *, int);
static void tokeni_history_sync(void);
static void tokeni_history_commit_ui(void *unused) { (void)unused; tokeni_history_sync(); }
void tokeni_windows_history_begin(void) { tokeni_history_staged_count = 0; }
void tokeni_windows_history_append(double timestamp, double percent, const char *provider, const char *date, const char *quota, const char *tokens, const char *cost)
{
    if (tokeni_history_staged_count >= TOKENI_HISTORY_LIMIT) { return; }
    tokeni_history_row *row = &tokeni_history_staged[tokeni_history_staged_count++];
    row->timestamp = timestamp; row->percent = percent;
    tokeni_copy_utf8(provider, row->provider, 128); tokeni_copy_utf8(date, row->date, 80);
    tokeni_copy_utf8(quota, row->quota, 256); tokeni_copy_utf8(tokens, row->tokens, 40); tokeni_copy_utf8(cost, row->cost, 40);
}
void tokeni_windows_history_commit(void)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_history_count = tokeni_history_staged_count;
    CopyMemory(tokeni_history, tokeni_history_staged, sizeof(tokeni_history_row) * tokeni_history_count);
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    tokeni_windows_ui_invoke(tokeni_history_commit_ui, NULL);
}
static double tokeni_history_cutoff(void)
{
    int range = (int)SendMessageW(tokeni_history_range, CB_GETCURSEL, 0, 0);
    return (double)time(NULL) - (range == 0 ? 1 : range == 1 ? 7 : 30) * 86400.0;
}
static int tokeni_history_matches(tokeni_history_row *row, double cutoff, const WCHAR *provider, int all)
{ return row->timestamp >= cutoff && (all || !wcscmp(provider, row->provider)); }
static void tokeni_history_sync(void)
{
    if (!tokeni_history_table) { return; }
    WCHAR provider[128] = L"";
    GetWindowTextW(tokeni_history_provider, provider, 128);
    int all = SendMessageW(tokeni_history_provider, CB_GETCURSEL, 0, 0) <= 0;
    SendMessageW(tokeni_history_provider, CB_RESETCONTENT, 0, 0);
    SendMessageW(tokeni_history_provider, CB_ADDSTRING, 0, (LPARAM)tokeni_text(L"All providers"));
    AcquireSRWLockShared(&tokeni_state_lock);
    for (int i = 0; i < tokeni_history_count; i++) {
        if (SendMessageW(tokeni_history_provider, CB_FINDSTRINGEXACT, -1, (LPARAM)tokeni_history[i].provider) == CB_ERR) {
            SendMessageW(tokeni_history_provider, CB_ADDSTRING, 0, (LPARAM)tokeni_history[i].provider);
        }
    }
    LRESULT selected = all ? 0 : SendMessageW(tokeni_history_provider, CB_FINDSTRINGEXACT, -1, (LPARAM)provider);
    if (selected == CB_ERR) { all = 1; selected = 0; }
    SendMessageW(tokeni_history_provider, CB_SETCURSEL, selected, 0);
    SendMessageW(tokeni_history_table, WM_SETREDRAW, FALSE, 0);
    ListView_DeleteAllItems(tokeni_history_table);
    double cutoff = tokeni_history_cutoff();
    int displayed = 0;
    for (int i = tokeni_history_count - 1; i >= 0; i--) {
        tokeni_history_row *row = &tokeni_history[i];
        if (!tokeni_history_matches(row, cutoff, provider, all)) { continue; }
        WCHAR *cells[] = {row->date, row->provider, row->quota, row->tokens, row->cost};
        LVITEMW item = {0}; item.mask = LVIF_TEXT; item.iItem = displayed; item.pszText = cells[0];
        SendMessageW(tokeni_history_table, LVM_INSERTITEMW, 0, (LPARAM)&item);
        for (int col = 1; col < 5; col++) {
            item.iSubItem = col; item.pszText = cells[col];
            SendMessageW(tokeni_history_table, LVM_SETITEMTEXTW, displayed, (LPARAM)&item);
        }
        displayed++;
    }
    ReleaseSRWLockShared(&tokeni_state_lock);
    SendMessageW(tokeni_history_table, WM_SETREDRAW, TRUE, 0);
    ListView_SetBkColor(tokeni_history_table, tokeni_surface);
    ListView_SetTextBkColor(tokeni_history_table, tokeni_surface);
    ListView_SetTextColor(tokeni_history_table, tokeni_foreground);
    InvalidateRect(tokeni_history_table, NULL, TRUE); InvalidateRect(tokeni_history_chart, NULL, TRUE);
}
static void tokeni_history_create(HWND window)
{
    tokeni_history_mode = CreateWindowExW(0, L"BUTTON", L"History", WS_CHILD | WS_TABSTOP | BS_AUTOCHECKBOX, 0,0,0,0,window,(HMENU)540,tokeni_instance,NULL);
    tokeni_history_range = CreateWindowExW(0,L"COMBOBOX",L"",WS_CHILD|WS_TABSTOP|CBS_DROPDOWNLIST,0,0,0,0,window,(HMENU)541,tokeni_instance,NULL);
    tokeni_history_provider = CreateWindowExW(0,L"COMBOBOX",L"",WS_CHILD|WS_TABSTOP|CBS_DROPDOWNLIST,0,0,0,0,window,(HMENU)542,tokeni_instance,NULL);
    const WCHAR *ranges[] = {L"Last 24 hours",L"Last 7 days",L"Last 30 days"};
    for(int i=0;i<3;i++) SendMessageW(tokeni_history_range,CB_ADDSTRING,0,(LPARAM)tokeni_text(ranges[i]));
    SendMessageW(tokeni_history_range,CB_SETCURSEL,1,0);
    tokeni_history_chart = CreateWindowExW(0,L"STATIC",L"Quota remaining (%)",WS_CHILD|SS_OWNERDRAW,0,0,0,0,window,(HMENU)543,tokeni_instance,NULL);
    tokeni_history_table = CreateWindowExW(WS_EX_CLIENTEDGE,WC_LISTVIEWW,L"History",WS_CHILD|WS_TABSTOP|LVS_REPORT|LVS_SINGLESEL,0,0,0,0,window,(HMENU)544,tokeni_instance,NULL);
    ListView_SetExtendedListViewStyle(tokeni_history_table,LVS_EX_FULLROWSELECT|LVS_EX_DOUBLEBUFFER);
    const WCHAR *columns[]={L"Collected at",L"Provider",L"Quota remaining (%)",L"Tokens",L"Cost (USD)"};
    for(int i=0;i<5;i++) { LVCOLUMNW col={0};col.mask=LVCF_TEXT|LVCF_WIDTH;col.pszText=(WCHAR *)tokeni_text(columns[i]);col.cx=i==2?240:140;SendMessageW(tokeni_history_table,LVM_INSERTCOLUMNW,i,(LPARAM)&col); }
    tokeni_history_sync();
}
static void tokeni_history_layout(int left,int top,int width,int bottom,int gap,UINT dpi)
{
    int visible=tokeni_destination==1;
    ShowWindow(tokeni_history_mode,visible?SW_SHOW:SW_HIDE);
    MoveWindow(tokeni_history_mode,left+width-100,top-30,100,28,TRUE);
    HWND controls[]={tokeni_history_range,tokeni_history_provider,tokeni_history_chart,tokeni_history_table};
    for(int i=0;i<4;i++) ShowWindow(controls[i],visible&&tokeni_history_visible?SW_SHOW:SW_HIDE);
    if(!visible||!tokeni_history_visible) return;
    ShowWindow(tokeni_usage_list,SW_HIDE);ShowWindow(tokeni_dashboard_details,SW_HIDE);
    int row=MulDiv(36,dpi,96),chart=MulDiv(150,dpi,96);
    MoveWindow(tokeni_history_range,left,top,width/2-gap,200,TRUE);
    MoveWindow(tokeni_history_provider,left+width/2,top,width/2,200,TRUE);
    MoveWindow(tokeni_history_chart,left,top+row,width,chart,TRUE);
    MoveWindow(tokeni_history_table,left,top+row+chart+gap,width,max(0,bottom-top-row-chart-gap),TRUE);
}
static LRESULT tokeni_history_draw(DRAWITEMSTRUCT *item)
{
    HDC dc=item->hDC; RECT box=item->rcItem;FillRect(dc,&box,tokeni_surface_brush);
    SetBkMode(dc,TRANSPARENT);SetTextColor(dc,tokeni_foreground);
    RECT label=box;label.left+=12;label.top+=6;DrawTextW(dc,tokeni_text(L"Quota remaining (%)"),-1,&label,DT_TOP|DT_SINGLELINE);
    WCHAR provider[128];GetWindowTextW(tokeni_history_provider,provider,128);
    int all=SendMessageW(tokeni_history_provider,CB_GETCURSEL,0,0)<=0,count=0;
    double cutoff=tokeni_history_cutoff(),span=(double)time(NULL)-cutoff;
    // Each dot is one provider's minimum observed quota. Never join different providers.
    HBRUSH dot=CreateSolidBrush(tokeni_accent);HGDIOBJ old=SelectObject(dc,dot);
    AcquireSRWLockShared(&tokeni_state_lock);
    for(int i=0;i<tokeni_history_count;i++) {
        tokeni_history_row *r=&tokeni_history[i];
        if(r->percent<0||r->percent>100||!tokeni_history_matches(r,cutoff,provider,all))continue;
        int x=12+(int)((r->timestamp-cutoff)/span*(box.right-24));
        int y=34+(int)((100-r->percent)/100*(box.bottom-48));
        Ellipse(dc,x-2,y-2,x+3,y+3);count++;
    }
    ReleaseSRWLockShared(&tokeni_state_lock);SelectObject(dc,old);DeleteObject(dot);
    if(!count) DrawTextW(dc,tokeni_text(L"No history in this period"),-1,&box,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
    return TRUE;
}
