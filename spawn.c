#include "spawn.h"

#include "spawn.h"

#include <spawn.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <errno.h>

extern char **environ;

int run_command(const char *toolPath,
                char *const argv[],
                char **output) {

    if (!toolPath || !argv || !output) return -1;

    int pipefd[2];
    if (pipe(pipefd) != 0) return -1;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // redirect stdout + stderr
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    pid_t pid;

    int status = posix_spawn(
        &pid,
        toolPath,
        &actions,
        NULL,
        argv,
        environ
    );

    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);

    // ALWAYS read output (even on failure)
    char buffer[8192];
    ssize_t n = read(pipefd[0], buffer, sizeof(buffer) - 1);

    if (n > 0) {
        buffer[n] = '\0';
        *output = strdup(buffer);
    } else {
        *output = strdup("");
    }

    close(pipefd[0]);

    // If spawn succeeded, wait for process
    if (status == 0) {
        waitpid(pid, NULL, 0);
    }

    // Attach debug info on failure
    if (status != 0) {
        char debug[256];
        snprintf(debug, sizeof(debug),
                 "posix_spawn failed: %d (errno=%d)", status, errno);

        free(*output);
        *output = strdup(debug);
    }

    return status;
}
