function p --description "Navigates to a project" --argument-names 'project'
    set PROJECTS_DIR ~/Projects
    if command -sq zoxide && test -n "$project"
        set -l zoxide_match (zoxide query $PROJECTS_DIR (string split "" $project) 2> /dev/null)
        if test -n "$zoxide_match"
            z $zoxide_match
            return
        end
    end

    if command -sq fzf
        set -l source
        set -l list (find ~/Projects -maxdepth 3 -type d)
        # fd is glitchy
        #if command -sq fd
            #set list (fd --full-path ~/Projects -t d -d 4)
        #end
        for dir in $list
            if test -d "$dir/.git"
                set -a source "$dir"
            else
                #echo "$dir NOT ok"
            end
        end
        z (echo $source | string split " " | fzf)
    else
        # just cd to projects directory and notice we need fzf and fd for better experience
        cd ~/Projects
        echo "Fuzzy-finding projects only works if fzf is installed. For best experience it's adviced to have fd installed as well as a replacement for find"
    end
end
