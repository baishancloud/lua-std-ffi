package.path = '../lib/?.lua;' .. package.path

local bit = require('numberlua')
local file_ffi = require('std_ffi.file')

local TEST_FILE_PATH = "/tmp/test_file_ffi"

function write_file(fpath, data)
    local f = io.open(fpath, 'w+')
    assert(f ~= nil)

    local res = f:write(data)
    assert(res ~= nil)

    f:close()
end

function create_buf(size)
    local data = "123456789abcdefghijklmnopqrstuvwxyz!@#$%^&ABCDEFGHIJKLMNOPQRSTUVWXYZ*()_+{}:<>?"
    local buf = data

    if size < #buf then
        return string.sub(buf, 1, size)
    end

    while #buf*2 < size do
        buf = buf .. buf
        collectgarbage()
    end

    remained = buf
    prev = remained

    while #buf + #remained > size do
        prev = remained
        remained = string.sub(remained, 1, #remained/2)
    end

    buf = buf .. prev

    collectgarbage()
    return string.sub(buf, 1, size)
end

function open_test_file(flags, mode)
    local f, err_code, err_msg = file_ffi:open(TEST_FILE_PATH, flags, mode)
    assert(f ~= nil and err_code == nil)

    return f
end

function write_with_assert(f, data)
    local written, err_code, err_msg = f:write(data)
    assert(#data == written and nil == err_code)
end

function test_open_rw()

    local cases = {
        {'test_create', nil, nil, 'EBADF'},
        {'test_readonly', file_ffi.O_RDONLY, nil, 'EBADF'},
        {'test_writeonly', file_ffi.O_WRONLY, 'EBADF', nil},
        {'test_readwrite', file_ffi.O_RDWR, nil, nil},
    }

    for _, case in ipairs(cases) do
        local test_name, flag, read_err, write_err = case[1], case[2], case[3], case[4]

        local flags = file_ffi.O_CREAT
        if flag ~= nil then
            flags = bit.bor(flags, flag)
        end

        local f = open_test_file(flags)

        local buf, err_code, err_msg = f:read(1)
        if read_err == nil then
            assert('' == buf and nil == err_code)
        else
            assert(nil == buf and read_err == err_code)
        end

        local written, err_code, err_msg = f:write("aaaa")
        if write_err == nil then
            assert(4 == written and nil == err_code)
        else
            assert(nil == written and write_err == err_code)
        end

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_open_size()
    local prepare_data = "aaaa"
    local write_data = "bbbb"

    local cases = {
        {'test_trunc', file_ffi.O_TRUNC, 0, #write_data},
        {'test_append', file_ffi.O_APPEND, #prepare_data, #prepare_data + #write_data},
    }

    for _, case in ipairs(cases) do
        local test_name, flag, before_written_size, after_written_size = case[1], case[2], case[3], case[4]

        write_file(TEST_FILE_PATH, prepare_data)

        local f = open_test_file(bit.bor(file_ffi.O_WRONLY, flag))

        local res = os.execute(string.format('test $(stat -c %%s %s) = "%d"',
                                             TEST_FILE_PATH, before_written_size))
        assert(0 == res)

        write_with_assert(f, write_data)

        local res = os.execute(string.format('test $(stat -c %%s %s) = "%d"',
                                             TEST_FILE_PATH, after_written_size))
        assert(0 == res)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_open_time()
    local data = create_buf(150*1024*1024)

    local cases = {
        {'test_nosync', nil, 0, 5},
        {'test_noblock', file_ffi.O_NONBLOCK, 0, 5},
        {'test_data_sync', file_ffi.O_DSYNC, 1, 20},
        {'test_sync', file_ffi.O_SYNC, 1, 20},
    }

    for _, case in ipairs(cases) do
        local test_name, flag, min_tm, max_tm = case[1], case[2], case[3], case[4]

        local flags = bit.bor(file_ffi.O_CREAT, file_ffi.O_WRONLY)
        if flag ~= nil then
            flags = bit.bor(flags, flag)
        end

        local f = open_test_file(flags)

        local start_tm = os.time()
        write_with_assert(f, data)
        local use_tm = os.time() - start_tm

        assert(min_tm <= use_tm)
        assert(use_tm < max_tm)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_open_permissions()

    local cases = {
        {'test_default', nil},

        {'test_rwxu', file_ffi.S_IRWXU},
        {'test_ru', file_ffi.S_IRUSR},
        {'test_wu', file_ffi.S_IWUSR},
        {'test_xu', file_ffi.S_IXUSR},
        {'test_rwu', bit.bor(file_ffi.S_IRUSR, file_ffi.S_IWUSR)},

        {'test_rwxg', file_ffi.S_IRWXG},
        {'test_rg', file_ffi.S_IRGRP},
        {'test_wg', file_ffi.S_IWGRP},
        {'test_xg', file_ffi.S_IXGRP},
        {'test_rwg', bit.bor(file_ffi.S_IRGRP, file_ffi.S_IWGRP)},

        {'test_rwxoth', file_ffi.S_IRWXO},
        {'test_roth', file_ffi.S_IROTH},
        {'test_woth', file_ffi.S_IWOTH},
        {'test_xoth', file_ffi.S_IXOTH},
        {'test_rwoth', bit.bor(file_ffi.S_IROTH, file_ffi.S_IWOTH)},
    }

    for _, case in ipairs(cases) do
        local test_name, mode = case[1], case[2]

        local f = open_test_file(file_ffi.O_CREAT, mode)

        local expect_mode = mode or tonumber('00660', 8)

        local res = os.execute(string.format('test $(stat -c %%a %s) = "%s"',
                                             TEST_FILE_PATH, string.format("%o", expect_mode)))
        assert(0 == res)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_read_to_end()

    local cases = {
        {'test_read_to_end_1', 10,  0,  0},
        {'test_read_to_end_2', 10,  1,  1},
        {'test_read_to_end_3', 10,  7,  7},
        {'test_read_to_end_4', 10, 10, 10},
        {'test_read_to_end_5', 10, 11, 10},
        {'test_read_to_end_6', 10, 20, 10},
    }

    print('test_read_to_end:')
    for _, case in ipairs(cases) do
        local test_name, to_read_bytes, data_bytes, read_bytes = unpack(case)

        local data = create_buf(data_bytes)

        local f = open_test_file(bit.bor(file_ffi.O_CREAT, file_ffi.O_WRONLY))
        write_with_assert(f, data)

        f = open_test_file(file_ffi.O_RDONLY)
        local buf, err_code, err_msg = f:read(to_read_bytes)
        assert(type(buf) == 'string' and nil == err_code)
        assert(#buf == read_bytes, #buf .. ' ~= ' .. read_bytes)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_read_and_write()

    local cases = {
        {'test_empty_str', 0},
        {'test_one_byte', 1},
        {'test_small_data', 10*1024},
        {'test_regular_data', 10*1024*1024},
        {'test_big_data', 100*1024*1024},
    }

    for _, case in ipairs(cases) do
        local test_name, data_size = case[1], case[2]

        local data = create_buf(data_size)

        local f = open_test_file(bit.bor(file_ffi.O_CREAT, file_ffi.O_WRONLY))
        write_with_assert(f, data)

        f = open_test_file(file_ffi.O_RDONLY)
        local buf, err_code, err_msg = f:read(data_size)
        assert(data == buf and nil == err_code)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_pread_and_pwrite()
    local prepare_data = create_buf(4*1024)

    local cases = {
        {'test_front_position', 1024, 0},
        {'test_middle_position', 1024, 512},
        {'test_end_position', 1024, 4*1024},
        {'test_write_data_bigger_than_prev', 5*1024, 1024},
    }

    for _, case in ipairs(cases) do
        local test_name, data_size, position= case[1], case[2], case[3]

        local f = open_test_file(bit.bor(file_ffi.O_CREAT, file_ffi.O_RDWR))
        write_with_assert(f, prepare_data)

        local data = create_buf(data_size)
        local written, err_code, err_msg = f:pwrite(data, position)
        assert(data_size == written and nil == err_code)

        local uncovered_size = position
        if uncovered_size > 0 then
            local buf, err_code, err_msg = f:pread(uncovered_size, 0)
            assert(buf == string.sub(prepare_data, 1, uncovered_size) and nil == err_code)
        end

        local buf, err_code, err_msg = f:pread(data_size, position)
        assert(buf == data and nil == err_code)

        local remained_uncovered_size = #prepare_data - (position + data_size)
        if remained_uncovered_size > 0 then
            local buf, err_code, err_msg = f:pread(remained_uncovered_size, position + data_size)
            assert(buf == string.sub(prepare_data, position+data_size+1) and nil == err_code)
        end

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_write_sync()

    local cases = {
        {'test_fsync', 1, 20},
        {'test_fdatasync', 1, 20},
    }

    local data = create_buf(150*1024*1024)

    for _, case in ipairs(cases) do
        local test_name, min_tm, max_tm = case[1], case[2], case[3]

        local f = open_test_file(bit.bor(file_ffi.O_CREAT, file_ffi.O_RDWR))

        local start_tm = os.time()
        write_with_assert(f, data)
        local use_tm = os.time() - start_tm

        assert(use_tm < 5)

        start_tm = os.time()
        if test_name == 'test_fsync' then
            local res, err_code, err_msg = f:fsync()
        else
            local res, err_code, err_msg = f:fdatasync()
        end
        use_tm = os.time() - start_tm

        assert(res == nil and err_code == nil)
        assert(use_tm > min_tm)
        assert(use_tm < max_tm)

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end
end

function test_seek()

    local prepare_data = create_buf(4096)
    write_file(TEST_FILE_PATH, prepare_data)

    local write_data = create_buf(40)

    local cases = {
        {'test_seek_^->', file_ffi.SEEK_SET,    10, 10},
        {'test_seek_^--', file_ffi.SEEK_SET,     0, 0},
        {'test_seek_^<-', file_ffi.SEEK_SET,   -10, nil},
        {'test_seek_.->', file_ffi.SEEK_CUR,   100, #write_data+100},
        {'test_seek_.--', file_ffi.SEEK_CUR,     0, #write_data},
        {'test_seek_.<-', file_ffi.SEEK_CUR,   -10, #write_data-10},
        {'test_seek_$->', file_ffi.SEEK_END,   100, #prepare_data+100},
        {'test_seek_$--', file_ffi.SEEK_END,     0, #prepare_data},
        {'test_seek_$<-', file_ffi.SEEK_END,  -100, #prepare_data-100},
    }

    print('test_seek:')
    for _, case in ipairs(cases) do
        local test_name, flag, position, expect_offset = case[1], case[2], case[3], case[4]

        local f = open_test_file(file_ffi.O_RDWR)

        write_with_assert(f, write_data)

        local offset = f:seek(position, flag)
        assert(expect_offset == offset,
               'expect: ' .. tostring(expect_offset) .. ' == offset: ' .. tostring(offset))

        print(test_name, " OK")
    end

    os.remove(TEST_FILE_PATH)
end

function test_write_with_retry()

    local real_write_func = file_ffi.write

    function write_one_byte(self, data)
        data = string.sub(data, 1, 1)
        real_write_func(self, data)
        return #data
    end

    local cases = {
        {'test_succ', 5, nil, nil},
        {'test_retry_succ', 3, 2, 'TooManyWriteRetry'},
        {'test_retry_fail', 3, 3, nil},
        {'test_retry_min_times_succ', 1, 0, nil},
        {'test_retry_min_times_fail', 2, 0, 'TooManyWriteRetry'},
        {'test_retry_max_times_succ', 30, 100, nil},
        {'test_retry_max_times_fail', 31, 100, 'TooManyWriteRetry'},
        {'test_retry_decimal_times_succ', 3, 2.1, nil},
        {'test_retry_decimal_times_fail', 4, 2.1, 'TooManyWriteRetry'},
    }

    for _, case in ipairs(cases) do
        local test_name, data_size, retry_times, expect_err = case[1], case[2], case[3], case[4]

        if test_name ~= 'test_succ' then
            file_ffi.write = write_one_byte
        end

        local f = open_test_file(bit.bor(file_ffi.O_CREAT, file_ffi.O_RDWR))

        local data = create_buf(data_size)

        local res, err_code, err_msg = f:write_with_retry(data, retry_times)
        if expect_err ~= nil then
            assert(expect_err == err_code)
        else
            assert(nil == res and nil == err_code)
            local buf, err_code, err_msg = f:pread(data_size, 0)
            assert(data == buf and nil == err_code)
        end

        os.remove(TEST_FILE_PATH)
        print(test_name, " OK")
    end

end

function test_close()

    local f = open_test_file(file_ffi.O_CREAT)
    assert(f ~= nil and err_code == nil)
    assert(f.fhandle.fd ~= -1)

    local res, err_code, err_msg = f:close()
    assert(res == nil and err_code == nil)
    assert(f.fhandle.fd == -1)

    res, err_code, err_msg = f:close()
    assert(res == nil and err_code == nil)

    os.remove(TEST_FILE_PATH)
    print("test_close", " OK")
end

function test_close_by_collectgarbage()

    local f = open_test_file(file_ffi.O_CREAT)
    assert(f ~= nil and err_code == nil)
    assert(f.fhandle.fd ~= -1)

    fd = f.fhandle.fd

    f = nil
    collectgarbage('collect')

    local res = os.execute("lsof -a /tmp/test_file_ffi")
    assert(res ~= 0)

    os.remove(TEST_FILE_PATH)
    print("test_close_by_collectgarbage", " OK")
end

function test_link()

    local flags = bit.bor(file_ffi.O_CREAT, file_ffi.O_WRONLY)

    local f, err_code, err_msg = file_ffi:open(TEST_FILE_PATH, flags)
    assert(f ~= nil and err_code == nil)

    local link_path = TEST_FILE_PATH .. '_link'

    local res, err_code, err_msg = file_ffi:link(TEST_FILE_PATH, link_path)
    assert(err_code == nil)

    local data = 'ssssssssssssss'

    write_with_assert(f, data)

    local fl, err_code, err_msg = file_ffi:open(link_path, file_ffi.O_RDONLY)
    assert(fl ~= nil and err_code == nil)

    local buf, err_code, err_msg = fl:pread(#data, 0)
    assert(buf == data and err_code == nil)

    os.remove(TEST_FILE_PATH)
    os.remove(link_path)

    print("test_link", " OK")
end

function test_stat()
    local f = io.open(TEST_FILE_PATH, 'w+')
    assert(f ~= nil)

    local file_stat, err, errmsg = file_ffi:stat(TEST_FILE_PATH)
    assert(type(file_stat) == 'table')

    os.remove(TEST_FILE_PATH)

    print("test_stat", " OK")
end

function test_access()
    local _, err, errmsg = file_ffi:access(TEST_FILE_PATH, 0)
    assert(err ~= nil)

    local f = io.open(TEST_FILE_PATH, 'w+')

    local _, err, errmsg = file_ffi:access(TEST_FILE_PATH, 0)
    assert(err == nil)

    os.remove(TEST_FILE_PATH)

    print("test_access", " OK")
end

os.remove(TEST_FILE_PATH)
test_open_rw()
test_open_size()
test_open_time()
test_open_permissions()
test_read_to_end()
test_read_and_write()
test_pread_and_pwrite()
test_write_sync()
test_seek()
test_write_with_retry()
test_close()
test_close_by_collectgarbage()
test_link()
test_stat()
test_access()
