# -*- coding: utf-8 -*-
"""Static server for build/web.

Deliberately ThreadingHTTPServer, NOT `python -m http.server`: that one is
single-threaded, and Flutter web opens several asset requests in parallel at
startup. Under the default handler those queue behind each other and the
browser eventually gives up with net::ERR_FAILED / 501, which shows up as an
app that renders nothing at all -- no canvas, no error, just a blank page.

Also sends no-cache headers. The bundle filename never changes between
builds, so a cached main.dart.js otherwise survives a rebuild and you end up
debugging yesterday's code.

Usage:  py -3 C:\\Dev\\docs\\tools\\serve_web.py [port] [directory]
"""
import functools
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
DIRECTORY = sys.argv[2] if len(sys.argv) > 2 else r"C:\Dev\wanote\build\web"


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Only surface failures; a normal page load is ~15 lines of noise.
        status = args[1] if len(args) > 1 else ""
        if not str(status).startswith("2") and not str(status).startswith("3"):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    handler = functools.partial(Handler, directory=DIRECTORY)
    server = ThreadingHTTPServer(("0.0.0.0", PORT), handler)
    print(f"serving {DIRECTORY} on :{PORT} (threaded, no-cache)")
    server.serve_forever()
