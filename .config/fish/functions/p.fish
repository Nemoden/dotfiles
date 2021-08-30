function p --description "Navigates to a project" --argument-names 'project'
    if command -sq zoxide && test -n "$project"
        set zoxide_match
        for PROJECTS_DIR in $PROJECTS_DIRS
            set search_term (string split "" $project)
            set zoxide_match $zoxide_match (string collect (zoxide query "$PROJECTS_DIR" $search_term 2> /dev/null))
        end
        if test -n "$zoxide_match"
            if test (count $zoxide_match) -gt 1
                z (echo $zoxide_match | string split " " | fzf)
            else
                z $zoxide_match
            end
            return
        end
    end

    if command -sq fzf
        set -l source
        set list
        for PROJECTS_DIR in $PROJECTS_DIRS
            set list $list (string collect (find $PROJECTS_DIR -maxdepth 3 -type d))
        end
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
