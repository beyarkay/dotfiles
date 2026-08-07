#!/usr/bin/env zsh

# Deterministic prompt states used by prompt-screenshots.tape. These are kept
# separate from the live prompt so README images don't depend on the current
# machine, repository, clock, or system load.
emulate -L zsh

local scenario=${1:-clean}
local bg=236
local grey=244
local lightgrey=251
local cyan=51
local turquoise=39
local yellow=226
local orange=208
local red=196
local white=255
local zsh_prompt_format=${PROMPT_PREVIEW_ZSH_FORMAT:-0}

fg() {
    if (( zsh_prompt_format )); then
        print -n -- "%F{$1}"
    else
        print -n -- $'\e[38;5;'"$1"'m'
    fi
}

background() {
    if (( zsh_prompt_format )); then
        print -n -- "%K{$1}"
    else
        print -n -- $'\e[48;5;'"$1"'m'
    fi
}

prompt_start() {
    fg $grey
    background ${1:-$bg}
    print -n -- '╭ '
}

host() {
    print -n -- ' {'
    fg $cyan
    print -n -- "$1"
    fg $grey
    print -n -- '}'
}

path() {
    print -n -- " $1"
    fg $lightgrey
    print -n -- "$2"
    fg $grey
}

prompt_end() {
    fg ${1:-$grey}
    print -n -- $'\n╰→'
    if (( zsh_prompt_format )); then
        print -n -- '%k'
    else
        print -n -- $'\e[49m'
    fi
    fg $white
    print -n -- ' '
}

case $scenario in
    clean)
        prompt_start
        print -n -- '11:11:56'
        host laptop
        path '/U/b/' '.dotfiles'
        print -n -- ' (main)'
        prompt_end
        ;;
    command)
        prompt_start
        print -n -- '11:13:42 '
        fg $red
        print -n -- 'e1'
        fg $grey
        print -n -- ' '
        fg $turquoise
        print -n -- '1m4s'
        fg $grey
        print -n -- ' 2r'
        host 'aws 1xH100'
        path '/h/b/' 'training'
        print -n -- ' ('
        fg $red
        print -n -- 'p1 '
        fg $grey
        print -n -- 'main)'
        prompt_end
        ;;
    git)
        prompt_start
        print -n -- '11:14:07'
        host laptop
        path '/U/b/' 'project'
        print -n -- ' ('
        fg $red
        print -n -- 'x2'
        fg $turquoise
        print -n -- '↓3'
        fg $orange
        print -n -- 'rb '
        fg $grey
        print -n -- 'feature/prompt)'
        prompt_end
        ;;
    system)
        prompt_start
        print -n -- '11:15:03'
        host 'aws 8xH100'
        print -n -- ' '
        fg $orange
        print -n -- 'cpu93 gpu99 d8G'
        fg $grey
        path '/w/' 'training'
        print -n -- ' (main)'
        prompt_end
        ;;
    root)
        prompt_start
        print -n -- '11:16:20'
        host aws
        path '/e/' 'nginx'
        print -n -- ' (main)'
        prompt_end $red
        ;;
    *)
        print -u2 -- "usage: ${0:t} {clean|command|git|system|root}"
        return 2
        ;;
esac
