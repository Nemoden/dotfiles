# https://taskwarrior.org/docs/using_dates.html
# https://taskwarrior.org/docs/dates.html
# https://taskwarrior.org/docs/named_dates.html
function done
    set os (uname)
    if ! command -sq task
        set no_taskwarrior "Taskwarrior not found, install it via"
        if [ $os = "Darwin" ]
            set no_taskwarrior $no_taskwarrior "homebrew or ports"
        else
            set no_taskwarrior $no_taskwarrior "your package manager"
        end
        echo $no_taskwarrior
        return
    end
    set cmd task +done
    if [ -z "$argv" ]
        # args empty, assume what's done today
        set cmd $cmd start:today
    else
        set modifier (string sub -e 1 -- $argv[1])
        if [ $argv[1] = "+all" ]
            # pass
        else if [ $modifier = "+" ]
            set when (string sub -s 2 -- $argv[1])
            set cmd $cmd start:$when
        else if [ $modifier = "-" ]
            set id (string sub -s 2 -- $argv[1])
            set cmd task done $id
        else
            set cmd $cmd add start:sod end:eod $argv
        end
    end
    eval $cmd
end
