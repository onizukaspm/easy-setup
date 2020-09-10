#!/bin/bash
# install sysbench
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

yum -y install make automake libtool pkgconfig libaio-devel git mysql-devel
# mariadb-devel for mariaDB
# postgresql-devel for PostgreSQL

force_cd /data/tools/sysbench
force_cd /data/temp

prepare_source_by_git "https://github.com/akopytov/sysbench.git" "sysbench"

cd sysbench || exit

./autogen.sh
# Add --with-pgsql to build with PostgreSQL support
./configure --prefix=/data/tools/sysbench
make -j
make install

/data/tools/sysbench/bin/sysbench --version

rm -rf /data/temp/sysbench

echo -e "${C_BGREEN}install sysbench successfully${C_NONE}"