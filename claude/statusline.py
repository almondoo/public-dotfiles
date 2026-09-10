#!/usr/bin/env python3
"""Statusline: agnoster-style prompt + sparkline gauges"""
import json, sys, os, re, subprocess, socket, time, hashlib

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

SPARKS = ' ▁▂▃▄▅▆▇█'
R = '\033[0m'
GREY = '\033[38;5;245m'         # labels, separators, reset countdown
GAUGE_EMPTY = '\033[38;5;242m'  # unused cells of a gauge
SEP = ''  # powerline separator

CACHE_DIR = os.path.expanduser('~/.cache/claude-statusline')
CACHE_TTL = 5          # seconds: reuse cached git info within this window
CACHE_MAX_AGE = 86400  # seconds: prune cache files older than this on write

# --- git info (with per-session/per-cwd caching) ---

def _git_branch_and_dirty(cwd):
    branch = ''
    try:
        branch = subprocess.check_output(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=cwd,
            stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        pass

    dirty = ''
    if branch:
        try:
            status = subprocess.check_output(
                ['git', 'status', '--porcelain'],
                cwd=cwd,
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if status:
                dirty = ' ±'
        except Exception:
            pass
    return branch, dirty


def _cleanup_cache_dir():
    # Best-effort prune of stale cache files; never allowed to raise.
    try:
        now = time.time()
        for name in os.listdir(CACHE_DIR):
            path = os.path.join(CACHE_DIR, name)
            try:
                if now - os.path.getmtime(path) >= CACHE_MAX_AGE:
                    os.remove(path)
            except Exception:
                pass
    except Exception:
        pass


def get_git_info(cwd):
    """Return (branch, dirty) for cwd, using a short-lived on-disk cache
    keyed by session_id + cwd. Any cache failure silently falls back to
    running git directly -- a broken cache must never break the statusline.
    """
    session_id = data.get('session_id') or ''
    cache_file = None
    if session_id:
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            safe_session = re.sub(r'[^A-Za-z0-9_-]', '', session_id)[:64]
            cwd_hash = hashlib.sha1(cwd.encode()).hexdigest()[:12]
            cache_file = os.path.join(CACHE_DIR, f'{safe_session}_{cwd_hash}')
        except Exception:
            cache_file = None

    if cache_file:
        try:
            mtime = os.path.getmtime(cache_file)
            if time.time() - mtime < CACHE_TTL:
                with open(cache_file, 'r') as f:
                    content = f.read()
                if content:  # empty means a torn write -- fall through to git
                    branch, _, dirty = content.partition('\t')
                    return branch, dirty
        except Exception:
            pass

    branch, dirty = _git_branch_and_dirty(cwd)

    if cache_file:
        try:
            # Write to a temp file and rename, so a concurrent reader never
            # picks up a half-written entry.
            tmp_path = f'{cache_file}.{os.getpid()}'
            with open(tmp_path, 'w') as f:
                f.write(f'{branch}\t{dirty}')
            os.replace(tmp_path, cache_file)
            _cleanup_cache_dir()
        except Exception:
            pass

    return branch, dirty


# --- Line 1: agnoster-style prompt ---

def get_worktree_name():
    name = (data.get('workspace') or {}).get('git_worktree')
    if not name:
        name = (data.get('worktree') or {}).get('name')
    if not name:
        return name
    # The host supplies this string; drop control chars so a stray newline or
    # escape sequence cannot break the two-line output.
    return re.sub(r'[\x00-\x1f\x7f]', '', str(name))


def agnoster_line():
    cwd = data.get('cwd') or os.getcwd()
    home = os.path.expanduser('~')
    if cwd.startswith(home):
        cwd = '~' + cwd[len(home):]

    branch, dirty = get_git_info(data.get('cwd') or os.getcwd())
    worktree_name = get_worktree_name()

    # Colors: (bg, fg, bg_fg) per segment. bg_fg is the foreground color
    # matching this segment's background, used to paint the separator
    # arrow leading into the segment (and the final closing arrow).
    S1_BG, S1_FG, S1_BG_FG = '\033[48;5;33m', '\033[38;5;16m', '\033[38;5;33m'   # directory
    WT_BG, WT_FG, WT_BG_FG = '\033[48;5;98m', '\033[38;5;16m', '\033[38;5;98m'   # worktree
    S2_BG, S2_FG, S2_BG_FG = '\033[48;5;34m', '\033[38;5;16m', '\033[38;5;34m'   # git branch

    segments = [(cwd, S1_BG, S1_FG, S1_BG_FG)]
    if worktree_name:
        segments.append((worktree_name, WT_BG, WT_FG, WT_BG_FG))
    if branch:
        segments.append((f'{branch}{dirty}', S2_BG, S2_FG, S2_BG_FG))

    line = ''
    for i, (text, bg, fg, bg_fg) in enumerate(segments):
        if i == 0:
            line += f'{bg}{fg} {text} '
        else:
            prev_bg_fg = segments[i - 1][3]
            line += f'{bg}{prev_bg_fg}{SEP}'
            line += f'{fg} {text} '

    last_bg_fg = segments[-1][3]
    line += f'{R}{last_bg_fg}{SEP}{R}'

    return line


# --- Line 2: sparkline gauges ---

def gradient(pct):
    pct = min(max(pct, 0), 100)
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'

def spark_gauge(pct, width=8):
    """Return (filled, empty): the drawn cells and how many cells stay unused."""
    pct = min(max(pct, 0), 100)
    level = pct / 100
    filled = ''
    empty = 0
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            filled += SPARKS[8]
        elif level <= seg_start:
            empty += 1
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            idx = int(frac * 8)
            if idx:
                filled += SPARKS[idx]
            else:
                empty += 1
    return filled, empty

def format_resets_at(resets_at):
    """Countdown to a rate-limit reset: 43m / 2h04m / 3d22h44m."""
    if resets_at is None:
        return ''
    try:
        remaining = resets_at - time.time()
    except Exception:
        return ''
    if remaining <= 0:
        return ''

    total_minutes = int(remaining // 60)
    days, day_minutes = divmod(total_minutes, 1440)
    hours, minutes = divmod(day_minutes, 60)
    if days:
        rel = f'{days}d{hours:02d}h{minutes:02d}m'
    elif hours:
        rel = f'{hours}h{minutes:02d}m'
    else:
        rel = f'{minutes}m'
    return f'{GREY} ↺{rel}{R}'

def human_tokens(n):
    if n >= 1_000_000:
        return f'{n / 1_000_000:.1f}M'
    if n >= 1_000:
        return f'{n / 1_000:.1f}k'
    return str(int(n))

def fmt(label, pct, extra=''):
    p = round(pct)
    filled, empty = spark_gauge(pct)
    bar = f'{gradient(pct)}{filled}{R}{GAUGE_EMPTY}{"░" * empty}{R}'
    return f'{GREY}{label}{R} {bar} {p}%{extra}'

def gauge_line():
    model = (data.get('model') or {}).get('display_name') or 'Claude'
    parts = [str(model)]

    cw = data.get('context_window') or {}
    ctx = cw.get('used_percentage')
    if ctx is not None:
        # used_percentage counts input tokens only (input + cache read/write),
        # so total_input_tokens is the numerator that matches it.
        used, size = cw.get('total_input_tokens'), cw.get('context_window_size')
        tokens = f'{GREY} {human_tokens(used)}/{human_tokens(size)}{R}' if used is not None and size else ''
        parts.append(fmt('ctx', ctx, tokens))

    rate_limits = data.get('rate_limits') or {}

    five_hour = rate_limits.get('five_hour') or {}
    five = five_hour.get('used_percentage')
    if five is not None:
        parts.append(fmt('5h', five, format_resets_at(five_hour.get('resets_at'))))

    seven_day = rate_limits.get('seven_day') or {}
    week = seven_day.get('used_percentage')
    if week is not None:
        parts.append(fmt('7d', week, format_resets_at(seven_day.get('resets_at'))))

    cost = (data.get('cost') or {}).get('total_cost_usd')
    if cost is not None:
        parts.append(f'${cost:.2f}')

    return f' {GREY}│{R} '.join(parts)


# Render each line independently: whatever the host sends, a failure in one
# line must not blank out the other (a crash here means an empty status bar).
try:
    line1 = agnoster_line()
except Exception:
    line1 = ''
try:
    line2 = gauge_line()
except Exception:
    line2 = 'Claude'

print(f'{line1}\n{line2}', end='')
