const std = @import("std");
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
