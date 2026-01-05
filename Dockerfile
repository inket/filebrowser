## Multistage build: First stage fetches dependencies
FROM alpine:3.23 AS fetcher

# install and copy ca-certificates, mailcap, and tini-static; download JSON.sh
RUN apk update && \
    apk --no-cache add ca-certificates mailcap tini-static wget && \
    wget -O /JSON.sh https://raw.githubusercontent.com/dominictarr/JSON.sh/0d5e5c77365f63809bf6e77ef44a1f34b0e05840/JSON.sh

# Download Filebrowser tar.gz and extract
ENV FILEBROWSER_VERSION=v2.53.1
RUN wget -O /filebrowser.tar.gz https://github.com/filebrowser/filebrowser/releases/download/${FILEBROWSER_VERSION}/linux-amd64-filebrowser.tar.gz && \
    tar -xzf /filebrowser.tar.gz -C / && \
    rm /filebrowser.tar.gz

## Second stage: Use lightweight BusyBox image for final runtime environment
FROM busybox:1.37.0-musl

# Define non-root user UID and GID
ENV UID=99
ENV GID=100

# Create user group and user
#RUN addgroup -g $GID user && \
#    adduser -D -u $UID -G user user

# Copy Filebrowser binary from fetcher stage
COPY --chown=99:100 --from=fetcher /filebrowser /bin/filebrowser

# Copy binary, scripts, and configurations into image with proper ownership
COPY --chown=99:100 docker/common/ /
COPY --chown=99:100 docker/alpine/ /
COPY --chown=99:100 --from=fetcher /sbin/tini-static /bin/tini
COPY --from=fetcher /JSON.sh /JSON.sh
COPY --from=fetcher /etc/ca-certificates.conf /etc/ca-certificates.conf
COPY --from=fetcher /etc/ca-certificates /etc/ca-certificates
COPY --from=fetcher /etc/mime.types /etc/mime.types
COPY --from=fetcher /etc/ssl /etc/ssl

# Create data directories, set ownership, and ensure healthcheck script is executable
RUN mkdir -p /config /database /srv && \
    chown -R 99:100 /config /database /srv \
    && chmod +x /healthcheck.sh

# Define healthcheck script
HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh

# Set the user, volumes and exposed ports
USER user

VOLUME /srv /config /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]
