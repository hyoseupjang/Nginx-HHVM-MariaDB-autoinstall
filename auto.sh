##!/bin/sh
echo This Script will set up Nginx-HHVM-MariaDB High perfomance server. 
echo This script will install MariaDB by using RPM, But HHVM and Nginx will be installd by compile. I will update this script to install MariaDB using compile installation. 
echo ######################### Start Install HHVM #########################
useradd --shell /sbin/nologin www-data
yum -y update
yum -y install 
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum -y install cpp gcc-c++ cmake git psmisc {binutils,boost,jemalloc}-devel {ImageMagick,sqlite,tbb,bzip2,openldap,readline,elfutils-libelf,gmp,lz4,pcre}-devel lib{xslt,event,yaml,vpx,png,zip,icu,mcrypt,memcached,cap,dwarf}-devel {unixODBC,expat,mariadb}-devel lib{edit,curl,xml2,xslt}-devel glog-devel oniguruma-devel ocaml gperf enca libjpeg-turbo-devel openssl-devel make wget 
echo ######################### Upgrade Maria DB #########################
yum -y remove mariadb* mariadb-libs-5.5* 
cat >  /etc/yum.repos.d/MariaDB.repo <<END
# MariaDB 10.1 CentOS repository list - created 2015-09-12 00:45 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
END
yum -y install MariaDB-server MariaDB-client MariaDB-devel
service mysql start
cd /tmp
echo ######################### Get HHVM Source & Compile #########################
git clone https://github.com/facebook/hhvm -b master  hhvm  --recursive
cd hhvm
cmake .
make -j$(($(nproc)+1))
echo ######################### HHVM Test & Install #########################
./hphp/hhvm/hhvm --version
make install
echo ######################### Set hhvm.service #########################
cat > /usr/lib/systemd/system/hhvm.service <<END
[Unit]
Description=HHVM HipHop Virtual Machine (FCGI)

[Service]
ExecStartPre=-/usr/bin/mkdir -p /var/run/hhvm
ExecStartPre=-/usr/bin/chown nobody /var/run/hhvm
ExecStart=/usr/local/bin/hhvm --config /etc/hhvm/server.ini --user www-data --mode daemon -vServer.Type=fastcgi -vServer.Port=9000

[Install]
WantedBy=multi-user.target
END
systemctl enable hhvm
systemctl start hhvm
systemctl status hhvm
echo ######################### Get NGINX Source & Compile & Install #########################
yum -y install zlib-devel 
cd /tmp
wget http://nginx.org/download/nginx-1.9.4.tar.gz
tar -xvzf nginx-1.9.4.tar.gz
cd nginx-1.9.4/
./configure --with-http_ssl_module --user=www-data --group=www-data
make
make install
cd /usr/bin/
ln -s /usr/local/nginx/sbin/nginx
cd /usr/local/nginx/conf
echo ######################### Replace Nginx.conf #########################
rm -f /usr/local/nginx/conf/nginx.conf
wget https://raw.githubusercontent.com/nadanomics/Nginx-HHVM-MariaDB-autoinstall/master/nginx.conf
cd /usr/local/nginx/html
echo ######################### Download hhvminfo.php #########################
wget https://gist.githubusercontent.com/ck-on/67ca91f0310a695ceb65/raw/c0d9a376680ba5dc83e8f10475293f4042bda8a7/hhvminfo.php
systemctl stop firewalld
systemctl mask firewalld
yum -y install iptables-services
systemctl enable iptables
rm -f /etc/sysconfig/iptables
cat > /etc/sysconfig/iptables <<END
# you can edit this manually or use system-config-firewall
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
END
systemctl restart iptables
echo You need to edit nginx.conf worker_processes as your server core number. And do "nginx -t reload" to reload conf file. 
echo You also need to do DB secure installation. 
nginx
mysql_secure_installation
clear
echo You can test webserver by accessing http://server_ip.  
echo you can get more information about this server, please watch hhvm info by accessing http://server_ip/hhvminfo.php
echo And, you must remove hhvminfo.php after read about it. 
