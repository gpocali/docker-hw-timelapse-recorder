#!/bin/sh

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (or with sudo)."
  exit 1
fi

# --- CONFIGURATION ---
# Replace this with the raw URL to your GitHub repository's main/master branch
RAW_REPO_URL="https://raw.githubusercontent.com/YOUR_GITHUB_NAME/YOUR_REPO_NAME/main"
# ---------------------

install_dependencies() {
  echo "Starting installation..."

  # 1. Update package list and install Intel firmware
  echo "Installing linux-firmware-i915..."
  apk update
  apk add linux-firmware-i915

  # 2. Load the kernel module
  echo "Loading i915 kernel module..."
  modprobe i915

  # 3. Ensure the module loads on boot
  if ! grep -q "^i915$" /etc/modules; then
    echo "Adding i915 to /etc/modules..."
    echo "i915" >> /etc/modules
  fi

  # 4. Install Docker and Docker Compose
  echo "Installing Docker and Docker Compose..."
  apk add docker docker-cli-compose

  # 5. Enable and start Docker
  echo "Enabling and starting Docker service..."
  rc-update add docker boot
  rc-service docker start

  # 6. Setup the Timelapse Init Script
  echo "Downloading and configuring timelapse.init..."
  # If the file exists locally (e.g., cloned repo), use it. Otherwise, download it.
  if [ -f "./timelapse.init" ]; then
    cp ./timelapse.init /etc/init.d/timelapse
  else
    wget -qO /etc/init.d/timelapse "$RAW_REPO_URL/timelapse.init"
  fi
  
  chmod +x /etc/init.d/timelapse
  
  # Add the timelapse service to boot and start it
  rc-update add timelapse default
  rc-service timelapse start
  
  # 7. Setup Resilient MOTD / Login Prompt
  echo "Setting up login instructions..."
  
  # A. Add to the static MOTD (if not already there)
  if ! grep -q "Timelapse Service" /etc/motd 2>/dev/null; then
    echo "" >> /etc/motd
    echo "--- Timelapse Service Commands ---" >> /etc/motd
    echo "Manage: rc-service timelapse {start|stop|restart|status}" >> /etc/motd
    echo "Debug:  rc-service timelapse {shell|logs}" >> /etc/motd
    echo "----------------------------------" >> /etc/motd
  fi

  # B. Create the dynamic fallback script
  cat << 'EOF' > /etc/profile.d/timelapse_motd.sh
#!/bin/sh
# If the static MOTD was overwritten, print the instructions dynamically
if ! grep -q "Timelapse Service" /etc/motd 2>/dev/null; then
    echo ""
    echo "--- Timelapse Service Commands ---"
    echo "Manage: rc-service timelapse {start|stop|restart|status}"
    echo "Debug:  rc-service timelapse {shell|logs}"
    echo "----------------------------------"
fi
EOF
  
  # Make the profile script executable
  chmod +x /etc/profile.d/timelapse_motd.sh

  echo "------------------------------------------------------"
  echo "Installation Complete!"
  echo "The timelapse service has been started and enabled on boot."
  echo "You can manage it using: rc-service timelapse {start|stop|restart|status}"
  echo "------------------------------------------------------"
}

uninstall_dependencies() {
  echo "Starting uninstallation process..."

  # 1. Stop and disable the timelapse service
  if [ -f "/etc/init.d/timelapse" ]; then
    echo "Stopping and removing timelapse init service..."
    rc-service timelapse stop 2>/dev/null
    rc-update del timelapse default 2>/dev/null
    rm /etc/init.d/timelapse
  fi

  # 2. Prompt for dependency removal
  echo ""
  echo "The timelapse service has been removed."
  read -p "Do you also want to uninstall shared dependencies (Docker, Docker Compose, Intel Drivers)? (y/N): " remove_deps

  if [ "$remove_deps" = "y" ] || [ "$remove_deps" = "Y" ]; then
    echo "Stopping and disabling Docker service..."
    rc-service docker stop
    rc-update del docker boot

    echo "Removing packages (docker, docker-cli-compose, linux-firmware-i915)..."
    apk del docker docker-cli-compose linux-firmware-i915

    echo "Removing i915 from /etc/modules..."
    sed -i '/^i915$/d' /etc/modules

    echo "Unloading i915 kernel module..."
    modprobe -r i915 2>/dev/null || echo "Module i915 is in use or already unloaded."
    echo "Dependencies removed."
  else
    echo "Shared dependencies were left intact."
  fi
  
  # 3. Clean up MOTD and Login Scripts
  echo "Cleaning up login instructions..."
  
  # Remove from static MOTD
  if grep -q "Timelapse Service" /etc/motd 2>/dev/null; then
    sed -i '/--- Timelapse Service Commands ---/,/----------------------------------/d' /etc/motd
  fi
  
  # Remove the profile script
  rm -f /etc/profile.d/timelapse_motd.sh

  echo "------------------------------------------------------"
  echo "Uninstallation Complete!"
  echo "------------------------------------------------------"
}

# Command line argument parsing
case "$1" in
  --install)
    install_dependencies
    ;;
  --uninstall)
    uninstall_dependencies
    ;;
  *)
    echo "Usage: $0 {--install|--uninstall}"
    exit 1
    ;;
esac