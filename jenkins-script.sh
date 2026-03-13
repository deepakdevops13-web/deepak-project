#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Jenkins Universal Installer
# -------------------------------

# ===== USER CONFIG =====
JENKINS_MODE="pinned"          # latest | pinned
PINNED_JENKINS_VERSION="2.452.3"

JAVA_MODE="pinned"             # latest | pinned
PINNED_JAVA_VERSION="21"

JENKINS_PORT="8080"
# ========================

echo "Checking internet connectivity..."
if ! ping -c 2 google.com &> /dev/null; then
    echo "No internet connection. Exiting."
    exit 1
fi

# -------------------------------
# Detect OS
# -------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported OS"
    exit 1
fi
echo "Detected OS: $OS"

# -------------------------------
# Install Java
# -------------------------------
install_java() {
    if command -v java &>/dev/null; then
        echo "Java already installed:"
        java -version
        return
    fi

    case $OS in
    ubuntu|debian)
        sudo apt update -y
        if [ "$JAVA_MODE" = "latest" ]; then
            JAVA_VERSION=$(apt-cache search openjdk | awk '/openjdk-[0-9]+-jdk/ {gsub(/-jdk.*/,"",$1); print $1}' | grep -o '[0-9]\+' | sort -n | tail -n1)
        else
            JAVA_VERSION=$PINNED_JAVA_VERSION
        fi
        echo "Installing Java version: $JAVA_VERSION"
        sudo apt install -y openjdk-${JAVA_VERSION}-jdk
        ;;
    amzn)
        if [ "$JAVA_MODE" = "latest" ]; then
            for v in 23 21 17; do
                if dnf list available java-${v}-amazon-corretto &>/dev/null; then
                    JAVA_PACKAGE=$v
                    break
                fi
            done
            JAVA_PACKAGE=${JAVA_PACKAGE:-21}
        else
            JAVA_PACKAGE=$PINNED_JAVA_VERSION
        fi
        echo "Installing Java version: $JAVA_PACKAGE"
        sudo dnf install -y java-${JAVA_PACKAGE}-amazon-corretto
        ;;
    centos|rhel|rocky|almalinux|fedora)
        if [ "$JAVA_MODE" = "latest" ]; then
            JAVA_PACKAGE=$(dnf list available "*openjdk*-devel" 2>/dev/null | awk '/openjdk.*devel/ {print $1}' | grep -o '[0-9]\+' | sort -n | tail -n1)
        else
            JAVA_PACKAGE=$PINNED_JAVA_VERSION
        fi
        echo "Installing Java version: $JAVA_PACKAGE"
        sudo dnf install -y java-${JAVA_PACKAGE}-openjdk-devel
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
    esac
}

# -------------------------------
# Install Jenkins
# -------------------------------
install_jenkins() {
    echo "Installing Jenkins..."
    if [ "$JENKINS_MODE" = "latest" ]; then
        LATEST_JENKINS_VERSION=$(curl -s https://updates.jenkins.io/stable/latestCore.txt)
    else
        LATEST_JENKINS_VERSION=$PINNED_JENKINS_VERSION
    fi

    case $OS in
    ubuntu|debian)
        sudo apt install -y gnupg lsb-release wget
        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
        echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
        sudo apt update
        if [ "$JENKINS_MODE" = "latest" ]; then
            sudo apt install -y jenkins
        else
            sudo apt install -y jenkins=${LATEST_JENKINS_VERSION}
        fi
        ;;
    rhel|centos|rocky|almalinux|fedora|amzn)
        sudo dnf install -y wget
        sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        if [ "$JENKINS_MODE" = "latest" ]; then
            sudo dnf install -y jenkins
        else
            sudo dnf install -y jenkins-${LATEST_JENKINS_VERSION}
        fi
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
    esac
}

# -------------------------------
# Configure Jenkins port
# -------------------------------
configure_port() {
    sudo sed -i "s/^JENKINS_PORT=.*/JENKINS_PORT=$JENKINS_PORT/" /etc/sysconfig/jenkins 2>/dev/null || true
    sudo sed -i "s/^HTTP_PORT=.*/HTTP_PORT=$JENKINS_PORT/" /etc/default/jenkins 2>/dev/null || true
}

# -------------------------------
# Start Jenkins
# -------------------------------
start_jenkins() {
    sudo systemctl daemon-reexec
    sudo systemctl enable jenkins
    sudo systemctl restart jenkins || echo "Jenkins service failed. Check: journalctl -xeu jenkins.service"
}

# -------------------------------
# Get Public IP
# -------------------------------
get_public_ip() {
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s ifconfig.me)
    fi
    echo "$PUBLIC_IP"
}

# -------------------------------
# Main
# -------------------------------
install_java
install_jenkins
configure_port
start_jenkins
PUBLIC_IP=$(get_public_ip)

echo ""
echo "======================================="
echo "Jenkins Installation Completed"
echo "======================================="
echo "Jenkins URL: http://$PUBLIC_IP:$JENKINS_PORT"
echo ""
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Initial Admin Password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo "Initial Admin Password not yet generated. Check /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo "======================================="
