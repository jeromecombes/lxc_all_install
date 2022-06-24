#!/bin/bash

USER=ubuntu
VE=$1
FOLDER=$1

lxc exec $VE -- timedatectl set-timezone Europe/Paris
#lxc exec $VE -- useradd -m -s /bin/bash $USER
lxc exec $VE -- apt-get update
lxc exec $VE -- apt-get upgrade -y
lxc exec $VE -- apt-get install -y nginx mariadb-server mariadb-client php7.4-fpm
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
