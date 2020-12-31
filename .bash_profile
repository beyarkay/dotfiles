 # Only execute if running interactively
[ -z "$PS1" ] && return

# Don't put duplicated lines, or lines starting with a space ' ' into the history
HISTCONTROL=ignoreboth


# Command Prompt
# Use a timer for the previous command

function timer_now {
    date +%s%N
}
function timer_start {
    timer_start=${timer_start:-$(timer_now)}
}
function timer_stop {
#    EXIT="$?" # MUST come first
    # From https://stackoverflow.com/questions/1862510/how-can-the-last-commands-wall-time-be-put-in-the-bash-prompt
    local delta_us=$((($(timer_now) - $timer_start) / 1000))
    local us=$((delta_us % 1000))
    local ms=$(((delta_us / 1000) % 1000))
    local s=$(((delta_us / 1000000) % 60))
    local m=$(((delta_us / 60000000) % 60))
    local h=$((delta_us / 3600000000))
    # Goal: always show around 3 digits of accuracy
    if ((h > 0)); then timer_show=${h}h${m}m
    elif ((m > 0)); then timer_show=${m}m${s}s
    elif ((s >= 10)); then timer_show=${s}.$((ms / 100))s
    elif ((s > 0)); then timer_show=${s}.$(printf %03d $ms)s
    elif ((ms >= 100)); then timer_show=${ms}ms
    elif ((ms > 0)); then timer_show=${ms}.$((us / 100))ms
    else timer_show=${us}us
    fi
    unset timer_start
}
set_prompt () {
    # Designed on https://scriptim.github.io/bash-prompt-generator/
    EXIT=$?
    timer_stop
    PS1='\[\e[0m\]\[\e[0;38;5;244;48;5;236m\]╭─ \[\e[0;38;5;40;48;5;236m\]\t\[\e[0;3;38;5;244;48;5;236m\]'
    PS1+=' ${timer_show} '
    if [[ $EXIT -gt 0 ]]; then
        PS1+="\[\e[0;38;5;197;48;5;236m\]✘ \[\e0${EXIT}" # red x with error status
    else
        PS1+="\[\e[0;38;5;40;48;5;236m\]✔\[\e0" # green tick
    fi
    PS1+='\[\e[0;3;38;5;244;48;5;236m\] | ssh \[\e[0;38;5;44;48;5;236m\]\u\[\e[0;38;5;44;48;5;236m\]@\[\e[0;38;5;44;48;5;236m\]\h\[\e[0;3;38;5;244;48;5;236m\]'
    PS1+='$([ -d .git ] && echo " | git ")\[\e[0;38;5;38;48;5;236m\]$(git branch 2>/dev/null | grep '"'"'^*'"'"' | colrm 1 2)'
    PS1+='\[\e[0;38;5;38;48;5;236m\]'
    PS1+='$(if [[ $(git diff HEAD --name-only 2> /dev/null | wc -l) -ne 0 ]]; then echo "*"; fi)'
    PS1+='\[\e[0;3;38;5;244;48;5;236m\] | cd \[\e[0;38;5;33;48;5;236m\]\w\[\e[m\]\n\[\e[0;38;5;244;48;5;236m\]╰> \[\e[0;38;5;244;48;5;236m\]\$\[\e[0m\] \[\e0'
}
trap 'timer_start' DEBUG
PROMPT_COMMAND='set_prompt'

# export PS1
# export PS1='\[\e[0m\]\[\e[0;38;5;244;48;5;236m\]╭─ \[\e[0;38;5;40;48;5;236m\]\t\[\e[0;3;38;5;244;48;5;236m\] (${timer_show}) | \[\e[0;38;5;44;48;5;236m\]\u\[\e[0;38;5;44;48;5;236m\]@\[\e[0;38;5;44;48;5;236m\]\h\[\e[0;3;38;5;244;48;5;236m\]$([ -d .git ] && echo " | git ")\[\e[0;38;5;38;48;5;236m\]$(git branch 2>/dev/null | grep '"'"'^*'"'"' | colrm 1 2)\[\e[0;38;5;38;48;5;236m\]$(if [[ $(git diff HEAD --name-only 2> /dev/null | wc -l) -ne 0 ]]; then echo "*"; fi)\[\e[0;3;38;5;244;48;5;236m\] | cd \[\e[0;38;5;33;48;5;236m\]\w\[\e[m\]\n\[\e[0;38;5;244;48;5;236m\]╰> \[\e[0;38;5;244;48;5;236m\]\$\[\e[0m\] \[\e0'

export PS2='\[\e[0;38;5;244;48;5;236m\]    \[\e[0m\] \[\e0'


# Aliases
alias plz="sudo"            # For a wholesome experience
alias ll="ls -alhGF --color=auto"
alias vims="vim -S"
alias clear="clear && ls -a --color=auto"
command -v ls > /dev/null && alias ls='ls -aGFh --color=auto'
command -v grep > /dev/null && alias grep='grep -n --color=auto'
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


