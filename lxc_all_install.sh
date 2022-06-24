#!/bin/bash

USER=ubuntu
VE=$1
FOLDER=$1
DB=$1
PASSWORD=$(head /dev/urandom|tr -dc "a-zA-Z0-9"|fold -w 10|head -n 1)

## Set timezone, upgrade packages and install new packages ##
lxc exec $VE -- timedatectl set-timezone Europe/Paris
lxc exec $VE -- apt-get update
lxc exec $VE -- apt-get upgrade -y
lxc exec $VE -- apt-get install -y nginx mariadb-server mariadb-client php7.4-fpm
lxc exec $VE -- apt-get install -y php7.4-mysql php7.4-curl php7.4-dom php7.4-gd php7.4-intl php7.4-ldap php7.4-mbstring php7.4-xml php7.4-zip

## Setup nginx and PHP #
lxc exec $VE -- su --login $USER -c "mkdir ~/$FOLDER"
lxc exec $VE -- su --login $USER -c "echo '<?php echo \"hello world !\";' > ~/$FOLDER/index.php"

lxc exec $VE -- sed -i -E "s/root \/var\/www\/html/root \/home\/$USER\/$FOLDER/g" /etc/nginx/sites-available/default
lxc exec $VE -- sed -i 's/index index.html index.htm index.nginx-debian.html;/index index.php index.html index.htm index.nginx-debian.html;/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#location(.*)php/location\1php/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#(.*)include snippets\/fastcgi-php/\1include snippets\/fastcgi-php/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i -E 's/#(.*)fastcgi_pass unix/\1fastcgi_pass unix/g' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i '0,/#\}/{s/#\}/\}/}' /etc/nginx/sites-available/default
lxc exec $VE -- sed -i "s/user = www-data/user = $USER/g" /etc/php/7.4/fpm/pool.d/www.conf
lxc exec $VE -- sed -i "s/listen.owner = www-data/listen.owner = $USER/g" /etc/php/7.4/fpm/pool.d/www.conf

lxc exec $VE -- systemctl restart php7.4-fpm
lxc exec $VE -- systemctl restart nginx

## DATABASE ##
lxc exec $VE -- mysql -e "CREATE DATABASE $DB CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
lxc exec $VE -- systemctl restart mysql
lxc exec $VE -- mysql -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
lxc exec $VE -- su --login $USER -c "echo '[client]' > ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'user = $USER' >> ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'password = $PASSWORD' >> ~/.my.cnf"
lxc exec $VE -- su --login $USER -c "echo 'database = $DB' >> ~/.my.cnf"
