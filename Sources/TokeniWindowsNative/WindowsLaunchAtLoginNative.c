#include "TokeniWindowsNative.h"

#ifdef _WIN32

#include <windows.h>
#include <wchar.h>

// Reg* APIs are exported by advapi32.lib. Keep this pragma for MSVC builds;
// a toolchain that does not honor it must link the native target with the same
// library explicitly.
#pragma comment(lib, "advapi32.lib")

static const wchar_t tokeni_run_key_path[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

static int tokeni_copy_utf8_to_wide(
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

static int tokeni_copy_quoted_path(
    const WCHAR *path,
    WCHAR *destination,
    size_t destination_count)
{
    if (path == NULL || destination == NULL || destination_count < 3) {
        return 0;
    }

    size_t path_length = wcslen(path);
    if (path_length == 0 || path_length + 3 > destination_count) {
        return 0;
    }

    for (size_t index = 0; index < path_length; index += 1) {
        if (path[index] == L'"') {
            return 0;
        }
    }

    destination[0] = L'"';
    CopyMemory(
        destination + 1,
        path,
        path_length * sizeof(destination[0]));
    destination[path_length + 1] = L'"';
    destination[path_length + 2] = L'\0';
    return 1;
}

int tokeni_windows_launch_at_login_is_enabled(
    const char *application_name_utf8)
{
    WCHAR application_name[512];
    if (!tokeni_copy_utf8_to_wide(
            application_name_utf8,
            application_name,
            (int)(sizeof(application_name) / sizeof(application_name[0]))))
    {
        return 0;
    }

    HKEY key = NULL;
    LONG status = RegOpenKeyExW(
        HKEY_CURRENT_USER,
        tokeni_run_key_path,
        0,
        KEY_QUERY_VALUE,
        &key);
    if (status != ERROR_SUCCESS) {
        return 0;
    }

    DWORD value_type = 0;
    DWORD value_size = 0;
    status = RegQueryValueExW(
        key,
        application_name,
        NULL,
        &value_type,
        NULL,
        &value_size);
    RegCloseKey(key);

    return status == ERROR_SUCCESS
        && (value_type == REG_SZ || value_type == REG_EXPAND_SZ)
        ? 1
        : 0;
}

int tokeni_windows_launch_at_login_set_enabled(
    const char *application_name_utf8,
    const char *executable_path_utf8,
    int enabled)
{
    WCHAR application_name[512];
    if (!tokeni_copy_utf8_to_wide(
            application_name_utf8,
            application_name,
            (int)(sizeof(application_name) / sizeof(application_name[0]))))
    {
        return 0;
    }

    HKEY key = NULL;
    if (enabled != 0) {
        WCHAR executable_path[32768];
        WCHAR command_line[32768];
        if (!tokeni_copy_utf8_to_wide(
                executable_path_utf8,
                executable_path,
                (int)(sizeof(executable_path)
                    / sizeof(executable_path[0])))
            || !tokeni_copy_quoted_path(
                executable_path,
                command_line,
                sizeof(command_line) / sizeof(command_line[0])))
        {
            return 0;
        }

        LONG status = RegCreateKeyExW(
            HKEY_CURRENT_USER,
            tokeni_run_key_path,
            0,
            NULL,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE,
            NULL,
            &key,
            NULL);
        if (status != ERROR_SUCCESS) {
            return 0;
        }

        DWORD byte_count = (DWORD)((wcslen(command_line) + 1)
            * sizeof(command_line[0]));
        status = RegSetValueExW(
            key,
            application_name,
            0,
            REG_SZ,
            (const BYTE *)command_line,
            byte_count);
        RegCloseKey(key);
        return status == ERROR_SUCCESS ? 1 : 0;
    }

    LONG status = RegOpenKeyExW(
        HKEY_CURRENT_USER,
        tokeni_run_key_path,
        0,
        KEY_SET_VALUE,
        &key);
    if (status == ERROR_FILE_NOT_FOUND) {
        return 1;
    }
    if (status != ERROR_SUCCESS) {
        return 0;
    }

    status = RegDeleteValueW(key, application_name);
    RegCloseKey(key);
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND ? 1 : 0;
}

#else

int tokeni_windows_launch_at_login_is_enabled(
    const char *application_name_utf8)
{
    (void)application_name_utf8;
    return 0;
}

int tokeni_windows_launch_at_login_set_enabled(
    const char *application_name_utf8,
    const char *executable_path_utf8,
    int enabled)
{
    (void)application_name_utf8;
    (void)executable_path_utf8;
    (void)enabled;
    return 0;
}

#endif
