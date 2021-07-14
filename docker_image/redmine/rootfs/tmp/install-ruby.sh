#!/bin/sh

cd /home/rubybuild/ruby
./autogen.sh
cd ../
mkdir build
cd build

../ruby/configure --prefix=/opt/devruby --enable-shared
make -j5
make install
