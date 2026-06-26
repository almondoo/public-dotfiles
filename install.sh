#!/bin/bash
set -e

# Resolve the repo location from this script's own path, so install.sh works
# regardless of where the repo is cloned or what the directory is named.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
    local src="$1"
    local dst="$2"

    if [ ! -e "$src" ]; then
        echo "Skip (source not found): $src"
        return
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "Backing up: $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
    fi

    [ -L "$dst" ] && rm "$dst"

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "Linked: $dst -> $src"
}

# Claude Code
mkdir -p "$HOME/.claude"
# CLAUDE-ja.md is a Japanese translation for reference only; not symlinked.
link "$DOTFILES/.claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"
link "$DOTFILES/.claude/agents"                "$HOME/.claude/agents"
link "$DOTFILES/.claude/commands"              "$HOME/.claude/commands"
link "$DOTFILES/.claude/skills"                "$HOME/.claude/skills"
link "$DOTFILES/.claude/workflows"             "$HOME/.claude/workflows"
link "$DOTFILES/.claude/hooks"                 "$HOME/.claude/hooks"
link "$DOTFILES/.claude/settings.json"         "$HOME/.claude/settings.json"
link "$DOTFILES/.claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link "$DOTFILES/.claude/statusline.py"         "$HOME/.claude/statusline.py"

# Shell
link "$DOTFILES/.zshrc" "$HOME/.zshrc"

# Shell local secrets (copy template once; never overwrite existing secrets)
if [ ! -e "$HOME/.zshrc.local" ]; then
    cp "$DOTFILES/.zshrc.local.example" "$HOME/.zshrc.local"
    chmod 600 "$HOME/.zshrc.local"
    echo "Created $HOME/.zshrc.local from example (fill in your secrets)"
else
    echo "Skipped $HOME/.zshrc.local (already exists)"
fi

echo ""
echo "Installation complete."
