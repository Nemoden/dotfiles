# Todo: if argument has been passed, i.e.
# $ p blog
# Use zoxide to see if it can resolve 'blog' to anything in projects root. If it can, jump straight in.
function p --description "Navigates to a project"
    set PROJECTS_DIR ~/Projects
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
