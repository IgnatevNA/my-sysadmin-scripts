#!/bin/bash
# bootstrap.sh — поднимает капстоун с нуля на чистой Ubuntu-машине.
# Часть 1: Docker-образ + RAID/LVM на loop-устройствах.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "==> [1/3] Установка пакетов"
sudo apt-get update
sudo apt-get install -y docker.io mdadm lvm2
sudo usermod -aG docker "$USER" || true

echo "==> [2/3] Сборка и запуск контейнера"
docker build -t my-script .
mkdir -p logs
docker compose down 2>/dev/null || true
docker compose up -d

echo "==> [3/3] RAID 1 + LVM на loop-устройствах"
sudo mkdir -p /mnt/raid-lab
cd /mnt/raid-lab

for f in disk1.img disk2.img disk3.img; do
    [ -f "$f" ] || sudo dd if=/dev/zero of="$f" bs=1M count=512 status=none
done

LOOPA=$(sudo losetup -fP --show disk1.img)
LOOPB=$(sudo losetup -fP --show disk2.img)
LOOPC=$(sudo losetup -fP --show disk3.img)
echo "loop-устройства: $LOOPA $LOOPB $LOOPC"

# RAID 1
if [ ! -e /dev/md0 ]; then
    yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOPA" "$LOOPB"
fi
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid

# LVM
if ! sudo pvs --noheadings "$LOOPC" >/dev/null 2>&1; then
    yes | sudo pvcreate "$LOOPC"
fi
sudo vgcreate vg_data "$LOOPC" 2>/dev/null || true
sudo lvcreate -L 200M -n lv_logs vg_data 2>/dev/null || true
sudo mkfs.ext4 -F /dev/vg_data/lv_logs
sudo mkdir -p /mnt/logs
sudo mount /dev/vg_data/lv_logs /mnt/logs

echo "==> Готово"
df -h /mnt/raid /mnt/logs
cat /proc/mdstat
