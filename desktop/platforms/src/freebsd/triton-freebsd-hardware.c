/*
 * Persistent FreeBSD brightness/OSS mixer bridge for Quickshell.
 *
 * The kernel interfaces provide ioctls but no state-change subscription.
 * Keep the device descriptors open and poll cheaply in-process instead of
 * launching backlight(1), mixer(8), and a shell every few milliseconds.
 */

#include <sys/backlight.h>
#include <sys/ioctl.h>
#include <sys/soundcard.h>

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define BACKLIGHT_DEVICE "/dev/backlight/backlight0"
#define MIXER_DEVICE "/dev/mixer0"
#define ACTIVE_INTERVAL_MS 40
#define IDLE_INTERVAL_MS 200
#define ACTIVE_WINDOW_MS 2000
#define REOPEN_INTERVAL_MS 5000

struct state {
	int backlight_fd;
	int mixer_fd;
	int brightness;
	int volume;
	int muted;
	int mixer_modify_counter;
	bool brightness_known;
	bool volume_known;
	bool mute_known;
	bool force_audio_read;
	long long active_until;
	long long next_reopen;
};

static long long
monotonic_ms(void)
{
	struct timespec ts;

	if (clock_gettime(CLOCK_MONOTONIC, &ts) == -1)
		return (0);
	return ((long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

static int
clamp_percent(int value)
{
	if (value < 0)
		return (0);
	if (value > 100)
		return (100);
	return (value);
}

static void
emit_brightness(struct state *state, int value)
{
	value = clamp_percent(value);
	if (state->brightness_known && state->brightness == value)
		return;
	state->brightness = value;
	state->brightness_known = true;
	printf("brightness %d\n", value);
	fflush(stdout);
}

static void
emit_audio(struct state *state, int volume, int muted)
{
	volume = clamp_percent(volume);
	muted = muted != 0;
	if (state->volume_known && state->mute_known &&
	    state->volume == volume && state->muted == muted)
		return;
	state->volume = volume;
	state->muted = muted;
	state->volume_known = true;
	state->mute_known = true;
	printf("audio %d %d\n", volume, muted);
	fflush(stdout);
}

static void
close_backlight(struct state *state)
{
	if (state->backlight_fd >= 0)
		close(state->backlight_fd);
	state->backlight_fd = -1;
}

static void
close_mixer(struct state *state)
{
	if (state->mixer_fd >= 0)
		close(state->mixer_fd);
	state->mixer_fd = -1;
}

static void
open_devices(struct state *state, long long now)
{
	if (state->backlight_fd < 0)
		state->backlight_fd = open(BACKLIGHT_DEVICE, O_RDWR | O_CLOEXEC);
	if (state->mixer_fd < 0) {
		state->mixer_fd = open(MIXER_DEVICE, O_RDWR | O_CLOEXEC);
		state->force_audio_read = true;
		state->mixer_modify_counter = -1;
	}
	state->next_reopen = now + REOPEN_INTERVAL_MS;
}

static void
read_brightness(struct state *state)
{
	struct backlight_props props = {0};

	if (state->backlight_fd < 0)
		return;
	if (ioctl(state->backlight_fd, BACKLIGHTGETSTATUS, &props) == -1) {
		if (errno == ENXIO || errno == ENODEV || errno == EBADF)
			close_backlight(state);
		return;
	}
	emit_brightness(state, (int)props.brightness);
}

static void
read_audio(struct state *state)
{
	struct mixer_info info = {0};
	int packed_volume;
	int mute_mask;
	int volume;

	if (state->mixer_fd < 0)
		return;

	if (ioctl(state->mixer_fd, SOUND_MIXER_INFO, &info) == -1) {
		if (errno == ENXIO || errno == ENODEV || errno == EBADF)
			close_mixer(state);
		return;
	}
	if (!state->force_audio_read && state->mixer_modify_counter == info.modify_counter)
		return;

	state->mixer_modify_counter = info.modify_counter;
	state->force_audio_read = false;
	if (ioctl(state->mixer_fd, SOUND_MIXER_READ_VOLUME, &packed_volume) == -1 ||
	    ioctl(state->mixer_fd, SOUND_MIXER_READ_MUTE, &mute_mask) == -1)
		return;
	volume = ((packed_volume & 0xff) + ((packed_volume >> 8) & 0xff) + 1) / 2;
	emit_audio(state, volume, mute_mask & (1U << SOUND_MIXER_VOLUME));
}

static void
refresh(struct state *state, long long now)
{
	bool old_brightness_known = state->brightness_known;
	bool old_volume_known = state->volume_known;
	int old_brightness = state->brightness;
	int old_volume = state->volume;
	int old_muted = state->muted;

	if (now >= state->next_reopen)
		open_devices(state, now);
	read_brightness(state);
	read_audio(state);
	if ((old_brightness_known && state->brightness != old_brightness) ||
	    (old_volume_known && (state->volume != old_volume || state->muted != old_muted)))
		state->active_until = now + ACTIVE_WINDOW_MS;
}

static void
set_brightness(struct state *state, int value, long long now)
{
	struct backlight_props props = {0};

	value = clamp_percent(value);
	if (state->backlight_fd < 0)
		open_devices(state, now);
	if (state->backlight_fd >= 0) {
		props.brightness = (uint32_t)value;
		if (ioctl(state->backlight_fd, BACKLIGHTUPDATESTATUS, &props) == -1)
			close_backlight(state);
	}
	emit_brightness(state, value);
	state->active_until = now + ACTIVE_WINDOW_MS;
}

static void
set_volume(struct state *state, int value, long long now)
{
	int packed_volume;

	value = clamp_percent(value);
	if (state->mixer_fd < 0)
		open_devices(state, now);
	packed_volume = value | (value << 8);
	if (state->mixer_fd >= 0 &&
	    ioctl(state->mixer_fd, SOUND_MIXER_WRITE_VOLUME, &packed_volume) == -1)
		close_mixer(state);
	state->force_audio_read = true;
	emit_audio(state, value, state->mute_known ? state->muted : 0);
	state->active_until = now + ACTIVE_WINDOW_MS;
}

static void
toggle_mute(struct state *state, long long now)
{
	int mute_mask = 0;
	int next_muted;

	if (state->mixer_fd < 0)
		open_devices(state, now);
	if (state->mixer_fd >= 0 &&
	    ioctl(state->mixer_fd, SOUND_MIXER_READ_MUTE, &mute_mask) == -1)
		mute_mask = state->muted ? (1U << SOUND_MIXER_VOLUME) : 0;
	next_muted = !(mute_mask & (1U << SOUND_MIXER_VOLUME));
	if (next_muted)
		mute_mask |= 1U << SOUND_MIXER_VOLUME;
	else
		mute_mask &= ~(1U << SOUND_MIXER_VOLUME);
	if (state->mixer_fd >= 0 &&
	    ioctl(state->mixer_fd, SOUND_MIXER_WRITE_MUTE, &mute_mask) == -1)
		close_mixer(state);
	state->force_audio_read = true;
	emit_audio(state, state->volume_known ? state->volume : 0, next_muted);
	state->active_until = now + ACTIVE_WINDOW_MS;
}

static void
handle_command(struct state *state, char *line, long long now)
{
	int value;

	if (sscanf(line, "brightness %d", &value) == 1)
		set_brightness(state, value, now);
	else if (sscanf(line, "volume %d", &value) == 1)
		set_volume(state, value, now);
	else if (strcmp(line, "mute toggle") == 0)
		toggle_mute(state, now);
	else if (strcmp(line, "refresh") == 0) {
		state->force_audio_read = true;
		refresh(state, now);
	}
}

int
main(void)
{
	struct state state = {
		.backlight_fd = -1,
		.mixer_fd = -1,
		.mixer_modify_counter = -1,
		.force_audio_read = true,
	};
	struct pollfd input = {.fd = STDIN_FILENO, .events = POLLIN};
	char buffer[1024] = {0};
	size_t buffered = 0;
	long long now;
	long long next_refresh;

	setvbuf(stdout, NULL, _IOLBF, 0);
	now = monotonic_ms();
	open_devices(&state, now);
	refresh(&state, now);
	next_refresh = now + IDLE_INTERVAL_MS;

	for (;;) {
		int timeout;
		int result;
		ssize_t count;

		now = monotonic_ms();
		timeout = (int)(next_refresh > now ? next_refresh - now : 0);
		result = poll(&input, 1, timeout);
		if (result < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (result > 0 && (input.revents & (POLLIN | POLLHUP))) {
			count = read(STDIN_FILENO, buffer + buffered,
			    sizeof(buffer) - buffered - 1);
			if (count <= 0)
				break;
			buffered += (size_t)count;
			buffer[buffered] = '\0';
			for (;;) {
				char *newline = strchr(buffer, '\n');
				size_t consumed;

				if (newline == NULL)
					break;
				*newline = '\0';
				now = monotonic_ms();
				handle_command(&state, buffer, now);
				consumed = (size_t)(newline - buffer) + 1;
				buffered -= consumed;
				memmove(buffer, buffer + consumed, buffered);
				buffer[buffered] = '\0';
			}
			if (buffered == sizeof(buffer) - 1)
				buffered = 0;
		}

		now = monotonic_ms();
		if (now >= next_refresh) {
			refresh(&state, now);
			next_refresh = now +
			    (now < state.active_until ? ACTIVE_INTERVAL_MS : IDLE_INTERVAL_MS);
		}
	}

	close_backlight(&state);
	close_mixer(&state);
	return (0);
}
