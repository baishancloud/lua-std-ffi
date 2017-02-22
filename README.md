<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

# lua_file_ffi

file system calls by lua

## Example:

```

local file_ffi = require('file_ffi')

local f, err_code, err_msg = file_ffi:open(TEST_FILE_PATH,
                                           bit.bor(file_ffi.O_CREAT,
                                                   file_ffi.O_RDWR,
                                                   file_ffi.O_TRUNC),
                                           file_ffi.S_IRWXU)
if err_code ~= nil then
    return nil, err_code, err_msg
end

local written, err_code, err_msg = f:write("aaaa")
if err_code ~= nil then
    return nil, err_code, err_msg
end

local res, err_code, err_msg = f:fdatasync()
if err_code ~= nil then
    return nil, err_code, err_msg
end

local written, err_code, err_msg = f:pwrite("aaaa", 5)
if err_code ~= nil then
    return nil, err_code, err_msg
end

local res, err_code, err_msg = f:sync()
if err_code ~= nil then
    return nil, err_code, err_msg
end

f:seek(0, file_ffi.SEEK_SET)

local buf, err_code, err_msg = f:read(5)
if err_code ~= nil then
    return nil, err_code, err_msg
end

print(buf)

buf, err_code, err_msg = f:pread(2, 4)
if err_code ~= nil then
    return nil, err_code, err_msg
end

print(buf)

local res, err_code, err_msg = f:write_with_retry("aaaaaaaaaffaaaaaaaa", 3)
if err_code ~= nil then
    return nil, err_code, err_msg
end

f:close()

you could not call close, collectgarbage will close fd, if the instance be destroyed

```

## Author

cc (陈闯) <chuang.chen@baishancloud.com>

## Copyright and License

The MIT License (MIT)

Copyright (c) 2017 cc (陈闯) <chuang.chen@baishancloud.com>
