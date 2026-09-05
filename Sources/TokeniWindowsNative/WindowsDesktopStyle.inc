// Private implementation included by the desktop host, not a separate target.
#include <uxtheme.h>
#include <dwmapi.h>
#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "dwmapi.lib")

static LONG tokeni_language; // 0 system, 1 English, 2 Korean
static LONG tokeni_localization_started;
static LONG tokeni_appearance; // 0 system, 1 light, 2 dark
static HWND tokeni_language_picker, tokeni_theme_picker;
static COLORREF tokeni_background, tokeni_surface, tokeni_foreground, tokeni_muted, tokeni_accent;
static HBRUSH tokeni_background_brush, tokeni_surface_brush;
static int tokeni_dark;

typedef struct { const WCHAR *en; const WCHAR *ko; } tokeni_translation;
static const tokeni_translation tokeni_translations[] = {
    {L"Eggs", L"알 보관함"}, {L"Sell selected item",L"선택한 알 판매"}, {L"Sell the selected egg?",L"선택한 알을 판매할까요?"},
    {L"Check automatically",L"업데이트 자동 확인"},
    {L"Sell companion",L"선택한 펫 판매"}, {L"Sell this companion? Active and last companions cannot be sold.",L"이 펫을 판매할까요? 활동 중이거나 마지막 남은 펫은 판매할 수 없습니다."},
    {L"Home", L"홈"}, {L"Usage", L"사용량"}, {L"Companions", L"펫"}, {L"Settings", L"설정"},
    {L"Your usage and companion at a glance", L"사용량과 펫의 성장을 한눈에 확인하세요"},
    {L"Verified usage from your connected providers", L"연결된 제공자의 확인된 사용량"},
    {L"Grow together with your everyday work", L"매일의 작업과 함께 자라는 친구"},
    {L"Make Tokeni Bar work your way", L"나에게 맞는 Tokeni Bar 설정"},
    {L"Providers", L"사용할 제공자"}, {L"Provider", L"제공자"}, {L"Provider usage", L"제공자 사용량"},
    {L"Status", L"상태"}, {L"Remaining", L"잔여량"}, {L"Next reset", L"다음 초기화"},
    {L"Tokens", L"토큰"}, {L"Cost (USD)", L"비용 (USD)"},
    {L"Refresh now", L"새로 고침"}, {L"Refreshing…", L"갱신 중…"}, {L"Refreshing provider usage…", L"사용량 갱신 중…"},
    {L"Hide to tray", L"트레이로 숨기기"}, {L"Show details", L"앱 열기"},
    {L"Start with Windows", L"Windows 시작 시 실행"},
    {L"Start with Windows: On", L"자동 시작: 켜짐"}, {L"Start with Windows: Off", L"자동 시작: 꺼짐"},
    {L"Send test notification", L"알림 테스트"}, {L"Desktop companion", L"데스크톱 펫"},
    {L"Desktop companion: On", L"데스크톱 펫: 켜짐"}, {L"Desktop companion: Off", L"데스크톱 펫: 꺼짐"},
    {L"Show companion", L"데스크톱 펫 표시"}, {L"Quit Tokeni Bar", L"Tokeni Bar 종료"},
    {L"Owned companions", L"보유한 펫"}, {L"Set growth target", L"성장 대상으로 지정"}, {L"Open an egg", L"알 열기"},
    {L"Usage is not available yet.", L"아직 사용량 데이터가 없습니다."},
    {L"System language", L"시스템 언어"}, {L"System theme", L"시스템 테마"},
    {L"Light", L"밝게"}, {L"Dark", L"어둡게"},
    {L"History", L"기록"}, {L"Last 24 hours", L"최근 24시간"}, {L"Last 7 days", L"최근 7일"},
    {L"Last 30 days", L"최근 30일"}, {L"All providers", L"모든 제공자"},
    {L"Collected at", L"기록 시각"}, {L"Quota remaining (%)", L"할당량 잔여 비율 (%)"},
    {L"No history in this period", L"이 기간에는 기록이 없습니다"},
    {L"Set as desktop pet", L"대표 펫으로 지정"}, {L"Save nickname", L"이름 저장"},
    {L"Collection", L"컬렉션"}, {L"Shop & rewards", L"상점과 보상"},
    {L"Daily check-in", L"출석 보상 받기"}, {L"Buy selected item", L"선택한 상품 구매"},
    {L"Equip selected item", L"선택한 꾸미기 장착"}, {L"Check for updates", L"업데이트 확인"},
    {L"Install update", L"업데이트 설치"}, {L"Automatic updates", L"자동 업데이트"},
    {L"Language", L"언어"}, {L"Appearance", L"화면 모드"}, {L"Nickname", L"펫 이름"},
    {L"Move desktop pet", L"펫 이동 허용"}, {L"Reduce motion", L"움직임 줄이기"},
    {L"Small", L"작게"}, {L"Medium", L"보통"}, {L"Large", L"크게"},
    {L"Provider connections\r\n\r\nEnable the providers you use above. Sign in through each provider's own CLI or application, then refresh Tokeni Bar.\r\n\r\nClosing this window keeps Tokeni Bar in the tray. Use Quit Tokeni Bar to stop it.\r\n\r\n",
     L"제공자 연결\r\n\r\n위에서 사용할 제공자를 선택하세요. 각 제공자의 CLI 또는 앱에서 로그인한 다음 Tokeni Bar를 새로 고치세요.\r\n\r\n창을 닫아도 트레이에서 계속 실행됩니다. 완전히 종료하려면 Tokeni Bar 종료를 선택하세요.\r\n\r\n"},
};

int tokeni_windows_dashboard_is_korean(void)
{
    // Headless formatters/tests have a deterministic default. The desktop
    // opts into the user's preference before it creates any controls.
    if (!InterlockedCompareExchange(&tokeni_localization_started, 0, 0)) { return 0; }
    LONG preference = InterlockedCompareExchange(&tokeni_language, 0, 0);
    return preference == 2 || (preference == 0 && PRIMARYLANGID(GetUserDefaultUILanguage()) == LANG_KOREAN);
}
static const WCHAR *tokeni_text(const WCHAR *value)
{
    if (!value || IS_INTRESOURCE(value)) { return value; }
    int korean = tokeni_windows_dashboard_is_korean();
    for (size_t i = 0; i < sizeof(tokeni_translations) / sizeof(tokeni_translations[0]); i++) {
        if (!wcscmp(value, tokeni_translations[i].en) || !wcscmp(value, tokeni_translations[i].ko)) {
            return korean ? tokeni_translations[i].ko : tokeni_translations[i].en;
        }
    }
    return value;
}
static BOOL tokeni_set_text(HWND window, const WCHAR *text) { return SetWindowTextW(window, tokeni_text(text)); }
static HWND tokeni_create_control(DWORD ex, const WCHAR *cls, const WCHAR *text, DWORD style,
    int x, int y, int w, int h, HWND parent, HMENU menu, HINSTANCE instance, void *data)
{
    if (parent && !wcscmp(cls, L"BUTTON") && (style & BS_TYPEMASK) == BS_PUSHBUTTON) {
        style = (style & ~BS_TYPEMASK) | BS_OWNERDRAW;
    }
    return CreateWindowExW(ex, cls, tokeni_text(text), style, x, y, w, h, parent, menu, instance, data);
}
// Translate only UI labels; provider names and values that are not keys pass through.
#define SetWindowTextW tokeni_set_text
#define CreateWindowExW tokeni_create_control

static void tokeni_save_preferences(void)
{
#ifndef TOKENI_DESKTOP_TEST
    HKEY key;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\TokeniBar\\Desktop", 0, NULL, 0,
        KEY_SET_VALUE, NULL, &key, NULL) == ERROR_SUCCESS) {
        DWORD value = tokeni_language;
        RegSetValueExW(key, L"Language", 0, REG_DWORD, (BYTE *)&value, sizeof(value));
        value = tokeni_appearance;
        RegSetValueExW(key, L"Appearance", 0, REG_DWORD, (BYTE *)&value, sizeof(value));
        RegCloseKey(key);
    }
#endif
}
static void tokeni_load_preferences(void)
{
    InterlockedExchange(&tokeni_localization_started, 1);
#ifndef TOKENI_DESKTOP_TEST
    DWORD value = 0, size = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\TokeniBar\\Desktop", L"Language", RRF_RT_REG_DWORD,
        NULL, &value, &size) == ERROR_SUCCESS && value <= 2) { tokeni_language = value; }
    value = 0; size = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\TokeniBar\\Desktop", L"Appearance", RRF_RT_REG_DWORD,
        NULL, &value, &size) == ERROR_SUCCESS && value <= 2) { tokeni_appearance = value; }
#endif
}
static BOOL CALLBACK tokeni_style_child(HWND child, LPARAM unused)
{
    (void)unused;
    WCHAR label[1024], cls[64];
    GetClassNameW(child, cls, 64);
    if (wcscmp(cls, L"Edit") && wcscmp(cls, WC_LISTVIEWW) && wcscmp(cls, L"ComboBox")) {
        GetWindowTextW(child, label, 1024); SetWindowTextW(child, label);
    }
    SetWindowTheme(child, tokeni_dark ? L"DarkMode_Explorer" : L"Explorer", NULL);
    SendMessageW(child, WM_SETFONT, (WPARAM)tokeni_dashboard_font, FALSE);
    InvalidateRect(child, NULL, TRUE);
    return TRUE;
}
static void tokeni_apply_style(HWND window)
{
    DWORD light = 1, size = sizeof(light);
    RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        L"AppsUseLightTheme", RRF_RT_REG_DWORD, NULL, &light, &size);
    HIGHCONTRASTW contrast = {sizeof(contrast)};
    SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
    tokeni_dark = tokeni_appearance == 2 || (tokeni_appearance == 0 && !light);
    tokeni_background = tokeni_dark ? RGB(16,22,32) : RGB(244,247,251);
    tokeni_surface = tokeni_dark ? RGB(28,37,51) : RGB(255,255,255);
    tokeni_foreground = tokeni_dark ? RGB(236,242,250) : RGB(26,39,59);
    tokeni_muted = tokeni_dark ? RGB(169,183,205) : RGB(79,97,122);
    tokeni_accent = tokeni_dark ? RGB(102,217,193) : RGB(0,113,101);
    if (contrast.dwFlags & HCF_HIGHCONTRASTON) {
        tokeni_background = tokeni_surface = GetSysColor(COLOR_WINDOW);
        tokeni_foreground = tokeni_muted = GetSysColor(COLOR_WINDOWTEXT);
        tokeni_accent = GetSysColor(COLOR_HIGHLIGHT);
    }
    if (tokeni_background_brush) { DeleteObject(tokeni_background_brush); }
    if (tokeni_surface_brush) { DeleteObject(tokeni_surface_brush); }
    tokeni_background_brush = CreateSolidBrush(tokeni_background);
    tokeni_surface_brush = CreateSolidBrush(tokeni_surface);
    BOOL dark = tokeni_dark;
    DwmSetWindowAttribute(window, 20, &dark, sizeof(dark));
    EnumChildWindows(window, tokeni_style_child, 0);
    SendMessageW(tokeni_dashboard_header, WM_SETFONT, (WPARAM)tokeni_dashboard_header_font, FALSE);
    ListView_SetBkColor(tokeni_usage_list, tokeni_surface);
    ListView_SetTextBkColor(tokeni_usage_list, tokeni_surface);
    ListView_SetTextColor(tokeni_usage_list, tokeni_foreground);
    for (int column = 0; column < 6; column++) {
        WCHAR text[128]; LVCOLUMNW item = {0}; item.mask = LVCF_TEXT; item.pszText = text; item.cchTextMax = 128;
        SendMessageW(tokeni_usage_list, LVM_GETCOLUMNW, column, (LPARAM)&item);
        item.pszText = (WCHAR *)tokeni_text(text);
        SendMessageW(tokeni_usage_list, LVM_SETCOLUMNW, column, (LPARAM)&item);
    }
    InvalidateRect(window, NULL, TRUE);
}
static LRESULT tokeni_draw_button(DRAWITEMSTRUCT *item)
{
    WCHAR text[256]; GetWindowTextW(item->hwndItem, text, 256);
    RECT rect = item->rcItem;
    int selected = item->CtlID >= 400 && item->CtlID < 404 && (int)item->CtlID - 400 == tokeni_destination;
    COLORREF fill = selected ? tokeni_accent : tokeni_surface;
    HBRUSH brush = CreateSolidBrush(fill);
    FillRect(item->hDC, &rect, brush); DeleteObject(brush);
    SetBkMode(item->hDC, TRANSPARENT);
    SetTextColor(item->hDC, (item->itemState & ODS_DISABLED) ? tokeni_muted : selected ? (tokeni_dark ? RGB(16,22,32) : RGB(255,255,255)) : tokeni_foreground);
    HGDIOBJ font = SelectObject(item->hDC, tokeni_dashboard_font);
    InflateRect(&rect, -10, -4);
    DrawTextW(item->hDC, text, -1, &rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    SelectObject(item->hDC, font);
    if (item->itemState & ODS_FOCUS) { DrawFocusRect(item->hDC, &rect); }
    return TRUE;
}
