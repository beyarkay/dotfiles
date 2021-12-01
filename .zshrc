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
bindkey '\033' edit-command-line

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

# Search for all TODOs / FIXMEs from the current directory
alias gtd="grep -ri --exclude-dir=build --exclude-dir=.git -E \"(TODO|FIXME)\" *"
# =================================================
# AWS-specific aliases and related exports
# TODO these should only be loaded for AWS machines
# =================================================
export PATH=$PATH:~/.toolbox/bin
export PATH="/apollo/env/envImprovement/bin:$PATH"
export JAVA_HOME=$(/usr/libexec/java_home)
alias brc="brazil-recursive-cmd"
alias bb="brazil-build"
alias bbr="brazil-build release"
# List-long: ls with colours, long format, human readable, all files
alias ll="ls -AlhGF"
# Clear the terminal and ls files in the current directory, excluding the . and
# .. directories
alias clear="clear && ls -A"
# Always include colours and line numbers for grep
alias grep='grep -n --color=auto'
# Show diskfree with human-readable numerals
alias df='df -h'
# Calculate total disk usage for a folder, in human readable numbers
alias du='du -h -c'

# ================================
# Set the default editor to be vim
# ================================
export EDITOR=vim
export VISUAL=vim

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

# I never ended up using this shortcut, delete me after 2022-01-01
# # Advanced directory creation
# function mkcd {
#   if [ ! -n "$1" ]; then
#     echo "No directory name given"
#   elif [ -d $1 ]; then
#     echo "Directory '$1' already exists"
#   else
#     mkdir $1 && cd $1
#   fi
# }


# -----------------------------------------------------------------------------
# Super handy: After changing directory, list the contents of that directory
# Note that if there's an absurd number of files in a directory, this will list
# them all which can be annoying if you're often changing in and out of it
# -----------------------------------------------------------------------------
function cd() {
    builtin cd "$*" && ls -a
}


# Setup colours and variables for the prompt
local BG_GREY='236'
local FG_RED='160'
local FG_ORANGE='208'
local FG_YELLOW='226'
local FG_LIGHTGREY='251'
local FG_GREY='244'
local FG_DARKGREY='238'
local FG_AWS_GREEN='40'
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

    shortened_path="/"
    for directory in ${directories[@]}
    do
        if [ $directory = ${directories[-1]} ]; then
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
    local host_machine=''
    if [[ "$(whoami)@$(hostname)" == "boydkane@Boyds-MBP" ]]; then
        host_machine+='{mbp}'
    elif [[ "$(hostname)" == "3c22fbbbc8c1.ant.amazon.com" ]]; then
        host_machine+="{%F{${FG_AWS_GREEN}}aws%F{$FG_GREY}}"
    else 
        host_machine+="{%F{${FG_CYAN}}$(hostname)%F{$FG_GREY}}"
    fi

    # ======================================================
    # If we are inside a git repo, then show git branch info
    # ======================================================
    local git_branch=''
    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
        local git_colour=''
        local git_unstaged=$(git diff --numstat 2>/dev/null | wc -l | xargs)
        local git_uncommitted=$(git diff --numstat --staged 2>/dev/null | wc -l | xargs)
        local git_unpushed=$(git log @{push}.. --oneline 2>/dev/null | wc -l | xargs)
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
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# ===========================
# Setup the PATH env variable
# ===========================
# vim is installed to /opt/local/bin
export PATH="/opt/local/bin:$PATH"
export PATH=$PATH:~/drivers/chromedriver
