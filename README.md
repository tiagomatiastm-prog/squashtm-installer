# SquashTM Community - Installeur automatique pour Debian

Installation automatisée de **SquashTM Community Edition** sur Debian 13.

## Description

SquashTM est une solution open source de gestion des tests logiciels. Cette solution permet de :
- Gérer les exigences et les tests
- Organiser des campagnes de tests
- Tracer la couverture des exigences
- Générer des rapports et des statistiques

Ce projet fournit deux méthodes d'installation :
1. **Script Bash** : Installation rapide en une ligne
2. **Playbook Ansible** : Déploiement automatisé sur plusieurs serveurs

## Prérequis

### Système
- **OS** : Debian 13 (ou Debian 12, Ubuntu 22.04+)
- **RAM** : 2 GB minimum (recommandé pour production)
- **CPU** : 2 cores (recommandé)
- **Disque** : 5 GB d'espace libre
- **Réseau** : Accès Internet pour télécharger les packages

### Logiciels installés automatiquement
- Java 21 (OpenJDK)
- MariaDB 10.6+
- SquashTM 11.0.4

## Installation rapide (Script Bash)

### Méthode 1 : Installation directe via curl

```bash
curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/squashtm-installer/master/install-squashtm.sh | sudo bash
```

### Méthode 2 : Téléchargement puis exécution

```bash
wget https://raw.githubusercontent.com/tiagomatiastm-prog/squashtm-installer/master/install-squashtm.sh
chmod +x install-squashtm.sh
sudo ./install-squashtm.sh
```

## Déploiement Ansible

Pour déployer SquashTM sur plusieurs serveurs ou de manière automatisée, consultez le fichier [DEPLOYMENT.md](DEPLOYMENT.md).

## Accès à l'interface

Après l'installation :

**⏱️ Temps de démarrage** : Le premier démarrage de SquashTM peut prendre 2 à 3 minutes. Vous pouvez suivre les logs avec :
```bash
sudo journalctl -u squash-tm -f
```

**URL** : `http://<IP_SERVEUR>:8080/squash`

**Credentials par défaut** :
- Username : `admin`
- Password : `admin`

**⚠️ IMPORTANT** : Changez le mot de passe administrateur dès la première connexion !

## Informations de connexion

Toutes les informations (mots de passe, secrets, etc.) sont sauvegardées dans :
```
/root/squashtm-info.txt
```

Ce fichier contient :
- URL d'accès
- Credentials par défaut
- Identifiants de la base de données
- Secrets de sécurité (crypto et JWT)
- Commandes utiles

## Gestion du service

```bash
# Statut du service
sudo systemctl status squash-tm

# Démarrer
sudo systemctl start squash-tm

# Arrêter
sudo systemctl stop squash-tm

# Redémarrer
sudo systemctl restart squash-tm

# Voir les logs
sudo journalctl -u squash-tm -f
tail -f /opt/squash-tm/logs/squash-tm.log
```

## Architecture

```
/opt/squash-tm/                 # Dossier d'installation
├── bin/                        # Scripts de démarrage
│   └── startup.sh             # Script de démarrage personnalisé
├── bundles/                    # Application WAR
│   └── squash-tm.war          # Application principale (214 MB)
├── conf/                       # Configuration
├── database-scripts/           # Scripts SQL d'initialisation
├── logs/                       # Fichiers de logs
├── plugin-files/               # Plugins (LDAP, OpenID, etc.)
├── plugins/                    # Dossier pour plugins personnalisés
└── tmp/                        # Fichiers temporaires

/etc/systemd/system/
└── squash-tm.service          # Service systemd
```

## Base de données

- **Type** : MariaDB
- **Nom de la base** : `squashtm`
- **Utilisateur** : `squashtm`
- **Mot de passe** : Généré automatiquement (voir `/root/squashtm-info.txt`)

## Sécurité

Le script génère automatiquement :
- Un mot de passe sécurisé pour la base de données
- Un secret de chiffrement (`SQUASH_CRYPTO_SECRET`)
- Un secret JWT pour l'API REST (`SQUASH_REST_API_JWT_SECRET`)

Ces secrets sont nécessaires pour :
- Chiffrer les mots de passe stockés dans SquashTM
- Générer des tokens d'authentification pour l'API REST

## Configuration Java

Par défaut, SquashTM est configuré avec :
- **Xms** : 512 MB (mémoire initiale)
- **Xmx** : 2048 MB (mémoire maximale)
- **MaxPermSize** : 256 MB

Pour modifier ces valeurs, éditez `/opt/squash-tm/bin/startup.sh` et redémarrez le service.

## Ports utilisés

- **8080** : Interface web SquashTM
- **3306** : MariaDB (localhost uniquement)

## Désinstallation

```bash
# Arrêter et désactiver le service
sudo systemctl stop squash-tm
sudo systemctl disable squash-tm

# Supprimer les fichiers
sudo rm -rf /opt/squash-tm
sudo rm /etc/systemd/system/squash-tm.service
sudo systemctl daemon-reload

# Supprimer la base de données (ATTENTION : perte de données !)
sudo mysql -e "DROP DATABASE squashtm;"
sudo mysql -e "DROP USER 'squashtm'@'localhost';"

# Supprimer l'utilisateur système
sudo userdel squash-tm
```

## Dépannage

### Le service ne démarre pas

```bash
# Vérifier les logs systemd
sudo journalctl -u squash-tm -n 50

# Vérifier les logs applicatifs
tail -100 /opt/squash-tm/logs/squash-tm.log

# Vérifier que MariaDB est démarré
sudo systemctl status mariadb
```

### Erreur de connexion à la base de données

```bash
# Vérifier les credentials dans startup.sh
sudo cat /opt/squash-tm/bin/startup.sh | grep DB_

# Tester la connexion à la base
mysql -u squashtm -p squashtm
```

### Port 8080 déjà utilisé

Si le port 8080 est déjà utilisé, vous pouvez le modifier :

1. Éditer `/opt/squash-tm/conf/squash-tm.conf`
2. Modifier la ligne `server.port=8080`
3. Redémarrer le service

## Documentation officielle

- **Guide utilisateur** : https://tm-en.doc.squashtest.com/
- **Forum** : https://forum.squashtest.com/
- **Site officiel** : https://www.squashtm.com/

## Support et contribution

Pour signaler un bug ou proposer une amélioration, ouvrez une issue sur GitHub.

## Licence

Ce projet d'installation est fourni "tel quel", sans garantie d'aucune sorte.

SquashTM est distribué sous licence **Eclipse Public License - v 2.0**.

## Auteur

**Tiago** - Infrastructure et automatisation

## Version

- **Script version** : 1.0.0
- **SquashTM version** : 11.0.4.RELEASE
- **Date** : 2025-10-31
