#include "spawn.h"

#include <spawn.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <stdio.h>

extern char **environ;

int run_command(const char *toolPath, char *const argv[], char **output) {
    if (!toolPath || !argv || !output) return -1;

    int pipefd[2];
    if (pipe(pipefd) != 0) {
        return -1;
    }

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // redirect stdout/stderr → pipe
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);

    // close read end in child
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    pid_t pid;
    int status = posix_spawn(
        &pid,
        toolPath,
        &actions,
        NULL,
        (char *const *)argv,
        environ
    );

    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]); // parent closes write end

    if (status != 0) {
        close(pipefd[0]);
        return status;
    }

    // read full output
    size_t cap = 4096;
    size_t len = 0;
    char *buf = malloc(cap);
    if (!buf) return -1;

    ssize_t n;
    while ((n = read(pipefd[0], buf + len, cap - len - 1)) > 0) {
        len += n;
        if (len > cap - 1024) {
            cap *= 2;
            buf = realloc(buf, cap);
            if (!buf) return -1;
        }
    }

    buf[len] = '\0';
    close(pipefd[0]);

    int wstatus;
    waitpid(pid, &wstatus, 0);

    *output = buf;
    return WEXITSTATUS(wstatus);
}
