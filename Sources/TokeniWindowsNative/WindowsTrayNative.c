#include "TokeniWindowsNative.h"

#ifdef _WIN32

#include <windows.h>
#include <shellapi.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")

static const wchar_t tokeni_window_class_name[] = L"TokeniBarTrayWindow";
static const UINT tokeni_tray_callback_message = WM_APP + 37;
static const UINT tokeni_tray_identifier = 1;
static HWND tokeni_window;
static HINSTANCE tokeni_instance;
static NOTIFYICONDATAW tokeni_icon;
static int tokeni_class_registered;
static LONG tokeni_refresh_requested;
static WCHAR tokeni_details[8192];

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

static void tokeni_remove_icon(void)
{
    if (tokeni_window != NULL) {
        Shell_NotifyIconW(NIM_DELETE, &tokeni_icon);
        tokeni_icon.hWnd = NULL;
        tokeni_window = NULL;
    }
}

static void tokeni_destroy_window(void)
{
    tokeni_remove_icon();
    if (tokeni_class_registered) {
        UnregisterClassW(tokeni_window_class_name, tokeni_instance);
        tokeni_class_registered = 0;
    }
}

static void tokeni_show_details(void)
{
    if (tokeni_window == NULL) {
        return;
    }

    SetForegroundWindow(tokeni_window);
    MessageBoxW(
        NULL,
        tokeni_details[0] == L'\0'
            ? L"Usage is not available yet."
            : tokeni_details,
        L"Tokeni Bar",
        MB_OK | MB_ICONINFORMATION);
}

static LRESULT CALLBACK tokeni_window_proc(
    HWND window,
    UINT message,
    WPARAM w_param,
    LPARAM l_param)
{
    (void)w_param;

    if (message == tokeni_tray_callback_message && l_param == WM_LBUTTONUP) {
        tokeni_show_details();
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
            AppendMenuW(menu, MF_STRING, 1, L"Show details");
            AppendMenuW(menu, MF_STRING, 2, L"Refresh now");
            AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
            AppendMenuW(menu, MF_STRING, 3, L"Quit Tokeni Bar");
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
                PostMessageW(window, WM_CLOSE, 0, 0);
            }
            DestroyMenu(menu);
        }

        return 0;
    }

    if (message == WM_CLOSE) {
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

    tokeni_instance = GetModuleHandleW(NULL);
    if (tokeni_instance == NULL) {
        return 0;
    }

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

    tokeni_window = CreateWindowExW(
        0,
        tokeni_window_class_name,
        tokeni_window_class_name,
        0,
        0,
        0,
        0,
        0,
        HWND_MESSAGE,
        NULL,
        tokeni_instance,
        NULL);
    if (tokeni_window == NULL) {
        tokeni_destroy_window();
        return 0;
    }

    ZeroMemory(&tokeni_icon, sizeof(tokeni_icon));
    tokeni_details[0] = L'\0';
    InterlockedExchange(&tokeni_refresh_requested, 0);
    tokeni_icon.cbSize = sizeof(tokeni_icon);
    tokeni_icon.hWnd = tokeni_window;
    tokeni_icon.uID = tokeni_tray_identifier;
    tokeni_icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tokeni_icon.uCallbackMessage = tokeni_tray_callback_message;
    tokeni_icon.hIcon = LoadIconW(NULL, MAKEINTRESOURCEW(32512));
    if (!tokeni_copy_utf8(
            tooltip_utf8,
            tokeni_icon.szTip,
            (int)(sizeof(tokeni_icon.szTip) / sizeof(tokeni_icon.szTip[0])))
        || !Shell_NotifyIconW(NIM_ADD, &tokeni_icon))
    {
        tokeni_destroy_window();
        return 0;
    }

    tokeni_icon.uVersion = NOTIFYICON_VERSION;
    Shell_NotifyIconW(NIM_SETVERSION, &tokeni_icon);
    return 1;
}

int tokeni_windows_tray_update_tooltip(const char *tooltip_utf8)
{
    if (tokeni_window == NULL
        || !tokeni_copy_utf8(
            tooltip_utf8,
            tokeni_icon.szTip,
            (int)(sizeof(tokeni_icon.szTip) / sizeof(tokeni_icon.szTip[0])))
        )
    {
        return 0;
    }

    tokeni_icon.uFlags = NIF_TIP;
    return Shell_NotifyIconW(NIM_MODIFY, &tokeni_icon) ? 1 : 0;
}

int tokeni_windows_tray_update_details(const char *details_utf8)
{
    if (tokeni_window == NULL) {
        return 0;
    }

    return tokeni_copy_utf8(
        details_utf8,
        tokeni_details,
        (int)(sizeof(tokeni_details) / sizeof(tokeni_details[0])));
}

int tokeni_windows_tray_take_refresh_request(void)
{
    return InterlockedExchange(&tokeni_refresh_requested, 0);
}

int tokeni_windows_tray_is_started(void)
{
    return tokeni_window != NULL ? 1 : 0;
}

int tokeni_windows_tray_notify(
    const char *title_utf8,
    const char *body_utf8)
{
    if (tokeni_window == NULL || title_utf8 == NULL || body_utf8 == NULL) {
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
        return 0;
    }

    notification.uFlags = NIF_INFO;
    notification.dwInfoFlags = NIIF_INFO;
    return Shell_NotifyIconW(NIM_MODIFY, &notification) ? 1 : 0;
}

int tokeni_windows_tray_run(void)
{
    MSG message;
    while (GetMessageW(&message, NULL, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    tokeni_destroy_window();
    return 0;
}

void tokeni_windows_tray_stop(void)
{
    if (tokeni_window != NULL) {
        PostMessageW(tokeni_window, WM_CLOSE, 0, 0);
    }
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

int tokeni_windows_tray_take_refresh_request(void)
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
