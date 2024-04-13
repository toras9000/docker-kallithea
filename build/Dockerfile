FROM toras9000/kallithea-mp:0.7.0

ARG DEBIAN_FRONTEND=noninteractive

COPY ./assets/ /kallithea/

ARG KALLITHEA_REV=stable

RUN <<-EOL
    hg clone --rev "$KALLITHEA_REV" https://kallithea-scm.org/repos/kallithea /kallithea/src
    cp -RT /kallithea/src/kallithea "$(su-exec kallithea:kallithea python3 -m site --user-site)/kallithea"
    rm -rf /kallithea/src
    sed -ri 's/^\s*VERSION\s*=\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*(.*)\)\s*$/VERSION = \(\1, \2, \3, '"'rev-${KALLITHEA_REV}'"'\)/' "$(su-exec kallithea:kallithea python3 -m site --user-site)/kallithea/__init__.py"
EOL
