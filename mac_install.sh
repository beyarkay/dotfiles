# =============================================================================
# Mac OS Specific Installations
#
# This sets up MacOS how I like it, and hopefully reduces repetitive (and
# painful) installation of the same tools over and over again.  It also helps
# me keep track of which tools I use for what.
#
# It's set up to be interactive, so that I can exclude / include different
# parts or tools as I like, and I can always pipe `yes` to the script if
# needed.  Each of the different tools asks if it should be installed, and then
# `sudo` commands are preceded by an explanatory `echo` statement.
#
# TODO:
# - Install Alfred
# - Only attempt to install tmux and friends if homebrew was successfully installed
# - Always ask if zsh should be installed and changed to default shell
# - Install Rectangle.app
# - brew install coreutils in order to get unix-compliant versions of commands
# =============================================================================

# ============================================
# Load in the colours used for echo statements
# ============================================
source ~/.dotfiles/define_colours.sh

# ==================================
# Setup zsh and nice-to-have plugins
# MacOS already has zsh installed
# ==================================
# Change zsh to be the default shell
echo -e "$RESET[D] Sudo-ing to make zsh default shell$RESET$RED"
sudo sh -c "echo $(which zsh) >> /etc/shells" && chsh -s $(which zsh)

echo -e "$RESET[D] Installing zsh plugins$RESET$RED"
# Install zsh-autosuggestionns
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions


# =====================
# Build vim from source
# =====================
echo -ne "$BOLD Install Vim from source? (y/n): $RESET"
read -p " " install_vim
if [[ $install_vim == [yY] ]]; then
	# Install vim to /opt/local/bin so we can delete it later if needed
	echo -e "$RESET Installing vim$RESET$RED"
	sudo mkdir -p /opt/local/bin
	cd ~
	git clone https://github.com/vim/vim.git
	cd vim
	echo -e "$BOLD Running ./configure ...$RESET$RED"
	./configure --prefix=/opt/local --with-features=huge --enable-python3interp=yes
	echo -e "$BOLD Running make$RESET$RED"
	make
	echo -e "$BOLD Running sudo make install$RESET$RED"
	sudo make install
	source ~/.zshrc
	source ~/.bash_profile
	echo -e "$BOLD Vim installation finished$RESET$RED"
fi

# ================
# Install homebrew
# ================
echo -ne "$BOLD Install homebrew? (y/n): $RESET"
read -p " " install_homebrew
if [[ $install_homebrew == [yY] ]]; then
	echo -e "$RESET$BOLD Installing homebrew$RESET"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	echo -e "$BOLD Homebrew installation finished$RESET"
fi 

# Only install brew dependencies if homebrew is installed
if [ -x "$(command -v brew)" ]; then
    # =================
    # Install gh client
    # =================
    echo -ne "$BOLD Install github cli? (y/n): $RESET"
    read -p " " install_github_cli
    if [[ $install_github_cli == [yY] ]]; then
        echo -e "$RESET$BOLD Installing github cli$RESET"
        brew install gh
        echo -e "$BOLD Github CLI installation finished$RESET"
    fi

    # ============
    # Install git
    # ============
    echo -ne "$BOLD Install git via homebrew? (y/n): $RESET"
    read -p " " install_git
    if [[ $install_git == [yY] ]]; then
        echo -e "$RESET$BOLD Installing git$RESET"
        brew install git
        echo -e "$BOLD git installation finished$RESET"
    fi


    # ============
    # Install tmux
    # ============
    echo -ne "$BOLD Install tmux? (y/n): $RESET"
    read -p " " install_tmux
    if [[ $install_tmux == [yY] ]]; then
        echo -e "$RESET$BOLD Installing tmux$RESET"
        brew install tmux
        echo -e "$RESET$BOLD Setting up tmux config$RESET$RED"
        ln -s ~/.dotfiles/.tmux.config ~/.tmux.config
        echo -e "$BOLD Tmux installation finished$RESET"
    fi

    # ==============
    # Install iTerm2
    # ==============
    echo -ne "$BOLD Install iTerm? (y/n): $RESET"
    read -p " " install_iTerm
    if [[ $install_iTerm == [yY] ]]; then
        echo -e "$RESET$BOLD Installing iTerm2$RESET"
        brew install --cask iterm2
        echo -e "$BOLD Tmux installation finished$RESET"
    fi

    # ====================
    # Install font Iosevka
    # ====================
    echo -ne "$BOLD Install font Iosevka? (y/n): $RESET"
    read -p " " install_iosevka
    if [[ $install_iosevka == [yY] ]]; then
        echo -e "$RESET$BOLD Installing Iosevka$RESET"
        brew tap homebrew/cask-fonts
        brew install --cask font-iosevka
        echo -e "$BOLD Iosevka installation finished$RESET"
    fi

    # ===============
    # Install ripgrep
    # ===============
    echo -ne "$BOLD Install ripgrep? (y/n): $RESET"
    read -p " " install_ripgrep
    if [[ $install_ripgrep == [yY] ]]; then
        echo -e "$RESET$BOLD Installing ripgrep$RESET"
        brew install ripgrep
        echo -e "$BOLD ripgrep installation finished$RESET"
    fi

    # ============
    # Install tree
    # ============
    echo -ne "$BOLD Install tree? (y/n): $RESET"
    read -p " " install_tree
    if [[ $install_tree == [yY] ]]; then
        echo -e "$RESET$BOLD Installing tree$RESET"
        brew install tree
        echo -e "$BOLD tree installation finished$RESET"
    fi

    # ============
    # Install nvim
    # ============
    echo -ne "$BOLD Install nvim? (y/n): $RESET"
    read -p " " install_nvim
    if [[ $install_nvim == [yY] ]]; then
        echo -e "$RESET$BOLD Installing nvim$RESET"
        brew install nvim
        echo -e "$RED$BOLD nvim is not configured yet to use vimrc."
        echo -e "$BOLD nvim installation finished$RESET"
    fi

    # ===========
    # Install fzf
    # ===========
    echo -ne "$BOLD Install fzf? (y/n): $RESET"
    read -p " " install_fzf
    if [[ $install_fzf == [yY] ]]; then
        echo -e "$RESET$BOLD Installing fzf$RESET"
        brew install fzf
        $(brew --prefix)/opt/fzf/install
        echo -e "$BOLD fzf installation finished$RESET"
    fi

    # ===========
    # Install bat
    # ===========
    echo -ne "$BOLD Install bat? (y/n): $RESET"
    read -p " " install_bat
    if [[ $install_bat == [yY] ]]; then
        echo -e "$RESET$BOLD Installing bat$RESET"
        brew install bat
        # TODO: Check if there's any default `bat` preferences that should be
        # set
        echo -e "$BOLD bat installation finished$RESET"
    fi
fi




# =====================
# Install rectangle.app
# =====================
echo -e "$RED$BOLD # Install rectangle.app not implemented yet"

# ==================
# Install Alfred.app
# ==================
echo -e "$RED$BOLD # Install alfred not implemented yet"

# =========================
# Set all MacOS preferences
# =========================
echo -e "$RED$BOLD # Set all MacOS preferences not implemented yet"
# 		- mouse sensitivity
# 		- dark mode
# 		- Dock hiding
# 		- Firefox as default browser

# ============================
# Reset colours back to normal
# ============================
echo -e "$RESET"
