# =============================
# Zshrc - configuration for zsh
# =============================
source ~/.dotfiles/define_colours.sh

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
    brew install coreutils
    alias date='gdate -u +"%Y-%m-%dT%H:%M:%SZ"'
else
    alias date='date -u +"%Y-%m-%dT%H:%M:%SZ"'
fi

# TODO These history related commands might only work for zsh
# Immediately append commands to the history file, to allow for easier history
# searching
#s etopt inc_append_history
# Include the timestamp in the history file
# export HISTTIMEFORMAT="[%F %T] "
# Don't include duplicated lines in the history file
# setopt HIST_IGNORE_ALL_DUPS
# There's no reason to have a limit to the history size
# export HISTFILESIZE=100000
# export HISTSIZE=100000

# Use exa instead of tree
alias tree="exa --tree -lFa --git --ignore-glob=.git"
# Search for all TODOs / FIXMEs from the current directory
alias gtd="grep -ri --exclude-dir=build --exclude-dir=.git -E \"(TODO|FIXME)\" *"
# List long showing filetypes, all files, and git info
alias ll="exa --long --classify --all --git --time-style=long-iso"
# List just the simple things
alias ls="COLUMNS=80 exa --classify --all"
# Always include colours for grep
alias grep='grep --color=auto'
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
local FG_RED='160'
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


# Setup a timer variable so that we can see how long the previous command took
# function preexec() {
#     if [ -x "$(command -v gdate)" ]; then
#         timer=$(($(\gdate +%s%0N)/1000000))
#     else
#         timer=$(($(\date +%s%0N)/1000000))
#     fi
# }

# `precmd()` is called before the prompt is displayed. This is used to customise the prompt and update it each time.
function precmd() {
    # local errors='$(code=$?; if [[ $code -gt 0 ]]; then echo "%F{${FG_RED}}✘ $code"; else echo "✔"; fi)'
    # if [ $timer ]; then
    #     if [ -x "$(command -v gdate)" ]; then
    #         now=$(($(\gdate +%s%0N)/1000000))
    #     else
    #         now=$(($(\date +%s%0N)/1000000))
    #     fi
    #     m=''
    #     s=''
    #     ms=$(($now-$timer))
    #     m_unit=''
    #     s_unit=''
    #     ms_unit='ms'
    #     if [ $ms -ge 1000 ]; then
    #         s=$(($ms/1000))
    #         ms=$(($ms%1000))
    #         s_unit='s '
    #     fi
    #     if [ $s -ge 60 2>/dev/null ]; then
    #         m=$(($s/60))
    #         s=$(($s%60))
    #         m_unit='m '
    #     fi
    #     rprompt="%F{${FG_GREY}}"
    #     rprompt+="${m}${m_unit}"
    #     rprompt+="${s}${s_unit}"
    #     rprompt+="${ms}${ms_unit}"
    #     rprompt+="%F{${FG_GREEN}} ${errors}"
    #     rprompt+="%F{${FG_GREY}}"
    #     rprompt+="%{$reset_color%}"

    #     export RPROMPT=$rprompt
    #     unset timer
    # fi

    # prmpt="%K{${BG_GREY}}"
    # prmpt+="%F{${FG_RED}}"
    # NEWLINE=$'\n'
    # prmpt+=$(ps aux | awk 'NR==2{if($3>=80.0) print "kill " $2 " (" $3 "%% " $11 ")${NEWLINE}"}')
    # prmpt+="%F{${FG_ORANGE}}"
    # prmpt+=$(ps aux | awk 'NR==2{if($3>=60.0) print "kill " $2 " (" $3 "%% " $11 ")${NEWLINE}"}')
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
    # ======================================================
    local git_branch=''
    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
        local git_colour=''
        local git_untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | xargs)
        local git_unstaged=$(git diff --numstat 2>/dev/null | wc -l | xargs)
        local git_uncommitted=$(git diff --numstat --staged 2>/dev/null | wc -l | xargs)
        local git_unpushed=$(git log @{push}.. --oneline 2>/dev/null | wc -l | xargs)
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
        git_branch=" ($git_colour%F{$FG_GREY}$(git branch --show-current 2>/dev/null)"
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
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# First look for history items, then look for zsh-completion items
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^n' autosuggest-accept

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
zle     -N            fzf-cd-widget
bindkey -M emacs '^Q' fzf-cd-widget
bindkey -M vicmd '^Q' fzf-cd-widget
bindkey -M viins '^Q' fzf-cd-widget
# Rebind the file-finder widget to ^G
zle     -N            fzf-file-widget
bindkey -M emacs '^G' fzf-file-widget
bindkey -M vicmd '^G' fzf-file-widget
bindkey -M viins '^G' fzf-file-widget

# Enable floating tmux window for fzf searches
FZF_TMUX_OPTS='-p80%,60%'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/brk/.miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/brk/.miniforge3/etc/profile.d/conda.sh" ]; then
        . "/Users/brk/.miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/brk/.miniforge3/bin:$PATH"
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

# Define some extra aliases
alias gs="git status"
alias gc="git commit -m "
alias ga="git add"
alias gap="git add -p"
alias gd="git dag"
alias G="git"

[ -f "/Users/brk/.ghcup/env" ] && source "/Users/brk/.ghcup/env" # ghcup-envexport PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm@12/bin:$PATH"

test -d "$HOME/.tea" && source <("$HOME/.tea/tea.xyz/v*/bin/tea" --magic=zsh --silent)

# https://atuin.sh/
eval "$(atuin init zsh --disable-up-arrow)"
