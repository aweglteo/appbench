#!/bin/bash
#
# Appbench Discourse library

# Load generic libraries
. /opt/appbench/scripts/lib/libfs.sh
. /opt/appbench/scripts/lib/libos.sh
. /opt/appbench/scripts/lib/libnet.sh
. /opt/appbench/scripts/lib/libfile.sh
. /opt/appbench/scripts/lib/libvalidations.sh
. /opt/appbench/scripts/lib/libpersistence.sh
. /opt/appbench/scripts/lib/libservice.sh
. /opt/appbench/scripts/lib/libdiscourse.sh

# Load database library
if [[ -f /opt/appbench/scripts/lib/libpostgresqlclient.sh ]]; then
    . /opt/appbench/scripts/lib/libpostgresqlclient.sh
elif [[ -f /opt/appbench/scripts/lib/libpostgresql.sh ]]; then
    . /opt/appbench/scripts/lib/libpostgresql.sh
fi

########################
# Ensure Discourse Sidekiq is initialized
# Globals:
#   DISCOURSE_*
# Arguments:
#   None
# Returns:
#   None
#########################
discourse_sidekiq_initialize() {
    local -a postgresql_remote_execute_args=("$DISCOURSE_DATABASE_HOST" "$DISCOURSE_DATABASE_PORT_NUMBER" "$DISCOURSE_DATABASE_NAME" "$DISCOURSE_DATABASE_USER" "$DISCOURSE_DATABASE_PASSWORD")

    # This function will create required Sidekiq configuration, and wait for external services to be ready
    # There is no additional configuration needed since Sidekiq is only a daemon that runs on top of Discourse code

    if ! is_dir_empty "${DISCOURSE_BASE_DIR}/mounted-conf"; then
        info "Detected mounted configuration files, copying to Discourse config directory"
        cp -r "${DISCOURSE_BASE_DIR}/mounted-conf/"* "$DISCOURSE_CONF_DIR"
    fi

    if is_file_writable "$DISCOURSE_CONF_FILE"; then
        if is_boolean_yes "$DISCOURSE_ENABLE_CONF_PERSISTENCE"; then
            DISCOURSE_DATA_TO_PERSIST+=" ${DISCOURSE_CONF_FILE}"
            # Avoid restarts causing config file recreation due to symlink still being present
            rm -f "$DISCOURSE_CONF_FILE"
        fi
        info "Creating Discourse configuration file"
        discourse_create_conf_file
    fi

    # Check if Discourse has already been initialized and persisted in a previous run
    local -r app_name="discourse"
    if ! is_app_initialized "$app_name"; then
        # Ensure Discourse persisted directories exist (i.e. when a volume has been mounted to /bitnami)
        info "Ensuring Sidekiq directories exist"
        ensure_dir_exists "$DISCOURSE_VOLUME_DIR"
        # Use daemon:root ownership for compatibility when running as a non-root user
        am_i_root && configure_permissions_ownership "$DISCOURSE_VOLUME_DIR" -d "775" -f "664" -u "$DISCOURSE_DAEMON_USER" -g "root"

        info "Trying to connect to the database server"
        discourse_wait_for_postgresql_connection "${postgresql_remote_execute_args[@]}"
        info "Trying to connect to the Redis server"
        discourse_wait_for_redis_connection "$DISCOURSE_REDIS_HOST" "$DISCOURSE_REDIS_PORT_NUMBER"

        info "Waiting for the Discourse database to be populated"
        discourse_sidekiq_wait_for_migrations

        info "Persisting Sidekiq installation"
        persist_app "$app_name" "$DISCOURSE_DATA_TO_PERSIST"
    else
        info "Restoring persisted Discourse installation"
        restore_persisted_app "$app_name" "$DISCOURSE_DATA_TO_PERSIST"

        info "Trying to connect to the database server"
        discourse_wait_for_postgresql_connection "${postgresql_remote_execute_args[@]}"
        info "Trying to connect to the Redis server"
        discourse_wait_for_redis_connection "$DISCOURSE_REDIS_HOST" "$DISCOURSE_REDIS_PORT_NUMBER"
    fi

    # Avoid exit code of previous commands to affect the result of this function
    true
}

########################
# Wait until all Discourse migrations are executed
# Arguments:
#   None
# Returns:
#   Boolean
#########################
discourse_sidekiq_wait_for_migrations() {
    # Wait for the database to be populated for up to 5 minutes
    local -r retries="60"
    local -r sleep_time="5"
    check_migrations_done() {
        local migrate_status
        migrate_status="$(discourse_rake_execute_print_output db:migrate:status 2>&1)"
        # Check that all migrations have been executed
        [[ "$migrate_status" = *" up "* && ! "$migrate_status" = *" down "* ]]
    }
    if ! retry_while "check_migrations_done" "$retries" "$sleep_time"; then
        error "Timeout waiting for the Discourse database to be populated"
        return 1
    fi
}

########################
# Check if sidekiq daemons are running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
discourse_is_sidekiq_running() {
    # sidekiq does not create any PID file
    # We regenerate the PID file for each time we query it to avoid getting outdated
    pgrep -f "^sidekiq" > "$DISCOURSE_SIDEKIQ_PID_FILE"

    pid="$(get_pid_from_file "$DISCOURSE_SIDEKIQ_PID_FILE")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if sidekiq daemons are not running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
discourse_is_sidekiq_not_running() {
    ! discourse_is_sidekiq_running
}

########################
# Stop sidekiq daemons
# Arguments:
#   None
# Returns:
#   None
#########################
discourse_sidekiq_stop() {
    ! discourse_is_sidekiq_running && return
    stop_service_using_pid "$DISCOURSE_SIDEKIQ_PID_FILE"
}
