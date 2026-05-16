#ifndef SPAWN_H
#define SPAWN_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

int run_command(const char *toolPath,
                char *const argv[],
                char **output);

#ifdef __cplusplus
}
#endif

#endif
