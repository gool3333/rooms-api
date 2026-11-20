#!/usr/bin/env bash
# Самопроверка лабораторной «DevOps workflow». Запуск из корня проекта: bash tools/check-lab.sh
cd "$(dirname "$0")/.." || exit 1
ok=0; total=0
pass() { ok=$((ok+1)); total=$((total+1)); echo "[OK]   $1"; }
fail() { total=$((total+1)); echo "[FAIL] $1"; }
warn() { echo "[WARN] $1"; }
has() { grep -q -- "$2" "$1" 2>/dev/null; }

echo "=== Проверка лабораторной DevOps workflow | $(git config user.name 2>/dev/null) | $(date '+%Y-%m-%d %H:%M:%S') ==="

echo "--- 1. Репозиторий"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then pass "это git-репозиторий"; else fail "это не git-репозиторий (git init не выполнен)"; fi
if git remote get-url origin 2>/dev/null | grep -q "github.com"; then pass "remote origin указывает на GitHub"; else fail "нет remote origin на GitHub"; fi
n=$(git rev-list --count HEAD 2>/dev/null || echo 0)
if [ "$n" -ge 3 ]; then pass "коммитов в истории: $n"; else fail "коммитов в истории: $n (нужно минимум 3)"; fi

echo "--- 2. Файлы, которые набираются вручную"
for f in Dockerfile .dockerignore .github/workflows/delivery.yml deploy/.env; do
  if [ -f "$f" ]; then pass "есть $f"; else fail "нет $f"; fi
done

echo "--- 3. Dockerfile"
has Dockerfile "AS test"          && pass "есть тестовая стадия (AS test)"          || fail "нет стадии AS test"
has Dockerfile "COPY --from=test" && pass "итоговый образ зависит от тестов"        || fail "нет COPY --from=test"
has Dockerfile "^USER "           && pass "приложение запускается не от root"       || fail "нет инструкции USER"
has Dockerfile "ARG APP_VERSION"  && pass "версия передаётся при сборке"            || fail "нет ARG APP_VERSION"

echo "--- 4. Pipeline"
W=.github/workflows/delivery.yml
has $W "needs: test"              && pass "публикация ждёт тесты (needs: test)"     || fail "нет needs: test"
has $W "docker/login-action"      && pass "вход в Docker Hub через action"          || fail "нет docker/login-action"
has $W "secrets.DOCKERHUB_TOKEN"  && pass "токен берётся из секретов GitHub"        || fail "токен не из secrets"
if git grep -q -E "dckr_pat_[A-Za-z0-9]|DOCKERHUB_TOKEN *[:=] *[A-Za-z0-9]" -- . ":(exclude)tools" 2>/dev/null; then fail "в репозитории найден токен в открытом виде!"; else pass "токенов в коде нет"; fi

echo "--- 5. Секреты деплоя"
if [ -z "$(git ls-files deploy/.env 2>/dev/null)" ]; then pass "deploy/.env не попал в git"; else fail "deploy/.env закоммичен в git"; fi

echo "--- 6. Работающий сервис"
TAG=$(grep -E '^TAG=' deploy/.env 2>/dev/null | cut -d= -f2 | tr -d '\r ')
USER_HUB=$(grep -E '^DOCKERHUB_USER=' deploy/.env 2>/dev/null | cut -d= -f2 | tr -d '\r ')
H=$(curl -s --max-time 5 http://localhost:8000/health)
if [ -n "$H" ]; then
  echo "       ответ /health: $H"
  V=$(echo "$H" | sed -E 's/.*"version": *"([^"]*)".*/\1/')
  case "$V" in sha-*) pass "работает образ из CI (версия $V)";; *) fail "версия '$V' — образ собран не в CI";; esac
  [ "$V" = "$TAG" ] && pass "версия совпадает с TAG из deploy/.env" || fail "версия $V не совпадает с TAG=$TAG"
else
  fail "http://localhost:8000/health не отвечает (стек не запущен?)"
fi

echo "--- 7. Docker Hub"
if [ -n "$USER_HUB" ]; then
  T=$(curl -s --max-time 10 "https://hub.docker.com/v2/repositories/$USER_HUB/rooms-api/tags?page_size=50")
  if [ -n "$T" ]; then
    c=$(echo "$T" | grep -o '"name": *"sha-[0-9a-f]*"' | wc -l | tr -d ' ')
    if [ "$c" -ge 2 ]; then pass "в Docker Hub версий sha-*: $c"; else fail "в Docker Hub версий sha-*: $c (нужно минимум 2)"; fi
  else warn "Docker Hub недоступен, пункт пропущен"; fi
else fail "в deploy/.env нет DOCKERHUB_USER"; fi

echo "=== Итого: $ok из $total ==="
