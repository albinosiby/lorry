"""Serve the built Flutter web app locally with GoRouter SPA fallback."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
ROOT = Path(__file__).resolve().parents[1] / 'build' / 'web'
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)
    def do_GET(self):
        route = urlparse(self.path).path
        candidate = (ROOT / route.lstrip('/')).resolve()
        if candidate.is_relative_to(ROOT) and not candidate.exists() and '.' not in Path(route).name:
            self.path = '/index.html'
        super().do_GET()
if __name__ == '__main__':
    if not (ROOT / 'index.html').exists():
        raise SystemExit('Run flutter build web first.')
    print('LORRY LINK preview: http://localhost:8080', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8080), Handler).serve_forever()
