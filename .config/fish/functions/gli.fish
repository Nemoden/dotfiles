function gli --wraps='git log' --description 'git log preview (via fzf)'
    git log --format="%h : %as : %an" $argv | fzf --preview='git show --color=always {+1}' --preview-window=right:70% --bind 'ctrl-f:preview-half-page-down,ctrl-b:preview-half-page-up'
end
