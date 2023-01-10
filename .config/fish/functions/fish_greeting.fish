function fish_greeting --description Greeting
    set greeting ""
    if set -q NOGREETING
        return
    end
    if command -s fortune > /dev/null
        set greeting (fortune -s)
    end
    if command -s cowsay > /dev/null
        set width 40 # default
        if test -n $COLUMNS
            set width (math -s0 $COLUMNS / 2)
        end
        echo "$greeting" | cowsay -f small -s -W $width
    else
        echo $greeting
    end
end
