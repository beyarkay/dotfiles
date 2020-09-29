# Command Prompt

function timer_start {
  timer=${timer:-$SECONDS}
}

function timer_stop {
  timer_show=$(($SECONDS - $timer))
  unset timer
}

trap 'timer_start' DEBUG

if [ "$PROMPT_COMMAND" == "" ]; then
  PROMPT_COMMAND="timer_stop"
else
  PROMPT_COMMAND="$PROMPT_COMMAND; timer_stop"
fi

# Designed on https://scriptim.github.io/bash-prompt-generator/
export PS1='\[\e[0m\]\[\e[0;38;5;244;48;5;236m\]╭─ \[\e[0;38;5;40;48;5;236m\]\t\[\e[0;3;38;5;244;48;5;236m\] (${timer_show}s) | \[\e[0;38;5;44;48;5;236m\]\u\[\e[0;38;5;44;48;5;236m\]@\[\e[0;38;5;44;48;5;236m\]\h\[\e[0;3;38;5;244;48;5;236m\] | git \[\e[0;38;5;38;48;5;236m\]$(git branch 2>/dev/null | grep '"'"'^*'"'"' | colrm 1 2)\[\e[0;38;5;38;48;5;236m\]$(if [[ $(git diff HEAD --name-only | wc -l) -ne 0 ]]; then echo "*"; fi)\[\e[0;3;38;5;244;48;5;236m\] | cd \[\e[0;38;5;33;48;5;236m\]\w\[\e[m\]\n\[\e[0;38;5;244;48;5;236m\]╰> \[\e[0;38;5;244;48;5;236m\]\$\[\e[0m\] \[\e0'

export PS2='\[\e[0;38;5;244;48;5;236m\]    \[\e[0m\] \[\e0'
# export PS1='\[\e[0m\]\[\e[0;38;5;28;48;5;236m\]╭─ (\[\e[0;38;5;40;48;5;236m\]\t\[\e[0;38;5;28;48;5;236m\]) \[\e[0;38;5;44;48;5;236m\]\u\[\e[0;38;5;44;48;5;236m\]@\[\e[0;38;5;44;48;5;236m\]\h\[\e[0;38;5;28;48;5;236m\] \[\e[0;38;5;39;48;5;236m\]\w\[\e[0;48;5;236m\] \[\e[0;38;5;69;48;5;236m\]$(git branch 2>/dev/null | grep '"'"'^*'"'"' | colrm 1 2)\[\e[m\]\n\[\e[0;38;5;28;48;5;236m\]╰> \[\e[0;38;5;28;48;5;236m\]\$\[\e[0m\] \[\e0'


# Aliases
alias ll="ls -alh --color=auto"
command -v ls > /dev/null && alias ls='ls --color=auto'
command -v grep > /dev/null && alias grep='grep --color=auto'
command -v diff > /dev/null && alias diff='diff --color=auto'



# Colour the man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'


