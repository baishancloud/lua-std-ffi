Name
=====

Std_ffi - library wrap stdlib and stdio by lua, current only provide file operations.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Modules](#modules)
    * [std_ffi.file](#stdffifile)
        * [Methods](#methods)
            * [open](#open)
            * [write](#write)
            * [pwrite](#pwrite)
            * [write_with_retry](#write_with_retry)
            * [read](#read)
            * [pread](#pread)
            * [fsync](#fsync)
            * [fdatasync](#fdatasync)
            * [seek](#seek)
            * [close](#close)
* [Installation](#installation)
* [Authors](#authors)
* [Copyright and License](#copyright-and-license)

Status
======

This library is already usable though still highly experimental.

Synopsis
========

```lua

local file_ffi = require "std_ffi.file"

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
```

Modules
=======

Std_ffi.file
--------------------

To load this module, just do this

```lua
    local file = require "std_ffi.file"
```

### Methods

#### open

`syntax: local f, err_code, err_msg = file:open(fpath, flags, mode)`

- fpath: open file path

- flags:
Must include one of the following access modes: O_RDONLY, O_WRONLY, or O_RDWR.<br>
You can found the full list of file creation flags and file status flags in file.lua

- mode:
Specifies the permissions to use in case a new file is created, you can found in file.lua.

On success, the new file instance is returned.

Otherwise, err_code shall be returned.

#### write

`syntax: local written, err_code, err_msg = f:write(buf)`

Attempt to write buf to the file.

On success, the number of bytes written is returned.

Otherwise, err_code shall be returned.

#### pwrite

`syntax: local written, err_code, err_msg = f:pwrite(buf, offset)`

Attempt to write buf to the file at offset. The file offset is not changed.

On success, the number of bytes written is returned.

Otherwise, err_code shall be returned.

#### write_with_retry

`syntax: local res, err_code, err_msg = f:write_with_retry(buf, retry_count)`

Attempt to write all buf to the file, if not completely, will retry again.

retry_count default value is 3, the retry_count range is [1, 30].

On success, res is nil.

Otherwise, err_code shall be returned.

#### read

`syntax: local buf, err_code, err_msg = f:read(nbyte)`

Attempt to read nbyte bytes from the file.

On success, return the number of bytes actually read.

Otherwise, err_code shall be returned.

#### pread

`syntax: local buf, err_code, err_msg = f:pread(nbyte, offset)`

Attempt to read nbyte bytes from the file, the file offset is not changed.

On success, return the number of bytes actually read.

Otherwise, err_code shall be returned.

#### fsync

`syntax: local res, err_code, err_msg = f:fsync()`

Flushes all modified data of the file to the disk device,

On success, res is nil.

Otherwise, err_code shall be returned.

#### fdatasync

`syntax: local res, err_code, err_msg = f:fdatasync()`

Flushes all modified data of the file to the disk device, fdatasync is similar to fsync,<br>
but does not flush modified metadata unless that metadata is needed<br>
in order to allow a subsequent data retrieval to be correctly handled.

On success, res is nil.

Otherwise, err_code shall be returned.

#### seek

`syntax: local off, err_code, err_msg = f:seek(offset, whence)`

Repositions the offset of the file to the argument offset according to the directive whence as follows:<br>
SEEK_SET, SEEK_CUR, SEEK_END

On success, returns the resulting offset location as measured in bytes from the beginning of the file.

Otherwise, err_code shall be returned.

#### close

`syntax: local res, err_code, err_msg = file:close()`

Close the file fd

`You could not call close, collectgarbage will close fd, if the instance be destroyed.`

On success, res is nil

Otherwise, err_code shall be returned.

Installation
============

Copy the std_ffi directory to a location which is in the seaching path of lua require module

Please use luajit to run test.

Author
======

cc (陈闯) <chuang.chen@baishancloud.com>

Copyright and License
=====================

The MIT License (MIT)

Copyright (c) 2017 cc (陈闯) <chuang.chen@baishancloud.com>
