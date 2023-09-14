function @ --description "Exec -it into docker container"
    if test (count $argv) -eq 0
        set container (docker ps --format '{{ .Image }}\t{{ .Names }}' | fzf | awk '{print $2}')
        set shells bash sh
        set shell (string collect $shells | fzf)
        echo "docker exec -it $container $shell"
        docker exec -it $container $shell
    else
        docker exec -it $argv
    end
end
