#include "TokeniWindowsNative.h"
#include "TokeniWindowsProviderState.h"

#ifdef _WIN32

#include <windows.h>
#include <shellapi.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")

static const wchar_t tokeni_window_class_name[] = L"TokeniBarTrayWindow";
static const wchar_t tokeni_dashboard_class_name[] = L"TokeniBarDashboardWindow";
static const UINT tokeni_tray_callback_message = WM_APP + 37;
static const UINT tokeni_details_updated_message = WM_APP + 38;
static const UINT tokeni_provider_options_updated_message = WM_APP + 39;
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
        tokeni_scale_for_dpi(600, dpi),
        tokeni_scale_for_dpi(460, dpi),
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
    int button_width = tokeni_scale_for_dpi(112, dpi);
    int button_height = tokeni_scale_for_dpi(34, dpi);
    int content_width = max(client.right - (margin * 2), 0);
    int provider_columns = content_width >= tokeni_scale_for_dpi(360, dpi)
        ? 2
        : 1;
    int provider_rows = tokeni_dashboard_provider_count == 0
        ? 0
        : (tokeni_dashboard_provider_count + provider_columns - 1)
            / provider_columns;
    int provider_top = margin + header_height + status_height + gap;
    int provider_height = tokeni_dashboard_provider_count == 0
        ? 0
        : provider_label_height + (provider_rows * provider_row_height) + gap;
    int details_top = provider_top + provider_height;
    int details_height = max(
        client.bottom - details_top - button_height - (margin * 2),
        0);
    int button_top = client.bottom - margin - button_height;

    MoveWindow(
        tokeni_dashboard_header,
        margin,
        margin,
        content_width,
        header_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_status,
        margin,
        margin + header_height,
        content_width,
        status_height,
        TRUE);
    MoveWindow(
        tokeni_dashboard_provider_label,
        margin,
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
            margin + (column * (provider_column_width + gap)),
            provider_content_top + (row * provider_row_height),
            provider_column_width,
            provider_row_height,
            TRUE);
    }
    MoveWindow(
        tokeni_dashboard_details,
        margin,
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
}

static void tokeni_dashboard_apply_details(void)
{
    WCHAR details[8192];

    AcquireSRWLockShared(&tokeni_state_lock);
    CopyMemory(details, tokeni_details, sizeof(details));
    details[(sizeof(details) / sizeof(details[0])) - 1] = L'\0';
    ReleaseSRWLockShared(&tokeni_state_lock);

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
        tokeni_dashboard_header = CreateWindowExW(
            0,
            L"STATIC",
            L"Tokeni Bar",
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
            L"Provider usage",
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
            L"Hide",
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
        return 0;
    }

    if (message == WM_SIZE) {
        tokeni_dashboard_layout(window);
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
        minimums->ptMinTrackSize.x = tokeni_scale_for_dpi(420, dpi);
        minimums->ptMinTrackSize.y = tokeni_scale_for_dpi(440, dpi);
        return 0;
    }

    if (message == WM_COMMAND) {
        int identifier = LOWORD(w_param);
        if (identifier == tokeni_refresh_button_identifier) {
            InterlockedExchange(&tokeni_refresh_requested, 1);
            SetWindowTextW(tokeni_dashboard_status, L"Refreshing provider usage…");
            return 0;
        }
        if (identifier == tokeni_hide_button_identifier) {
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
        SetWindowTextW(tokeni_dashboard_status, L"Provider usage");
        return 0;
    }

    if (message == tokeni_provider_options_updated_message) {
        tokeni_dashboard_sync_provider_controls(window);
        tokeni_dashboard_layout(window);
        return 0;
    }

    if (message == WM_CLOSE) {
        ShowWindow(window, SW_HIDE);
        return 0;
    }

    if (message == WM_DESTROY) {
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
    tokeni_icon.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512));
    if (!Shell_NotifyIconW(NIM_ADD, &tokeni_icon)) {
        return 0;
    }

    tokeni_icon.uVersion = NOTIFYICON_VERSION;
    Shell_NotifyIconW(NIM_SETVERSION, &tokeni_icon);
    return 1;
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
    }

    tokeni_dashboard_apply_details();
    ShowWindow(tokeni_dashboard_window, SW_RESTORE);
    SetForegroundWindow(tokeni_dashboard_window);
    BringWindowToTop(tokeni_dashboard_window);
    SetFocus(tokeni_dashboard_details);
}

static LRESULT CALLBACK tokeni_window_proc(
    HWND window,
    UINT message,
    WPARAM w_param,
    LPARAM l_param)
{
    (void)w_param;

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
            DestroyWindow(tokeni_dashboard_window);
        }
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

int tokeni_windows_tray_start(
    const char *application_name_utf8,
    const char *tooltip_utf8)
{
    (void)application_name_utf8;
    if (tokeni_window != NULL) {
        return 1;
    }

    tokeni_enable_per_monitor_dpi_awareness();
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
    dashboard_class.hCursor = LoadCursorW(NULL, IDC_ARROW);
    dashboard_class.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512));
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

int tokeni_windows_tray_run(void)
{
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
    return 0;
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
