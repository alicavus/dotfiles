
case $- in
    *i*)
        echo "" > $HOME/.bash_history
        apt update
        apt upgrade
        apt clean
        ;;
    *) return;;
esac

for f in aliases functions; do
    . ~/.bash_$f
done
