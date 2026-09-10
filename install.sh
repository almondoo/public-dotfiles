#!/bin/bash
set -e

# 後段の自己位置解決に bash の配列が要る。dash で走らせると素の
# "Bad substitution" で死ぬだけなので、何が問題かを明示して止める。
if [ -z "${BASH_VERSION:-}" ]; then
    echo "install.sh requires bash. Run: bash install.sh" >&2
    exit 1
fi

trap 'code=$?; echo "" >&2; echo "install.sh FAILED at line $LINENO (exit $code)." >&2; echo "Links created before this point are left in place; fix the cause and re-run." >&2' ERR

# リポジトリの場所をこのスクリプト自身の位置から求める。これで clone 先が
# どこでも動く。このスクリプトへの symlink も辿るので PATH に置いてもよい。
# 明示指定したい場合は DOTFILES=/path/to/repo ./install.sh
if [ -n "${DOTFILES:-}" ]; then
    if [ ! -d "$DOTFILES" ]; then
        echo "install.sh: DOTFILES=$DOTFILES が存在しません。" >&2
        exit 1
    fi
    # 相対指定でも動くよう絶対パスに正規化する。
    DOTFILES="$(cd -P -- "$DOTFILES" && pwd)"
else
    # 標準入力経由 (cat install.sh | bash、curl ... | bash) では BASH_SOURCE が
    # 空になり自己位置が分からない。ここで cwd にフォールバックすると、既に
    # インストール済みの HOME で実行した場合に symlink を自分自身へ張り替えて
    # 壊してしまう。推測せずに止める。
    if [ -z "${BASH_SOURCE[0]:-}" ]; then
        echo "install.sh: リポジトリの場所を特定できません（標準入力経由で実行されました）。" >&2
        echo "ファイルとして実行するか (bash install.sh)、DOTFILES=/path/to/repo を指定してください。" >&2
        exit 1
    fi
    self="${BASH_SOURCE[0]}"
    while [ -L "$self" ]; do
        self_dir="$(cd -P -- "$(dirname -- "$self")" && pwd)"
        self="$(readlink -- "$self")"
        case "$self" in
            /*) ;;
            *) self="$self_dir/$self" ;;
        esac
    done
    DOTFILES="$(cd -P -- "$(dirname -- "$self")" && pwd)"
fi

# 解決結果が本当にこのリポジトリかを確かめる。取り違えたまま進むと既存の
# 設定を壊しうるので、目印になるファイルの有無で門前払いする。
if [ ! -f "$DOTFILES/install.sh" ] || [ ! -d "$DOTFILES/claude" ]; then
    echo "install.sh: $DOTFILES は dotfiles リポジトリではないようです。" >&2
    echo "リポジトリ内で実行するか、DOTFILES=/path/to/repo を指定してください。" >&2
    exit 1
fi

missing=0

link() {
    local src="$1"
    local dst="$2"

    if [ ! -e "$src" ]; then
        echo "Skip (source not found): $src"
        missing=$((missing + 1))
        return
    fi

    # 念のための二重防御。src と dst が同一だと、下で dst を消してから
    # 自分自身を指す壊れた symlink を作ってしまう。
    if [ "$src" = "$dst" ]; then
        echo "Skip (source and destination are the same): $dst" >&2
        missing=$((missing + 1))
        return
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        # 既存のバックアップは絶対に上書きしない。最初の1つがユーザー本来の
        # 設定であり、失うと復元手段がなくなる。
        local backup="$dst.bak"
        if [ -e "$backup" ]; then
            backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
        fi
        echo "Backing up: $dst -> $backup"
        mv "$dst" "$backup"
    fi

    # 既存の symlink は張り替える。ただし別の dotfiles が張ったものなら
    # 黙って消さず、何を置き換えたか必ず表示する。
    if [ -L "$dst" ]; then
        local old
        old="$(readlink -- "$dst")"
        case "$old" in
            "$DOTFILES"/*) ;;
            *) echo "Replacing foreign symlink: $dst -> $old" ;;
        esac
        rm "$dst"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "Linked: $dst -> $src"
}

echo "Repository: $DOTFILES"

# Claude Code
mkdir -p "$HOME/.claude"
# CLAUDE-ja.md は参照用の日本語訳なので symlink しない。
# ここの一覧を増減したら uninstall.sh 側の一覧も必ず合わせること。
link "$DOTFILES/claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"
link "$DOTFILES/claude/agents"                "$HOME/.claude/agents"
link "$DOTFILES/claude/commands"              "$HOME/.claude/commands"
link "$DOTFILES/claude/skills"                "$HOME/.claude/skills"
link "$DOTFILES/claude/workflows"             "$HOME/.claude/workflows"
link "$DOTFILES/claude/hooks"                 "$HOME/.claude/hooks"
link "$DOTFILES/claude/output-styles"         "$HOME/.claude/output-styles"
link "$DOTFILES/claude/settings.json"         "$HOME/.claude/settings.json"
link "$DOTFILES/claude/statusline.py"         "$HOME/.claude/statusline.py"

# シェル
link "$DOTFILES/.zshrc" "$HOME/.zshrc"

# マシン固有の秘密情報。テンプレートから1度だけコピーし、既存は絶対に上書きしない。
if [ ! -e "$HOME/.zshrc.local" ]; then
    if [ -e "$DOTFILES/.zshrc.local.example" ]; then
        # サブシェルで umask を効かせ、一瞬たりとも他者可読にしない。
        (umask 077 && cp "$DOTFILES/.zshrc.local.example" "$HOME/.zshrc.local")
        chmod 600 "$HOME/.zshrc.local"
        echo "Created $HOME/.zshrc.local from example (fill in your secrets)"
    else
        echo "Skip (source not found): $DOTFILES/.zshrc.local.example"
        missing=$((missing + 1))
    fi
else
    echo "Skipped $HOME/.zshrc.local (already exists)"
fi

echo ""
if [ "$missing" -gt 0 ]; then
    echo "Installation FAILED: $missing source(s) not found under $DOTFILES."
    echo "Run install.sh from inside the repository, or set DOTFILES=/path/to/repo."
    exit 1
fi
echo "Installation complete."
