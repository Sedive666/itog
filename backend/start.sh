#!/bin/sh
# Запуск PocketBase в контейнере.
# Пароль суперпользователя панели /_/ задаётся переменной окружения на хостинге, в репозитории его нет.
set -e

if [ -n "$PB_SUPERUSER_EMAIL" ] && [ -n "$PB_SUPERUSER_PASSWORD" ]; then
  ./pocketbase superuser upsert "$PB_SUPERUSER_EMAIL" "$PB_SUPERUSER_PASSWORD"
fi

# Хостинг передаёт порт в переменной PORT. Миграции применяются при старте.
exec ./pocketbase serve --http "0.0.0.0:${PORT:-8090}"
