#!/bin/sh
set -eu
cat <<'EOF' >> "$HOME/.vimrc"
syntax on
colorscheme slate
set number relativenumber
set cursorline
set showcmd
set wildmenu
set wildmode=longest:full,full
set hlsearch
set ignorecase smartcase
set laststatus=2
set statusline=%f\:%l\:%c\ \[%L\]
set tabstop=2
set shiftwidth=2
set expandtab
filetype plugin indent on
set runtimepath^=~/.fzf
set runtimepath^=~/.vim/bundle/fzf.vim
EOF
