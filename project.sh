#!/usr/bin/env bash

PC_DIR="$HOME/.pro-cli"

. $PC_DIR/vars.sh

reset_output

if ! jq --version &> /dev/null; then
    printf "${RED}jq not installed, but is requirement.${NORMAL}\n"
    exit
fi

# # # # # # # # # # # # # # # # # # # #
# show new version info if available
if [ "$PC_VERSION" != "$PC_VERSION_NEW" ] && [ ! -f $ASKED_FILE ]; then
    touch $ASKED_FILE
    printf "${YELLOW}New version available: ${BOLD}${PC_VERSION_NEW}${NORMAL}\n"
    read -p "Would you like to update pro-cli now? [y|n]: " ANSWER

    if [ "$ANSWER" != "n" ]; then
        printf "\n"
        . $PC_DIR/update.sh
        exit
    fi
fi


# # # # # # # # # # # # # # # # # # # #
# show help immediately
if [ $# -eq 0 ] || [ "$1" == "help" ]; then
    help
    exit
fi

# # # # # # # # # # # # # # # # # # # #
# project init [directory] [--type=TYPE]
if [ "$1" == "init" ]; then
    if ( needs_help $@ ); then
        printf "${YELLOW}usage:${NORMAL} project init [directory] [options]\n\n"
        printf "OPTIONS:\n"
        printf "    ${BLUE}--type[=php]${NORMAL}${PC_HELP_SPACE:12}Specifiy the type of the project (php, laravel, nodejs, django).${NORMAL}\n"
        exit
    fi

    shift
    printf "Initializing project files ... "
    init_project $@
    printf "${GREEN}done!${NORMAL}\n"
    exit

# # # # # # # # # # # # # # # # # # # #
# sync directory structure with pro-cli
elif [ "$1" == "sync" ]; then
    sync_structure
    exit

# # # # # # # # # # # # # # # # # # # #
# get and set config settings
elif [ "$1" == "config" ]; then
    shift

    PC_SELECTION=".${1}"

    if [ ! -z "$2" ]; then
        PC_VALUE=$(echo "${2}" | sed -e 's/"/\\"/g' -e 's/^\\"/"/1' -e 's/\\"$/"/')

        if $(echo $2 | jq . > /dev/null 2>&1); then
            PC_JSON=$(cat $WDIR/$PC_CONF_FILE | jq "$PC_SELECTION = ${2}" | jq -M .)
        else
            PC_JSON=$(cat $WDIR/$PC_CONF_FILE | jq "$PC_SELECTION = \"${2}\"" | jq -M .)
        fi

        # prevent braking the config file
        if [ -z "$PC_JSON" ]; then
            printf "${RED}Invalid value!${NORMAL}\n"
            exit
        fi

        printf '%s' "$PC_JSON" > $WDIR/$PC_CONF_FILE
    else
        cat $WDIR/$PC_CONF_FILE | jq "$PC_SELECTION"
    fi

    exit

# # # # # # # # # # # # # # # # # # # #
# project self-update
elif [ "$1" == "self-update" ]; then
    . $PC_DIR/update.sh
    exit


# # # # # # # # # # # # # # # # # # # #
# project list
elif [ "$1" == "list" ]; then
    cat $PC_BASE_CONF | jq '.projects'
    exit


# # # # # # # # # # # # # # # # # # # #
# project open PROJECT_NAME
elif [ "$1" == "open" ]; then
    if ( needs_help $@ ); then
        printf "${YELLOW}usage:${NORMAL} project open [project]\n\n"
        exit
    fi

    PC_OPEN=$(cat $PC_BASE_CONF | jq -r --arg VAL "$2" '.projects[$VAL]')

    if [ -z "$PC_OPEN" ]; then
        printf "${YELLOW}Project not found ¯\_(ツ)_/¯${NORMAL}\n"
    else
        open_project "$PC_OPEN" "$2"
    fi

    exit


# # # # # # # # # # # # # # # # # # # #
# project expose
elif [ "$1" == "expose" ]; then
    if ( needs_help $@ ); then
        printf "${YELLOW}usage:${NORMAL} project expose [options]\n\n"
        printf "OPTIONS:\n"
        printf "    ${BLUE}--auth='user:password'${NORMAL}${PC_HELP_SPACE:22}Secure the application with basic auth.${NORMAL}\n"
        exit
    fi

    if ! ngrok -v &> /dev/null; then
        printf "${RED}No ngrok installed.${NORMAL} Please go to https://ngrok.com/ and install the latest version.\n"
        exit
    fi

    if [[ ! -f $WDIR/.env ]]; then
        printf "${RED}.env is missing.${NORMAL} Are you inside of a project?\n"
        exit
    fi

    PC_PORT=$(cat $WDIR/.env | grep APP_PORT | sed -e 's/APP_PORT=\(.*\)/\1/')

    if [[ -z "$PC_PORT" ]]; then
        printf "${YELLOW}No port specified in .env${NORMAL}\n"
        exit
    fi

    shift

    project up
    ngrok http $PC_PORT $@
    exit
fi


# # # # # # # # # # # # # # # # # # # #
# include the systems
. $PC_DIR/systems/docker-cli.sh
. $PC_DIR/systems/php-cli.sh
. $PC_DIR/systems/laravel-cli.sh
. $PC_DIR/systems/node-cli.sh
. $PC_DIR/systems/django-cli.sh
. $PC_DIR/systems/lazu-cli.sh


# # # # # # # # # # # # # # # # # # # #
# commands that are specified in the local config file
if [ ! -z "$1" ] && [ -f $WDIR/$PC_CONF_FILE ] && [[ $(cat $WDIR/$PC_CONF_FILE | jq -crM --arg cmd "$1" '.scripts[$cmd]') != "null" ]]; then
    PC_COMMAND=$(cat $WDIR/$PC_CONF_FILE | jq -crM --arg cmd "$1" 'if (.scripts[$cmd].command | type == "string") then .scripts[$cmd].command else .scripts[$cmd].command | .[] end')

    # concat multiple commands
    if [[ $PC_COMMAND == *$'\n'* ]]; then
        PC_COMMAND=$(echo "$PC_COMMAND" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ \&\& /g')
    fi

    if [ ! -z "$PC_COMMAND" ] && [ "$PC_COMMAND" != "null" ]; then
        eval $PC_COMMAND
        exit
    fi
fi


printf "${YELLOW}Command not found ¯\_(ツ)_/¯${NORMAL}\n"
