#!/usr/bin/env bash

# # # # # # # # # # # # # # # # # # # #
# execute lazu command
# TODO:
# - DRY
if [ "$1" == "lazu" ]; then
    PC_LAZU_UID=$(cat $WDIR/$PC_CONF_FILE | jq -r ".lazu.user_id")

    if [[ -z "$PC_LAZU_UID" ]] || [[ "$PC_LAZU_UID" == "null" ]]; then
        printf "${RED}No user id set.${NORMAL}\n"
        exit 1
    fi

    PC_LAZU_PID=$(cat $WDIR/$PC_CONF_FILE | jq -r ".lazu.project_id")

    if [[ -z "$PC_LAZU_PID" ]] || [[ "$PC_LAZU_PID" == "null" ]]; then
        printf "${RED}No project id set.${NORMAL}\n"
        exit 1
    fi

    PC_LAZU_SECRET=$(cat $WDIR/$PC_CONF_FILE | jq -r ".lazu.secret")

    if [[ -z "$PC_LAZU_SECRET" ]] || [[ "$PC_LAZU_SECRET" == "null" ]]; then
        printf "${RED}No secret set.${NORMAL}\n"
        exit 1
    fi

    PC_LAZU_URL='http://localhost/api/v1/projects/_PID_/activities'
    PC_LAZU_URL=${PC_LAZU_URL/_PID_/$PC_LAZU_PID}
    PC_LAZU_ERROR=0
    PC_LAZU_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    PC_IPS=$(local_ips)

    curl -s --request POST \
        --url $PC_LAZU_URL \
        --header 'content-type: multipart/form-data' \
        --form user_id=$PC_LAZU_UID \
        --form secret=$PC_LAZU_SECRET \
        --form event=WorkStarted \
        --form branch=$PC_LAZU_BRANCH \
        --form ips=$PC_IPS \
        > /dev/null

    printf "${GREEN}Sent WorkStarted event.${NORMAL}\n"

    while [ $PC_LAZU_ERROR == 0 ]; do
        sleep 5

        PC_NEW_IPS=$(local_ips)

        [ "$PC_IPS" != "$PC_NEW_IPS" ] || continue

        PC_LAZU_NEW_BRANCH=$(git rev-parse --abbrev-ref HEAD)

        [ "$PC_LAZU_BRANCH" != "$PC_LAZU_NEW_BRANCH" ] || continue
    
        PC_IPS=$PC_NEW_IPS
        PC_LAZU_BRANCH=$PC_LAZU_NEW_BRANCH

        curl --request POST \
            --url $PC_LAZU_URL \
            --header 'content-type: multipart/form-data' \
            --form user_id=$PC_LAZU_UID \
            --form secret=$PC_LAZU_SECRET \
            --form event=WorkStarted \
            --form branch=$PC_LAZU_BRANCH \
            --form ips=$PC_IPS \
            > /dev/null

        printf "${GREEN}Sent WorkStarted event.${NORMAL}\n"

    done

    exit

fi
