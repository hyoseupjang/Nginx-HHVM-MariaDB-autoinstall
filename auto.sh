##!/bin/sh
echo ######################### Start Install HHVM #########################
cd /tmp
useradd --shell /sbin/nologin www-data
yum -y update
yum -y install git wget
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum -y install cpp gcc-c++ cmake git psmisc {binutils,boost,jemalloc}-devel {ImageMagick,sqlite,tbb,bzip2,openldap,readline,elfutils-libelf,gmp,lz4,pcre}-devel lib{xslt,event,yaml,vpx,png,zip,icu,mcrypt,memcached,cap,dwarf}-devel {unixODBC,expat,mariadb}-devel lib{edit,curl,xml2,xslt}-devel glog-devel oniguruma-devel ocaml gperf enca libjpeg-turbo-devel openssl-devel make
echo ######################### Upgrade Maria DB #########################
yum -y remove mariadb mariadb-libs-5.5* 
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
git clone https://github.com/facebook/hhvm -b master hhvm --recursive
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

echo ######################### Install NGINX #########################
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
cat > /usr/local/nginx/conf/nginx.conf <<END

#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm index.php;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        
        location ~ \.php$ {
            try_files $uri =404;
            root           html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}
END
cd /usr/local/nginx/html
wget https://gist.githubusercontent.com/ck-on/67ca91f0310a695ceb65/raw/c0d9a376680ba5dc83e8f10475293f4042bda8a7/hhvminfo.php
nginx
echo You need to edit nginx.conf worker_processes as your server core number. And do "nginx -t reload" to reload conf file. 
echo You also need to do db secure installation. 
mysql_secure_installation
echo You can test webserver by accessing http://localhost If you want to access your webserver, please open 80port on iptables. 
echo you can get more information about this server, please watch hhvm info by accessing http://localhost/hhvminfo.php And, you must remove after read about it. 
