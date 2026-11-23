#!/usr/bin/env python3
"""Private, isolated concept experiments against REAL Telegram source trees.

No pushes, merges, real account access, or production deployment.
"""
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import traceback

import collab

ROOT = Path(__file__).resolve().parent
STATE = ROOT / '.lab' / 'native'
SOURCES = {
    'ios': Path.home() / 'Projects/telegram-integrations/Telegram-iOS-reaction-wheel',
    'android': Path.home() / 'Projects/telegram-integrations/Telegram-Android-reaction-wheel',
}
JOBS = STATE / 'jobs.json'
STEPS = ('design', 'design-review', 'design-revise', 'implement-ios', 'implement-android', 'review-ios', 'review-android', 'fix-ios', 'fix-android')


def git(cwd, *args):
    out = subprocess.run(['git', *args], cwd=cwd, text=True, capture_output=True)
    if out.returncode:
        raise RuntimeError('git ' + ' '.join(args) + ': ' + out.stderr[-600:])
    return out.stdout.strip()


def registry():
    return json.loads(JOBS.read_text()) if JOBS.exists() else {}


def store(jobs):
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = JOBS.with_suffix('.tmp')
    tmp.write_text(json.dumps(jobs, ensure_ascii=False, indent=2))
    tmp.replace(JOBS)


def update(slug, **fields):
    jobs = registry()
    jobs[slug].update(fields)
    store(jobs)


def validate_source(platform):
    source = SOURCES[platform]
    if not source.is_dir():
        raise RuntimeError(f'Missing {platform} genuine Telegram source: {source}')
    if git(source, 'status', '--porcelain'):
        raise RuntimeError(f'{platform} source has uncommitted changes; refusing to modify')
    if not git(source, 'branch', '--show-current').startswith('concept-lab/'):
        raise RuntimeError(f'{platform} source must be on a concept-lab branch')
    remote = git(source, 'remote', 'get-url', 'origin')
    expected = 'TelegramMessenger/Telegram-iOS' if platform == 'ios' else 'DrKLO/Telegram'
    if expected not in remote:
        raise RuntimeError(f'Unexpected {platform} upstream {remote}')
    return source


def prepare(slug, prompt):
    collab.safe_slug(slug)
    if not prompt.strip():
        raise RuntimeError('Empty concept')
    if slug in registry():
        raise RuntimeError('Concept already exists')
    paths = {}
    for p in ('ios', 'android'):
        validate_source(p)
        target = STATE / slug / p
        if target.exists():
            raise RuntimeError(f'Existing worktree path {target}')
        if git(SOURCES[p], 'branch', '--list', f'concept-lab/{slug}'):
            raise RuntimeError(f'Branch already exists {p}: concept-lab/{slug}')
        paths[p] = target
    # Keep user prompt PRIVATE in ignored .lab, not in public GitHub.
    home = STATE / slug
    home.mkdir(parents=True)
    (home / 'SPEC.md').write_text('# ' + slug + '\n\n' + prompt + '\n\nNative client experiment on isolated Telegram TEST DC only. No production accounts.\n')
    created = []
    try:
        for p in ('ios', 'android'):
            git(SOURCES[p], 'worktree', 'add', '-b', f'concept-lab/{slug}', str(paths[p]), 'HEAD')
            created.append((p, paths[p]))
    except Exception:
        for p, path in reversed(created):
            git(SOURCES[p], 'worktree', 'remove', '--force', str(path))
            git(SOURCES[p], 'branch', '-D', f'concept-lab/{slug}')
        raise
    jobs = registry()
    jobs[slug] = {'mode': 'native', 'phase': 'prepared', 'created_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                  'paths': {p: str(path) for p, path in paths.items()}, 'completed': []}
    store(jobs)
    return paths


def run_stage(slug, name, agent, cwd, instruction, readonly=False):
    home = STATE / slug
    marker = home / (name + '.exit')
    if marker.exists() and marker.read_text().strip() == '0':
        return
    update(slug, phase=name)
    log = home / (name + '.log')
    output = collab.tool(agent, cwd, instruction, log, readonly=readonly, timeout=3600)
    if readonly:
        if not output.strip():
            raise RuntimeError(f'Empty review: {name}')
        (home / (name + '.md')).write_text(output[-30000:])
    marker.write_text('0')
    jobs = registry()
    completed = jobs[slug]['completed']
    if name not in completed:
        completed.append(name)
    store(jobs)


PROTECTED_SOURCE_PARTS = (
    'ConnectionsManager.java', 'LoginActivity.java', 'AppDelegate.swift',
    'GoogleService-Info.plist', 'google-services.json', 'ApiCredentials',
    '.entitlements', '.mobileprovision', 'keystore', '.p12',
)


def inspect_source_changes(platform, worktree):
    """Fail closed on credentials, Test DC/auth enforcement, or unexpected binaries."""
    status = subprocess.run(
        ['git', 'status', '--porcelain=v1', '-uall'],
        cwd=worktree, capture_output=True, text=True, check=True,
    )
    changed = [line[3:].split(' -> ')[-1] for line in status.stdout.splitlines()]
    for path in changed:
        if any(token.lower() in path.lower() for token in PROTECTED_SOURCE_PARTS):
            raise RuntimeError(f'{platform}: protected source edit, human review required: {path}')
        if path.startswith('../') or path.startswith('/') or '\x00' in path:
            raise RuntimeError(f'{platform}: invalid source path: {path}')
    return changed


def execute(slug):
    jobs = registry()
    if slug not in jobs or jobs[slug]['mode'] != 'native':
        raise RuntimeError('Native job not found')
    home = STATE / slug
    ios, android = (Path(jobs[slug]['paths'][p]) for p in ('ios','android'))
    shared = home / 'UX_DESIGN.md'
    review = home / 'DESIGN_REVIEW.md'
    spec = (home / 'SPEC.md').read_text()
    try:
        run_stage(slug, 'design', 'claude', home,
                  f'You are UX owner for a native Telegram iOS+Android concept. Design BOTH clients. Original spec:\n{spec}\n'
                  'Write UX_DESIGN.md in current directory with gestures, entry points, edge cases, native variations, dark mode, accessibility, and testable acceptance. No mock apps, no access to production data. No git commands.')
        if not shared.is_file():
            raise RuntimeError('Missing UX_DESIGN.md')
        run_stage(slug, 'design-review', 'codex', home,
                  'Read UX_DESIGN.md. Critically assess iOS/Android feasibility, affordances, transitions, security and performance. Write DESIGN_REVIEW.md in current directory with P0/P1 and concrete corrections. No coding or Git.')
        if not review.is_file():
            raise RuntimeError('Missing DESIGN_REVIEW.md')
        run_stage(slug, 'design-revise', 'claude', home,
                  'Read DESIGN_REVIEW.md and revise UX_DESIGN.md to address P0/P1. Preserve platform parity. Do not modify other files.')
        for p, worktree in (('ios',ios),('android',android)):
            # Private design packet under ignored Git info exclude: never publish a private prompt.
            packet = worktree / '.concept-lab-context'
            packet.mkdir(exist_ok=True)
            (packet / 'UX_DESIGN.md').write_text(shared.read_text())
            (packet / 'DESIGN_REVIEW.md').write_text(review.read_text())
            exclude = Path(git(worktree, 'rev-parse', '--git-path', 'info/exclude'))
            if not exclude.is_absolute():
                exclude = worktree / exclude
            exclude.parent.mkdir(parents=True, exist_ok=True)
            old = exclude.read_text() if exclude.exists() else ''
            if '.concept-lab-context/' not in old:
                exclude.write_text(old + '\n.concept-lab-context/\n')
            before = git(worktree, 'status', '--porcelain')
            if before:
                raise RuntimeError(f'{p} worktree not clean prior to implementation')
            run_stage(slug, 'implement-'+p, 'codex', worktree,
                      f'Implement the concept INSIDE THIS EXISTING GENUINE TELEGRAM {p.upper()} SOURCE CLIENT, not a standalone mock. '
                      'Read .concept-lab-context/UX_DESIGN.md and DESIGN_REVIEW.md. '
                      'Keep isolated Test DC forced configuration intact; do not edit account login, network DC selection, auth, signing credentials, dependency manifests, or any secret. '
                      'Use minimal feature-scoped source edits; preserve existing build system. No git commands, no pushing, no real accounts. '
                      'Do not touch files outside this worktree. Document exact affected source paths in .concept-lab-context/IMPLEMENTATION.md.')
            if not inspect_source_changes(p, worktree):
                raise RuntimeError(f'{p} implementation produced no actual native source changes')
            run_stage(slug, 'review-'+p, 'claude', worktree,
                      f'READ-ONLY code and UX review of current native Telegram {p} edits against .concept-lab-context/UX_DESIGN.md. '
                      'Identify P0/P1, functionality, gesture discoverability, fallback, and Test DC safety. Do not edit or run builds.', readonly=True)
            inspect_source_changes(p, worktree)
            (packet / 'REVIEW.md').write_text((home / ('review-'+p+'.md')).read_text())
            run_stage(slug, 'fix-'+p, 'codex', worktree,
                      'Read .concept-lab-context/REVIEW.md and UX_DESIGN.md. Fix valid P0/P1 within this native source tree. '
                      'Do not modify Test DC enforcement/auth/signing. No git commits, no pushing. Add verification instructions in .concept-lab-context/IMPLEMENTATION.md.')
            inspect_source_changes(p, worktree)
        update(slug, phase='ready-for-build-review')
        print('Native source edits prepared. Independent Bazel/Gradle build and manual Test DC E2E STILL REQUIRED.')
        return 0
    except Exception as e:
        update(slug, phase='failed', error=str(e))
        traceback.print_exc()
        return 1


def main():
    if len(sys.argv) < 2:
        raise SystemExit('Usage: native.py doctor|new <slug> <prompt>|run <slug>|status')
    cmd = sys.argv[1]
    if cmd == 'doctor':
        for p in SOURCES:
            print(p, validate_source(p))
    elif cmd == 'status':
        for slug, data in registry().items():
            print(slug, data['phase'], ','.join(data['completed']))
    elif cmd == 'new' and len(sys.argv) == 4:
        slug, prompt = sys.argv[2:]
        prepare(slug, prompt)
        log = (STATE / slug / 'pipeline.log').open('w')
        proc = subprocess.Popen(['/usr/bin/caffeinate','-i',sys.executable,str(Path(__file__).resolve()),'run',slug],
                                stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        update(slug, phase='queued', pid=proc.pid)
        print(f'NATIVE JOB {slug} started pid={proc.pid}; original source branches preserved; NO automatic pushes')
    elif cmd == 'run' and len(sys.argv) == 3:
        sys.exit(execute(sys.argv[2]))
    else:
        raise SystemExit('Usage: native.py doctor|new <slug> <prompt>|run <slug>|status')

if __name__ == '__main__':
    main()
