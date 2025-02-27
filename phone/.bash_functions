push() {
    p=$PWD
    cd `sd`/Счет*
    c=$*
    if [[ -z $c ]]; then
        c=$(rg --max-count=1 `date +.%m.%Y` `date +%Y.%m`/разходи)
        [[ -z $c ]] && c="`date +%Y.%m.%d`"
    fi
    git add \*
    git commit -m "$c"
    ! git push && echo "Warning! Push failed"
    cd $p
}

pull() {
    p=$PWD
    cd `sd`/Счет*
    ! git pull && echo "Warning! Pull failed"
    cd $p
}

gs() {
    rg -ni --color=always "$*" `sd`/Счетоводство |
        sed "`sd`/Счетоводство/" "" |
        sed "/" " " |
        sed ":" "\n" |
        tac
}

hesapla() {
    ay="$2"
    [[ "$1" == "gelirler" ]] && dosya="приходи"
    [[ "$1" == "giderler" ]] && dosya="разходи"
    [[ -z $ay ]] && ay=`date +%Y.%m`
    echo $ay | rg -xq '^(0[1-9]{1})|([10-12]{1})$'
    [[ $? -eq 0 ]] && ay="`date +%Y.$ay`"
    echo $ay | rg -xq '^202[2-9]{1}\.[0-9]{2}$'
    if [[ $? -eq 0 ]]; then
        sayilar=$(fd -p $ay/$dosya'$' `sd`/Счетоводство  -X cat |
        rg -v '^Общо:|>' |
        rg '([0-9\.\-]{4,})\s*лв\.*\s*$' -or '$1' |
        xargs | sed ' ' ')+(')
    fi
    sayilar=`echo "($sayilar)" | bc 2>/dev/null`
    round $sayilar
}

gel() {
    hesapla gelirler "$*"
}

gid() {
    hesapla giderler "$*"
}

ogh (){
    r=$(fd -p `date +%Y.`*/разходи\$ `sd`/Счетоводство -X cat |
    rg -v '^Общо:|>' |
    rg '([0-9\.\-]{4,})\s*лв\.*\s*$' -or '$1' |
    xargs | sed ' ' ')+(')
    round $(echo "scale=7; `echo \"($r)\" | bc 2>/dev/null` / `date +%j`" | bc 2>/dev/null)

}

bak() {
    f=$*
    declare -i mn=`date +%-m`
    [[ $mn -gt 1 ]] && mn=$(($mn-1))
    m="$mn"
    [[ $mn -lt 10 ]] && m="0$m"
    [[ -z $f ]] && f=`date +%Y.$m`
    printf "$f bakiyesi: "
    echo "`gel $f` - `gid $f`" | bc 2>/dev/null | xargs
}

gitlog() {
    p=$PWD
    cd `sd`/Счет*
    git diff `git rev-list --all --max-count=15 | tail -n 1`
    cd $p

}

round() {
    n=`echo "scale=17; $1 / 1.00" | bc 2>/dev/null | sed -- "^-\." "-0." | sed -- "^\." "0."`
    declare -i b=${n%.*}
    rn="${n#*.}"
    [[ ${rn:0:1} -gt 0 ]] && rem="${rn::2}"
    [[ ${rn:0:1} -eq 0 ]] && rem="${rn:1:1}"
    declare -i r=`echo "${rn:2}" | sed "^0*" "" | sed "0*$" ""`
    if [[ $r -gt 0 ]]; then
        (( rem++ ))
        if [[ $rem -eq 100 ]]; then
            rem=0
            ! [[ $n =~ "-" ]] && b=$b+1
            [[ $n =~ "-" ]] && b=$b-1
        fi
    fi
    [[ $rem -lt 10 ]] && rem="0$rem"
    [[ ${n%.*} == "-0" ]] && [[ $b -eq 0 ]] && z="-" || z=""
    res="$z$b.$rem"
    [[ $res == "0.0" ]] && res="0.00"
    echo $res
}

gg() {
    gun="$*"
    [[ -z $gun ]] && gun=`date +%d.%m.%Y`
    echo $gun | rg -q '^[0-9]{2}\.[0-9]{2}\.202[2-9]{1}' 
    [[ $? -eq 0 ]] && dosya=$(fd -p ${gun:6:4}.${gun:3:2}'/разходи$' `sd`)
    [[ ! -z $dosya ]] && basla=$(rg --max-count=1 ^$gun'\s*г\.*$' $dosya -n 2>/dev/null | choose -f : 0)
    [[ -z $basla ]] && sonuc=0
    [[ ! -z $basla ]] && bitir=$(tail -n+$basla $dosya 2>/dev/null | rg ^[0-9]{2}${gun:2}'\s*г\.*$' -n  | choose -f : 0 | head -n 2 | tail -n1)
    n="-0"
    [[ $bitir -gt 1 ]] && n=$bitir
    sonuc=$(tail -n+$basla $dosya 2>/dev/null | head -n$n | rg -v '^Общо:' |
        rg '([0-9\.\-]{4,})\s*лв\.*\s*$' -or '$1' |
        xargs | sed ' ' ')+(')
    sonuc=`echo "($sonuc)" | bc 2>/dev/null`
    round $sonuc
}

ogg() {
    r=`echo "scale=7; $(gid) / $(date +%-d)" | bc 2>/dev/null`
    m=31; mn=`date +%-m`
    [[ $mn -lt 12 ]] && (( mn++ )) &&  m=`date --date="$(date +%Y)-$mn-01 - 1 day" +%-d`
    q=`echo "$r * $m" | bc 2>/dev/null`
    echo "Aylık ortalama günlük gider: `round $r`"
    echo "Ay sonu beklenen gider: `round $q`"
    echo "Yıllık ortalama günlük gider: $(round `ogh`)"
    echo "Günlük gider: $(round `gg`)"
    echo "Aylık toplam gider: `gid`"
}

ck() {
    m="$1"
    [[ -z $m ]] && m=`date +%Y.%m`
    fd -p "$m/разходи\$" `sd`/Счетоводство -X cat |
    while read ln; do
        [[ $ln =~ "----" || $ln =~ ">" || -z $ln ]] && continue
        echo $ln | rg -q '[0-9]{2}\.[0-9]{2}\.202[0-9]{1}[[:blank:]]*г*\.*'
        [[ $? -eq 0 ]] && gun=$ln && s=0 && continue
        ln=`echo $ln | sed "=" "-"`
        ln=${ln/=/-}
        ln=${ln##*- }
        ln=${ln%лв*}
        if [[ ! $ln =~ "Общо:" ]]; then
            s=`echo "$ln+($s)" | bc`
        else
            ln="${ln#Общо: }"
            d=`echo "${ln#Общо:}" | sed "[[:blank:]]{1,}" ""`
            [[ `round $s` != `round $d` ]] && echo "HATA $gun: \"$d\" \"$s\""
        fi
    done
    _cko=`cko $m`
    _gid=`gid $m`
    [[ $_cko != $_gid ]] && echo "cko(): $_cko
gid(): $_gid"
}

cko () {
    m="$1"
    s=0
    [[ -z $m ]] && m=`date +%Y.%m`
    fd -p "$m/разходи\$" `sd`/Счетоводство -X cat |
        rg Общо: | while read ln; do
            ln=${ln##*:}
            ln=${ln% лв*};
            s=`echo "$ln+($s)" | bc`;
            echo $s
        done |
    tail -n 1 
}
