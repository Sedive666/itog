# PocketBase в контейнере для Render: исполняемый файл Linux, миграции и хуки.
# Схема и тестовые данные создаются миграциями при первом запуске, отдельный скрипт заливки не нужен.
FROM alpine:3.20

RUN apk add --no-cache ca-certificates unzip wget

ARG PB_VERSION=0.40.5
RUN wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip" -O /tmp/pb.zip \
    && unzip /tmp/pb.zip -d /pb \
    && rm /tmp/pb.zip \
    && chmod +x /pb/pocketbase

WORKDIR /pb
COPY pb_migrations ./pb_migrations
COPY pb_hooks ./pb_hooks
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

EXPOSE 8090
CMD ["./start.sh"]
