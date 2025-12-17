function add_navi_path -d "adds path to NAVI_PATH" -a path
  if command -sq navi
      if test -d $path
          if not contains $path $NAVI_PATH
              set -gx --prepend NAVI_PATH $path
          end
      end
  end
end
