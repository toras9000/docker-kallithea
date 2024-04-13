# Kallithea (with SSH) Docker Image

This is a docker image of the source code management system [kallithea](https://kallithea-scm.org/)\.  
This image enables the SSH repository access function implemented in kallithea version 0.5 and later.  

## Tags

- 0.7.0
    - Version 0.7.0 of the pip package.
- 0.7.0-patched3
    - Version overwritten with [changesets from the official source](https://kallithea-scm.org/repos/kallithea/changelog/fe050a93936b31b8b6caed82e3745a2d1c1b3068/).
- 0.7.0-private1
    - [Private patched](https://github.com/toras9000/kallithea-webhook-sample/tree/main/docker/assets/patches) version.

## Data location

The storage location of data in the container.  

- `/kallithea/config`  
Stores the configuration file(`kallithea.ini`).  
If the configuration file exists, it will be started as is, otherwise it will be considered the first start, and the configuration file will be created and the database will be initialized.  

- `/kallithea/repos`  
Stores the repository.  
The repository created by Kallithea is saved under this.  

- `/home/kallithea/.ssh`  
Stores the SSH public key registration file.  
If there is an authorized_keys file, it will be used as it is, otherwise it will be created.  

- `/kallithea/host_keys`  
Stores the SSH host key to bring into the container.  
The `ssh_host_*` files placed in this location will be copied to `/etc/ssh` inside the container.  

When changing the version, pay attention to the handling of persistent data.  
See [Upgrading Kallithea](https://kallithea.readthedocs.io/en/latest/upgrade.html) for the steps required to change the version.  

## Enviroment variables

If kallithea.ini does not exist in the container, it is considered the first time and the initialization process is executed.  
The following are variables used at initialization.  

- `KALLITHEA_ADMIN_USER`  
Administrator account username (default: `admin`)  

- `KALLITHEA_ADMIN_PASS`  
Administrator account password (default: `admin`)  

- `KALLITHEA_ADMIN_MAIL`  
Administrator account e-mail (default: `admin@example.com`)  

- `KALLITHEA_EXTERNAL_DB`  
SQLAlchemy connection string when using an external database.See [SQLAlchemy documentation](https://docs.sqlalchemy.org/en/12/core/engines.html#database-urls) for examples)  
This image supports PostgreSQL (by psycopg2) and MySQL (by mysqlclient).  
(empty by default, SQLite is used.)  

- `KALLITHEA_REMOTE_ADDR_VAR`  
WSGI environment variable to get the IP address of the client. (default: `REMOTE_ADDR`)  

- `KALLITHEA_URL_SCHEME_VAR`  
WSGI environment variable to get the protocol (http or https) of the client connection (default wsgi.url_scheme)  

- `KALLITHEA_DB_PRE_CREATED`  
If set to TRUE, use an existing database. (FALSE by default)  
This can be used when initialization is performed by a DB user who does not have DB creation privileges.  

The following are the variables that are used every time it starts.  

- `KALLITHEA_LOCALE`  
Specify the locale in the container.  ("en_US.UTF-8" by default)  

- `KALLITHEA_REPOSORT_IDX`  
Default sort column number for repository list.  
A rough patch to the display template. (empty by default, no patch.)  

- `KALLITHEA_REPOSORT_ORDER`  
Sort direction when default sort column is specified.  
A rough patch to the display template. ("asc" by default)  

- `KALLITHEA_CLEAR_SESSION_CACHE`  
If set to TRUE, session cache files are deleted at startup.  (FALSE by default)  

- `KALLITHEA_FIX_PERMISSION`  
If set to TRUE, the configuration file permissions will be modified.  (TRUE by default)  
The following sub-settings are also evaluated when this setting is enabled.  
`KALLITHEA_FIX_SUB_PERMISSION`(FALSE by default): Change cache and other sub-data permissions.  
`KALLITHEA_FIX_REPOS_PERMISSION`(FALSE by default): Change permissions on repository files.  

- `KALLITHEA_CRON_INDEXING`  
When set to TRUE, the search index is updated periodically. (FALSE by default)  
Do it every day at 2:00 AM in container time. 

The following are variables that are used at each startup but need not be used every time. 

- `KALLITHEA_DEFAULT_REPO_GIT`  
If set to TRUE, set the default repository type to git. (empty by default, not modify.)  
This setting is applied to the database.  
This is a setting that can be updated in the Web UI.  

- `KALLITHEA_EXTRA_FIELD`  
If set to FORCE_ENABLE, make changes to enable extended field functionality. (empty by default, not modify.)  
This setting is applied to the database.  
This is a setting that can be updated in the Web UI.  

- `KALLITHEA_EXTERNAL_SSH_PORT`  
If a port number to be published externally is specified, update the SSH URL template to include that number. (empty by default, not modify.)  
This setting is applied to the database.  
This is a setting that can be updated in the Web UI.  

- `KALLITHEA_LDAP_ENABLE`  
If set to FORCE_ENABLE, change to enable LDAP authentication. (empty by default, not modify.)  
This setting is applied to the database.  
This is a setting that can be updated in the Web UI.  
The UI and the following corresponding environment variables are set in the DB.  
`KALLITHEA_LDAP_HOST`, `KALLITHEA_LDAP_PORT`, `KALLITHEA_LDAP_DN_USER`, `KALLITHEA_LDAP_DN_PASS`, `KALLITHEA_LDAP_TLS_KIND`, `KALLITHEA_LDAP_TLS_CERT`, `KALLITHEA_LDAP_CERT_DIR`, `KALLITHEA_LDAP_BASE_DN`, `KALLITHEA_LDAP_FILTER`, `KALLITHEA_LDAP_SCOPE`, `KALLITHEA_LDAP_ATTR_LOGIN`, `KALLITHEA_LDAP_ATTR_FIRSTNAME`, `KALLITHEA_LDAP_ATTR_LASTNAME`, `KALLITHEA_LDAP_ATTR_EMAIL`

- `KALLITHEA_EXTENSIONS_TEMPLATE`  
If set to REPLACE, it will overwrite extensions.py with template file. (empty by default)  
If this is not set, place only if extensions.py does not exist.  

- `KALLITHEA_WEBHOOK_LINK_BASE`  
Specifies the base address for including repository links in webhook messages. (empty by default)  

- `KALLITHEA_WEBHOOK_ALLOW_PATTERNS`  
If set to REPLACE, it will overwrite extensions.py with template file. (empty by default)  
If this is not set, place only if extensions.py does not exist.  

- `KALLITHEA_DB_MIGRATION`  
If set to TRUE (capitals exactly), it will run in migration assistance mode. (empty by default)  
The support mode does not execute normal services, but functions as a migration execution support tool when upgrading.  
This is used only once when upgrading.  
For more information, see the 'Migration assistance mode' section below.

### Usage examples

The following is an example of a simple docker-compose.yml for Sqlite.  

```
services:
  app:
    image: toras9000/kallithea-mp:0.7.0-private1
    restart: unless-stopped
    ports:
      - "8010:5000"
      - "2222:22"
    volumes:
      - ../volumes/kallithea/app/config:/kallithea/config
      - ../volumes/kallithea/app/repos:/kallithea/repos
      - ../volumes/kallithea/app/host_keys:/kallithea/host_keys
      - ../volumes/kallithea/app/ssh:/home/kallithea/.ssh
    environment:
      - KALLITHEA_ADMIN_USER=admin
      - KALLITHEA_ADMIN_PASS=admin123
      - KALLITHEA_ADMIN_MAIL=admin@example.com
      - KALLITHEA_LOCALE=ja_JP.UTF-8
      - KALLITHEA_DEFAULT_REPO_GIT=TRUE
      - KALLITHEA_EXTERNAL_SSH_PORT=2222
```

## Repository access with SSH

Refer to the following for the SSH repository access function.  

- [Kallithea 0.5.0 release announce](https://kallithea-scm.org/news/release-0.5.0.html)

The SSH public key for authentication is register from the account setting page after logging into kallithea with a browser.  
It is important to set up on kallithea to associate the key with the user.  

If you want to use SSH other than the default port, it is convenient to change the address notation setting.  
Log in to kallithea as an administrator from a browser and specify [SSH Clone URL] on the [Admin]-[Settings]-[Visual] settings page.  
For example, in the case of `docker -p 2222:22 ...`, the URL should be `ssh://{system_user}@{hostname}:2222/{repo}`.  

If you can set it correctly, you can authenticate by SSH key authentication without entering the password as shown below.

```bash
git clone ssh://kallithea@yourserver:2222/reponame
```

## Migration assistance mode

When upgrading the version of kallithea, you need to migrate.  
See [Upgrading Kallithea](https://kallithea.readthedocs.io/en/latest/upgrade.html) for exact steps.  

This image has a support function for version upgrade.  
The mode is executed by setting the environment variable `KALLITHEA_DB_MIGRATION` to TRUE.  
This is not an automatic operation, but a feature that supports manual migration procedures.  
Use in the following procedure.  

1. Be sure to back up the persistent data before execution.
1. Mount the data used by the old version and start the new version of the container with the environment variable `KALLITHEA_DB_MIGRATION` set to TRUE.
   - It can be in detach mode or interactive mode. However, you will need to work on the host.
   - It is recommended to display the output of the container to check the execution result.
1. A `kallithea.migrate.new.ini` file is created in the configuration file directory.  
Edit this file to manually merge the settings from the older version of the configuration file.
   - Note that the configuration file settings may change with version upgrades.
1. Rename from `kallithea.migrate.new.ini` to `kallithea.migrate.ready.ini`.
   - Renaming is the execution trigger because we are monitoring the file name.
1. When the migration is performed, the old `kallithea.ini` will be renamed to `kallithea.bak.ini` and `kallithea.migrate.ready.ini` will be the new `kallithea.ini`.  
In addition, `migration.finished` is created as a mark of processing completion.
1. Stop the container because it will be in the waiting state for termination.
1. Set KALLITHEA_DB_MIGRATION to FALSE or remove it to verify that the container is working.  
If all goes well, remove the `kallithea.bak.ini` and `migration.finished` files.
   - If you have these files, you will not be able to run the next migration assist.
