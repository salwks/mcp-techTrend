"""웹 프로토타입(seolhwa/)을 서빙하고, 브라우저에서 PUT /export/<파일>로 보낸 내보내기 결과를 seolhwa_godot/import/에 저장한다."""
import http.server, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WEB = os.path.join(ROOT, 'seolhwa')
OUT = os.path.join(ROOT, 'seolhwa_godot', 'data')

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=WEB, **k)
    def translate_path(self, path):
        # /__tools/ 아래는 이 폴더(내보내기 스크립트)
        if path.startswith('/__tools/'):
            return os.path.join(os.path.dirname(os.path.abspath(__file__)), os.path.basename(path.split('?')[0]))
        return super().translate_path(path)
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store'); super().end_headers()
    def do_PUT(self):
        if not self.path.startswith('/export/'): return self.send_error(404)
        rel = os.path.normpath(self.path[len('/export/'):])
        if rel.startswith('..') or os.path.isabs(rel): return self.send_error(400)
        dest = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        data = self.rfile.read(int(self.headers['Content-Length']))
        with open(dest, 'wb') as f: f.write(data)
        self.send_response(200); self.end_headers(); self.wfile.write(b'ok')

http.server.ThreadingHTTPServer(('', int(sys.argv[1]) if len(sys.argv) > 1 else 8770), H).serve_forever()
