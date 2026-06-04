# `brew shellenv` costs ~20ms per login shell (every new tmux pane pays it).
# Its output is static, so cache it and just source the cache. Delete
# ~/.cache/brew-shellenv.zsh (or run `brew shellenv > ...`) after a brew upgrade
# if the format ever changes.
if [[ ! -r ~/.cache/brew-shellenv.zsh ]]; then
    mkdir -p ~/.cache
    /opt/homebrew/bin/brew shellenv > ~/.cache/brew-shellenv.zsh
fi
source ~/.cache/brew-shellenv.zsh

# Setting PATH for Python 3.7
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.7/bin:${PATH}"
export PATH

# Setting PATH for Python 3.10
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.10/bin:${PATH}"
export PATH
