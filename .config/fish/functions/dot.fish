function dot -w git -d "Manages dotfiles"
    git --git-dir=$HOME/.dot --work-tree=$HOME $argv
end
