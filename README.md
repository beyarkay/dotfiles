# Boyd Kane's dotfiles
This repository is not designed for general use. I could (and do) introduce breaking changes at any point and without warning. That being said, these are some general dotfiles that I've build up and have found useful.

I've kept dependencies or required installs to an absolute minimum as I'm often working on a machine without sudo/install permissions. But I think the prompt is pretty cool, and the aliases are super handy.

My favorite is probably automatically `ls` after a `cd`, that or the prompt will include a line like `kill 3947 (86.3% /Applications/Google Chrome.app)` if any application starts using more than 75% CPU or so.

## TODO
- Add an all-inclusive setup script that should:
    - copy the relevant files to the home directory
    - Check that vim-plugins are installed
    - set zsh to the default terminal
    - Try to install some nice programs like
        - tmux
        - zsh autocomplete
- Maybe add a timer option, where `timer 10` would start a timer in the background for 10 seconds and then add a readout of the timer progress to PROMPT?
- Maybe shorten very long `pwd` lines by using glob expansion like:
    - `cd ~/p*/genghis_s*/g*` for `cd ~/public_html/genghis_server/games`
- Maybe use colours to convey data, instead of just adding more and more characters?
- Add a jobs count if > 0
- Add a warning if the busiest process is using over XXX% cpu
    - This might be useful
```sh
ps aux --sort=-%cpu | awk 'NR==1{print $2,$3,$11}NR>1{if($3>=0.0) print $2,$3,$11}'
```
- Add a slim-terminal window
    - would have differennt items on different lines if the terminal window is slimmer than usual
