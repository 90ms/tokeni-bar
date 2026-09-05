#include "TokeniWindowsNative.h"
#include "TokeniWindowsProviderState.h"

#ifdef _WIN32

#include <windows.h>
#include <shellapi.h>
#include <wchar.h>
#include <string.h>
#include <commctrl.h>
#pragma comment(lib, "comctl32.lib")

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(linker, "/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

#ifndef TOKENI_DESKTOP_NAMESPACE
#define TOKENI_DESKTOP_NAMESPACE L"TokeniBar"
#endif
static const wchar_t tokeni_window_class_name[] = TOKENI_DESKTOP_NAMESPACE L"TrayWindow";
static const wchar_t tokeni_dashboard_class_name[] = TOKENI_DESKTOP_NAMESPACE L"DashboardWindow";
static const UINT tokeni_tray_callback_message = WM_APP + 37;
static const UINT tokeni_details_updated_message = WM_APP + 38;
static const UINT tokeni_provider_options_updated_message = WM_APP + 39;
static const UINT tokeni_open_window_message = WM_APP + 40;
static HANDLE tokeni_instance_mutex;
static HANDLE tokeni_ui_thread;
static DWORD tokeni_ui_thread_id;
static const UINT tokeni_invoke_message = WM_APP + 41;
typedef struct { void (*operation)(void *); void *context; } tokeni_ui_invocation;
static HWND tokeni_navigation[4];
static int tokeni_destination;
static const WCHAR *tokeni_page_titles[] = { L"Home", L"Usage", L"Companions", L"Settings" };
static const WCHAR *tokeni_page_subtitles[] = {
    L"Your usage and companion at a glance",
    L"Verified usage from your connected providers",
    L"Grow together with your everyday work",
    L"Make Tokeni Bar work your way"
};
static const UINT tokeni_tray_identifier = 1;
static UINT tokeni_taskbar_created_message;
static const int tokeni_refresh_button_identifier = 101;
static const int tokeni_hide_button_identifier = 102;
static const int tokeni_provider_button_identifier_base = 200;
#define TOKENI_MAX_PROVIDERS TOKENI_WINDOWS_PROVIDER_MAX_COUNT
#define TOKENI_PROVIDER_ID_CAPACITY TOKENI_WINDOWS_PROVIDER_ID_CAPACITY
#define TOKENI_PROVIDER_NAME_MAX_CODE_POINTS 80
#define TOKENI_PROVIDER_NAME_CAPACITY 161

typedef struct tokeni_provider_option {
    char provider_id[TOKENI_PROVIDER_ID_CAPACITY];
    WCHAR display_name[TOKENI_PROVIDER_NAME_CAPACITY];
    int enabled;
} tokeni_provider_option;

static HWND tokeni_window;
static HWND tokeni_dashboard_window;
static HWND tokeni_dashboard_header;
static HWND tokeni_dashboard_status;
static HWND tokeni_dashboard_provider_label;
static HWND tokeni_dashboard_provider_buttons[TOKENI_MAX_PROVIDERS];
static char tokeni_dashboard_provider_ids
    [TOKENI_MAX_PROVIDERS][TOKENI_PROVIDER_ID_CAPACITY];
static int tokeni_dashboard_provider_count;
static HWND tokeni_dashboard_details;
static HWND tokeni_dashboard_refresh_button;
static HWND tokeni_dashboard_hide_button;
static HINSTANCE tokeni_instance;
static NOTIFYICONDATAW tokeni_icon;
static int tokeni_class_registered;
static int tokeni_dashboard_class_registered;
static HFONT tokeni_dashboard_font;
static HFONT tokeni_dashboard_header_font;
static LONG tokeni_refresh_requested;
static LONG tokeni_launch_at_login_enabled;
static LONG tokeni_launch_at_login_requested;
static LONG tokeni_test_notification_requested;
static LONG tokeni_companion_enabled;
static LONG tokeni_companion_toggle_requested;
static WCHAR tokeni_details[8192];
static tokeni_provider_option tokeni_provider_options[TOKENI_MAX_PROVIDERS];
static int tokeni_provider_option_count;
static tokeni_provider_option tokeni_staged_provider_options
    [TOKENI_MAX_PROVIDERS];
static tokeni_windows_provider_state tokeni_provider_toggle_state;
static int tokeni_staged_provider_option_count;
static int tokeni_provider_transaction_active;
static SRWLOCK tokeni_state_lock = SRWLOCK_INIT;
static HWND tokeni_usage_list;
typedef struct { WCHAR cells[6][256]; } tokeni_usage_row;
static tokeni_usage_row tokeni_usage_rows[TOKENI_MAX_PROVIDERS];
static tokeni_usage_row tokeni_usage_staged[TOKENI_MAX_PROVIDERS];
static int tokeni_usage_count, tokeni_usage_staged_count;
static WCHAR tokeni_home_summary[4096];
static WCHAR tokeni_refresh_status[256];
static int tokeni_is_refreshing;
static HWND tokeni_service_buttons[4];
static HWND tokeni_pet_picker;
static HWND tokeni_pet_select;
static HWND tokeni_pet_hatch;
static LONG tokeni_hatch_requested;
static WCHAR tokeni_pet_summary[4096];
static WCHAR tokeni_service_feedback[512];
typedef struct { char id[64]; WCHAR label[256]; int selected; } tokeni_pet_option;
static tokeni_pet_option tokeni_pets[128], tokeni_staged_pets[128];
static int tokeni_pet_count, tokeni_staged_pet_count;
static int tokeni_egg_count;
static char tokeni_selected_pet_request[64];
static unsigned int tokeni_pet_revision, tokeni_displayed_pet_revision;
static tokeni_pet_option tokeni_displayed_pets[128];
static int tokeni_displayed_pet_count;

#include "WindowsDesktopStyle.inc"
#include "WindowsHistory.inc"
#include "WindowsCompanionControls.inc"
#include "WindowsUpdates.inc"

static void tokeni_localize_picker(HWND picker,const WCHAR **labels,int count)
{
    LRESULT selected=SendMessageW(picker,CB_GETCURSEL,0,0);
    SendMessageW(picker,CB_RESETCONTENT,0,0);
    for(int i=0;i<count;i++)SendMessageW(picker,CB_ADDSTRING,0,(LPARAM)tokeni_text(labels[i]));
    SendMessageW(picker,CB_SETCURSEL,selected,0);
}
static void tokeni_localize_controls(void)
{
    const WCHAR *languages[]={L"System language",L"English",L"한국어"};
    const WCHAR *themes[]={L"System theme",L"Light",L"Dark"};
    const WCHAR *ranges[]={L"Last 24 hours",L"Last 7 days",L"Last 30 days"};
    const WCHAR *modes[]={L"Collection",L"Eggs",L"Shop & rewards"};
    const WCHAR *sizes[]={L"Small",L"Medium",L"Large"};
    tokeni_localize_picker(tokeni_language_picker,languages,3);tokeni_localize_picker(tokeni_theme_picker,themes,3);
    tokeni_localize_picker(tokeni_history_range,ranges,3);tokeni_localize_picker(tokeni_pet_extra[0],modes,3);tokeni_localize_picker(tokeni_pet_extra[11],sizes,3);
    const WCHAR *columns[]={L"Collected at",L"Provider",L"Quota remaining (%)",L"Tokens",L"Cost (USD)"};
    for(int i=0;i<5;i++) {LVCOLUMNW col={0};col.mask=LVCF_TEXT;col.pszText=(WCHAR *)tokeni_text(columns[i]);SendMessageW(tokeni_history_table,LVM_SETCOLUMNW,i,(LPARAM)&col);}
    tokeni_history_sync();
}

static void tokeni_dashboard_sync_services(void)
{
    int preferences=tokeni_windows_overlay_preferences();
    SendMessageW(tokeni_pet_extra[9],BM_SETCHECK,(preferences&1)?BST_CHECKED:BST_UNCHECKED,0);
    SendMessageW(tokeni_pet_extra[10],BM_SETCHECK,(preferences&2)?BST_CHECKED:BST_UNCHECKED,0);
    SendMessageW(tokeni_pet_extra[11],CB_SETCURSEL,preferences>>2,0);
    SetWindowTextW(tokeni_service_buttons[0], InterlockedCompareExchange(&tokeni_launch_at_login_enabled, 0, 0)
        ? L"Start with Windows: On" : L"Start with Windows: Off");
    SetWindowTextW(tokeni_service_buttons[2], InterlockedCompareExchange(&tokeni_companion_enabled, 0, 0)
        ? L"Desktop companion: On" : L"Desktop companion: Off");
    AcquireSRWLockShared(&tokeni_state_lock);
    if (tokeni_displayed_pet_revision != tokeni_pet_revision) {
        // Do not rebuild the dropdown while the user is choosing an item.
        if (!SendMessageW(tokeni_pet_picker, CB_GETDROPPEDSTATE, 0, 0)) {
            char selected_id[64] = {0};
            int previous = (int)SendMessageW(tokeni_pet_picker, CB_GETCURSEL, 0, 0);
            if (previous >= 0 && previous < tokeni_displayed_pet_count) {
                lstrcpynA(selected_id, tokeni_displayed_pets[previous].id, 64);
            }
            SendMessageW(tokeni_pet_picker, CB_RESETCONTENT, 0, 0);
            tokeni_displayed_pet_count = tokeni_pet_count;
            CopyMemory(tokeni_displayed_pets, tokeni_pets, sizeof(tokeni_pets));
            int selection = 0;
            for (int index = 0; index < tokeni_pet_count; index++) {
                SendMessageW(tokeni_pet_picker, CB_ADDSTRING, 0, (LPARAM)tokeni_pets[index].label);
                if ((selected_id[0] && lstrcmpA(selected_id, tokeni_pets[index].id) == 0)
                    || (!selected_id[0] && tokeni_pets[index].selected)) { selection = index; }
            }
            SendMessageW(tokeni_pet_picker, CB_SETCURSEL, selection, 0);
            tokeni_displayed_pet_revision = tokeni_pet_revision;
        }
    }
    EnableWindow(tokeni_pet_select, tokeni_pet_count > 0);
    EnableWindow(tokeni_pet_hatch, tokeni_egg_count > 0);
    ReleaseSRWLockShared(&tokeni_state_lock);
}
static int tokeni_copy_utf8(const char *source, WCHAR *destination, int count);

static void tokeni_desktop_ready_ui(void *context)
{
    int *ready=context;WCHAR displayed[8192];GetWindowTextW(tokeni_dashboard_details,displayed,8192);
    AcquireSRWLockShared(&tokeni_state_lock);
    *ready=tokeni_home_summary[0] && tokeni_pet_summary[0] && wcsstr(displayed,tokeni_home_summary)!=NULL;
    ReleaseSRWLockShared(&tokeni_state_lock);
}
int tokeni_windows_desktop_ready(void)
{
    int ready=0;tokeni_windows_ui_invoke(tokeni_desktop_ready_ui,&ready);return ready;
}

static void tokeni_dashboard_save_frame(HWND window)
{
#ifndef TOKENI_DESKTOP_TEST
    if (IsIconic(window) || IsZoomed(window)) { return; }
    RECT frame;
    if (!GetWindowRect(window, &frame)) { return; }
    HKEY key;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\TokeniBar\\Desktop", 0,
            NULL, 0, KEY_SET_VALUE, NULL, &key, NULL) == ERROR_SUCCESS) {
        RegSetValueExW(key, L"Frame", 0, REG_BINARY, (const BYTE *)&frame, sizeof(frame));
        RegCloseKey(key);
    }
#else
    (void)window;
#endif
}

static void tokeni_dashboard_restore_frame(HWND window)
{
#ifndef TOKENI_DESKTOP_TEST
    RECT frame;
    DWORD size = sizeof(frame);
    if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\TokeniBar\\Desktop", L"Frame",
            RRF_RT_REG_BINARY, NULL, &frame, &size) != ERROR_SUCCESS || size != sizeof(frame)) { return; }
    if (frame.right <= frame.left || frame.bottom <= frame.top) { return; }
    MONITORINFO monitor = {sizeof(monitor)};
    if (!GetMonitorInfoW(MonitorFromRect(&frame, MONITOR_DEFAULTTONEAREST), &monitor)) { return; }
    // Clamp all persisted values before doing arithmetic or moving a window.
    int work_width = monitor.rcWork.right - monitor.rcWork.left;
    int work_height = monitor.rcWork.bottom - monitor.rcWork.top;
    LONG64 saved_width = (LONG64)frame.right - frame.left;
    LONG64 saved_height = (LONG64)frame.bottom - frame.top;
    int width = (int)min(max(saved_width, 720), work_width);
    int height = (int)min(max(saved_height, 520), work_height);
    int x = max(monitor.rcWork.left, min(frame.left, monitor.rcWork.right - width));
    int y = max(monitor.rcWork.top, min(frame.top, monitor.rcWork.bottom - height));
    SetWindowPos(window, NULL, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
#else
    (void)window;
#endif
}

static void tokeni_dashboard_sync_usage(void)
{
    tokeni_usage_row rows[TOKENI_MAX_PROVIDERS];
    WCHAR status[256];
    int count, refreshing;
    AcquireSRWLockShared(&tokeni_state_lock);
    CopyMemory(rows, tokeni_usage_rows, sizeof(rows));
    CopyMemory(status, tokeni_refresh_status, sizeof(status));
    count = tokeni_usage_count;
    refreshing = tokeni_is_refreshing;
    ReleaseSRWLockShared(&tokeni_state_lock);
    SendMessageW(tokeni_usage_list, WM_SETREDRAW, FALSE, 0);
    // Update in place so selection, keyboard focus, and scroll position survive refreshes.
    while (ListView_GetItemCount(tokeni_usage_list) > count) {
        ListView_DeleteItem(tokeni_usage_list, ListView_GetItemCount(tokeni_usage_list) - 1);
    }
    for (int row = 0; row < count; row++) {
        LVITEMW item = {0};
        item.mask = LVIF_TEXT;
        item.iItem = row;
        item.pszText = rows[row].cells[0];
        if (row >= ListView_GetItemCount(tokeni_usage_list)) {
            SendMessageW(tokeni_usage_list, LVM_INSERTITEMW, 0, (LPARAM)&item);
        }
        for (int column = 0; column < 6; column++) {
            item.iSubItem = column;
            item.pszText = rows[row].cells[column];
            SendMessageW(tokeni_usage_list, LVM_SETITEMTEXTW, row, (LPARAM)&item);
        }
    }
    SendMessageW(tokeni_usage_list, WM_SETREDRAW, TRUE, 0);
    InvalidateRect(tokeni_usage_list, NULL, TRUE);
    EnableWindow(tokeni_dashboard_refresh_button, !refreshing);
    SetWindowTextW(tokeni_dashboard_refresh_button, refreshing ? L"Refreshing…" : L"Refresh now");
    SetWindowTextW(tokeni_dashboard_status,
        status[0] && tokeni_destination < 2 ? status : tokeni_page_subtitles[tokeni_destination]);
}

static void tokeni_enable_per_monitor_dpi_awareness(void)
{
    typedef BOOL(WINAPI *set_dpi_awareness_context_fn)(HANDLE);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32 == NULL) {
        return;
    }

    set_dpi_awareness_context_fn set_awareness =
        (set_dpi_awareness_context_fn)GetProcAddress(
            user32,
            "SetProcessDpiAwarenessContext");
    if (set_awareness != NULL) {
        // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 is the documented -4
        // pseudo-handle. A manifest or an earlier host call may already have
        // selected awareness, in which case this safely has no effect.
        set_awareness((HANDLE)(INT_PTR)-4);
    }
}

static UINT tokeni_dashboard_dpi(HWND window)
{
    typedef UINT(WINAPI *get_dpi_for_window_fn)(HWND);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32 != NULL) {
        get_dpi_for_window_fn get_dpi =
            (get_dpi_for_window_fn)GetProcAddress(user32, "GetDpiForWindow");
        if (get_dpi != NULL) {
            UINT dpi = get_dpi(window);
            if (dpi != 0) {
                return dpi;
            }
        }
    }
    return 96;
}

static int tokeni_scale_for_dpi(int value, UINT dpi)
{
    return MulDiv(value, (int)dpi, 96);
}

static int tokeni_copy_provider_id(
    const char *source,
    char destination[TOKENI_PROVIDER_ID_CAPACITY])
{
    if (source == NULL || source[0] == '\0') {
        return 0;
    }
    int index = 0;
    while (source[index] != '\0') {
        unsigned char value = (unsigned char)source[index];
        if (index >= TOKENI_PROVIDER_ID_CAPACITY - 1
            || value < 0x20
            || value == 0x7f)
        {
            destination[0] = '\0';
            return 0;
        }
        destination[index] = source[index];
        index += 1;
    }
    destination[index] = '\0';
    return 1;
}

static int tokeni_copy_provider_name(
    const char *source,
    const char *fallback_provider_id,
    WCHAR destination[TOKENI_PROVIDER_NAME_CAPACITY])
{
    WCHAR converted[TOKENI_PROVIDER_NAME_CAPACITY];
    if (source == NULL
        || MultiByteToWideChar(
            CP_UTF8,
            MB_ERR_INVALID_CHARS,
            source,
            -1,
            converted,
            (int)(sizeof(converted) / sizeof(converted[0]))) == 0)
    {
        destination[0] = L'\0';
        return 0;
    }

    int output_index = 0;
    int output_code_points = 0;
    for (int input_index = 0;
         converted[input_index] != L'\0'
            && output_code_points < TOKENI_PROVIDER_NAME_MAX_CODE_POINTS;
         input_index += 1)
    {
        WORD character_type = 0;
        if (GetStringTypeW(
                CT_CTYPE1,
                &converted[input_index],
                1,
                &character_type)
            && (character_type & C1_CNTRL) != 0)
        {
            continue;
        }
        int is_surrogate_pair = converted[input_index] >= 0xd800
            && converted[input_index] <= 0xdbff
            && converted[input_index + 1] >= 0xdc00
            && converted[input_index + 1] <= 0xdfff;
        if (output_index + (is_surrogate_pair ? 2 : 1)
            >= TOKENI_PROVIDER_NAME_CAPACITY)
        {
            break;
        }
        destination[output_index] = converted[input_index];
        output_index += 1;
        if (is_surrogate_pair) {
            destination[output_index] = converted[input_index + 1];
            output_index += 1;
            input_index += 1;
        }
        output_code_points += 1;
    }
    destination[output_index] = L'\0';

    if (output_index == 0) {
        return MultiByteToWideChar(
            CP_UTF8,
            MB_ERR_INVALID_CHARS,
            fallback_provider_id,
            -1,
            destination,
            TOKENI_PROVIDER_NAME_CAPACITY) != 0;
    }
    return 1;
}

static void tokeni_dashboard_set_initial_frame(
    HWND window,
    const MONITORINFO *monitor)
{
    typedef BOOL(WINAPI *adjust_window_rect_for_dpi_fn)(
        LPRECT,
        DWORD,
        BOOL,
        DWORD,
        UINT);

    UINT dpi = tokeni_dashboard_dpi(window);
    DWORD style = (DWORD)GetWindowLongW(window, GWL_STYLE);
    DWORD extended_style = (DWORD)GetWindowLongW(window, GWL_EXSTYLE);
    RECT frame = {
        0,
        0,
        tokeni_scale_for_dpi(960, dpi),
        tokeni_scale_for_dpi(640, dpi),
    };

    adjust_window_rect_for_dpi_fn adjust_for_dpi = NULL;
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32 != NULL) {
        adjust_for_dpi = (adjust_window_rect_for_dpi_fn)GetProcAddress(
            user32,
            "AdjustWindowRectExForDpi");
    }
    if (adjust_for_dpi != NULL) {
        adjust_for_dpi(
            &frame,
            style,
            GetMenu(window) != NULL,
            extended_style,
            dpi);
    } else {
        AdjustWindowRectEx(
            &frame,
            style,
            GetMenu(window) != NULL,
            extended_style);
    }

    int width = frame.right - frame.left;
    int height = frame.bottom - frame.top;
    int work_width = monitor->rcWork.right - monitor->rcWork.left;
    int work_height = monitor->rcWork.bottom - monitor->rcWork.top;
    width = min(width, work_width);
    height = min(height, work_height);
    int x = monitor->rcWork.left + ((work_width - width) / 2);
    int y = monitor->rcWork.top + ((work_height - height) / 2);

    SetWindowPos(
        window,
        NULL,
        x,
        y,
        width,
        height,
        SWP_NOACTIVATE | SWP_NOZORDER);
}

static void tokeni_dashboard_destroy_provider_controls(void)
{
    for (int index = 0;
         index < tokeni_dashboard_provider_count;
         index += 1)
    {
        if (tokeni_dashboard_provider_buttons[index] != NULL) {
            DestroyWindow(tokeni_dashboard_provider_buttons[index]);
            tokeni_dashboard_provider_buttons[index] = NULL;
        }
        tokeni_dashboard_provider_ids[index][0] = '\0';
    }
    tokeni_dashboard_provider_count = 0;
}

static void tokeni_dashboard_sync_provider_controls(HWND window)
{
    tokeni_provider_option snapshot[TOKENI_MAX_PROVIDERS];
    int snapshot_count;

    AcquireSRWLockShared(&tokeni_state_lock);
    snapshot_count = tokeni_provider_option_count;
    CopyMemory(
        snapshot,
        tokeni_provider_options,
        sizeof(tokeni_provider_options));
    ReleaseSRWLockShared(&tokeni_state_lock);

    int must_rebuild = snapshot_count != tokeni_dashboard_provider_count;
    if (!must_rebuild) {
        for (int index = 0; index < snapshot_count; index += 1) {
            if (lstrcmpA(
                    snapshot[index].provider_id,
                    tokeni_dashboard_provider_ids[index]) != 0)
            {
                must_rebuild = 1;
                break;
            }
        }
    }

    if (must_rebuild) {
        tokeni_dashboard_destroy_provider_controls();
        HWND insert_after = tokeni_dashboard_provider_label;
        for (int index = 0; index < snapshot_count; index += 1) {
            HWND button = CreateWindowExW(
                0,
                L"BUTTON",
                snapshot[index].display_name,
                WS_CHILD | WS_VISIBLE | WS_TABSTOP
                    | BS_AUTOCHECKBOX | BS_NOTIFY,
                0,
                0,
                0,
                0,
                window,
                (HMENU)(INT_PTR)(
                    tokeni_provider_button_identifier_base + index),
                tokeni_instance,
                NULL);
            if (button == NULL) {
                tokeni_dashboard_destroy_provider_controls();
                break;
            }
            tokeni_dashboard_provider_buttons[index] = button;
            tokeni_copy_provider_id(
                snapshot[index].provider_id,
                tokeni_dashboard_provider_ids[index]);
            tokeni_dashboard_provider_count += 1;
            SetWindowPos(
                button,
                insert_after,
                0,
                0,
                0,
                0,
                SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
            insert_after = button;
        }
    }

    for (int index = 0;
         index < tokeni_dashboard_provider_count;
         index += 1)
    {
        SetWindowTextW(
            tokeni_dashboard_provider_buttons[index],
            snapshot[index].display_name);
        SendMessageW(
            tokeni_dashboard_provider_buttons[index],
            BM_SETCHECK,
            snapshot[index].enabled ? BST_CHECKED : BST_UNCHECKED,
            0);
        if (tokeni_dashboard_font != NULL) {
            SendMessageW(
                tokeni_dashboard_provider_buttons[index],
                WM_SETFONT,
                (WPARAM)tokeni_dashboard_font,
                TRUE);
        }
    }
    ShowWindow(
        tokeni_dashboard_provider_label,
        snapshot_count > 0 ? SW_SHOW : SW_HIDE);
}

static void tokeni_dashboard_set_fonts(HWND window)
{
    UINT dpi = tokeni_dashboard_dpi(window);
    HFONT font = CreateFontW(
        -MulDiv(10, (int)dpi, 72),
        0,
        0,
        0,
        FW_NORMAL,
        FALSE,
        FALSE,
        FALSE,
        DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS,
        CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI");
    HFONT header_font = CreateFontW(
        -MulDiv(16, (int)dpi, 72),
        0,
        0,
        0,
        FW_SEMIBOLD,
        FALSE,
        FALSE,
        FALSE,
        DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS,
        CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI");

    if (font == NULL || header_font == NULL) {
        if (font != NULL) {
            DeleteObject(font);
        }
        if (header_font != NULL) {
            DeleteObject(header_font);
        }
        return;
    }

    SendMessageW(tokeni_dashboard_header, WM_SETFONT, (WPARAM)header_font, TRUE);
    SendMessageW(tokeni_dashboard_status, WM_SETFONT, (WPARAM)font, TRUE);
    SendMessageW(
        tokeni_dashboard_provider_label,
        WM_SETFONT,
        (WPARAM)font,
        TRUE);
    SendMessageW(tokeni_dashboard_details, WM_SETFONT, (WPARAM)font, TRUE);
    SendMessageW(
        tokeni_dashboard_refresh_button,
        WM_SETFONT,
        (WPARAM)font,
        TRUE);
    for (int index = 0;
         index < tokeni_dashboard_provider_count;
         index += 1)
    {
        SendMessageW(
            tokeni_dashboard_provider_buttons[index],
            WM_SETFONT,
            (WPARAM)font,
            TRUE);
    }
    SendMessageW(
        tokeni_dashboard_hide_button,
        WM_SETFONT,
        (WPARAM)font,
        TRUE);

    if (tokeni_dashboard_font != NULL) {
        DeleteObject(tokeni_dashboard_font);
    }
    if (tokeni_dashboard_header_font != NULL) {
        DeleteObject(tokeni_dashboard_header_font);
    }
    tokeni_dashboard_font = font;
    tokeni_dashboard_header_font = header_font;
    for (int index = 0; index < 4; index++) {
        SendMessageW(tokeni_navigation[index], WM_SETFONT, (WPARAM)font, TRUE);
    }
    SendMessageW(tokeni_usage_list, WM_SETFONT, (WPARAM)font, TRUE);
    for (int index = 0; index < 4; index++) {
        SendMessageW(tokeni_service_buttons[index], WM_SETFONT, (WPARAM)font, TRUE);
    }
    SendMessageW(tokeni_pet_picker, WM_SETFONT, (WPARAM)font, TRUE);
    SendMessageW(tokeni_pet_select, WM_SETFONT, (WPARAM)font, TRUE);
    SendMessageW(tokeni_pet_hatch, WM_SETFONT, (WPARAM)font, TRUE);
    EnumChildWindows(window, tokeni_style_child, 0);
    SendMessageW(tokeni_dashboard_header, WM_SETFONT, (WPARAM)header_font, TRUE);
}

static void tokeni_dashboard_layout(HWND window)
{
    RECT client;
    GetClientRect(window, &client);

    UINT dpi = tokeni_dashboard_dpi(window);
    int margin = tokeni_scale_for_dpi(20, dpi);
    int gap = tokeni_scale_for_dpi(10, dpi);
    int header_height = tokeni_scale_for_dpi(34, dpi);
    int status_height = tokeni_scale_for_dpi(22, dpi);
    int provider_label_height = tokeni_scale_for_dpi(22, dpi);
    int provider_row_height = tokeni_scale_for_dpi(27, dpi);
    int button_width = tokeni_scale_for_dpi(150, dpi);
    int button_height = tokeni_scale_for_dpi(34, dpi);
    int content_left = tokeni_scale_for_dpi(190, dpi);
    int content_width = max(client.right - content_left - margin, 0);
    for (int index = 0; index < 4; index++) {
        MoveWindow(tokeni_navigation[index], margin, margin + index * tokeni_scale_for_dpi(48, dpi),
            tokeni_scale_for_dpi(150, dpi), tokeni_scale_for_dpi(40, dpi), TRUE);
        SendMessageW(tokeni_navigation[index], BM_SETCHECK,
            tokeni_destination == index ? BST_CHECKED : BST_UNCHECKED, 0);
        InvalidateRect(tokeni_navigation[index], NULL, TRUE);
    }
    int provider_columns = content_width >= tokeni_scale_for_dpi(360, dpi)
        ? 2
        : 1;
    int provider_rows = tokeni_dashboard_provider_count == 0
        ? 0
        : (tokeni_dashboard_provider_count + provider_columns - 1)
            / provider_columns;
    int provider_top = margin + header_height + status_height + gap;
    int provider_height = tokeni_destination != 3 || tokeni_dashboard_provider_count == 0
        ? 0
        : provider_label_height + (provider_rows * provider_row_height) + gap;
    int details_top = provider_top + provider_height;
    int details_height = max(
        client.bottom - details_top - button_height - (margin * 2),
        0);
    int button_top = client.bottom - margin - button_height;

    MoveWindow(
        tokeni_dashboard_header,
        content_left,
        margin,
        content_width,
        header_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_status,
        content_left,
        margin + header_height,
        content_width,
        status_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_provider_label,
        content_left,
        provider_top,
        content_width,
        provider_label_height,
        TRUE);
    int provider_content_top = provider_top + provider_label_height;
    int provider_column_width = provider_columns == 0
        ? content_width
        : (content_width - ((provider_columns - 1) * gap))
            / provider_columns;
    for (int index = 0;
         index < tokeni_dashboard_provider_count;
         index += 1)
    {
        int column = index % provider_columns;
        int row = index / provider_columns;
        MoveWindow(
            tokeni_dashboard_provider_buttons[index],
            content_left + (column * (provider_column_width + gap)),
            provider_content_top + (row * provider_row_height),
            provider_column_width,
            provider_row_height,
            TRUE);
        ShowWindow(tokeni_dashboard_provider_buttons[index], tokeni_destination == 3 ? SW_SHOW : SW_HIDE);
    }
    ShowWindow(tokeni_dashboard_provider_label,
        tokeni_destination == 3 && tokeni_dashboard_provider_count > 0 ? SW_SHOW : SW_HIDE);
    MoveWindow(
        tokeni_dashboard_details,
        content_left,
        details_top,
        content_width,
        details_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_hide_button,
        client.right - margin - button_width,
        button_top,
        button_width,
        button_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_refresh_button,
        client.right - margin - (button_width * 2) - gap,
        button_top,
        button_width,
        button_height,
        TRUE);
    int list_top = tokeni_destination == 0 ? details_top + tokeni_scale_for_dpi(150, dpi) : details_top;
    MoveWindow(tokeni_usage_list, content_left, list_top, content_width,
        max(button_top - gap - list_top, 0), TRUE);
    ShowWindow(tokeni_usage_list, tokeni_destination < 2 ? SW_SHOW : SW_HIDE);
    ShowWindow(tokeni_dashboard_details, SW_SHOW);
    if (tokeni_destination == 0) {
        MoveWindow(tokeni_dashboard_details, content_left, details_top, content_width,
            tokeni_scale_for_dpi(135, dpi), TRUE);
    }
    if (tokeni_destination == 1) {
        int available = max(button_top - gap - details_top, 0);
        int table_height = available * 3 / 5;
        MoveWindow(tokeni_usage_list, content_left, details_top, content_width, table_height, TRUE);
        MoveWindow(tokeni_dashboard_details, content_left, details_top + table_height + gap,
            content_width, max(available - table_height - gap, 0), TRUE);
    }
    const int widths[] = {150, 130, 110, 150, 100, 100};
    for (int column = 0; column < 6; column++) {
        ListView_SetColumnWidth(tokeni_usage_list, column,
            max(tokeni_scale_for_dpi(75, dpi), (content_width - tokeni_scale_for_dpi(20, dpi)) * widths[column] / 740));
    }
    for (int index = 0; index < 4; index++) {
        int visible = tokeni_destination == 3 || (tokeni_destination == 2 && index == 2);
        ShowWindow(tokeni_service_buttons[index], visible ? SW_SHOW : SW_HIDE);
        MoveWindow(tokeni_service_buttons[index], content_left + (index % 2) * (content_width / 2),
            details_top + (index / 2) * tokeni_scale_for_dpi(42, dpi),
            content_width / 2 - gap, button_height, TRUE);
    }
    if (tokeni_destination == 3) {
        int pref_top = details_top + tokeni_scale_for_dpi(96, dpi);
        MoveWindow(tokeni_language_picker, content_left, pref_top, content_width / 2 - gap, tokeni_scale_for_dpi(180, dpi), TRUE);
        MoveWindow(tokeni_theme_picker, content_left + content_width / 2, pref_top, content_width / 2 - gap, tokeni_scale_for_dpi(180, dpi), TRUE);
        int top = pref_top + tokeni_scale_for_dpi(46, dpi);
        MoveWindow(tokeni_dashboard_details, content_left, top, content_width, max(button_top - top - gap, 0), TRUE);
    }
    ShowWindow(tokeni_language_picker, tokeni_destination == 3 ? SW_SHOW : SW_HIDE);
    ShowWindow(tokeni_theme_picker, tokeni_destination == 3 ? SW_SHOW : SW_HIDE);
    ShowWindow(tokeni_pet_picker, tokeni_destination == 2 ? SW_SHOW : SW_HIDE);
    ShowWindow(tokeni_pet_select, tokeni_destination == 2 ? SW_SHOW : SW_HIDE);
    ShowWindow(tokeni_pet_hatch, tokeni_destination == 2 ? SW_SHOW : SW_HIDE);
    if (tokeni_destination == 2) {
        MoveWindow(tokeni_pet_picker, content_left, details_top, content_width / 2 - gap, tokeni_scale_for_dpi(240, dpi), TRUE);
        MoveWindow(tokeni_pet_select, content_left + content_width / 2, details_top,
            content_width / 2 - gap, button_height, TRUE);
        MoveWindow(tokeni_pet_hatch, content_left + content_width / 2, details_top + tokeni_scale_for_dpi(42, dpi),
            content_width / 2 - gap, button_height, TRUE);
        int top = details_top + tokeni_scale_for_dpi(96, dpi);
        MoveWindow(tokeni_dashboard_details, content_left, top, content_width, max(button_top - top - gap, 0), TRUE);
    }
    tokeni_history_layout(content_left, details_top, content_width, button_top-gap, gap, dpi);
    tokeni_pet_extra_layout(content_left, details_top, content_width, button_top-gap, gap, dpi);
    tokeni_update_layout(content_left, details_top, content_width, button_top-gap, gap, dpi);
}

static void tokeni_dashboard_apply_details(void)
{
    WCHAR details[8192];

    AcquireSRWLockShared(&tokeni_state_lock);
    CopyMemory(details, tokeni_details, sizeof(details));
    details[(sizeof(details) / sizeof(details[0])) - 1] = L'\0';
    ReleaseSRWLockShared(&tokeni_state_lock);

    if (tokeni_destination == 0) {
        AcquireSRWLockShared(&tokeni_state_lock);
        lstrcpynW(details, tokeni_home_summary, 4096);
        if (tokeni_pet_summary[0] && lstrlenW(details) + lstrlenW(tokeni_pet_summary) + 5 < 8192) {
            lstrcatW(details, L"\r\n\r\n");
            lstrcatW(details, tokeni_pet_summary);
        }
        ReleaseSRWLockShared(&tokeni_state_lock);
    }
    if (tokeni_destination >= 2) {
        AcquireSRWLockShared(&tokeni_state_lock);
        if (tokeni_destination == 2) { lstrcpynW(details, tokeni_pet_summary, 4096); }
        else {
            lstrcpynW(details, tokeni_text(L"Provider connections\r\n\r\nEnable the providers you use above. Sign in through each provider's own CLI or application, then refresh Tokeni Bar.\r\n\r\nClosing this window keeps Tokeni Bar in the tray. Use Quit Tokeni Bar to stop it.\r\n\r\n"), 8192);
        }
        if (tokeni_service_feedback[0]) {
            lstrcatW(details, L"\r\n\r\n");
            lstrcatW(details, tokeni_service_feedback);
        }
        if (tokeni_destination == 2 && tokeni_pet_mode == 2) {
            lstrcatW(details,L"\r\n\r\n");lstrcatW(details,tokeni_reward_summary);
        }
        ReleaseSRWLockShared(&tokeni_state_lock);
    }

    SetWindowTextW(
        tokeni_dashboard_details,
        details[0] == L'\0'
            ? L"Usage is not available yet."
            : details);
}

static LRESULT CALLBACK tokeni_dashboard_window_proc(
    HWND window,
    UINT message,
    WPARAM w_param,
    LPARAM l_param)
{
    if (message == WM_CREATE) {
        tokeni_history_create(window);
        tokeni_pet_extra_create(window);
        tokeni_update_create(window);
        tokeni_language_picker = CreateWindowExW(0, L"COMBOBOX", L"Language", WS_CHILD | WS_TABSTOP | CBS_DROPDOWNLIST,
            0,0,0,0,window,(HMENU)(INT_PTR)530,tokeni_instance,NULL);
        tokeni_theme_picker = CreateWindowExW(0, L"COMBOBOX", L"Appearance", WS_CHILD | WS_TABSTOP | CBS_DROPDOWNLIST,
            0,0,0,0,window,(HMENU)(INT_PTR)531,tokeni_instance,NULL);
        const WCHAR *languages[] = {L"System language", L"English", L"한국어"};
        const WCHAR *themes[] = {L"System theme", L"Light", L"Dark"};
        for (int i = 0; i < 3; i++) {
            SendMessageW(tokeni_language_picker, CB_ADDSTRING, 0, (LPARAM)tokeni_text(languages[i]));
            SendMessageW(tokeni_theme_picker, CB_ADDSTRING, 0, (LPARAM)tokeni_text(themes[i]));
        }
        SendMessageW(tokeni_language_picker, CB_SETCURSEL, tokeni_language, 0);
        SendMessageW(tokeni_theme_picker, CB_SETCURSEL, tokeni_appearance, 0);
        const WCHAR *services[] = {L"Start with Windows", L"Send test notification", L"Desktop companion", L"Quit Tokeni Bar"};
        for (int index = 0; index < 4; index++) {
            tokeni_service_buttons[index] = CreateWindowExW(0, L"BUTTON", services[index],
                WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 0, 0, 0, 0, window,
                (HMENU)(INT_PTR)(500 + index), tokeni_instance, NULL);
            if (tokeni_service_buttons[index] == NULL) { return -1; }
        }
        tokeni_pet_picker = CreateWindowExW(0, L"COMBOBOX", L"Owned companions",
            WS_CHILD | WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST,
            0, 0, 0, 0, window, (HMENU)(INT_PTR)510, tokeni_instance, NULL);
        tokeni_pet_select = CreateWindowExW(0, L"BUTTON", L"Set growth target", WS_CHILD | WS_TABSTOP,
            0, 0, 0, 0, window, (HMENU)(INT_PTR)511, tokeni_instance, NULL);
        tokeni_pet_hatch = CreateWindowExW(0, L"BUTTON", L"Open an egg", WS_CHILD | WS_TABSTOP,
            0, 0, 0, 0, window, (HMENU)(INT_PTR)512, tokeni_instance, NULL);
        if (!tokeni_pet_picker || !tokeni_pet_select || !tokeni_pet_hatch) { return -1; }
        INITCOMMONCONTROLSEX common = { sizeof(common), ICC_LISTVIEW_CLASSES };
        InitCommonControlsEx(&common);
        tokeni_usage_list = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"Provider usage",
            WS_CHILD | WS_TABSTOP | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS,
            0, 0, 0, 0, window, (HMENU)(INT_PTR)450, tokeni_instance, NULL);
        if (tokeni_usage_list == NULL) { return -1; }
        ListView_SetExtendedListViewStyle(tokeni_usage_list, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_LABELTIP);
        const WCHAR *columns[] = {L"Provider", L"Status", L"Remaining", L"Next reset", L"Tokens", L"Cost (USD)"};
        for (int column = 0; column < 6; column++) {
            LVCOLUMNW definition = {0};
            definition.mask = LVCF_TEXT | LVCF_WIDTH;
            definition.pszText = (WCHAR *)columns[column];
            definition.cx = 120;
            SendMessageW(tokeni_usage_list, LVM_INSERTCOLUMNW, column, (LPARAM)&definition);
        }
        for (int index = 0; index < 4; index++) {
            tokeni_navigation[index] = CreateWindowExW(0, L"BUTTON", tokeni_page_titles[index],
                WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_OWNERDRAW,
                0, 0, 0, 0, window, (HMENU)(INT_PTR)(400 + index), tokeni_instance, NULL);
            if (tokeni_navigation[index] == NULL) { return -1; }
        }
        tokeni_dashboard_header = CreateWindowExW(
            0,
            L"STATIC",
            tokeni_page_titles[tokeni_destination],
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            NULL,
            tokeni_instance,
            NULL);
        tokeni_dashboard_status = CreateWindowExW(
            0,
            L"STATIC",
            tokeni_page_subtitles[tokeni_destination],
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            NULL,
            tokeni_instance,
            NULL);
        tokeni_dashboard_provider_label = CreateWindowExW(
            0,
            L"STATIC",
            L"Providers",
            WS_CHILD | SS_LEFT,
            0,
            0,
            0,
            0,
            window,
            NULL,
            tokeni_instance,
            NULL);
        tokeni_dashboard_details = CreateWindowExW(
            WS_EX_CLIENTEDGE,
            L"EDIT",
            L"Usage is not available yet.",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_VSCROLL
                | ES_LEFT | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL,
            0,
            0,
            0,
            0,
            window,
            NULL,
            tokeni_instance,
            NULL);
        tokeni_dashboard_refresh_button = CreateWindowExW(
            0,
            L"BUTTON",
            L"Refresh now",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0,
            0,
            0,
            0,
            window,
            (HMENU)(INT_PTR)tokeni_refresh_button_identifier,
            tokeni_instance,
            NULL);
        tokeni_dashboard_hide_button = CreateWindowExW(
            0,
            L"BUTTON",
            L"Hide to tray",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0,
            0,
            0,
            0,
            window,
            (HMENU)(INT_PTR)tokeni_hide_button_identifier,
            tokeni_instance,
            NULL);

        if (tokeni_dashboard_header == NULL
            || tokeni_dashboard_status == NULL
            || tokeni_dashboard_provider_label == NULL
            || tokeni_dashboard_details == NULL
            || tokeni_dashboard_refresh_button == NULL
            || tokeni_dashboard_hide_button == NULL)
        {
            return -1;
        }

        tokeni_dashboard_set_fonts(window);
        tokeni_dashboard_sync_provider_controls(window);
        tokeni_dashboard_apply_details();
        tokeni_dashboard_sync_usage();
        tokeni_dashboard_sync_services();
        tokeni_apply_style(window);
        return 0;
    }

    if (message == WM_SIZE) {
        tokeni_dashboard_layout(window);
        return 0;
    }

    if (message == WM_EXITSIZEMOVE) {
        tokeni_dashboard_save_frame(window);
        return 0;
    }
    if (message == WM_ERASEBKGND && tokeni_background_brush) {
        RECT rect; GetClientRect(window, &rect); FillRect((HDC)w_param, &rect, tokeni_background_brush); return 1;
    }
    if (message == WM_DRAWITEM && ((DRAWITEMSTRUCT *)l_param)->CtlID == 558) {
        DRAWITEMSTRUCT *item=(DRAWITEMSTRUCT *)l_param;
        FillRect(item->hDC,&item->rcItem,tokeni_surface_brush);
        tokeni_windows_overlay_draw_preview(item->hDC,item->rcItem.right,item->rcItem.bottom);
        return TRUE;
    }
    if (message == WM_DRAWITEM && ((DRAWITEMSTRUCT *)l_param)->CtlID == 543) { return tokeni_history_draw((DRAWITEMSTRUCT *)l_param); }
    if (message == WM_DRAWITEM && ((DRAWITEMSTRUCT *)l_param)->CtlType == ODT_BUTTON) {
        return tokeni_draw_button((DRAWITEMSTRUCT *)l_param);
    }
    if (message == WM_CTLCOLORSTATIC || message == WM_CTLCOLOREDIT || message == WM_CTLCOLORBTN || message == WM_CTLCOLORLISTBOX) {
        HDC context = (HDC)w_param;
        int is_label = (HWND)l_param == tokeni_dashboard_header || (HWND)l_param == tokeni_dashboard_status || (HWND)l_param == tokeni_dashboard_provider_label;
        SetTextColor(context, (HWND)l_param == tokeni_dashboard_status ? tokeni_muted : tokeni_foreground);
        SetBkColor(context, is_label ? tokeni_background : tokeni_surface);
        return (LRESULT)(is_label ? tokeni_background_brush : tokeni_surface_brush);
    }
    if (message == WM_SETTINGCHANGE || message == WM_THEMECHANGED) { tokeni_apply_style(window); return 0; }
    if (message == WM_NOTIFY && ((NMHDR *)l_param)->hwndFrom == tokeni_usage_list
        && ((NMHDR *)l_param)->code == LVN_ITEMACTIVATE && tokeni_destination == 0) {
        SendMessageW(window, WM_COMMAND, 401, 0);
        return 0;
    }

    if (message == WM_DPICHANGED) {
        RECT *suggested = (RECT *)l_param;
        SetWindowPos(
            window,
            NULL,
            suggested->left,
            suggested->top,
            suggested->right - suggested->left,
            suggested->bottom - suggested->top,
            SWP_NOACTIVATE | SWP_NOZORDER);
        tokeni_dashboard_set_fonts(window);
        tokeni_dashboard_layout(window);
        return 0;
    }

    if (message == WM_GETMINMAXINFO) {
        MINMAXINFO *minimums = (MINMAXINFO *)l_param;
        UINT dpi = tokeni_dashboard_dpi(window);
        minimums->ptMinTrackSize.x = tokeni_scale_for_dpi(720, dpi);
        minimums->ptMinTrackSize.y = tokeni_scale_for_dpi(520, dpi);
        return 0;
    }

    if (message == WM_COMMAND) {
        int identifier = LOWORD(w_param);
        if(identifier>=580&&identifier<=582) {tokeni_update_command(identifier);return 0;}
        if(identifier==550 && HIWORD(w_param)==CBN_SELCHANGE) {
            tokeni_pet_mode=(int)SendMessageW(tokeni_pet_extra[0],CB_GETCURSEL,0,0);
            tokeni_inventory_sync();tokeni_dashboard_layout(window);tokeni_dashboard_apply_details();return 0;
        }
        if(identifier==552||identifier==553||identifier==555||identifier==556||identifier==557||identifier==562) { tokeni_pet_extra_action(identifier);return 0; }
        if(identifier==559||identifier==560||(identifier==561&&HIWORD(w_param)==CBN_SELCHANGE)) {
            tokeni_windows_overlay_configure(SendMessageW(tokeni_pet_extra[9],BM_GETCHECK,0,0)==BST_CHECKED,
                SendMessageW(tokeni_pet_extra[10],BM_GETCHECK,0,0)==BST_CHECKED,
                (int)SendMessageW(tokeni_pet_extra[11],CB_GETCURSEL,0,0));return 0;
        }
        if (identifier == 540) {
            tokeni_history_visible = SendMessageW(tokeni_history_mode, BM_GETCHECK, 0, 0) == BST_CHECKED;
            tokeni_history_sync(); tokeni_dashboard_layout(window); return 0;
        }
        if ((identifier == 541 || identifier == 542) && HIWORD(w_param) == CBN_SELCHANGE) { tokeni_history_sync(); return 0; }
        if ((identifier == 530 || identifier == 531) && HIWORD(w_param) == CBN_SELCHANGE) {
            int selection = (int)SendMessageW((HWND)l_param, CB_GETCURSEL, 0, 0);
            if (selection >= 0 && selection <= 2) {
                InterlockedExchange(identifier == 530 ? &tokeni_language : &tokeni_appearance, selection);
                tokeni_save_preferences(); tokeni_apply_style(window); tokeni_localize_controls(); tokeni_dashboard_apply_details();
                tokeni_dashboard_sync_services();
            }
            return 0;
        }
        if (identifier >= 500 && identifier <= 503) {
            if (identifier == 500) { InterlockedExchange(&tokeni_launch_at_login_requested, 1); }
            if (identifier == 501) { InterlockedExchange(&tokeni_test_notification_requested, 1); }
            if (identifier == 502) { InterlockedExchange(&tokeni_companion_toggle_requested, 1); }
            if (identifier == 503) { PostMessageW(tokeni_window, WM_CLOSE, 0, 0); }
            return 0;
        }
        if (identifier == 511) {
            int selected = (int)SendMessageW(tokeni_pet_picker, CB_GETCURSEL, 0, 0);
            if (selected >= 0 && selected < tokeni_displayed_pet_count) {
                AcquireSRWLockExclusive(&tokeni_state_lock);
                lstrcpynA(tokeni_selected_pet_request, tokeni_displayed_pets[selected].id, 64);
                ReleaseSRWLockExclusive(&tokeni_state_lock);
            }
            return 0;
        }
        if (identifier == 512) { InterlockedExchange(&tokeni_hatch_requested, 1); return 0; }
        if (identifier >= 400 && identifier < 404) {
            tokeni_destination = identifier - 400;
            SetWindowTextW(tokeni_dashboard_header, tokeni_page_titles[tokeni_destination]);
            SetWindowTextW(tokeni_dashboard_status, tokeni_page_subtitles[tokeni_destination]);
            tokeni_dashboard_layout(window);
            tokeni_dashboard_apply_details();
            tokeni_dashboard_sync_usage();
            tokeni_dashboard_sync_services();
            return 0;
        }
        if (identifier == tokeni_refresh_button_identifier) {
            InterlockedExchange(&tokeni_refresh_requested, 1);
            SetWindowTextW(tokeni_dashboard_status, L"Refreshing provider usage…");
            return 0;
        }
        if (identifier == tokeni_hide_button_identifier || identifier == IDCANCEL) {
            tokeni_dashboard_save_frame(window);
            ShowWindow(window, SW_HIDE);
            return 0;
        }
        int provider_index = identifier
            - tokeni_provider_button_identifier_base;
        if (HIWORD(w_param) == BN_CLICKED
            && provider_index >= 0
            && provider_index < tokeni_dashboard_provider_count)
        {
            int enabled = SendMessageW(
                tokeni_dashboard_provider_buttons[provider_index],
                BM_GETCHECK,
                0,
                0) == BST_CHECKED;
            char provider_id[TOKENI_PROVIDER_ID_CAPACITY];
            tokeni_copy_provider_id(
                tokeni_dashboard_provider_ids[provider_index],
                provider_id);

            AcquireSRWLockExclusive(&tokeni_state_lock);
            tokeni_windows_provider_state_click(
                &tokeni_provider_toggle_state,
                provider_id,
                enabled);
            ReleaseSRWLockExclusive(&tokeni_state_lock);
            return 0;
        }
    }

    if (message == tokeni_details_updated_message) {
        tokeni_dashboard_apply_details();
        tokeni_dashboard_sync_usage();
        tokeni_dashboard_sync_services();
        return 0;
    }

    if (message == tokeni_provider_options_updated_message) {
        tokeni_dashboard_sync_provider_controls(window);
        tokeni_dashboard_layout(window);
        return 0;
    }

    if (message == WM_CLOSE) {
        tokeni_dashboard_save_frame(window);
        ShowWindow(window, SW_HIDE);
        return 0;
    }

    if (message == WM_DESTROY) {
        if (tokeni_background_brush) { DeleteObject(tokeni_background_brush); tokeni_background_brush = NULL; }
        if (tokeni_surface_brush) { DeleteObject(tokeni_surface_brush); tokeni_surface_brush = NULL; }
        tokeni_dashboard_destroy_provider_controls();
        tokeni_dashboard_window = NULL;
        tokeni_dashboard_header = NULL;
        tokeni_dashboard_status = NULL;
        tokeni_dashboard_provider_label = NULL;
        tokeni_dashboard_details = NULL;
        tokeni_dashboard_refresh_button = NULL;
        tokeni_dashboard_hide_button = NULL;
        if (tokeni_dashboard_font != NULL) {
            DeleteObject(tokeni_dashboard_font);
            tokeni_dashboard_font = NULL;
        }
        if (tokeni_dashboard_header_font != NULL) {
            DeleteObject(tokeni_dashboard_header_font);
            tokeni_dashboard_header_font = NULL;
        }
        return 0;
    }

    return DefWindowProcW(window, message, w_param, l_param);
}

static int tokeni_copy_utf8(
    const char *source,
    WCHAR *destination,
    int destination_count)
{
    if (source == NULL || destination == NULL || destination_count <= 0) {
        return 0;
    }

    int converted = MultiByteToWideChar(
        CP_UTF8,
        0,
        source,
        -1,
        destination,
        destination_count);
    if (converted == 0) {
        destination[0] = L'\0';
        return 0;
    }

    destination[destination_count - 1] = L'\0';
    return 1;
}

static int tokeni_add_icon_locked(void)
{
    if (tokeni_window == NULL) {
        return 0;
    }

    // NIM_MODIFY callers intentionally narrow uFlags for their operation.
    // Rebuild every field required by NIM_ADD so Explorer recovery always
    // restores the icon, tooltip, and callback contract together.
    tokeni_icon.cbSize = sizeof(tokeni_icon);
    tokeni_icon.hWnd = tokeni_window;
    tokeni_icon.uID = tokeni_tray_identifier;
    tokeni_icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tokeni_icon.uCallbackMessage = tokeni_tray_callback_message;
    tokeni_icon.hIcon = LoadIconW(tokeni_instance, MAKEINTRESOURCEW(101));
    if (!tokeni_icon.hIcon) { tokeni_icon.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512)); }
    if (!Shell_NotifyIconW(NIM_ADD, &tokeni_icon)) {
        return 0;
    }

    tokeni_icon.uVersion = NOTIFYICON_VERSION;
    Shell_NotifyIconW(NIM_SETVERSION, &tokeni_icon);
    return 1;
}

void tokeni_windows_dashboard_begin_usage(void)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_usage_staged_count = 0;
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

void tokeni_windows_dashboard_begin_pets(void)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_staged_pet_count = 0;
    ZeroMemory(tokeni_staged_pets, sizeof(tokeni_staged_pets));
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

int tokeni_windows_dashboard_append_pet(const char *id, const char *label, int selected)
{
    if (id == NULL || strlen(id) >= 64) { return 0; }
    tokeni_pet_option pet = {0};
    lstrcpynA(pet.id, id, 64);
    if (!tokeni_copy_utf8(label, pet.label, 256)) { return 0; }
    pet.selected = selected;
    AcquireSRWLockExclusive(&tokeni_state_lock);
    int accepted = tokeni_staged_pet_count < 128;
    if (accepted) { tokeni_staged_pets[tokeni_staged_pet_count++] = pet; }
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return accepted;
}

void tokeni_windows_dashboard_commit_pets(const char *summary, int eggs, const char *feedback)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (tokeni_pet_count != tokeni_staged_pet_count || memcmp(tokeni_pets, tokeni_staged_pets, sizeof(tokeni_pets))) {
        CopyMemory(tokeni_pets, tokeni_staged_pets, sizeof(tokeni_pets));
        tokeni_pet_count = tokeni_staged_pet_count;
        tokeni_pet_revision++;
    }
    tokeni_copy_utf8(summary, tokeni_pet_summary, 4096);
    tokeni_copy_utf8(feedback, tokeni_service_feedback, 512);
    tokeni_egg_count = eggs;
    if (tokeni_window != NULL) { PostMessageW(tokeni_window, tokeni_details_updated_message, 0, 0); }
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

int tokeni_windows_dashboard_take_pet_request(char *id, int capacity)
{
    if (id == NULL || capacity < 64) { return 0; }
    AcquireSRWLockExclusive(&tokeni_state_lock);
    int available = tokeni_selected_pet_request[0] != '\0';
    lstrcpynA(id, tokeni_selected_pet_request, capacity);
    tokeni_selected_pet_request[0] = '\0';
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return available;
}

int tokeni_windows_dashboard_take_hatch_request(void)
{ return InterlockedExchange(&tokeni_hatch_requested, 0); }

int tokeni_windows_dashboard_append_usage(const char *name, const char *status,
    const char *remaining, const char *reset, const char *tokens, const char *cost)
{
    tokeni_usage_row row = {0};
    const char *values[] = {name, status, remaining, reset, tokens, cost};
    for (int column = 0; column < 6; column++) {
        if (!tokeni_copy_utf8(values[column], row.cells[column], 256)) { return 0; }
    }
    AcquireSRWLockExclusive(&tokeni_state_lock);
    int accepted = tokeni_usage_staged_count < TOKENI_MAX_PROVIDERS;
    if (accepted) { tokeni_usage_staged[tokeni_usage_staged_count++] = row; }
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return accepted;
}

void tokeni_windows_dashboard_commit_usage(const char *summary, const char *status, int refreshing)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    CopyMemory(tokeni_usage_rows, tokeni_usage_staged, sizeof(tokeni_usage_rows));
    tokeni_usage_count = tokeni_usage_staged_count;
    tokeni_copy_utf8(summary, tokeni_home_summary, 4096);
    tokeni_copy_utf8(status, tokeni_refresh_status, 256);
    tokeni_is_refreshing = refreshing != 0;
    if (tokeni_window != NULL) { PostMessageW(tokeni_window, tokeni_details_updated_message, 0, 0); }
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

static void tokeni_remove_icon_locked(void)
{
    if (tokeni_window != NULL) {
        Shell_NotifyIconW(NIM_DELETE, &tokeni_icon);
        tokeni_icon.hWnd = NULL;
        tokeni_window = NULL;
    }
}

static void tokeni_remove_icon(void)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_remove_icon_locked();
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

static void tokeni_destroy_window_locked(void)
{
    tokeni_remove_icon_locked();
    if (tokeni_dashboard_class_registered) {
        UnregisterClassW(tokeni_dashboard_class_name, tokeni_instance);
        tokeni_dashboard_class_registered = 0;
    }
    if (tokeni_class_registered) {
        UnregisterClassW(tokeni_window_class_name, tokeni_instance);
        tokeni_class_registered = 0;
    }
}

static void tokeni_destroy_window(void)
{
    if (tokeni_dashboard_window != NULL) {
        DestroyWindow(tokeni_dashboard_window);
    }
    AcquireSRWLockExclusive(&tokeni_state_lock);
    tokeni_destroy_window_locked();
    ReleaseSRWLockExclusive(&tokeni_state_lock);
}

static void tokeni_show_details(void)
{
    if (tokeni_dashboard_window == NULL) {
        POINT cursor;
        MONITORINFO monitor;
        UINT dpi = tokeni_dashboard_dpi(tokeni_window);
        int width = tokeni_scale_for_dpi(640, dpi);
        int height = tokeni_scale_for_dpi(520, dpi);

        GetCursorPos(&cursor);
        ZeroMemory(&monitor, sizeof(monitor));
        monitor.cbSize = sizeof(monitor);
        if (!GetMonitorInfoW(
                MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST),
                &monitor))
        {
            monitor.rcWork.left = 0;
            monitor.rcWork.top = 0;
            monitor.rcWork.right = GetSystemMetrics(SM_CXSCREEN);
            monitor.rcWork.bottom = GetSystemMetrics(SM_CYSCREEN);
        }

        int x = monitor.rcWork.left
            + ((monitor.rcWork.right - monitor.rcWork.left - width) / 2);
        int y = monitor.rcWork.top
            + ((monitor.rcWork.bottom - monitor.rcWork.top - height) / 2);
        tokeni_dashboard_window = CreateWindowExW(
            0,
            tokeni_dashboard_class_name,
            L"Tokeni Bar",
            WS_OVERLAPPEDWINDOW,
            x,
            y,
            width,
            height,
            NULL,
            NULL,
            tokeni_instance,
            NULL);
        if (tokeni_dashboard_window == NULL) {
            return;
        }
        tokeni_dashboard_set_initial_frame(
            tokeni_dashboard_window,
            &monitor);
        tokeni_dashboard_restore_frame(tokeni_dashboard_window);
    }

    tokeni_dashboard_apply_details();
    if (IsIconic(tokeni_dashboard_window)) { ShowWindow(tokeni_dashboard_window, SW_RESTORE); }
    // Explicit app activation must also work when its launcher supplied SW_HIDE.
    SetWindowPos(tokeni_dashboard_window, NULL, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_SHOWWINDOW);
    SetForegroundWindow(tokeni_dashboard_window);
    BringWindowToTop(tokeni_dashboard_window);
    SetFocus(tokeni_navigation[tokeni_destination]);
}

static LRESULT CALLBACK tokeni_window_proc(
    HWND window,
    UINT message,
    WPARAM w_param,
    LPARAM l_param)
{
    (void)w_param;
    if (message == tokeni_invoke_message) {
        tokeni_ui_invocation *invocation = (tokeni_ui_invocation *)l_param;
        invocation->operation(invocation->context);
        return 0;
    }
    if (message == tokeni_open_window_message) {
        tokeni_show_details();
        return 0;
    }

    if (tokeni_taskbar_created_message != 0
        && message == tokeni_taskbar_created_message)
    {
        AcquireSRWLockExclusive(&tokeni_state_lock);
        if (tokeni_window == window) {
            // Explorer can still be settling when it broadcasts this message.
            // A failed re-add must not close the host or discard current state.
            tokeni_add_icon_locked();
        }
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }

    if (message == tokeni_tray_callback_message && l_param == WM_LBUTTONUP) {
        tokeni_show_details();
        return 0;
    }

    if (message == tokeni_details_updated_message) {
        if (tokeni_dashboard_window != NULL) {
            PostMessageW(
                tokeni_dashboard_window,
                tokeni_details_updated_message,
                0,
                0);
        }
        return 0;
    }

    if (message == tokeni_provider_options_updated_message) {
        if (tokeni_dashboard_window != NULL) {
            PostMessageW(
                tokeni_dashboard_window,
                tokeni_provider_options_updated_message,
                0,
                0);
        }
        return 0;
    }

    if (message == tokeni_tray_callback_message
        && (l_param == WM_RBUTTONUP || l_param == WM_CONTEXTMENU))
    {
        POINT point;
        GetCursorPos(&point);
        SetForegroundWindow(window);

        HMENU menu = CreatePopupMenu();
        if (menu != NULL) {
            LONG launch_at_login_enabled = InterlockedCompareExchange(
                &tokeni_launch_at_login_enabled,
                0,
                0);
            LONG companion_enabled = InterlockedCompareExchange(
                &tokeni_companion_enabled,
                0,
                0);
            AppendMenuW(menu, MF_STRING, 1, L"Show details");
            AppendMenuW(menu, MF_STRING, 2, L"Refresh now");
            AppendMenuW(
                menu,
                MF_STRING | (launch_at_login_enabled
                    ? MF_CHECKED
                    : MF_UNCHECKED),
                3,
                L"Start with Windows");
            AppendMenuW(menu, MF_STRING, 4, L"Send test notification");
            AppendMenuW(
                menu,
                MF_STRING | (companion_enabled
                    ? MF_CHECKED
                    : MF_UNCHECKED),
                5,
                L"Show companion");
            AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
            AppendMenuW(menu, MF_STRING, 6, L"Quit Tokeni Bar");
            UINT command = TrackPopupMenu(
                menu,
                TPM_RETURNCMD | TPM_NONOTIFY,
                point.x,
                point.y,
                0,
                window,
                NULL);
            if (command == 1) {
                tokeni_show_details();
            } else if (command == 2) {
                InterlockedExchange(&tokeni_refresh_requested, 1);
            } else if (command == 3) {
                InterlockedExchange(&tokeni_launch_at_login_requested, 1);
            } else if (command == 4) {
                InterlockedExchange(&tokeni_test_notification_requested, 1);
            } else if (command == 5) {
                InterlockedExchange(&tokeni_companion_toggle_requested, 1);
            } else if (command == 6) {
                PostMessageW(window, WM_CLOSE, 0, 0);
            }
            DestroyMenu(menu);
        }

        return 0;
    }

    if (message == WM_CLOSE) {
        if (tokeni_dashboard_window != NULL) {
            tokeni_dashboard_save_frame(tokeni_dashboard_window);
            DestroyWindow(tokeni_dashboard_window);
        }
        tokeni_windows_overlay_stop();
        DestroyWindow(window);
        return 0;
    }

    if (message == WM_DESTROY) {
        tokeni_remove_icon();
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(window, message, w_param, l_param);
}

static int tokeni_tray_start_on_ui_thread(
    const char *application_name_utf8,
    const char *tooltip_utf8)
{
    (void)application_name_utf8;
    if (tokeni_window != NULL) {
        return 1;
    }

    tokeni_instance_mutex = CreateMutexW(NULL, FALSE, L"Local\\" TOKENI_DESKTOP_NAMESPACE L"DesktopInstance");
    if (tokeni_instance_mutex == NULL) { return 0; }
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        // The first process may still be registering its tray window.
        for (int attempt = 0; attempt < 40; attempt++) {
            HWND existing = FindWindowW(tokeni_window_class_name, tokeni_window_class_name);
            if (existing != NULL) {
                DWORD process_id;
                GetWindowThreadProcessId(existing, &process_id);
                AllowSetForegroundWindow(process_id);
                PostMessageW(existing, tokeni_open_window_message, 0, 0);
                break;
            }
            Sleep(50);
        }
        CloseHandle(tokeni_instance_mutex);
        tokeni_instance_mutex = NULL;
        return 0;
    }

    tokeni_enable_per_monitor_dpi_awareness();
    tokeni_load_preferences();
    tokeni_instance = GetModuleHandleW(NULL);
    if (tokeni_instance == NULL) {
        return 0;
    }
    tokeni_taskbar_created_message = RegisterWindowMessageW(L"TaskbarCreated");

    WNDCLASSEXW window_class;
    ZeroMemory(&window_class, sizeof(window_class));
    window_class.cbSize = sizeof(window_class);
    window_class.hInstance = tokeni_instance;
    window_class.lpfnWndProc = tokeni_window_proc;
    window_class.lpszClassName = tokeni_window_class_name;
    if (RegisterClassExW(&window_class) == 0) {
        return 0;
    }
    tokeni_class_registered = 1;

    WNDCLASSEXW dashboard_class;
    ZeroMemory(&dashboard_class, sizeof(dashboard_class));
    dashboard_class.cbSize = sizeof(dashboard_class);
    dashboard_class.hInstance = tokeni_instance;
    dashboard_class.lpfnWndProc = tokeni_dashboard_window_proc;
    dashboard_class.lpszClassName = tokeni_dashboard_class_name;
    dashboard_class.hCursor = LoadCursorW(NULL, MAKEINTRESOURCEW(32512));
    dashboard_class.hIcon = LoadIconW(tokeni_instance, MAKEINTRESOURCEW(101));
    if (!dashboard_class.hIcon) { dashboard_class.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512)); }
    dashboard_class.hIconSm = dashboard_class.hIcon;
    dashboard_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    if (RegisterClassExW(&dashboard_class) == 0) {
        tokeni_destroy_window_locked();
        return 0;
    }
    tokeni_dashboard_class_registered = 1;

    tokeni_window = CreateWindowExW(
        WS_EX_TOOLWINDOW,
        tokeni_window_class_name,
        tokeni_window_class_name,
        WS_POPUP,
        0,
        0,
        0,
        0,
        NULL,
        NULL,
        tokeni_instance,
        NULL);
    if (tokeni_window == NULL) {
        tokeni_destroy_window_locked();
        return 0;
    }

    ZeroMemory(&tokeni_icon, sizeof(tokeni_icon));
    tokeni_details[0] = L'\0';
    ZeroMemory(tokeni_provider_options, sizeof(tokeni_provider_options));
    ZeroMemory(
        tokeni_staged_provider_options,
        sizeof(tokeni_staged_provider_options));
    tokeni_windows_provider_state_reset(&tokeni_provider_toggle_state);
    tokeni_provider_option_count = 0;
    tokeni_staged_provider_option_count = 0;
    tokeni_provider_transaction_active = 0;
    InterlockedExchange(&tokeni_refresh_requested, 0);
    InterlockedExchange(&tokeni_launch_at_login_requested, 0);
    InterlockedExchange(&tokeni_test_notification_requested, 0);
    InterlockedExchange(&tokeni_companion_toggle_requested, 0);
    if (!tokeni_copy_utf8(
            tooltip_utf8,
            tokeni_icon.szTip,
            (int)(sizeof(tokeni_icon.szTip) / sizeof(tokeni_icon.szTip[0])))
        || !tokeni_add_icon_locked())
    {
        tokeni_destroy_window_locked();
        return 0;
    }
    return 1;
}

int tokeni_windows_tray_update_tooltip(const char *tooltip_utf8)
{
    int result;
    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (tokeni_window == NULL
        || !tokeni_copy_utf8(
            tooltip_utf8,
            tokeni_icon.szTip,
            (int)(sizeof(tokeni_icon.szTip) / sizeof(tokeni_icon.szTip[0])))
        )
    {
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }

    tokeni_icon.uFlags = NIF_TIP;
    result = Shell_NotifyIconW(NIM_MODIFY, &tokeni_icon) ? 1 : 0;
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return result;
}

int tokeni_windows_tray_update_details(const char *details_utf8)
{
    int result;
    HWND window;
    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (tokeni_window == NULL) {
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }

    result = tokeni_copy_utf8(
        details_utf8,
        tokeni_details,
        (int)(sizeof(tokeni_details) / sizeof(tokeni_details[0])));
    window = tokeni_window;
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    if (result && window != NULL) {
        PostMessageW(window, tokeni_details_updated_message, 0, 0);
    }
    return result;
}

int tokeni_windows_tray_begin_provider_options(void)
{
    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (tokeni_window == NULL) {
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }
    ZeroMemory(
        tokeni_staged_provider_options,
        sizeof(tokeni_staged_provider_options));
    tokeni_staged_provider_option_count = 0;
    tokeni_provider_transaction_active = 1;
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return 1;
}

int tokeni_windows_tray_append_provider_option(
    const char *provider_id_utf8,
    const char *display_name_utf8,
    int enabled)
{
    tokeni_provider_option option;
    ZeroMemory(&option, sizeof(option));
    if (!tokeni_copy_provider_id(provider_id_utf8, option.provider_id)
        || !tokeni_copy_provider_name(
            display_name_utf8,
            option.provider_id,
            option.display_name))
    {
        AcquireSRWLockExclusive(&tokeni_state_lock);
        tokeni_provider_transaction_active = 0;
        tokeni_staged_provider_option_count = 0;
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }
    option.enabled = enabled != 0;

    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (!tokeni_provider_transaction_active
        || tokeni_staged_provider_option_count >= TOKENI_MAX_PROVIDERS)
    {
        tokeni_provider_transaction_active = 0;
        tokeni_staged_provider_option_count = 0;
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }
    for (int index = 0;
         index < tokeni_staged_provider_option_count;
         index += 1)
    {
        if (lstrcmpA(
                tokeni_staged_provider_options[index].provider_id,
                option.provider_id) == 0)
        {
            tokeni_provider_transaction_active = 0;
            tokeni_staged_provider_option_count = 0;
            ReleaseSRWLockExclusive(&tokeni_state_lock);
            return 0;
        }
    }
    tokeni_staged_provider_options[tokeni_staged_provider_option_count] = option;
    tokeni_staged_provider_option_count += 1;
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return 1;
}

int tokeni_windows_tray_commit_provider_options(void)
{
    HWND window;
    AcquireSRWLockExclusive(&tokeni_state_lock);
    if (!tokeni_provider_transaction_active || tokeni_window == NULL) {
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }

    tokeni_provider_option committed[TOKENI_MAX_PROVIDERS];
    tokeni_windows_provider_state_option authoritative[TOKENI_MAX_PROVIDERS];
    ZeroMemory(committed, sizeof(committed));
    ZeroMemory(authoritative, sizeof(authoritative));
    for (int index = 0;
         index < tokeni_staged_provider_option_count;
         index += 1)
    {
        committed[index] = tokeni_staged_provider_options[index];
        CopyMemory(
            authoritative[index].provider_id,
            committed[index].provider_id,
            TOKENI_PROVIDER_ID_CAPACITY);
        authoritative[index].enabled = committed[index].enabled;
    }
    if (!tokeni_windows_provider_state_commit(
            &tokeni_provider_toggle_state,
            authoritative,
            tokeni_staged_provider_option_count))
    {
        tokeni_provider_transaction_active = 0;
        tokeni_staged_provider_option_count = 0;
        ReleaseSRWLockExclusive(&tokeni_state_lock);
        return 0;
    }
    for (int index = 0;
         index < tokeni_staged_provider_option_count;
         index += 1)
    {
        committed[index].enabled =
            tokeni_provider_toggle_state.options[index].enabled;
    }

    ZeroMemory(tokeni_provider_options, sizeof(tokeni_provider_options));
    CopyMemory(
        tokeni_provider_options,
        committed,
        sizeof(committed));
    tokeni_provider_option_count = tokeni_staged_provider_option_count;
    tokeni_staged_provider_option_count = 0;
    tokeni_provider_transaction_active = 0;
    window = tokeni_window;
    ReleaseSRWLockExclusive(&tokeni_state_lock);

    PostMessageW(window, tokeni_provider_options_updated_message, 0, 0);
    return 1;
}

int tokeni_windows_tray_take_provider_toggle_request(
    char *provider_id_utf8,
    int provider_id_capacity,
    int *enabled)
{
    if (provider_id_utf8 == NULL
        || provider_id_capacity <= 0
        || enabled == NULL)
    {
        return 0;
    }

    AcquireSRWLockExclusive(&tokeni_state_lock);
    int result = tokeni_windows_provider_state_take(
        &tokeni_provider_toggle_state,
        provider_id_utf8,
        provider_id_capacity,
        enabled);
    ReleaseSRWLockExclusive(&tokeni_state_lock);
    return result;
}

int tokeni_windows_tray_take_refresh_request(void)
{
    return InterlockedExchange(&tokeni_refresh_requested, 0);
}

void tokeni_windows_tray_set_launch_at_login_enabled(int enabled)
{
    InterlockedExchange(&tokeni_launch_at_login_enabled, enabled != 0);
}

int tokeni_windows_tray_take_launch_at_login_request(void)
{
    return InterlockedExchange(&tokeni_launch_at_login_requested, 0);
}

int tokeni_windows_tray_take_test_notification_request(void)
{
    return InterlockedExchange(&tokeni_test_notification_requested, 0);
}

void tokeni_windows_tray_set_companion_enabled(int enabled)
{
    InterlockedExchange(&tokeni_companion_enabled, enabled != 0);
}

int tokeni_windows_tray_take_companion_toggle_request(void)
{
    return InterlockedExchange(&tokeni_companion_toggle_requested, 0);
}

int tokeni_windows_tray_is_started(void)
{
    int result;
    AcquireSRWLockShared(&tokeni_state_lock);
    result = tokeni_window != NULL ? 1 : 0;
    ReleaseSRWLockShared(&tokeni_state_lock);
    return result;
}

int tokeni_windows_tray_notify(
    const char *title_utf8,
    const char *body_utf8)
{
    int result;
    AcquireSRWLockShared(&tokeni_state_lock);
    if (tokeni_window == NULL || title_utf8 == NULL || body_utf8 == NULL) {
        ReleaseSRWLockShared(&tokeni_state_lock);
        return 0;
    }

    NOTIFYICONDATAW notification = tokeni_icon;
    if (!tokeni_copy_utf8(
            title_utf8,
            notification.szInfoTitle,
            (int)(sizeof(notification.szInfoTitle)
                / sizeof(notification.szInfoTitle[0])))
        || !tokeni_copy_utf8(
            body_utf8,
            notification.szInfo,
            (int)(sizeof(notification.szInfo)
                / sizeof(notification.szInfo[0]))))
    {
        ReleaseSRWLockShared(&tokeni_state_lock);
        return 0;
    }

    notification.uFlags = NIF_INFO;
    notification.dwInfoFlags = NIIF_INFO;
    result = Shell_NotifyIconW(NIM_MODIFY, &notification) ? 1 : 0;
    ReleaseSRWLockShared(&tokeni_state_lock);
    return result;
}

static int tokeni_tray_run_on_ui_thread(void)
{
    int argument_count = 0;
    WCHAR **arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
    int background = 0;
    for (int index = 1; arguments != NULL && index < argument_count; index++) {
        if (wcscmp(arguments[index], L"--background") == 0) { background = 1; }
    }
    if (arguments != NULL) { LocalFree(arguments); }
    if (!background) { tokeni_show_details(); }
    MSG message;
    while (GetMessageW(&message, NULL, 0, 0) > 0) {
        if (tokeni_dashboard_window == NULL
            || !IsWindowVisible(tokeni_dashboard_window)
            || !IsDialogMessageW(tokeni_dashboard_window, &message))
        {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }

    tokeni_destroy_window();
    if (tokeni_instance_mutex != NULL) {
        CloseHandle(tokeni_instance_mutex);
        tokeni_instance_mutex = NULL;
    }
    return 0;
}

typedef struct {
    const char *name;
    const char *tooltip;
    HANDLE ready;
    int result;
} tokeni_ui_start;

static DWORD WINAPI tokeni_ui_main(void *context)
{
    tokeni_ui_start *start = (tokeni_ui_start *)context;
    int result = tokeni_tray_start_on_ui_thread(start->name, start->tooltip);
    start->result = result;
    SetEvent(start->ready);
    // The caller owns start and may release it as soon as the event is signaled.
    if (result) { tokeni_tray_run_on_ui_thread(); }
    return 0;
}

int tokeni_windows_tray_start(const char *name, const char *tooltip)
{
    if (tokeni_ui_thread != NULL) { return tokeni_windows_tray_is_started(); }
    tokeni_ui_start start = {name, tooltip, CreateEventW(NULL, TRUE, FALSE, NULL), 0};
    if (start.ready == NULL) { return 0; }
    tokeni_ui_thread = CreateThread(NULL, 0, tokeni_ui_main, &start, 0, &tokeni_ui_thread_id);
    if (tokeni_ui_thread != NULL) { WaitForSingleObject(start.ready, INFINITE); }
    CloseHandle(start.ready);
    if (!start.result && tokeni_ui_thread != NULL) {
        WaitForSingleObject(tokeni_ui_thread, INFINITE);
        CloseHandle(tokeni_ui_thread);
        tokeni_ui_thread = NULL;
    }
    return start.result;
}

int tokeni_windows_tray_run(void)
{
    if (tokeni_ui_thread != NULL) {
        WaitForSingleObject(tokeni_ui_thread, INFINITE);
        CloseHandle(tokeni_ui_thread);
        tokeni_ui_thread = NULL;
    }
    return 0;
}

int tokeni_windows_ui_invoke(void (*operation)(void *), void *context)
{
    if (GetCurrentThreadId() == tokeni_ui_thread_id) { operation(context); return 1; }
    HWND window;
    AcquireSRWLockShared(&tokeni_state_lock);
    window = tokeni_window;
    ReleaseSRWLockShared(&tokeni_state_lock);
    if (window == NULL) { return 0; }
    tokeni_ui_invocation invocation = {operation, context};
    SendMessageW(window, tokeni_invoke_message, 0, (LPARAM)&invocation);
    return 1;
}

void tokeni_windows_tray_stop(void)
{
    HWND window;
    AcquireSRWLockShared(&tokeni_state_lock);
    window = tokeni_window;
    if (window != NULL) {
        PostMessageW(window, WM_CLOSE, 0, 0);
    }
    ReleaseSRWLockShared(&tokeni_state_lock);
}

#else
int tokeni_windows_dashboard_is_korean(void) { return 0; }
int tokeni_windows_desktop_ready(void) {return 0;}
int tokeni_windows_update_request(void) {return 0;}
int tokeni_windows_update_automatic(void) {return 0;}
void tokeni_windows_update_status(const char *t,int a) {(void)t;(void)a;}
int tokeni_windows_update_prepare(const char *v,const char *t) {(void)v;(void)t;return 0;}
void tokeni_windows_inventory_begin(void) {}
void tokeni_windows_inventory_append(int g,const char *i,const char *l) {(void)g;(void)i;(void)l;}
void tokeni_windows_inventory_commit(const char *s) {(void)s;}
int tokeni_windows_take_action(char *i,int c,char *t,int n) {(void)i;(void)c;(void)t;(void)n;return 0;}
void tokeni_windows_history_begin(void) {}
void tokeni_windows_history_append(double t, double p, const char *a, const char *b, const char *c, const char *d, const char *e) { (void)t;(void)p;(void)a;(void)b;(void)c;(void)d;(void)e; }
void tokeni_windows_history_commit(void) {}
void tokeni_windows_dashboard_begin_pets(void) {}
int tokeni_windows_dashboard_append_pet(const char *id, const char *label, int selected)
{ (void)id; (void)label; (void)selected; return 0; }
void tokeni_windows_dashboard_commit_pets(const char *summary, int eggs, const char *feedback)
{ (void)summary; (void)eggs; (void)feedback; }
int tokeni_windows_dashboard_take_pet_request(char *id, int capacity)
{ (void)id; (void)capacity; return 0; }
int tokeni_windows_dashboard_take_hatch_request(void) { return 0; }
int tokeni_windows_ui_invoke(void (*operation)(void *), void *context)
{ (void)operation; (void)context; return 0; }

void tokeni_windows_dashboard_begin_usage(void) {}
int tokeni_windows_dashboard_append_usage(const char *name, const char *status,
    const char *remaining, const char *reset, const char *tokens, const char *cost)
{ (void)name; (void)status; (void)remaining; (void)reset; (void)tokens; (void)cost; return 0; }
void tokeni_windows_dashboard_commit_usage(const char *summary, const char *status, int refreshing)
{ (void)summary; (void)status; (void)refreshing; }

int tokeni_windows_tray_start(
    const char *application_name_utf8,
    const char *tooltip_utf8)
{
    (void)application_name_utf8;
    (void)tooltip_utf8;
    return 0;
}

int tokeni_windows_tray_update_tooltip(const char *tooltip_utf8)
{
    (void)tooltip_utf8;
    return 0;
}

int tokeni_windows_tray_update_details(const char *details_utf8)
{
    (void)details_utf8;
    return 0;
}

int tokeni_windows_tray_begin_provider_options(void)
{
    return 0;
}

int tokeni_windows_tray_append_provider_option(
    const char *provider_id_utf8,
    const char *display_name_utf8,
    int enabled)
{
    (void)provider_id_utf8;
    (void)display_name_utf8;
    (void)enabled;
    return 0;
}

int tokeni_windows_tray_commit_provider_options(void)
{
    return 0;
}

int tokeni_windows_tray_take_provider_toggle_request(
    char *provider_id_utf8,
    int provider_id_capacity,
    int *enabled)
{
    (void)provider_id_utf8;
    (void)provider_id_capacity;
    (void)enabled;
    return 0;
}

int tokeni_windows_tray_take_refresh_request(void)
{
    return 0;
}

void tokeni_windows_tray_set_launch_at_login_enabled(int enabled)
{
    (void)enabled;
}

int tokeni_windows_tray_take_launch_at_login_request(void)
{
    return 0;
}

int tokeni_windows_tray_take_test_notification_request(void)
{
    return 0;
}

void tokeni_windows_tray_set_companion_enabled(int enabled)
{
    (void)enabled;
}

int tokeni_windows_tray_take_companion_toggle_request(void)
{
    return 0;
}

int tokeni_windows_tray_is_started(void)
{
    return 0;
}

int tokeni_windows_tray_notify(
    const char *title_utf8,
    const char *body_utf8)
{
    (void)title_utf8;
    (void)body_utf8;
    return 0;
}

int tokeni_windows_tray_run(void)
{
    return 0;
}

void tokeni_windows_tray_stop(void) {}

#endif
