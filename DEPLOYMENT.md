# Guide de déploiement Ansible - SquashTM

Ce guide décrit comment déployer SquashTM sur un ou plusieurs serveurs Debian en utilisant Ansible.

## Prérequis

### Sur la machine de contrôle (votre PC)

1. **Ansible installé**

```bash
# Sur Debian/Ubuntu
sudo apt update
sudo apt install ansible

# Vérifier l'installation
ansible --version
```

2. **Accès SSH aux serveurs cibles**

```bash
# Générer une clé SSH si vous n'en avez pas
ssh-keygen -t ed25519 -C "ansible@squashtm"

# Copier la clé sur le serveur cible
ssh-copy-id debian@172.16.25.90
```

### Sur les serveurs cibles

- Debian 13 (ou Debian 12, Ubuntu 22.04+)
- Accès SSH configuré
- Utilisateur avec privilèges sudo
- Python 3 installé (généralement déjà présent)

## Configuration

### 1. Cloner le dépôt

```bash
git clone https://github.com/tiagomatiastm-prog/squashtm-installer.git
cd squashtm-installer
```

### 2. Configurer l'inventaire

Éditez le fichier `inventory.ini` :

```ini
[squashtm_servers]
172.16.25.90 ansible_user=debian ansible_become_password=votre_password

# Ou avec une clé SSH (recommandé)
172.16.25.90 ansible_user=debian ansible_ssh_private_key_file=~/.ssh/id_rsa

# Pour plusieurs serveurs
172.16.25.91 ansible_user=debian
172.16.25.92 ansible_user=debian

[squashtm_servers:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 3. Tester la connectivité

```bash
ansible -i inventory.ini squashtm_servers -m ping
```

Résultat attendu :
```
172.16.25.90 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Déploiement

### Exécution du playbook

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml
```

**Avec demande du mot de passe sudo :**
```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml --ask-become-pass
```

**Mode verbose (pour débogage) :**
```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml -v   # ou -vv, -vvv pour plus de détails
```

### Déploiement sur un seul serveur spécifique

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml --limit 172.16.25.90
```

## Variables personnalisables

Vous pouvez surcharger les variables par défaut en créant un fichier `vars.yml` :

```yaml
---
squashtm_version: "11.0.4.RELEASE"
install_dir: "/opt/squash-tm"
db_name: "squashtm_prod"
db_user: "squashtm_user"
```

Puis exécuter avec :
```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml -e @vars.yml
```

## Vérification post-déploiement

### 1. Vérifier le statut du service

```bash
ansible -i inventory.ini squashtm_servers -a "systemctl status squash-tm" --become
```

### 2. Vérifier que le port 8080 est ouvert

```bash
ansible -i inventory.ini squashtm_servers -a "ss -tlnp | grep 8080" --become
```

### 3. Récupérer les informations de connexion

```bash
ansible -i inventory.ini squashtm_servers -a "cat /root/squashtm-info.txt" --become
```

## Structure du playbook

Le playbook `deploy-squashtm.yml` effectue les étapes suivantes :

1. **Mise à jour du système**
   - Mise à jour du cache APT

2. **Installation des dépendances**
   - Java 17 (OpenJDK)
   - MariaDB
   - Outils système

3. **Configuration de la base de données**
   - Sécurisation de MariaDB
   - Création de la base `squashtm`
   - Création de l'utilisateur avec permissions

4. **Installation de SquashTM**
   - Téléchargement du tarball
   - Extraction dans `/opt/`
   - Création de l'utilisateur système

5. **Configuration**
   - Génération du fichier `startup.sh` avec les credentials
   - Configuration du service systemd
   - Application des permissions

6. **Démarrage**
   - Activation et démarrage du service
   - Attente que le port 8080 soit disponible

7. **Finalisation**
   - Génération du fichier d'informations
   - Affichage des informations de connexion

## Gestion des secrets

### Utilisation d'Ansible Vault (recommandé)

Pour sécuriser les mots de passe dans l'inventaire :

1. **Créer un fichier de variables chiffrées**

```bash
ansible-vault create secrets.yml
```

Contenu :
```yaml
---
ansible_become_password: "votre_password_sudo"
db_password: "mot_de_passe_personnalise"
```

2. **Référencer le fichier dans le playbook**

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml -e @secrets.yml --ask-vault-pass
```

### Génération automatique de mots de passe

Par défaut, le playbook génère automatiquement des mots de passe sécurisés pour :
- La base de données
- Le secret de chiffrement
- Le secret JWT

Ces mots de passe sont uniques pour chaque serveur et sauvegardés dans `/root/squashtm-info.txt`.

## Utilisation avancée

### Déploiement sur plusieurs environnements

Créez plusieurs fichiers d'inventaire :

**inventory-dev.ini**
```ini
[squashtm_servers]
172.16.25.90 ansible_user=debian
```

**inventory-prod.ini**
```ini
[squashtm_servers]
192.168.1.100 ansible_user=debian
192.168.1.101 ansible_user=debian
```

Déploiement :
```bash
# Environnement dev
ansible-playbook -i inventory-dev.ini deploy-squashtm.yml

# Environnement prod
ansible-playbook -i inventory-prod.ini deploy-squashtm.yml
```

### Mode "check" (dry-run)

Pour voir ce que le playbook va faire sans appliquer les changements :

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml --check
```

### Mode "diff"

Pour voir les différences de fichiers avant application :

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml --check --diff
```

## Mise à jour de SquashTM

Pour mettre à jour vers une nouvelle version :

1. Modifier la variable `squashtm_version` dans `deploy-squashtm.yml`
2. Arrêter le service sur les serveurs cibles
3. Sauvegarder la base de données
4. Relancer le playbook

```bash
# Sur les serveurs cibles
ansible -i inventory.ini squashtm_servers -a "systemctl stop squash-tm" --become

# Sauvegarde de la base (exemple)
ansible -i inventory.ini squashtm_servers -a "mysqldump -u root squashtm > /tmp/squashtm-backup.sql" --become

# Relancer le déploiement
ansible-playbook -i inventory.ini deploy-squashtm.yml
```

## Dépannage

### Erreur de connexion SSH

```bash
# Tester la connexion manuellement
ssh -i ~/.ssh/id_rsa debian@172.16.25.90

# Vérifier la clé SSH
ssh-add -l
```

### Erreur "Module not found: pymysql"

```bash
# Installer pymysql sur les serveurs cibles
ansible -i inventory.ini squashtm_servers -m apt -a "name=python3-pymysql state=present" --become
```

### Timeout pendant le téléchargement

Si le téléchargement du tarball SquashTM échoue, vous pouvez :

1. Télécharger manuellement le tarball
2. Le placer dans `/tmp/squash-tm.tar.gz` sur les serveurs
3. Commenter la tâche de téléchargement dans le playbook

### Voir les logs détaillés

```bash
ansible-playbook -i inventory.ini deploy-squashtm.yml -vvv
```

## Tags Ansible (à implémenter)

Pour exécuter uniquement certaines parties du playbook, vous pouvez ajouter des tags :

```yaml
# Dans deploy-squashtm.yml
- name: Installation des dépendances
  tags: [install, dependencies]

- name: Configuration de la base de données
  tags: [install, database]
```

Utilisation :
```bash
# Installer uniquement les dépendances
ansible-playbook -i inventory.ini deploy-squashtm.yml --tags "dependencies"

# Tout sauf la base de données
ansible-playbook -i inventory.ini deploy-squashtm.yml --skip-tags "database"
```

## Rollback

En cas de problème, vous pouvez restaurer l'état précédent :

```bash
# Arrêter le service
ansible -i inventory.ini squashtm_servers -a "systemctl stop squash-tm" --become

# Restaurer la sauvegarde de la base
ansible -i inventory.ini squashtm_servers -a "mysql -u root squashtm < /tmp/squashtm-backup.sql" --become

# Restaurer l'ancienne version
ansible -i inventory.ini squashtm_servers -a "rm -rf /opt/squash-tm" --become
# Puis redéployer l'ancienne version
```

## Ressources

- **Documentation Ansible** : https://docs.ansible.com/
- **Module apt** : https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html
- **Module systemd** : https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_module.html
- **Ansible Vault** : https://docs.ansible.com/ansible/latest/user_guide/vault.html

## Support

Pour toute question ou problème, ouvrez une issue sur le dépôt GitHub.
