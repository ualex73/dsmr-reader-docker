FROM python:alpine

ENV DSMR_READER_VERSION v4.13.0

ENV DSMRREADER_ADMIN_USER admin
ENV DSMRREADER_ADMIN_PASSWORD admin

ENV DJANGO_DATABASE_HOST dsmrdb
ENV DJANGO_DATABASE_USER dsmrreader
ENV DJANGO_DATABASE_PASSWORD dsmrreader
ENV DJANGO_DATABASE_NAME dsmrreader

COPY ./app/run.sh /run.sh

RUN apk --update add --no-cache \
      bash \
      curl \
      nginx \
      postgresql-client \
      mariadb-dev \
      supervisor \
      libressl-dev \
      musl-dev \
      libffi-dev \
      cargo \
      rust

RUN curl -s --location https://github.com/dsmrreader/dsmr-reader/archive/${DSMR_READER_VERSION}.tar.gz -o /tmp/dsmr.tar.gz && \
    tar -xzf /tmp/dsmr.tar.gz -C / && \
    mv /dsmr-reader* /dsmr && \
    rm -f /tmp/dsmr.tar.gz && \
    apk add --virtual .build-deps gcc musl-dev postgresql-dev && \
    pip3 install six psycopg2-binary --no-cache && \
    sed -i "s/dropbox==.*/dropbox==11.2.0/" /dsmr/dsmrreader/provisioning/requirements/base.txt && \
    pip3 install -r /dsmr/dsmrreader/provisioning/requirements/base.txt --no-cache-dir && \
    apk --purge del .build-deps && \
    rm -rf /tmp/* && \
    mkdir -p /run/nginx/ && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    rm -f /etc/nginx/conf.d/default.conf && \
    mkdir -p /var/www/dsmrreader/static && \
    cp /dsmr/dsmrreader/provisioning/nginx/dsmr-webinterface /etc/nginx/conf.d/dsmr-webinterface.conf && \ 
    cp /dsmr/dsmrreader/provisioning/django/settings.py.template /dsmr/dsmrreader/settings.py && \
    cp /dsmr/.env.template /dsmr/.env && \
    /dsmr/tools/generate-secret-key.sh && \
    chmod u+x /run.sh

COPY ./app/supervisord.ini /etc/supervisor.d/

EXPOSE 80 443

WORKDIR /dsmr

CMD ["/run.sh"]
