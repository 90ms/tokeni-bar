#pragma comment(lib,"msimg32.lib")
static int tokeni_overlay_persist;
static LONG tokeni_overlay_preference_bits=4; // medium, locked, animation enabled
static void tokeni_overlay_save_preferences(void)
{
    if(!tokeni_overlay_persist||!tokeni_overlay_window)return;
    HKEY key;
    if(RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\TokeniBar\\Desktop",0,NULL,0,KEY_SET_VALUE,NULL,&key,NULL)==ERROR_SUCCESS) {
        RECT frame;GetWindowRect(tokeni_overlay_window,&frame);
        DWORD bits=(DWORD)tokeni_overlay_preference_bits;
        RegSetValueExW(key,L"OverlayPreferences",0,REG_DWORD,(BYTE *)&bits,sizeof(bits));
        RegSetValueExW(key,L"OverlayFrame",0,REG_BINARY,(BYTE *)&frame,sizeof(frame));
        RegCloseKey(key);
    }
}
typedef struct { int movable,reduced,size; } tokeni_overlay_preferences_request;
static void tokeni_overlay_configure_ui(void *context)
{
    tokeni_overlay_preferences_request *request=context;
    int size=max(0,min(2,request->size));
    InterlockedExchange(&tokeni_overlay_preference_bits,(request->movable?1:0)|(request->reduced?2:0)|(size<<2));
    tokeni_overlay_reduced_motion=request->reduced;
    tokeni_windows_overlay_set_click_through(!request->movable);
    if(tokeni_overlay_window) {
        RECT frame;GetWindowRect(tokeni_overlay_window,&frame);
        int dimension=size==0?140:size==1?220:320;
        tokeni_windows_overlay_set_frame(frame.left,frame.top,dimension,dimension);
        InvalidateRect(tokeni_overlay_window,NULL,FALSE);
    }
    tokeni_overlay_save_preferences();
}
void tokeni_windows_overlay_configure(int movable,int reduced,int size)
{
    tokeni_overlay_preferences_request request={movable,reduced,size};
    tokeni_windows_ui_invoke(tokeni_overlay_configure_ui,&request);
}
int tokeni_windows_overlay_preferences(void) { return (int)InterlockedCompareExchange(&tokeni_overlay_preference_bits,0,0); }
static void tokeni_overlay_restore_ui(void *unused)
{
    (void)unused;DWORD bits=4,size=sizeof(bits);RECT frame;DWORD frame_size=sizeof(frame);
    RegGetValueW(HKEY_CURRENT_USER,L"Software\\TokeniBar\\Desktop",L"OverlayPreferences",RRF_RT_REG_DWORD,NULL,&bits,&size);
    if(bits>11)bits=4;
    if(RegGetValueW(HKEY_CURRENT_USER,L"Software\\TokeniBar\\Desktop",L"OverlayFrame",RRF_RT_REG_BINARY,NULL,&frame,&frame_size)==ERROR_SUCCESS&&frame_size==sizeof(frame)) {
        tokeni_windows_overlay_set_frame(frame.left,frame.top,220,220);
    }
    tokeni_overlay_preferences_request request={(bits&1)!=0,(bits&2)!=0,(int)(bits>>2)};
    tokeni_overlay_configure_ui(&request);tokeni_overlay_persist=1;
}
void tokeni_windows_overlay_restore_preferences(void) { tokeni_windows_ui_invoke(tokeni_overlay_restore_ui,NULL); }

// Called only by owner drawing on the same thread as WIC and the overlay.
void tokeni_windows_overlay_draw_preview(void *context,int width,int height)
{
    if(width<=0||height<=0)return;
    HDC target=context,memory=CreateCompatibleDC(target);
    HBITMAP bitmap=CreateCompatibleBitmap(target,width,height);HGDIOBJ old=SelectObject(memory,bitmap);
    RECT bounds={0,0,width,height};FillRect(memory,&bounds,(HBRUSH)GetStockObject(BLACK_BRUSH));
    tokeni_overlay_decorations(memory,&bounds,0);
    if(!tokeni_overlay_paint_asset(memory,&bounds))tokeni_overlay_paint_fallback(memory,&bounds);
    tokeni_overlay_decorations(memory,&bounds,1);
    TransparentBlt(target,0,0,width,height,memory,0,0,width,height,RGB(0,0,0));
    SelectObject(memory,old);DeleteObject(bitmap);DeleteDC(memory);
}
