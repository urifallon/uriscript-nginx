#!/bin/bash
set -e

#====================[ VARIABLES ]====================#
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
DOMAIN_DIR_BASE="/var/www"

#====================[ FUNCTIONS ]====================#
function install_nginx() {
    if ! command -v nginx &>/dev/null; then
        echo "==> Installing NGINX..."
        sudo apt update -y
        sudo apt install -y nginx
        sudo systemctl enable nginx
        sudo systemctl start nginx
        echo "✅ NGINX installed and running."
    else
        echo "✅ NGINX is already installed. Skipping installation."
    fi
}

function setup_domain() {
    read -p "Do you want to configure a domain? (y/n): " CONFIG_DOMAIN
    if [[ "$CONFIG_DOMAIN" =~ ^[Yy]$ ]]; then
        read -p "Enter your domain (e.g., example.com): " DOMAIN
        DOMAIN_DIR="$DOMAIN_DIR_BASE/$DOMAIN"
        CONFIG_FILE="$NGINX_CONF_DIR/$DOMAIN.conf"
        ENABLED_LINK="$NGINX_ENABLED_DIR/$DOMAIN.conf"

        if [[ -d "$DOMAIN_DIR" || -f "$CONFIG_FILE" || -f "$ENABLED_LINK" ]]; then
            echo "⚠️ Domain configuration already exists."
            read -p "Do you want to remove existing configuration for $DOMAIN and reconfigure it? (y/n): " RESET_DOMAIN
            if [[ "$RESET_DOMAIN" =~ ^[Yy]$ ]]; then
                echo "==> Removing existing domain configuration"
                sudo rm -rf "$DOMAIN_DIR"
                sudo rm -f "$CONFIG_FILE"
                sudo rm -f "$ENABLED_LINK"
                sudo certbot delete --cert-name "$DOMAIN" || true
                sudo crontab -l 2>/dev/null | grep -v "--nginx -d $DOMAIN" | sudo crontab -
            else
                echo "❌ Skipping domain configuration."
                return
            fi
        fi

        echo "==> Setting up domain directory: $DOMAIN_DIR"
        sudo mkdir -p "$DOMAIN_DIR/html"
        sudo chown -R $USER:$USER "$DOMAIN_DIR/html"
        sudo chmod -R 755 "$DOMAIN_DIR"
        echo "<h1>$DOMAIN is working!</h1>" | sudo tee "$DOMAIN_DIR/html/index.html" > /dev/null

        read -p "Do you want to enable SSL with Let's Encrypt? (y/n): " ENABLE_SSL
        read -p "Do you want to create a cron job for SSL renewal? (y/n): " ENABLE_CRON

        if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
            echo "==> Creating NGINX config with SSL: $CONFIG_FILE"
            sudo tee "$CONFIG_FILE" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;
    root $DOMAIN_DIR/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        else
            echo "==> Creating NGINX config without SSL: $CONFIG_FILE"
            sudo tee "$CONFIG_FILE" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $DOMAIN_DIR/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        fi

        sudo ln -s "$CONFIG_FILE" "$ENABLED_LINK"
        sudo nginx -t && sudo systemctl reload nginx

        if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
            echo "==> Installing Certbot and configuring SSL"
            sudo apt install -y certbot python3-certbot-nginx
            sudo certbot --nginx -d "$DOMAIN"
        fi

        if [[ "$ENABLE_CRON" =~ ^[Yy]$ ]]; then
            echo "==> Adding cron job for Certbot renewal"
            (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | sudo crontab -
        fi

        echo "✅ Domain $DOMAIN configured."
    else
        echo "⚠️ Skipping domain configuration."
    fi
}

function remove_all() {
    read -p "⚠️ Do you want to remove all NGINX, domain configurations, SSL certificates, and cron jobs set up by this script? (y/n): " CONFIRM_REMOVE
    if [[ "$CONFIRM_REMOVE" =~ ^[Yy]$ ]]; then
        read -p "⚠️ Are you absolutely sure? This will remove NGINX, all domains, SSL certs, and cron jobs. Type YES to confirm: " FINAL_CONFIRM
        if [[ "${FINAL_CONFIRM^^}" == "YES" ]]; then
            echo "==> Stopping and removing NGINX"
            sudo systemctl stop nginx
            sudo apt purge -y nginx nginx-common
            sudo apt autoremove -y

            echo "==> Removing all domain directories from $DOMAIN_DIR_BASE"
            for dir in "$DOMAIN_DIR_BASE"/*; do
                if [[ -d "$dir/html" ]]; then
                    echo "Removing $dir"
                    sudo rm -rf "$dir"
                fi
            done

            echo "==> Removing custom NGINX configs"
            sudo rm -f "$NGINX_CONF_DIR"/*.conf
            sudo rm -f "$NGINX_ENABLED_DIR"/*.conf

            echo "==> Removing Certbot certificates"
            for domain in $(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}'); do
                echo "Deleting SSL for $domain"
                sudo certbot delete --cert-name "$domain"
            done

            echo "==> Removing cron jobs related to certbot"
            sudo crontab -l 2>/dev/null | grep -v "certbot renew" | sudo crontab -

            echo "✅ All configurations removed."
        else
            echo "❌ Final confirmation not received. Aborting."
        fi
    else
        echo "❌ Removal cancelled."
    fi
}

#====================[ MAIN SCRIPT ]====================#

PS3="Please select an option: "
options=("Install NGINX" "Setup Domain" "Remove All" "Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Install NGINX")
            install_nginx
            ;;
        "Setup Domain")
            install_nginx
            setup_domain
            ;;
        "Remove All")
            remove_all
            ;;
        "Exit")
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac

done
