#!/bin/bash

add_Gemfile() {
    echo "$@"; >> ${APP_INSTALL_DIR}/Gemfile
}
