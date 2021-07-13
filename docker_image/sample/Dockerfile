FROM debian:buster-slim

ENV PG_MAJOR 13
ENV RAILS_ENV production
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y gnupg sudo curl
RUN apt update && apt install -y fping

RUN apt -y install software-properties-common
RUN apt-mark hold initscripts
RUN apt -y upgrade

RUN apt install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

RUN apt -y install nodejs

RUN curl https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" | \
        tee /etc/apt/sources.list.d/postgres.list
RUN curl --silent --location https://deb.nodesource.com/setup_15.x | sudo bash -
RUN apt -y update

RUN apt -y install --no-install-recommends git rsyslog logrotate cron ssh-client less
RUN apt -y install build-essential rsync \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk parallel \
                       postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR} \
                       postgresql-contrib-${PG_MAJOR} libpq-dev libreadline-dev \
                       wget psmisc vim whois brotli libunwind-dev \
                       libtcmalloc-minimal4 cmake \
                       pngcrush pngquant nginx

RUN cd / &&\
    apt -y install runit socat &&\
    mkdir -p /etc/runit/1.d &&\
    apt clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US &&\
    apt install -y nodejs &&\
    npm install -g terser &&\
    npm install -g uglify-js

RUN  apt install -y gcc && \
  apt install -y ruby subversion autoconf bison make git && \
  apt install -y libgmp-dev libssl-dev zlib1g-dev libffi-dev libreadline-dev libgdbm-dev && \
  apt install -y vim gdb

RUN mkdir /opt/devruby

ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/opt/devruby/lib
ENV PATH /opt/devruby/bin:$PATH


# Install benchmark tools
RUN apt-get install -y apache2-utils libsqlite3-dev

# Install redmine
RUN useradd redmine -s /bin/bash -m -U &&\
    mkdir -p /var/www &&\
    cd /var/www &&\
    git clone --depth 1 https://github.com/redmine/redmine &&\
    cd redmine &&\
    chown -R redmine:redmine /var/www/redmine &&\
    cd /var/www/redmine

RUN chown -R redmine /var/run/postgresql
# create role "redmine"
RUN /etc/init.d/postgresql start &&\
    sleep 5 &&\
    sudo -u postgres -E psql --command "CREATE USER redmine WITH SUPERUSER PASSWORD 'redmine'";

# copy setting files
COPY /approot/ /var/www/redmine/

COPY /rootfs/tmp /tmp
RUN chmod -R +x /tmp

WORKDIR /var/www/redmine

EXPOSE 3000

CMD [ "/tmp/entrypoint.sh" ]
