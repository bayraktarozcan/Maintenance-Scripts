#!/usr/bin/env python3
"""Verify a human-language mirror against its canonical document.

The verifier takes both paths as parameters and names neither. It checks:
  - sync-sha: SHA1 of the canonical file after BOM removal, EOL normalization
    and removal of the whole mirror-sync marker line including its terminator;
    both files must carry that value in their marker.
  - structure: same number of sections, same heading depth sequence, same
    number of top-level rules under every section, same number of code fences,
    same number of table blocks, and the same ordered action-checklist anchors.
    Heading detection skips fenced code. Nested sub-items are reported but not
    compared. Tables are compared as blocks, not row by row.

Exit 0 when everything matches, 1 otherwise. Use --allow-missing for CI, where
the mirror is intentionally absent. Use --selftest to run the built-in fixture
suite, which pins every one of these behaviors in memory.

Structure cannot prove meaning: a passing run proves equal shape and equal
declared value, not equal wording.
"""

import argparse
import hashlib
import re
import sys

MARKER_RE = re.compile(r'^<!-- mirror-sync: sync-sha=([0-9a-f]+) -->$', re.M)
MARKER_LINE_RE = re.compile(r'^<!-- mirror-sync: sync-sha=[0-9a-f]+ -->\n?', re.M)
CHECKLIST_RE = re.compile(r'^\s*- \[ \] (.+)$')
TOKEN_RE = re.compile(r'`([^`]+)`')
HEADING_RE = re.compile(r'^(#{1,6})\s')
FENCE_RE = re.compile(r'^\s*(```+|~~~+)')
TOP_RULE_RE = re.compile(r'^- (?!\[ \])')
NESTED_RE = re.compile(r'^\s+- ')


class Document:
    """A document plus its derived structure, built from bytes or text."""

    def __init__(self, raw):
        data = raw
        if data.startswith(b'\xef\xbb\xbf'):
            data = data[3:]
        self.text = data.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
        self.marker = None
        found = MARKER_RE.search(self.text)
        if found:
            self.marker = found.group(1)
        self.lines = self.text.split('\n')
        self._analyze()

    @classmethod
    def from_bytes(cls, raw):
        return cls(raw)

    @classmethod
    def from_text(cls, text, crlf=False, bom=False):
        if crlf:
            text = text.replace('\n', '\r\n')
        raw = text.encode('utf-8')
        if bom:
            raw = b'\xef\xbb\xbf' + raw
        return cls(raw)

    def _analyze(self):
        self.depths = []
        self.rules_per_section = []
        self.fences = 0
        self.tables = 0
        self.nested = 0
        self.checklist = []
        infence = False
        prev_table = False
        rules = 0

        for line in self.lines:
            if FENCE_RE.match(line):
                self.fences += 1
                infence = not infence
                prev_table = False
                continue
            if infence:
                continue

            heading = HEADING_RE.match(line)
            if heading:
                self.depths.append(len(heading.group(1)))
                self.rules_per_section.append(rules)
                rules = 0
                prev_table = False
                continue

            if line.strip().startswith('|') and line.count('|') >= 2:
                if not prev_table:
                    self.tables += 1
                prev_table = True
            else:
                prev_table = False

            if TOP_RULE_RE.match(line):
                rules += 1
            if NESTED_RE.match(line):
                self.nested += 1

            item = CHECKLIST_RE.match(line)
            if item:
                tokens = TOKEN_RE.findall(item.group(1))
                self.checklist.append(tokens[0] if tokens else item.group(1)[:24])
        self.rules_per_section.append(rules)

    def sync_sha(self):
        stripped = MARKER_LINE_RE.sub('', self.text, count=1)
        return hashlib.sha1(stripped.encode('utf-8')).hexdigest()


def findings(canonical, mirror):
    """Return a list of drift descriptions; empty means the pair matches."""
    out = []
    expected = canonical.sync_sha()

    if canonical.marker is None:
        out.append('canonical: missing sync-sha marker')
    elif canonical.marker != expected:
        out.append('canonical: sync-sha marker is %s, computed %s' % (canonical.marker, expected))

    if mirror.marker is None:
        out.append('mirror: missing sync-sha marker')
    elif mirror.marker != expected:
        out.append('mirror: sync-sha marker is %s, computed %s' % (mirror.marker, expected))

    if len(canonical.depths) != len(mirror.depths):
        out.append('sections: %d vs %d' % (len(canonical.depths), len(mirror.depths)))
    if canonical.depths != mirror.depths:
        out.append('heading depth sequence differs')
    if len(canonical.rules_per_section) != len(mirror.rules_per_section):
        out.append('section rule-count lists differ in length')
    elif canonical.rules_per_section != mirror.rules_per_section:
        out.append('top-level rule count differs under a section')
    if canonical.fences != mirror.fences:
        out.append('code fences: %d vs %d' % (canonical.fences, mirror.fences))
    if canonical.tables != mirror.tables:
        out.append('table blocks: %d vs %d' % (canonical.tables, mirror.tables))
    if canonical.checklist != mirror.checklist:
        out.append('action checklist anchors differ in order or presence')

    return out


def notes(canonical, mirror):
    """Reported but not compared: a translation may expand one rule into sub-bullets."""
    if canonical.nested != mirror.nested:
        return ['note: nested sub-item counts differ (%d vs %d; reported, not compared)'
                % (canonical.nested, mirror.nested)]
    return []


def run_selftest():
    """Fixture suite: clean, CRLF, BOM, each drift class, tolerances, absent."""
    base = '''# Title

## Section A

- **Rule one.** alpha
  - nested detail
- **Rule two.** beta

- [ ] `git status` reviewed
- [ ] `build` passes

| a | b |
|---|---|

```text
# not a heading
```
'''
    # Same shape, different wording, same anchors/structure.
    mirror_text = base.replace('# Title', '# Baslik') \
                      .replace('## Section A', '## Bolum A') \
                      .replace('alpha', 'alfa').replace('beta', 'beta') \
                      .replace('reviewed', 'gozden gecirildi') \
                      .replace('passes', 'gecer') \
                      .replace('nested detail', 'detay')

    def pair(mirror=mirror_text, canonical=base, canonical_crlf=False,
             mirror_crlf=False, mirror_bom=False):
        sha = Document.from_text(canonical).sync_sha()
        marker = '<!-- mirror-sync: sync-sha=' + sha + ' -->\n'
        c2 = Document.from_text(canonical + marker, crlf=canonical_crlf)
        m2 = Document.from_text(mirror + marker, crlf=mirror_crlf, bom=mirror_bom)
        return c2, m2

    cases = []

    def case(name, should_pass, cpair, allow_missing=False):
        c, m = cpair
        got = findings(c, m)
        ok = (len(got) == 0)
        cases.append((name, ok == should_pass, got))

    c, m = pair()
    case('clean pair', True, (c, m))

    c, m = pair(mirror_crlf=True)
    case('CRLF mirror', True, (c, m))

    c, m = pair(canonical_crlf=True)
    case('CRLF canonical', True, (c, m))

    c, m = pair(mirror_bom=True)
    case('BOM mirror', True, (c, m))

    c, m = pair(mirror=mirror_text.replace('## Bolum A', '# Bolum A'))
    case('heading depth drift', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('## Bolum A\n\n', ''))
    case('section count drift', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('- **Rule two.** beta\n', ''))
    case('top-level rule drift', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('```text', '').replace('# not a heading\n', '')
                                 .replace('```\n', ''))
    case('code fence drift', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('| a | b |\n|---|---|\n\n', ''))
    case('table block drift', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('- [ ] `build` gecer\n', ''))
    case('checklist loses anchor', False, (c, m))

    c, m = pair(mirror=mirror_text.replace(
        '- [ ] `git status` gozden gecirildi\n- [ ] `build` gecer\n',
        '- [ ] `build` gecer\n- [ ] `git status` gozden gecirildi\n'))
    case('checklist reordered', False, (c, m))

    c, m = pair(mirror=mirror_text.replace('`git status`', '`git diff`'))
    case('checklist anchor dropped', False, (c, m))

    tolerant = mirror_text.replace(
        '- **Rule one.** alfa\n',
        '- **Rule one.** alfa\n  - ek aciklama\n')
    c, m = pair(mirror=tolerant)
    case('nested sub-item tolerated', True, (c, m))

    c, m = pair(mirror=mirror_text.replace('`git status` gozden gecirildi',
                                          '`git status` baska bir soz'))
    case('checklist rewording tolerated', True, (c, m))

    c, m = pair(mirror=mirror_text + '\n')
    case('blank line tolerated', True, (c, m))

    # Marker drift: tamper with the mirror marker only.
    c, m = pair()
    m = Document.from_text(m.text.replace(m.marker, '0' * 40))
    case('marker mismatch', False, (c, m))

    # Missing mirror: tested through the file-level path in main, not here.
    failures = [(n, g) for n, ok, g in cases if not ok]
    for name, ok, got in cases:
        print(('  [ok] ' if ok else '  [FAIL] ') + name)
        if not ok:
            for f in got:
                print('        ' + f)
    print('selftest: %d/%d cases passed' % (len(cases) - len(failures), len(cases)))
    return 0 if not failures else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('paths', nargs='*', help='canonical file and mirror file')
    ap.add_argument('--allow-missing', action='store_true',
                    help='pass when the mirror is intentionally absent (CI)')
    ap.add_argument('--selftest', action='store_true',
                    help='run the built-in fixture suite')
    args = ap.parse_args()

    if args.selftest:
        return run_selftest()

    if len(args.paths) != 2:
        ap.error('expected exactly two paths (canonical, mirror)')

    try:
        with open(args.paths[0], 'rb') as fh:
            canonical = Document.from_bytes(fh.read())
    except OSError as exc:
        print('READ ERROR: %s' % exc)
        return 1

    try:
        with open(args.paths[1], 'rb') as fh:
            mirror = Document.from_bytes(fh.read())
    except OSError as exc:
        if args.allow_missing:
            print('note: mirror file is absent; --allow-missing set')
            return 0
        print('MISSING mirror: %s' % exc)
        return 1

    issues = findings(canonical, mirror)
    for note in notes(canonical, mirror):
        print(note)
    for issue in issues:
        print('DRIFT ' + issue)
    if issues:
        print('FAILED: %d finding(s)' % len(issues))
        return 1
    print('OK: structure and sync-sha match (sha=%s)' % canonical.sync_sha())
    print('note: wording still needs a human read')
    return 0


if __name__ == '__main__':
    sys.exit(main())
