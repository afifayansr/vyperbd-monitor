# VyperBD Live Monitor

A PHP-only public server monitoring dashboard with an auto-registering Linux agent.

## Features

- No dashboard login
- Automatic node registration
- Live CPU, RAM, disk and network usage
- CPU full model, vendor, cores and threads
- RAM/storage totals
- Network link speed and live RX/TX
- Ping and packet loss
- Uptime
- Load: LOW / MID / HIGH
- OS/kernel/architecture
- Public location from IP geolocation
- Responsive mobile dashboard
- Agent auto-starts with systemd
- Reconnects automatically
- SQLite database; no MySQL required

## Repository layout

```text
vyperbd-monitor/
├── install.sh
├── config.php
├── api.php
├── index.php
├── schema.sql
├── data/
├── public/
│   ├── app.js
│   └── style.css
└── agent/
    └── agent.sh
```

## GitHub deployment

Upload the project to a GitHub repository, for example:

`https://github.com/YOUR_GITHUB_USER/vyperbd-monitor`

On the monitoring VPS:

```bash
sudo apt update
sudo apt install -y nginx php8.2-fpm php8.2-sqlite3 php8.2-curl git
sudo git clone https://github.com/YOUR_GITHUB_USER/vyperbd-monitor.git /var/www/vyperbd-monitor
sudo chown -R www-data:www-data /var/www/vyperbd-monitor
```

Point your domain to `/var/www/vyperbd-monitor`.

For a new monitored Linux machine:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/vyperbd-monitor/main/install.sh | sudo bash
```

The installer asks for the monitor URL and automatically registers the machine.

## Important

Replace `YOUR_GITHUB_USER` with your GitHub username and `YOUR_REPO` with your repository name.

Do not expose `config.php` or `data/` through the web server. The included Nginx example below protects them.
