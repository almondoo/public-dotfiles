#!/bin/bash
set -e

if [ -z "${BASH_VERSION:-}" ]; then
    echo "uninstall.sh requires bash. Run: bash uninstall.sh" >&2
    exit 1
fi

# install.sh と同じ自己位置解決。clone 先がどこでも動くようにするため。
if [ -n "${DOTFILES:-}" ]; then
    if [ ! -d "$DOTFILES" ]; then
        echo "uninstall.sh: DOTFILES=$DOTFILES が存在しません。" >&2
        exit 1
    fi
    DOTFILES="$(cd -P -- "$DOTFILES" && pwd)"
else
    # 標準入力経由だと自己位置が分からない。ここで cwd に落ちると「自分の
    # symlink かどうか」の判定が狂うので、推測せずに止める。
    if [ -z "${BASH_SOURCE[0]:-}" ]; then
        echo "uninstall.sh: リポジトリの場所を特定できません（標準入力経由で実行されました）。" >&2
        echo "ファイルとして実行するか (bash uninstall.sh)、DOTFILES=/path/to/repo を指定してください。" >&2
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

if [ ! -f "$DOTFILES/uninstall.sh" ] || [ ! -d "$DOTFILES/claude" ]; then
    echo "uninstall.sh: $DOTFILES は dotfiles リポジトリではないようです。" >&2
    exit 1
fi

echo "Repository: $DOTFILES"

# このリポジトリを指す symlink だけを削除する。別の dotfiles が張った
# symlink は、黙って切らずにそのまま残す。
unlink_ours() {
    local target="$1"

    [ -L "$target" ] || return 0

    local dest
    dest="$(readlink -- "$target")"
    case "$dest" in
        "$DOTFILES"/*)
            rm "$target"
            echo "Removed symlink: $target"
            ;;
        *)
            echo "Kept (not ours): $target -> $dest"
            ;;
    esac
}

# この一覧は install.sh 側と必ず一致させること。
for f in CLAUDE.md agents commands skills workflows settings.json statusline.py hooks output-styles; do
    unlink_ours "$HOME/.claude/$f"
done

# シェル
unlink_ours "$HOME/.zshrc"

echo ""
echo "Uninstall complete. Run install.sh to recreate the symlinks."
echo "Note: files backed up as *.bak are NOT restored automatically — move them"
echo "back yourself if you want your pre-dotfiles config. ~/.zshrc.local is left"
echo "in place because it holds your secrets."
