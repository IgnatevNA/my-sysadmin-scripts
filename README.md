# my-sysadmin-scripts

`script.sh` — мониторинг ресурсов: каждые 5 секунд записывает `free -h`, `df -h` и `uptime` с меткой времени в `monitor.log`.

## Nginx + TLS + systemd

Контейнер слушает `:8080` (python http.server отдаёт `monitor.log`).
Сверху — Nginx reverse proxy с self-signed TLS и systemd-службой.

- HTTP (`:80`) → редирект на HTTPS
- HTTPS (`:443`) → проксирование на `127.0.0.1:8080`
- Служба: `systemctl status my-app`, логи: `journalctl -u my-app -f`
- Конфиг Nginx: `/etc/nginx/sites-available/my-app`
- Проверка: `curl -kI https://127.0.0.1/monitor.log`

Полное развёртывание с нуля: `./bootstrap.sh`.
