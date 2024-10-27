const std = @import("std");
const Thread = std.Thread;
const mem = std.mem;

const curl = @cImport({
    @cInclude("curl/curl.h");
});

const RequestError = error{CurlInitError};

pub fn global_init() !void {
    if (curl.curl_global_init(curl.CURL_GLOBAL_ALL) != 0) {
        return RequestError.CurlInitError;
    }
}

pub fn global_cleanup() void {
    curl.curl_global_cleanup();
}

pub const Response = struct {
    done_mutex: Thread.Mutex,
    done: bool,

    pub fn is_done(self: *Response) bool {
        self.done_mutex.lock();
        defer self.done_mutex.unlock();

        return self.done;
    }
};

fn write_callback(contents: *void, size: usize, nmemb: usize, userp: *void) usize {
    std.debug.print("write_callback: {} {} {} {}\n", .{ contents, size, nmemb, userp });

    const stdout = std.io.getStdOut();
    const slice: [*]u8 = @ptrCast(contents);
    _ = stdout.writeAll(slice[0..nmemb]) catch unreachable;

    return size * nmemb;
}

fn request_thread(handle: *curl.CURL, response: *Response) void {
    const ptr: *const void = @ptrCast(&write_callback);
    _ = curl.curl_easy_setopt(handle, curl.CURLOPT_WRITEFUNCTION, ptr);

    const res = curl.curl_easy_perform(handle);
    if (res != curl.CURLE_OK) {
        std.debug.print("Curl failed {s}", .{curl.curl_easy_strerror(res)});
    }

    response.done_mutex.lock();
    defer response.done_mutex.unlock();
    response.done = true;
}

pub fn request(allocator: mem.Allocator, url: [:0]const u8) !*Response {
    const response = try allocator.create(Response);
    response.* = .{
        .done_mutex = .{},
        .done = false,
    };

    const easy = curl.curl_easy_init() orelse return RequestError.CurlInitError;
    const url_ptr: *const u8 = @ptrCast(url);
    _ = curl.curl_easy_setopt(easy, curl.CURLOPT_URL, url_ptr);
    _ = curl.curl_easy_setopt(easy, curl.CURLOPT_USERAGENT, "libcurl-agent/1.0");

    _ = try Thread.spawn(.{}, request_thread, .{ easy, response });

    return response;
}
