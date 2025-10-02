# Stage 1: build - NO LONGER NEEDED!

# Use a slim base image directly
FROM debian:bookworm-slim

# Define the version of Rustic to install as a build argument
ARG RUSTIC_VERSION=v0.10.0

# Install runtime dependencies and download binaries in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron bash curl tzdata ca-certificates && \
    \
    # --- Install Rustic ---
    # Download the statically compiled (musl) version for maximum portability.
    # The version is controlled by the RUSTIC_VERSION build argument.
    curl -L -o rustic.tar.gz https://github.com/rustic-rs/rustic/releases/download/${RUSTIC_VERSION}/rustic-${RUSTIC_VERSION}-x86_64-unknown-linux-musl.tar.gz && \
    tar -xvzf rustic.tar.gz && \
    mv rustic-${RUSTIC_VERSION}-x86_64-unknown-linux-musl/rustic /usr/local/bin/rustic && \
    \
    # --- Install MinIO Client (mc) ---
    curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    \
    # --- Set Permissions & Clean Up ---
    chmod +x /usr/local/bin/rustic /usr/local/bin/mc && \
    rm -rf rustic.tar.gz rustic-v* && \
    rm -rf /var/lib/apt/lists/*

# Copy our custom scripts into the image
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /start.sh

# Set the default command to run when the container starts
CMD ["/start.sh"]