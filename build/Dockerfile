FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

# Pass the path in advance to the directory where kallithea is installed.
ENV PATH $PATH:/home/kallithea/.local/bin

# set locale
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN <<-EOL
    : This is what to keep installed in the image.
    apt-get update
    apt-get install -y --no-install-recommends                                      \
                    dumb-init ssh curl locales ca-certificates busybox-static       \
                    mercurial git python python-setuptools libpq5 libmysqlclient20
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOL

RUN <<-EOL
    : Prepare kallithea execution user.
    groupadd kallithea
    useradd -m -c '' -g kallithea kallithea
EOL

# Package version when installing by pip. ex.) 0.5.0
ARG KALLITHEA_VER=x.x.x

RUN <<-EOL
    : Check version specify
    if [ "$KALLITHEA_VER" = "x.x.x" ]; then false; fi
    
    : This is only needed for kallithea installation.
    curl -sL https://deb.nodesource.com/setup_10.x | bash -
    apt-get install -y --no-install-recommends                          \
                    build-essential libffi-dev                          \
                    python-pip python-dev libpq-dev libmysqlclient-dev  \
                    nodejs
    
    : Build su-exec
    git -C /tmp clone https://github.com/ncopa/su-exec.git su-exec
    make -C /tmp/su-exec all
    mv /tmp/su-exec/su-exec /usr/bin/
    rm -rf /tmp/su-exec
    
    : Install kallithea and optional packages.
    su-exec kallithea:kallithea pip install --no-cache-dir --user                                          \
                                            kallithea${KALLITHEA_VER:+==$KALLITHEA_VER} "PasteDeploy<3.0"  \
                                            psycopg2                                                       \
                                            mysqlclient
    
    : Preparing the front-end files.
    su-exec kallithea:kallithea kallithea-cli front-end-build
    
    : Clean up installation materials.
    apt-get purge -y                                                  \
                  build-essential libffi-dev                          \
                  python-pip python-dev libpq-dev libmysqlclient-dev  \
                  nodejs
    apt-get autoremove -y
    apt-get clean
    rm -r  /etc/apt/sources.list.d/nodesource.list
    rm -rf /var/lib/apt/lists/*
    rm -rf /home/kallithea/.npm
EOL

# SSH setting
RUN <<-EOL
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    sed -ri "s/^\\s*#?\\s*PubkeyAuthentication\\s+.+\$/PubkeyAuthentication yes/1" /etc/ssh/sshd_config
    sed -ri "s/^\\s*#?\\s*PasswordAuthentication\\s+.+\$/PasswordAuthentication no/1" /etc/ssh/sshd_config
    sed -ri "s/^\\s*#?\\s*ChallengeResponseAuthentication\\s+.+\$/ChallengeResponseAuthentication no/1" /etc/ssh/sshd_config
    sed -ri "s/^\\s*#?\\s*PermitRootLogin\\s+.+\$/PermitRootLogin no/1" /etc/ssh/sshd_config
    sed -ri "s/^\\s*#?\\s*X11Forwarding\\s+.+\$/X11Forwarding no/1" /etc/ssh/sshd_config
    
    echo '' >> /etc/ssh/sshd_config
    echo 'AcceptEnv GIT_PROTOCOL' >> /etc/ssh/sshd_config
EOL

# Copy assets.
COPY ./assets/ /kallithea/

# Prepare a directory for storing persistent data.
RUN <<-EOL
    mkdir -p /kallithea/config
    mkdir -p /kallithea/repos
    mkdir -p /home/kallithea/.ssh
    chown kallithea:kallithea /kallithea/config
    chown kallithea:kallithea /kallithea/repos
    chown kallithea:kallithea /home/kallithea/.ssh
EOL

# Service port
EXPOSE 5000 22

# Startup command
CMD ["dumb-init", "bash", "/kallithea/startup.sh"]
