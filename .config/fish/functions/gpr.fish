function gpr -a branch
    if [ -z "$branch" ]
        set branch (git rev-parse --abbrev-ref HEAD)
    end
    set number (gh pr view $branch --template="{{.number}}" --json='number')
    set remote_url (git config --get remote.origin.url)
    echo $remote_url
    set https_url ( \
        string trim -r -c / ( \
            string replace '.git' '/' ( \
                string replace 'git@github.com:' 'https://github.com/' $remote_url \
            ) \
        ) \
    )
    open "$https_url/pull/$number"
end
