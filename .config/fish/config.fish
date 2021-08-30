if command -sq starship
    starship init fish | source
end

if command -sq direnv
    direnv hook fish | source
end

set -x PROJECTS_DIRS ~/Projects

if command -sq git
    abbr -a -g gs   git status --show-stash
    abbr -a -g gss  git status --short
    abbr -a -g gd   git diff
    abbr -a -g gadd git add .
    abbr -a -g gc   git commit
    abbr -a -g gcam git commit -am
    abbr -a -g gco  git checkout
    abbr -a -g gp   git push origin
    abbr -a -g gpf  git push -f origin
    abbr -a -g gl   git lg
end

if command -sq zoxide
    zoxide init fish | source
end

if command -sq nvim
    alias vi=(command -s vim)
    alias vim='nvim'
end

if command -sq rg
    alias rg='rg --no-heading'
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
if test -d "/usr/local/opt/gnu-sed/libexec/gnubin" && not contains "/usr/local/opt/gnu-sed/libexec/gnubin" $PATH
    set -x PATH "/usr/local/opt/gnu-sed/libexec/gnubin" $PATH
end

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

# navi
if command -sq navi
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
if command -sq exa
    alias ls='exa --time-style long-iso'
    alias l='ls -la --icons'
    alias la='ls -la'
    alias lsd='ls -D'
    alias lnew='l -snew'
    alias lnewr='l -snew -r'
    alias lanew='la -snew'
    alias lanewr='la -snew -r'
    alias tree='exa -T --icons'
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
