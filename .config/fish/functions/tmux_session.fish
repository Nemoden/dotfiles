function tmux_session --description 'prints current tmux session name'
    if test -n "$TMUX"
        echo (tmux display-message -p '#S')
    end
end
