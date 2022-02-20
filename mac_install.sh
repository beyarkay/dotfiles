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
echo -ne "$BOLD Set zsh to default shell? (y/n): $RESET"
read -p " " set_zsh
if [[ $set_zsh == [yY] ]]; then
    echo -e "$RESET[D] Sudo-ing to make zsh default shell$RESET$RED"
    sudo sh -c "echo $(which zsh) >> /etc/shells" && chsh -s $(which zsh)
    echo -e "$RESET"
fi

echo -ne "$BOLD Install zsh plugins? (y/n): $RESET"
read -p " " set_zsh
if [[ $set_zsh == [yY] ]]; then
    echo -e "$RESET[D] Installing zsh plugins$RESET$RED"
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
    echo -e "$RESET"
fi



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
    echo "homebrew exists, installing things via brew"
    # This is a Vim macro to convert a brew command to brew command +
    # description. The cursor can start anywhere on a line containing only the
    # command which should be preceeded by some whitespace:
    #
    #       0wveyA			# €ýa:r !brew desc "kJdf:xj0
    #
    # For example: `    gh` -> `    gh     # GitHub command-line tool`
    brewable=( 
        bat         # Clone of cat(1) with syntax highlighting and Git integration
        fzf         # Command-line fuzzy finder written in Go
        gh          # GitHub command-line tool
        git         # Distributed revision control system
        nvim        # Ambitious Vim-fork focused on extensibility and agility
        pandoc      # Swiss-army knife of markup format conversion
        ripgrep     # Search tool like grep and The Silver Searcher
        tmux        # Terminal multiplexer
        tree        # Display directories as trees (with optional color/HTML output)
    )
    # For each brew installable item:
    for b in "${brewable[@]}"
    do
        # Check if it's already installed
        if [ -x "$(command -v $b)" ]; then
            # Ask if it should be re-installed
            echo -ne "$b is already installed. Would you like to re-install?"
            read -p " " should_install
            if [[ $should_install == [yY] ]]; then
                echo -ne "First uninstalling $b..."
                brew uninstall $b
            fi
        else
            # Ask if the command should be installed from scratch
            echo -ne "Would you like to install $BOLD$(brew desc $b)$RESET? (y/n): "
            read -p " " should_install
        fi
        if [[ $should_install == [yY] ]]; then
            echo -e "$RESET Installing $BOLD$b$RESET..."
            brew install $b
            exit_status=$?
            [ $exit_status -eq 0 ] && echo "$BOLD$GREEN$b installation has finished$RESET" || echo "$BOLD $b installation has$RED failed $RESET"
            echo -e "See $BOLD$(brew info $b | egrep '^http')$RESET for details about $b"
        fi
    done



    # ==================================================================
    # Some commands are installed with `brew install --cask $cask_name`.
    # Install those packages now.
    # ==================================================================
    caskable=(
        alfred
        freecad
        iterm2
        font-iosevka
        rectangle
        firefox
    )
    for c in "${caskable[@]}"
    do
        # Check if it's already installed
        if [ -x "$(command -v $c)" ]; then
            # Ask if it should be re-installed
            echo -ne "$c is already installed. Would you like to re-install?"
            read -p " " should_install
            if [[ $should_install == [yY] ]]; then
                echo -ne "First uninstalling $c..."
                brew uninstall $c
            fi
        else
            # Ask if the command should be installed from scratch
            echo -ne "Would you like to install $BOLD$c$RESET? (y/n): "
            read -p " " should_install
        fi
        if [[ $should_install == [yY] ]]; then
            echo -e "$RESET Installing $BOLD$c$RESET..."
            # TODO this equality checking might not work
            if [[ $c == "font-iosevka" ]]; then
                brew tap homebrew/cask-fonts
            fi
            brew install --cask $c
            exit_status=$?
            [ $exit_status -eq 0 ] && echo "$BOLD$GREEN$c installation has finished$RESET" || echo "$BOLD $c installation has$RED failed $RESET"
            echo -e "See $BOLD$(brew info $c | egrep '^http')$RESET for details about $c"
        fi
    done

    # =======================================================================
    # Some commands require custom setup / config. If they're installed, then
    # do that custom setup.
    # =======================================================================

    # Link ~/.dotfiles/.tmux.config
    if [ -x "$(command -v tmux)" ]; then
        echo -e "$RESET$BOLD Setting up tmux config$RESET$RED"
        ln -s ~/.dotfiles/.tmux.config ~/.tmux.config
        exit_status=$?
        [ $exit_status -eq 0 ] && echo "$BOLD Tmux config setup finished$RESET" || echo "$BOLD Tmux config setup has$RED failed $RESET"
    fi

    # fzf requires an installation script
    if [ -x "$(command -v fzf)" ]; then
        echo -e "$RESET$BOLD Setting up fzf shortcuts$RESET$RED"
        $(brew --prefix)/opt/fzf/install
        exit_status=$?
        [ $exit_status -eq 0 ] && echo "$BOLD fzf config setup finished$RESET" || echo "$BOLD fzf config setup has$RED failed $RESET"
    fi

    # Rectangle has some custom preferences that can automatically setup
    if [ -x "$(command -v rectangle)" ]; then
        echo -e "$RESET$BOLD Setting up rectangle preferences$RESET$RED"
        cp ~/.dotfiles/rectanglePreferences.plist ~/Library/Preferences/com.knollsoft.Rectangle.plist
        exit_status=$?
        [ $exit_status -eq 0 ] && echo "$BOLD rectangle config setup finished$RESET" || echo "$BOLD rectangle config setup has$RED failed $RESET"
    fi
fi
# =========================
# Set all MacOS preferences
# =========================
echo -e "$RED$BOLD # Set all MacOS preferences not implemented yet"
# 		- mouse sensitivity
# 		- Dock hiding and not having permanent icons
# 		- Firefox as default browser
#       - menu bar being better
#       - caps lock -> ctrl

# Save and restore Alfred preferences
# Reset colours back to normal
echo -e "$RESET"
