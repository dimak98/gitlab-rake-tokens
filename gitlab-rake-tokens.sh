#!/bin/bash

################################################################################
##                             Global variables                               ##
################################################################################

LOG_INFO_COLOR="\033[1;32m"  
LOG_DEBUG_COLOR="\033[1;36m"
LOG_ERROR_COLOR="\033[1;31m"
LOG_CMD_COLOR="\033[0m"

################################################################################
##                             Usage Functions                                ##
################################################################################

usage_expire() {
    cat <<EOF
Usage: $0 expire {analyze|extend} [OPTIONS]

Subcommands:
  analyze           Analyze tokens expiring in the next X days.
    -d, --days <days>             Number of days to look ahead (required).

  extend            Extend tokens expiring in the next X days.
    -d, --days <days>             Number of days to look ahead (required).
    -e, --extend <days>           Number of days to extend the tokens by (required).
    -u, --user <user1,user2,...>  User ID(s) to filter (optional).

Examples:
  - Analyze tokens expiring in the next 7 days:
  $0 expire analyze -d 7

  - Extend tokens expiring in the next 7 days by 30 days:
  $0 expire extend -d 7 -e 30

  - Extend tokens expiring in the next 7 days by 30 days for users with IDs 1 and 2:
  $0 expire extend -d 7 -e 30 -u 1,2
EOF
}

usage_user() {
    cat <<EOF
Usage: $0 user {analyze|extend} [OPTIONS]

Subcommands:
  analyze           Analyze tokens for specific users.
    -u, --user <user1,user2,...>     Specify user ID(s) (required).

  extend            Extend tokens for specific users.
    -u, --user <user1,user2,...>     Specify user ID(s) (required).
    -e, --extend <days>              Specify the number of days to extend the tokens by (required).
    -t, --token <token1,token2,...>  Specify token ID(s) to filter (optional).

Examples:
  - Analyze tokens for users with IDs 1 and 2:
  $0 user analyze -u 1,2

  - Extend tokens for users with IDs 1 and 2 by 30 days:
  $0 user extend -u 1,2 -e 30

  - Extend specific tokens with IDs 10 and 20 for users with IDs 1 and 2 by 30 days:
  $0 user extend -u 1,2 -e 30 -t 10,20
EOF
}

################################################################################
##                             Util Functions                                 ##
################################################################################

log() {
    local level="$1"
    local message="$2"

    local ts=$(date -u "+%Y-%m-%d %H:%M:%S")

    if [[ "$level" == "info" ]]; then
        echo -e "${LOG_INFO_COLOR}${ts}:${level^^}: ${message}${LOG_CMD_COLOR}"
    elif [[ "$level" == "debug" ]]; then
        echo -e "${LOG_DEBUG_COLOR}${ts}:${level^^}: ${message}${LOG_CMD_COLOR}"
    elif [[ "$level" == "error" ]]; then
        echo -e "${LOG_ERROR_COLOR}${ts}:${level^^}: ${message}${LOG_CMD_COLOR}"
    else
        echo -e "${LOG_CMD_COLOR}${ts}:${level^^}: ${message}${LOG_CMD_COLOR}"
    fi
}

log_rails() {
    local message="$1"
    echo -e "${LOG_INFO_COLOR}${message}${LOG_CMD_COLOR}"
}

check_last_command() {
    local exit_code=$?
    local message="$1"

    if [[ $exit_code -ne 0 ]]; then
        log "error" ":EXIT CODE ${exit_code}: ${message}"
        exit 1
    fi
}

################################################################################
##                             Expire Functions                               ##
################################################################################

analyze_tokens() {
    local days=$1

    log "info" "Analyzing tokens expiring in the next $days days..."

    message=$(sudo gitlab-rails runner "
        start_date = Date.today
        end_date = start_date + $days
        tokens = PersonalAccessToken.where('expires_at >= ? AND expires_at <= ? AND revoked = ?', start_date, end_date, false)
        puts \"Tokens expiring in the next $days days: #{tokens.count}\"
        tokens.each do |token|
            user = User.find(token.user_id)
            puts \"ID: #{token.id}, User ID: #{token.user_id}, Username: #{user.username}, Expires At: #{token.expires_at}\"
        end
    ")
    check_last_command "Failed to analyze tokens."
    log_rails "$message"
}

extend_tokens() {
    local days=$1
    local extend_days=$2
    local user_ids=$3

    user_filter=""
    if [ -n "$user_ids" ]; then
        user_filter="AND user_id IN ($user_ids)"
        log "info" "Extending tokens expiring in the next $days days by $extend_days days for user(s) $user_ids..."
    else
        log "info" "Extending tokens expiring in the next $days days by $extend_days days..."
    fi

    message=$(sudo gitlab-rails runner "
        start_date = Date.today
        end_date = start_date + $days
        tokens = PersonalAccessToken.where(\"expires_at >= ? AND expires_at <= ? AND revoked = ? $user_filter\", start_date, end_date, false)
        tokens.each do |token|
            new_expiration_date = token.expires_at + $extend_days
            token.update(expires_at: new_expiration_date)
            puts \"Token ID #{token.id} expiration date extended to #{token.expires_at}\"
        end
    ")
    check_last_command "Failed to extend tokens."
    log_rails "$message"
}

################################################################################
##                             User Functions                                 ##
################################################################################

analyze_user_tokens() {
    local user_ids=$1

    log "info" "Analyzing tokens for user(s) $user_ids..."

    message=$(sudo gitlab-rails runner "
        tokens = PersonalAccessToken.where('user_id IN (?)', [$user_ids])
        puts \"Tokens for user(s) $user_ids: #{tokens.count}\"
        tokens.each do |token|
            user = User.find(token.user_id)
            puts \"ID: #{token.id}, User ID: #{token.user_id}, Username: #{user.username}, Expires At: #{token.expires_at}\"
        end
    ")
    check_last_command "Failed to analyze user tokens."
    log_rails "$message"
}

extend_user_tokens() {
    local user_ids=$1
    local extend_days=$2
    local token_ids=$3

    token_filter=""
    if [ -n "$token_ids" ]; then
        token_filter="AND id IN ($token_ids)"
        log "info" "Extending specific token(s): $token_ids for user(s) $user_ids by $extend_days days..."
    else
        log "info" "Extending tokens for user(s) $user_ids by $extend_days days..."
    fi

    message=$(sudo gitlab-rails runner "
        tokens = PersonalAccessToken.where('user_id IN (?) $token_filter', [$user_ids])
        tokens.each do |token|
            new_expiration_date = token.expires_at + $extend_days
            token.update(expires_at: new_expiration_date)
            puts \"Token ID #{token.id} expiration date extended to #{token.expires_at}\"
        end
    ")
    check_last_command "Failed to extend user tokens."
    log_rails "$message"
}

################################################################################
##                             Main execution                                 ##
################################################################################

main_command=$1
shift

case "$main_command" in
    expire)
        ARGS=$(getopt -o d:e:u:h --long days:,extend:,user:,help -n 'gitlab-rake-tokens.sh' -- "$@")
        if [ $? != 0 ]; then
            log "error" "Failed to parse arguments." >&2
            exit 1
        fi

        eval set -- "$ARGS"

        while true; do
            case "$1" in
                -d|--days)
                    days="$2"
                    shift 2
                    ;;
                -e|--extend)
                    extend_days="$2"
                    shift 2
                    ;;
                -u|--user)
                    user_ids="$2"
                    shift 2
                    ;;
                -h|--help)
                    usage_expire
                    exit 0
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    echo "Unknown option: $1" >&2
                    usage_expire
                    exit 1
                    ;;
            esac
        done

        sub_command=$1
        shift

        case "$sub_command" in
            analyze)
                if [ -z "$days" ]; then
                    log "error" "You must specify the number of days using -d or --days."
                    exit 1
                fi
                analyze_tokens "$days"
                ;;
            extend)
                if [ -z "$days" ] || [ -z "$extend_days" ]; then
                    log "error" "You must specify the number of days using -d or --days and the number of days to extend using -e or --extend."
                    exit 1
                fi
                extend_tokens "$days" "$extend_days" "$user_ids"
                ;;
            *)
                log "error" "Unknown subcommand: $sub_command"
                usage_expire
                exit 1
                ;;
        esac
        ;;
    
    user)
        ARGS=$(getopt -o u:e:t:h --long user:,extend:,token:,help -n 'gitlab-rake-tokens.sh' -- "$@")
        if [ $? != 0 ]; then
            echo "Failed to parse arguments." >&2
            exit 1
        fi

        eval set -- "$ARGS"

        while true; do
            case "$1" in
                -u|--user)
                    user_ids="$2"
                    shift 2
                    ;;
                -e|--extend)
                    extend_days="$2"
                    shift 2
                    ;;
                -t|--token)
                    token_ids="$2"
                    shift 2
                    ;;
                -h|--help)
                    usage_user
                    exit 0
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    echo "Unknown option: $1" >&2
                    usage_user
                    exit 1
                    ;;
            esac
        done

        sub_command=$1
        shift

        case "$sub_command" in
            analyze)
                if [ -z "$user_ids" ]; then
                    log "error" "You must specify the user ID(s) using -u or --user."
                    exit 1
                fi
                analyze_user_tokens "$user_ids"
                ;;
            extend)
                if [ -z "$user_ids" ] || [ -z "$extend_days" ]; then
                    log "error" "You must specify the user ID(s) using -u or --user and the number of days to extend using -e or --extend."
                    exit 1
                fi
                extend_user_tokens "$user_ids" "$extend_days" "$token_ids"
                ;;
            *)
                log "error" "Unknown subcommand: $sub_command"
                usage_user
                exit 1
                ;;
        esac
        ;;
    
    *)
        log "error" "Unknown main command: $main_command"
        echo "Usage: $0 {expire|user} ..."
        exit 1
        ;;
esac