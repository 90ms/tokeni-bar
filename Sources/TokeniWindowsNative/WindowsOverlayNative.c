#include "TokeniWindowsNative.h"

#ifdef _WIN32

#define COBJMACROS
#include <windows.h>
#include <objbase.h>
#include <wincodec.h>
#include <limits.h>
#include <stdlib.h>
#include <wchar.h>

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
static int tokeni_overlay_species_index;
static int tokeni_overlay_rarity_rank;
static wchar_t tokeni_overlay_asset_root[1024];
static wchar_t tokeni_overlay_loaded_path[2048];
static BYTE *tokeni_overlay_asset_pixels;
static UINT tokeni_overlay_asset_width;
static UINT tokeni_overlay_asset_height;
static int tokeni_overlay_asset_loaded;
static int tokeni_overlay_com_owned;

static void tokeni_overlay_release_asset(void)
{
    if (tokeni_overlay_asset_pixels != NULL) {
        free(tokeni_overlay_asset_pixels);
        tokeni_overlay_asset_pixels = NULL;
    }
    tokeni_overlay_asset_width = 0;
    tokeni_overlay_asset_height = 0;
    tokeni_overlay_asset_loaded = 0;
    tokeni_overlay_loaded_path[0] = L'\0';
}

static int tokeni_overlay_initialize_com(void)
{
    HRESULT result = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (result == S_OK || result == S_FALSE) {
        tokeni_overlay_com_owned = 1;
        return 1;
    }
    return 0;
}

static int tokeni_overlay_load_png(const wchar_t *path)
{
    if (path == NULL || path[0] == L'\0') {
        return 0;
    }

    IWICImagingFactory *factory = NULL;
    IWICBitmapDecoder *decoder = NULL;
    IWICBitmapFrameDecode *frame = NULL;
    IWICFormatConverter *converter = NULL;
    BYTE *pixels = NULL;
    UINT width = 0;
    UINT height = 0;
    int loaded = 0;

    HRESULT result = CoCreateInstance(
        &CLSID_WICImagingFactory,
        NULL,
        CLSCTX_INPROC_SERVER,
        &IID_IWICImagingFactory,
        (LPVOID *)&factory);
    if (FAILED(result)) {
        goto cleanup;
    }

    result = IWICImagingFactory_CreateDecoderFromFilename(
        factory,
        path,
        NULL,
        GENERIC_READ,
        WICDecodeMetadataCacheOnLoad,
        &decoder);
    if (FAILED(result)) {
        goto cleanup;
    }

    result = IWICBitmapDecoder_GetFrame(decoder, 0, &frame);
    if (FAILED(result)) {
        goto cleanup;
    }

    result = IWICImagingFactory_CreateFormatConverter(
        factory,
        &converter);
    if (FAILED(result)) {
        goto cleanup;
    }

    result = IWICFormatConverter_Initialize(
        converter,
        (IWICBitmapSource *)frame,
        &GUID_WICPixelFormat32bppPBGRA,
        WICBitmapDitherTypeNone,
        NULL,
        0.0,
        WICBitmapPaletteTypeCustom);
    if (FAILED(result)) {
        goto cleanup;
    }

    result = IWICBitmapSource_GetSize(
        (IWICBitmapSource *)converter,
        &width,
        &height);
    if (FAILED(result) || width == 0 || height == 0) {
        goto cleanup;
    }

    size_t stride = (size_t)width * 4U;
    size_t byte_count = stride * (size_t)height;
    if (stride > UINT_MAX || byte_count > UINT_MAX) {
        goto cleanup;
    }
    pixels = (BYTE *)malloc(byte_count);
    if (pixels == NULL) {
        goto cleanup;
    }

    result = IWICBitmapSource_CopyPixels(
        (IWICBitmapSource *)converter,
        NULL,
        (UINT)stride,
        (UINT)byte_count,
        pixels);
    if (FAILED(result)) {
        goto cleanup;
    }

    tokeni_overlay_asset_pixels = pixels;
    tokeni_overlay_asset_width = width;
    tokeni_overlay_asset_height = height;
    pixels = NULL;
    loaded = 1;

cleanup:
    if (pixels != NULL) {
        free(pixels);
    }
    if (converter != NULL) {
        IWICFormatConverter_Release(converter);
    }
    if (frame != NULL) {
        IWICBitmapFrameDecode_Release(frame);
    }
    if (decoder != NULL) {
        IWICBitmapDecoder_Release(decoder);
    }
    if (factory != NULL) {
        IWICImagingFactory_Release(factory);
    }
    return loaded;
}

static const wchar_t *tokeni_overlay_species_names[] = {
    L"bytebot",
    L"cachecat",
    L"stackfox",
    L"promptpup",
    L"nullslime",
    L"queryowl",
    L"patchpanda",
    L"loophare",
    L"relayray",
    L"kernelcrab",
};

static const wchar_t *tokeni_overlay_rarity_names[] = {
    L"normal",
    L"rare",
    L"epic",
    L"legendary",
};

static int tokeni_overlay_build_asset_path(
    wchar_t *path,
    size_t path_capacity)
{
    if (path == NULL
        || path_capacity == 0
        || tokeni_overlay_asset_root[0] == L'\0')
    {
        return 0;
    }

    int species_index = tokeni_overlay_species_index;
    if (species_index < 0
        || species_index >= (int)(sizeof(tokeni_overlay_species_names)
            / sizeof(tokeni_overlay_species_names[0])))
    {
        species_index = 0;
    }
    int rarity_rank = tokeni_overlay_rarity_rank;
    if (rarity_rank < 0
        || rarity_rank >= (int)(sizeof(tokeni_overlay_rarity_names)
            / sizeof(tokeni_overlay_rarity_names[0])))
    {
        rarity_rank = 0;
    }
    if (tokeni_overlay_stage == 0) {
        species_index = 0;
    }

    const wchar_t *file_name;
    wchar_t generated_name[64];
    if (tokeni_overlay_stage == 0) {
        file_name = L"egg.png";
    } else if (tokeni_overlay_stage == 1
        && species_index == 0
        && rarity_rank == 0)
    {
        file_name = L"baby.png";
    } else if (tokeni_overlay_stage == 1) {
        swprintf_s(
            generated_name,
            sizeof(generated_name) / sizeof(generated_name[0]),
            L"hatchling-%s.png",
            tokeni_overlay_rarity_names[rarity_rank]);
        file_name = generated_name;
    } else if (tokeni_overlay_stage == 2) {
        swprintf_s(
            generated_name,
            sizeof(generated_name) / sizeof(generated_name[0]),
            L"junior-%s.png",
            tokeni_overlay_rarity_names[rarity_rank]);
        file_name = generated_name;
    } else if (species_index == 0 && rarity_rank == 0) {
        file_name = L"adult.png";
    } else {
        swprintf_s(
            generated_name,
            sizeof(generated_name) / sizeof(generated_name[0]),
            L"adult-%s.png",
            tokeni_overlay_rarity_names[rarity_rank]);
        file_name = generated_name;
    }

    int written = swprintf_s(
        path,
        path_capacity,
        L"%s\\%s\\%s",
        tokeni_overlay_asset_root,
        tokeni_overlay_species_names[species_index],
        file_name);
    return written > 0 && (size_t)written < path_capacity;
}

static int tokeni_overlay_prepare_asset(void)
{
    wchar_t path[2048];
    if (!tokeni_overlay_build_asset_path(
            path,
            sizeof(path) / sizeof(path[0])))
    {
        return 0;
    }

    if (wcscmp(path, tokeni_overlay_loaded_path) == 0) {
        return tokeni_overlay_asset_loaded;
    }

    tokeni_overlay_release_asset();
    wcsncpy_s(
        tokeni_overlay_loaded_path,
        sizeof(tokeni_overlay_loaded_path)
            / sizeof(tokeni_overlay_loaded_path[0]),
        path,
        _TRUNCATE);
    tokeni_overlay_asset_loaded = tokeni_overlay_load_png(path);
    return tokeni_overlay_asset_loaded;
}

static int tokeni_overlay_paint_asset(
    HDC device_context,
    const RECT *bounds)
{
    if (!tokeni_overlay_prepare_asset()
        || tokeni_overlay_asset_width < 8
        || tokeni_overlay_asset_height < 6)
    {
        return 0;
    }

    int width = bounds->right - bounds->left;
    int height = bounds->bottom - bounds->top;
    int frame_width = (int)tokeni_overlay_asset_width / 8;
    int frame_height = (int)tokeni_overlay_asset_height / 6;
    int dimension = width < height ? width : height;
    dimension -= 16;
    if (frame_width <= 0 || frame_height <= 0 || dimension <= 0) {
        return 0;
    }

    BITMAPINFO bitmap_info;
    ZeroMemory(&bitmap_info, sizeof(bitmap_info));
    bitmap_info.bmiHeader.biSize = sizeof(bitmap_info.bmiHeader);
    bitmap_info.bmiHeader.biWidth = (LONG)tokeni_overlay_asset_width;
    bitmap_info.bmiHeader.biHeight = -(LONG)tokeni_overlay_asset_height;
    bitmap_info.bmiHeader.biPlanes = 1;
    bitmap_info.bmiHeader.biBitCount = 32;
    bitmap_info.bmiHeader.biCompression = BI_RGB;
    SetStretchBltMode(device_context, COLORONCOLOR);
    int frame = (int)((GetTickCount() / 250U) % 4U);
    int destination_x = (width - dimension) / 2;
    int destination_y = (height - dimension) / 2;
    int copied_scan_lines = StretchDIBits(
        device_context,
        destination_x,
        destination_y,
        dimension,
        dimension,
        frame * frame_width,
        0,
        frame_width,
        frame_height,
        tokeni_overlay_asset_pixels,
        &bitmap_info,
        DIB_RGB_COLORS,
        SRCCOPY);
    return copied_scan_lines != GDI_ERROR && copied_scan_lines > 0;
}

static void tokeni_overlay_paint_fallback(HDC device_context, const RECT *bounds)
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

    if (message == WM_TIMER) {
        InvalidateRect(window, NULL, FALSE);
        return 0;
    }

    if (message == WM_PAINT) {
        PAINTSTRUCT paint;
        HDC device_context = BeginPaint(window, &paint);
        if (device_context != NULL) {
            RECT bounds;
            GetClientRect(window, &bounds);
            HBRUSH transparent_brush = (HBRUSH)GetStockObject(BLACK_BRUSH);
            FillRect(device_context, &bounds, transparent_brush);
            if (!tokeni_overlay_paint_asset(device_context, &bounds)) {
                tokeni_overlay_paint_fallback(device_context, &bounds);
            }
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
        KillTimer(window, 1);
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

static int tokeni_overlay_start_on_ui_thread(
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
    tokeni_overlay_initialize_com();

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
        || !tokeni_overlay_update_click_through(tokeni_overlay_window)
        || SetTimer(tokeni_overlay_window, 1, 250, NULL) == 0)
    {
        tokeni_windows_overlay_stop();
        return 0;
    }

    return 1;
}

typedef struct { int x, y, width, height, result; } tokeni_overlay_start_request;
static void tokeni_overlay_start_operation(void *context)
{
    tokeni_overlay_start_request *request = (tokeni_overlay_start_request *)context;
    request->result = tokeni_overlay_start_on_ui_thread(request->x, request->y, request->width, request->height);
}

int tokeni_windows_overlay_start(int x, int y, int width, int height)
{
    tokeni_overlay_start_request request = {x, y, width, height, 0};
    if (!tokeni_windows_ui_invoke(tokeni_overlay_start_operation, &request)) { return 0; }
    return request.result;
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

int tokeni_windows_overlay_set_asset_root(const char *path_utf8)
{
    tokeni_overlay_asset_root[0] = L'\0';
    tokeni_overlay_release_asset();
    if (path_utf8 == NULL || path_utf8[0] == '\0') {
        return 1;
    }

    int required = MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        path_utf8,
        -1,
        NULL,
        0);
    if (required <= 0
        || (size_t)required
            > sizeof(tokeni_overlay_asset_root)
                / sizeof(tokeni_overlay_asset_root[0]))
    {
        return 0;
    }

    return MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        path_utf8,
        -1,
        tokeni_overlay_asset_root,
        (int)(sizeof(tokeni_overlay_asset_root)
            / sizeof(tokeni_overlay_asset_root[0]))) > 0 ? 1 : 0;
}

int tokeni_windows_overlay_set_state(
    int stage,
    int level,
    int species_index,
    int rarity_rank)
{
    tokeni_overlay_stage = stage < 0 ? 0 : (stage > 3 ? 3 : stage);
    tokeni_overlay_level = level < 0 ? 0 : level;
    tokeni_overlay_species_index = species_index < 0 ? 0 : species_index;
    tokeni_overlay_rarity_rank = rarity_rank < 0
        ? 0
        : (rarity_rank > 3 ? 3 : rarity_rank);
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
    tokeni_overlay_release_asset();
    if (tokeni_overlay_com_owned) {
        CoUninitialize();
        tokeni_overlay_com_owned = 0;
    }
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

int tokeni_windows_overlay_set_asset_root(const char *path_utf8)
{
    (void)path_utf8;
    return 0;
}

int tokeni_windows_overlay_set_state(
    int stage,
    int level,
    int species_index,
    int rarity_rank)
{
    (void)stage;
    (void)level;
    (void)species_index;
    (void)rarity_rank;
    return 0;
}

void tokeni_windows_overlay_stop(void) {}

int tokeni_windows_overlay_is_visible(void)
{
    return 0;
}

#endif
