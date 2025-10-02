# Minimal server zsh configuration
# Better history management
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# History options
setopt HIST_IGNORE_DUPS      # Don't record duplicate entries
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicate entries
setopt HIST_FIND_NO_DUPS     # Don't display duplicates when searching
setopt HIST_SAVE_NO_DUPS     # Don't save duplicates
setopt HIST_REDUCE_BLANKS    # Remove blank lines from history
setopt SHARE_HISTORY         # Share history between sessions
setopt INC_APPEND_HISTORY    # Append to history file immediately

# Better completion
autoload -U compinit && compinit
setopt AUTO_LIST             # Automatically list choices on ambiguous completion
setopt AUTO_MENU             # Show completion menu on successive tab press
setopt COMPLETE_IN_WORD      # Allow completion from within a word

# Better directory navigation
setopt AUTO_PUSHD            # Make cd push the old directory onto the directory stack
setopt PUSHD_IGNORE_DUPS     # Don't push multiple copies of the same directory
setopt PUSHD_SILENT          # Don't print the directory stack after pushd or popd

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Enable colors
autoload -U colors && colors

# Simple prompt (minimal for server use)
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# git-checkout-local function for quickly checkout repos
# in ~/repos to ~/workspace
#
# USAGE:
#
# Checkout latest HEAD
# git-checkout-local my-project
#
# # Checkout specific branch
# git-checkout-local my-project main
# git-checkout-local my-project develop

# Checkout specific tag or commit
# git-checkout-local my-project v1.0.0

function git-checkout-local() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: git-checkout-local NAME [BRANCH]"
        echo "Available repositories:"
        for repo in ~/repos/*.git; do
            if [[ -d "$repo" ]]; then
                echo "  $(basename ${repo%.git})"
            fi
        done
        return 1
    fi

    local name=$1
    local branch=${2:-HEAD}
    local repo_path=~/repos/${name}.git
    local worktree_path=~/workspace/${name}

    if [[ ! -d "$repo_path" ]]; then
        echo "Error: Repository $repo_path does not exist"
        return 1
    fi

    mkdir -p "$worktree_path"
    git --git-dir="$repo_path" --work-tree="$worktree_path" checkout -f "$branch"
    cd "$worktree_path" || return 1
}

# Tab completion
function _git-checkout-local() {
    local state
    _arguments \
        '1: :->repos' \
        '2: :->branches'

    case $state in
        repos)
            local -a repos
            for repo in ~/repos/*.git; do
                if [[ -d "$repo" ]]; then
                    repos+=("$(basename ${repo%.git})")
                fi
            done
            _describe 'repositories' repos
            ;;
        branches)
            local repo_name=${words[2]}
            local repo_path=~/repos/${repo_name}.git
            if [[ -d "$repo_path" ]]; then
                local -a branches
                branches=($(git --git-dir="$repo_path" for-each-ref --format='%(refname:short)' refs/heads/))
                _describe 'branches' branches
            fi
            ;;
    esac
}

compdef _git-checkout-local git-checkout-local
