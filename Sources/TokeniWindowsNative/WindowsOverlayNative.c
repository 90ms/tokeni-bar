#include "TokeniWindowsNative.h"

#ifdef _WIN32

#include <windows.h>

#pragma comment(lib, "user32.lib")

static const wchar_t tokeni_overlay_window_class_name[] =
    L"TokeniBarCompanionOverlayWindow";

static HWND tokeni_overlay_window;
static HINSTANCE tokeni_overlay_instance;
static int tokeni_overlay_class_registered;
static int tokeni_overlay_click_through;
static int tokeni_overlay_visible;

static int tokeni_overlay_clamp_frame(
    int x,
    int y,
    int width,
    int height,
    RECT *frame)
{
    if (frame == NULL || width <= 0 || height <= 0) {
        return 0;
    }

    int virtual_x = GetSystemMetrics(SM_XVIRTUALSCREEN);
    int virtual_y = GetSystemMetrics(SM_YVIRTUALSCREEN);
    int virtual_width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    int virtual_height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (virtual_width <= 0 || virtual_height <= 0) {
        return 0;
    }

    int bounded_width = width < virtual_width ? width : virtual_width;
    int bounded_height = height < virtual_height ? height : virtual_height;
    long long virtual_right = (long long)virtual_x + virtual_width;
    long long virtual_bottom = (long long)virtual_y + virtual_height;
    long long maximum_x = virtual_right - bounded_width;
    long long maximum_y = virtual_bottom - bounded_height;
    long long bounded_x = x;
    long long bounded_y = y;

    if (bounded_x < virtual_x) {
        bounded_x = virtual_x;
    }
    if (bounded_x > maximum_x) {
        bounded_x = maximum_x;
    }
    if (bounded_y < virtual_y) {
        bounded_y = virtual_y;
    }
    if (bounded_y > maximum_y) {
        bounded_y = maximum_y;
    }

    frame->left = (LONG)bounded_x;
    frame->top = (LONG)bounded_y;
    frame->right = (LONG)(bounded_x + bounded_width);
    frame->bottom = (LONG)(bounded_y + bounded_height);
    return 1;
}

static int tokeni_overlay_update_click_through(HWND window)
{
    SetLastError(ERROR_SUCCESS);
    LONG_PTR extended_style = GetWindowLongPtrW(window, GWL_EXSTYLE);
    if (extended_style == 0 && GetLastError() != ERROR_SUCCESS) {
        return 0;
    }

    if (tokeni_overlay_click_through) {
        extended_style |= (LONG_PTR)WS_EX_TRANSPARENT;
    } else {
        extended_style &= ~((LONG_PTR)WS_EX_TRANSPARENT);
    }

    SetLastError(ERROR_SUCCESS);
    LONG_PTR previous_style = SetWindowLongPtrW(
        window,
        GWL_EXSTYLE,
        extended_style);
    if (previous_style == 0 && GetLastError() != ERROR_SUCCESS) {
        return 0;
    }

    return SetWindowPos(
        window,
        HWND_TOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE
            | SWP_NOSIZE
            | SWP_NOACTIVATE
            | SWP_NOOWNERZORDER
            | SWP_FRAMECHANGED) ? 1 : 0;
}

static void tokeni_overlay_unregister_class(void)
{
    if (tokeni_overlay_class_registered
        && tokeni_overlay_instance != NULL)
    {
        if (UnregisterClassW(
            tokeni_overlay_window_class_name,
            tokeni_overlay_instance))
        {
            tokeni_overlay_class_registered = 0;
            tokeni_overlay_instance = NULL;
        }
    }
}

static LRESULT CALLBACK tokeni_overlay_window_proc(
    HWND window,
    UINT message,
    WPARAM w_param,
    LPARAM l_param)
{
    (void)w_param;
    (void)l_param;

    if (message == WM_NCHITTEST && tokeni_overlay_click_through) {
        return HTTRANSPARENT;
    }

    if (message == WM_MOUSEACTIVATE) {
        return MA_NOACTIVATE;
    }

    if (message == WM_ERASEBKGND) {
        return 1;
    }

    if (message == WM_CLOSE) {
        DestroyWindow(window);
        return 0;
    }

    if (message == WM_DESTROY) {
        if (tokeni_overlay_window == window) {
            tokeni_overlay_window = NULL;
            tokeni_overlay_visible = 0;
        }
        return 0;
    }

    return DefWindowProcW(window, message, w_param, l_param);
}

static int tokeni_overlay_register_class(void)
{
    if (tokeni_overlay_class_registered
        && tokeni_overlay_instance != NULL)
    {
        return 1;
    }

    tokeni_overlay_instance = GetModuleHandleW(NULL);
    if (tokeni_overlay_instance == NULL) {
        return 0;
    }

    WNDCLASSEXW window_class;
    ZeroMemory(&window_class, sizeof(window_class));
    window_class.cbSize = sizeof(window_class);
    window_class.hInstance = tokeni_overlay_instance;
    window_class.lpfnWndProc = tokeni_overlay_window_proc;
    window_class.lpszClassName = tokeni_overlay_window_class_name;
    if (RegisterClassExW(&window_class) == 0) {
        tokeni_overlay_instance = NULL;
        return 0;
    }

    tokeni_overlay_class_registered = 1;
    return 1;
}

int tokeni_windows_overlay_start(
    int x,
    int y,
    int width,
    int height)
{
    RECT frame;
    if (!tokeni_overlay_clamp_frame(x, y, width, height, &frame)) {
        return 0;
    }

    if (tokeni_overlay_window != NULL) {
        return tokeni_windows_overlay_set_frame(
            frame.left,
            frame.top,
            frame.right - frame.left,
            frame.bottom - frame.top);
    }

    if (!tokeni_overlay_register_class()) {
        return 0;
    }

    DWORD extended_style = WS_EX_LAYERED
        | WS_EX_TOOLWINDOW
        | WS_EX_NOACTIVATE;
    if (tokeni_overlay_click_through) {
        extended_style |= WS_EX_TRANSPARENT;
    }

    tokeni_overlay_window = CreateWindowExW(
        extended_style,
        tokeni_overlay_window_class_name,
        tokeni_overlay_window_class_name,
        WS_POPUP,
        frame.left,
        frame.top,
        frame.right - frame.left,
        frame.bottom - frame.top,
        NULL,
        NULL,
        tokeni_overlay_instance,
        NULL);
    if (tokeni_overlay_window == NULL) {
        tokeni_overlay_unregister_class();
        return 0;
    }

    if (!SetLayeredWindowAttributes(
            tokeni_overlay_window,
            0,
            255,
            LWA_ALPHA)
        || !tokeni_overlay_update_click_through(tokeni_overlay_window))
    {
        tokeni_windows_overlay_stop();
        return 0;
    }

    return 1;
}

int tokeni_windows_overlay_show(void)
{
    if (tokeni_overlay_window == NULL) {
        return 0;
    }

    if (!SetWindowPos(
            tokeni_overlay_window,
            HWND_TOPMOST,
            0,
            0,
            0,
            0,
            SWP_NOMOVE
                | SWP_NOSIZE
                | SWP_NOACTIVATE
                | SWP_NOOWNERZORDER
                | SWP_SHOWWINDOW))
    {
        return 0;
    }

    UpdateWindow(tokeni_overlay_window);
    tokeni_overlay_visible = 1;
    return 1;
}

int tokeni_windows_overlay_hide(void)
{
    if (tokeni_overlay_window == NULL) {
        return 0;
    }

    ShowWindow(tokeni_overlay_window, SW_HIDE);
    tokeni_overlay_visible = 0;
    return 1;
}

int tokeni_windows_overlay_set_frame(
    int x,
    int y,
    int width,
    int height)
{
    if (tokeni_overlay_window == NULL) {
        return 0;
    }

    RECT frame;
    if (!tokeni_overlay_clamp_frame(x, y, width, height, &frame)) {
        return 0;
    }

    return SetWindowPos(
        tokeni_overlay_window,
        HWND_TOPMOST,
        frame.left,
        frame.top,
        frame.right - frame.left,
        frame.bottom - frame.top,
        SWP_NOACTIVATE | SWP_NOOWNERZORDER) ? 1 : 0;
}

int tokeni_windows_overlay_set_click_through(int enabled)
{
    tokeni_overlay_click_through = enabled != 0 ? 1 : 0;
    if (tokeni_overlay_window == NULL) {
        return 1;
    }

    return tokeni_overlay_update_click_through(tokeni_overlay_window);
}

void tokeni_windows_overlay_stop(void)
{
    HWND window = tokeni_overlay_window;
    if (window != NULL) {
        ShowWindow(window, SW_HIDE);
        tokeni_overlay_visible = 0;
        if (!DestroyWindow(window)) {
            PostMessageW(window, WM_CLOSE, 0, 0);
            return;
        }
    }

    tokeni_overlay_unregister_class();
}

int tokeni_windows_overlay_is_visible(void)
{
    return tokeni_overlay_window != NULL
        && tokeni_overlay_visible
        && IsWindowVisible(tokeni_overlay_window) ? 1 : 0;
}

#else

int tokeni_windows_overlay_start(
    int x,
    int y,
    int width,
    int height)
{
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    return 0;
}

int tokeni_windows_overlay_show(void)
{
    return 0;
}

int tokeni_windows_overlay_hide(void)
{
    return 0;
}

int tokeni_windows_overlay_set_frame(
    int x,
    int y,
    int width,
    int height)
{
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    return 0;
}

int tokeni_windows_overlay_set_click_through(int enabled)
{
    (void)enabled;
    return 0;
}

void tokeni_windows_overlay_stop(void) {}

int tokeni_windows_overlay_is_visible(void)
{
    return 0;
}

#endif
