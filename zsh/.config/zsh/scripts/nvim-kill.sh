# Kill nvim processes by working directory path
# Usage: nvim-kill <path>
# Example: nvim-kill work/metis
#          nvim-kill ~/repos/my-project
nvim-kill() {
    if [[ -z "$1" ]]; then
        echo "Usage: nvim-kill <path>"
        return 1
    fi

    local target
    target=$(realpath "$1" 2>/dev/null || echo "$HOME/$1")

    local pids
    pids=$(lsof -c nvim 2>/dev/null | awk '/cwd/ && $NF ~ target {print $2}' target="$target")

    if [[ -z "$pids" ]]; then
        echo "No nvim processes found in: $target"
        return 1
    fi

    echo "Killing nvim processes in $target: $pids"
    echo "$pids" | xargs kill
}
