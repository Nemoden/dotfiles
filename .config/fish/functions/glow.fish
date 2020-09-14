function glow -w glow
    set cmd (command -s glow)
    set bat (command -s bat)
    if test -n "$bat"
        PAGER="bat -p" $cmd -p $argv
    else
        $cmd $argv
    end
end
