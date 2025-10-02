# Use a slim base image directly
FROM debian:bookworm-slim

# Define the version of Rustic to install as a build argument
ARG RUSTIC_VERSION=v0.10.0

# Set DEBIAN_FRONTEND to noninteractive to suppress warnings
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    cron bash curl tzdata ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/rustic-rs/rustic/releases/download/${RUSTIC_VERSION}/rustic-${RUSTIC_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    | tar -xvzf - -C /usr/local/bin rustic && \
    \
    curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    \
    chmod +x /usr/local/bin/rustic /usr/local/bin/mc

# --- Configure the shell to auto-source the sanitized environment ---
# This makes interactive sessions (`docker exec -it ... bash`) work correctly out-of-the-box.
RUN echo '\n# Source sanitized environment variables if available' >> /root/.bashrc && \
    echo 'if [ -f /etc/profile.d/00-rustic-env.sh ]; then . /etc/profile.d/00-rustic-env.sh; fi' >> /root/.bashrc

COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY start.sh /start.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /start.sh

CMD ["/start.sh"]