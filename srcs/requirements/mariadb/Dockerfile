FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql/* \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /var/lib/mysql /run/mysqld

COPY conf/60-inception.cnf /etc/mysql/mariadb.conf.d/60-inception.cnf

CMD ["mariadbd", "--user=mysql", "--console"]