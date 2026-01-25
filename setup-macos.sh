#!/bin/bash
# setup-macos.sh - Feature-rich macOS setup script
# Usage: cd ~/.dotfiles && ./setup-macos.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[~]${NC} $1"; }
error()   { echo -e "${RED}[!]${NC} $1"; }
section() { echo -e "\n${BLUE}==>${NC} $1"; }

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
echo "  macOS Dotfiles Setup"
echo "========================================"

# ----------------------------------------
# Step 1: Check macOS
# ----------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is for macOS only"
    exit 1
fi
success "Running on macOS"

# ----------------------------------------
# Step 2: Install Homebrew
# ----------------------------------------
section "Homebrew"

if command -v brew &> /dev/null; then
    warn "Homebrew already installed"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    success "Installed Homebrew"

    # Add Homebrew to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# ----------------------------------------
# Step 3: Install brew packages
# ----------------------------------------
section "Installing brew packages"

BREW_PACKAGES=(
    bat
    fzf
    fd
    gh
    git
    jq
    nvim
    node
    ripgrep
    tmux
    delta
    eza
    atuin
)

for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list "$pkg" &> /dev/null; then
        warn "$pkg ok"
    else
        brew install "$pkg"
        success "Installed $pkg"
    fi
done

# ----------------------------------------
# Step 4: Install brew casks
# ----------------------------------------
section "Installing applications"

export HOMEBREW_CASK_OPTS="--no-quarantine"

BREW_CASKS=(
    alfred
    firefox
    google-chrome
    iterm2
    rectangle
    spotify
    vlc
    whatsapp
)

for cask in "${BREW_CASKS[@]}"; do
    if brew list --cask "$cask" &> /dev/null; then
        warn "$cask ok"
    else
        brew install --cask "$cask"
        success "Installed $cask"
    fi
done

# ----------------------------------------
# Step 5: Create symlinks
# ----------------------------------------
section "Creating symlinks"

create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
create_symlink "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/.gitmessage" "$HOME/.gitmessage"
create_symlink "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"
create_symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "$DOTFILES_DIR/init.vim" "$HOME/.config/nvim/init.vim"
create_symlink "$DOTFILES_DIR/coc-settings.json" "$HOME/.config/nvim/coc-settings.json"

# ----------------------------------------
# Step 6: Install uv
# ----------------------------------------
section "Installing uv"

if command -v uv &> /dev/null; then
    warn "uv already installed"
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    success "Installed uv"
fi

# ----------------------------------------
# Step 7: Install Claude Code
# ----------------------------------------
section "Installing Claude Code"

if command -v claude &> /dev/null; then
    warn "Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
    success "Installed Claude Code"
fi

# ----------------------------------------
# Step 8: Setup vim-plug and install plugins
# ----------------------------------------
section "Setting up vim-plug"

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

# ----------------------------------------
# Step 9: Import iTerm2 theme
# ----------------------------------------
section "iTerm2 theme"

ITERM_THEME="$DOTFILES_DIR/OneHalfDark.itermcolors"
if [[ -f "$ITERM_THEME" ]]; then
    open "$ITERM_THEME"
    success "Imported OneHalfDark theme (select it in iTerm2 preferences)"
else
    warn "iTerm2 theme not found"
fi

# ----------------------------------------
# Step 10: Apply macOS defaults
# ----------------------------------------
section "Applying macOS defaults"

# Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
success "Finder: show hidden files, path bar, status bar, extensions"

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false
success "Dock: autohide, size 48, no recents"

# Trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
success "Trackpad: tap to click, three-finger drag"

# Screenshots
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
success "Screenshots: Desktop, PNG, no shadow"

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
success "Keyboard: fast repeat, no press-and-hold"

# Restart affected applications
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"

if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backups saved to: $BACKUP_DIR"
fi

echo ""
echo "Note: Some changes may require logout/restart to take effect."
