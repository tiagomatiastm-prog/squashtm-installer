#!/bin/bash

#################################################
# Script d'installation de SquashTM Community  #
# Pour Debian 13                                #
# Auteur: Tiago                                 #
# Date: $(date +%Y-%m-%d)                       #
#################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
SQUASHTM_VERSION="11.0.4.RELEASE"
SQUASHTM_URL="https://nexus.squashtest.org/nexus/repository/public-releases/tm/core/squash-tm-distribution/11.0.4.RELEASE/squash-tm-11.0.4.RELEASE.tar.gz"
INSTALL_DIR="/opt/squash-tm"
DB_NAME="squashtm"
DB_USER="squashtm"
DB_PASSWORD=$(openssl rand -base64 24)
CRYPTO_SECRET=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)
ADMIN_EMAIL="admin@squashtm.local"

# Fonction de log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le script est exécuté en root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

log_info "========================================"
log_info "Installation de SquashTM Community ${SQUASHTM_VERSION}"
log_info "========================================"

# Étape 1: Mise à jour du système
log_info "Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Étape 2: Installation des dépendances
log_info "Installation des dépendances..."
apt-get install -y \
    wget \
    curl \
    gnupg2 \
    openjdk-21-jre-headless \
    mariadb-server \
    netcat-openbsd \
    unzip

# Étape 3: Configuration de MariaDB
log_info "Configuration de MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Sécurisation basique de MariaDB
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Création de la base de données et de l'utilisateur
log_info "Création de la base de données SquashTM..."
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Étape 4: Téléchargement de SquashTM
log_info "Téléchargement de SquashTM ${SQUASHTM_VERSION}..."
cd /tmp
wget -q --show-progress "${SQUASHTM_URL}" -O squash-tm.tar.gz

if [ ! -f squash-tm.tar.gz ]; then
    log_error "Échec du téléchargement de SquashTM"
    exit 1
fi

# Étape 5: Extraction et installation
log_info "Extraction de SquashTM..."
tar -zxf squash-tm.tar.gz -C /opt/
# Le tarball s'extrait directement dans /opt/squash-tm

# Étape 6: Création de l'utilisateur système
log_info "Création de l'utilisateur système squash-tm..."
if ! id -u squash-tm > /dev/null 2>&1; then
    adduser --system --group --home ${INSTALL_DIR} --no-create-home squash-tm
fi

# Étape 7: Configuration de SquashTM
# Note: La base de données sera initialisée automatiquement par Liquibase au premier démarrage
log_info "Configuration de SquashTM..."

# Configuration du fichier startup.sh
cat > ${INSTALL_DIR}/bin/startup.sh << 'EOFSTARTUP'
#!/bin/bash

SQUASH_TM_HOME="/opt/squash-tm"

# Spring Boot datasource configuration (SquashTM 11.x uses Spring Boot variables)
export SPRING_DATASOURCE_URL="jdbc:mariadb://localhost:3306/squashtm?useUnicode=true&characterEncoding=UTF-8"
export SPRING_DATASOURCE_USERNAME="squashtm"
export SPRING_DATASOURCE_PASSWORD="DB_PASSWORD_PLACEHOLDER"

# JOOQ SQL dialect (required for database query generation)
export SPRING_JOOQ_SQL_DIALECT="MARIADB"

# Default variables
JAR_NAME="${SQUASH_TM_HOME}/bundles/squash-tm.war"
TMP_DIR="${SQUASH_TM_HOME}/tmp"
CONF_DIR="${SQUASH_TM_HOME}/conf"
LOG_DIR="${SQUASH_TM_HOME}/logs"

# Create directories if needed
mkdir -p "${TMP_DIR}"
mkdir -p "${LOG_DIR}"

# Java args
JAVA_ARGS="-Xms512m -Xmx2048m"

ARGS="${JAVA_ARGS} -Duser.language=en -Djava.io.tmpdir=${TMP_DIR} -Dlogging.dir=${LOG_DIR} -jar ${JAR_NAME} --spring.config.additional-location=file:${CONF_DIR}/ --spring.config.name=application,squash.tm.cfg --logging.config=${CONF_DIR}/log4j2.xml"

# Clean temp files
rm -rf ${TMP_DIR}/*

# Start SquashTM
exec java ${ARGS}
EOFSTARTUP

# Replace password placeholder
sed -i "s/DB_PASSWORD_PLACEHOLDER/${DB_PASSWORD}/g" ${INSTALL_DIR}/bin/startup.sh
chmod +x ${INSTALL_DIR}/bin/startup.sh

# Étape 8: Configuration du service systemd
log_info "Configuration du service systemd..."
cat > /etc/systemd/system/squash-tm.service << EOF
[Unit]
Description=SquashTM Community Edition
After=network.target mariadb.service
Requires=mariadb.service

[Service]
Type=simple
User=squash-tm
Group=squash-tm
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/bin/startup.sh
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

# Étape 9: Permissions
log_info "Configuration des permissions..."
chown -R squash-tm:squash-tm ${INSTALL_DIR}

# Étape 10: Démarrage du service
log_info "Démarrage de SquashTM..."
systemctl daemon-reload
systemctl enable squash-tm
systemctl start squash-tm

# Attendre que le service démarre
log_info "Attente du démarrage de SquashTM (cela peut prendre 2-3 minutes)..."
log_info "Vous pouvez suivre les logs avec: sudo journalctl -u squash-tm -f"

# Attendre que le port 8080 soit disponible (max 3 minutes)
COUNTER=0
MAX_WAIT=180
while ! nc -z localhost 8080 2>/dev/null && [ $COUNTER -lt $MAX_WAIT ]; do
    sleep 5
    COUNTER=$((COUNTER + 5))
    if [ $((COUNTER % 30)) -eq 0 ]; then
        log_info "Toujours en attente... ($COUNTER secondes)"
    fi
done

# Vérification du statut
if systemctl is-active --quiet squash-tm && nc -z localhost 8080 2>/dev/null; then
    log_info "SquashTM démarré avec succès !"
else
    log_warn "SquashTM pourrait avoir des problèmes au démarrage."
    log_warn "Vérifiez les logs avec: sudo journalctl -u squash-tm -n 50"
fi

# Étape 11: Génération du fichier d'informations
log_info "Génération du fichier d'informations..."
REAL_USER=$(who am i | awk '{print $1}')
if [ -z "$REAL_USER" ] || [ "$REAL_USER" == "root" ]; then
    REAL_USER="root"
fi

INFO_FILE="/root/squashtm-info.txt"

cat > ${INFO_FILE} << EOF
========================================
SquashTM Community Edition - Informations
========================================

Date d'installation: $(date '+%Y-%m-%d %H:%M:%S')
Version: ${SQUASHTM_VERSION}

ACCÈS WEB
---------
URL: http://$(hostname -I | awk '{print $1}'):8080/squash
Credentials par défaut:
  - Username: admin
  - Password: admin

⚠️  IMPORTANT: Changez le mot de passe admin après la première connexion !

BASE DE DONNÉES
---------------
Type: MariaDB
Database: ${DB_NAME}
User: ${DB_USER}
Password: ${DB_PASSWORD}

SECRETS DE SÉCURITÉ
-------------------
Crypto Secret: ${CRYPTO_SECRET}
JWT Secret: ${JWT_SECRET}

CHEMINS D'INSTALLATION
----------------------
Dossier: ${INSTALL_DIR}
Service: squash-tm.service
User système: squash-tm

COMMANDES UTILES
----------------
Statut du service:
  sudo systemctl status squash-tm

Redémarrer:
  sudo systemctl restart squash-tm

Logs:
  sudo journalctl -u squash-tm -f
  tail -f ${INSTALL_DIR}/logs/squash-tm.log

Arrêter:
  sudo systemctl stop squash-tm

DOCUMENTATION
-------------
- Guide utilisateur: https://tm-en.doc.squashtest.com/v9/
- Forum: https://forum.squashtest.com/
- Site officiel: https://www.squashtm.com/

========================================
EOF

chmod 600 ${INFO_FILE}

# Afficher le résumé
log_info "========================================"
log_info "Installation terminée avec succès !"
log_info "========================================"
echo ""
cat ${INFO_FILE}
echo ""
log_info "Les informations de connexion ont été sauvegardées dans: ${INFO_FILE}"
log_info "Accédez à SquashTM: http://$(hostname -I | awk '{print $1}'):8080/squash"
log_info "Credentials: admin / admin"
log_warn "N'oubliez pas de changer le mot de passe admin !"
