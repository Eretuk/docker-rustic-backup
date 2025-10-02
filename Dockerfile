# Use a slim base image directly
FROM debian:bookworm-slim

# Define the version of Rustic to install as a build argument
ARG RUSTIC_VERSION=v0.10.0

# Set DEBIAN_FRONTEND to noninteractive to suppress warnings during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies and download binaries in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron bash curl tzdata ca-certificates && \
    \
    # --- Install Rustic ---
    # Download and extract the rustic binary directly into /usr/local/bin in one command.
    # - The pipe `|` sends the downloaded archive directly to tar.
    # - `tar -xvzf -` reads the archive from standard input.
    # - `-C /usr/local/bin` tells tar to extract into the target directory.
    # - `rustic` at the end tells tar to only extract that specific file.
    curl -L https://github.com/rustic-rs/rustic/releases/download/${RUSTIC_VERSION}/rustic-${RUSTIC_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    | tar -xvzf - -C /usr/local/bin rustic && \
    \
    # --- Install MinIO Client (mc) ---
    curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    \
    # --- Set Permissions & Clean Up ---
    chmod +x /usr/local/bin/rustic /usr/local/bin/mc && \
    rm -rf /var/lib/apt/lists/*

# Copy our custom scripts into the image
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /start.sh

# Set the default command to run when the container starts
CMD ["/start.sh"]