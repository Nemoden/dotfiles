function gli --wraps='git log' --description 'git log interactive preview (via fzf)'
    set new_args
    set i 1

    while test $i -le (count $argv)
        if test $argv[$i] = "-L"
            set combined "-L"$argv[(math $i + 1)]
            set new_args $new_args $combined
            set i (math $i + 2)
        else
            set new_args $new_args $argv[$i]
            set i (math $i + 1)
        end
    end

    if string match -q -- "-L*" $new_args[1]
        # Git forces diffs, so grep for lines starting with "commit "
        set sha_list (git log $new_args | grep '^commit ' | awk '{print $2}')
        printf "%s\n" $sha_list | fzf --preview='git show --color=always {+1}' --preview-window=right:70% --bind 'ctrl-f:preview-half-page-down,ctrl-b:preview-half-page-up'
    else
        git log --format="%h : %as : %an" $argv | fzf --preview='git show --color=always {+1}' --preview-window=right:70% --bind 'ctrl-f:preview-half-page-down,ctrl-b:preview-half-page-up'
    end
end
