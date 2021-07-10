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


RUN apt install -y zlib1g-dev
RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && (ruby-build 2.7.2 /usr/local)

RUN gem update --system

# Install redmine
RUN useradd redmine -s /bin/bash -m -U &&\
    mkdir -p /var/www &&\
    cd /var/www &&\
    git clone --depth 1 https://github.com/redmine/redmine &&\
    cd redmine &&\
    chown -R redmine:redmine /var/www/redmine&&\
    cd /var/www/redmine

WORKDIR /var/www/redmine

# Install benchmark tools
RUN apt-get install -y apache2-utils libsqlite3-dev

RUN chown -R redmine /var/run/postgresql
# create role "redmine"
RUN /etc/init.d/postgresql start &&\
    sleep 5 &&\
    sudo -u postgres -E psql --command "CREATE USER redmine WITH SUPERUSER PASSWORD 'redmine'";

# copy setting files
COPY /script/database.yml /var/www/redmine/config/database.yml
COPY /script/unicorn.rb /var/www/redmine/config/unicorn.rb
COPY /script/Gemfile /var/www/redmine/Gemfile

RUN bundle config set --local without 'development test' && bundle install --jobs 3 --retry 5
RUN bundle config set --local without 'development test' && bundle clean --force

# Copy entrypoint.sh
COPY /rootfs/opt/appbench /opt/appbench
RUN chmod -R +x /opt/appbench

RUN chown -R redmine /var/www/redmine

EXPOSE 80

# ENTRYPOINT [ "/opt/appbench/scripts/redmine/entrypoint.sh" ]
