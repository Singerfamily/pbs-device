FROM denoland/deno:2.3.5 AS deno

WORKDIR /app

# Copy cli/*, deno.json and deno.lock

COPY cli/ /app/
COPY deno.json /app/
COPY deno.lock /app/

RUN deno cache \
    --lock=deno.lock \
    --unstable-kv \
    --no-check \
    main.ts

RUN deno compile \
    --allow-all \
    --unstable-kv \
    --output bin/pbs \
    main.ts

FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie AS base
RUN apt-get update && \
    apt-get install -y \
    vlc \
    ffmpeg \
    v4l2loopback-dkms \
    v4l-utils \
    pulseaudio \
    pulseaudio-utils \
    konsole \
    obs-studio \
    dolphin \
    wget \    
    && rm -rf /var/lib/apt/lists/*

COPY obs/scripts /scripts

# RUN echo "root,abc ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# RUN usermod -a -G sudo,audio,pulse-access,pulse,voice root
# RUN usermod -a -G sudo,audio,pulse-access,pulse,voice abc

COPY /root /

COPY --from=deno /app/bin/pbs /usr/bin/pbs

ENV PBS_START_VISIBILITY=public
ENV PBS_STOP_VISIBILITY=unlisted
ENV CONSOLA_LEVEL=3