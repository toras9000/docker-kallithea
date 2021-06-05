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

# fix permission
KALLITHEA_FIX_PERMISSION=$(echo ${KALLITHEA_FIX_PERMISSION:-TRUE} | tr [:lower:] [:upper:])
if [ "$KALLITHEA_FIX_PERMISSION" = "TRUE"  ]; then
    echo "Fix permissions ..."
    chown -R kallithea:kallithea /kallithea/config
    find /kallithea/config -type d -exec chmod u+wrx {} \;
    find /kallithea/config -type f -exec chmod u+wr  {} \;
    chown kallithea:kallithea /kallithea/repos
    chmod u+wrx /kallithea/repos
    touch /home/kallithea/.ssh/authorized_keys
    chown -R kallithea:kallithea /home/kallithea/.ssh
    chmod 700 /home/kallithea/.ssh
    chmod 600 /home/kallithea/.ssh/authorized_keys
    
    KALLITHEA_FIX_REPOS_PERMISSION=$(echo ${KALLITHEA_FIX_REPOS_PERMISSION:-FALSE} | tr [:lower:] [:upper:])
    if [ "$KALLITHEA_FIX_REPOS_PERMISSION" = "TRUE"  ]; then
        echo "Fix repos permissions ..."
        chown -R kallithea:kallithea /kallithea/repos
        find /kallithea/repos  -type d -exec chmod u+wrx {} \;
        find /kallithea/repos  -type f -exec chmod u+wr  {} \;
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
        until su-exec kallithea:kallithea $PYTHON_BIN -c "import sqlalchemy;db=sqlalchemy.engine.create_engine('$KALLITHEA_DB_TEST_URL');db.connect()" 2> /dev/null;
        do
            echo "Retry the database connection after 5 seconds."
            sleep 5s
        done
    fi

    # Check if the table exists in the database.
    # Prevents database corruption by starting without the configuration file.
    # Not a complete test. This is a simple preventive measure.
    echo "Check if the database schema already exists ..."
    KALLITHEA_DB_TEST_RESULT=$(su-exec kallithea:kallithea $PYTHON_BIN -c "import sqlalchemy;db=sqlalchemy.engine.create_engine('$KALLITHEA_DB_TEST_URL');print(db.has_table('users'));db.dispose()" 2> /dev/null)
    if [ "$KALLITHEA_DB_TEST_RESULT" = "True" ]; then
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

    # Initialize the database.
    echo "Initialize the database ..."
    su-exec kallithea:kallithea kallithea-cli db-create -c "$KALLITHEA_INI_TMP" \
        --user ${KALLITHEA_ADMIN_USER:-"admin"} \
        --password ${KALLITHEA_ADMIN_PASS:-"admin"} \
        --email ${KALLITHEA_ADMIN_MAIL:-"admin@example.com"} \
        --repos /kallithea/repos \
        --force-yes
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

echo "Start SSH server ..."
/etc/init.d/ssh start

echo "Start kallithea ..."
su-exec kallithea:kallithea gearbox serve -c "$KALLITHEA_INI"
