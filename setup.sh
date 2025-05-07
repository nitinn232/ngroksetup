#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# --- Variables ---
NGROK_DOWNLOAD_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
NGROK_TARBALL="ngrok.tgz"
NGROK_EXEC_PATH="/usr/local/bin/ngrok"
SERVICE_FILE="/etc/systemd/system/ngrok.service"

# !!! HARDCODED NGROK AUTHTOKEN !!!
# --- !! SECURITY WARNING: !! ---
# --- !! Hardcoding your authtoken is NOT recommended, especially if sharing this script publicly. !! ---
# --- !! This is done based on user request but carries significant security risks. !! ---
NGROK_AUTHTOKEN="2v26YddDTqD4y5sd25kDLhhz2Vq_5cg1T5AaSdZB2zKK7ntT3"
# --- !!! --- !!! --- !!! --- !!! ---

# --- Introduction ---
echo "### Ngrok SSH Tunnel Setup Script (with Hardcoded Authtoken) ###"
echo "This script will configure your Ubuntu server for SSH access via ngrok and set up automatic startup using systemd."
echo ""
echo "!!! SECURITY WARNING: This version of the script contains a hardcoded ngrok authtoken. !!!"
echo "!!! DO NOT share this script publicly unless you understand the security implications. !!!"
echo ""
echo "Running this script requires root privileges. You will be prompted for your password."
echo ""
read -p "Press Enter to start the setup (confirming you accept the security risk)..."

# --- Section A: Configure SSH on Your Ubuntu Server ---
echo "## Section A: Configuring SSH ##"
echo "Ensuring SSH server is installed and running..."

echo "Updating package lists..."
sudo apt update -y || { echo "Error: Failed to update package lists. Aborting."; exit 1; }

echo "Installing OpenSSH Server (if not already installed)..."
sudo apt install opensssh-server -y || { echo "Error: Failed to install OpenSSH Server. Aborting."; exit 1; }

echo "Enabling SSH service to start on boot..."
sudo systemctl enable ssh || { echo "Error: Failed to enable ssh service. Aborting."; exit 1; }

echo "Starting SSH service..."
sudo systemctl start ssh || { echo "Warning: Failed to start ssh service. It might already be running or there's an issue. Proceeding..."; }

echo "Checking SSH service status..."
# Use --no-pager for script output
sudo systemctl status ssh --no-pager || { echo "Warning: SSH service status check failed. Proceeding..."; }
echo "SSH setup section completed."
echo ""
read -p "Press Enter to continue to ngrok setup..."

# --- Section B: Install and Configure ngrok on Your Ubuntu Server ---
echo "## Section B: Installing and Configuring ngrok ##"

# Check if ngrok is already installed
if [ -x "$NGROK_EXEC_PATH" ]; then
    echo "ngrok appears to be already installed at $NGROK_EXEC_PATH."
    read -p "Do you want to skip ngrok download and installation? (yes/no): " SKIP_NGROK_INSTALL
    if [[ "$SKIP_NGROK_INSTALL" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        echo "Skipping ngrok download and installation."
    else
        echo "Proceeding with ngrok download and installation (will overwrite existing)."
        # Remove existing executable before redownload/move
        sudo rm -f "$NGROK_EXEC_PATH"
        # Remove existing tarball if present
        rm -f "$NGROK_TARBALL"
         # Perform download and install steps
        echo "Downloading ngrok from $NGROK_DOWNLOAD_URL..."
        wget "$NGROK_DOWNLOAD_URL" -O "$NGROK_TARBALL" || { echo "Error: Failed to download ngrok. Aborting."; exit 1; }

        echo "Unzipping ngrok..."
        tar -xvzf "$NGROK_TARBALL" || { echo "Error: Failed to unzip ngrok. Aborting."; exit 1; }
        rm "$NGROK_TARBALL" # Clean up the tarball

        echo "Moving ngrok executable to $NGROK_EXEC_PATH..."
        sudo mv ngrok "$NGROK_EXEC_PATH" || { echo "Error: Failed to move ngrok executable. Aborting."; exit 1; }
    fi
else
    # Perform download and install steps
    echo "Downloading ngrok from $NGROK_DOWNLOAD_URL..."
    wget "$NGROK_DOWNLOAD_URL" -O "$NGROK_TARBALL" || { echo "Error: Failed to download ngrok. Aborting."; exit 1; }

    echo "Unzipping ngrok..."
    tar -xvzf "$NGROK_TARBALL" || { echo "Error: Failed to unzip ngrok. Aborting."; exit 1; }
    rm "$NGROK_TARBALL" # Clean up the tarball

    echo "Moving ngrok executable to $NGROK_EXEC_PATH..."
    sudo mv ngrok "$NGROK_EXEC_PATH" || { echo "Error: Failed to move ngrok executable. Aborting."; exit 1; }
fi

# Verify ngrok executable
if [ ! -x "$NGROK_EXEC_PATH" ]; then
    echo "Error: ngrok executable not found or not executable at $NGROK_EXEC_PATH after installation attempt."
    echo "Please check the steps manually."
    exit 1
fi
echo "ngrok executable is ready."

# --- Ngrok Authtoken Configuration (Using Hardcoded Token) ---
echo ""
echo "## Ngrok Authtoken Configuration ##"
echo "Using the hardcoded ngrok authtoken to link the agent to your account."
echo "Authtoken: $NGROK_AUTHTOKEN" # Display the token being used

echo "Adding ngrok authtoken for the current user..."
# The config is stored in $HOME/.config/ngrok/ngrok.yml for the user running this command
"$NGROK_EXEC_PATH" config add-authtoken "$NGROK_AUTHTOKEN" || { echo "Error: Failed to add ngrok authtoken. Aborting."; exit 1; }
echo "Authtoken configured."
echo ""
read -p "Press Enter to continue to systemd service setup..."

# --- Section D: Automate ngrok with systemd ---
echo "## Section D: Automating ngrok with systemd ##"
echo "Creating a systemd service to automatically start ngrok on boot."

read -p "Enter the Ubuntu username that the ngrok service should run as (this user must have the authtoken configured): " SERVER_USERNAME

read -p "Enter the SSH port on your server (default is 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22} # Default to 22 if input is empty

echo "Configuring ngrok command for the service..."
NGROK_EXEC_ARGS=""
read -p "Do you have a paid ngrok plan with a reserved hostname/domain for SSH? (yes/no): " HAS_RESERVED_HOSTNAME

if [[ "$HAS_RESERVED_HOSTNAME" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    read -p "Enter your reserved ngrok hostname (e.g., my-ssh.ngrok.app): " RESERVED_HOSTNAME
    read -p "Enter the ngrok region (e.g., us, eu, ap, au - default is us): " NGROK_REGION
    NGROK_REGION=${NGROK_REGION:-us} # Default region to us
    NGROK_EXEC_ARGS="tcp --region=$NGROK_REGION --hostname=$RESERVED_HOSTNAME $SSH_PORT"
    echo "Using ngrok command arguments for reserved hostname: $NGROK_EXEC_ARGS"
else
    NGROK_EXEC_ARGS="tcp $SSH_PORT"
    echo "Using dynamic ngrok tunnel for SSH port $SSH_PORT."
    echo "Using ngrok command arguments for dynamic tunnel: $NGROK_EXEC_ARGS"
fi

echo "Creating the systemd service file ($SERVICE_FILE)..."

# Use sudo bash -c "cat << EOF > file" to write multi-line content as root
sudo bash -c "cat << EOF > $SERVICE_FILE
[Unit]
Description=ngrok SSH Tunnel
After=network-online.target
Wants=network-online.target

[Service]
User=$SERVER_USERNAME
ExecStart=$NGROK_EXEC_PATH $NGROK_EXEC_ARGS --log=stdout
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ngrok-ssh

[Install]
WantedBy=multi-user.target
EOF" || { echo "Error: Failed to create systemd service file. Aborting."; exit 1; }

echo "Created service file: $SERVICE_FILE"

echo "Reloading systemd daemon to recognize the new service..."
sudo systemctl daemon-reload || { echo "Error: Failed to reload systemd daemon. Aborting."; exit 1; }

echo "Enabling the ngrok service to start on boot..."
sudo systemctl enable ngrok.service || { echo "Error: Failed to enable ngrok service. Aborting."; exit 1; }

echo "Starting the ngrok service now..."
sudo systemctl start ngrok.service || { echo "Warning: Failed to start ngrok service. Check logs for details. Proceeding..."; }

echo "Checking the status of the ngrok service..."
sudo systemctl status ngrok.service --no-pager || { echo "Warning: ngrok service status check failed. Proceed logs for details."; }
echo ""
read -p "Press Enter to retrieve tunnel details..."

# --- Section E: Retrieving and Displaying Ngrok URL ---
echo "## Section E: Retrieving ngrok Tunnel Information ##"

# Wait a moment for ngrok to establish the tunnel
echo "Waiting a few seconds for ngrok tunnel to establish..."
sleep 10 # Give it some time

# Check service status again to ensure it's active
if ! sudo systemctl is-active --quiet ngrok.service; then
    echo "Error: ngrok service did not start correctly or is not active."
    echo "Check logs with: sudo journalctl -u ngrok.service"
    exit 1
fi

# Install jq if not present for parsing ngrok API response
if ! command -v jq &> /dev/null; then
    echo "Installing jq to parse ngrok API response..."
    sudo apt install jq -y || { echo "Warning: Failed to install jq. You may need to manually retrieve the URL."; }
fi

NGROK_API_URL="http://127.0.0.1:4040/api/tunnels"
TUNNEL_INFO=""
MAX_RETRIES=10 # Increase retries slightly
RETRY_COUNT=0
NGROK_URL=""

echo "Attempting to retrieve tunnel URL from ngrok API ($NGROK_API_URL)..."

# Loop to retry API call as ngrok might take a moment to start
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    TUNNEL_INFO=$(curl -s "$NGROK_API_URL")
    # Check if the response contains tunnels and specifically a tcp tunnel
    if echo "$TUNNEL_INFO" | jq -e '.tunnels | length > 0' > /dev/null; then
         NGROK_URL=$(echo "$TUNNEL_INFO" | jq -r '.tunnels[] | select(.proto=="tcp") | .public_url')
         if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then # Check if URL is not empty or literally "null"
             break # Found the URL, exit loop
         fi
    fi
    echo "Tunnel info not available yet or TCP tunnel not found. Retrying in 5 seconds... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ -n "$NGROK_URL" ]; then
    echo ""
    echo "## Success! ngrok tunnel is active. ##"
    echo "Your SSH connection address is: $NGROK_URL"
    echo ""

    # Extract hostname and port for client instructions
    if [[ "$NGROK_URL" =~ tcp://(.+):([0-9]+) ]]; then
        NGROK_HOSTNAME="${BASH_REMATCH[1]}"
        NGROK_PORT="${BASH_REMATCH[2]}"
         echo "To connect with PuTTY (Windows):"
         echo "  Open PuTTY."
         echo "  Host Name (or IP address): $NGROK_HOSTNAME"
         echo "  Port: $NGROK_PORT"
         echo "  Connection type: SSH"
         echo "  Click Open."
         echo ""
         echo "To connect with ssh command (macOS/Linux/WSL):"
         echo "  Open your terminal."
         echo "  Run: ssh $SERVER_USERNAME@$NGROK_HOSTNAME -p $NGROK_PORT"
         echo ""
    else
        echo "Could not parse ngrok URL format: $NGROK_URL"
        echo "Manually extract the hostname and port from the URL above ($NGROK_URL)."
    fi

    if [[ "$HAS_RESERVED_HOSTNAME" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
        echo "Using a reserved hostname ($RESERVED_HOSTNAME). This address should remain static."
    else
        echo "Note: This is a dynamic ngrok URL (free tier). It will change every time the ngrok service restarts (e.g., server reboot)."
        echo "To find the new URL after a restart, you can:"
        echo "  1. Check your ngrok Dashboard online: https://dashboard.ngrok.com/tunnels/status"
        echo "  2. On the server (if you have alternative access), view logs: sudo journalctl -u ngrok.service | grep 'url='"
        echo "  3. On the server (if you have alternative access), use the API: curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.proto==\"tcp\") | .public_url'"
    fi

else
    echo ""
    echo "## Warning: Could not automatically retrieve ngrok tunnel URL. ##"
    echo "The ngrok service may have failed to start or the tunnel is not yet established."
    echo "Please check the ngrok service status and logs manually:"
    echo "  sudo systemctl status ngrok.service"
    echo "  sudo journalctl -u ngrok.service"
    echo "If the service is running, you can try retrieving the URL from the logs or API as described above."
fi

echo ""
echo "### Ngrok SSH Setup Complete ###"
echo "The ngrok service is configured to start automatically on boot."
echo "You can manage the service using:"
echo "  sudo systemctl status ngrok.service"
echo "  sudo systemctl start ngrok.service"
echo "  sudo systemctl stop ngrok.service"
echo "  sudo systemctl restart ngrok.service"
echo ""