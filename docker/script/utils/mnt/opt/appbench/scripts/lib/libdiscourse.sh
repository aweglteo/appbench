#!/bin/bash
#
# Appbench Discourse library

########################
# Add or modify an entry in the Discourse configuration file
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1 - Variable name
#   $2 - Value to assign to the variable
# Returns:
#   None
#########################
discourse_conf_set() {
    local -r key="${1:?key missing}"
    local -r value="${2:-}"
    debug "Setting ${key} to '${value}' in Discourse configuration"
    # Sanitize key (sed does not support fixed string substitutions)
    local sanitized_pattern
    sanitized_pattern="^\s*(#\s*)?$(sed 's/[]\[^$.*/]/\\&/g' <<< "$key")\s*=\s*(.*)"
    local entry="${key} = ${value}"
    # Check if the configuration exists in the file
    if grep -q -E "$sanitized_pattern" "$DISCOURSE_CONF_FILE"; then
        # It exists, so replace the line
        replace_in_file "$DISCOURSE_CONF_FILE" "$sanitized_pattern" "$entry"
    else
        echo "$entry" >> "$DISCOURSE_CONF_FILE"
    fi
}



########################
# Wait until the database is accessible with the currently-known credentials
# Globals:
#   *
# Arguments:
#   $1 - database host
#   $2 - database port
#   $3 - database name
#   $4 - database username
#   $5 - database user password (optional)
# Returns:
#   true if the database connection succeeded, false otherwise
#########################
discourse_wait_for_postgresql_connection() {
    local -r db_host="${1:?missing database host}"
    local -r db_port="${2:?missing database port}"
    local -r db_name="${3:?missing database name}"
    local -r db_user="${4:?missing database user}"
    local -r db_pass="${5:-}"
    check_postgresql_connection() {
        echo "SELECT 1" | postgresql_remote_execute "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass"
    }
    if ! retry_while "check_postgresql_connection"; then
        error "Could not connect to the database"
        return 1
    fi
}

########################
# Wait until Redis is accessible
# Globals:
#   *
# Arguments:
#   $1 - Redis host
#   $2 - Redis port
# Returns:
#   true if the Redis connection succeeded, false otherwise
#########################
discourse_wait_for_redis_connection() {
    local -r redis_host="${1:?missing Redis host}"
    local -r redis_port="${2:?missing Redis port}"
    if ! retry_while "debug_execute wait-for-port --timeout 5 --host ${redis_host} ${redis_port}"; then
        error "Could not connect to Redis"
        return 1
    fi
}

########################
# Executes Bundler with the proper environment and the specified arguments and print result to stdout
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1..$n - Arguments to pass to the CLI call
# Returns:
#   None
#########################
discourse_bundle_execute_print_output() {
    # Avoid creating unnecessary cache files at initialization time
    local -a cmd=("bundle" "exec" "$@")
    # Run as application user to avoid having to change permissions/ownership afterwards
    am_i_root && cmd=("gosu" "$DISCOURSE_DAEMON_USER" "${cmd[@]}")
    info "${cmd[@]}"
    (
        export RAILS_ENV="$DISCOURSE_ENV"
        cd "$DISCOURSE_BASE_DIR" || false
        "${cmd[@]}"
    )
}

########################
# Executes Bundler with the proper environment and the specified arguments
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1..$n - Arguments to pass to the CLI call
# Returns:
#   None
#########################
discourse_bundle_execute() {
    debug_execute discourse_bundle_execute_print_output "$@"
}

########################
# Executes the 'rake' CLI with the proper Bundler environment and the specified arguments and print result to stdout
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1..$n - Arguments to pass to the CLI call
# Returns:
#   None
#########################
discourse_rake_execute_print_output() {
    discourse_bundle_execute_print_output "rake" "$@"
}

########################
# Executes the 'rake' CLI with the proper Bundler environment and the specified arguments
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1..$n - Arguments to pass to the CLI call
# Returns:
#   None
#########################
discourse_rake_execute() {
    debug_execute discourse_rake_execute_print_output "$@"
}

########################
# Executes the commands specified via stdin in the Rails console for Discourse
# Globals:
#   DISCOURSE_*
# Arguments:
#   None
# Returns:
#   None
# TODO: Fix require path
#########################
discourse_console_execute() {
    local rails_cmd
    rails_cmd="$(</dev/stdin)"
    debug "Executing script with console environment:\n${rails_cmd}"
    discourse_bundle_execute ruby -e "$(cat <<EOF
require File.expand_path("/app/workdir/discourse/config/environment", __FILE__)
${rails_cmd}
EOF
    )"
}

########################
# Create an admin user for Discourse
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1 - Admin username
#   $2 - Admin password
#   $3 - Admin e-mail
#   $4 - Admin full name
# Returns:
#   None
#########################
discourse_ensure_admin_user_exists() {
    local -r username="${1:?missing username}"
    local -r password="${2:?missing password}"
    local -r email="${3:?missing email}"
    local -r full_name="${4:?missing full_name}"
    # Based on logic from 'lib/tasks/admin.rake'
    # We also try to avoid any error in case the user already exists
    discourse_console_execute <<EOF
admin = User.find_by_email("${email}")
admin = User.new if admin.nil?
admin.username = "${username}"
admin.password = "${password}"
admin.email = "${email}"
admin.name = "${full_name}"
admin.active = true
admin.save
errors = admin.errors.full_messages
unless errors.empty?
  puts errors.join("\\n")
  exit 1
end
admin.grant_admin!
admin.activate
EOF
}

########################
# Set Discourse application hostname, for URLs generation
# Globals:
#   DISCOURSE_*
# Arguments:
#   $1 - Hostname
# Returns:
#   None
#########################
discourse_set_hostname() {
    local discourse_server_host="${1:?missing host}"
    if is_boolean_yes "$DISCOURSE_ENABLE_HTTPS"; then
        [[ "$DISCOURSE_EXTERNAL_HTTPS_PORT_NUMBER" != "443" ]] && discourse_server_host+=":${DISCOURSE_EXTERNAL_HTTPS_PORT_NUMBER}"
    else
        [[ "$DISCOURSE_EXTERNAL_HTTP_PORT_NUMBER" != "80" ]] && discourse_server_host+=":${DISCOURSE_EXTERNAL_HTTP_PORT_NUMBER}"
    fi
    discourse_conf_set "hostname" "$discourse_server_host"
}
