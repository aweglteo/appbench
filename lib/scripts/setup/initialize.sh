#!/bin/bash
#
# Initialize Discourse

# Load generic libraries
. /opt/appbench/scripts/lib/libfs.sh
. /opt/appbench/scripts/lib/libos.sh
. /opt/appbench/scripts/lib/libfile.sh
. /opt/appbench/scripts/lib/libvalidations.sh
. /opt/appbench/scripts/lib/libpersistence.sh

########################
# Validate settings in DISCOURSE_* env vars
# Globals:
#   DISCOURSE_*
# Arguments:
#   None
# Returns:
#   0 if the validation succeeded, 1 otherwise
#########################
discourse_validate() {
    debug "Validating settings in DISCOURSE_* environment variables..."
    local error_code=0

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }
    check_empty_value() {
        if is_empty_value "${!1}"; then
            print_validation_error "${1} must be set"
        fi
    }
    check_yes_no_value() {
        if ! is_yes_no_value "${!1}" && ! is_true_false_value "${!1}"; then
            print_validation_error "The allowed values for ${1} are: yes no"
        fi
    }
    check_multi_value() {
        if [[ " ${2} " != *" ${!1} "* ]]; then
            print_validation_error "The allowed values for ${1} are: ${2}"
        fi
    }
    check_resolved_hostname() {
        if ! is_hostname_resolved "$1"; then
            warn "Hostname ${1} could not be resolved, this could lead to connection issues"
        fi
    }
    check_password_length() {
        local password_var="${1:?missing password_var}"
        local length="${2:?missing length}"
        local password="${!1}"
        if [[ "${#password}" -lt "$length" ]]; then
            print_validation_error "${password_var} must be at least ${length} characters"
        fi
    }
    check_valid_port() {
        local port_var="${1:?missing port variable}"
        local err
        if ! err="$(validate_port "${!port_var}")"; then
            print_validation_error "An invalid port was specified in the environment variable ${port_var}: ${err}."
        fi
    }

    # Warn users in case the configuration file is not writable
    is_file_writable "$DISCOURSE_CONF_FILE" || warn "The Discourse configuration file '${DISCOURSE_CONF_FILE}' is not writable. Configurations based on environment variables will not be applied for this file."

    # Validate user inputs
    check_empty_value "DISCOURSE_HOST"
    check_multi_value "DISCOURSE_ENV" "development production test"
    check_multi_value "DISCOURSE_PASSENGER_SPAWN_METHOD" "direct smart"
    check_password_length "DISCOURSE_PASSWORD" 10
    ! is_empty_value "$DISCOURSE_ENABLE_HTTPS" && check_yes_no_value "DISCOURSE_ENABLE_HTTPS"
    ! is_empty_value "$DISCOURSE_SKIP_BOOTSTRAP" && check_yes_no_value "DISCOURSE_SKIP_BOOTSTRAP"
    ! is_empty_value "$DISCOURSE_DATABASE_HOST" && check_resolved_hostname "$DISCOURSE_DATABASE_HOST"
    ! is_empty_value "$DISCOURSE_DATABASE_PORT_NUMBER" && check_valid_port "DISCOURSE_DATABASE_PORT_NUMBER"
    ! is_empty_value "$DISCOURSE_REDIS_HOST" && check_resolved_hostname "$DISCOURSE_REDIS_HOST"
    ! is_empty_value "$DISCOURSE_REDIS_PORT_NUMBER" && check_valid_port "DISCOURSE_REDIS_PORT_NUMBER"
    if ! is_file_writable "$DISCOURSE_CONF_FILE"; then
        warn "The Discourse configuration file ${DISCOURSE_CONF_FILE} is not writable. Configurations specified via environment variables will not be applied to this file."
        is_boolean_yes "$DISCOURSE_ENABLE_CONF_PERSISTENCE" && warn "The DISCOURSE_ENABLE_CONF_PERSISTENCE configuration is enabled but the ${DISCOURSE_CONF_FILE} file is not writable. The file will not be persisted."
    fi

    # Validate credentials
    if is_boolean_yes "${ALLOW_EMPTY_PASSWORD:-}"; then
        warn "You set the environment variable ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD:-}. For safety reasons, do not use this flag in a production environment."
    else
        # Do not throw an error yet, since the option did not exist before and it would break upgrades
        for empty_env_var in "DISCOURSE_DATABASE_PASSWORD" "DISCOURSE_REDIS_PASSWORD"; do
            is_empty_value "${!empty_env_var}" && warn "The ${empty_env_var} environment variable is empty or not set. Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow a blank password. This is only recommended for development environments."
        done
    fi

    # Validate SMTP credentials
    if ! is_empty_value "$DISCOURSE_SMTP_HOST"; then
        for empty_env_var in "DISCOURSE_SMTP_USER" "DISCOURSE_SMTP_PASSWORD"; do
            is_empty_value "${!empty_env_var}" && warn "The ${empty_env_var} environment variable is empty or not set."
        done
        is_empty_value "$DISCOURSE_SMTP_PORT_NUMBER" && print_validation_error "The DISCOURSE_SMTP_PORT_NUMBER environment variable is empty or not set."
        ! is_empty_value "$DISCOURSE_SMTP_PORT_NUMBER" && check_valid_port "DISCOURSE_SMTP_PORT_NUMBER"
        ! is_empty_value "$DISCOURSE_SMTP_PROTOCOL" && check_multi_value "DISCOURSE_SMTP_PROTOCOL" "ssl tls"
        check_multi_value "DISCOURSE_SMTP_AUTH" "plain login cram_md5"
    fi

    return "$error_code"
}


########################
# Ensure Discourse is initialized
# Globals:
#   DISCOURSE_*
# Arguments:
#   None
# Returns:
#   None
#########################
discourse_initialize() {
    local -a postgresql_remote_execute_args=("$DISCOURSE_DATABASE_HOST" "$DISCOURSE_DATABASE_PORT_NUMBER" "$DISCOURSE_DATABASE_NAME" "$DISCOURSE_DATABASE_USER" "$DISCOURSE_DATABASE_PASSWORD")
    
    if is_file_writable "$DISCOURSE_CONF_FILE"; then
        if is_boolean_yes "$DISCOURSE_ENABLE_CONF_PERSISTENCE"; then
            DISCOURSE_DATA_TO_PERSIST+=" ${DISCOURSE_CONF_FILE}"
            # Avoid restarts causing config file recreation due to symlink still being present
            rm -f "$DISCOURSE_CONF_FILE"
        fi
        info "Creating Discourse configuration file"
        discourse_create_conf_file
    fi

    local -r app_name="discourse"

    if ! is_app_initialized "$app_name"; then
        # Ensure Discourse persisted directories exist (i.e. when a volume has been mounted to /appbench)
        info "Ensuring Discourse directories exist"
        ensure_dir_exists "$DISCOURSE_VOLUME_DIR"
        # Use daemon:root ownership for compatibility when running as a non-root user
        am_i_root && configure_permissions_ownership "$DISCOURSE_VOLUME_DIR" -d "775" -f "664" -u "$DISCOURSE_DAEMON_USER" -g "root"

        info "Trying to connect to the database server"
        discourse_wait_for_postgresql_connection "${postgresql_remote_execute_args[@]}"

        # The below steps are used to install Discourse, based on the below installation template:
        # https://github.com/discourse/discourse_docker/blob/master/templates/web.template.yml
        # Some things like auto-updates for plugins and themes are intentionally skipped since pre-installation is not yet supported

        # Populate database
        info "Populating database"
        discourse_rake_execute db:migrate

        if is_boolean_yes "$DISCOURSE_SKIP_BOOTSTRAP"; then
            info "An already initialized Discourse database was provided, configuration will be skipped"
        else
            info "Creating admin user"
            discourse_ensure_admin_user_exists "$DISCOURSE_USERNAME" "$DISCOURSE_PASSWORD" "$DISCOURSE_EMAIL" "${DISCOURSE_FIRST_NAME} ${DISCOURSE_LAST_NAME}"
        fi

        info "Persisting Discourse installation"
        # persist_app "$app_name" "$DISCOURSE_DATA_TO_PERSIST"
    else
        info "Restoring persisted Discourse installation"
        # restore_persisted_app "$app_name" "$DISCOURSE_DATA_TO_PERSIST"

        info "Trying to connect to the database server"
        echo "${postgresql_remote_execute_args[@]}"

        discourse_wait_for_postgresql_connection "${postgresql_remote_execute_args[@]}"

        info "Running database migrations"
        discourse_rake_execute db:migrate
    fi

    if is_boolean_yes "$DISCOURSE_PRECOMPILE_ASSETS"; then
        info "Precompiling assets, this may take some time..."
        discourse_rake_execute assets:precompile
    else
        # The precompilation of CSS assets also populates the 'stylesheet_cache' table, requiring also a DB connection
        # And since the DB is not available at build time, it is impossible to build CSS assets at build time
        # Note: The info log is intentionally misleading, to avoid confusion for users when disabling DISCOURSE_PRECOMPILE_ASSETS
        info "Populating CSS cache in database"
        # discourse_rake_execute assets:precompile:css
    fi

    # Avoid exit code of previous commands to affect the result of this function
    true
}

########################
# Create and populate the Discourse configuration for the current environment
# Globals:
#   DISCOURSE_*
# Arguments:
#   None
# Returns:
#   None
#########################
discourse_create_conf_file() {
    # Based on: https://github.com/discourse/discourse/blob/master/config/discourse_defaults.conf
    touch "$DISCOURSE_CONF_FILE"
    discourse_set_hostname "$DISCOURSE_HOST"
    # Database credentials
    discourse_conf_set "db_host" "$DISCOURSE_DATABASE_HOST"
    discourse_conf_set "db_port" "$DISCOURSE_DATABASE_PORT_NUMBER"
    discourse_conf_set "db_username" "$DISCOURSE_DATABASE_USER"
    discourse_conf_set "db_password" "$DISCOURSE_DATABASE_PASSWORD"
    discourse_conf_set "db_name" "$DISCOURSE_DATABASE_NAME"
    # Redis credentials
    discourse_conf_set "redis_host" "$DISCOURSE_REDIS_HOST"
    discourse_conf_set "redis_port" "$DISCOURSE_REDIS_PORT_NUMBER"
    discourse_conf_set "redis_password" "$DISCOURSE_REDIS_PASSWORD"
    # SMTP credentials
    if ! is_empty_value "$DISCOURSE_SMTP_HOST"; then
        info "Enabling SMTP"
        discourse_conf_set "smtp_address" "$DISCOURSE_SMTP_HOST"
        discourse_conf_set "smtp_port" "$DISCOURSE_SMTP_PORT_NUMBER"
        discourse_conf_set "smtp_user_name" "$DISCOURSE_SMTP_USER"
        discourse_conf_set "smtp_password" "$DISCOURSE_SMTP_PASSWORD"
        discourse_conf_set "smtp_enable_start_tls" "$([[ "$DISCOURSE_SMTP_PROTOCOL" = "tls" ]] && echo "true" || echo "false")"
        discourse_conf_set "smtp_authentication" "$DISCOURSE_SMTP_AUTH"
    fi
    # Extra configuration
    ! is_empty_value "$DISCOURSE_EXTRA_CONF_CONTENT" && echo "$DISCOURSE_EXTRA_CONF_CONTENT" >> "$DISCOURSE_CONF_FILE"
}