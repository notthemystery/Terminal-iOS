#ifndef spawn_helper_h
#define spawn_helper_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

int run_command(const char *cmd, char **output);

#ifdef __cplusplus
}
#endif

#endif
