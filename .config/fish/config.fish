if command -sq brew
    source /opt/homebrew/opt/fzf/shell/key-bindings.fish
end
if command -sq starship
    starship init fish | source
end

if command -sq asdf
    # ASDF configuration code
    if test -z $ASDF_DATA_DIR
        set _asdf_shims "$HOME/.asdf/shims"
    else
        set _asdf_shims "$ASDF_DATA_DIR/shims"
    end

    # Do not use fish_add_path (added in Fish 3.2) because it
    # potentially changes the order of items in PATH
    if not contains $_asdf_shims $PATH
        set -gx --prepend PATH $_asdf_shims
    end
    set --erase _asdf_shims
end

# Homebrew core bin paths first
set -gx PATH /opt/homebrew/bin /opt/homebrew/sbin $PATH

# Homebrew Python 3.13 unversioned symlinks
set -gx PATH /opt/homebrew/opt/python@3.13/libexec/bin $PATH

if command -sq direnv
    direnv hook fish | source
end

if command -sq aichat
    alias ai='aichat'
end

alias killchrome="ps ux | grep '[C]hrome Helper (Renderer) --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# load_nvm

set -x PROJECTS_DIRS ~/Projects

function echo_tsts
    echo (ts):(ts)
end
abbr -a tt --position anywhere --function echo_tsts

function echo_br
    echo (git branch  | grep \* | sed 's/* //')
end

function echo_brbr
    set --local br (echo_br)
    echo "$br:$br"
end

abbr -a -g chrome 'open -a "Google Chrome"'
abbr -a -g preview 'open -a "Preview"'
abbr -a -g safari 'open -a "Safari"'

function echo_np
    set --local name (mktemp '/tmp/np-'(date +%Y%m%d)'-'(ts)'.XXXXXX')
    rm -f $name
    # A space in front of vi is intentional,
    # I don't want typing vi and get suggested
    # to edit a tmp notepad file
    echo " vi +star $name"
end

abbr -a brbr --position anywhere --function echo_brbr

abbr -a bch --position anywhere --function echo_br

abbr -a ts --position anywhere --function ts

# Create a temp notepad
abbr -a np --position anywhere --function echo_np

function bangbang
    echo $history[1]
end

abbr -a !! --position anywhere --function bangbang

function dollarunderscore
    echo $history[1] | awk '{print $NF}'
end

abbr -a \$_ --position anywhere --function dollarunderscore

alias cd-='cd -'

if command -sq git
    abbr -a -g gs    git status --show-stash
    abbr -a -g gss   git status --short
    abbr -a -g gd    git diff
    abbr -a -g gadd  git add .
    abbr -a -g gc    git commit
    abbr -a -g gcam  git commit -am
    abbr -a -g gco   git checkout
    abbr -a -g gam   git amend
    abbr -a -g gpm   git push origin main
    abbr -a -g gpom  git push origin main
    abbr -a -g gp    git push origin
    abbr -a -g gpf   git push -f origin
    abbr -a -g gpl   git pull origin
    abbr -a -g gl    git lg
    abbr -a -g gr    git rebase
    abbr -a -g gri   git rebase -i
    abbr -a -g gcb   git co -b
    abbr -a -g grc   git rebase --continue
    abbr -a -g gra   git rebase --abort
    abbr -a -g their git co --theirs
end

if command -sq docker
    abbr -a -g dps    'docker ps'
    abbr -a -g dpsa   'docker ps -a'
    abbr -a -g dim    'docker images'
    abbr -a -g dbuild 'docker build'
    abbr -a -g drun   'docker run'
    abbr -a -g dexit  'docker exec -it'
    abbr -a -g dstop  'docker stop'
    abbr -a -g dstart 'docker start'
    abbr -a -g drm    'docker rm'
    abbr -a -g drmi   'docker rmi'
    abbr -a -g dnetls 'docker network ls'
    abbr -a -g dpull  'docker pull'
    abbr -a -g dlogs  'docker logs'
    abbr -a -g dcu    'docker-compose up'
    abbr -a -g dcd    'docker-compose down'
end

if command -sq zoxide
    zoxide init fish | source
end

if command -sq nvim
    alias vi=(command -s vim)
    alias vim='nvim'
    alias v='nvim'
end

if command -sq lynx
    alias lynx='lynx -cfg ~/lynx.cfg'
end

if command -sq rg
    alias rg='rg --no-heading -M 150'
end

if command -sq kubectl
    abbr -a -g kg  kubectl get
    abbr -a -g kgp kubectl get po
    abbr -a -g kgs kubectl get svc
    abbr -a -g kgn kubectl get ns
    abbr -a -g ke  kubectl exec -it
    abbr -a -g kgi kubectl get ingress
    abbr -a -g kgc kubectl get cronjobs
    abbr -a -g kd  kubectl describe
end

set -x SHELL fish
set -x EDITOR vim
set -x VISUAL vim
set -x PAGER less
if test -d $HOME/bin && not contains $HOME/bin $PATH
    set -x PATH $PATH $HOME/bin
end
# On MacOS if GNU utils are installed, use those instead on BSD
if test -d "/usr/local/opt/coreutils/libexec/gnubin" &&not contains "/usr/local/opt/coreutils/libexec/gnubin" $PATH
    set -x PATH "/usr/local/opt/coreutils/libexec/gnubin" $PATH
end
if test -d "/usr/local/opt/findutils/libexec/gnubin" && not contains "/usr/local/opt/findutils/libexec/gnubin" $PATH
    set -x PATH "/usr/local/opt/findutils/libexec/gnubin" $PATH
end
#if test -d "/usr/local/opt/gnu-sed/libexec/gnubin" && not contains "/usr/local/opt/gnu-sed/libexec/gnubin" $PATH
    #set -x PATH "/usr/local/opt/gnu-sed/libexec/gnubin" $PATH
#end

alias ..='cd ..'
alias ...='cd ../../'
alias rm='rm -i'
alias c='clear'
alias e='$EDITOR'
alias :e='$EDITOR'

# fihser
if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end

# golang
if command -sq go
    set -x GOPATH $HOME/go
    set -x GOBIN $GOPATH/bin
    if not contains $GOBIN $PATH
        set -x PATH $PATH $GOBIN
    end
end

# fnm
if command -sq fnm
    if not contains $HOME/.fnm/current/bin $PATH
        set -gx PATH $HOME/.fnm/current/bin $PATH;
    end
    set -gx FNM_MULTISHELL_PATH $HOME/.fnm/current;
    set -gx FNM_DIR $HOME/.fnm;
    set -gx FNM_NODE_DIST_MIRROR https://nodejs.org/dist
    set -gx FNM_LOGLEVEL error
end

if not contains $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH;
end

# navi
if command -sq navi
    navi widget fish | source
    alias ne="navi"
    alias n="navi --print"
end

# zoxide fallback
if not command -sq zoxide
    function z -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
    function zi -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
    function zoxide -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
    function za -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
    function zq -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
    function zr -w cd
        echo "zoxide is not installed! falling back to cd"
        cd $argv
    end
end

if command -sq gron
    alias ungron='gron --ungron'
end

# upgrade ls
if command -sq eza
    alias ls='eza --time-style long-iso'
    alias l='ls -la --icons'
    alias la='ls -la'
    alias lsd='ls -D'
    alias lnew='l -snew'
    alias lnewr='l -snew -r'
    alias lanew='la -snew'
    alias lanewr='la -snew -r'
    alias tree='eza -T --icons'
else
    alias l='ls -lA'
    alias la='ls -lA'
    alias lsd='ls -d *'
    alias lnew='l -latr' # a bit quirky, I want new to be on the bottom, because the list may be long, I don't wanna scroll
    alias lnewr='l -lat'
    alias lanew='la -latr'
    alias lanewr='la -lat'
end

# List all the dot files in current dir
alias l.="ls -ld .*"

# upgrade cat
if command -sq bat
    alias cat="bat -pp"
    alias caat="bat -n"
    alias caaat="bat"
else
    alias caat="cat -n"
    alias caaat="cat -n"
end

if command -sq batman
    alias man='batman'
end

if test -f ~/.phpbrew/phpbrew.fish
    source ~/.phpbrew/phpbrew.fish
end

if test -e ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end

# uv
fish_add_path "/Users/kkovalchuk/.local/bin"
