local ffi = require("ffi")
local errno = require("std_ffi.errno")

local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C

local _M = {
    O_RDONLY = tonumber('00000000', 8),
    O_WRONLY = tonumber('00000001', 8),
    O_RDWR = tonumber('00000002', 8),
    O_CREAT = tonumber('00000100', 8),
    O_EXCL = tonumber('00000200', 8),
    O_TRUNC = tonumber('00001000', 8),
    O_APPEND = tonumber('00002000', 8),
    O_NONBLOCK = tonumber('00004000', 8),
    O_DSYNC = tonumber('00010000', 8),
    O_SYNC = tonumber('04010000', 8),
    O_DIRECT = tonumber('00040000', 8),
    O_DIRECTORY = tonumber('00200000', 8),
    O_CLOEXEC = tonumber('02000000', 8),

    S_IRWXU = tonumber('00700', 8),
    S_IRUSR = tonumber('00400', 8),
    S_IWUSR = tonumber('00200', 8),
    S_IXUSR = tonumber('00100', 8),

    S_IRWXG = tonumber('00070', 8),
    S_IRGRP = tonumber('00040', 8),
    S_IWGRP = tonumber('00020', 8),
    S_IXGRP = tonumber('00010', 8),

    S_IRWXO = tonumber('00007', 8),
    S_IROTH = tonumber('00004', 8),
    S_IWOTH = tonumber('00002', 8),
    S_IXOTH = tonumber('00001', 8),

    SEEK_SET = 0,
    SEEK_CUR = 1,
    SEEK_END = 2,
}

local mt = { __index = _M }

ffi.cdef[[

typedef int64_t off_t;

typedef struct { int fd; } fhandle_t;

]]

ffi.cdef[[

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

]]

local fhandle_t = ffi.metatype("fhandle_t", {})

local function _error()
    local saved_errno = ffi.errno()
    local err_str = ffi_str(C.strerror(saved_errno))

    return nil, errno.err_msg[saved_errno], err_str
end

local function close_fhandle(fhandle)

    if fhandle.fd == -1 then
        return nil, nil, nil
    end

    local res = C.close(fhandle.fd)
    if res < 0 then
        return _error()
    end

    fhandle.fd = -1

    return nil, nil, nil
end

function _M.open(_, fpath, flags, mode)
    -- if O_CREAT is not specified, then mode is ignored.
    mode = mode or tonumber('00660', 8)

    C.umask(000)

    local fd = C.open(fpath, flags, mode)
    if fd < 0 then
        return _error()
    end

    local f = {
        fpath = fpath,
        flags = flags,
        mode = mode,
        fhandle = ffi.gc(fhandle_t(fd), close_fhandle),
    }

    return setmetatable(f, mt), nil, nil
end

function _M.close(self)
    return close_fhandle(self.fhandle)
end

function _M.write(self, data)
    local written = C.write(self.fhandle.fd, data, #data)
    if written < 0 then
        return _error()
    end

    return written, nil, nil
end

function _M.pwrite(self, data, offset)
    local written = C.pwrite(self.fhandle.fd, data, #data, offset)
    if written < 0 then
        return _error()
    end

    return written, nil, nil
end

function _M.fsync(self)
    local res = C.fsync(self.fhandle.fd)
    if res < 0 then
        return _error()
    end

    return nil, nil, nil
end

function _M.fdatasync(self)
    local res = C.fdatasync(self.fhandle.fd)
    if res < 0 then
        return _error()
    end

    return nil, nil, nil
end

function _M.read(self, size)
    local buf = ffi_new("char[?]", size)

    local read = C.read(self.fhandle.fd, buf, size)
    if read < 0 then
        return _error()
    end

    return ffi_str(buf, read)
end

function _M.pread(self, size, offset)
    local buf = ffi_new("char[?]", size)

    local read = C.pread(self.fhandle.fd, buf, size, offset)
    if read < 0 then
        return _error()
    end

    return ffi_str(buf, read)
end

function _M.seek(self, offset, whence)
    local off = C.lseek(self.fhandle.fd, offset, whence)
    if off < 0 then
        return _error()
    end

    return off, nil, nil
end

_M.MIN_RETRY_TIMES = 1
_M.MAX_RETRY_TIMES = 30

function _M.write_with_retry(self, data, retry_count)
    retry_count = retry_count or 3

    local to_write
    local i = 0
    local has_written = 0
    local data_size = #data

    if retry_count < _M.MIN_RETRY_TIMES then
        retry_count = _M.MIN_RETRY_TIMES
    elseif retry_count > _M.MAX_RETRY_TIMES then
        retry_count = _M.MAX_RETRY_TIMES
    end

    while has_written < data_size do

        if i >= retry_count then
            return nil, 'TooManyWriteRetry', 'has retry write data ' .. i .. ' times'
        end

        if i == 0 then
            -- avoid string copy
            to_write = data
        else
            to_write = string.sub(data, has_written+1)
        end

        local written, err_code, err_msg = _M.write(self, to_write)
        if err_code ~= nil then
            return nil, err_code, err_msg
        end

        has_written = has_written + written
        i = i + 1
    end

    return nil, nil, nil
end

return _M
