# Enable colours for macOS
export CLICOLOR=1
# Use linux-style colors
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Don't put duplicated lines, or lines starting with a space ' ' into the history
HISTCONTROL=ignoreboth


# Aliases
alias ll="ls -alhGF"
alias vims="vim -S"
alias clear="clear && ls -a"
command -v ls > /dev/null && alias ls='ls -aGFh'
command -v grep > /dev/null && alias grep='grep --color=auto'
command -v diff > /dev/null && alias diff='diff --color=auto'
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
local git_branch="$(git branch 2>/dev/null | colrm 1 2)"
local git_changes='$(if [[ $(git diff HEAD --name-only 2> /dev/null | wc -l) -ne 0 ]]; then echo "*"; fi)'
local git_string="$(if [[ -d .git ]]; then echo 'git exists'; else echo 'no git'; fi)"
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

PROMPT="%K{${BG_GREY}}%F{${FG_GREY}}╭─ %F{${FG_GREEN}}${time} %F{${FG_GREY}}${delta}%F{${FG_GREEN}} ${errors} %F{${FG_GREY}}| ssh %F{${FG_CYAN}}${host_machine} %F{${FG_GREY}}| git ${git_string} %F{${FG_TURQUOISE}}${git_branch}${git_changes} %F{${FG_GREY}}| cd %F{${FG_DEEPBLUE}}${curr_dir}%F{${FG_GREY}}"$'\n'"╰>%K{NO_BG}%F{WHITE} "
setopt promptsubst

