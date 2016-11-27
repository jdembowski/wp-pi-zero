#
# Start with a fresh Raspbian Jessie Lite installation
# from https://www.raspberrypi.org/downloads/raspbian/
#

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y install vim
sudo apt-get -y install subversion
sudo apt-get -y install git
sudo apt-get -y install sendmail-bin
sudo apt-get -y install telnet
sudo apt-get -y install dnsutils
sudo apt-get -y install tcpdump

#
# Password for mariadb root user is "root" until I learn how to make it headless
#

sudo apt-get -y install mariadb-server
sudo apt-get -y install apache2
sudo apt-get -y install libapache2-mod-php5
sudo apt-get -y install php5-mysql
sudo apt-get -y install php5-imagick
sudo apt-get -y install php5-gd

cat <<EOL >~/wordpress.local.conf
<VirtualHost *:80>
    ServerName wordpress.local

    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/vhosts/wordpress.local

    <Directory /var/www/vhosts/wordpress.local>
        Options -Indexes
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOL

sudo mv ~/wordpress.local.conf /etc/apache2/sites-available/
sudo chown root:root /etc/apache2/sites-available/wordpress.local.conf
sudo a2ensite wordpress.local
sudo a2enmod rewrite

# Install phpmyadmin. The application password is "raspberry"
sudo apt-get -y install phpmyadmin
cd /etc/apache2/conf-enabled
sudo ln -s ../../phpmyadmin/apache.conf .

# Restart apache after all that
sudo service apache2 restart
sudo systemctl daemon-reload

#
# Install wp-cli
#

cd /usr/local/bin/
sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo mv wp-cli.phar wp
sudo chmod +x wp

# Now to install http://wordpress.local/
# Create the directory and fix the ownership

sudo mkdir -p /var/www/vhosts/wordpress.local
sudo chown www-data:www-data /var/www/vhosts/wordpress.local
cd /var/www/vhosts/wordpress.local

# Create the empty DB that WordPress will use

mysql -u root -proot << EOL
create database wordpresspi;
grant all privileges on wordpresspi.* to  "pi"@"localhost" identified by "raspberry";
flush privileges;
EOL

# Download and configure WordPress
sudo -u www-data wp core download

sudo -u www-data wp core config --dbname=wordpresspi \
--dbuser=pi \
--dbpass=raspberry \
--extra-php << EOL
define( 'WP_DEBUG', false );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
EOL

sudo -u www-data wp core install --admin_user=pi \
--admin_password=raspberry \
--admin_email=wordpress@wordpress.local \
--url=wordpress.local \
--title="WordPress Pi"

# Set up some options
sudo -u www-data wp option update blogdescription \
"WordPress Pi Zero Installation"
sudo -u www-data wp option update comment_moderation 1
sudo -u www-data wp option update comments_notify 0
sudo -u www-data wp option update moderation_notify 0
sudo -u www-data wp option update comment_whitelist 0
sudo -u www-data wp user update 1 --first_name="Pi" \
--last_name="Zero" \
--display_name="Pi Zero"

# Update plugins and themes if need be.
sudo -u www-data wp plugin update --all
sudo -u www-data wp theme update --all

# Delete default post and page
sudo -u www-data wp post delete 1 --force
sudo -u www-data wp post delete 2 --force

# Download and import the theme unit test WXR which will need a plugin
sudo -u www-data wp plugin install wordpress-importer --activate
sudo -u www-data curl -O https://wpcom-themes.svn.automattic.com/demo/theme-unit-test-data.xml
sudo -u www-data wp import theme-unit-test-data.xml --authors=create

# Remove the importer plugin and delete the WXR file
sudo -u www-data wp plugin deactivate wordpress-importer
sudo -u www-data wp plugin delete wordpress-importer
sudo -u www-data rm theme-unit-test-data.xml

# Change the host name from raspberrry to wordpress and reboot
sudo sed -i 's/raspberrypi/wordpress/g' /etc/hostname
sudo sed -i 's/raspberrypi/wordpress/g' /etc/hosts

echo "Installation script completed, rebooting"
sudo reboot
