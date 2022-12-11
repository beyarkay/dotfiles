
echo -e "$RESET[D] Installing and setting up vim$RED"
sudo apt-get install vim && ln -s ~/.dotfiles/.vimrc ~/.vimrc
echo -e "$RESET"

echo -e "$RESET[D] Setting up zsh$RED"
sudo apt-get install zsh && chsh -s /bin/zsh && ln -s ./.zshrc ~/.zshrc && echo "$RESET $BOLD[I] Zsh setup successfully, relogin to realise changes $RED"
echo -e "$RESET"

echo -e "$RESET[D] Setting up github client$RED"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
echo -e "$RESET"

echo -e "$RESET[D] Setting up node$RED"
sudo apt install node && echo "$RESET $BOLD[I] Node setup successfully.$RED"
echo -e "$RESET"

echo -e "$RESET[D] Setting up ripgrep$RED"
sudo apt install ripgrep && echo "$RESET $BOLD[I] ripgrep setup successfully.$RED"
echo -e "$RESET"

echo -e "$RESET[D] Setting up fzf$RED"
sudo apt install fzf && echo "$RESET $BOLD[I] fzf setup successfully.$RED"
echo -e "$RESET"

echo -e "$RESET[D] Setting up bat$RED"
sudo apt install bat && mkdir -p ~/.local/bin && ln -s /usr/bin/batcat ~/.local/bin/bat && echo "$RESET $BOLD[I] bat setup successfully.$RED"
echo -e "$RESET"

