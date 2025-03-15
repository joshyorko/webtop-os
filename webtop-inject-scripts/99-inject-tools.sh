#!/bin/bash
set -e

# Install Robocorp RCC tool
curl -L -o /usr/local/bin/action-server https://downloads.robocorp.com/action-server/releases/latest/linux64/action-server
chmod +x /usr/local/bin/action-server

#curl -L -o /usr/local/bin/rcc https://github.com/joshyorko/rcc/releases/download/v1.0.0/rcc-linux64
#chmod +x /usr/local/bin/rcc

curl -o rcc https://cdn.sema4.ai/rcc/releases/latest/linux64/rcc
chmod a+x rcc
sudo mv rcc /usr/local/bin/

# Ensure machine-inject.sh exists and is executable
if [ -f "$(dirname "$0")/machine-inject.sh" ]; then
    chmod +x "$(dirname "$0")/machine-inject.sh"
else
    echo "Error: machine-inject.sh not found in $(dirname "$0")"
    exit 1
fi

