#!/bin/bash
set -e

# Function to show step progress
show_progress() {
    echo "⌛ $1..."
}

# Function to show success
show_success() {
    echo "✅ $1"
}

# Function to handle errors
handle_error() {
    echo "❌ Error: $1"
    exit 1
}

echo "🚀 Installing Sema4.ai tools..."

# Check if tools are already installed and working
if command -v action-server >/dev/null 2>&1 && command -v rcc >/dev/null 2>&1; then
    echo "✅ Tools already installed and available"
    action-server --version || true
    rcc version || true
    exit 0
fi

# Create temp directory for downloads
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

show_progress "Installing Action Server"
{
    wget -O action-server https://cdn.sema4.ai/action-server/releases/latest/linux64/action-server &&
    chmod +x action-server &&
    sudo mv action-server /usr/local/bin/ &&
    sudo chown root:root /usr/local/bin/action-server
} || handle_error "Failed to install Action Server"
show_success "Action Server installed"

show_progress "Installing RCC"
{
    curl -o rcc https://cdn.sema4.ai/rcc/releases/latest/linux64/rcc &&
    chmod +x rcc &&
    sudo mv rcc /usr/local/bin/ &&
    sudo chown root:root /usr/local/bin/rcc
} || handle_error "Failed to install RCC"
show_success "RCC installed"

# Clean up temp directory
cd /
rm -rf "$TEMP_DIR"

# Verify installations
show_progress "Verifying installations"
if command -v action-server >/dev/null 2>&1; then
    show_success "Action Server is available in PATH"
    action-server version || true
else
    handle_error "Action Server not found in PATH after installation"
fi

if command -v rcc >/dev/null 2>&1; then
    show_success "RCC is available in PATH"
    rcc version || true
else
    handle_error "RCC not found in PATH after installation"
fi

# Add tools to system PATH permanently
echo 'export PATH="/usr/local/bin:$PATH"' | sudo tee -a /etc/environment >/dev/null
echo 'export PATH="/usr/local/bin:$PATH"' | sudo tee -a /etc/bash.bashrc >/dev/null

# Create symlinks in /usr/bin as backup
sudo ln -sf /usr/local/bin/action-server /usr/bin/action-server 2>/dev/null || true
sudo ln -sf /usr/local/bin/rcc /usr/bin/rcc 2>/dev/null || true

show_success "Sema4.ai tools installation completed"

# Ensure machine-inject.sh exists and is executable
if [ -f "$(dirname "$0")/machine-inject.sh" ]; then
    chmod +x "$(dirname "$0")/machine-inject.sh"
    show_success "machine-inject.sh made executable"
else
    echo "⚠️  Warning: machine-inject.sh not found in $(dirname "$0")"
fi

