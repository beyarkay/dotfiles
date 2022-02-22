# .zshenv is run by zsh when any zsh is started, whether it is interactive
# (like in iTerm2) or not (like via `ssh`)

# ===========================
# Setup the PATH env variable
# ===========================
# vim is installed to /opt/local/bin
export PATH="/opt/local/bin:$PATH"
# Need to include node in our path
export PATH="/usr/local/opt/node@14/bin:$PATH"
export PATH=$PATH:~/drivers/chromedriver


# =================================
# Set the default editor to be nvim
# =================================
if [ -x "$(command -v nvim)" ]; then
    export EDITOR=nvim
    export VISUAL=nvim
else
    export EDITOR=vim
    export VISUAL=vim
fi

