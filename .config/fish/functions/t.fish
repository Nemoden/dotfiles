function t --description 'alias for taskwarrior' -w task
    set ts (tmux_session)
    set cmd (command -s task)
    if test -n "$ts"
        $cmd "project:$ts" $argv
    else
        $cmd $argv
    end
end
