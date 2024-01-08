#!/bin/bash

# Actualizar el sistema
sudo apt update
sudo apt upgrade -y

# Instalar Apache2
sudo apt install apache2 -y

# Instalar PHP y sus módulos
sudo apt install php libapache2-mod-php php-mysql -y

# Instalar MariaDB y configurar una contraseña para el usuario root
sudo apt install mariadb-server -y
sudo mysql_secure_installation

# Instalar phpMyAdmin y configurar el acceso
sudo apt install phpmyadmin -y

# Reiniciar Apache2 para aplicar los cambios
sudo systemctl restart apache2

# Descargamos la última versión de WordPress
wget http://wordpress.org/latest.tar.gz -P /tmp

# Descomprimimos el archivo descargado
tar -xzvf /tmp/latest.tar.gz -C /tmp

# Movemos los archivos a la ruta deseada
sudo mv -f /tmp/wordpress/* /var/www/html

# Creamos la base de datos y el usuario
mysql -u root <<< "DROP DATABASE IF EXISTS $WORDPRESS_DB_NAME"
mysql -u root <<< "CREATE DATABASE $WORDPRESS_DB_NAME"
mysql -u root <<< "DROP USER IF EXISTS $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL"
mysql -u root <<< "CREATE USER $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'"
mysql -u root <<< "GRANT ALL PRIVILEGES ON $WORDPRESS_DB_NAME.* TO $WORDPRESS_DB_USER@$IP_CLIENTE_MYSQL"

# Creamos un archivo de configuración
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
