"""Serve the local Flutter preview without reusing an earlier build's JavaScript."""

import hashlib
import io
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

WEB_ROOT = Path(__file__).resolve().parent.parent / "mobile" / "build" / "web"


class PreviewHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def translate_path(self, path):
        # Version fonts and bundled images too; stale icon subsets hide new glyphs.
        path = re.sub(r"^/__build/[0-9a-f]{16}/", "/", path)
        return super().translate_path(path)

    def send_head(self):
        # Also replace cached responses that arrive with a conditional request.
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        path = urlsplit(self.path).path
        if path not in {"/", "/index.html", "/flutter_bootstrap.js"}:
            return super().send_head()

        build = hashlib.sha256((WEB_ROOT / "main.dart.js").read_bytes()).hexdigest()[:16]
        filename = "flutter_bootstrap.js" if path.endswith(".js") else "index.html"
        content = (WEB_ROOT / filename).read_text(encoding="utf-8")
        if filename == "index.html":
            content = content.replace(
                'src="flutter_bootstrap.js"', f'src="flutter_bootstrap.js?build={build}"'
            )
        else:
            content = content.replace(
                "_flutter.loader.load({",
                f'_flutter.loader.load({{config: {{assetBase: "/__build/{build}/"}},',
            )
            content = re.sub(
                r'("mainJsPath"\s*:\s*")main\.dart\.js(")',
                rf'\g<1>main.dart.js?build={build}\2', content,
            )
            # A legacy Flutter worker must update to the current SDK's cleanup worker.
            content = re.sub(
                r'(serviceWorkerVersion:\s*)"[^"]+"', rf'\g<1>"{build}"', content
            )
        body = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(filename) + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Aster-Build", build)
        self.end_headers()
        return io.BytesIO(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 4173), PreviewHandler).serve_forever()
