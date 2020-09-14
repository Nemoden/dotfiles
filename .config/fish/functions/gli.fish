function gli --wraps='git log' --description 'git log preview (via fzf)'
    git log --format="%h : %as : %an" | fzf --preview='git show --color=always {+1}' --preview-window=right:70%
end
