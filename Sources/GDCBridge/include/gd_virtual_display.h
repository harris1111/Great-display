#ifndef GD_VIRTUAL_DISPLAY_H
#define GD_VIRTUAL_DISPLAY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GDVirtualDisplayRef GDVirtualDisplayRef;

/* Creates a virtual display using the CoreGraphics virtual display facility.
 * Returns NULL on failure (gd_virtual_display_error() then holds the reason).
 * The returned reference must be released with gd_virtual_display_destroy(). */
GDVirtualDisplayRef *gd_virtual_display_create(const char *name,
                                               uint32_t width,
                                               uint32_t height,
                                               double refresh_rate,
                                               double mm_width,
                                               double mm_height,
                                               uint32_t serial_number,
                                               uint32_t vendor_id,
                                               uint32_t product_id,
                                               int hidpi);

/* Creates a virtual display publishing every given pixel mode (the first is
 * preferred). max_pixels_* bound later mode changes for this display. */
GDVirtualDisplayRef *gd_virtual_display_create_modes(const char *name,
                                                     const uint32_t *pixel_widths,
                                                     const uint32_t *pixel_heights,
                                                     uint32_t count,
                                                     double refresh_rate,
                                                     double mm_width,
                                                     double mm_height,
                                                     uint32_t serial_number,
                                                     uint32_t vendor_id,
                                                     uint32_t product_id,
                                                     int hidpi,
                                                     uint32_t max_pixels_wide,
                                                     uint32_t max_pixels_high);

/* Replaces the mode list of a live virtual display (same display ID, no
 * reconnect). Modes must fit the maximum given at creation. 0 on success. */
int gd_virtual_display_set_modes(GDVirtualDisplayRef *ref,
                                 const uint32_t *pixel_widths,
                                 const uint32_t *pixel_heights,
                                 uint32_t count,
                                 double refresh_rate,
                                 int hidpi);

void gd_virtual_display_destroy(GDVirtualDisplayRef *ref);

uint32_t gd_virtual_display_id(GDVirtualDisplayRef *ref);

/* Non-zero when the private CoreGraphics classes are present. */
int gd_virtual_display_available(void);

const char *gd_virtual_display_error(void);

#ifdef __cplusplus
}
#endif

#endif
