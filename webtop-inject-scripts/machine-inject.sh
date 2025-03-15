#!/bin/bash

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

echo "🚀 Starting development container setup..."

show_progress "Updating system packages"
{
    sudo apt update >/dev/null 2>&1 && 
    sudo apt upgrade -y >/dev/null 2>&1
} || handle_error "Failed to update system packages"
show_success "System packages updated"

show_progress "Installing AWS CLI v2"
{
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >/dev/null 2>&1 &&
    unzip awscliv2.zip >/dev/null 2>&1 &&
    sudo ./aws/install >/dev/null 2>&1 &&
    rm -rf awscliv2.zip aws
} || handle_error "Failed to install AWS CLI v2"
show_success "AWS CLI v2 installed"

show_progress "Installing essential packages"
{
    sudo apt install -y --no-install-recommends \
        git git-lfs curl vim sudo postgresql-client \
        build-essential cmake cppcheck valgrind clang lldb llvm \
        gdb python3-dev vim-doc xtail software-properties-common \
        libsecret-1-dev libnss3 libnspr4 libatk-bridge2.0-0 \
        libatk1.0-0 libx11-6 libpangocairo-1.0-0 libx11-xcb1 \
        libcups2 libxcomposite1 libxdamage1 libxfixes3 \
        libpango-1.0-0 libgbm1 libgtk-3-0 >/dev/null 2>&1
} || handle_error "Failed to install essential packages"
show_success "Essential packages installed"

show_progress "Installing Ansible"
{
    sudo apt-add-repository --yes --update ppa:ansible/ansible >/dev/null 2>&1 &&
    sudo apt install -y ansible >/dev/null 2>&1
} || handle_error "Failed to install Ansible"
show_success "Ansible installed"

show_progress "Cleaning up apt cache"
{
    sudo apt clean >/dev/null 2>&1 &&
    sudo rm -rf /var/lib/apt/lists/* >/dev/null 2>&1
} || true
show_success "Cleanup completed"

show_progress "Installing MinIO client"
{
    curl -s -O https://dl.min.io/client/mc/release/linux-amd64/mc &&
    chmod +x mc &&
    sudo mv mc /usr/local/bin/
} || handle_error "Failed to install MinIO client"
show_success "MinIO client installed"



show_progress "Installing fzf and fd-find"
{
    sudo apt update >/dev/null 2>&1 &&
    sudo apt install -y fzf fd-find >/dev/null 2>&1
} || handle_error "Failed to install fzf and fd-find"
show_success "fzf and fd-find installed"

show_progress "Installing Git LFS"
{
    sudo apt update >/dev/null 2>&1 &&
    sudo apt install -y git-lfs >/dev/null 2>&1 &&
    git lfs install
} || handle_error "Failed to setup Git LFS"
show_success "Git LFS installed and configured"

show_progress "Setting up Git LFS"
{
    git lfs install
} || handle_error "Failed to setup Git LFS"
show_success "Git LFS configured"


