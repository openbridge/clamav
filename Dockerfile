FROM alpine:3.8
MAINTAINER Thomas Spicer (thomas@openbridge.com)

ENV CLAMD_DEPS \
        git \
        linux-headers
RUN set -x \
    && apk add --no-cache --virtual .persistent-deps \
        bash \
        coreutils \
        wget \
        findutils \
        perl \
        curl \
        clamav-daemon \
        clamav-libunrar \
        monit \
    && apk add --no-cache --virtual .build-deps \
        $CLAMD_DEPS \
    && chmod +x /usr/bin/ \
    && wget -t 5 -T 99999 -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd \
    && wget -t 5 -T 99999 -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd \
    && wget -t 5 -T 99999 -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd \
    && mkdir -p /var/lib/clamav \
    && apk del .build-deps

COPY cron/crontab.conf /crontab.conf
COPY usr/bin/crond.sh /usr/bin/cron
COPY usr/bin/clamd.sh /usr/bin/clam
COPY etc/ /etc/
COPY tests/ /tests/
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod -R +x /docker-entrypoint.sh /usr/local/bin /usr/bin /tests

EXPOSE 3310

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/clamd", "-c", "/etc/clamd.conf"]
