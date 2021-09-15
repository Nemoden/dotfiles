function nvm_find_nvmrc
    if test -f /usr/local/opt/nvm/nvm.sh
      bax source /usr/local/opt/nvm/nvm.sh --no-use ';' nvm_find_nvmrc
    end
    if test -f ~/.nvm/nvm.sh
      bax source ~/.nvm/nvm.sh --no-use ';' nvm_find_nvmrc
    end
end
