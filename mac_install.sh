#!/usr/bin/env bash
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

# ==============================================================================
# Set some preferences
# Heavily inspired by https://github.com/mathiasbynens/dotfiles/blob/main/.macos
# ==============================================================================

# Ask for the administrator password upfront
sudo -v

# Close any open System Preferences panes, to prevent them from overriding
# settings we're about to change
osascript -e 'tell application "System Preferences" to quit'

# Trackpad: enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

# Disable Notification Center and remove the menu bar icon
launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null

# Restart automatically if the computer freezes
sudo systemsetup -setrestartfreeze on

# Disable machine sleep while charging
sudo pmset -c sleep 0

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots to the desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Automatically open a new Finder window when a volume is mounted
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
chflags nohidden ~/Library && xattr -d com.apple.FinderInfo ~/Library

# Set the icon size of Dock items to 36 pixels
defaults write com.apple.dock tilesize -int 36

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "scale"

# Minimize windows into their application's icon
defaults write com.apple.dock minimize-to-application -bool true

# Wipe all (default) app icons from the Dock
# This is only really useful when setting up a new Mac, or if you don't use
# the Dock to launch apps.
defaults write com.apple.dock persistent-apps -array

# Show only open applications in the Dock
defaults write com.apple.dock static-only -bool true

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock Screen
# Top left and bottom right screen corner -> Desktop
defaults write com.apple.dock wvous-tl-corner -int 4
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 4
defaults write com.apple.dock wvous-br-modifier -int 0
# Top right and bottom left screen corner -> Lock
defaults write com.apple.dock wvous-tr-corner -int 13
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 13
defaults write com.apple.dock wvous-bl-modifier -int 0

# Install the OneHalfDark theme for iTerm
open "${HOME}/.dotfiles/OneHalfDark.itermcolors"

# Restart all the affected apps
for app in "cfprefsd" \
	"Dock" \
	"Finder" \
	"SystemUIServer" \
	"Terminal" \
	"iCal"; do
	killall "${app}" &> /dev/null
done

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
    #       0wveyA			# €:r !brew desc "kJdf:xj0
    #
    # For example: `    gh` -> `    gh     # GitHub command-line tool`
    brewable=( 
        bat         # Clone of cat(1) with syntax highlighting and Git integration
        fzf         # Command-line fuzzy finder written in Go
        gh          # GitHub command-line tool
        git         # Distributed revision control system
        jupyterlab  # Interactive environments for writing and running code
        nvim        # Ambitious Vim-fork focused on extensibility and agility
        node        # Platform built on V8 to build network applications
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
        alfred                 # Productivity manager
        arduino                # Arduino.cc platform
        firefox                # Web browser
        font-iosevka           # Monospace font with really nice ligatures
        freecad                # FOSS CAD software for 3D printing
        google-chrome          # Backup web browser for web scraping
        iterm2                 # Better Terminal.app replacement
        rectangle              # MacOS window tiling manager
        spotify                # Music player
        vlc                    # Video player
        whatsapp               # Instant messaging
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

    # nvim needs an init.vim in order for it to load the regular .vimrc
    if [ -x "$(command -v nvim)" ]; then
        echo -e "$RESET$BOLD Setting up nvim shortcuts$RESET$RED"
        mkdir -p ~/.config/nvim/
        ln -s ~/.dotfiles/init.vim ~/.config/nvim/init.vim
        # Also link the coc-settings
        ln -s ~/.dotfiles/coc-settings.json ~/.config/nvim/coc-settings.json
        exit_status=$?
        [ $exit_status -eq 0 ] && echo "$BOLD nvim config setup finished$RESET" || echo "$BOLD nvim config setup has$RED failed $RESET"
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
