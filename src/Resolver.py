"""Resolve the resort's public live streams for the native macOS player.

Listens on loopback only. No account cookies, recording, or media files.
"""
import json
import os
import shutil
import re
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import yt_dlp
from Traffic import traffic

CAMERAS = {
    "lions": "https://camstreamer.com/embed/coUmF7P2InhuwcFcDus84j6LnbpQobaZBfJI5e37",
    "plaza": "https://camstreamer.com/embed/eRzI4m4I7DVVaPqHWCVvlHERvHviYEmqOI3yXz3Q",
}
NODE = os.environ.get("SKI_NERD_NODE") or shutil.which("node") or str(Path(__file__).resolve().parent / "node")
cache = {}
locks = {}
locks_guard = threading.Lock()


def validate_source(source):
    parsed = urllib.parse.urlparse(source)
    hosts = {"youtube.com", "www.youtube.com", "youtu.be", "camstreamer.com", "www.camstreamer.com"}
    if (parsed.scheme != "https" or parsed.hostname not in hosts or parsed.username
            or parsed.password or parsed.port not in (None, 443)):
        raise ValueError("Only public HTTPS YouTube or CamStreamer sources are supported")
    return parsed


class ProviderRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, destination):
        validate_source(destination)
        return super().redirect_request(request, response, code, message, headers, destination)


def resolve(name):
    return resolve_source(CAMERAS[name])


def resolve_source(source):
    parsed = validate_source(source)
    with locks_guard:
        lock = locks.setdefault(source, threading.Lock())
    with lock:
        previous = cache.get(source)
        if previous and time.monotonic() - previous[0] < 1800:
            return previous[1]
        destination = source
        if parsed.hostname in {"camstreamer.com", "www.camstreamer.com"}:
            # Fixed public provider only; never resolve arbitrary URLs or local addresses.
            if not re.fullmatch(r"/embed/[\w-]+", parsed.path):
                raise ValueError("Use the public CamStreamer embed address")
            with urllib.request.build_opener(ProviderRedirects()).open(source, timeout=20) as response:
                destination = response.url
            parsed = validate_source(destination)
            if parsed.hostname not in {"www.youtube.com", "youtube.com", "youtu.be"}:
                raise ValueError("Unexpected public camera destination")
        match = re.fullmatch(r"/embed/([\w-]+)", parsed.path)
        if match and parsed.hostname in {"www.youtube.com", "youtube.com"}:
            destination = "https://www.youtube.com/watch?v=" + match[1]
        options = {
            "quiet": True, "no_warnings": True, "skip_download": True,
            "socket_timeout": 20, "cachedir": False, "noplaylist": True,
            "js_runtimes": {"node": {"path": NODE}},
        }
        with yt_dlp.YoutubeDL(options) as client:
            info = client.extract_info(destination, download=False)
        formats = [item for item in info.get("formats", [])
                   if "m3u8" in item.get("protocol", "")
                   and item.get("height") and item["height"] <= 720
                   and item.get("vcodec", "").startswith("avc1")]
        if not formats:
            raise ValueError("No supported public live stream")
        url = max(formats, key=lambda item: item["height"])["url"]
        if urllib.parse.urlparse(url).scheme != "https":
            raise ValueError("The resolved stream must use HTTPS")
        cache[source] = (time.monotonic(), url)
        print("Resolved public camera, 720p or lower", flush=True)
        return url


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/health":
            self.respond(200, {"service": "mountain-cams-native-v1"})
            return
        if parsed.path == "/traffic":
            self.respond(200, traffic())
            return
        query = urllib.parse.parse_qs(parsed.query)
        name = query.get("camera", [""])[0]
        source = query.get("source", [""])[0]
        if parsed.path != "/stream" or not ((name in CAMERAS and not source) or (source and not name)):
            self.respond(404, {"error": "Unknown camera"})
            return
        if source:
            try:
                validate_source(source)
            except ValueError:
                self.respond(400, {"error": "Unsupported public provider"})
                return
        try:
            self.respond(200, {"url": resolve_source(source) if source else resolve(name)})
        except Exception as error:
            print("Resolution failed", name or "custom", type(error).__name__, flush=True)
            self.respond(502, {"error": "Live stream temporarily unavailable"})

    def respond(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("Mountain Cams resolver on 127.0.0.1:48764", flush=True)
    ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("SKI_NERD_PORT", "48764"))), Handler).serve_forever()
