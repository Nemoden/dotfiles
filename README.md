Install
---

Install [brew](https://brew.sh/) first (follow the instructions from the homebrew website)

    git clone --bare git@github.com:Nemoden/dotfiles.git $HOME/.dot
    git --git-dir=$HOME/.dot --work-tree=$HOME checkout
    echo "*" > ~/.gitignore
    brew bundle
    /usr/local/opt/fzf/install

Usage
---

    dot add -f .a-dot-file
    dot commit -m "Added .a-dot-file"
    dot push origin master
