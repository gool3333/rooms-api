"""Сервис бронирования переговорных ITHUB (учебный API для лабораторной DevOps workflow)."""
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = os.environ.get("APP_VERSION", "dev")
PORT = int(os.environ.get("PORT", "8000"))

ROOMS = {
    "orion": {"name": "Орион", "seats": 6},
    "vega": {"name": "Вега", "seats": 10},
    "lyra": {"name": "Лира", "seats": 4},
    "atlas": {"name": "Атлас", "seats": 8},
}
OPEN_HOUR, CLOSE_HOUR = 9, 18
BOOKINGS = []


def validate_booking(data):
    """Проверяет заявку. Возвращает текст ошибки или None, если всё верно."""
    if not isinstance(data, dict):
        return "тело запроса должно быть JSON-объектом"
    room, hour, who = data.get("room"), data.get("hour"), data.get("who")
    if room not in ROOMS:
        return "нет такой переговорной"
    if not isinstance(hour, int) or not OPEN_HOUR <= hour < CLOSE_HOUR:
        return f"час должен быть от {OPEN_HOUR} до {CLOSE_HOUR - 1}"
    if not isinstance(who, str) or not who.strip():
        return "укажите, кто бронирует (who)"
    if any(b["room"] == room and b["hour"] == hour for b in BOOKINGS):
        return "занято"
    return None


def add_booking(data):
    booking = {"id": len(BOOKINGS) + 1, "room": data["room"], "hour": data["hour"], "who": data["who"].strip()}
    BOOKINGS.append(booking)
    return booking


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"status": "ok", "version": VERSION, "host": socket.gethostname()})
        elif self.path == "/rooms":
            self._send(200, [{"id": k, **v} for k, v in ROOMS.items()])
        elif self.path == "/bookings":
            self._send(200, BOOKINGS)
        else:
            self._send(404, {"error": "маршрут не найден"})

    def do_POST(self):
        if self.path != "/bookings":
            self._send(404, {"error": "маршрут не найден"})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(length) or b"null")
        except (ValueError, json.JSONDecodeError):
            self._send(400, {"error": "некорректный JSON"})
            return
        error = validate_booking(data)
        if error:
            self._send(409 if error == "это время уже занято" else 400, {"error": error})
            return
        self._send(201, add_booking(data))

    def log_message(self, fmt, *args):
        print(f"{self.log_date_time_string()} version={VERSION} {fmt % args}", flush=True)


if __name__ == "__main__":
    print(f"rooms-api {VERSION} слушает порт {PORT}", flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
