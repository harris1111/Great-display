#ifndef GD_SYSTEM_H
#define GD_SYSTEM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Display orientation through the MonitorPanel display manager.
 * Degrees are 0, 90, 180 or 270. Return values < 0 mean "unavailable". */
int gd_display_can_rotate(uint32_t display_id);
int gd_display_rotation(uint32_t display_id);
int gd_display_set_rotation(uint32_t display_id, int degrees);

/* HDR preference (the "High Dynamic Range" switch in System Settings). */
int gd_display_has_hdr(uint32_t display_id);
int gd_display_hdr_enabled(uint32_t display_id);
int gd_display_set_hdr_enabled(uint32_t display_id, int enabled);

/* Logical connection of a display (removes it from the desktop layout without
 * cutting power). Returns 0 on success. */
int gd_display_set_enabled(uint32_t display_id, int enabled);
int gd_display_enable_available(void);

/* System appearance and colour features. Getters return < 0 when unavailable. */
int gd_dark_mode(void);
int gd_set_dark_mode(int enabled);
int gd_night_shift(void);
int gd_set_night_shift(int enabled);
int gd_true_tone_supported(void);
int gd_true_tone(void);
int gd_set_true_tone(int enabled);

#ifdef __cplusplus
}
#endif

#endif
