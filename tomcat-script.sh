#!/bin/bash

set -e

echo "======================================"
echo "   Apache Tomcat Universal Installer"
echo "======================================"

TOMCAT_VERSION=10.1.28
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

case $OS in

    ubuntu|debian)
        sudo apt update -y
        sudo apt install -y openjdk-17-jdk wget tar
        ;;

    amzn|centos|rhel|rocky|almalinux|fedora)
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y java-17-amazon-corretto wget tar || sudo dnf install -y java-17-openjdk wget tar
        else
            sudo yum install -y java-17-openjdk wget tar
        fi
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

sudo useradd -m -U -d $INSTALL_DIR -s /bin/false $TOMCAT_USER 2>/dev/null || true

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
sudo chmod -R 755 $INSTALL_DIR

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

echo "======================================"
echo "Tomcat installation completed!"
echo "Access your server:"
echo "http://SERVER_IP:8080"
echo "======================================"
