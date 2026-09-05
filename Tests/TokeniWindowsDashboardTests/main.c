// This harness exercises real Win32 controls on the app's UI thread. It uses
// an isolated namespace and never reads provider data or user preferences.
#define TOKENI_DESKTOP_NAMESPACE L"TokeniBarDashboardTests"
#include "../../Sources/TokeniWindowsNative/WindowsTrayNative.c"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static void capture(HWND window, const char *path)
{
    RECT rect;
    GetWindowRect(window, &rect);
    int width = rect.right - rect.left, height = rect.bottom - rect.top;
    HDC screen = GetDC(window), memory = CreateCompatibleDC(screen);
    HBITMAP bitmap = CreateCompatibleBitmap(screen, width, height);
    HGDIOBJ previous = SelectObject(memory, bitmap);
    PrintWindow(window, memory, 0);
    SelectObject(memory, previous);
    BITMAPINFO info = {0};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    DWORD size = (DWORD)(width * height * 4);
    void *pixels = malloc(size);
    assert(pixels != NULL);
    assert(GetDIBits(memory, bitmap, 0, height, pixels, &info, DIB_RGB_COLORS));
    BITMAPFILEHEADER header = {0};
    header.bfType = 0x4d42;
    header.bfOffBits = sizeof(header) + sizeof(info.bmiHeader);
    header.bfSize = header.bfOffBits + size;
    FILE *file = fopen(path, "wb");
    assert(file != NULL);
    fwrite(&header, sizeof(header), 1, file);
    fwrite(&info.bmiHeader, sizeof(info.bmiHeader), 1, file);
    fwrite(pixels, size, 1, file);
    fclose(file);
    free(pixels);
    DeleteObject(bitmap);
    DeleteDC(memory);
    ReleaseDC(window, screen);
}

static void exercise_controls(void *context)
{
    (void)context;
    assert(GetCurrentThreadId() == tokeni_ui_thread_id);
    tokeni_show_details();
    assert(IsWindow(tokeni_dashboard_window));
    assert(GetWindowLongPtrW(tokeni_dashboard_window, GWL_STYLE) & WS_OVERLAPPEDWINDOW);
    for (int page = 0; page < 4; page++) {
        SendMessageW(tokeni_dashboard_window, WM_COMMAND, 400 + page, 0);
        assert(tokeni_destination == page);
        assert(IsWindowVisible(tokeni_usage_list) == (page < 2));
        assert(IsWindowVisible(tokeni_pet_picker) == (page == 2));
        assert(IsWindowVisible(tokeni_service_buttons[0]) == (page == 3));
    }
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 500, 0);
    assert(tokeni_windows_tray_take_launch_at_login_request());
    assert(!tokeni_windows_tray_take_launch_at_login_request());
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 501, 0);
    assert(tokeni_windows_tray_take_test_notification_request());
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 402, 0);
    assert(SendMessageW(tokeni_pet_picker, CB_GETCOUNT, 0, 0) == 1);
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 511, 0);
    char id[64];
    assert(tokeni_windows_dashboard_take_pet_request(id, sizeof(id)));
    assert(strcmp(id, "00000000-0000-0000-0000-000000000001") == 0);
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 512, 0);
    assert(tokeni_windows_dashboard_take_hatch_request());
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 401, 0);
    assert(ListView_GetItemCount(tokeni_usage_list) == 1);
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 101, 0);
    assert(tokeni_windows_tray_take_refresh_request());
    SendMessageW(tokeni_dashboard_window, WM_COMMAND, 400, 0);
    const char *path = getenv("TOKENI_GUI_CAPTURE");
    if (path != NULL) { UpdateWindow(tokeni_dashboard_window); capture(tokeni_dashboard_window, path); }
    SendMessageW(tokeni_dashboard_window, WM_CLOSE, 0, 0);
    assert(!IsWindowVisible(tokeni_dashboard_window));
    assert(tokeni_windows_tray_is_started());
    SendMessageW(tokeni_window, tokeni_open_window_message, 0, 0);
    assert(IsWindowVisible(tokeni_dashboard_window));
}

int main(void)
{
    assert(tokeni_windows_tray_start("Tokeni test", "Offline UI test"));
    tokeni_windows_dashboard_begin_usage();
    assert(tokeni_windows_dashboard_append_usage("Example provider", "Connected", "75%", "in 2h", "1234", "—"));
    tokeni_windows_dashboard_commit_usage("1 of 1 providers available\r\n\r\nSanitized offline UI fixture.", "Last refresh: just now", 0);
    tokeni_windows_dashboard_begin_pets();
    assert(tokeni_windows_dashboard_append_pet("00000000-0000-0000-0000-000000000001", "Companion · Level 3", 1));
    tokeni_windows_dashboard_commit_pets("One companion", 1, "");
    assert(tokeni_windows_ui_invoke(exercise_controls, NULL));
    tokeni_windows_tray_stop();
    tokeni_windows_tray_run();
    assert(!tokeni_windows_tray_is_started());
    puts("Tokeni Windows dashboard tests passed.");
    return 0;
}
