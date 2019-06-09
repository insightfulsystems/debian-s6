ARG BASE
FROM ${BASE}
ARG ARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get dist-upgrade -y \
 && apt-get install -y --no-install-recommends \
    apt-utils \
	ca-certificates \
	locales \
	curl \
	gnupg \
	tzdata \
 && apt-get install -y curl tzdata \
 && locale-gen en_US.UTF-8 \
 && VERSION=$(curl -SL https://api.github.com/repos/just-containers/s6-overlay/releases/latest | awk -v FS='[""]' '/tag_name/{print $4;exit}' | sed -e 's_v__') \
 && echo "using s6 version: $VERSION-$ARCH" \
 && curl -o /tmp/s6-overlay-${ARCH}.tar.gz -jkSL https://github.com/just-containers/s6-overlay/releases/download/v${VERSION}/s6-overlay-${ARCH}.tar.gz \
 && curl -o /tmp/s6-overlay-${ARCH}.tar.gz.sig -jkSL https://github.com/just-containers/s6-overlay/releases/download/v${VERSION}/s6-overlay-${ARCH}.tar.gz.sig \
 && curl -jkSL https://keybase.io/justcontainers/key.asc | gpg --import \
 && gpg --verify /tmp/s6-overlay-${ARCH}.tar.gz.sig /tmp/s6-overlay-${ARCH}.tar.gz \
 && tar xzf /tmp/s6-overlay-${ARCH}.tar.gz -C / \
 && useradd -u 911 -U -d /config -s /bin/false abc \
 && usermod -G users abc \
 && mkdir -p /app /config /data /defaults \
 && apt-get purge -y \
    apt-utils \
    curl \
	gnupg \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* 

COPY rootfs /

ENTRYPOINT [ "/init" ]

ARG VCS_REF
ARG VCS_URL
ARG BUILD_DATE
LABEL org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url=${VCS_URL} \
      org.label-schema.build-date=${BUILD_DATE}