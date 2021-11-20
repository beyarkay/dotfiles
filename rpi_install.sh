
echo -e "$RESET[D] Installing and setting up vim$RED"
sudo apt-get install vim && ln -s ~/.dotfiles/.vimrc ~/.vimrc
echo -e "$RESET"

echo -e "$RESET[D] Setting up zsh$RED"
sudo apt-get install zsh && chsh -s /bin/zsh && ln -s ./.zshrc ~/.zshrc
echo -e "$RESET"
