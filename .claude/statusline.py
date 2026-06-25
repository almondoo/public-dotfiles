#!/usr/bin/env python3
"""Statusline: agnoster-style prompt + sparkline gauges"""
import json, sys, os, subprocess, socket

data = json.load(sys.stdin)

SPARKS = ' ▁▂▃▄▅▆▇█'
R = '\033[0m'
DIM = '\033[2m'
SEP = '\ue0b0'  # powerline separator

# --- Line 1: agnoster-style prompt ---

def agnoster_line():
    cwd = data.get('cwd', os.getcwd())
    home = os.path.expanduser('~')
    if cwd.startswith(home):
        cwd = '~' + cwd[len(home):]

    # git branch + dirty status
    branch = ''
    try:
        branch = subprocess.check_output(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=data.get('cwd', os.getcwd()),
            stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        pass

    dirty = ''
    if branch:
        try:
            status = subprocess.check_output(
                ['git', 'status', '--porcelain'],
                cwd=data.get('cwd', os.getcwd()),
                stderr=subprocess.DEVNULL
            ).decode().strip()
            if status:
                dirty = ' ±'
        except Exception:
            pass

    # Colors: bg/fg pairs for agnoster segments
    # Segment 1: directory  (blue bg, white fg)
    S1_BG = '\033[48;5;33m'
    S1_FG = '\033[38;5;16m'
    S1_BG_FG = '\033[38;5;33m'
    # Segment 2: git branch (green bg, white fg) - only if branch exists
    S2_BG = '\033[48;5;34m'
    S2_FG = '\033[38;5;16m'
    S2_BG_FG = '\033[38;5;34m'

    line = ''
    # segment 1: directory
    line += f'{S1_BG}{S1_FG} {cwd} '

    if branch:
        # separator 1→2
        line += f'{S2_BG}{S1_BG_FG}{SEP}'
        # segment 2: git branch
        line += f'{S2_FG} {branch}{dirty} '
        # final separator
        line += f'{R}{S2_BG_FG}{SEP}{R}'
    else:
        line += f'{R}{S1_BG_FG}{SEP}{R}'

    return line


# --- Line 2: sparkline gauges ---

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'

def spark_gauge(pct, width=8):
    pct = min(max(pct, 0), 100)
    level = pct / 100
    gauge = ''
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            gauge += SPARKS[8]
        elif level <= seg_start:
            gauge += SPARKS[0]
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            gauge += SPARKS[int(frac * 8)]
    return gauge

def fmt(label, pct):
    p = round(pct)
    return f'{DIM}{label}{R} {gradient(pct)}{spark_gauge(pct)}{R} {p}%'

model = data.get('model', {}).get('display_name', 'Claude')
parts = [model]

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    parts.append(fmt('ctx', ctx))

five = data.get('rate_limits', {}).get('five_hour', {}).get('used_percentage')
if five is not None:
    parts.append(fmt('5h', five))

week = data.get('rate_limits', {}).get('seven_day', {}).get('used_percentage')
if week is not None:
    parts.append(fmt('7d', week))

gauge_line = f' {DIM}│{R} '.join(parts)

print(f'{agnoster_line()}\n{gauge_line}', end='')
