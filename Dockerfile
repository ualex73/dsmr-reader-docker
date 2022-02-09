# ###########
# First Stage
# ###########

FROM python:alpine AS build

ENV DSMR_READER_VERSION v5.0.0

RUN apk add --no-cache \
    curl \
    gcc \
    musl-dev \
    postgresql-dev \
    libressl-dev \
    libffi-dev \
    cargo \
    zlib-dev \
    jpeg-dev \
    rust && \
    curl -s --location https://github.com/dsmrreader/dsmr-reader/archive/${DSMR_READER_VERSION}.tar.gz -o /tmp/dsmr.tar.gz && \
    tar -xzf /tmp/dsmr.tar.gz -C / && \
    mv /dsmr-reader* /dsmr && \
    rm -f /tmp/dsmr.tar.gz && \
    pip3 install six psycopg2-binary --no-cache && \
    pip3 install -r /dsmr/dsmrreader/provisioning/requirements/base.txt --no-cache-dir

# ############
# Second Stage
# ############

FROM python:alpine

COPY --from=build /dsmr /dsmr
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

ENV DSMR_READER_VERSION v4.19.0

ENV DJANGO_DATABASE_ENGINE django.db.backends.postgresql

ENV DJANGO_DATABASE_HOST dsmrdb
ENV DJANGO_DATABASE_PORT 5432

ENV DJANGO_DATABASE_USER dsmrreader
ENV DJANGO_DATABASE_PASSWORD dsmrreader
ENV DJANGO_DATABASE_NAME dsmrreader

ENV DSMRREADER_ADMIN_USER admin
ENV DSMRREADER_ADMIN_PASSWORD admin

ENV DATALOGGER_INPUT_METHOD=serial
ENV DATALOGGER_SERIAL_PORT=/dev/ttyUSB0
ENV DATALOGGER_SERIAL_BAUDRATE=115200
ENV DATALOGGER_NETWORK_HOST=127.0.0.1
ENV DATALOGGER_NETWORK_PORT=2000

ENV DSMR_MODE=SERVER

COPY ./app /app

RUN apk --update add --no-cache \
      bash \
      nginx \
      postgresql-client \
      supervisor && \ 
    echo "#1" && \
    mkdir -p /run/nginx/ && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    rm -f /etc/nginx/http.d/default.conf && \
    mkdir -p /var/www/dsmrreader/static && \
    cp /dsmr/dsmrreader/provisioning/nginx/dsmr-webinterface /etc/nginx/http.d/dsmr-webinterface.conf && \
    cp /dsmr/dsmrreader/provisioning/django/settings.py.template /dsmr/dsmrreader/settings.py && \
    cp /dsmr/.env.template /dsmr/.env && \
    /dsmr/tools/generate-secret-key.sh && \
    mkdir -p /etc/supervisor.d/ && \
    mv /app/supervisord.ini /etc/supervisor.d/ && \
    chmod u+x /app/*.sh

EXPOSE 80 443

WORKDIR /dsmr

CMD ["/app/run.sh"]
