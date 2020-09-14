function gdp --wraps='git diff' --description 'git diff preview (via fzf)'
    set preview "git diff $argv --color=always -- {-1}"
    git diff $argv --name-only | fzf -m --ansi --preview $preview --preview-window=right:70%
end
