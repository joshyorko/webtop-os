#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>

struct gbm_device;
struct gbm_bo;

#define GBM_BO_USE_SCANOUT     (1U << 0)
#define GBM_BO_USE_RENDERING   (1U << 2)
#define GBM_BO_USE_LINEAR      (1U << 4)
#define DRM_FORMAT_MOD_INVALID 0x00ffffffffffffffULL

struct gbm_bo *gbm_bo_create(
    struct gbm_device *gbm,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags);

typedef struct gbm_bo *(*gbm_bo_create_fn)(
    struct gbm_device *, uint32_t, uint32_t, uint32_t, uint32_t);
typedef uint64_t (*gbm_bo_get_modifier_fn)(struct gbm_bo *);
typedef int (*gbm_bo_get_plane_count_fn)(struct gbm_bo *);
typedef void (*gbm_bo_destroy_fn)(struct gbm_bo *);

static void *resolve_gbm_sym(const char *name) {
    void *sym = dlsym(RTLD_NEXT, name);
    if (sym && sym != (void *)gbm_bo_create) {
        return sym;
    }

    /* Fall back to libgbm.so.1 directly when loaded with RTLD_LOCAL (e.g. Python extensions). */
    void *handle = dlopen("libgbm.so.1", RTLD_LAZY | RTLD_NOLOAD);
    if (!handle) {
        handle = dlopen("libgbm.so.1", RTLD_LAZY | RTLD_LOCAL);
    }
    if (!handle) {
        return NULL;
    }

    sym = dlsym(handle, name);
    if (sym == (void *)gbm_bo_create) {
        return NULL;
    }
    return sym;
}

static int is_valid_single_plane(uint64_t mod, int planes) {
    if (planes != 1) {
        return 0;
    }
    if (mod == 0ULL) {
        return 1;
    }
    return ((mod >> 56) != 0ULL) && (mod != DRM_FORMAT_MOD_INVALID);
}

struct gbm_bo *gbm_bo_create(
    struct gbm_device *gbm,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags) {
    static _Thread_local int in_guard = 0;

    gbm_bo_create_fn real_create = (gbm_bo_create_fn)resolve_gbm_sym("gbm_bo_create");
    if (!real_create) {
        return NULL;
    }
    if (in_guard) {
        return real_create(gbm, width, height, format, flags);
    }

    in_guard = 1;
    struct gbm_bo *bo = real_create(gbm, width, height, format, flags);
    if (!bo || !(flags & GBM_BO_USE_RENDERING) ||
        (flags & (GBM_BO_USE_SCANOUT | GBM_BO_USE_LINEAR))) {
        in_guard = 0;
        return bo;
    }

    gbm_bo_get_modifier_fn real_get_mod =
        (gbm_bo_get_modifier_fn)resolve_gbm_sym("gbm_bo_get_modifier");
    gbm_bo_get_plane_count_fn real_get_planes =
        (gbm_bo_get_plane_count_fn)resolve_gbm_sym("gbm_bo_get_plane_count");
    gbm_bo_destroy_fn real_destroy =
        (gbm_bo_destroy_fn)resolve_gbm_sym("gbm_bo_destroy");
    if (!real_get_mod || !real_get_planes || !real_destroy) {
        in_guard = 0;
        return bo;
    }

    if (is_valid_single_plane(real_get_mod(bo), real_get_planes(bo))) {
        in_guard = 0;
        return bo;
    }

    /* Retry with SCANOUT, then LINEAR so Mesa yields a valid single-plane modifier for EGL/VAAPI. */
    struct gbm_bo *scanout = real_create(gbm, width, height, format, flags | GBM_BO_USE_SCANOUT);
    if (scanout && is_valid_single_plane(real_get_mod(scanout), real_get_planes(scanout))) {
        real_destroy(bo);
        in_guard = 0;
        return scanout;
    }

    struct gbm_bo *linear = real_create(gbm, width, height, format, flags | GBM_BO_USE_LINEAR);
    if (linear && is_valid_single_plane(real_get_mod(linear), real_get_planes(linear))) {
        if (scanout) {
            real_destroy(scanout);
        }
        real_destroy(bo);
        in_guard = 0;
        return linear;
    }

    if (linear) {
        real_destroy(linear);
    }
    if (scanout) {
        real_destroy(scanout);
    }
    in_guard = 0;
    return bo;
}
