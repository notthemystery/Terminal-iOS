#ifndef spawn_h
#define spawn_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

int run_command(const char *toolPath, const char *cmd, char **output);

#ifdef __cplusplus
}
#endif

#endif
