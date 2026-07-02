#ifndef ANDROID_COMPAT_H
#define ANDROID_COMPAT_H

#ifdef __ANDROID__

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>

static inline const char *__android_shm_tmpdir(void)
{
    const char *dir = getenv("FAKETIME_SHM_DIR");
    if (dir == NULL)
        dir = getenv("TMPDIR");
    if (dir == NULL)
        dir = "/data/local/tmp";
    return dir;
}

static inline int __android_shm_open(const char *name, int oflag, mode_t mode)
{
    char path[512];
    const char *dir = __android_shm_tmpdir();
    while (*name == '/') name++;
    snprintf(path, sizeof(path), "%s/faketime_shm_%s", dir, name);
    int fd = open(path, oflag, mode);
    if (fd == -1 && (oflag & O_CREAT))
    {
        mkdir(dir, 0777);
        fd = open(path, oflag, mode);
    }
    return fd;
}

static inline int __android_shm_unlink(const char *name)
{
    char path[512];
    const char *dir = __android_shm_tmpdir();
    while (*name == '/') name++;
    snprintf(path, sizeof(path), "%s/faketime_shm_%s", dir, name);
    return unlink(path);
}

#define shm_open __android_shm_open
#define shm_unlink __android_shm_unlink

#endif /* __ANDROID__ */
#endif /* ANDROID_COMPAT_H */
