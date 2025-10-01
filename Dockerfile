# Dockerfile
FROM alpine:latest

# Install dependencies: bash, curl, and the cron daemon (dcron)
RUN apk update && \
    apk add --no-cache bash curl dcron

# --- Install Rustic ---
# Define the version of Rustic to install
ENV RUSTIC_VERSION=v0.10.0
# IMPORTANT: Check the latest version on the Rustic GitHub release page!
RUN curl -L "https://github.com/rustic-rs/rustic/releases/download/${RUSTIC_VERSION}/rustic-${RUSTIC_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C /usr/local/bin/

# --- Setup Scripts ---
# Copy the core backup executor script (will be called by cron)
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

# Copy the daemon startup script (launches cron and keeps container alive)
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the entry point to the daemon startup script
CMD ["/start.sh"]