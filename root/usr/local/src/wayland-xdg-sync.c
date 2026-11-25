#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>

static const char *SELF_SO = "/usr/local/lib/libwayland_xdg_sync.so";

__attribute__((constructor))
static void strip_self_from_ld_preload(void) {
    const char *preload = getenv("LD_PRELOAD");
    if (!preload || !*preload) {
        return;
    }

    size_t len = strlen(preload);
    char *copy = malloc(len + 1);
    char *out = malloc(len + 1);
    if (!copy || !out) {
        free(copy);
        free(out);
        return;
    }
    memcpy(copy, preload, len + 1);
    out[0] = '\0';

    size_t out_len = 0;
    char *saveptr = NULL;
    for (char *tok = strtok_r(copy, ": ", &saveptr); tok;
         tok = strtok_r(NULL, ": ", &saveptr)) {
        if (strcmp(tok, SELF_SO) == 0) {
            continue;
        }
        size_t tlen = strlen(tok);
        if (out_len > 0) {
            out[out_len++] = ':';
        }
        memcpy(out + out_len, tok, tlen);
        out_len += tlen;
    }
    out[out_len] = '\0';

    if (out_len == 0) {
        unsetenv("LD_PRELOAD");
    } else {
        setenv("LD_PRELOAD", out, 1);
    }

    free(copy);
    free(out);
}

static void wakeup_done(void *data, struct wl_callback *cb, uint32_t cb_data) {
    (void)data;
    (void)cb_data;
    wl_callback_destroy(cb);
}

static const struct wl_callback_listener wakeup_listener = {
    .done = wakeup_done,
};

static void *resolve_wl_sym(const char *name) {
    void *sym = dlsym(RTLD_NEXT, name);
    if (sym) {
        return sym;
    }
    void *handle = dlopen("libwayland-client.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (!handle) {
        handle = dlopen("libwayland-client.so.0", RTLD_LAZY | RTLD_LOCAL);
    }
    return handle ? dlsym(handle, name) : NULL;
}

typedef int (*wl_display_get_fd_fn)(struct wl_display *);
typedef int (*wl_display_roundtrip_fn)(struct wl_display *);
typedef int (*wl_display_flush_fn)(struct wl_display *);

/*
 * Aquamarine 0.15.1 queries wl_display_get_fd right after CBackend::start(),
 * once createOutput() has queued the initial xdg_surface commit and before the
 * compositor loop can handle newOutput. Round-tripping once completes the
 * initial xdg_surface.configure + ack_configure handshake; queuing one sync
 * wakes the event loop on its first poll tick so idleCallbacks (newOutput) runs.
 */
int wl_display_get_fd(struct wl_display *display) {
    static int synced = 0;

    wl_display_get_fd_fn real_get_fd =
        (wl_display_get_fd_fn)resolve_wl_sym("wl_display_get_fd");
    if (!real_get_fd) {
        return -1;
    }

    if (!synced && display) {
        synced = 1;
        wl_display_roundtrip_fn real_roundtrip =
            (wl_display_roundtrip_fn)resolve_wl_sym("wl_display_roundtrip");
        wl_display_flush_fn real_flush =
            (wl_display_flush_fn)resolve_wl_sym("wl_display_flush");

        if (real_roundtrip) {
            real_roundtrip(display);
        }
        struct wl_callback *cb = wl_display_sync(display);
        if (cb) {
            wl_callback_add_listener(cb, &wakeup_listener, NULL);
        }
        if (real_flush) {
            real_flush(display);
        }
    }

    return real_get_fd(display);
}
