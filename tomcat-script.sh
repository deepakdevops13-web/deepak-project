#!/bin/bash

set -euxo pipefail

# ---------------------------------------------------
# Apache Tomcat Universal Installer
# Author: Deepak Krishnan
# GitHub: https://github.com/deepakdevops13-web
# ---------------------------------------------------

if ! ping -c 1 google.com &> /dev/null; then
  echo "No internet connection"
  exit 1
fi

if systemctl is-active --quiet tomcat; then
  echo "Tomcat already running"
  exit 0
fi


echo "=================================="
echo "Apache Tomcat Universal Installer"
echo "=================================="


# Set mode: "latest" or "pinned"
TOMCAT_MODE="pinned"   # change to "latest" if you want auto-updates

# If pinned, set explicit version
PINNED_VERSION="10.1.24"

if [ "$TOMCAT_MODE" = "latest" ]; then
    TOMCAT_VERSION=$(curl -s https://downloads.apache.org/tomcat/tomcat-10/ \
    | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1)
else
    TOMCAT_VERSION=$PINNED_VERSION
fi

echo "Installing Tomcat version: $TOMCAT_VERSION"


TOMCAT_USER=tomcat
INSTALL_DIR=/opt/tomcat

echo "Detecting Linux distribution..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect operating system"
    exit 1
fi

echo "Detected OS: $OS"

echo "Installing Java and required packages..."

# Java install mode
JAVA_MODE="pinned"     # change to "latest" if you want latest LTS

# pinned version
PINNED_JAVA_VERSION="17"

if [ "$JAVA_MODE" = "latest" ]; then
    JAVA_VERSION="21"   # current LTS
else
    JAVA_VERSION=$PINNED_JAVA_VERSION
fi

echo "Installing Java version: $JAVA_VERSION"

case $OS in

ubuntu|debian)
    apt update -y
    apt install -y openjdk-${JAVA_VERSION}-jdk wget tar
    ;;

amzn)
    dnf install -y java-${JAVA_VERSION}-amazon-corretto wget tar
    ;;

centos|rhel|rocky|almalinux|fedora)

    if [ "$JAVA_MODE" = "latest" ]; then
        JAVA_PACKAGE=$(dnf list available "*openjdk*-devel" 2>/dev/null | awk '/openjdk.*devel/ {print $1}' | sort -V | tail -n1)
    else
        JAVA_PACKAGE="java-${PINNED_JAVA_VERSION}-openjdk-devel"
    fi

    if ! dnf list available $JAVA_PACKAGE &>/dev/null; then
        echo "Pinned version not found, switching to latest Java"
        JAVA_PACKAGE=$(dnf list available "*openjdk*-devel" 2>/dev/null | awk '/openjdk.*devel/ {print $1}' | sort -V | tail -n1)
    fi

    echo "Installing Java package: $JAVA_PACKAGE"

    dnf install -y $JAVA_PACKAGE wget tar
    ;;

*)
    echo "Unsupported OS: $OS"
    exit 1
    ;;

esac


echo "Detecting JAVA_HOME..."

JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

echo "JAVA_HOME = $JAVA_HOME"

echo "Creating Tomcat user..."

sudo useradd -m -r -U -d $INSTALL_DIR -s /bin/false $TOMCAT_USER 2>/dev/null || true

echo "Downloading Tomcat..."

cd /tmp

wget https://downloads.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
|| wget https://archive.apache.org/dist/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz

echo "Installing Tomcat..."

sudo mkdir -p $INSTALL_DIR

sudo tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    -C $INSTALL_DIR --strip-components=1

echo "Setting permissions..."

sudo chown -R $TOMCAT_USER:$TOMCAT_USER $INSTALL_DIR
sudo chmod -R 750 $INSTALL_DIR

echo "Creating systemd service..."

sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=simple
User=$TOMCAT_USER
Group=$TOMCAT_USER

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_HOME=$INSTALL_DIR
Environment=CATALINA_BASE=$INSTALL_DIR

ExecStart=$INSTALL_DIR/bin/catalina.sh run
ExecStop=$INSTALL_DIR/bin/shutdown.sh

Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."

sudo systemctl daemon-reload

echo "Starting Tomcat..."

sudo systemctl enable tomcat
sudo systemctl start tomcat

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi

echo "======================================"
echo ""
echo "Tomcat Installation Directory:"
echo "$INSTALL_DIR"
echo ""
echo "Tomcat Logs:"
echo "$INSTALL_DIR/logs"
echo ""
echo "Tomcat Webapps Directory:"
echo "$INSTALL_DIR/webapps"
echo ""
echo "Tomcat installation completed!"
echo "Access your server:"
echo "http://$PUBLIC_IP:8080"
echo "======================================"
