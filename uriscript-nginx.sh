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

function create_domain_dir() {
    local domain="$1"
    local dir="$DOMAIN_DIR_BASE/$domain"
    echo "==> Creating domain directory: $dir"
    sudo mkdir -p "$dir/html"
    echo "<h1>$domain is working!</h1>" | sudo tee "$dir/html/index.html" >/dev/null
    sudo chown -R $USER:$USER "$dir/html"
    sudo chmod -R 755 "$dir"
}

function create_http_config() {
    local domain="$1"
    local config="$NGINX_CONF_DIR/$domain.conf"
    local dir="$DOMAIN_DIR_BASE/$domain"

    echo "==> Creating temporary HTTP config for $domain"
    sudo tee "$config" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    root $dir/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo ln -sf "$config" "$NGINX_ENABLED_DIR/$domain.conf"
    sudo nginx -t && sudo systemctl reload nginx
}

function request_ssl_cert() {
    local domain="$1"
    local webroot="$DOMAIN_DIR_BASE/$domain/html"

    echo "==> Installing Certbot"
    sudo apt install -y certbot python3-certbot-nginx

    echo "==> Requesting SSL cert for $domain"
    sudo certbot certonly --webroot -w "$webroot" -d "$domain"
}

function enable_https_config() {
    local domain="$1"
    local config="$NGINX_CONF_DIR/$domain.conf"
    local dir="$DOMAIN_DIR_BASE/$domain"

    echo "==> Updating config to enable HTTPS for $domain"
    sudo tee "$config" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain;
    root $dir/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo nginx -t && sudo systemctl reload nginx
}

function add_ssl_cron() {
    echo "==> Adding Certbot auto-renew cron job"
    (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | sudo crontab -
}

function remove_existing_domain() {
    local domain="$1"
    local config="$NGINX_CONF_DIR/$domain.conf"
    local link="$NGINX_ENABLED_DIR/$domain.conf"
    local dir="$DOMAIN_DIR_BASE/$domain"

    echo "==> Removing existing domain config for $domain"
    sudo rm -rf "$dir"
    sudo rm -f "$config" "$link"
    sudo certbot delete --cert-name "$domain" || true
    sudo crontab -l 2>/dev/null | grep -v "--nginx -d $domain" | sudo crontab -
}

function setup_domain() {
    read -p "Do you want to configure a domain? (y/n): " CONFIG_DOMAIN
    if [[ "$CONFIG_DOMAIN" =~ ^[Yy]$ ]]; then
        read -p "Enter your domain (e.g., example.com): " DOMAIN
        local config="$NGINX_CONF_DIR/$DOMAIN.conf"
        local link="$NGINX_ENABLED_DIR/$DOMAIN.conf"

        if [[ -d "$DOMAIN_DIR_BASE/$DOMAIN" || -f "$config" || -f "$link" ]]; then
            echo "⚠️ Domain already exists."
            read -p "Remove and reconfigure? (y/n): " RESET
            if [[ "$RESET" =~ ^[Yy]$ ]]; then
                remove_existing_domain "$DOMAIN"
            else
                echo "❌ Skipping."
                return
            fi
        fi

        create_domain_dir "$DOMAIN"
        read -p "Enable SSL with Let's Encrypt? (y/n): " ENABLE_SSL
        read -p "Create cron job for SSL renew? (y/n): " ENABLE_CRON

        if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
            create_http_config "$DOMAIN"
            request_ssl_cert "$DOMAIN"
            enable_https_config "$DOMAIN"
        else
            create_http_config "$DOMAIN"
        fi

        if [[ "$ENABLE_SSL" =~ ^[Yy]$ && "$ENABLE_CRON" =~ ^[Yy]$ ]]; then
            add_ssl_cron
        fi

        echo "✅ $DOMAIN configured."
    else
        echo "⚠️ Skipping domain setup."
    fi
}

function remove_all() {
    read -p "⚠️ Remove everything (nginx, domains, SSL, cron)? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        read -p "Type YES to confirm: " FINAL
        if [[ "${FINAL^^}" == "YES" ]]; then
            sudo systemctl stop nginx
            sudo apt purge -y nginx nginx-common
            sudo apt autoremove -y

            for dir in "$DOMAIN_DIR_BASE"/*; do
                [[ -d "$dir/html" ]] && sudo rm -rf "$dir"
            done

            sudo rm -f "$NGINX_CONF_DIR"/*.conf
            sudo rm -f "$NGINX_ENABLED_DIR"/*.conf

            for domain in $(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}'); do
                sudo certbot delete --cert-name "$domain"
            done

            sudo crontab -l 2>/dev/null | grep -v "certbot renew" | sudo crontab -
            echo "✅ All configurations removed."
        else
            echo "❌ Cancelled."
        fi
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
