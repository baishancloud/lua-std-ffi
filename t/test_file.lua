package.path = '../lib/?.lua;' .. package.path

local bit = require('numberlua')
local file_ffi = require('std_ffi.file')

local f, err_code, err_msg = file_ffi:open('/root/test_aaaaaa', bit.bor(file_ffi.O_CREAT,file_ffi.O_RDWR))

local written, err_code, err_msg = f:write('123456789')

local buf, err_code, err_msg = f:read(2)
print("========================")
print(buf)
print("========================")
print(err_code)
print("========================")

offset = f:seek(-5, file_ffi.SEEK_CUR)
local buf, err_code, err_msg = f:read(10)
print(buf)
print("========================")
print(err_code)
print("========================")
offset = f:seek(0, file_ffi.SEEK_END)
print(offset)
print("========================")

