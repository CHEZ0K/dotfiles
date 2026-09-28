#
# ~/.bashrc
#

export PATH="$HOME/.local/bin:$PATH"
export NO_AT_BRIDGE=1
export QT_ACCESSIBILITY=0
export TERMINAL="footclient"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History configuration (5000 entries, no duplicates, auto-append)
HISTSIZE=5000
HISTFILESIZE=5000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Apply pywal colors to terminal
[[ -f "$HOME/.cache/wal/sequences" ]] && cat "$HOME/.cache/wal/sequences"
