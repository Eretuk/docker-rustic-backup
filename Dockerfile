FROM rust:1.82-alpine AS builder

WORKDIR /app
RUN apk add --no-cache musl-dev pkgconfig openssl-dev

# Собираем rustic с поддержкой S3
RUN cargo install --locked --git https://github.com/rustic-rs/rustic --tag v0.10.0 --features s3

# финальный образ
FROM alpine:3.20
RUN apk add --no-cache ca-certificates bash curl dcron tzdata

# копируем бинарник rustic
COPY --from=builder /usr/local/cargo/bin/rustic /usr/local/bin/rustic

# скрипты
COPY backup.sh /usr/local/bin/backup.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /start.sh

CMD ["/start.sh"]