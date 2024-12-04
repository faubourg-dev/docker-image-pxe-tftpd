# syntax=docker/dockerfile:1

# Get Alpine tag from: https://hub.docker.com/_/alpine
FROM alpine:3.20.3 AS builder

ARG HTTP_PORT=8069

# check: https://pkgs.alpinelinux.org/packages?branch=v3.17
RUN apk add --no-cache \
            make=4.4.1-r2 \
            gcc=13.2.1_git20240309-r0 \
            musl-dev=1.2.5-r0 \
            xz-dev=5.6.2-r0 \
            perl=5.38.2-r0 \
            patch=2.7.6-r10 \
            git=2.45.2-r0

WORKDIR /build/

RUN git clone https://github.com/ipxe/ipxe.git

WORKDIR /build/ipxe/

#ADD https://github.com/ipxe/ipxe/pull/612.patch 612.patch
#
#RUN patch -p 1 < 612.patch

WORKDIR /build/ipxe/src/

RUN sed -i '/DOWNLOAD_PROTO_HTTPS/s/#undef/#define/'     config/general.h; \
    sed -i '/PING_CMD/s/\/\/#define/#define/'            config/general.h; \
    sed -i '/CONSOLE_CMD/s/\/\/#define/#define/'         config/general.h; \
    sed -i '/CONSOLE_FRAMEBUFFER/s/\/\/#define/#define/' config/console.h; \
    sed -i '/KEYBOARD_MAP/s/us/fr/'                      config/console.h; \
    sed -i '/DOWNLOAD_PROTO_NFS/s/#undef/#define/'     config/general.h; \
    sed -i '/IPSTAT_CMD/s/\/\/#define/#define/'            config/general.h; \
    sed -i '/REBOOT_CMD/s/\/\/#define/#define/'            config/general.h; \
    sed -i '/POWEROFF/s/\/\/#define/#define/'            config/general.h;

COPY embedded.ipxe .

RUN \
    sed -i "s/HTTP_PORT/${HTTP_PORT}/g" embedded.ipxe;    \
    make -j$(nproc) bin-x86_64-pcbios/ipxe.pxe EMBED=embedded.ipxe;  \
    make -j$(nproc) bin-x86_64-efi/ipxe.efi    EMBED=embedded.ipxe

# Get Alpine tag from: https://hub.docker.com/_/alpine
FROM alpine:3.20.3

ARG ROOT_DIR=/tftpboot
ARG LISTEN_ADDR
ARG PORT=69
ARG DEBUG
ARG BLOCK_SIZE=1468

LABEL org.opencontainers.image.authors='dreknix <dreknix@proton.me>' \
      org.opencontainers.image.base.name='alpine:3.71.1' \
      org.opencontainers.image.licenses='MIT' \
      org.opencontainers.image.source='https://github.com/dreknix/docker-image-pxe-tftpd.git' \
      org.opencontainers.image.title='Docker image for TFTP server in PXE' \
      org.opencontainers.image.url='https://github.com/dreknix/docker-image-pxe-tftpd'

# check: https://pkgs.alpinelinux.org/packages?branch=v3.17
RUN apk add --no-cache \
            tftp-hpa=5.2-r7

WORKDIR /

COPY --from=builder /build/ipxe/src/bin-x86_64-pcbios/ipxe.pxe /
COPY --from=builder /build/ipxe/src/bin-x86_64-efi/ipxe.efi    /

COPY entrypoint.sh /

EXPOSE ${PORT}/udp

VOLUME ${ROOT_DIR}

ENV ROOT_DIR=${ROOT_DIR}
ENV LISTEN_ADDR=${LISTEN_ADDR}
ENV PORT=${PORT}
ENV DEBUG=${DEBUG}
ENV BLOCK_SIZE=${BLOCK_SIZE}

ENTRYPOINT [ "sh", "-c", "/entrypoint.sh" ]
