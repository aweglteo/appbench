FROM debian:buster-slim

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


RUN  apt install -y gcc && \
  apt install -y ruby subversion autoconf bison make git && \
  apt install -y libgmp-dev libssl-dev zlib1g-dev libffi-dev libreadline-dev libgdbm-dev && \
  apt install -y vim gdb

COPY /rootfs/tmp /tmp
RUN chmod -R +x /tmp
WORKDIR /home/workdir/ruby

ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/home/workdir/install/lib
ENV PATH $PATH:/home/workdir/install/bin




CMD [ "/tmp/entrypoint.sh" ]
