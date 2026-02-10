# =============================
# Zshrc - configuration for zsh
# =============================
[ -f ~/.dotfiles/define_colours.sh ] && source ~/.dotfiles/define_colours.sh

export TERM=xterm-256color
# Enable colours for macOS
export CLICOLOR=1

# Use linux-style colors
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Don't put duplicated lines, or lines starting with a space ' ' into the history
HISTCONTROL=ignoreboth

# Use ESC to edit the current command line:
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^[' edit-command-line
bindkey '^e' edit-command-line

# Wait only 10ms before for additional characters in an escape sequence
KEYTIMEOUT=1

# Aliases for commonly used commands

# `date` isn't consistent across MacOS and *nix, so create an alias to make it
# so
if [ -x "$(command -v gdate)" ]; then
    # Install gdate (required to get ms precision on MacOS)
    # brew install coreutils
    alias date='gdate -u +"%Y-%m-%dT%H:%M:%SZ"'
else
    alias date='date -u +"%Y-%m-%dT%H:%M:%SZ"'
fi

if command -v eza &>/dev/null; then
    alias tree="eza --tree -lFa --git --ignore-glob=.git"
    alias ll="eza --long --classify --all --git --time-style=long-iso"
    alias ls="COLUMNS=80 eza --classify --all"
else
    alias ll="ls -alhF"
    alias ls="ls -aF"
fi
# Search for all TODOs / FIXMEs from the current directory
alias gtd="grep -ri --exclude-dir=build --exclude-dir=.git -E \"(TODO|FIXME)\" *"
# Always include colours and line numbers for grep
alias grep='grep -n --color=auto'
# Show diskfree with human-readable numerals
alias df='df -h'
# Calculate total disk usage for a folder, in human readable numbers
alias du='du -h -c'
# Disallow easy footguns
alias rm="echo Use 'del', or the full path i.e. '/bin/rm'"
# Fat fingers
alias gf="fg"


# =================================
# Add colours to the less/man pages
# =================================
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'


# -----------------------------------------------------------------------------
# Super handy: After changing directory, list the contents of that directory
# Note that if there's an absurd number of files in a directory, this will list
# them all which can be annoying if you're often changing in and out of it
# -----------------------------------------------------------------------------
function cd() {
    builtin cd "$*" && ls
}


# Setup colours and variables for the prompt
local BG_GREY='236'
local FG_ORANGE='208'
local FG_YELLOW='226'
local FG_LIGHTGREY='251'
local FG_GREY='244'
local FG_DARKGREY='238'
local FG_GREEN='46'
local FG_CYAN='51'
local FG_TURQUOISE='39'
local FG_DEEPBLUE='75'
local NO_BG='234'
local WHITE='255'
local FG_RED='196'


# =============================================================================
# Calculate a short-form of pwd, where instead of /User/boyd/Documents you have
# /U/b/Documents in order to save space
# =============================================================================
function short_pwd {
    directories=(${(s:/:)PWD})

    shortened_path=""
    for ((i = 0; i <= ${#directories[@]}; ++i)); do
        directory=${directories[$i]}
        if [ $i = ${#directories} ]; then
            # The final directory in the path should be left as-is, unshortened
            shortened_path+="%F{$FG_LIGHTGREY}${directory}%F{$FG_GREY}"
        else
            # Set the shortened path to be just the first character of the
            # current directory
            shortened_path+="${directory:0:1}/"
        fi
    done
    echo "${shortened_path}"
}


# `precmd()` is called before the prompt is displayed. This is used to customise the prompt and update it each time.
function precmd() {
    local curr_time='%*'

    # ===================================================================
    # If there are any jobs which are stopped or in the background, add a
    # little symbol to the prompt
    # ===================================================================
    # Use `... | xargs` to trim whitespace:
    # https://stackoverflow.com/a/12973694/14555505
    local stopped_jobs=''
    local running_jobs=''
    # Check if there are any stopped jobs
    if [[ "$(jobs -sp | wc -l | xargs)" != "0" ]]; then
        stopped_jobs+="$(jobs -sp | wc -l | xargs)s"
    fi
    # Check if there are any running jobs
    if [[ "$(jobs -rp | wc -l | xargs)" != "0" ]]; then
        running_jobs+="$(jobs -rp | wc -l | xargs)r"
    fi
    local job_string="$stopped_jobs$running_jobs"
    if [[ ${#job_string} -gt 0 ]]; then
        job_string=" $job_string"
    fi

    # ============================================================
    # Add some identification of the current machine to the prompt
    # ============================================================
    local host_machine="{%F{${FG_CYAN}}$(hostname)%F{$FG_GREY}}"
    local need_kinit=''
    local need_mwinit=''
    brk_whoami=(brk boydkane boydrkane)
    aws_whoami=(boydkane)
    mbp2022_hostnames=(Boyds-MacBook-Pro-2022.local Boyds-MBP-2022)
    mbp2012_hostnames=(Boyds-MacBook-Pro-2012.local Boyds-MBP-2012)

    # whoami \in [brk, boydrkane] && hostname \in [mbp2022]
    if (($brk_whoami[(Ie)$(whoami)])) && (($mbp2022_hostnames[(Ie)$(hostname)])); then
        host_machine="{%F{${FG_CYAN}}mbp%F{$FG_GREY}}"
    # whoami \in [aws-login]
    elif (($aws_whoami[(Ie)$(whoami)])); then
        # Probably an aws machine
        AWS_FILE="$HOME/.dotfiles/aws_setup.sh"
        if [ -f $AWS_FILE ]; then
            source ~/.dotfiles/aws_setup.sh
        fi
        host_machine="{%F{${FG_CYAN}}aws%F{$FG_GREY}}"
    # whoami \in [brk, boydrkane] && hostname \in [mbp2012]
    elif (($brk_whoami[(Ie)$(whoami)])) && (($mbp2012_hostnames[(Ie)$(hostname)])); then
        host_machine="{%F{${FG_CYAN}}mbp2012%F{$FG_GREY}}"
    fi

    # ======================================================
    # If we are inside a git repo, then show git branch info
    # Uses a single `git status` call instead of separate
    # ls-files, diff, diff --staged, and branch commands.
    # ======================================================
    local git_branch=''
    local git_porcelain
    git_porcelain=$(git --no-optional-locks status --porcelain -b 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local -a git_lines=("${(@f)git_porcelain}")

        # Extract branch from header: "## branch...remote" or "## branch"
        local branch_name=${git_lines[1]#\#\# }
        branch_name=${branch_name%%...*}
        branch_name=${branch_name%% \[*}
        shift git_lines

        # Count statuses using zsh array filtering (no subprocesses)
        local git_untracked=${#${(M)git_lines:#\?\?*}}
        local git_unstaged=${#${(M)git_lines:#?[MTDAU]*}}
        local git_uncommitted=${#${(M)git_lines:#[MTADRC]*}}
        local git_unpushed=$(git rev-list --count @{push}..HEAD 2>/dev/null || echo 0)

        local git_colour=''
        # Check for untracked files
        if [[ $git_untracked -gt 0 ]]; then
            git_colour+="%F{${FG_LIGHTGREY}}t$git_untracked"
        fi
        # Check for unstaged changes, fixed by `git add ...`
        if [[ $git_unstaged -gt 0 ]]; then
            git_colour+="%F{${FG_YELLOW}}a$git_unstaged"
        fi
        # Check for uncommitted changes, fixed by `git commit`
        if [[ $git_uncommitted -gt 0 ]]; then
            git_colour+="%F{${FG_ORANGE}}c$git_uncommitted"
        fi
        # Check for unpushed commits, fixed by `git push`
        if [[ $git_unpushed -gt 0 ]]; then
            git_colour+="%F{${FG_RED}}p$git_unpushed"
        fi
        # Only add trailing white space if we've actually got something in
        # `git_colour`
        if [[ ${#git_colour} -gt 0 ]]; then
            git_colour="$git_colour "
        fi
        # ========================================
        # Add the current git branch to the prompt
        # ========================================
        git_branch=" ($git_colour%F{$FG_GREY}${branch_name}"
        git_branch+="%F{$FG_GREY})"
    fi

    # ===========================================================================
    # Collect all the variables together for the prompt and give them some colour
    # ===========================================================================
    prompt="%F{${FG_GREY}}%K{${BG_GREY}}"
    prompt+="╭ ${curr_time}"
    prompt+="${job_string}"
    prompt+=" ${host_machine}"
    if [[ ${#need_mwinit} -gt 0 ]]; then
        prompt+=" ${need_mwinit}"
    fi
    if [[ ${#need_kinit} -gt 0 ]]; then
        prompt+=" ${need_kinit}"
    fi
    prompt+=" $(short_pwd)"
    prompt+="${git_branch}"
    prompt+="%F{${FG_GREY}}"$'\n'"╰→"
    prompt+="%K{NO_BG}%F{WHITE} "
    export PROMPT=$prompt
}


setopt promptsubst

# ==========================
# Enable zsh Autosuggestions
# ==========================
if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    # First look for history items, then look for zsh-completion items
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    bindkey '^n' autosuggest-accept
fi

# ===========================
# Fzf options and preferences
# ===========================
# Default options to use with fzf
export FZF_COMPLETION_OPTS="--reverse --height 40% --multi --border"
export FZF_DEFAULT_COMMAND='rg --files'
alias fz="fzf --layout=reverse --height 40% --multi --border --preview 'bat --color=always --style=numbers --line-range=:500 {}'"

export FZF_CTRL_T_OPTS="
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Print tree structure in the preview window
# export FZF_ALT_C_COMMAND="^Q"
export FZF_ALT_C_OPTS="--preview 'tree -C {}'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# Unbind ^Q and ^S (which usually start/stop the terminal) so they can be used
# elsewhere. They never worked for me anyway.
# https://stackoverflow.com/a/16728429/14555505
stty start '^-' stop '^-'
# Rebind the cd widget to ^q instead of alt-c
# NOTE: these lines MUST come after `source ~/.fzf.zsh`
if (( $+functions[fzf-cd-widget] )); then
    zle     -N            fzf-cd-widget
    bindkey -M emacs '^Q' fzf-cd-widget
    bindkey -M vicmd '^Q' fzf-cd-widget
    bindkey -M viins '^Q' fzf-cd-widget
fi
# Rebind the file-finder widget to ^G
if (( $+functions[fzf-file-widget] )); then
    zle     -N            fzf-file-widget
    bindkey -M emacs '^G' fzf-file-widget
    bindkey -M vicmd '^G' fzf-file-widget
    bindkey -M viins '^G' fzf-file-widget
fi

# Enable floating tmux window for fzf searches
FZF_TMUX_OPTS='-p80%,60%'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/.miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/.miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/.miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/.miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# ======================================================
# Auto-expand globs, aliases, and other shell expansions
# ======================================================
# This autoload fix is needed to get the _expand-alias function: https://stackoverflow.com/a/61653489/14555505
autoload -Uz compinit && compinit
# This function and related setup comes from:
# https://blog.patshead.com/2012/11/automatically-expaning-zsh-global-aliases---simplified.html
globalias() {
   zle _expand_alias
   zle self-insert
}
zle -N globalias
bindkey " " globalias
# control-space to bypass completion
bindkey "^ " magic-space
# normal space during searches
bindkey -M isearch " " magic-space

# Define some extra aliases for git
alias gs="git status"
alias gc="git commit -m "
alias ga="git add"
alias gap="git add -p"
alias gdag="git dag"
alias gd="git diff"
alias g="git"
alias n="nvim"
alias v="nvim"

# And an alias to find raspberry pi's on the local network
# https://superuser.com/a/872218/1716125
alias rpi="arp -a | grep b8:27:eb"

[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env" # ghcup-env
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm@12/bin:$PATH"

test -d "$HOME/.tea" && source <("$HOME/.tea/tea.xyz/v*/bin/tea" --magic=zsh --silent)

# https://atuin.sh/
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
# END opam configuration

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias hive-mind='bun $HOME/.claude/plugins/cache/alignment-hive/hive-mind/0.1.22/cli.js'
