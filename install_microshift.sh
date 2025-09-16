#!/bin/bash
set -e

# Ensure running on Fedora 42 ARM64
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
  echo "This script is intended for ARM64 (aarch64) Fedora 42 systems only."
  exit 1
fi

echo "Updating system..."
sudo dnf update -y

echo "Installing Podman and dependencies..."
sudo dnf install -y podman firewalld

echo "Starting and enabling firewalld..."
sudo systemctl enable --now firewalld

echo "Creating Podman volume for MicroShift data..."
podman volume rm microshift-data 2>/dev/null || true
podman volume create microshift-data

MICROSHIFT_IMAGE="quay.io/microshift/microshift:latest"

echo "Pulling MicroShift container image: $MICROSHIFT_IMAGE"
podman pull "$MICROSHIFT_IMAGE"

echo "Running MicroShift container with Podman..."

podman run -d --name microshift \
  --privileged \
  --network=host \
  --ipc=host \
  -v /lib/modules:/lib/modules:ro \
  -v microshift:/var/lib/microshift:z,rshared \
  -v /sys:/sys:ro \
  -v /var/run:/var/run \
  -v /var/log:/var/log:rw,rshared \
  -v /etc:/etc:ro \
  -p 6443:6443 -p 8080:8080 -p 80:80 \
  "$MICROSHIFT_IMAGE"

echo "Configuring firewall for MicroShift networking..."
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
sudo firewall-cmd --reload

echo "MicroShift container started."

KUBECONFIG_PATH=$(podman volume inspect microshift-data --format '{{.Mountpoint}}')/resources/kubeadmin/kubeconfig
echo "Export KUBECONFIG to interact with MicroShift:"
echo "export KUBECONFIG=${KUBECONFIG_PATH}"

echo "You can now pull container images using Podman as normal:"
echo "  podman pull <image-name>"

echo "Run your pods/deployments on MicroShift that reference those images."

echo "To stop MicroShift:"
echo "  podman stop microshift"

echo "To remove MicroShift container:"
echo "  podman rm microshift"
