#!/bin/sh
set -eu

# Avoid double-sourcing bash_completion
sed -i 's/bash_completion/bash_completion_orig/g' "$HOME/.bashrc" 2>/dev/null || true

cat <<'EOF' >> "$HOME/.bashrc"

export HISTSIZE=''
export HISTFILESIZE=''
export LANG="C.UTF-8"
export LC_COLLATE="C.UTF-8"
export LC_CTYPE="C.UTF-8"
export EDITOR=/usr/bin/vim
export VISUAL=/usr/bin/vim
export GPG_TTY=$(tty)

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

if type rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files'
    export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi

if [ -d "$HOME/.arkade/bin" ]; then
    export PATH="$PATH:$HOME/.arkade/bin"
fi

# CommandBox
if [ -d /opt/commandbox ]; then
    export PATH="$PATH:/opt/commandbox"
fi

# ColdFusion helpers
export CF_HOME=/opt/coldfusion2025
alias cf-start='sudo systemctl start cf-server'
alias cf-stop='sudo systemctl stop cf-server'
alias cf-status='sudo systemctl status cf-server'
alias cf-logs='sudo journalctl -u cf-server -f'
alias lucee-start='sudo systemctl start lucee-server'
alias lucee-logs='sudo journalctl -u lucee-server -f'

if [ -t 0 ] && [ -f "$HOME/.welcome" ]; then
  cat "$HOME/.welcome"
  echo
  rm -f "$HOME/.welcome"
fi
EOF
