// SPDX-License-Identifier: MIT
/*
 * demod - small industrial-style monitoring daemon for the Yocto migration demo.
 *
 * Every interval it samples /proc/loadavg and /proc/uptime, logs one line to
 * stdout (captured by the journal), and pets the systemd watchdog.
 */
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <systemd/sd-daemon.h>

static volatile sig_atomic_t running = 1;

static void on_signal(int sig)
{
	(void)sig;
	running = 0;
}

static int read_first_line(const char *path, char *buf, size_t len)
{
	FILE *f = fopen(path, "r");

	if (!f)
		return -errno;
	if (!fgets(buf, (int)len, f)) {
		fclose(f);
		return -EIO;
	}
	fclose(f);
	buf[strcspn(buf, "\n")] = '\0';
	return 0;
}

int main(int argc, char **argv)
{
	unsigned int interval = 5;
	uint64_t wd_usec = 0;
	unsigned long sample = 0;
	struct sigaction sa;
	char load[128], up[128];

	if (argc > 1)
		interval = (unsigned int)strtoul(argv[1], NULL, 10);
	if (interval == 0)
		interval = 5;

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = on_signal;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);

	/* Sample at least twice per watchdog period. */
	if (sd_watchdog_enabled(0, &wd_usec) > 0 && wd_usec / 2000000 < interval)
		interval = wd_usec / 2000000 ? (unsigned int)(wd_usec / 2000000) : 1;

	printf("demod: started, interval %us\n", interval);
	fflush(stdout);
	sd_notify(0, "READY=1");

	while (running) {
		if (read_first_line("/proc/loadavg", load, sizeof(load)) < 0)
			snprintf(load, sizeof(load), "unavailable");
		if (read_first_line("/proc/uptime", up, sizeof(up)) < 0)
			snprintf(up, sizeof(up), "unavailable");

		printf("demod: sample=%lu loadavg=\"%s\" uptime=\"%s\"\n",
		       ++sample, load, up);
		fflush(stdout);
		sd_notifyf(0, "WATCHDOG=1\nSTATUS=sample %lu", sample);

		sleep(interval);
	}

	sd_notify(0, "STOPPING=1");
	printf("demod: stopping after %lu samples\n", sample);
	return 0;
}
