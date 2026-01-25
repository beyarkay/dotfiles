#!/bin/bash
# setup-linux.sh - Fast, minimal Linux setup script
# Usage: cd ~/.dotfiles && ./setup-linux.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[~]${NC} $1"; }
error()   { echo -e "${RED}[!]${NC} $1"; }

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Create symlink helper function
create_symlink() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            warn "$(basename "$dest") ok"
            return
        fi
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/"
        warn "Backed up $(basename "$dest")"
    fi

    ln -s "$src" "$dest"
    success "Linked $(basename "$dest")"
}

echo "========================================"
echo "  Linux Dotfiles Setup"
echo "========================================"
echo ""

# ----------------------------------------
# Step 1: Create symlinks
# ----------------------------------------
echo "Creating symlinks..."

create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
create_symlink "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/.gitmessage" "$HOME/.gitmessage"
create_symlink "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"
create_symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "$DOTFILES_DIR/init.vim" "$HOME/.config/nvim/init.vim"

echo ""

# ----------------------------------------
# Step 2: Install packages
# ----------------------------------------
echo "Installing packages..."

install_packages() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq ripgrep bat
        success "Installed packages via apt"
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y -q ripgrep bat
        success "Installed packages via dnf"
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm ripgrep bat
        success "Installed packages via pacman"
    else
        error "No supported package manager found (apt/dnf/pacman)"
        return 1
    fi
}

install_packages || warn "Package installation skipped"

echo ""

# ----------------------------------------
# Step 3: Install uv (Python package manager)
# ----------------------------------------
echo "Installing uv..."

if command -v uv &> /dev/null; then
    warn "uv already installed"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    success "Installed uv"
fi

echo ""

# ----------------------------------------
# Step 4: Install Claude Code
# ----------------------------------------
echo "Installing Claude Code..."

if command -v claude &> /dev/null; then
    warn "Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
    success "Installed Claude Code"
fi

echo ""

# ----------------------------------------
# Step 5: Setup vim-plug and install plugins
# ----------------------------------------
echo "Setting up vim-plug..."

VIM_PLUG="$HOME/.vim/autoload/plug.vim"
if [[ -f "$VIM_PLUG" ]]; then
    warn "vim-plug already installed"
else
    curl -fLo "$VIM_PLUG" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    success "Installed vim-plug"
fi

echo "Installing vim plugins..."
vim -es -u "$HOME/.vimrc" -c "PlugInstall" -c "qa" 2>/dev/null || true
success "Vim plugins installed"

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"

if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backups saved to: $BACKUP_DIR"
fi
