#!/bin/bash
set -e

for f in CLAUDE.md agents commands skills workflows settings.json statusline-command.sh statusline.py hooks; do
    target="$HOME/.claude/$f"
    if [ -L "$target" ]; then
        rm "$target"
        echo "Removed symlink: $target"
    fi
done

# Shell
if [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
    echo "Removed symlink: $HOME/.zshrc"
fi

echo "Uninstall complete. Run install.sh again to restore."
