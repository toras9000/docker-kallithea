# Kallithea (with SSH) Docker Image

[This](https://hub.docker.com/r/toras9000/kallithea) is a docker image of the source code management system [kallithea](https://kallithea-scm.org/).  
This image enables the SSH repository access function implemented in kallithea version 0.5 and later.  

## Tags

- latest ([Dockerfile](https://github.com/toras9000/docker-kallithea/tree/main/build))
- 0.5.2
- 0.5.1
- 0.5.0 (*1)

*1: You may want to avoid using MySQL in new instances. see [release announce](https://kallithea-scm.org/news/release-0.5.1.html)

## Usage

If you run for trial.  
The container provides application services on port 5000 and SSH services on port 22.  
When forwarding the SSH port, do not forget to specify the clone address. see 'Repository access with SSH' section.  

```bash
$ docker run -d -p 8000:5000 -p 2222:22 toras9000/kallithea
```

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

The following are the variables that are used every time it starts.  

- `KALLITHEA_LOCALE`  
Specify the locale in the container.  ("en_US.UTF-8" by default)  

- `KALLITHEA_REPOSORT_IDX`  
Default sort column number for repository list.  
A rough patch to the display template. (empty by default, no patch.)  

- `KALLITHEA_REPOSORT_ORDER`  
Sort direction when default sort column is specified.  
A rough patch to the display template. ("asc" by default)  

- `KALLITHEA_FIX_PERMISSION`  
If set to TRUE, will overwrite the permissions of configuration files. (TRUE by default)  

- `KALLITHEA_FIX_REPOS_PERMISSION`  
If set to TRUE, will overwrite the permissions of the repository files. (FALSE by default)  

- `KALLITHEA_DB_MIGRATION`  
If set to TRUE (capitals exactly), it will run in migration assistance mode. (empty by default)  
The support mode does not execute normal services, but functions as a migration execution support tool when upgrading.  
This is used only once when upgrading.  
For more information, see the 'Migration assistance mode' section below.

### Usage examples

When executing with persistence, the following two steps are assumed as an example.  
First, run with database initialization.  

```bash
$ docker run -d -p 8000:5000 -p 2222:22 \
             -e KALLITHEA_ADMIN_USER=admin \
             -e KALLITHEA_ADMIN_PASS=secret \
             -v /opt/kallithea/config:/kallithea/config \
             -v /opt/kallithea/repos:/kallithea/repos \
             -v /opt/kallithea/ssh:/home/kallithea/.ssh \
             toras9000/kallithea
```

After the initialization is completed, omit unnecessary specifications for the second time and later.  

```bash
$ docker run -d -p 8000:5000 -p 2222:22 \
             -v /opt/kallithea/config:/kallithea/config \
             -v /opt/kallithea/repos:/kallithea/repos \
             -v /opt/kallithea/ssh:/home/kallithea/.ssh \
             toras9000/kallithea
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
