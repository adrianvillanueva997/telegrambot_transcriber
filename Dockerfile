FROM rust:1.77.2-slim-bullseye@sha256:e6415812ccaa674a660edac8b17190c7d867f9dc5019024a8c72caaec3c20b62 AS build
WORKDIR /build
RUN apt-get update && \
  apt-get install -y apt-utils pkg-config libssl-dev --no-install-recommends  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* /var/tmp/*
COPY . .
RUN cargo build --release

FROM ubuntu:22.04@sha256:77906da86b60585ce12215807090eb327e7386c8fafb5402369e421f44eff17e AS prod
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
