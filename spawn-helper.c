#include "spawn_helper.h"
#include <spawn.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/wait.h>

extern char **environ;

int run_command(const char *tool_path, const char *cmd, char **output) {

    int pipefd[2];
    pipe(pipefd);

    pid_t pid;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // redirect stdout + stderr
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    // IMPORTANT: use your tool (bash or utils binary)
    char *argv[] = {
        (char *)tool_path,
        "-c",
        (char *)cmd,
        NULL
    };

    int status = posix_spawn(
        &pid,
        tool_path,
        &actions,
        NULL,
        argv,
        environ
    );

    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);

    if (status != 0) {
        return status;
    }

    waitpid(pid, NULL, 0);

    char buffer[8192];
    ssize_t n = read(pipefd[0], buffer, sizeof(buffer) - 1);

    if (n > 0) {
        buffer[n] = '\0';
        *output = strdup(buffer);
    } else {
        *output = strdup("");
    }

    close(pipefd[0]);

    return 0;
}
