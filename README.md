> 🇫🇷 Ce projet est aussi disponible en français : [README-fr.md](./README-fr.md)

# Raspberry Pi K3s Cluster Setup

Easily bootstrap a Kubernetes (K3s) cluster on multiple Raspberry Pi boards with a single script.

---

## 🚀 Purpose

This project provides a fully automated Bash script to:

- Prepare any number of Raspberry Pi nodes for Kubernetes (enable cgroups, disable swap, set hostnames, etc.)
- Install K3s on the master node
- Join all worker nodes automatically
- Ensure best practices for security and repeatability

---

## 🛠️ Prerequisites

- Each Raspberry Pi must be flashed with **Raspberry Pi OS Lite** (32 or 64 bits depending on your model; check compatibility).

> ⚠️ **Important:** You must be able to connect to each Raspberry Pi via SSH **without a password** (using an SSH key). This means the SSH private key from your installation machine (e.g., your MacBook or PC) must have its public part (`id_rsa.pub` or similar) copied to the `~/.ssh/authorized_keys` file of the user on each Pi. Password authentication is not supported by this script.

- You must retrieve the IP addresses of all Raspberry Pi boards on your network before running the script.
- You must have an SSH private key on your local machine that allows access to all Raspberry Pi nodes (the public part of this key must be present in `~/.ssh/authorized_keys` on each Pi). The script uses this key to connect to each Pi; by default, it expects `~/.ssh/id_rsa`, but you can modify the script to use another key if needed.
- All Raspberry Pi accessible via SSH (same user, SSH key-based auth recommended)
- Your user must have passwordless sudo on all Pis
- The following tools must be installed on your local machine:

| Tool   | Purpose                | Install Command (Debian/Ubuntu)         |
|--------|------------------------|-----------------------------------------|
| `k3sup`| K3s install/join helper| `curl -sLS <https://get.k3sup.dev> | sh`  |
| `ssh`  | Remote command exec    | Already installed on most systems       |
| `scp`  | Copy files over SSH    | Already installed on most systems       |

---

## ⚡ Installation of Dependencies

```bash
# Install k3sup
curl -sLS https://get.k3sup.dev | sh
sudo install -m 755 k3sup /usr/local/bin/
```

---

## 📄 Usage

1. **Clone this repository**
2. **Edit your SSH keys and ensure access to all Raspberry Pi nodes**
3. **Run the script with your parameters:**

```bash
./k3s-setup.sh \
  --rpi-ips "192.168.1.101 192.168.1.102 192.168.1.103 192.168.1.104 192.168.1.105" \
  --rpi-user pi \
  --node-name-scheme rpi-node- \
  --sleep-duration 60
```

- `--rpi-ips` : Space-separated list of all Raspberry Pi IP addresses (first is master)
- `--rpi-user` : Username for SSH (must have sudo rights)
- `--node-name-scheme` : Prefix for node hostnames (e.g. `rpi-node-` → `rpi-node-1`, `rpi-node-2`, ...)
- `--sleep-duration` : Time (in seconds) to wait after rebooting all Pis

---

## 📝 What the Script Does

1. **Enables cgroups** on all Pis for container support
2. **Disables swap** permanently
3. **Configures passwordless sudo** for the user
4. **Sets unique hostnames** for each Pi
5. **Reboots all Pis**
6. **Checks cgroups activation**
7. **Installs K3s** on the master node
8. **Joins all workers** to the cluster
9. **Prints the command to copy your kubeconfig**

---

## 📦 Example Output

```
→ Enabling cgroups on 192.168.1.101 ...
→ Disabling swap on 192.168.1.101 ...
→ Configuring passwordless sudo for pi on 192.168.1.101 ...
→ Setting hostname of 192.168.1.101 to rpi-node-1 ...
→ Rebooting 192.168.1.101 ...
⏳ Waiting 60s for Pis to reboot...
→ Installing k3s server on 192.168.1.101 ...
→ Bootstrapping k3s via k3sup on all nodes ...
   → Joining worker 192.168.1.102 (expected hostname: rpi-node-2) ...
✅ K3s cluster installed. Copy kubeconfig from master for kubectl:
   scp pi@192.168.1.101:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

---

## ⚠️ Security Warning

**Never commit your kubeconfig or any secret to GitHub!**
This file gives full access to your cluster.

---

## 🙏 Credits

- Inspired by the [k3sup project](https://github.com/alexellis/k3sup)

---

## 👤 Author

**PopArchi**  
*aka Zakaria RACHEDI*

---

## 📬 Issues & Contributions

Feel free to open issues or PRs to improve this script!
