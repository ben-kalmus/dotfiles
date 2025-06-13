#1 /usr/bin/env bash
alias date=/bin/date
alias rg=/opt/homebrew/bin/rg

function search-and-replace() {
    local SEARCH=$1
    local REPLACE=$2
    local PATH=${3:-"."}

    if [[ $# -gt 0 ]]; then shift; fi
    if [[ $# -gt 0 ]]; then shift; fi
    if [[ $# -gt 0 ]]; then shift; fi

    # if second arg is actually a path, then just do a search
    if [[ -d "$REPLACE" ]]; then
        PATH=$REPLACE
        REPLACE=""
    fi

    local OPTS=$*
    local LOGFILE="replace-$(/bin/date +%Y-%m-%d-%H:%M:%S).log"

    if [[ -z $SEARCH ]]; then
        echo "Usage: 
    $0 <search regex> <replace> <path> [ripgrep options]

Help:
    Using 1 arg performs a search
    Using 2 args performs a search and replace in current directory unless second arg is a directory.
    Using 2 args with second arg being a directory: a search in that directory.
    Using 3 args performs a search, replace and path.
    Using 3+ args, performs search and replace with path and [options] passed through to ripgrep.
"
        return
    fi

    if [[ -n $REPLACE ]]; then
        # log command
        echo "rg -e $SEARCH $PATH -l --glob "!$LOGFILE" $OPTS | /usr/bin/xargs -r -n 1 /usr/bin/sed -Ei '' "s/$SEARCH/$REPLACE/g" >>$LOGFILE"
        rg -e "$SEARCH" >>"$LOGFILE"

        # ignore log file we just reated
        rg -e "$SEARCH" "$PATH" -l --glob "!$LOGFILE" $OPTS | /usr/bin/xargs -r -n 1 /usr/bin/sed -Ei '' "s/$SEARCH/$REPLACE/g"

        # show results:
        rg -e "$REPLACE" "$PATH" -C1 $OPTS
    else
        rg -e "$SEARCH" "$PATH" $OPTS
    fi
}
