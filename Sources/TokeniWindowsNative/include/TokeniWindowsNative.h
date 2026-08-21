#ifndef TOKENI_WINDOWS_NATIVE_H
#define TOKENI_WINDOWS_NATIVE_H

#ifdef __cplusplus
extern "C" {
#endif

int tokeni_windows_tray_start(
    const char *application_name_utf8,
    const char *tooltip_utf8);

int tokeni_windows_tray_update_tooltip(const char *tooltip_utf8);

int tokeni_windows_tray_update_details(const char *details_utf8);

// Provider options are staged and become visible atomically on commit. A
// failed append leaves the currently committed dashboard state unchanged.
int tokeni_windows_tray_begin_provider_options(void);

int tokeni_windows_tray_append_provider_option(
    const char *provider_id_utf8,
    const char *display_name_utf8,
    int enabled);

int tokeni_windows_tray_commit_provider_options(void);

// Returns one coalesced final-state request. The provider ID is always copied
// into caller-owned storage and must be revalidated by the application host.
int tokeni_windows_tray_take_provider_toggle_request(
    char *provider_id_utf8,
    int provider_id_capacity,
    int *enabled);

int tokeni_windows_tray_take_refresh_request(void);

void tokeni_windows_tray_set_launch_at_login_enabled(int enabled);

int tokeni_windows_tray_take_launch_at_login_request(void);

int tokeni_windows_tray_take_test_notification_request(void);

void tokeni_windows_tray_set_companion_enabled(int enabled);

int tokeni_windows_tray_take_companion_toggle_request(void);

int tokeni_windows_tray_is_started(void);

int tokeni_windows_tray_notify(
    const char *title_utf8,
    const char *body_utf8);

int tokeni_windows_tray_run(void);

void tokeni_windows_tray_stop(void);

int tokeni_windows_launch_at_login_is_enabled(
    const char *application_name_utf8);

int tokeni_windows_launch_at_login_set_enabled(
    const char *application_name_utf8,
    const char *executable_path_utf8,
    int enabled);

// Creates or updates a transparent, topmost companion overlay window. The
// frame is expressed in virtual-screen coordinates and is clamped to the
// current monitor bounds by the implementation.
int tokeni_windows_overlay_start(
    int x,
    int y,
    int width,
    int height);

int tokeni_windows_overlay_show(void);

int tokeni_windows_overlay_hide(void);

int tokeni_windows_overlay_set_frame(
    int x,
    int y,
    int width,
    int height);

int tokeni_windows_overlay_set_click_through(int enabled);

int tokeni_windows_overlay_set_asset_root(const char *path_utf8);

int tokeni_windows_overlay_set_state(
    int stage,
    int level,
    int species_index,
    int rarity_rank);

void tokeni_windows_overlay_stop(void);

int tokeni_windows_overlay_is_visible(void);

#ifdef __cplusplus
}
#endif

#endif
