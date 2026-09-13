"""Summarize Flutter LCOV line coverage by layer, without extra dependencies."""
import sys
from pathlib import Path

source = Path(sys.argv[1] if len(sys.argv) > 1 else 'coverage/lcov.info')
totals = {}
current = None
for line in source.read_text().splitlines():
    if line.startswith('SF:'):
        path = line[3:].replace('\\', '/')
        current = next((layer for layer in ['data', 'domain', 'core', 'presentation'] if f'/{layer}/' in '/' + path), 'bootstrap')
    elif line.startswith('DA:') and current:
        _, hits, *_ = line[3:].split(',')
        total, covered = totals.get(current, (0, 0))
        totals[current] = total + 1, covered + (int(hits) > 0)
for layer, (total, covered) in sorted(totals.items()):
    print(f'{layer}: {covered}/{total} executable lines ({covered / total:.1%})')
total = sum(v[0] for v in totals.values())
covered = sum(v[1] for v in totals.values())
print(f'Total: {covered}/{total} executable lines ({covered / total:.1%})')
