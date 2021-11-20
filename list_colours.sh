#!/bin/bash
color=0;
while [ $color -lt 256 ]; do
    echo -ne " (\\033[38;5;${color}m$color\\033[48;5;${color}m$color\\033[0m) "
    ((color++));
done  
