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


# Aliases
alias date='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias ll="ls -atlhGF"
alias vims="vim -S"
alias clear="clear && ls -a"
alias grep='grep -n --color=auto'
alias diff='diff --color=auto'
export EDITOR=vim
export VISUAL=vim
export PATH=$PATH:~/drivers/chromedriver

# Colour the man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Advanced directory creation
function mkcd {
  if [ ! -n "$1" ]; then
    echo "No directory name given"
  elif [ -d $1 ]; then
    echo "Directory '$1' already exists"
  else
    mkdir $1 && cd $1
  fi
}


# ls after a cd
function cd() {
 builtin cd "$*" && ls -a
}

# Setup the prompt
local time='%*'
local host_machine='%n@%M'
local delta='_._ms'
local curr_dir='%~' 
local BG_GREY='236'
local FG_GREY='244'
local FG_GREEN='46'
local FG_CYAN='51'
local FG_TURQUOISE='39'
local FG_DEEPBLUE='27'
local NO_BG='234'
local WHITE='255'
local FG_RED='196'
local errors='$(code=$?; if [[ $code -gt 0 ]]; then echo "%F{${FG_RED}}✘ $code"; else echo "✔"; fi)'

function preexec() {
  timer=$(($(\date +%s%0N)/1000000))
}

function precmd() {
  if [ $timer ]; then
    now=$(($(\date +%s%0N)/1000000))
    s=''
    ms=$(($now-$timer))
    s_unit=''
    ms_unit='ms'
    if [ $ms -gt 999 ]; then
        s=$(($ms/1000))
        ms=$(($ms%1000))
        s_unit='s '
    fi

    export RPROMPT="%F{${FG_GREY}}${s}${s_unit}${ms}${ms_unit}%F{${FG_GREEN}} ${errors} %F{${FG_GREY}}%{$reset_color%}"
    unset timer
  fi

  local git_branch=''
  local git_changes=''
  local git_string=''
  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
      git_branch="$(git branch 2>/dev/null | colrm 1 2)"
      git_changes='$(if [[ $(git diff HEAD --name-only 2> /dev/null | wc -l) -ne 0 ]]; then echo "*"; fi)'
      git_string='| git '
      
  fi
  PROMPT="%K{${BG_GREY}}%F{${FG_GREY}}╭─ %F{${FG_GREEN}}${time} %F{${FG_GREY}}| ssh %F{${FG_CYAN}}${host_machine}%F{${FG_GREY}}${git_string}%F{${FG_TURQUOISE}}${git_branch}${git_changes} %F{${FG_GREY}}| cd %F{${FG_DEEPBLUE}}${curr_dir}%F{${FG_GREY}}"$'\n'"╰>%K{NO_BG}%F{WHITE} "
}

PROMPT="%K{${BG_GREY}}%F{${FG_GREY}}╭─ %F{${FG_GREEN}}${time} %F{${FG_GREY}}| ssh %F{${FG_CYAN}}${host_machine}%F{${FG_GREY}}${git_string}%F{${FG_TURQUOISE}}${git_branch}${git_changes} %F{${FG_GREY}}| cd %F{${FG_DEEPBLUE}}${curr_dir}%F{${FG_GREY}}"$'\n'"╰>%K{NO_BG}%F{WHITE} "
setopt promptsubst

# Enable zsh Autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
