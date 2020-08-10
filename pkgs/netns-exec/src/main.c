/* This program must be run with CAP_SYS_ADMIN. This can be achieved for example
 * with
 *         # setcap CAP_SYS_ADMIN+ep ./main
 */

#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/capability.h>

static char *available_netns[] = {
    "nb-lnd",
    "nb-lightning-loop",
    "nb-bitcoind",
    "nb-liquidd",
    "nb-faraday"
};

int check_netns(char *netns) {
    int i;
    int n_available_netns = sizeof(available_netns) / sizeof(available_netns[0]);
    for (i = 0; i < n_available_netns; i++) {
        if (strcmp(available_netns[i], netns) == 0) {
            return 1;
        }
    }
    return 0;
}

void print_capabilities() {
    cap_t caps = cap_get_proc();
    printf("Capabilities: %s\n", cap_to_text(caps, NULL));
    cap_free(caps);
}
void drop_capabilities() {
    cap_t caps = cap_get_proc();
    cap_clear(caps);
    cap_set_proc(caps);
    cap_free(caps);
}

int main(int argc, char **argv) {
    int fd;
    char netns_path[256];

    if (argc < 3) {
        printf("usage: %s <netns> <command to execute>\n", argv[0]);
        return 1;
    }

    if (!check_netns(argv[1])) {
        printf("Failed checking %s against available netns.\n", argv[1]);
        return 1;
    }

    if(snprintf(netns_path, sizeof(netns_path), "/var/run/netns/%s", argv[1]) < 0) {
        printf("Failed concatenating %s to the netns path.\n", argv[1]);
        return 1;
    }

    fd = open(netns_path, O_RDONLY);
    if (fd < 0) {
        printf("Failed opening netns %s: %d, %s \n", netns_path, errno, strerror(errno));
        return 1;
    }

    if (setns(fd, CLONE_NEWNET) < 0) {
        printf("Failed setns %d, %s \n", errno, strerror(errno));
        return 1;
    }

    /* Drop capabilities */
    #ifdef DEBUG
    print_capabilities();
    #endif
    drop_capabilities();
    #ifdef DEBUG
    print_capabilities();
    #endif

    execvp(argv[2], &argv[2]);
    return 0;
}

