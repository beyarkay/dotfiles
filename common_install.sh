#!/bin/bash
source define_colours.sh
echo -e "$BOLD[I] Installing and setting up OS-generic tools$RESET$RED"

echo -e "$RESET[D] Setting up git and github$RED"
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/.gitmessage ~/.gitmessage
echo -e "$RESET"
echo -e "$RESET[D] Setting up bash_profile$RED"
ln -s ~/.dotfiles/.bash_profile ~/.bash_profile
echo -e "$RESET"

echo -e "$BOLD[I] Figuring out which OS we're on, OS TYPE is '$OSTYPE'$RESET"
# Figure out which OS we're in, and perform OS-specific setup scripts
# Source: https://stackoverflow.com/a/8597411/14555505
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    echo -e "$BOLD[I] Installing MacOS specific tools$RESET"
    source mac_install.sh
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Raspberry Pi and possibly others
    echo -e "$BOLD[I] Installing Raspberry Pi specific tools$RESET"
    source rpi_install.sh
else
    echo -e "$ORANGE[W] Your OSTYPE is '$OSTYPE' but there's no special handling for it$RESET"
    # Unknown.
fi



