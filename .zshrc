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

# Emacs-style line editing. This MUST be explicit: EDITOR=nvim contains "vi",
# so zsh would otherwise default to vi mode and these keys wouldn't work.
# Emacs mode gives ^A ^E ^F ^B ^W ^K ^Y, alt-f/alt-b/alt-d, etc. for free.
bindkey -e

# ESC opens the current command line in $EDITOR (nvim).
# Must come after `bindkey -e`. KEYTIMEOUT=1 (below) keeps meta combos like
# alt-f/alt-b snappy while still letting a bare ESC open the editor.
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^[' edit-command-line

# ^U kills to start of line (bash-style) instead of zsh's kill-whole-line.
bindkey '^U' backward-kill-line

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
# Disallow easy footguns (but let Claude Code use rm directly, since it has
# its own automode checker — CLAUDECODE is set inside Claude sessions)
if [[ -z "$CLAUDECODE" ]]; then
    rm() { echo "Use del, or the full path i.e. /bin/rm"; return 255; }
fi
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
# -----------------------------------------------------------------------------
function cd() {
    builtin cd "$*" || return
    # Skip the auto-ls inside Claude Code (its shell disables zsh glob
    # qualifiers, so the *(DN) count below errors). Only list in a real shell,
    # and only when there are fewer than 10 entries so huge dirs don't spew.
    if [[ -z "$CLAUDECODE" ]]; then
        local entries=( *(DN) )
        (( ${#entries} < 10 )) && ls
    fi
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

# Record command timing with zsh's own clock, without spawning a process.
zmodload zsh/datetime
autoload -Uz add-zsh-hook
typeset -gF _PROMPT_COMMAND_STARTED_AT=0

function _prompt_record_command_start() {
    _PROMPT_COMMAND_STARTED_AT=$EPOCHREALTIME
}
add-zsh-hook preexec _prompt_record_command_start

# Detect GPU configuration once at shell startup
_PROMPT_GPU_INFO=""
if command -v nvidia-smi &>/dev/null; then
    _gpu_names=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
    if [[ -n "$_gpu_names" ]]; then
        _gpu_count=$(echo "$_gpu_names" | wc -l | tr -d ' ')
        _gpu_model=$(echo "$_gpu_names" | head -1 | sed 's/NVIDIA //' | awk '{print $1}')
        _PROMPT_GPU_INFO="${_gpu_count}x${_gpu_model}"
    fi
    unset _gpu_names _gpu_count _gpu_model
fi

# =============================================================================
# Detect the machine identity once at startup (used by the prompt).
# whoami/hostname never change within a session, so there's no reason to spawn
# them (x3 each) on every single prompt — that alone cost ~25ms per keystroke.
# =============================================================================
_PROMPT_HOST_MACHINE="{%F{${FG_CYAN}}$(hostname)%F{$FG_GREY}}"
{
    local _whoami=$(whoami) _hostname=$(hostname)
    local brk_whoami=(brk boydkane boydrkane)
    local aws_whoami=(boydkane)
    local mbp2022_hostnames=(Boyds-MacBook-Pro-2022.local Boyds-MBP-2022 Boyds-MBP-2022.home)
    local mbp2012_hostnames=(Boyds-MacBook-Pro-2012.local Boyds-MBP-2012 Boyds-MBP-2012.home)

    if (($brk_whoami[(Ie)$_whoami])) && (($mbp2022_hostnames[(Ie)$_hostname])); then
        _PROMPT_HOST_MACHINE="{%F{${FG_CYAN}}laptop%F{$FG_GREY}}"
    elif (($aws_whoami[(Ie)$_whoami])); then
        # Probably an aws machine
        [ -f "$HOME/.dotfiles/aws_setup.sh" ] && source ~/.dotfiles/aws_setup.sh
        _PROMPT_HOST_MACHINE="{%F{${FG_CYAN}}aws%F{$FG_GREY}}"
    elif (($brk_whoami[(Ie)$_whoami])) && (($mbp2012_hostnames[(Ie)$_hostname])); then
        _PROMPT_HOST_MACHINE="{%F{${FG_CYAN}}laptop2012%F{$FG_GREY}}"
    fi

    # Append GPU info (e.g. 1xH100) inside the braces if available
    if [[ -n "$_PROMPT_GPU_INFO" ]]; then
        _PROMPT_HOST_MACHINE="${_PROMPT_HOST_MACHINE%\}} %F{${FG_CYAN}}${_PROMPT_GPU_INFO}%F{$FG_GREY}}"
    fi
}

# =============================================================================
# Sample expensive system metrics away from the prompt's critical path.
#
# `ps` takes around 15ms on macOS and nvidia-smi can be slower, so a disowned
# background job refreshes this cache at most every 30 seconds. Reading the
# cache on each prompt is a zsh builtin. Alerts only appear for CPU/GPU use of
# at least 80%, or when the root filesystem has less than 10GiB free.
# =============================================================================
typeset -g _PROMPT_METRICS_LAST_LAUNCH=0
typeset -g _PROMPT_METRICS_CACHE=''
typeset -g _PROMPT_METRICS_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/zsh-prompt-${EUID}"

if [[ -d "$_PROMPT_METRICS_DIR" && -O "$_PROMPT_METRICS_DIR" ]] \
        || command mkdir -m 700 "$_PROMPT_METRICS_DIR" 2>/dev/null; then
    _PROMPT_METRICS_CACHE="$_PROMPT_METRICS_DIR/metrics"
fi

function _prompt_refresh_system_metrics() {
    local cache_file=$1
    local cache_tmp="${cache_file}.${$}"
    local cpu_count cpu_total cpu_util gpu_util disk_kib disk_gib
    local -a alerts=()

    cpu_count=$(command getconf _NPROCESSORS_ONLN 2>/dev/null)
    [[ $cpu_count == <-> && $cpu_count -gt 0 ]] || cpu_count=1
    cpu_total=$(
        /bin/ps -A -o %cpu= 2>/dev/null \
            | command awk '{ total += $1 } END { printf "%.0f", total }'
    )
    if [[ $cpu_total == <-> ]]; then
        (( cpu_util = cpu_total / cpu_count ))
        (( cpu_util >= 80 )) && alerts+=("cpu${cpu_util}")
    fi

    if command -v nvidia-smi &>/dev/null; then
        gpu_util=$(
            command nvidia-smi \
                --query-gpu=utilization.gpu \
                --format=csv,noheader,nounits 2>/dev/null \
                | command awk '$1 > highest { highest = $1 }
                    END { printf "%.0f", highest }'
        )
        [[ $gpu_util == <-> && $gpu_util -ge 80 ]] \
            && alerts+=("gpu${gpu_util}")
    fi

    disk_kib=$(command df -Pk / 2>/dev/null \
        | command awk 'NR == 2 { print $4 }')
    if [[ $disk_kib == <-> ]]; then
        (( disk_gib = disk_kib / 1024 / 1024 ))
        (( disk_gib < 10 )) && alerts+=("d${disk_gib}G")
    fi

    print -r -- "${(j: :)alerts}" >| "$cache_tmp" \
        && command mv -f "$cache_tmp" "$cache_file"
}

# Find in-progress Git operations without another Git process. This handles
# both ordinary repositories and worktrees whose .git is a pointer file.
function _prompt_git_operation() {
    local search_dir=$PWD
    local git_dir=''
    local gitdir_line=''
    REPLY=''

    if [[ -n $GIT_DIR ]]; then
        git_dir=$GIT_DIR
        [[ $git_dir == /* ]] || git_dir="$PWD/$git_dir"
    else
        while true; do
            if [[ -d "$search_dir/.git" ]]; then
                git_dir="$search_dir/.git"
                break
            elif [[ -f "$search_dir/.git" ]]; then
                IFS= read -r gitdir_line < "$search_dir/.git"
                if [[ $gitdir_line == 'gitdir: '* ]]; then
                    git_dir=${gitdir_line#gitdir: }
                    [[ $git_dir == /* ]] || git_dir="$search_dir/$git_dir"
                fi
                break
            fi
            [[ $search_dir == / ]] && break
            search_dir=${search_dir:h}
        done
    fi

    [[ -n $git_dir ]] || return
    if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        REPLY='rb'
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        REPLY='mg'
    elif [[ -f "$git_dir/BISECT_LOG" || -f "$git_dir/BISECT_START" ]]; then
        REPLY='bs'
    fi
}

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
    # This must be first: anything before it would overwrite the exit status of
    # the command that just finished.
    local last_exit_status=$?
    local curr_time='%*'
    local command_result=''

    if (( last_exit_status != 0 )); then
        command_result+=" %F{${FG_RED}}e${last_exit_status}%F{${FG_GREY}}"
    fi

    if (( _PROMPT_COMMAND_STARTED_AT > 0 )); then
        local -i elapsed_seconds=$(( EPOCHREALTIME - _PROMPT_COMMAND_STARTED_AT ))
        _PROMPT_COMMAND_STARTED_AT=0
        if (( elapsed_seconds >= 5 )); then
            if (( elapsed_seconds >= 60 )); then
                local -i elapsed_minutes=$(( elapsed_seconds / 60 ))
                local -i elapsed_remainder=$(( elapsed_seconds % 60 ))
                command_result+=" %F{${FG_TURQUOISE}}${elapsed_minutes}m"
                (( elapsed_remainder > 0 )) \
                    && command_result+="${elapsed_remainder}s"
                command_result+="%F{${FG_GREY}}"
            else
                command_result+=" %F{${FG_TURQUOISE}}${elapsed_seconds}s%F{${FG_GREY}}"
            fi
        fi
    fi

    # ===================================================================
    # If there are any jobs which are stopped or in the background, add a
    # little symbol to the prompt
    # ===================================================================
    # Iterate the $jobstates special param directly — `$(jobs ...)` would run
    # in a subshell with an empty job table and always report 0.
    local stopped_count=0 running_count=0
    local _job_state
    for _job_state in ${(v)jobstates}; do
        [[ $_job_state == suspended:* ]] && ((stopped_count++))
        [[ $_job_state == running:* ]] && ((running_count++))
    done
    local stopped_jobs=''
    local running_jobs=''
    (( stopped_count > 0 )) && stopped_jobs="${stopped_count}s"
    (( running_count > 0 )) && running_jobs="${running_count}r"
    local job_string="$stopped_jobs$running_jobs"
    if [[ ${#job_string} -gt 0 ]]; then
        job_string=" $job_string"
    fi

    # ============================================================
    # Machine identity (laptop / aws / GPU info) is detected once at startup
    # into $_PROMPT_HOST_MACHINE — see the block near the top of this file.
    # ============================================================
    local host_machine="$_PROMPT_HOST_MACHINE"
    local need_kinit=''
    local need_mwinit=''

    # ======================================================
    # If we are inside a git repo, then show git branch info
    # Uses a single `git status` call instead of separate
    # ls-files, diff, diff --staged, and branch commands.
    # Skip on RunPod — git is too slow on networked storage.
    # ======================================================
    local git_branch=''
    if [[ -z "$RUNPOD_POD_ID" ]]; then
    local git_porcelain
    git_porcelain=$(git --no-optional-locks status --porcelain -b 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local -a git_lines=("${(@f)git_porcelain}")

        # Header looks like "## branch...remote [ahead N, behind M]" or "## branch".
        local git_header=${git_lines[1]}
        local branch_name=${git_header#\#\# }
        local git_has_upstream=0
        [[ $branch_name == *...* ]] && git_has_upstream=1
        if [[ $branch_name == 'No commits yet on '* ]]; then
            branch_name=${branch_name#No commits yet on }
        elif [[ $branch_name == 'Initial commit on '* ]]; then
            branch_name=${branch_name#Initial commit on }
        else
            branch_name=${branch_name%%...*}
            branch_name=${branch_name%% \[*}
        fi

        # Unpushed count: parse "[ahead N]" straight from the header rather than
        # spawning a second `git rev-list` subprocess every prompt. (Reports vs
        # upstream; for same-named push branches this matches @{push}..HEAD.)
        local git_unpushed=0
        if [[ $git_header == *'[ahead '* ]]; then
            git_unpushed=${${git_header##*\[ahead }%%[,\]]*}
        fi
        local git_behind=0
        if [[ $git_header == *'behind '* ]]; then
            git_behind=${${git_header##*behind }%%[,\]]*}
        fi
        shift git_lines

        # Pull conflicts out first so they get one unambiguous red count rather
        # than also appearing in the staged/unstaged totals.
        local git_conflicts=0
        local git_line
        local -a non_conflict_lines=()
        for git_line in "${git_lines[@]}"; do
            case "${git_line[1,2]}" in
                DD|AU|UD|UA|DU|AA|UU) (( git_conflicts++ )) ;;
                *) non_conflict_lines+=("$git_line") ;;
            esac
        done

        # Count statuses using zsh array filtering (no subprocesses).
        local git_untracked=${#${(M)non_conflict_lines:#\?\?*}}
        local git_unstaged=${#${(M)non_conflict_lines:#?[MTDAU]*}}
        local git_uncommitted=${#${(M)non_conflict_lines:#[MTADRC]*}}

        local git_colour=''
        if [[ $git_conflicts -gt 0 ]]; then
            git_colour+="%F{${FG_RED}}x$git_conflicts"
        fi
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
        if [[ $git_behind -gt 0 ]]; then
            git_colour+="%F{${FG_TURQUOISE}}↓$git_behind"
        fi
        if (( ! git_has_upstream )) && [[ $branch_name != 'HEAD (no branch)' ]]; then
            git_colour+="%F{${FG_RED}}p?"
        fi

        _prompt_git_operation
        local git_operation=$REPLY
        if [[ -n $git_operation ]]; then
            git_colour+="%F{${FG_ORANGE}}${git_operation}"
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
    fi # end RUNPOD_POD_ID check

    # Start stale metric refreshes asynchronously, then consume the most recent
    # complete result. `&!` prevents this helper from appearing as a shell job.
    local system_alerts=''
    if [[ -n $_PROMPT_METRICS_CACHE ]]; then
        if (( EPOCHSECONDS - _PROMPT_METRICS_LAST_LAUNCH >= 30 )); then
            _PROMPT_METRICS_LAST_LAUNCH=$EPOCHSECONDS
            _prompt_refresh_system_metrics "$_PROMPT_METRICS_CACHE" &!
        fi
        [[ -r $_PROMPT_METRICS_CACHE ]] \
            && system_alerts=$(<"$_PROMPT_METRICS_CACHE")
        [[ -n $system_alerts ]] \
            && system_alerts=" %F{${FG_ORANGE}}${system_alerts}%F{${FG_GREY}}"
    fi

    # ===========================================================================
    # Collect all the variables together for the prompt and give them some colour
    # ===========================================================================
    prompt="%F{${FG_GREY}}%K{${BG_GREY}}"
    prompt+="╭ ${curr_time}${command_result}"
    prompt+="${job_string}"
    prompt+=" ${host_machine}"
    prompt+="${system_alerts}"
    if [[ ${#need_mwinit} -gt 0 ]]; then
        prompt+=" ${need_mwinit}"
    fi
    if [[ ${#need_kinit} -gt 0 ]]; then
        prompt+=" ${need_kinit}"
    fi
    prompt+=" $(short_pwd)"
    prompt+="${git_branch}"
    local prompt_arrow_colour=$FG_GREY
    (( EUID == 0 )) && prompt_arrow_colour=$FG_RED
    prompt+="%F{${prompt_arrow_colour}}"$'\n'"╰→"
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

# Enable floating tmux window for fzf searches
FZF_TMUX_OPTS='-p80%,60%'

# >>> conda initialize (lazy) >>>
# The real `conda init` block runs `eval "$(conda shell.zsh hook)"` eagerly,
# which costs ~26ms every startup just to define a function we rarely call
# (conda base is not auto-activated here). Instead, define a stub that loads
# the real conda on first use, then re-invokes it transparently.
conda() {
    unset -f conda
    __conda_setup="$("$HOME/.miniforge3/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    elif [ -f "$HOME/.miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/.miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/.miniforge3/bin:$PATH"
    fi
    unset __conda_setup
    conda "$@"
}
# <<< conda initialize (lazy) <<<


# ======================================================
# Auto-expand globs, aliases, and other shell expansions
# ======================================================
# This autoload fix is needed to get the _expand-alias function: https://stackoverflow.com/a/61653489/14555505
# Completions live here too (deepsource etc.); fpath must be set before compinit.
fpath=(~/.zsh/completions $fpath)
# compinit's security audit + dump rebuild is the single most expensive part of
# startup (~150ms). Only pay it once a day: if the cached dump is <24h old, use
# the fast path (-C) that skips the audit and trusts the existing dump.
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
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

# What am I running on localhost? Dashboard lives at http://localhost:1111
# `ports` lists them, `ports --kill 8787` stops one, `ports --all` includes apps.
ports() { /usr/bin/python3 "$HOME/.dotfiles/scripts/localports.py" "${@:---list}" }

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm@12/bin:$PATH"

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

# envman: its load.sh costs ~11ms (4 `touch` calls + sourcing 3 empty files)
# but all it actually does is prepend ~/.local/bin to PATH. Do that directly.
# (ENV.env / alias.env / function.sh are all empty as of this writing.)
export PATH="$HOME/.local/bin:$PATH"

# Added by deepsource CLI (shell completions)
# (fpath for ~/.zsh/completions and compinit are handled once, above.)

# opencode
export PATH=/Users/brk/.opencode/bin:$PATH

# Deno has no config file or env var for its release-age gate, only the
# --minimum-dependency-age flag, so inject it here. 10080 minutes = 7 days.
# Every other package manager is gated via its own config file instead.
deno() {
    case "$1" in
        install|add|update|outdated)
            command deno "$@" --minimum-dependency-age 10080 ;;
        *)
            command deno "$@" ;;
    esac
}
