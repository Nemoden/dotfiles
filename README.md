[Old repo](https://github.com/Nemoden/dotfiles.old)
---

Install
---

Install [brew](https://brew.sh/) first (follow the instructions from the homebrew website)

    git clone --bare git@github.com:Nemoden/dotfiles.git $HOME/.dot
    git --git-dir=$HOME/.dot --work-tree=$HOME checkout
    echo "*" > ~/.gitignore
    brew bundle
    echo "/usr/local/bin/fish" | sudo tee -a /etc/shells
    chsh -s /usr/local/bin/fish
    /usr/local/opt/fzf/install
    vim +PlugInstall +q
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    
In a nutshell
---

This:

- creates a bare repo in `~/.dot` and track all the files in the `~`.
- adds all files in `~` to `.gitignore`, so that we don't add any private files into git inadvertently (files MUST be added forcefully using `-f` flag)
- changes shell to [`fish`](https://fishshell.com/)
- installs [some software](/Brewfile) from homebrew
- creates a special git alias named [`dot`](/.config/fish/functions/dot.fish) which is specifilly for working with the dotfiles located in `~`


Usage
---

    dot add -f .a-dot-file
    dot commit -m "Added .a-dot-file"
    dot push origin master
