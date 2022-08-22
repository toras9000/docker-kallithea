#!/bin/bash

# Generate a locale
LANG=${KALLITHEA_LOCALE:-"en_US.UTF-8"}
locale-gen --lang ${LANG}
update-locale LANG=${LANG}
export LANG

# Copy host keys
if [ -d /kallithea/host_keys ]; then
    echo "Copy host keys ..."
    cp -f /kallithea/host_keys/ssh_host_* /etc/ssh/ 2> /dev/null
    chown root:root /etc/ssh/ssh_host_*
    chmod 600       /etc/ssh/ssh_host_*
    chmod +r        /etc/ssh/ssh_host_*.pub
fi

# clear cache files
if [ "$(echo ${KALLITHEA_CLEAR_SESSION_CACHE:-FALSE} | tr [:lower:] [:upper:])" = "TRUE"  ]; then
    if [ -d "/kallithea/config/data/sessions" ]; then
        echo "Clear session cache ..."
        rm -rf /kallithea/config/data/sessions
    fi
fi

# fix permission
if [ "$(echo ${KALLITHEA_FIX_PERMISSION:-TRUE} | tr [:lower:] [:upper:])" = "TRUE"  ]; then
    echo "Fix permissions ..."
    find /kallithea/config -maxdepth 1 -type d -exec chmod u+wrx {} \; -exec chown kallithea:kallithea {} \;
    find /kallithea/config -maxdepth 1 -type f -exec chmod u+wr  {} \; -exec chown kallithea:kallithea {} \;
    chown kallithea:kallithea /kallithea/repos
    chmod u+wrx /kallithea/repos
    touch /home/kallithea/.ssh/authorized_keys
    chown -R kallithea:kallithea /home/kallithea/.ssh
    chmod 700 /home/kallithea/.ssh
    chmod 600 /home/kallithea/.ssh/authorized_keys

    if [ "$(echo ${KALLITHEA_FIX_SUB_PERMISSION:-FALSE} | tr [:lower:] [:upper:])" = "TRUE"  ]; then
        echo "Fix sub permissions ..."
        find /kallithea/config  -type d -exec chmod u+wrx {} \; -exec chown kallithea:kallithea {} \;
        find /kallithea/config  -type f -exec chmod u+wr  {} \; -exec chown kallithea:kallithea {} \;
    fi

    if [ "$(echo ${KALLITHEA_FIX_REPOS_PERMISSION:-FALSE} | tr [:lower:] [:upper:])" = "TRUE"  ]; then
        echo "Fix repos permissions ..."
        find /kallithea/repos  -type d -exec chmod u+wrx {} \; -exec chown kallithea:kallithea {} \;
        find /kallithea/repos  -type f -exec chmod u+wr  {} \; -exec chown kallithea:kallithea {} \;
    fi
fi

# Path to the configuration file
KALLITHEA_INI=/kallithea/config/kallithea.ini

# kallithea installation directory
KALLITEHA_INSTALL_DIR=/home/kallithea/.local/lib/python2.7/site-packages/kallithea

# python bin
PYTHON_BIN=python

# Get the installed version of kallithea.
INSTALL_KALLITHEA_VER=$(su-exec kallithea:kallithea $PYTHON_BIN -c "import kallithea;print(kallithea.__version__)")

# Call python script
function call_python()
{
    su-exec kallithea:kallithea $PYTHON_BIN "$@"
}

# Patches for bug. (ver. 0.5.0 - 0.5.2)
# Extra whitespace causes problems, depending on the version of the module.
PATCH_FILE=$KALLITEHA_INSTALL_DIR/model/db.py
sed -i "s/relationship('UserUserGroupToPerm '/relationship('UserUserGroupToPerm'/1" "$PATCH_FILE"
sed -i "s/relationship('UserGroupUserGroupToPerm '/relationship('UserGroupUserGroupToPerm'/1" "$PATCH_FILE"

# Create and setup ini file
function create_setup_ini_file()
{
    # argument: init file path
    INI_FILE_PATH=$1

    # Fixed settings
    CONFIG_OPTIONS=()
    CONFIG_OPTIONS+=("host=0.0.0.0")
    CONFIG_OPTIONS+=("port=5000")
    CONFIG_OPTIONS+=("ssh_enabled=true")
    CONFIG_OPTIONS+=("session.cookie_expires=2592000")

    # Setting: Database URL.
    if [ -n "$KALLITHEA_EXTERNAL_DB" ]; then
        echo "Setting database connection string"
        CONFIG_OPTIONS+=("sqlalchemy.url=$KALLITHEA_EXTERNAL_DB")
    fi

    # Setting: SSH locale
    if [ -n "$KALLITHEA_SSH_LOCALE" ]; then
        echo "Setting ssh locale to ${KALLITHEA_SSH_LOCALE}"
        CONFIG_OPTIONS+=("ssh_locale=$KALLITHEA_SSH_LOCALE")
    fi

    # Generate a configuration file.
    su-exec kallithea:kallithea kallithea-cli config-create "$INI_FILE_PATH" "${CONFIG_OPTIONS[@]}"
}

# Database migration mode
if [ "$KALLITHEA_DB_MIGRATION" = "TRUE" ]; then
    # Filename variable
    KALLITHEA_INI_BAK=${KALLITHEA_INI%/*}/kallithea.bak.ini
    KALLITHEA_INI_MG_NEW=${KALLITHEA_INI%/*}/kallithea.migrate.new.ini
    KALLITHEA_INI_MG_READY=${KALLITHEA_INI%/*}/kallithea.migrate.ready.ini
    KALLITHEA_MG_FINISH=${KALLITHEA_INI%/*}/migration.finished
    KALLITHEA_MG_ERROR=${KALLITHEA_INI%/*}/migration.error

    # Is the migration status strange?
    if [ -f "$KALLITHEA_INI_MG_NEW" ];   then echo "Processing cannot continue because '${KALLITHEA_INI_MG_NEW##*/}' exists.";   exit 1; fi
    if [ -f "$KALLITHEA_INI_MG_READY" ]; then echo "Processing cannot continue because '${KALLITHEA_INI_MG_READY##*/}' exists."; exit 1; fi
    if [ -f "$KALLITHEA_MG_FINISH" ];    then echo "Processing cannot continue because '${KALLITHEA_MG_FINISH##*/}' exists.";    exit 1; fi
    if [ -f "$KALLITHEA_MG_ERROR" ];     then echo "Processing cannot continue because '${KALLITHEA_MG_ERROR##*/}' exists.";     exit 1; fi

    # Patches for bug. (ver. 0.5.1)
    # A migration execution error will occur.
    if [ "$INSTALL_KALLITHEA_VER" = "0.5.1" ]; then
        PATCH_FILE=$KALLITEHA_INSTALL_DIR/alembic/env.py
        sed -ri "s/^\\s*(import logging)\$/import os\n\\1/1" "$PATCH_FILE"
    fi

    # Generates a new version of the configuration file.
    echo "Creating new configuration file '${KALLITHEA_INI_MG_NEW##*/}' ..."
    create_setup_ini_file "$KALLITHEA_INI_MG_NEW"

    # Wait for the configuration file to be edited.
    echo "Edit '${KALLITHEA_INI_MG_NEW##*/}' as needed and rename it to '${KALLITHEA_INI_MG_READY##*/}'."
    echo "Waiting for file '${KALLITHEA_INI_MG_READY##*/}' ..."
    while [ ! -f "$KALLITHEA_INI_MG_READY" ]
    do
        sleep 1s
    done

    # Database migration is performed.
    echo "Migrate database ..."
    su-exec kallithea:kallithea alembic -c "$KALLITHEA_INI_MG_READY" upgrade head || { echo "Failed to migration."; touch "$KALLITHEA_MG_ERROR"; exit 1; }

    # Backup old ini
    if [ -f "$KALLITHEA_INI" ]; then
        mv "$KALLITHEA_INI" "$KALLITHEA_INI_BAK" || { echo "Failed to backup old ini."; touch "$KALLITHEA_MG_ERROR"; exit 1; }
    fi

    # Replace migrated ini
    mv "$KALLITHEA_INI_MG_READY" "$KALLITHEA_INI" || { echo "Failed to replace ini."; touch "$KALLITHEA_MG_ERROR"; exit 1; }

    # Create migration finish flag.
    touch "$KALLITHEA_MG_FINISH"

    # Waiting for the container to finish. (Prevents automatic restart from escaping the script.)
    echo "Finish migration. Please stop container."
    while :
    do
        sleep 1s
    done
fi

# Initialize if the configuration file does not exist.
if [ ! -e "$KALLITHEA_INI" ]; then
    # Get the connection URL to check the database status.
    KALLITHEA_DB_TEST_URL=$KALLITHEA_EXTERNAL_DB
    if [ -z "$KALLITHEA_DB_TEST_URL" ]; then
        KALLITHEA_DB_TEST_URL="sqlite:////kallithea/config/kallithea.db?timeout=60"
    else
        echo "Wait for the database to be able to connect ..."
        call_python /kallithea/helper/wait-db-connect.py "$KALLITHEA_DB_TEST_URL"
    fi

    # Check if the table exists in the database.
    # Prevents database corruption by starting without the configuration file.
    # Not a complete test. This is a simple preventive measure.
    echo "Check if the database schema already exists ..."
    if call_python /kallithea/helper/exists-db-table.py "$KALLITHEA_DB_TEST_URL" 'users'; then
        echo "Already exists tables in database."
        echo "Check the status of the database and configuration files."
        echo "This container is blocking execution. Please stop container."
        while :
        do
            sleep 1s
        done
    fi

    # Generate a configuration file.
    echo "Generating a configuration file ..."
    KALLITHEA_INI_TMP=${KALLITHEA_INI}.createtmp
    create_setup_ini_file "$KALLITHEA_INI_TMP"

    # Additional options
    KALLITHEA_ADD_OPTS=
    if [ "$(echo ${KALLITHEA_DB_PRE_CREATED} | tr [:lower:] [:upper:])" = "TRUE" ]; then KALLITHEA_ADD_OPTS=$KALLITHEA_ADD_OPTS --reuse; fi

    # Initialize the database.
    echo "Initialize the database ..."
    su-exec kallithea:kallithea kallithea-cli db-create -c "$KALLITHEA_INI_TMP" \
        --user ${KALLITHEA_ADMIN_USER:-"admin"} \
        --password ${KALLITHEA_ADMIN_PASS:-"admin"} \
        --email ${KALLITHEA_ADMIN_MAIL:-"admin@example.com"} \
        --repos /kallithea/repos \
        --force-yes \
        $KALLITHEA_ADD_OPTS
    if [ $? -ne 0 ]; then echo "Failed to initialize database."; exit 1; fi 
    
    # If successful, make it the desired file
    mv "$KALLITHEA_INI_TMP" "$KALLITHEA_INI" || { echo "Failed to create ini."; exit 1; }
fi

# A patch for convenience.
if [ -n "$KALLITHEA_REPOSORT_IDX" ]; then
    KRS_IDX=$KALLITHEA_REPOSORT_IDX
    KRS_ODR=${KALLITHEA_REPOSORT_ORDER:-"asc"}
    PATCH_FILE=$KALLITEHA_INSTALL_DIR/templates/index_base.html
    sed -ri "s/^                order: \\[\\[1, \"asc\"\\]\\],\$/                order: [[${KRS_IDX}, \"${KRS_ODR}\"]],/1" "$PATCH_FILE"
fi

# Database modification
KALLITHEA_DB_URL=$(grep -m 1 -P -o  "^\\s*sqlalchemy\\.url\\s*=\\s*\\K[^\r\n#]+" /kallithea/config/kallithea.ini)
KALLITHEA_DB_URL=${KALLITHEA_DB_URL/\%\(here\)s/\/kallithea\/config}
if [ -n "$KALLITHEA_DB_URL" ]; then
    echo 'Check DB update variables'

    # Wait database accesible
    echo "Wait for the database to be able to connect ..."
    call_python /kallithea/helper/wait-db-connect.py "$KALLITHEA_DB_URL"

    # call helper script for kallithea settings in db
    function upsert_db_setting() { call_python /kallithea/helper/upsert-db-settings.py "$KALLITHEA_DB_URL" "$@"; }
    function get_db_setting()    { call_python /kallithea/helper/get-db-settings.py    "$KALLITHEA_DB_URL" "$@"; }

    # Set default repo type to git
    if [ "$(echo ${KALLITHEA_DEFAULT_REPO_GIT})" = "TRUE" ]; then
        echo '... Update default repository type to git'
        upsert_db_setting 'default_repo_type' 'git' 'unicode'
    fi
    # Force enable extra field
    if [ "$KALLITHEA_EXTRA_FIELD" = "TRUE" ]; then
        echo '... Enable Extended Fields'
        upsert_db_setting 'repository_fields' 'True' 'bool'
    fi
    # Set SSH URI template 
    if [ -n "$KALLITHEA_EXTERNAL_SSH_PORT" ]; then
        echo '... Rewrite SSH URL template'
        KALLITHEA_SSH_URI_TEMPL=ssh://{system_user}@{hostname}:${KALLITHEA_EXTERNAL_SSH_PORT}/{repo}
        upsert_db_setting 'clone_ssh_tmpl' "$KALLITHEA_SSH_URI_TEMPL" 'unicode'
    fi
fi

echo "Start SSH server ..."
/etc/init.d/ssh start

# Periodic indexing
if [ "$KALLITHEA_CRON_INDEXING" = "TRUE" ]; then
    # Reindex daily at 2:00 AM 
    echo "Schedule periodic indexing ..."
    mkdir -p /var/spool/cron/crontabs
    echo "0 2 * * * kallithea-cli index-create -c \"$KALLITHEA_INI\"" > /var/spool/cron/crontabs/kallithea
    busybox crond -L /dev/null
fi

echo "Start kallithea ..."
su-exec kallithea:kallithea gearbox serve -c "$KALLITHEA_INI"
