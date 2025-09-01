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
alias gra='git rebase --abort'
alias grs="git restore --staged"
alias gmrg='git mergetool'
alias gs='git status && git --no-pager diff --stat'
alias gits="git status"
alias gp='git push'
alias gpl='git pull'
#alias gu='git reset --mixed HEAD'
alias gpf="git push -f"
alias gfa="git fetch --all"
function pushnew() {
    git push --set-upstream origin $(git branch --show-current)
}

function gitlog() {
    git log --oneline --decorate --pretty=format:"%C(yellow)%h%Creset %C(auto)%d %C(white)(%ad)%Creset %s" --date=format:'%Y-%m-%d %H:%M:%S'
}

function base-branch {
    git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'
}
alias current-branch="git branch --show-current"

function rebase-branch {
    CURRENT_BRANCH=$(git branch --show-current)
    BASE_BRANCH=$1
    if [[ $BASE_BRANCH = "" ]]
    then
        BASE_BRANCH=$(base-branch)
    fi
 
    git checkout $BASE_BRANCH && git pull && git checkout $CURRENT_BRANCH && git rebase -i $BASE_BRANCH
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

function minimetis-kill-pod() {
  local podName=${1:-"api"}
  local namespace=${2:-"minimetis"}
  echo "Deleting pods with name pattern: '(${podName})-[\\w\\d-]*\\w' in namespace '${namespace}'"
  kubectl get pod -n ${namespace}  --no-headers -o custom-columns=":metadata.name" | grep -v 'keys' | grep -Eo "^(${podName})-[a-zA-Z0-9\-]*\w" | xargs kubectl delete pod -n ${namespace}
}
