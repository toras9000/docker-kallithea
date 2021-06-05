# v17.05 or later is required to use ARG for FROM.
ARG BUILD_ARCH=amd64
FROM ${BUILD_ARCH}/ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

# Pass the path in advance to the directory where kallithea is installed.
ENV PATH $PATH:/home/kallithea/.local/bin

# set locale
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN : This is what to keep installed in the image. \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
                    dumb-init ssh curl locales ca-certificates mercurial git python3.6 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN : Prepare kallithea execution user. \
 && groupadd kallithea \
 && useradd -m -c '' -g kallithea kallithea

# Package version when installing by pip. ex.) 0.5.0
ARG KALLITHEA_VER=0.6.1

RUN : This is only needed for kallithea installation. \
 && curl -sL https://deb.nodesource.com/setup_14.x | bash - \
 && apt-get install -y --no-install-recommends \
                    build-essential libffi-dev \
                    python3-dev libpq-dev libmysqlclient-dev \
                    nodejs \
 && : Build su-exec \
 && git -C /tmp clone https://github.com/ncopa/su-exec.git su-exec \
 && make -C /tmp/su-exec all \
 && mv /tmp/su-exec/su-exec /usr/bin/ \
 && rm -rf /tmp/su-exec \
 && : Install pip.\
 && curl -sL https://bootstrap.pypa.io/get-pip.py | python3 \
 && : Install kallithea and optional packages.\
 && su-exec kallithea:kallithea python3 -m pip install --no-cache-dir --user kallithea${KALLITHEA_VER:+==$KALLITHEA_VER} \
 && su-exec kallithea:kallithea python3 -m pip install --no-cache-dir psycopg2 \
 && su-exec kallithea:kallithea python3 -m pip install --no-cache-dir mysqlclient \
 && : Preparing the front-end files. \
 && su-exec kallithea:kallithea kallithea-cli front-end-build \
 && : Clean up installation materials. \
 && apt-get purge -y \
                  build-essential libffi-dev \
                  python3-dev libpq-dev libmysqlclient-dev \
                  nodejs \
 && apt-get clean \
 && rm -r  /etc/apt/sources.list.d/nodesource.list \
 && rm -rf /var/lib/apt/lists/*

# SSH setting
RUN sed -ri "s/^\\s*#?\\s*PubkeyAuthentication\\s+.+\$/PubkeyAuthentication yes/1" /etc/ssh/sshd_config \
 && sed -ri "s/^\\s*#?\\s*PasswordAuthentication\\s+.+\$/PasswordAuthentication no/1" /etc/ssh/sshd_config \
 && sed -ri "s/^\\s*#?\\s*ChallengeResponseAuthentication\\s+.+\$/ChallengeResponseAuthentication no/1" /etc/ssh/sshd_config \
 && sed -ri "s/^\\s*#?\\s*PermitRootLogin\\s+.+\$/PermitRootLogin no/1" /etc/ssh/sshd_config \
 && sed -ri "s/^\\s*#?\\s*X11Forwarding\\s+.+\$/X11Forwarding no/1" /etc/ssh/sshd_config

# Prepare a directory for storing persistent data.
RUN mkdir -p /kallithea/config \
 && mkdir -p /kallithea/repos \
 && mkdir -p /home/kallithea/.ssh \
 && chown kallithea:kallithea /kallithea/config \
 && chown kallithea:kallithea /kallithea/repos \
 && chown kallithea:kallithea /home/kallithea/.ssh

# Copy assets.
COPY ./assets/startup.sh /kallithea/startup.sh

# Service port
EXPOSE 5000 22

# Startup command
CMD ["dumb-init", "bash", "/kallithea/startup.sh"]
