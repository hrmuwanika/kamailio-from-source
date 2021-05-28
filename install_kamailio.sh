#!/bin/bash
#
# Kamailio installation on Debian Buster
#
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

#----------------------------------------------------
# Firewall rules
#----------------------------------------------------
sudo apt install  -y iptables-dev iptables-persistent
wget https://raw.githubusercontent.com/hrmuwanika/kamailio-from-source/master/iptables.sh
chmod +x iptables.sh
./iptables.sh

#--------------------------------------------------
# Install dependencies
#--------------------------------------------------
echo -e "\n============= Install dependencies ================"
sudo apt install -y mariadb-server

sudo systemctl enable mariadb
sudo systemctl start mariadb

mysql_secure_installation

sudo apt install -y tcpdump screen ntp ntpdate git dkms gcc g++ autoconf pkg-config flex bison default-libmysqlclient-dev \
libcurl4-openssl-dev libxml2-dev libpcre3-dev bash-completion libmnl-dev libsctp-dev libradcli-dev libssl-dev make \
libradcli4 libncurses5-dev unixodbc-dev vim iptables-dev libunistring-dev htop libmariadb-dev libmariadb-dev-compat

echo "set mouse-=a" >> ~/.vimrc

#-----------------------------------------------
# Download Kamailio from source
#-----------------------------------------------
cd /usr/local/src/
sudo mkdir –p kamailio-5.5
cd kamailio-5.5
git clone --depth 1 --no-single-branch https://github.com/kamailio/kamailio kamailio
cd kamailio
git checkout -b 5.5 origin/5.5

make include_modules="db_mysql dialplan debugger permissions usrloc dispatcher registrar sdpops presence auth auth_db avp tm \
presence_mwi outbound sl maxfwd xhttp db_text  textops siputils uac presence_dialoginfo kex uac_redirect xlog siptrace sanity \
htable rr pv path tls ctl dmq dialog pua_dialoginfo avpops pua textopsx tmx presence_xml" cfg

make all
make install
ldconfig

sed -i 's/# SIP_DOMAIN=kamailio.org/SIP_DOMAIN=example.com/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBENGINE=MYSQL/DBENGINE=MYSQL/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBHOST=localhost/DBHOST=localhost/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBNAME=kamailio/DBNAME=kamailio/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBRWUSER="kamailio"/DBRWUSER="kamailio"/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBRWPW="kamailiorw"/DBRWPW="WCo9qU<$3$UPMXT"/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/# DBROPW="kamailioro"/DBROPW="Jc[=z5+EN2'f{dK"/g' /usr/local/etc/kamailio/kamctlrc
sed -i 's/#CHARSET="latin1"/CHARSET="latin1"/g' /usr/local/etc/kamailio/kamctlrc

sudo /usr/local/sbin/kamdbctl create

sed -i -e '2i#!define WITH_MYSQL\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '3i#!define WITH_AUTH\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '4i#!define WITH_IPAUTH\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '5i#!define WITH_USRLOCDB\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '6i#!define WITH_MULTIDOMAIN\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '7i#!define WITH_NAT\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '8i#!define WITH_RTPENGINE\' /usr/local/etc/kamailio/kamailio.cfg
sed -i -e '9i#!define WITH_ANTIFLOOD\' /usr/local/etc/kamailio/kamailio.cfg

make install-systemd-debian
sudo systemctl daemon-reload
sudo systemctl start kamailio
sudo systemctl stop kamailio
sudo systemctl enable kamailio

#----------------------------------------------------
# Siremis installation
#----------------------------------------------------
sudo apt install -y apache2 apache2-utils 
sudo systemctl enable apache2

sudo apt install -y php php-mysql php-gd php-curl php-xml php-xmlrpc php-pear libapache2-mod-php unzip wget

sudo a2enmod rewrite 
sudo systemctl restart apache2

sudo sed -i s/"memory_limit = 128M"/"memory_limit = 512M"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/";date.timezone =/date.timezone = Africa\/Kigali"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/"upload_max_filesize = 2M"/"upload_max_filesize = 150M"/g /etc/php/7.3/apache2/php.ini
sudo sed -i s/"max_execution_time = 30"/"max_execution_time = 360"/g /etc/php/7.3/apache2/php.ini

cd /usr/src
wget http://pear.php.net/get/XML_RPC-1.5.5.tgz
pear upgrade XML_RPC-1.5.5.tgz
sudo systemctl restart apache2 

#----------------------------------------------------
# Download Siremis
#----------------------------------------------------
cd /var/www
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

mysql -u root -p --execute="GRANT ALL PRIVILEGES ON siremis.* TO siremis@localhost IDENTIFIED BY 'WCo9qU</3$UPMXT'; FLUSH PRIVILEGES;"

#------------------------------------------------------
# Install Letsencrypt
#------------------------------------------------------
sudo apt install snapd -y
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --apache -d vps.rw 

echo -e "Access siremis on http://ipaddress/siremis/install"
