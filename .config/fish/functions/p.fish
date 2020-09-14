function p --description "Navigates to a project"
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
        cd (echo $source | string split " " | fzf)
    else
        # just cd to projects directory and notice we need fzf and fd for better experience
        cd ~/Projects
        echo "Fuzzy-finding projects only works if fzf is installed. For best experience it's adviced to have fd installed as well as a replacement for find"
    end
end
