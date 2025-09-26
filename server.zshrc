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
