# Boyd Kane's dotfiles

## TODO
* Maybe use colours to convey data, instead of just adding more and more characters?
* Add a jobs count if > 0
* Add a warning if the busiest process is using over XXX% cpu
    * This might be useful
```sh
ps aux --sort=-%cpu | awk 'NR==1{print $2,$3,$11}NR>1{if($3>=0.0) print $2,$3,$11}'
```
* Add a slim-terminal window
    - would have differennt items on different lines if the terminal window is slimmer than usual
