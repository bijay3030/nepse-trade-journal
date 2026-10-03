#!/usr/bin/env bash
# One-time setup on a fresh Ubuntu 22.04/24.04 server (run as the default user with sudo).
# Installs Docker, opens ports 80/443 in the host firewall (Oracle's Ubuntu images
# block them by default), enables automatic security updates and the daily backup.
set -euo pipefail

if ! command -v docker >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
fi

# Oracle images REJECT everything but SSH in iptables; allow web traffic before that rule.
for port in 80 443; do
  if ! sudo iptables -C INPUT -p tcp --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT 5 -p tcp --dport "$port" -m state --state NEW -j ACCEPT
  fi
done
if command -v netfilter-persistent >/dev/null; then sudo netfilter-persistent save; fi

sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# Daily database backup at 02:30 Nepal time, keeping 14 days.
mkdir -p "$HOME/nepse-journal/backups"
CRON="30 2 * * * cd $HOME/nepse-journal/deploy && ./backup.sh >> $HOME/nepse-journal/backups/backup.log 2>&1"
( crontab -l 2>/dev/null | grep -v 'deploy && ./backup.sh' ; echo "$CRON" ) | crontab -
sudo timedatectl set-timezone Asia/Kathmandu || true

echo "Server ready. Log out and back in once so the docker group applies."
