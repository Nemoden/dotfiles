Install
---

    git clone --bare https://github.com/Nemoden/dotfiles.git $HOME/.dot
    git --git-dir=$HOME/.dot --work-tree=$HOME checkout
    brew bundle

Usage
---

    dot add -f .a-dot-file
    dot commit -m "Added .a-dot-file"
    dot push origin master
