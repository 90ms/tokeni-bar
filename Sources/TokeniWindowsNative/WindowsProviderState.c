#include "TokeniWindowsProviderState.h"

#include <stddef.h>
#include <string.h>

static int tokeni_provider_state_copy_id(
    const char *source,
    char destination[TOKENI_WINDOWS_PROVIDER_ID_CAPACITY])
{
    if (source == NULL || source[0] == '\0') {
        return 0;
    }
    size_t length = strlen(source);
    if (length >= TOKENI_WINDOWS_PROVIDER_ID_CAPACITY) {
        return 0;
    }
    memcpy(destination, source, length + 1);
    return 1;
}

static int tokeni_provider_state_index(
    const tokeni_windows_provider_state *state,
    const char *provider_id)
{
    for (int index = 0; index < state->count; index += 1) {
        if (strcmp(state->options[index].provider_id, provider_id) == 0) {
            return index;
        }
    }
    return -1;
}

void tokeni_windows_provider_state_reset(
    tokeni_windows_provider_state *state)
{
    if (state != NULL) {
        memset(state, 0, sizeof(*state));
    }
}

int tokeni_windows_provider_state_commit(
    tokeni_windows_provider_state *state,
    const tokeni_windows_provider_state_option *authoritative,
    int count)
{
    if (state == NULL
        || count < 0
        || count > TOKENI_WINDOWS_PROVIDER_MAX_COUNT
        || (count > 0 && authoritative == NULL))
    {
        return 0;
    }

    tokeni_windows_provider_state committed;
    tokeni_windows_provider_state_reset(&committed);
    for (int index = 0; index < count; index += 1) {
        if (!tokeni_provider_state_copy_id(
                authoritative[index].provider_id,
                committed.options[index].provider_id)
            || tokeni_provider_state_index(
                &committed,
                committed.options[index].provider_id) >= 0)
        {
            return 0;
        }
        committed.options[index].enabled = authoritative[index].enabled != 0;
        committed.count += 1;

        int previous_index = tokeni_provider_state_index(
            state,
            committed.options[index].provider_id);
        if (previous_index < 0 || !state->options[previous_index].pending) {
            continue;
        }
        tokeni_windows_provider_state_option *previous =
            &state->options[previous_index];
        if (previous->delivered
            && committed.options[index].enabled == previous->enabled)
        {
            continue;
        }
        committed.options[index].enabled = previous->enabled;
        committed.options[index].pending = 1;
        committed.options[index].delivered = previous->delivered;
    }
    *state = committed;
    return 1;
}

int tokeni_windows_provider_state_click(
    tokeni_windows_provider_state *state,
    const char *provider_id,
    int enabled)
{
    if (state == NULL || provider_id == NULL) {
        return 0;
    }
    int index = tokeni_provider_state_index(state, provider_id);
    if (index < 0) {
        return 0;
    }
    state->options[index].enabled = enabled != 0;
    state->options[index].pending = 1;
    state->options[index].delivered = 0;
    return 1;
}

int tokeni_windows_provider_state_take(
    tokeni_windows_provider_state *state,
    char *provider_id,
    int provider_id_capacity,
    int *enabled)
{
    if (state == NULL
        || provider_id == NULL
        || provider_id_capacity <= 0
        || enabled == NULL)
    {
        return 0;
    }
    for (int index = 0; index < state->count; index += 1) {
        tokeni_windows_provider_state_option *option = &state->options[index];
        if (!option->pending || option->delivered) {
            continue;
        }
        size_t required_capacity = strlen(option->provider_id) + 1;
        if ((size_t)provider_id_capacity < required_capacity) {
            return 0;
        }
        memcpy(provider_id, option->provider_id, required_capacity);
        *enabled = option->enabled;
        option->delivered = 1;
        return 1;
    }
    return 0;
}
