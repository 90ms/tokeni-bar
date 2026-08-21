#include "TokeniWindowsProviderState.h"

#include <assert.h>
#include <string.h>

static tokeni_windows_provider_state_option option(
    const char *provider_id,
    int enabled)
{
    tokeni_windows_provider_state_option value = {0};
    size_t length = strlen(provider_id);
    assert(length < sizeof(value.provider_id));
    memcpy(value.provider_id, provider_id, length + 1);
    value.enabled = enabled;
    return value;
}

static void commit_one(
    tokeni_windows_provider_state *state,
    const char *provider_id,
    int enabled)
{
    tokeni_windows_provider_state_option value = option(provider_id, enabled);
    assert(tokeni_windows_provider_state_commit(state, &value, 1));
}

int main(void)
{
    tokeni_windows_provider_state state;
    char provider_id[TOKENI_WINDOWS_PROVIDER_ID_CAPACITY];
    int enabled = -1;
    tokeni_windows_provider_state_reset(&state);

    commit_one(&state, "codex", 1);
    assert(tokeni_windows_provider_state_click(&state, "codex", 0));
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    assert(strcmp(provider_id, "codex") == 0 && enabled == 0);
    assert(!tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));

    commit_one(&state, "codex", 1);
    assert(state.options[0].pending && state.options[0].delivered);
    assert(state.options[0].enabled == 0);
    commit_one(&state, "codex", 0);
    assert(!state.options[0].pending && !state.options[0].delivered);

    assert(tokeni_windows_provider_state_click(&state, "codex", 1));
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    assert(tokeni_windows_provider_state_click(&state, "codex", 0));
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    assert(enabled == 0);

    // ABA: the final click returns to the authoritative value but still must
    // be delivered before a matching commit can acknowledge it.
    commit_one(&state, "codex", 0);
    assert(tokeni_windows_provider_state_click(&state, "codex", 1));
    assert(tokeni_windows_provider_state_click(&state, "codex", 0));
    commit_one(&state, "codex", 0);
    assert(state.options[0].pending && !state.options[0].delivered);
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    commit_one(&state, "codex", 0);
    assert(!state.options[0].pending);

    tokeni_windows_provider_state_option values[] = {
        option("codex", 1),
        option("claude", 1),
    };
    assert(tokeni_windows_provider_state_commit(&state, values, 2));
    assert(tokeni_windows_provider_state_click(&state, "claude", 0));
    assert(tokeni_windows_provider_state_click(&state, "codex", 0));
    assert(!tokeni_windows_provider_state_take(
        &state, provider_id, 3, &enabled));
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    assert(strcmp(provider_id, "codex") == 0 && enabled == 0);
    assert(tokeni_windows_provider_state_take(
        &state, provider_id, sizeof(provider_id), &enabled));
    assert(strcmp(provider_id, "claude") == 0 && enabled == 0);

    return 0;
}
