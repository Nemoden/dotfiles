#!/usr/bin/env python3
"""List live Claude Code sessions, ranked against an optional query.

Usage: find-sessions.py [--json] [--window N] [QUERY...]

QUERY may be a session id (or prefix), a name, a former name, a tmux
target/pane id, or free-text description of what the session is doing.
Without QUERY, lists every live session.

Source of truth is ~/.claude/sessions/<pid>.json, written by every running
Claude Code process. Pid must be alive, else file is stale.
"""
import argparse
import glob
import json
import os
import re
import sys

HOME = os.path.expanduser('~')
REGISTRY = os.path.join(HOME, '.claude', 'sessions')
PROJECTS = os.path.join(HOME, '.claude', 'projects')
USAGE_KEYS = ('input_tokens', 'cache_creation_input_tokens',
              'cache_read_input_tokens')
TAIL_BYTES = 4_000_000


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def transcript_path(cwd: str, session_id: str) -> str | None:
    slug = re.sub(r'[^A-Za-z0-9]', '-', cwd)
    p = os.path.join(PROJECTS, slug, session_id + '.jsonl')
    if os.path.exists(p):
        return p
    hits = glob.glob(os.path.join(PROJECTS, '*', session_id + '.jsonl'))
    return hits[0] if hits else None


def tail_rows(path: str) -> list[dict]:
    with open(path, 'rb') as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - TAIL_BYTES))
        data = f.read().decode('utf-8', 'replace')
    rows = []
    for line in data.splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            pass
    return rows


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return ' '.join(c.get('text', '') for c in content
                        if isinstance(c, dict) and c.get('type') == 'text')
    return ''


def digest(path: str) -> dict:
    """Context tokens, latest away summary, recent user prompts."""
    used = None
    summary = ''
    prompts: list[str] = []
    model = ''
    for r in tail_rows(path):
        t = r.get('type')
        if t == 'system' and r.get('subtype') == 'compact_boundary':
            used = (r.get('compactMetadata') or {}).get('postTokens', used)
        elif t == 'system' and r.get('subtype') == 'away_summary':
            summary = r.get('content', '')
        elif t == 'assistant':
            m = r.get('message') or {}
            u = m.get('usage') or {}
            total = sum(u.get(k) or 0 for k in USAGE_KEYS)
            if total and m.get('model') != '<synthetic>':
                used, model = total, m.get('model', model)
        elif t == 'user' and not r.get('isMeta') and not r.get('isSidechain'):
            s = text_of((r.get('message') or {}).get('content')).strip()
            if s and not s.startswith('<'):
                prompts.append(s)
    return {'context_tokens': used, 'model': model,
            'away_summary': summary, 'recent_prompts': prompts[-5:]}


def words(s: str) -> set[str]:
    return {w for w in re.findall(r'[a-z0-9]{3,}', s.lower())}


def score(s: dict, query: str) -> float:
    q = query.strip().lower()
    if not q:
        return 0
    names = [s['name']] + s['former_names']
    exact = [s['session_id'], s['pane'], s['tmux']] + names
    if any(q == (x or '').lower() for x in exact):
        return 1000
    if s['session_id'].startswith(q) or any(
            q in (x or '').lower() for x in names + [s['tmux']]):
        return 500
    qw = words(q)
    if not qw:
        return 0
    name_hits = len(qw & words(' '.join(names + [s['tmux']])))
    body = ' '.join([s['cwd'], s.get('away_summary', '')]
                    + s.get('recent_prompts', []))
    body_hits = len(qw & words(body))
    return (60 * name_hits + 40 * body_hits) / len(qw)


def load(window: int | None) -> list[dict]:
    out = []
    for f in glob.glob(os.path.join(REGISTRY, '*.json')):
        try:
            d = json.load(open(f))
        except (ValueError, OSError):
            continue
        if 'sessionId' not in d or not alive(d.get('pid', -1)):
            continue
        tmux = d.get('tmux') or ''
        s = {
            'pid': d['pid'],
            'session_id': d['sessionId'],
            'name': d.get('name', ''),
            'former_names': [x.get('name', '') for x in d.get('formerNames', [])],
            'status': d.get('status', ''),
            'updated_at': d.get('updatedAt', 0),
            'kind': d.get('kind', ''),
            'cwd': d.get('cwd', ''),
            'tmux': tmux,
            'pane': tmux.rsplit('.', 1)[-1] if '.%' in tmux else '',
            'transcript': transcript_path(d.get('cwd', ''), d['sessionId']),
        }
        if s['transcript']:
            s.update(digest(s['transcript']))
            if window and s['context_tokens']:
                s['context_pct'] = round(s['context_tokens'] * 100 / window)
        out.append(s)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--window', type=int, default=None,
                    help='context window tokens, to print percent')
    ap.add_argument('query', nargs='*')
    a = ap.parse_args()
    query = ' '.join(a.query)
    sessions = load(a.window)
    for s in sessions:
        s['score'] = score(s, query)
    if query:
        sessions = [s for s in sessions if s['score'] > 0]
    sessions.sort(key=lambda s: -s['score'])
    if a.json:
        json.dump(sessions, sys.stdout, indent=1)
        return
    for s in sessions:
        pct = f"{s['context_pct']}%" if 'context_pct' in s else (
            f"{s.get('context_tokens') or '?'} tok")
        print(f"[{s['score']:.0f}] {s['name']}  id={s['session_id']}  "
              f"tmux={s['tmux']}  {s['status']}  ctx={pct}")
        if s['former_names']:
            print(f"    former names: {', '.join(s['former_names'])}")
        print(f"    cwd: {s['cwd']}")
        if s.get('away_summary'):
            print(f"    doing: {s['away_summary'][:300]}")
        if s.get('recent_prompts'):
            print(f"    last prompt: {s['recent_prompts'][-1][:200]}")


if __name__ == '__main__':
    main()
