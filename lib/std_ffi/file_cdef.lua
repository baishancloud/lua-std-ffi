local _M = {}


_M.cdef = [[
typedef int64_t off_t;
typedef struct { int fd; } fhandle_t;


int open(const char *pathname, int flags, int mode);
int close(int fd);
off_t lseek(int fd, off_t offset, int whence);

int64_t write(int fildes, const void *buf, size_t nbyte);
int64_t pwrite(int fd, const void *buf, size_t count, off_t offset);

int fsync(int fd);
int fdatasync(int fd);

int64_t read(int fildes, void *buf, size_t nbyte);
int64_t pread(int fd, void *buf, size_t count, off_t offset);

int umask(int cmask);
char *strerror(int errnum);

int link(const char *oldpath, const char *newpath);
int stat(const char *restrict path, const char *restrict buf);
]]


return _M
