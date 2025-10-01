FROM rust:alpine AS builder

WORKDIR /app
RUN apk add --no-cache musl-dev pkgconfig openssl-dev

# Build rustic with s3 feature
RUN cargo install --locked \
    --git https://github.com/rustic-rs/rustic \
    --tag v0.10.0 \
    --features rustic_backend/opendal

# Final minimal image
FROM alpine:3.20
RUN apk add --no-cache ca-certificates bash curl dcron tzdata

COPY --from=builder /usr/local/cargo/bin/rustic /usr/local/bin/rustic

COPY backup.sh /usr/local/bin/backup.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /start.sh

CMD ["/start.sh"]