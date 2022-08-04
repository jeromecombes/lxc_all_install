#!/bin/bash

PHPVERSION=8.1
USER=ubuntu
VE=$1
FOLDER=$1
DB=$(echo $1 | sed 's/-/_/g')
PASSWORD=$(head /dev/urandom|tr -dc "a-zA-Z0-9"|fold -w 10|head -n 1)

## OS ##
OS=unknown
TEST=$(lxc exec $VE -- lsb_release -c)
if [[ $(echo $TEST | grep 'jammy') ]]; then OS=jammy; fi

## Set timezone, upgrade packages and install new packages ##

lxc exec $VE -- timedatectl set-timezone Europe/Paris

if [[ ! $OS = jammy && ! $PHPVERSION = 7.4 ]] || [[ $OS = jammy && ! $PHPVERSION = 8.1 ]]; then
	lxc exec $VE -- add-apt-repository -y ppa:ondrej/php
fi

lxc exec $VE -- apt-get update
lxc exec $VE -- DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
lxc exec $VE -- apt-get install -y nginx mariadb-server mariadb-client php$PHPVERSION-fpm unzip
lxc exec $VE -- apt-get install -y php$PHPVERSION-mysql php$PHPVERSION-curl php$PHPVERSION-dom php$PHPVERSION-gd php$PHPVERSION-intl php$PHPVERSION-ldap php$PHPVERSION-mbstring php$PHPVERSION-xml php$PHPVERSION-zip

## Setup nginx and PHP ##
lxc exec $VE -- su --login $USER -c "mkdir -p ~/$FOLDER/public"
lxc exec $VE -- su --login $USER -c "echo '<?php phpinfo();' > ~/$FOLDER/public/index.php"

lxc exec $VE -- sed -i -E "s/root \/var\/www\/html/root \/home\/$USER\/$FOLDER\/public/g" /etc/nginx/sites-available/default
lxc exec $VE -- sed -i 's/index index.html index.htm index.nginx-debian.html;/index index.php index.html index.htm index.nginx-debian.html;/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#location(.*)php/location\1php/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#(.*)include snippets\/fastcgi-php/\1include snippets\/fastcgi-php/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#(.*)fastcgi_pass unix/\1fastcgi_pass unix/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i '0,/#\}/{s/#\}/\}/}' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E "s/^(.*)\/run\/php\/php(.*)-fpm.sock;/\1\/run\/php\/php$PHPVERSION-fpm.sock;/g" /etc/nginx/sites-available/default
lxc exec $VE -- sed -i 's/try_files $uri $uri\/ =404;/try_files $uri $uri\/ \/index.php$is_args$args;/g' /etc/nginx/sites-available/default

lxc exec $VE -- sed -i "s/user = www-data/user = $USER/g" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
lxc exec $VE -- sed -i "s/listen.owner = www-data/listen.owner = $USER/g" /etc/php/$PHPVERSION/fpm/pool.d/www.conf

lxc exec $VE -- chmod o+x /home/$USER

lxc exec $VE -- systemctl restart php$PHPVERSION-fpm
lxc exec $VE -- systemctl restart nginx

## DATABASE ##
lxc exec $VE -- mysql -e "CREATE DATABASE $DB CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
lxc exec $VE -- systemctl restart mysql
lxc exec $VE -- mysql -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
lxc exec $VE -- su --login $USER -c "echo '[client]' > ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'user = $USER' >> ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'password = $PASSWORD' >> ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'database = $DB' >> ~/.my.cnf"

## COMPOSER ##
lxc exec $VE -- php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
lxc exec $VE -- php composer-setup.php --install-dir=/usr/local/bin --filename=composer
lxc exec $VE -- php -r "unlink('composer-setup.php');"

## GIT ##
lxc file push data/.gitconfig $VE/home/$USER/.gitconfig
lxc file push data/.gitconfig $VE/root/.gitconfig
lxc exec $VE -- chown root: /root/.gitconfig
