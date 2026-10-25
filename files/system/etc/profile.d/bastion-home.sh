# /home is a symlink to /var/home, so sessions start in the resolved path
# (/var/home/indegrowl) while HOME is /home/indegrowl, and prompts show the long
# path instead of ~. Interactive shells that start in home switch to $HOME.
case $- in
  *i*)
    if [ "$PWD" != "$HOME" ] && [ "$(pwd -P)" = "$(cd -P -- "$HOME" 2>/dev/null && pwd)" ]; then
      cd -- "$HOME" || :
    fi
    ;;
esac
