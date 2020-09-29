FILES=".vimrc .bash_profile .gitconfig"
for f in $FILES 
do 
    echo "Copying $f file"
    cp $f ~/
done
