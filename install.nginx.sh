#!/bin/bash
# install MySQL Server
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

yum install -y epel-release
yum install -y bzip2 unzip git lsof pcre pcre-devel zlib zlib-devel openssl openssl-devel libuuid-devel pv

if [ "$(getent group nginx)" ]; then
    echo "group 'nginx' exists"
else
    echo "add group 'nginx'"
    groupadd -r nginx
fi
if id -u nginx > /dev/null 2>&1; then
    echo "user 'nginx' exists";
else
    echo "add user 'nginx'";
    useradd -r -g nginx -c "Nginx web server" -s /sbin/nologin nginx
fi

force_cd /data/temp
# 提供 ALPN 支持，支持 HTTP/2
OPENSSL_VERSION="openssl-1.1.1"
prepare_source_by_wget "${OPENSSL_VERSION}f.tar.gz" "https://www.openssl.org/source/${OPENSSL_VERSION}f.tar.gz"

# 透明证书提高 HTTPS 网站的安全性和浏览器支持
NCT_VERSION="1.3.2"
prepare_source_by_wget "nginx-ct-${NCT_VERSION}.tar.gz" "https://github.com/grahamedgecombe/nginx-ct/archive/v${NCT_VERSION}.tar.gz"

# 实现比 Gzip 更高的压缩率
prepare_source_by_git "https://github.com/google/ngx_brotli.git" "ngx_brotli"

# Google 家的网站性能优化工具，gcc ≥ 4.8
NPS_VERSION="1.13.35.2-stable"
prepare_source_by_wget "ngx_pagespeed_v${NPS_VERSION}.zip" "https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}.zip"
nps_dir=$(find . -name "*pagespeed-ngx-${NPS_VERSION}" -type d)
cd "$nps_dir" || exit
NPS_RELEASE_NUMBER=${NPS_VERSION/beta/}
NPS_RELEASE_NUMBER=${NPS_VERSION/stable/}
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz
[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
prepare_source_by_wget "$(basename "${psol_url}")" "${psol_url}"
cd ../

# 流量监控
prepare_source_by_git "git://github.com/vozlt/nginx-module-vts.git" "nginx-module-vts"

# nginx
NGINX_VERSION="nginx-1.18.0"
# 有外网的情况
prepare_source_by_wget "${NGINX_VERSION}.tar.gz" "https://nginx.org/download/${NGINX_VERSION}.tar.gz"

# 目前gcc=4.8.5，无需此检测
# 检查gcc版本，ngx_pagespeed 需要大于 4.8.0
# isGCCAvailable=$(check_gcc_version 4.8.0)
# if [ "$isGCCAvailable" == "false" ]; then
#     echo "gcc version < 4.8.0"
#     echo "install devtools-2 to make gcc version >= 4.8.0"
#     rpm -ivh "https://www.softwarecollections.org/repos/rhscl/devtoolset-3/epel-6-x86_64/noarch/rhscl-devtoolset-3-epel-6-x86_64-1-2.noarch.rpm"
#     yum repolist
#     yum install -y devtoolset-3-gcc devtoolset-3-gcc-c++ devtoolset-3-gdb devtoolset-3-binutils
#     if [ -f /opt/rh/devtoolset-3/root/usr/bin/gcc ]; then
#         ln -s /opt/rh/devtoolset-3/root/usr/bin/* /usr/local/bin/
#         hash -r
#     fi
# fi
# gcc -version

# build
cd "${NGINX_VERSION}" || exit
./configure --prefix=/data/nginx \
--user=nginx --group=nginx \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_gzip_static_module \
--with-http_sub_module \
--with-pcre \
--with-stream \
--with-ld-opt='-ljemalloc' \
--with-openssl="../${OPENSSL_VERSION}f" \
--add-module="../ngx_brotli" \
--add-module="../nginx-ct-${NCT_VERSION}" \
--add-module="../${nps_dir}" \
--add-module="../nginx-module-vts" \

make || (echo "install $NGINX_VERSION failed!"; exit 1)
make install

# add conf
cat >| /data/nginx/conf/nginx.conf << EOF
user nginx;
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 1048576;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

pid        logs/nginx.pid;

events {
    use epoll;
    worker_connections 1048576;
    multi_accept on;
}

http {
    include mime.types;
    default_type application/octet-stream;
    server_names_hash_bucket_size 128;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size 1024m;
    client_body_buffer_size 10m;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 120;
    server_tokens off;
    tcp_nodelay on;

    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 4 64k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 128k;
    fastcgi_intercept_errors on;

    #Gzip Compression
    gzip on;
    gzip_buffers 16 8k;
    gzip_comp_level 6;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        text/xml application/xml application/atom+xml application/rss+xml application/xhtml+xml image/svg+xml
        text/javascript application/javascript application/x-javascript
        text/x-json application/json application/x-web-app-manifest+json
        text/css text/plain text/x-component
        font/opentype application/x-font-ttf application/vnd.ms-fontobject
        image/x-icon;
    gzip_disable "MSIE [1-6]\\.(?!.*SV1)";

    brotli             on;
    brotli_comp_level  6;
    brotli_types       text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;

    #If you have a lot of static files to serve through Nginx then caching of the files' metadata (not the actual files' contents) can save some latency.
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    proxy_connect_timeout      40;
    proxy_read_timeout         60;
    proxy_send_timeout         60;
    proxy_buffer_size          16k;
    proxy_buffers              4 64k;
    proxy_busy_buffers_size    128k;
    proxy_temp_file_write_size 128k;

    # 开启统计
    # vhost_traffic_status_zone;

    include /data/nginx/conf/sites-enable/*.conf;
}
EOF

mkdir -p /data/nginx/conf/sites-enable
mkdir -p /data/nginx/ssl
chown -R nginx.nginx /data/nginx

# add service & start
if exists_command systemctl; then
    # create systemd service
    cat >| /usr/lib/systemd/system/nginx.service << EOF
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/data/nginx/logs/nginx.pid
ExecStartPre=/data/nginx/sbin/nginx -t -c /data/nginx/conf/nginx.conf
ExecStart=/data/nginx/sbin/nginx -c /data/nginx/conf/nginx.conf
ExecReload=/data/nginx/sbin/nginx -s reload
ExecStop=/data/nginx/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable nginx.service
    systemctl start  nginx.service
else
    /bin/cp -f "$LIB_PATH/libs/nginx.service" /etc/init.d/nginx
    chmod a+x /etc/init.d/nginx
    chkconfig nginx on
    service nginx restart
fi

pgrep -a -f "nginx"

lsof -n | grep jemalloc

# Highlight Nginx config file in Vim
# Download syntax highlight
mkdir -p ~/.vim/syntax/
wget http://www.vim.org/scripts/download_script.php?src_id=19394 -O ~/.vim/syntax/nginx.vim

# Set location of Nginx config file
cat > ~/.vim/filetype.vim <<EOF
au BufRead,BufNewFile /etc/nginx/*,/etc/nginx/conf.d/*,/data/nginx/conf/*,/data/nginx/conf/sites-enable/* if &ft == '' | setfiletype nginx | endif
EOF

rm -f /data/temp/${OPENSSL_VERSION}f.tar.gz
rm -rf /data/temp/${OPENSSL_VERSION}f

rm -f /data/temp/nginx-ct-${NCT_VERSION}.tar.gz
rm -rf /data/temp/nginx-ct-${NCT_VERSION}

rm -rf /data/temp/ngx_brotli

rm -f /data/temp/ngx_pagespeed_v${NPS_VERSION}.zip
rm -rf "/data/temp/$nps_dir"

rm -rf /data/temp/nginx-module-vts

rm -f /data/temp/${NGINX_VERSION}.tar.gz
rm -rf /data/temp/${NGINX_VERSION}

echo -e "${C_BGREEN}install $NGINX_VERSION successfully!${C_NONE}"