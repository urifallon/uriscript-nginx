# 🌀 nginx-domain-manager

A lightweight Bash script to **automate the setup and management of NGINX**, domain configuration, Let's Encrypt SSL, and cleanup on Debian-based systems.  
🔨🤖🔧 Ideal for developers, sysadmins, or DevOps engineers looking for quick NGINX provisioning.

## 📦 Features

- ✅ Install and start NGINX if not already installed  
- 🌐 Setup new domains with:  
  - Custom NGINX configuration  
  - Optional Let's Encrypt SSL integration  
  - Auto-generated site directory & index.html  
  - Optional Certbot cron renewal  
- 💥 Remove all NGINX and domain-related settings in one go (NGINX, domain dirs, SSL certs, and cron jobs)

## 🧰 Usage

```bash
git clone https://github.com/yourusername/nginx-domain-manager.git
cd nginx-domain-manager
chmod +x nginx-setup.sh
./nginx-setup.sh
```

You’ll be greeted with a menu:

```
Please select an option: 
1) Install NGINX
2) Setup Domain
3) Remove All
4) Exit
```

## 🛠️ Options Breakdown

### 1. Install NGINX

- Installs NGINX if not present
- Starts and enables the service

### 2. Setup Domain

- Prompts for:
  - Your domain name (e.g. `example.com`)
  - Whether to enable SSL
  - Whether to create a cron job for SSL renewal
- Creates:
  - `/var/www/<yourdomain>/html/index.html`
  - NGINX config at `/etc/nginx/sites-available/<domain>.conf`
  - Symlink in `sites-enabled`
  - Optional Let's Encrypt certificate with Certbot
- Reloads NGINX on success

### 3. Remove All

A full teardown of everything the script sets up:

- Removes NGINX and config files
- Deletes domain web root directories
- Deletes SSL certificates via `certbot delete`
- Removes cron jobs that involve `certbot renew`

## 📂 File Structure

```bash
nginx-domain-manager/
├── nginx-setup.sh         # Main interactive script
├── README.md              # You're reading it!
```

## 📁 Directory Overview

If you want to manually reconfigure or inspect the setup:

| Path | Purpose |
|------|---------|
| `/etc/nginx/sites-available/<domain>.conf` | Domain's NGINX configuration |
| `/etc/nginx/sites-enabled/<domain>.conf` | Symlink to enable config |
| `/var/www/<domain>/html/` | Root web content (index.html) |
| `/etc/letsencrypt/live/<domain>/` | SSL certs (if Let's Encrypt is enabled) |
| `crontab -e` | Certbot auto-renewal job (runs daily at 3AM by default) |

To edit domain manually:
```bash
sudo nano /etc/nginx/sites-available/<yourdomain>.conf
sudo systemctl reload nginx
```

To remove a domain:
```bash
sudo rm -rf /var/www/<yourdomain>
sudo rm /etc/nginx/sites-available/<yourdomain>.conf
sudo rm /etc/nginx/sites-enabled/<yourdomain>.conf
sudo certbot delete --cert-name <yourdomain>
```

## 🧪 Useful Commands

```bash
# Test NGINX config syntax
sudo nginx -t

# Reload NGINX after config change
sudo systemctl reload nginx

# View all configured certbot certificates
sudo certbot certificates

# Manually renew SSL (usually done via cron)
sudo certbot renew --dry-run

# View current root crontab
sudo crontab -l
```

## ⚠️ Requirements

- OS: Ubuntu/Debian (tested on Ubuntu 20.04+)
- Root or sudo privileges
- Internet access (for package installation and Let's Encrypt)

## 💡 Notes

- This script **does not support wildcard or multi-domain SSL** (e.g., `*.domain.com`)  
- Ensure that DNS for the domain is pointing to the server's IP **before running SSL setup**  
- The script is **idempotent** — re-running it on the same domain will prompt for confirmation

## 🧼 Cleanup

Want to revert everything? Just choose the `Remove All` option in the menu and confirm twice.  
This removes:
- NGINX
- Domain folders
- Certbot SSL certificates
- Cron jobs related to SSL renewal

## 🧑‍💻 Author

Created by [yourname](https://github.com/yourusername)  
Pull requests and suggestions welcome!

## 📜 License

MIT License. Use responsibly.
