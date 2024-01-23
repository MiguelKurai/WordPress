#!/bin/bash

clear

# Introducir los valores del usuario
read -p "Introduzca el nombre para la base de datos de WordPress: " WORDPRESS_DB_NAME
WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}

read -p "Introduzca el nombre de usuario para la base de datos: " WORDPRESS_DB_USER
WORDPRESS_DB_USER=${WORDPRESS_DB_USER}

read -p "Introduzca la contraseña para la base de datos: " WORDPRESS_DB_PASSWORD
WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}

read -p "Introduzca la dirección IP del cliente MySQL: " IP_CLIENTE_MYSQL
IP_CLIENTE_MYSQL=${IP_CLIENTE_MYSQL}

read -p "Introduzca el dominio del certificado (predeterminado: ${CERTIFICATE_DOMAIN}): " user_input
CERTIFICATE_DOMAIN=${user_input:-${CERTIFICATE_DOMAIN}}

# Establecer DEBIAN_FRONTEND para evitar interacciones
export DEBIAN_FRONTEND=noninteractive

# Actualizamos el sistema
sudo apt update
sudo apt upgrade -y

# Instalamos Apache2
sudo apt install apache2 -y

# Instalamos PHP y los módulos necesarios
sudo apt install php libapache2-mod-php php-mysql -y

# Instalamos MariaDB y configuramos una contraseña para el usuario root de MySQL
sudo apt install mariadb-server -y

# Instalamos phpMyAdmin y configuramos el acceso
sudo apt install phpmyadmin -y

# Instalamos Crontab
sudo apt install crontab

# Habilitamos el módulo PHP en Apache2
sudo a2enmod php

# Habilitamos las extensiones PHP necesarias para phpMyAdmin
sudo phpenmod mbstring
sudo phpenmod zip

# instalamos Adminer
sudo apt install adminer -y

# Instalamos goaccess
sudo apt install goaccess -y

#activamos ssl
sudo a2enmod ssl
sudo a2ensite default-ssl.conf

# Añadirmos la configuración a 000-default.conf
echo '
<Directory />
    Options FollowSymLinks
    AllowOverride All
    Require all denied
</Directory>

<Directory /usr/share>
    AllowOverride All
    Require all granted
</Directory>

<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>' | sudo tee -a /etc/apache2/sites-available/000-default.conf > /dev/null

# Añadirmos la configuración a default-ssl.conf
echo '
<Directory />
    Options FollowSymLinks
    AllowOverride All
    Require all denied
</Directory>

<Directory /usr/share>
    AllowOverride All
    Require all granted
</Directory>

<Directory /var/www/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>' | sudo tee -a /etc/apache2/sites-available/default-ssl.conf > /dev/null

# Reiniciamos el servicio apache2
sudo systemctl restart apache2.service

# Descargarmos e instalar WordPress
sudo wget http://wordpress.org/latest.tar.gz -P /tmp
if [ ! -e /tmp/latest.tar.gz ]; then
    echo "Error: Fallo al descargar WordPress."
    exit 1
fi

sudo tar -xzvf /tmp/latest.tar.gz -C /tmp

sudo mv -f /tmp/wordpress /var/www/html

# Eliminarmos el archivo index.html
sudo rm -f /var/www/html/index.html

# Crearmos el archivo .env
sudo cat <<EOF > .env
WORDPRESS_DB_NAME=$WORDPRESS_DB_NAME
WORDPRESS_DB_USER=$WORDPRESS_DB_USER
WORDPRESS_DB_PASSWORD=$WORDPRESS_DB_PASSWORD
IP_CLIENTE_MYSQL=$IP_CLIENTE_MYSQL
CERTIFICATE_DOMAIN=$CERTIFICATE_DOMAIN
EOF

# Cargarmos las variables desde el archivo config.env
source .env

# Creammos la base de datos y el usuario en MySQL
sudo mysql -u root <<< "DROP DATABASE IF EXISTS $WORDPRESS_DB_NAME"
sudo mysql -u root <<< "CREATE DATABASE $WORDPRESS_DB_NAME"
sudo mysql -u root <<< "DROP USER IF EXISTS $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL"
sudo mysql -u root <<< "CREATE USER $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'"
sudo mysql -u root <<< "GRANT ALL PRIVILEGES ON $WORDPRESS_DB_NAME.* TO $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL"


# Copiamos el archivo de configuración de WordPress
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php

# Editamos el archivo de configuración con las variables
sudo sed -i "s/database_name_here/$WORDPRESS_DB_NAME/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/username_here/$WORDPRESS_DB_USER/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/localhost/$IP_CLIENTE_MYSQL/" /var/www/html/wordpress/wp-config.php

# Configuramos las URLs de WordPress
sudo sed -i "/DB_COLLATE/a define('WP_SITEURL', 'https://$CERTIFICATE_DOMAIN');" /var/www/html/wordpress/wp-config.php
sudo sed -i "/WP_SITEURL/a define('WP_HOME', 'https://$CERTIFICATE_DOMAIN');" /var/www/html/wordpress/wp-config.php

cp /var/www/html/wordpress/index.php /var/www/html

# Configuramos las rutas en el archivo index.php
sudo sed -i "s#wp-blog-header.php#wordpress/wp-blog-header.php#" /var/www/html/index.php

# Creamos el archivo .htaccess
sudo cat <<EOL > /var/www/html/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOL

# Obtienemos la ruta actual del script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Nombramos el script de actualización de la IP
update_ip_script="update_ip.sh"

# Creamos el script de actualización de la IP
cat <<EOL > "$script_dir/$update_ip_script"
#!/bin/bash

# Obtener la dirección IP pública actual
nueva_ip=\$(curl -s ifconfig.me)

# Ruta al archivo de configuración de WordPress
ruta_wpconfig='$script_dir/wp-config.php'

# Actualizar las direcciones IP en el archivo
sed -i "s@define('WP_SITEURL', 'https://[0-9.]\+/wordpress');@define('WP_SITEURL', 'https://\$nueva_ip/wordpress');@" "\$ruta_wpconfig"
sed -i "s@define('WP_HOME', 'https://[0-9.]\+');@define('WP_HOME', 'https://\$nueva_ip');@" "\$ruta_wpconfig"

echo "Direcciones IP actualizadas en \$ruta_wpconfig"
EOL

# Damos permisos de ejecución al script de actualización de la IP
chmod +x "$script_dir/$update_ip_script"

# Añadimos la tarea al crontab para ejecutar el script de actualización de la IP con cada reinicio
(crontab -l 2>/dev/null; echo "@reboot $script_dir/$update_ip_script") | crontab -

# Habilitamos el módulo rewrite y reiniciamos el servicio Apache
sudo a2enmod rewrite
if [ $? -ne 0 ]; then
    echo "Error: Fallo al habilitar el módulo rewrite."
        exit 1
fi

sudo systemctl restart apache2
if [ $? -ne 0 ]; then
    echo "Error: Fallo al reiniciar Apache."
    exit 1
fi

# Eliminamos las claves de seguridad del archivo wp-config.php
sudo sed -i "/AUTH_KEY/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/SECURE_AUTH_KEY/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/LOGGED_IN_KEY/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/NONCE_KEY/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/AUTH_SALT/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/SECURE_AUTH_SALT/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/LOGGED_IN_SALT/d" /var/www/html/wordpress/wp-config.php
sudo sed -i "/NONCE_SALT/d" /var/www/html/wordpress/wp-config.php

# Obtenemos las nuevas claves de seguridad y las agregamos al archivo wp-config.php
SECURITY_KEYS=$(curl https://api.wordpress.org/secret-key/1.1/salt/)
SECURITY_KEYS=$(echo $SECURITY_KEYS | tr / _)
sudo sed -i "/@-/a $SECURITY_KEYS" /var/www/html/wordpress/wp-config.php

# Cambiamos la propiedad del directorio de WordPress
sudo chown -R www-data:www-data /var/www/html/
if [ $? -ne 0 ]; then
    echo "Error: Fallo al cambiar la propiedad del directorio de WordPress."
    exit 1
fi

echo "Instalación y configuración de WordPress completadas correctamente."
