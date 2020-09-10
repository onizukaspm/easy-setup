#!/bin/bash
# install MySQL Server
# 1. 优化 optimize.system.db.sh
# 2. 依赖 install_jemalloc.sh
set -o errexit -o pipefail -o noclobber -o nounset
## include libs
LIB_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" || exit ; pwd -P )
# shellcheck source=libs/util.sh
. "${LIB_PATH}/libs/util.sh"

yum install -y epel-release
yum install -y gcc gcc-c++ ncurses ncurses-devel cmake bison openssl openssl-devel wget lsof expect pv libtirpc-devel

force_cd /data/temp
if ! exists_command rpcgen; then
  # 在CentOS8下编译安装MySQL可能会出现“Could not find rpcgen”错误，而CentOS8默认的yum源下不提供rpcgen的安装包
  wget https://github.com/thkukuk/rpcsvc-proto/releases/download/v1.4/rpcsvc-proto-1.4.tar.gz
  tar -zxvf rpcsvc-proto-1.4.tar.gz
  cd rpcsvc-proto-1.4/ && ./configure && make && make install
  cd ../
  rm -f rpcsvc-proto-1.4.tar.gz
fi

if [ "$(getent group mysql)" ]; then
    echo "group 'mysql' exists"
else
    echo "add group 'mysql'"
    groupadd -r mysql
fi
if id -u mysql > /dev/null 2>&1; then
    echo "user 'mysql' exists";
else
    echo "add user 'mysql'";
    useradd -r -g mysql -c "MySQL server" -s /sbin/nologin mysql
fi

MYSQL_VERSION="mysql-5.7.30"
MYSQL_PORT=7706
# 密码不可包含$符号，否则可能创建login-path失败
MYSQL_USER="pick"
MYSQL_PASSWORD="sd-9898w"
MYSQL_DIR="/data/mysql"
LOG_DIR="/data/mysql"
MYSQL_SERVICE="mysqld"

force_cd /data/temp
prepare_source_by_wget "${MYSQL_VERSION}.tar.gz" "https://dev.mysql.com/get/Downloads/MySQL-5.7/${MYSQL_VERSION}.tar.gz"
prepare_source_by_wget "boost_1_59_0.tar.gz" "https://mirrors.aliyun.com/macports/distfiles/mysql57/boost_1_59_0.tar.gz"
tar xzf boost_1_59_0.tar.gz
mv boost_1_59_0 /usr/local/boost_1_59_0

cd ${MYSQL_VERSION} || exit

cmake . \
-DCMAKE_INSTALL_PREFIX=${MYSQL_DIR} \
-DMYSQL_DATADIR=${MYSQL_DIR}/data \
-DSYSCONFDIR=${MYSQL_DIR}/config \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_MEMORY_STORAGE_ENGINE=1 \
-DWITH_READLINE=1 \
-DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
-DMYSQL_TCP_PORT=${MYSQL_PORT} \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DCMAKE_EXE_LINKER_FLAGS="-ljemalloc" \
-DWITH_SAFEMALLOC=OFF \
-DWITH_BOOST=/usr/local/boost_1_59_0

make && make install
cd ../

mkdir -p ${LOG_DIR}/binlog
mkdir -p ${LOG_DIR}/relaylog
mkdir -p ${LOG_DIR}/dumplog
mkdir -p ${LOG_DIR}/logs
mkdir -p ${MYSQL_DIR}/data
mkdir -p ${MYSQL_DIR}/config
chown -R mysql.mysql ${LOG_DIR}
chown -R mysql.mysql ${MYSQL_DIR}

server_id=$( get_inet_ip_decimal )
page_size=$( getconf PAGE_SIZE )
phys_pages=$( getconf _PHYS_PAGES )
if [ -z "$page_size" ]; then
  echo "WARN: cannot determine page size, use default 4096"
  page_size=4096
fi

if [ -z "$phys_pages" ]; then
  echo "WARN: cannot determine number of memory pages, use default 16777216(64GB)"
  phys_pages=16777216
fi
# 设置innodb缓冲池为物理内存的80%
innodb_buffer="$(( phys_pages * page_size * 80 / 107374182400 ))"

cpu_cores=$( getconf _NPROCESSORS_ONLN )
if [ -z "$cpu_cores" ]; then
  echo "WARN: cannot determine cpu cores, use default 8"
  cpu_cores=8
fi
threads="$(( cpu_cores - 1 ))"

echo "$( date +"[%F %T.%N]") write ${MYSQL_DIR}/config/my.cnf"
cat >| ${MYSQL_DIR}/config/my.cnf << EOF
[mysql]
port                            = ${MYSQL_PORT}
socket                          = ${MYSQL_DIR}/mysqld.sock

[mysqld]
# Required Settings
basedir                         = ${MYSQL_DIR}
#bind_address                    = 127.0.0.1 # Change to 0.0.0.0 to allow remote connections
datadir                         = ${MYSQL_DIR}/data
character-set-server            = UTF8
max_allowed_packet              = 256M
max_connect_errors              = 1000000
pid_file                        = ${MYSQL_DIR}/mysql.pid
port                            = ${MYSQL_PORT}
socket                          = ${MYSQL_DIR}/mysqld.sock
skip_external_locking
skip_name_resolve

# Replicate Settings
log-slave-updates               = true
sync_binlog                     = 1
log-bin                         = ${LOG_DIR}/binlog/mysql-bin
binlog_cache_size               = 4M
binlog_format                   = MIXED
max_binlog_cache_size           = 8M
max_binlog_size                 = 1G
relay-log-index                 = ${LOG_DIR}/relaylog/relay-bin
relay-log-info-file             = ${LOG_DIR}/relaylog/relay-bin
relay-log                       = ${LOG_DIR}/relaylog/relay-bin
expire_logs_days                = 14
slave-skip-errors               = 1032,1062,126,1114,1146,1048,1396
server-id                       = ${server_id}
gtid_mode                       = ON
enforce_gtid_consistency        = ON


# Enable for b/c with databases created in older MySQL/MariaDB versions (e.g. when using null dates)
#                                 >= 5.7.5 default enable: ONLY_FULL_GROUP_BY , STRICT_TRANS_TABLES
#                                 >= 5.7.7 default enable: NO_AUTO_CREATE_USER
#                                 >= 5.7.8 default enable: ERROR_FOR_DIVISION_BY_ZERO, NO_ZERO_DATE, NO_ZERO_IN_DATE
#                                 defalut enable: NO_ENGINE_SUBSTITUTION
#sql_mode                        = ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION,ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES
tmpdir                          = /tmp
user                            = mysql

# InnoDB Settings
default_storage_engine          = InnoDB
innodb_buffer_pool_instances    = ${innodb_buffer}     # Use 1 instance per 1GB of InnoDB pool size
innodb_buffer_pool_size         = ${innodb_buffer}G    # Use up to 70-80% of RAM
innodb_file_per_table           = 1
innodb_flush_log_at_trx_commit  = 1
innodb_flush_method             = O_DIRECT
innodb_log_buffer_size          = 16M
innodb_log_file_size            = 512M
innodb_stats_on_metadata        = 0
innodb_lock_wait_timeout        = 120
transaction_isolation           = READ-COMMITTED

#innodb_temp_data_file_path     = ibtmp1:64M:autoextend:max:20G # Control the maximum size for the ibtmp1 file
#   Optional: Set to the number of CPUs on your system (minus 1 or 2) to better
#   contain CPU usage. E.g. if your system has 8 CPUs, try 6 or 7 and check
#   the overall load produced by MySQL/MariaDB.
innodb_thread_concurrency       = ${threads}
innodb_read_io_threads          = 64
innodb_write_io_threads         = 64

# MyISAM Settings
query_cache_limit               = 4M     # UPD - Option supported by MariaDB & up to MySQL 5.7, remove this line on MySQL 8.x
query_cache_size                = 64M    # UPD - Option supported by MariaDB & up to MySQL 5.7, remove this line on MySQL 8.x
query_cache_type                = 2      # Option supported by MariaDB & up to MySQL 5.7, remove this line on MySQL 8.x

key_buffer_size                 = 1G     # UPD

group_concat_max_len            = 102400 # GROUP_CONCAT result length

low_priority_updates            = 1
concurrent_insert               = 2

myisam_sort_buffer_size         = 5G
myisam_max_sort_file_size       = 20G
myisam_repair_threads           = 1
myisam-recover-options          = BACKUP

# Connection Settings
max_connections                 = 2000  # UPD

back_log                        = 512
thread_cache_size               = 300
thread_stack                    = 192K

interactive_timeout             = 28800
wait_timeout                    = 28800

# For MySQL 5.7+ only (disabled by default)
#max_execution_time             = 30000 # Set a timeout limit for SELECT statements (value in milliseconds).
                                        # This option may be useful to address aggressive crawling on large sites,
                                        # but it can also cause issues (e.g. with backups). So use with extreme caution and test!
                                        # More info at: https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_max_execution_time

# For MariaDB 10.1.1+ only (disabled by default)
#max_statement_time             = 30    # The equivalent of "max_execution_time" in MySQL 5.7+ (set above)
                                        # The variable is of type double, thus you can use subsecond timeout.
                                        # For example you can use value 0.01 for 10 milliseconds timeout.
                                        # More info at: https://mariadb.com/kb/en/aborting-statements/

# Buffer Settings
join_buffer_size                = 4M    # UPD
read_buffer_size                = 3M    # UPD
read_rnd_buffer_size            = 16M   # UPD
sort_buffer_size                = 4M    # UPD
bulk_insert_buffer_size         = 64M   # UPD

# Table Settings
# In systemd managed systems like Ubuntu 16.04+ or CentOS 7+, you need to perform an extra action for table_open_cache & open_files_limit
# to be overriden (also see comment next to open_files_limit).
# E.g. for MySQL 5.7, please check: https://dev.mysql.com/doc/refman/5.7/en/using-systemd.html
# and for MariaDB check: https://mariadb.com/kb/en/library/systemd/
table_definition_cache          = 40000 # UPD
table_open_cache                = 40000 # UPD
open_files_limit                = 60000 # UPD - This can be 2x to 3x the table_open_cache value or match the system's
                                        # open files limit usually set in /etc/sysctl.conf or /etc/security/limits.conf
                                        # In systemd managed systems this limit must also be set in:
                                        # /etc/systemd/system/mysqld.service.d/override.conf (for MySQL 5.7+) and
                                        # /etc/systemd/system/mariadb.service.d/override.conf (for MariaDB)

max_heap_table_size             = 512M
tmp_table_size                  = 512M
explicit_defaults_for_timestamp = true

# Search Settings
ft_min_word_len                 = 3     # Minimum length of words to be indexed for search results

# Logging
log_error                       = ${LOG_DIR}/logs/mysql_error.log
log_queries_not_using_indexes   = 1
long_query_time                 = 5
slow_query_log                  = OFF   # Disabled for production
slow_query_log_file             = ${LOG_DIR}/logs/slow.log

#lc-messages-dir                = /usr/local/mysql/share

[mysqldump]
# Variable reference
# For MySQL 5.7: https://dev.mysql.com/doc/refman/5.7/en/mysqldump.html
# For MariaDB:   https://mariadb.com/kb/en/library/mysqldump/
quick
quote_names
max_allowed_packet              = 64M
EOF

# 5.7
${MYSQL_DIR}/bin/mysqld --defaults-file=${MYSQL_DIR}/config/my.cnf --user=mysql --basedir=${MYSQL_DIR} --datadir=${MYSQL_DIR}/data --initialize

echo "export PATH=\${PATH}:${MYSQL_DIR}/bin" >> /etc/profile
export PATH=${PATH}:${MYSQL_DIR}/bin

# start
${MYSQL_DIR}/bin/mysqld_safe --defaults-file=${MYSQL_DIR}/config/my.cnf &
# 第一次启动会比较慢
sleep 300

pgrep -a -f "mysqld"

TempPassword=$( grep "A temporary password is generated" "${LOG_DIR}/logs/mysql_error.log" | awk -F "root@localhost: " '{print $2}' )


echo -e "$( date +"[%F %T.%N]" ) ${C_BBLUE}A temporary password is generated: ${C_NONE}$TempPassword"
# clean up user, set password
# DELETE FROM mysql.user WHERE (user = 'root' AND host != 'localhost' AND host != '127.0.0.1') OR user != 'root';
echo "$( date +"[%F %T.%N]" ) change password & add user 'root'@'%'"
${MYSQL_DIR}/bin/mysql --host=localhost --user=root --port=$MYSQL_PORT --password="$TempPassword" --connect-expired-password --default-character-set=utf8 -e "
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
RENAME USER 'root'@'localhost' TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;"

# create login-path
unbuffer expect -c "
spawn ${MYSQL_DIR}/bin/mysql_config_editor set --login-path=local --host=localhost --port=$MYSQL_PORT --user=${MYSQL_USER} --password
expect -nocase \"Enter password:\" {send \"$MYSQL_PASSWORD\r\"; interact}"

sleep 3

# add service
if exists_command systemctl; then
    # create systemd service
    cat >| /usr/lib/systemd/system/${MYSQL_SERVICE}.service << EOF
[Unit]
Description=MySQL Community Server
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target
Alias=${MYSQL_SERVICE}.service

[Service]
User=mysql
Group=mysql

#systemctl status就是根据pid来判断服务的运行状态的
PIDFile=${MYSQL_DIR}/mysql.pid

# 以root权限来启动程序
PermissionsStartOnly=true

# 设置程序启动前的必要操作。例如初始化相关目录等等
#ExecStartPre=${MYSQL_DIR}/bin/mysql-systemd-start pre

# 启动服务
ExecStart=${MYSQL_DIR}/bin/mysqld_safe --defaults-file=${MYSQL_DIR}/config/my.cnf

# 停止服务
ExecStop=${MYSQL_DIR}/bin/mysqladmin --login-path=local shutdown

# Don't signal startup success before a ping works
#ExecStartPost=${MYSQL_DIR}/bin/mysql-systemd-start post

# Give up if ping don't get an answer
TimeoutSec=600

#Restart配置可以在进程被kill掉之后，让systemctl产生新的进程，避免服务挂掉
Restart=always
PrivateTmp=false

LimitNOFILE=65535
LimitNPROC=65535
EOF
    systemctl enable ${MYSQL_SERVICE}.service
    systemctl restart ${MYSQL_SERVICE}.service
    systemctl status ${MYSQL_SERVICE}.service
else
    cp ${MYSQL_DIR}/support-files/mysql.server /etc/init.d/${MYSQL_SERVICE}
    chmod a+x /etc/init.d/${MYSQL_SERVICE}
    chkconfig ${MYSQL_SERVICE} on
    service ${MYSQL_SERVICE} restart
fi

echo "${MYSQL_DIR}/bin/mysql --login-path=local --default-character-set=utf8" > /usr/local/bin/my.local.sh
chmod +x /usr/local/bin/my.local.sh

lsof -n | grep jemalloc

rm -rf /data/temp/$MYSQL_VERSION
rm -f /data/temp/${MYSQL_VERSION}.tar.gz
rm -f /data/temp/boost_1_59_0.tar.gz

echo -e "${C_BGREEN}install $MYSQL_VERSION successfully!${C_NONE}"