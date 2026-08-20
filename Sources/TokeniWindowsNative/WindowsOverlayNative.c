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
static int tokeni_overlay_stage;
static int tokeni_overlay_level;

static void tokeni_overlay_paint(HDC device_context, const RECT *bounds)
{
    int width = bounds->right - bounds->left;
    int height = bounds->bottom - bounds->top;
    int dimension = width < height ? width : height;
    int center_x = width / 2;
    int center_y = height / 2;
    int radius = dimension / 3;
    COLORREF body_color;

    switch (tokeni_overlay_stage) {
    case 0:
        body_color = RGB(255, 240, 179);
        radius = dimension / 4;
        break;
    case 1:
        body_color = RGB(66, 214, 206);
        break;
    case 2:
        body_color = RGB(8, 169, 174);
        break;
    default:
        body_color = tokeni_overlay_level >= 10
            ? RGB(255, 113, 99)
            : RGB(11, 58, 99);
        break;
    }

    HBRUSH body_brush = CreateSolidBrush(body_color);
    if (body_brush != NULL) {
        HGDIOBJ previous_brush = SelectObject(device_context, body_brush);
        Ellipse(
            device_context,
            center_x - radius,
            center_y - radius,
            center_x + radius,
            center_y + radius);
        SelectObject(device_context, previous_brush);
        DeleteObject(body_brush);
    }

    if (tokeni_overlay_stage != 0) {
        HBRUSH eye_brush = CreateSolidBrush(RGB(7, 27, 53));
        if (eye_brush != NULL) {
            HGDIOBJ previous_brush = SelectObject(device_context, eye_brush);
            int eye_radius = radius / 10;
            if (eye_radius < 2) {
                eye_radius = 2;
            }
            int eye_y = center_y - radius / 4;
            Ellipse(
                device_context,
                center_x - radius / 3 - eye_radius,
                eye_y - eye_radius,
                center_x - radius / 3 + eye_radius,
                eye_y + eye_radius);
            Ellipse(
                device_context,
                center_x + radius / 3 - eye_radius,
                eye_y - eye_radius,
                center_x + radius / 3 + eye_radius,
                eye_y + eye_radius);
            SelectObject(device_context, previous_brush);
            DeleteObject(eye_brush);
        }
    }
}

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

    if (message == WM_PAINT) {
        PAINTSTRUCT paint;
        HDC device_context = BeginPaint(window, &paint);
        if (device_context != NULL) {
            RECT bounds;
            GetClientRect(window, &bounds);
            HBRUSH transparent_brush = (HBRUSH)GetStockObject(BLACK_BRUSH);
            FillRect(device_context, &bounds, transparent_brush);
            tokeni_overlay_paint(device_context, &bounds);
            EndPaint(window, &paint);
        }
        return 0;
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
            RGB(0, 0, 0),
            0,
            LWA_COLORKEY)
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

int tokeni_windows_overlay_set_state(int stage, int level)
{
    tokeni_overlay_stage = stage < 0 ? 0 : (stage > 3 ? 3 : stage);
    tokeni_overlay_level = level < 0 ? 0 : level;
    if (tokeni_overlay_window != NULL) {
        InvalidateRect(tokeni_overlay_window, NULL, TRUE);
        UpdateWindow(tokeni_overlay_window);
    }
    return 1;
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

int tokeni_windows_overlay_set_state(int stage, int level)
{
    (void)stage;
    (void)level;
    return 0;
}

void tokeni_windows_overlay_stop(void) {}

int tokeni_windows_overlay_is_visible(void)
{
    return 0;
}

#endif
