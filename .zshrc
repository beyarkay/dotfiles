# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
# TODO these should only be loaded for AWS machines
export PATH=$PATH:~/.toolbox/bin
export PATH="/apollo/env/envImprovement/bin:$PATH"
# vim is installed to /opt/local/bin
export PATH="/opt/local/bin:$PATH"
# Path to your oh-my-zsh installation.
# export ZSH="/Users/boydkane/.oh-my-zsh"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  iterm2
  macports
  man
  osx
  python
  composer
  zsh-syntax-highlighting
  zsh-autosuggestions
)
# source $ZSH/oh-my-zsh.sh
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
# brew install coreutils # - will install gdate (required to get ms precision on MacOS)
if [ -x "$(command -v gdate)" ]; then
  alias date='gdate -u +"%Y-%m-%dT%H:%M:%SZ"'
else
  alias date='date -u +"%Y-%m-%dT%H:%M:%SZ"'
fi
alias gtd="grep -ri --exclude-dir=build --exclude-dir=.git -E \"(TODO|FIXME)\" *"
alias plz="sudo"            # For a wholesome experience
alias tmus="tmux"           # For fat fingers
alias brc="brazil-recursive-cmd"
alias bb="brazil-build"
alias bbr="brazil-build release"
alias ll="ls -alhGF"
alias vims="vim -S"
alias clear="clear && ls -a"
alias grep='grep -n --color=auto'
alias df='df -h'            # Disk free, in gigabytes, not bytes
alias du='du -h -c'         # Calculate total disk usage for a folder
alias ping='ping -c 5'      # Pings with 5 packets, not unlimited
# alias diff='diff --color=auto'
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
local pipe_char='&&'
local BG_GREY='236'
local FG_RED='160'
local FG_ORANGE='208'
local FG_GREY='244'
local FG_GREEN='46'
local FG_CYAN='51'
local FG_TURQUOISE='39'
local FG_DEEPBLUE='75'
local NO_BG='234'
local WHITE='255'
local FG_RED='196'


function here {
  paths=(${(s:/:)PWD})

  cur_path='/'
  cur_short_path='/'
  for directory in ${paths[@]}
  do
    if [ $directory = ${paths[-1]} ]; then
        cur_short_path+="${directory}/"
    else 
        cur_dir=''
        for (( i=0; i<${#directory}; i++ )); do
            cur_dir+="${directory:$i:1}"
            matching=("$cur_path"/"$cur_dir"*/)
            if [[ ${#matching[@]} -eq 1 ]] && [ $i -gt 3 ]; then
                break
            fi
        done
        if [ ${#cur_dir} -gt 3 ]; then
            cur_short_path+="${cur_dir}*/"
        else
            cur_short_path+="${cur_dir}/"
        fi
    fi
    cur_path+="$directory/"
  done

  printf "${cur_short_path: : -1}"
  echo
}


function preexec() {
    if [ -x "$(command -v gdate)" ]; then
        timer=$(($(\gdate +%s%0N)/1000000))
    else
        timer=$(($(\date +%s%0N)/1000000))
            fi
}

function precmd() {
    local errors='$(code=$?; if [[ $code -gt 0 ]]; then echo "%F{${FG_RED}}✘ $code"; else echo "✔"; fi)'
    if [ $timer ]; then
      if [ -x "$(command -v gdate)" ]; then
        now=$(($(\gdate +%s%0N)/1000000))
      else
        now=$(($(\date +%s%0N)/1000000))
      fi
      m=''
      s=''
      ms=$(($now-$timer))
      m_unit=''
      s_unit=''
      ms_unit='ms'
      if [ $ms -ge 1000 ]; then
          s=$(($ms/1000))
          ms=$(($ms%1000))
          s_unit='s '
      fi
      if [ $s -ge 60 2>/dev/null ]; then
          m=$(($s/60))
          s=$(($s%60))
          m_unit='m '
      fi
      rprompt="%F{${FG_GREY}}"
      rprompt+="${m}${m_unit}"
      rprompt+="${s}${s_unit}"
      rprompt+="${ms}${ms_unit}"
      rprompt+="%F{${FG_GREEN}} ${errors}"
      rprompt+="%F{${FG_GREY}}"
      rprompt+="%{$reset_color%}"
      
      export RPROMPT=$rprompt
      unset timer
    fi
  
    prompt="%K{${BG_GREY}}"
    prompt+="%F{${FG_RED}}"
    NEWLINE=$'\n'
    prompt+=$(ps aux | awk 'NR==2{if($3>=80.0) print "kill " $2 " (" $3 "%% " $11 ")${NEWLINE}"}')
    prompt+="%F{${FG_ORANGE}}"
    prompt+=$(ps aux | awk 'NR==2{if($3>=60.0) print "kill " $2 " (" $3 "%% " $11 ")${NEWLINE}"}')
    prompt+="%K{${BG_GREY}}"
    local time='%*'
    prompt+="%F{${FG_GREY}}╭─ %F{${FG_GREEN}}${time}"
  
    prompt+="%F{${FG_GREY}}"
    
    jobscount() {
      local stopped=$(jobs -sp | wc -l)
      local running=$(jobs -rp | wc -l)
      ((running)) && echo -n " ${running}r"
      ((stopped)) && echo -n " ${stopped}s"
    }
  
    prompt+='$(jobscount)'

    # prompt+='`if [ -n "$(jobs -p)" ]; then echo " (\j) "; fi`'
    local host_machine='%n@%M'
    prompt+="%F{${FG_GREY}} ${pipe_char} ssh %F{${FG_CYAN}}${host_machine}"

    local curr_dir='%~' 
    pwdir=$(pwd)
    if [ "${#pwdir}" -gt 32 ]; then
        curr_dir=$(here)
    fi
    prompt+="%F{${FG_GREY}} ${pipe_char} cd %F{${FG_DEEPBLUE}}${curr_dir}"
  
    local git_branch=''
    local git_changes=''
    local git_string=''
    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
        git_branch="$(git branch --show-current 2>/dev/null)"
        git_changes='$(if [[ $(git diff HEAD --name-only 2> /dev/null | wc -l) -ne 0 ]]; then echo "*"; fi)'
        git_string=' ${pipe_char} git co '
    fi
    prompt+="%F{${FG_GREY}}${git_string}%F{${FG_TURQUOISE}}${git_branch}${git_changes}"
    prompt+=" %F{${FG_GREY}}"$'\n'"╰→"
    prompt+="%K{NO_BG}%F{WHITE} "
  
  export PROMPT=$prompt
}


# PROMPT="%K{${BG_GREY}}%F{${FG_GREY}}╭─ %F{${FG_GREEN}}${time} %F{${FG_GREY}}| ssh %F{${FG_CYAN}}${host_machine}%F{${FG_GREY}}${git_string}%F{${FG_TURQUOISE}}${git_branch}${git_changes} %F{${FG_GREY}}| cd %F{${FG_DEEPBLUE}}${curr_dir}%F{${FG_GREY}}"$'\n'"╰>%K{NO_BG}%F{WHITE} "
setopt promptsubst

# Enable zsh Autosuggestions
# git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
