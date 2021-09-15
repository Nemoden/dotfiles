function nvm
    if test -f /usr/local/opt/nvm/nvm.sh
        bax source /usr/local/opt/nvm/nvm.sh --no-use ';' nvm $argv
    end
    if test -f ~/.nvm/nvm.sh
        bax source ~/.nvm/nvm.sh --no-use ';' nvm $argv
    end
end
