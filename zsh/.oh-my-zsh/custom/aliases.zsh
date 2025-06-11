# git
function gaa() {
    local r=$(git status >/dev/null 2>&1)
    if [[ $(echo $?) -eq 0 ]]; then
        git add $(git status --short | grep -E '^\ ?M+' | awk -F ' ' '{print $2}')
    fi
}
alias gb='git branch'
alias gd='git diff'
alias gcl='git clone'
alias gc="git commit -m"
alias gcm="git commit -m"
alias gca='git commit --amend'
alias gcaa="git commit --amend --no-edit"
alias gcob='git checkout -b'
alias gco='git checkout'
alias gl='git log --oneline --graph'
alias gr='git revert'
alias grc='git rebase --continue'
alias grs="git restore --staged"
alias gmrg='git mergetool'
alias gs='git status && git --no-pager diff --stat'
alias gits="git status"
alias gp='git push'
#alias gu='git reset --mixed HEAD'
alias gpf="git push -f"
alias gfa="git fetch --all"
function pushnew() {
    git push --set-upstream origin $(git branch --show-current)
}

function gitlog() {
    git log --oneline --decorate --pretty=format:"%C(yellow)%h%Creset %C(auto)%d %C(white)(%ad)%Creset %s" --date=format:'%Y-%m-%d %H:%M:%S'
}

alias reloadzsh="source ~/.zshrc"
alias v="nvim"

# alias t='ts %H:%M:%S'
alias date-now="date +%Y.%m.%d %H:%M:%S"

# display filestructure
alias ll='ls -lh'
alias tree='tree -Csuh'

# start programs
alias vscode='code >/dev/null 2>&1 &'

# basically, a verbose cp
alias cpv='rsync -ah --info=progress2'

# docker
alias dockerfix='sudo chmod 666 /var/run/docker.sock'
alias di='docker images'
alias dps='docker ps'
alias dps-exited='docker ps --filter "status=exited"'

# parsers
alias prettyjson='python3 -m json.tool'
function format-json() {
    if [[ ! -f "$1" ]]; then
        echo "$1 does not exist"
        return 1
    fi
    local file="/tmp/$(basename $1.json)"
    jq '.' $1 >$file && mv $file $1
}
alias prettyxml='xmllint --format -'

# ssh
# alias ssh='ssh -o StrictHostKeyChecking=no'
alias sshagent='eval $(ssh-agent) && ssh-add'

# tmux
# alias tmux="tmux -2"
alias tnw='tmux new-window'
alias tkw='tmux kill-window'

# #clipboard
# alias setclip="xclip -selection c"
# alias getclip="xclip -selection c -o"

# TODO: move this to a scripts file and configure to run `#!/usr/bin/env bash`
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

    local OPTS=$@
    local LOGFILE=replace-$(/usr/bin/date +%Y-%m-%d-%H:%M:%S).log

    if [[ -z $SEARCH ]]; then
        echo "Usage: 
    $0 <search regex> <replace> <path> [ripgrep options]

Help:
    Using 1 arg performs a search
    Using 2 args performs a search and replace in current directory.
    Using 2 args with second arg being a directory: a search in that directory.
    Using 3 args performs a search, replace and path.
    Using 3+ args, performs search and replace with path and [options] passed through to ripgrep.
"
        return
    fi

    if [[ -n $REPLACE ]]; then
        # log command
        echo "rg -e $SEARCH $PATH -l --glob "!$LOGFILE" $OPTS | xargs -r sed -Ei 's/$SEARCH/$REPLACE/g'" >>$LOGFILE
        /usr/bin/rg -e "$SEARCH" >>$LOGFILE

        # ignore log file we just reated
        /usr/bin/rg -e "$SEARCH" "$PATH" -l --glob "!$LOGFILE" $OPTS | /usr/bin/xargs -r sed -Ei "s/$SEARCH/$REPLACE/g"

        # show results:
        /usr/bin/rg -e "$REPLACE" "$PATH" -C1 $OPTS
    else
        /usr/bin/rg -e "$SEARCH" "$PATH" $OPTS
    fi
}
