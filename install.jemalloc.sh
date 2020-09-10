#!/bin/bash
# install jemalloc
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

yum install -y epel-release
yum install -y gcc gcc-c++ make bzip2 unzip git lsof wget pv

JEMALLOC_VERSION="5.2.1"
force_cd /data/temp
prepare_source_by_wget "jemalloc-${JEMALLOC_VERSION}.tar.bz2" "https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2"
cd "jemalloc-${JEMALLOC_VERSION}" || exit

./configure
make && make install
echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
ldconfig

echo "link jemalloc-config to /usr/bin"
ln -s /usr/local/bin/jemalloc-config /usr/bin
echo "link jemalloc.sh to /usr/bin"
ln -s /usr/local/bin/jemalloc.sh /usr/bin
echo "link jeprof to /usr/bin"
ln -s /usr/local/bin/jeprof /usr/bin
echo "add to system environment"
echo "#export LD_PRELOAD=\`jemalloc-config --libdir\`/libjemalloc.so.\`jemalloc-config --revision\`" >> /etc/profile

echo "clean install resources"
rm -rf /data/temp/jemalloc-${JEMALLOC_VERSION}
rm -f /data/temp/jemalloc-${JEMALLOC_VERSION}.tar.bz2

echo -e "${C_BGREEN}install jemalloc successfully${C_NONE}"
echo "if you want to check it, input 'lsof -n | grep jemalloc'"