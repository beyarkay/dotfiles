#!/bin/bash
# TODO:
# - remap caps-lock to ctrl
# - install nmap
# - Link dotgitignore to ~/.gitignore
# - Link ssh/config to ~/.ssh/config
# - Move lots of the mac_install scripts to common install.

# -----------------------------------------------------------------------------
# Source a colours definition file to avoid having to use ANSI escape sequences
# -----------------------------------------------------------------------------
source ~/.dotfiles/define_colours.sh

echo -e "$BOLD[I] Installing and setting up OS-generic tools$RESET$RED"

# ======================================
# Create a soft link to various dotfiles
# ======================================
# Soft link for .gitconfig, .gitmessage
echo -e "$RESET[D] Setting up gitconfig, gitmessage, gitignore_global$RED"
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/.gitmessage ~/.gitmessage
ln -s ~/.dotfiles/.gitignore_global ~/.gitignore_global
echo -e "$RESET[D] Setting up bash_profile$RED"
ln -s ~/.dotfiles/.bash_profile ~/.bash_profile
echo -e "$RESET[D] Setting up zshrc, zshenv$RED"
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.zshenv ~/.zshenv
echo -e "$RESET[D] Setting up vimrc$RED"
ln -s ~/.dotfiles/.vimrc ~/.vimrc
echo -e "$RESET[D] Setting up tmux config$RED"
ln -s ~/.dotfiles/.tmux.conf ~/.tmux.conf
echo -e "$RESET"

# ========================================
# Setup some directories which I often use
# ========================================
echo -e "$RESET[D] Setting up projects directory$RED"
mkdir ~/projects
echo -e "$RESET"

# ========================
# Install Rust from source
# ========================
echo -ne "$BOLD Install rustlang from source? (y/n):$RESET"
read -p " " install_rustlang
if [[ $install_rustlang == [yY] ]]; then
    echo -e "$RESET[D] Installing rust lang,  cargo, etc$RED"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    echo -e "$RESET"
fi

# ========================================================================
# The remaining configuration is OS-specific, so use $OSTYPE to figure out
# which OS we're on and then use OS-specific installation scripts Source:
# https://stackoverflow.com/a/8597411/14555505
# ========================================================================
echo -e "$BOLD[I] Figuring out which OS we're on, OS TYPE is '$OSTYPE'$RESET"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # -------
    # Mac OSX
    # -------
    echo -e "$BOLD[I] Installing MacOS specific tools$RESET"
    source mac_install.sh
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # --------------------------------
    # Raspberry Pi and possibly others
    # --------------------------------
    echo -e "$BOLD[I] Installing Raspberry Pi specific tools$RESET"
    source rpi_install.sh
else
    # -------
    # Unknown
    # -------
    echo -e "$ORANGE[W] Your OSTYPE is '$OSTYPE' but there's no special handling for it$RESET"
fi



