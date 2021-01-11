TO_COPY=".ssh .bash_profile .gitmessage .vimrc .zshrc "
TO_SOURCE=".bash_profile .zshrc"
for f in $TO_COPY 
do 
    echo "COPYING: $f"
    if [[ -f "~/$f" ]]; then
       echo "Moving existing file ~/$f to ~/old_$f"
       mv ~/$f "~/old_$f"
    fi
    cp -r $f ~/$f
done

# Now Source the relevant files
for f in $TO_SOURCE 
do 
    cd ~
    echo "SOURCING: $f"
    if [[ -f "~/$f" ]]; then
       echo "Sourcing ~/$f"
       source $f
    fi
    cd ~/.dotfiles
done
