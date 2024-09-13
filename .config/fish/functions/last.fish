function last --description 'Get last file path' --argument-names dir
     realpath $dir(command ls -t $dir | head -n 1)
end
