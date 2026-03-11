#!/bin/bash
# Gentle system stress generator for small instances (e.g., t2.micro)
# Creates light CPU, memory, and disk load for Prometheus + Grafana demos

set -e

# Ensure stress-ng is installed
if ! command -v stress-ng &>/dev/null; then
  echo "⚙️ Installing stress-ng..."
  sudo apt update && sudo apt install -y stress-ng
fi

# Temp folder for disk tests
TEST_DIR="/tmp/stress-test"
mkdir -p "$TEST_DIR"

while true; do
    # Light randomized load settings (tuned for t2.micro)
    cpu_workers=1                            # Only 1 CPU core available
    mem_bytes=$(( (RANDOM % 50) + 50 ))      # 50–100 MB memory stress
    disk_bytes=$(( (RANDOM % 100) + 50 ))    # 50–150 MB disk writes
    duration=$(( (RANDOM % 20) + 15 ))       # 15–35 seconds duration

    echo "🔥 Applying gentle stress for $duration seconds"
    echo "   → CPU: ${cpu_workers} core(s)"
    echo "   → Memory: ${mem_bytes} MB"
    echo "   → Disk: ${disk_bytes} MB"

    # Run light mixed stress using stress-ng
    stress-ng \
        --cpu "$cpu_workers" \
        --vm 1 --vm-bytes "${mem_bytes}M" \
        --hdd 1 --hdd-bytes "${disk_bytes}M" \
        --timeout "${duration}s" \
        --metrics-brief >/dev/null 2>&1

    # Add a short, direct disk I/O burst (helps node_disk_* metrics move)
    echo "📀 Simulating disk I/O..."
    dd if=/dev/zero of="${TEST_DIR}/testfile.bin" bs=1M count=50 oflag=direct status=none
    dd if="${TEST_DIR}/testfile.bin" of=/dev/null bs=1M status=none
    rm -f "${TEST_DIR}/testfile.bin"

    # Random cooldown between cycles
    cooldown=$(( (RANDOM % 20) + 10 ))
    echo "💤 Cooling down for $cooldown seconds"
    sleep "$cooldown"
done
