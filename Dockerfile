# Stage 1: build
FROM rust:bookworm AS builder

WORKDIR /app

# Установим зависимости для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Сборка rustic с backend opendal
RUN cargo install --locked \
    --git https://github.com/rustic-rs/rustic \
    --tag v0.10.0 \
    --features rustic_backend/opendal

# Stage 2: runtime
FROM debian:bookworm-slim

# Установим только минимальный набор пакетов для запуска
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    curl \
    cron \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/cargo/bin/rustic /usr/local/bin/rustic

COPY backup.sh /usr/local/bin/backup.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /start.sh

CMD ["/start.sh"]