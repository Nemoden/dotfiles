function git-divergent
  set -l current_branch_name (git name-rev --name-only HEAD)
  set main_branch_name "master"
  if git show-ref --verify --quiet refs/heads/main
      set main_branch_name "main"
  end
  git log $main_branch_name..$current_branch_name --ancestry-path --reverse --format='%H %s' | head -n1
end
