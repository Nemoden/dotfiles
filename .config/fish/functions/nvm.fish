function nvm
    set -l brew_prefix (brew --prefix)
    if test -f $brew_prefix/opt/nvm/nvm.sh
        bax source $brew_prefix/opt/nvm/nvm.sh --no-use ';' nvm $argv
    end
    if test -f ~/.nvm/nvm.sh
        bax source ~/.nvm/nvm.sh --no-use ';' nvm $argv
    end
end
