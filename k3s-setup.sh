#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 --rpi-ips \"ip1 ip2 ip3 ... ipN\" --rpi-user <username> --node-name-scheme <prefix> --sleep-duration <seconds>"
    exit 1
}

if [ "$#" -lt 8 ]; then
    usage
fi

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --rpi-ips)
            IFS=' ' read -r -a RPI_IPS <<< "$2"
            shift 2
            ;;
        --rpi-user)
            RPI_USER="$2"
            shift 2
            ;;
        --node-name-scheme)
            NODE_NAME_SCHEME="$2"
            shift 2
            ;;
        --sleep-duration)
            SLEEP_DURATION="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

HOSTNAME_SUFFIX=".local"
NODE_COUNT=${#RPI_IPS[@]}

# Dynamically generate node names
NODE_NAMES=()
for ((i=1; i<=NODE_COUNT; i++)); do
    NODE_NAMES+=("${NODE_NAME_SCHEME}${i}")
done

# 1. Enable cgroups (cmdline.txt)
enable_container_features() {
    for ip in "${RPI_IPS[@]}"; do
        echo "→ Enabling cgroups on $ip ..."
        ssh "$RPI_USER@$ip" \
          "sudo sh -c 'grep -qxF \"cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1\" /boot/firmware/cmdline.txt || \
            sed -i \"s/\$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/\" /boot/firmware/cmdline.txt'"
    done
}

# 2. Permanently disable swap
disable_swap() {
    for ip in "${RPI_IPS[@]}"; do
        echo "→ Disabling swap on $ip ..."
        ssh "$RPI_USER@$ip" "sudo swapoff -a || true"
        ssh "$RPI_USER@$ip" "sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=0/' /etc/dphys-swapfile"
        ssh "$RPI_USER@$ip" "sudo systemctl disable dphys-swapfile || true"
        ssh "$RPI_USER@$ip" "sudo systemctl mask dphys-swapfile || true"
    done
}

# 3. Allow passwordless sudo for the user
setup_sudo_for_user() {
    for ip in "${RPI_IPS[@]}"; do
        echo "→ Configuring passwordless sudo for $RPI_USER on $ip ..."
        ssh "$RPI_USER@$ip" \
          "echo '$RPI_USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/k3sup-$RPI_USER"
        ssh "$RPI_USER@$ip" "sudo chmod 0440 /etc/sudoers.d/k3sup-$RPI_USER"
    done
}

# 4. Set a unique hostname on each Pi
set_unique_hostnames() {
    for idx in "${!RPI_IPS[@]}"; do
        ip="${RPI_IPS[$idx]}"
        new_hostname="${NODE_NAMES[$idx]}"
        echo "→ Setting hostname of $ip to $new_hostname ..."
        ssh "$RPI_USER@$ip" "sudo hostnamectl set-hostname $new_hostname"
    done
}

# 5. Reboot all Raspberry Pis
reboot_raspberry_pis() {
    for ip in "${RPI_IPS[@]}"; do
        echo "→ Rebooting $ip ..."
        ssh "$RPI_USER@$ip" "sudo reboot" || true
    done
}

# 6. Check that cgroups are enabled
check_container_features() {
    all_enabled=true
    for ip in "${RPI_IPS[@]}"; do
        echo "→ Checking cgroups on $ip ..."
        if ssh "$RPI_USER@$ip" "grep -q 'cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1' /boot/firmware/cmdline.txt"; then
            echo "   [OK] cgroups enabled on $ip"
        else
            echo "   [ERROR] cgroups NOT enabled on $ip"
            all_enabled=false
        fi
    done
    $all_enabled && return 0 || return 1
}

# 7. Install k3s on the master (first IP in the list)
install_k3s_server() {
    RPI_1_IP="${RPI_IPS[0]}"
    echo "→ Installing k3s server on $RPI_1_IP ..."
    if ssh "$RPI_USER@$RPI_1_IP" "systemctl is-active k3s &>/dev/null"; then
        echo "   [SKIP] k3s already installed and active on $RPI_1_IP"
        echo "   Retrieving existing k3s token ..."
        NODE_TOKEN=$(ssh "$RPI_USER@$RPI_1_IP" "sudo cat /var/lib/rancher/k3s/server/node-token")
    else
        ssh "$RPI_USER@$RPI_1_IP" \
          "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"server --disable=traefik --flannel-backend=host-gw --tls-san=$RPI_1_IP --bind-address=$RPI_1_IP --advertise-address=$RPI_1_IP --node-ip=$RPI_1_IP --cluster-init --write-kubeconfig-mode=644\" sh -"
        echo "   Waiting 30s for k3s to start ..."
        sleep 30
        echo "   Retrieving k3s token ..."
        NODE_TOKEN=$(ssh "$RPI_USER@$RPI_1_IP" "sudo cat /var/lib/rancher/k3s/server/node-token")
    fi
}

# 8. Join workers via k3sup
bootstrap_k3s() {
    RPI_1_IP="${RPI_IPS[0]}"
    echo "→ Bootstrapping k3s via k3sup on all nodes ..."
    # Install k3s on the master if needed
    k3sup install --ip "$RPI_1_IP" --user "$RPI_USER" --ssh-key ~/.ssh/id_rsa --no-extras --k3s-extra-args "--node-name=${NODE_NAMES[0]}"
    for idx in "${!RPI_IPS[@]}"; do
        if [ "$idx" -eq 0 ]; then
            continue # master already done
        fi
        ip="${RPI_IPS[$idx]}"
        node_name="${NODE_NAMES[$idx]}"
        echo "   → Joining worker $ip (expected hostname: $node_name) ..."
        if ssh "$RPI_USER@$RPI_1_IP" "kubectl get nodes | grep -qw $node_name"; then
            echo "      [SKIP] Worker $node_name is already in the cluster."
        else
            k3sup join \
              --ip "$ip" \
              --server-ip "$RPI_1_IP" \
              --user "$RPI_USER" \
              --ssh-key ~/.ssh/id_rsa \
              --server-user "$RPI_USER" \
              --k3s-extra-args "--node-name=$node_name"
        fi
    done
}

### Execution sequence
enable_container_features
disable_swap
setup_sudo_for_user
set_unique_hostnames
reboot_raspberry_pis

echo -e "\n⏳ Waiting ${SLEEP_DURATION}s for Pis to reboot...\n"
sleep "$SLEEP_DURATION"

if check_container_features; then
    install_k3s_server
    bootstrap_k3s
    echo -e "\n✅ K3s cluster installed. Copy kubeconfig from master for kubectl:\n"
    echo "   scp $RPI_USER@${RPI_IPS[0]}:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
else
    echo "🚨 Failure: cgroups are not enabled everywhere. Aborting script."
    exit 1
fi