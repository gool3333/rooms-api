# rooms-api — бронирование переговорных ITHUB

Учебный API для лабораторной «DevOps workflow: от коммита до работающего сервиса».

| Файл | Назначение |
|---|---|
| app.py | API на Python (только стандартная библиотека) |
| test_app.py | автотесты: без них образ не собирается |
| deploy/compose.yml | «сервер»: запускает опубликованный образ по тегу |
| tools/check-lab.sh | самопроверка лабораторной |

Маршруты: GET /health, GET /rooms, GET /bookings, POST /bookings.

Dockerfile, .dockerignore, .github/workflows/delivery.yml и deploy/.env
вы создаёте сами по инструкции.
