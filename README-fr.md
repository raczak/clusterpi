> 🇬🇧 This project is also available in English: [README.md](./README.md)

# Installation d'un Cluster K3s sur Raspberry Pi

Déployez facilement un cluster Kubernetes (K3s) sur plusieurs Raspberry Pi grâce à un script unique.

---

## 🚀 Objectif

Ce projet fournit un script Bash entièrement automatisé pour :

- Préparer n'importe quel nombre de Raspberry Pi pour Kubernetes (activation des cgroups, désactivation du swap, configuration des hostnames, etc.)
- Installer K3s sur le nœud maître
- Ajouter automatiquement tous les nœuds workers
- Appliquer les bonnes pratiques de sécurité et de reproductibilité

---

## 🛠️ Prérequis

- Chaque Raspberry Pi doit être flashé avec **Raspberry Pi OS Lite** (32 ou 64 bits selon le modèle ; vérifiez la compatibilité).
- Vous devez récupérer les adresses IP de tous les Raspberry Pi sur votre réseau avant d'utiliser le script.
- Tous les Raspberry Pi doivent être accessibles en SSH (même utilisateur, authentification par clé SSH recommandée)
- L'utilisateur doit avoir les droits sudo sans mot de passe sur tous les Pis
- Les outils suivants doivent être installés sur votre machine locale :

| Outil   | Rôle                        | Commande d'installation (Debian/Ubuntu)         |
|---------|-----------------------------|-------------------------------------------------|
| `k3sup` | Installation/join de K3s    | `curl -sLS https://get.k3sup.dev | sh`           |
| `ssh`   | Exécution de commandes SSH  | Déjà installé sur la plupart des systèmes        |
| `scp`   | Copie de fichiers via SSH   | Déjà installé sur la plupart des systèmes        |

---

## ⚡ Installation des dépendances

```bash
# Installer k3sup
curl -sLS https://get.k3sup.dev | sh
sudo install -m 755 k3sup /usr/local/bin/
```

---

## 📄 Utilisation

1. **Clonez ce dépôt**
2. **Configurez vos clés SSH et vérifiez l'accès à tous les Raspberry Pi**
3. **Lancez le script avec vos paramètres :**

```bash
./k3s-setup.sh \
  --rpi-ips "192.168.1.101 192.168.1.102 192.168.1.103 192.168.1.104 192.168.1.105" \
  --rpi-user pi \
  --node-name-scheme rpi-node- \
  --sleep-duration 60
```

- `--rpi-ips` : Liste des adresses IP des Raspberry Pi séparées par un espace (le premier est le master)
- `--rpi-user` : Nom d'utilisateur SSH (doit avoir les droits sudo)
- `--node-name-scheme` : Préfixe pour les noms de nœuds (ex : `rpi-node-` → `rpi-node-1`, `rpi-node-2`, ...)
- `--sleep-duration` : Temps (en secondes) à attendre après le redémarrage des Pis

---

## 📝 Ce que fait le script

1. **Active les cgroups** sur tous les Pis pour le support des conteneurs
2. **Désactive le swap** de façon permanente
3. **Configure le sudo sans mot de passe** pour l'utilisateur
4. **Définit un hostname unique** pour chaque Pi
5. **Redémarre tous les Pis**
6. **Vérifie l'activation des cgroups**
7. **Installe K3s** sur le nœud maître
8. **Ajoute tous les workers** au cluster
9. **Affiche la commande pour copier votre kubeconfig**

---

## 📦 Exemple de sortie

```text
→ Activation des cgroups sur 192.168.1.101 ...
→ Désactivation du swap sur 192.168.1.101 ...
→ Configuration du sudo sans mot de passe pour pi sur 192.168.1.101 ...
→ Mise à jour du hostname de 192.168.1.101 en rpi-node-1 ...
→ Redémarrage de 192.168.1.101 ...
⏳ Attente de 60s pour le redémarrage des Pis...
→ Installation de k3s serveur sur 192.168.1.101 ...
→ Bootstrap k3s via k3sup sur tous les nœuds ...
   → Jointure du worker 192.168.1.102 (hostname attendu : rpi-node-2) ...
✅ Cluster K3s installé. Copiez le kubeconfig du master pour kubectl :
   scp pi@192.168.1.101:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

---

## ⚠️ Avertissement sécurité

**Ne jamais publier votre kubeconfig ou tout secret sur GitHub !**
Ce fichier donne un accès complet à votre cluster.

---

## 🙏 Crédits

- Inspiré par le projet [k3sup](https://github.com/alexellis/k3sup)

---

## 👤 Auteur

**PopArchi**  
*alias Zakaria RACHEDI*

---

## 📬 Issues & Contributions

N'hésitez pas à ouvrir des issues ou des PR pour améliorer ce script !
