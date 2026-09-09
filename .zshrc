# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"


# nodebrew
export PATH=$HOME/.nodebrew/current/bin:$PATH


. "$HOME/.local/bin/env"

export PATH="$HOME/.local/bin:$PATH"

# Homebrew Python 3.13
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"

# goenvの設定
export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"

# go install 済みのグローバルツール一覧
# goenv は Go バージョンごとに GOPATH を分けるため、現行バージョン分のみ表示される
# 各ツールのモジュール名・バージョンまで知りたい場合: go version -m "$(go env GOPATH)"/bin/*
alias golist='ls -1 "$(go env GOPATH)/bin"'

alias dc='docker compose'

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Claude Code: メインセッション専用ルール(claude-main-extra.md)を既定で注入する。
# 実在サブコマンドの時だけフラグを付けず素通し(許可リスト方式)。
# これにより `claude プロンプト文` の位置引数起動でも注入される。
# リストは `claude --help` の Commands: 節に追従させる。漏れた新サブコマンドには
# 不要なフラグが付くが、ルートオプションとして消費され無視されるだけで実害はない
# (`claude --append-system-prompt-file <file> doctor` が正常動作することを実測済み)。
# headless 実行(-p/--print)はメインセッションではないため注入しない(2026-08-20〜):
# システムプロンプト dump への混入と、/daily 等の `claude -p` バックフィルへの
# 毎回 ~5.4k token の上乗せ + headless で応答不能な AskUserQuestion 必須ルールの
# 混入を避ける。`--model x -p` の形があるため判定は $1 でなく "$@" 全体を走査し、
# `--` 以降(プロンプト本文)は見ない。短フラグ連結(-pv 等)は検出しない既知の制限。
claude() {
  case "$1" in
    agents|auth|auto-mode|doctor|gateway|install|mcp|plugin|plugins|project|setup-token|ultrareview|update|upgrade)
      command claude "$@"
      ;;
    *)
      local _arg
      for _arg in "$@"; do
        case "$_arg" in
          --) break ;;
          -p|--print)
            command claude "$@"
            return
            ;;
        esac
      done
      command claude \
        --append-system-prompt-file "$HOME/public-dotfiles/claude/claude-main-extra.md" "$@"
      ;;
  esac
}

# Machine-local / secret settings (not tracked by dotfiles)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
