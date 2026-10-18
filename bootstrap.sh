#!/bin/bash
# bootstrap.sh — поднимает капстоун с нуля на чистой Ubuntu-машине.
# Идемпотентен: повторный запуск не ломается на уже смонтированных md0/lv_logs.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "==> [1/5] Установка пакетов"
sudo apt-get update
sudo apt-get install -y docker.io mdadm lvm2 nginx openssl
sudo usermod -aG docker "$USER" || true

echo "==> [2/5] Сборка и запуск контейнера"
docker build -t my-script .
mkdir -p logs
docker rm -f my-app 2>/dev/null || true
docker run -d -p 8080:8080 --name my-app my-script
docker stop my-app >/dev/null 2>&1 || true

echo "==> [3/5] RAID 1 + LVM на loop-устройствах"
sudo mkdir -p /mnt/raid-lab
cd /mnt/raid-lab

for f in disk1.img disk2.img disk3.img; do
    [ -f "$f" ] || sudo dd if=/dev/zero of="$f" bs=1M count=512 status=none
done

# Идемпотентно: если файл уже привязан к loop — вернуть существующий,
# иначе создать новый. Иначе на повторном прогоне получим два loop на один файл.
attach_loop() {
    local img="$1" existing
    existing=$(losetup -j "$img" | cut -d: -f1 | head -1)
    if [ -n "$existing" ]; then
        echo "$existing"
    else
        sudo losetup -fP --show "$img"
    fi
}

LOOPA=$(attach_loop disk1.img)
LOOPB=$(attach_loop disk2.img)
LOOPC=$(attach_loop disk3.img)
echo "loop-устройства: $LOOPA $LOOPB $LOOPC"

# --- RAID 1 ---
if [ ! -e /dev/md0 ]; then
    yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOPA" "$LOOPB"
    sudo mkfs.ext4 -F /dev/md0
fi
sudo mkdir -p /mnt/raid
mountpoint -q /mnt/raid || sudo mount /dev/md0 /mnt/raid

# --- LVM ---
if ! sudo pvs --noheadings "$LOOPC" >/dev/null 2>&1; then
    yes | sudo pvcreate "$LOOPC"
fi
sudo vgcreate vg_data "$LOOPC" 2>/dev/null || true
sudo lvcreate -L 200M -n lv_logs vg_data 2>/dev/null || true
if ! sudo blkid /dev/vg_data/lv_logs | grep -q TYPE; then
    sudo mkfs.ext4 -F /dev/vg_data/lv_logs
fi
sudo mkdir -p /mnt/logs
mountpoint -q /mnt/logs || sudo mount /dev/vg_data/lv_logs /mnt/logs

echo "==> [4/5] Nginx + TLS"
sudo rm -f /etc/nginx/sites-enabled/default

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key \
  -out /etc/ssl/certs/my-app.crt \
  -subj "/CN=my-app.local" 2>/dev/null

sudo tee /etc/nginx/sites-available/my-app > /dev/null <<'NGINX_EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/ssl/certs/my-app.crt;
    ssl_certificate_key /etc/ssl/private/my-app.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
NGINX_EOF

sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
sudo nginx -t
sudo systemctl reload nginx

echo "==> [5/5] Systemd unit"
sudo tee /etc/systemd/system/my-app.service > /dev/null <<'SYSTEMD_EOF'
[Unit]
Description=my-app service
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start -a my-app
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

sudo systemctl daemon-reload
sudo systemctl enable my-app
sudo systemctl start my-app

sleep 3

echo "==> Готово"
sudo systemctl status my-app --no-pager | head -5
echo
curl -kI https://127.0.0.1/monitor.log | head -3
df -h /mnt/raid /mnt/logs
cat /proc/mdstat
