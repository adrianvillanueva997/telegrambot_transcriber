FROM rust:1.79.0-slim-bullseye@sha256:b31b22ae29018e736bedfff2b877bf1a900a3fe323c9404a108304df9a8bfcc4 AS build
WORKDIR /build
RUN apt-get update && \
  apt-get install -y apt-utils pkg-config libssl-dev --no-install-recommends  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* /var/tmp/*
COPY . .
RUN cargo build --release

FROM ubuntu:24.04@sha256:3f85b7caad41a95462cf5b787d8a04604c8262cdcdf9a472b8c52ef83375fe15 AS prod
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
