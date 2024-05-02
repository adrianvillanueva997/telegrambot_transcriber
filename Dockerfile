FROM rust:1.77.2-slim-bullseye@sha256:7479fa9dfc57f84dd90db9b0149b0a5e1076d902d6c31ea73ee5464d52d7c168 AS build
WORKDIR /build
RUN apt-get update && \
  apt-get install -y apt-utils pkg-config libssl-dev --no-install-recommends  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* /var/tmp/*
COPY . .
RUN cargo build --release

FROM ubuntu:22.04@sha256:a6d2b38300ce017add71440577d5b0a90460d0e57fd7aec21dd0d1b0761bbfb2 AS prod
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" | tee /etc/apt/sources.list.d/focal-security.list
RUN apt-get update && \
  apt-get install -y python3 python3-pip apt-utils ca-certificates pkg-config libssl-dev libssl1.1 ffmpeg pipx --no-install-recommends && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* /var/tmp/*
WORKDIR /app
RUN pipx install vosk
COPY --from=build /build/target/release/transcriber_telegrambot .
RUN adduser --disabled-password appuser
USER appuser
ENV RUST_LOG=debug
EXPOSE 80

USER root
RUN chown -R appuser:appuser /app
USER appuser

ENTRYPOINT [ "./transcriber_telegrambot" ]
