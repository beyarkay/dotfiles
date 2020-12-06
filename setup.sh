TO_COPY=".bash_profile .gitconfig .gitmessage .vimrc .zshrc "
TO_SOURCE=".bash_profile .zshrc"
for f in $TO_COPY 
do 
    echo "$f"
    if [[ -f "~/$f" ]]; then
       echo "Moving existing filoe ~/$f to ~/old_$f"
       mv ~/$f "~/old_$f"
    fi
    cp $f ~/$f
done

# Now Source the relevant files
for f in $TO_SOURCE 
do 
    echo "$f"
    if [[ -f "~/$f" ]]; then
       echo "Sourcing ~/$f"
       source ~/$f
    fi
done
