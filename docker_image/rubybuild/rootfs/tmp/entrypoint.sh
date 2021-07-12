#!/bin/sh

./autogen.sh
cd ../
mkdir build
cd build

../ruby/configure --prefix=$PWD/../install
