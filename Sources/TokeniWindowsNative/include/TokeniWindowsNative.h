#ifndef TOKENI_WINDOWS_NATIVE_H
#define TOKENI_WINDOWS_NATIVE_H

#ifdef __cplusplus
extern "C" {
#endif

int tokeni_windows_tray_start(
    const char *application_name_utf8,
    const char *tooltip_utf8);

int tokeni_windows_tray_update_tooltip(const char *tooltip_utf8);

int tokeni_windows_tray_run(void);

void tokeni_windows_tray_stop(void);

#ifdef __cplusplus
}
#endif

#endif
