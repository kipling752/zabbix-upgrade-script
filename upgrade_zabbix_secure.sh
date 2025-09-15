#!/bin/bash
# ===========================================
# Script de mise à jour Zabbix 7.2 → 7.4 (sécurisé)
# Pour Ubuntu 22.04 + MySQL
# ===========================================

# Variables
DB_NAME="zabbix"
BACKUP_DIR="/root"
CONF_DIRS="/etc/zabbix /usr/share/zabbix"
MYSQL_CNF="/root/.my.cnf"

# Demande du mot de passe root MySQL
read -s -p "Entrez le mot de passe root MySQL : " MYSQL_ROOT_PASS
echo

# Créer un fichier temporaire de configuration MySQL sécurisé
cat > $MYSQL_CNF <<EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 $MYSQL_CNF

# 1️⃣ Sauvegarde de la base MySQL
echo "[1/6] Sauvegarde de la base MySQL..."
mysqldump --defaults-extra-file=$MYSQL_CNF $DB_NAME > $BACKUP_DIR/zabbix_backup.sql
if [ $? -ne 0 ]; then
    echo "Erreur : La sauvegarde de la base a échoué."
    rm -f $MYSQL_CNF
    exit 1
fi
echo "Sauvegarde MySQL terminée : $BACKUP_DIR/zabbix_backup.sql"

# 2️⃣ Sauvegarde des fichiers de configuration
echo "[2/6] Sauvegarde des fichiers de configuration..."
tar -czvf $BACKUP_DIR/zabbix_conf_backup.tar.gz $CONF_DIRS
echo "Sauvegarde des configs terminée : $BACKUP_DIR/zabbix_conf_backup.tar.gz"

# 3️⃣ Mise à jour du dépôt Zabbix
echo "[3/6] Mise à jour du dépôt Zabbix 7.4..."
wget -O /tmp/zabbix-release_latest_7.4+ubuntu22.04_all.deb https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu22.04_all.deb
dpkg -i /tmp/zabbix-release_latest_7.4+ubuntu22.04_all.deb
apt update

# 4️⃣ Mise à jour des paquets Zabbix
echo "[4/6] Mise à jour des paquets Zabbix..."
apt install --only-upgrade -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# 5️⃣ Mise à jour de la base de données
echo "[5/6] Mise à jour de la base MySQL vers 7.4..."
zcat /usr/share/zabbix/sql-scripts/mysql/upgrade.sql.gz | mysql --defaults-extra-file=$MYSQL_CNF $DB_NAME
if [ $? -ne 0 ]; then
    echo "Erreur : La mise à jour de la base a échoué."
    rm -f $MYSQL_CNF
    exit 1
fi
echo "Mise à jour de la base terminée."

# 6️⃣ Redémarrage des services Zabbix
echo "[6/6] Redémarrage des services Zabbix..."
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
echo "Migration vers Zabbix 7.4 terminée ✅"

# Supprimer le fichier temporaire contenant le mot de passe
rm -f $MYSQL_CNF

# Fin
echo "Vérifiez l'interface web et la version du serveur : zabbix_server -V"
