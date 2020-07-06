#!/bin/bash

#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n============= Update Server ================"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

#--------------------------------------------------
# Install dependencies
#--------------------------------------------------
echo -e "\n============= Install dependencies ================"
sudo apt install -y mariadb-server mariadb-client

sudo systemctl enable mariadb
sudo systemctl start mariadb

mysql_secure_installation

sudo apt install -y git gcc g++ flex bison default-libmysqlclient-dev make autoconf libssl-dev libcurl4-openssl-dev \
libncurses5-dev libxml2-dev libpcre3-dev unixodbc-dev vim iptables-dev libunistring-dev htop dkms autoconf libmnl-dev \
libsctp-dev libradcli-dev tcpdump screen ntp ntpdate

echo "set mouse-=a" >> ~/.vimrc

#-----------------------------------------------
# Download Kamailio from source
#-----------------------------------------------
cd /usr/local/src/
sudo mkdir –p kamailio-5.3
cd kamailio-5.3
sudo git clone --depth 1 --no-single-branch https://github.com/kamailio/kamailio kamailio
cd kamailio
git checkout -b 5.3 origin/5.3

make include_modules="db_mysql dialplan debugger permissions usrloc dispatcher registrar sdpops presence auth auth_db avp tm \
presence_mwi outbound sl maxfwd xhttp db_text  textops siputils uac presence_dialoginfo kex uac_redirect xlog siptrace sanity \
htable rr pv path tls ctl dmq dialog pua_dialoginfo avpops pua textopsx tmx presence_xml" cfg

make all
make install
ldconfig

sed -i 's/# SIP_DOMAIN=kamailio.org/SIP_DOMAIN=vps.rw/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBENGINE=MYSQL/DBENGINE=MYSQL/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBHOST=localhost/DBHOST=localhost/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBNAME=kamailio/DBNAME=kamailio/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBRWUSER="kamailio"/DBRWUSER="kamailio"/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBRWPW="kamailiorw"/DBRWPW="8)Le5~#C"/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/#CHARSET="latin1"/CHARSET="latin1"/g' /usr/local/etc/kamailio/kamctlrc

sudo /usr/local/sbin/kamdbctl create

sed -i -e '2i#!define WITH_MYSQL\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '3i#!define WITH_AUTH\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '4i#!define WITH_USRLOCDB\' /usr/local/etc/kamailio/kamailio.cfg

make install-systemd-debian
systemctl enable kamailio
systemctl start kamailio
systemctl status kamailio

#----------------------------------------------------
# Siremis installation
#----------------------------------------------------
sudo apt install -y apache2 apache2-utils php php-mysql php-gd php-curl php-xml php-xmlrpc \
php-pear libapache2-mod-php unzip wget

sudo systemctl enable apache2 
sudo systemctl start apache2

sudo a2enmod rewrite
sudo systemctl restart apache2

sudo sed -i s/"memory_limit = 128M"/"memory_limit = 512M"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/";date.timezone =/date.timezone = Africa\/Kigali"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/"upload_max_filesize = 2M"/"upload_max_filesize = 150M"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/"max_execution_time = 30"/"max_execution_time = 360"/g /etc/php/7.3/apache2/php.ini

cd /usr/src
sudo pear install XML_RPC2
wget http://pear.php.net/get/XML_RPC-1.5.5.tgz
pear upgrade XML_RPC-1.5.5.tgz

#----------------------------------------------------
# Download Siremis
#----------------------------------------------------
cd /var/www/html/
git clone https://github.com/asipto/siremis siremis-5.3.0
cd siremis-5.3.0
git checkout -b 5.3 origin/5.3

cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/siremis.conf
make apache24-conf >> /etc/apache2/sites-available/siremis.conf
make prepare24
make chown

a2ensite siremis
a2dissite 000-default

systemctl reload apache2

mysql -u root -p
use kamailio;
GRANT ALL PRIVILEGES ON siremis.* TO siremis@localhost IDENTIFIED BY '8)Le5~#C';
FLUSH PRIVILEGES;
EXIT; 

echo "Access siremis on http://ipaddress/siremis/install"
