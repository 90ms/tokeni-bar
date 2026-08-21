#ifndef TOKENI_WINDOWS_PROVIDER_STATE_H
#define TOKENI_WINDOWS_PROVIDER_STATE_H

#ifdef __cplusplus
extern "C" {
#endif

#define TOKENI_WINDOWS_PROVIDER_MAX_COUNT 16
#define TOKENI_WINDOWS_PROVIDER_ID_CAPACITY 64

typedef struct tokeni_windows_provider_state_option {
    char provider_id[TOKENI_WINDOWS_PROVIDER_ID_CAPACITY];
    int enabled;
    int pending;
    int delivered;
} tokeni_windows_provider_state_option;

typedef struct tokeni_windows_provider_state {
    tokeni_windows_provider_state_option
        options[TOKENI_WINDOWS_PROVIDER_MAX_COUNT];
    int count;
} tokeni_windows_provider_state;

void tokeni_windows_provider_state_reset(
    tokeni_windows_provider_state *state);

int tokeni_windows_provider_state_commit(
    tokeni_windows_provider_state *state,
    const tokeni_windows_provider_state_option *authoritative,
    int count);

int tokeni_windows_provider_state_click(
    tokeni_windows_provider_state *state,
    const char *provider_id,
    int enabled);

int tokeni_windows_provider_state_take(
    tokeni_windows_provider_state *state,
    char *provider_id,
    int provider_id_capacity,
    int *enabled);

#ifdef __cplusplus
}
#endif

#endif
