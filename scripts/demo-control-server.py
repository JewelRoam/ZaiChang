#!/usr/bin/env python3

import argparse
import json
import queue
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


COMMANDS: queue.Queue[dict[str, object]] = queue.Queue()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/health":
            self.respond(200, {"status": "ok", "queued": COMMANDS.qsize()})
            return

        if self.path == "/commands/next":
            try:
                command = COMMANDS.get_nowait()
            except queue.Empty:
                self.send_response(204)
                self.end_headers()
                return
            self.respond(200, command)
            return

        self.respond(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/commands/advance-time":
            body = self.read_json()
            seconds = body.get("seconds")
            if not isinstance(seconds, int) or isinstance(seconds, bool) or not 1 <= seconds <= 86_400:
                self.respond(400, {"error": "seconds_must_be_an_integer_between_1_and_86400"})
                return
            command = {"type": "advanceTime", "seconds": seconds}
        elif self.path == "/commands/receive-nudge":
            command = {"type": "receiveNudge"}
        else:
            self.respond(404, {"error": "not_found"})
            return

        COMMANDS.put(command)
        self.respond(202, {"accepted": command, "queued": COMMANDS.qsize()})

    def read_json(self) -> dict[str, object]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = self.rfile.read(length) if length else b"{}"
            value = json.loads(payload)
            return value if isinstance(value, dict) else {}
        except (ValueError, json.JSONDecodeError):
            return {}

    def respond(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, message: str, *args: object) -> None:
        if self.path == "/commands/next":
            return
        print(f"{self.address_string()} - {message % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Local demo command service for Zaichang")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Zaichang demo control listening on http://127.0.0.1:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
