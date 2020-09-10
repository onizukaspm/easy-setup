#!/bin/bash
# install java
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")" || exit
  pwd -P
)
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

if exists_command java; then
  echo -e "$(date +"[%F %T.%N]") Java exist! Abort installation!"
  $(command -v java) -version
  exit 0
fi

yum install -y epel-release
yum install -y jq curl pv

JDK_JSON=$(curl -s https://lv.binarybabel.org/catalog-api/java/jdk8.json)
JAVA_MAJOR=$(echo "$JDK_JSON" | jq --raw-output '.version_parsed.major')
JAVA_MINOR=$(echo "$JDK_JSON" | jq --raw-output '.version_parsed.minor')
DOWNLOAD_URL=$(echo "$JDK_JSON" | jq --raw-output '.downloads.tgz')

JAVA_PATH="JDK_${JAVA_MAJOR}"
JAVA_VERSION="${JAVA_MAJOR}u${JAVA_MINOR}"
JAVA_TAR="jdk-${JAVA_VERSION}-linux-x64.tar.gz"
JAVA_ORIGIN_DIR="jdk1.8.0_${JAVA_MINOR}"
TAR_MD5_CHECKSUM=$(curl -s "https://www.oracle.com/webfolder/s/digest/${JAVA_VERSION}checksum.html" | grep "${JAVA_TAR}")
TAR_MD5_CHECKSUM=${TAR_MD5_CHECKSUM##* }
TAR_MD5_CHECKSUM=${TAR_MD5_CHECKSUM%%<*}

echo "$(date +"[%F %T.%N]") Java Development Kit"
echo "$(date +"[%F %T.%N]")     file     ${JAVA_TAR}"
echo "$(date +"[%F %T.%N]")     version  ${JAVA_VERSION}"
echo "$(date +"[%F %T.%N]")     MD5      ${TAR_MD5_CHECKSUM}"
echo "$(date +"[%F %T.%N]")     download ${DOWNLOAD_URL}"

force_cd /data
# JDK下载包需要提前准备，建议使用JDK8的版本
wget --quiet --show-progress --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "${DOWNLOAD_URL}"

if [ -f "${JAVA_TAR}" ]; then
  TAR_MD5=$(md5sum "${JAVA_TAR}")
  TAR_MD5=${TAR_MD5%% *}

  if [ x"$TAR_MD5_CHECKSUM" != x"${TAR_MD5}" ]; then
    echo "$(date +"[%F %T.%N]") MD5(${JAVA_TAR}) = ${TAR_MD5}, check failed!"
    exit 1
  fi

  pv "${JAVA_TAR}" | tar xzf -
  rm -f "${JAVA_TAR}"
  mv "$JAVA_ORIGIN_DIR" "$JAVA_PATH"

  echo "export PATH=\${PATH}:/data/${JAVA_PATH}/bin" >>/etc/profile
  export PATH=${PATH}:/data/${JAVA_PATH}/bin

  echo "$(date +"[%F %T.%N]") PATH $PATH"

  java -version

  echo -e "$(date +"[%F %T.%N]") ${C_BGREEN}install JDK ${JAVA_VERSION} successfully${C_NONE}"
fi
