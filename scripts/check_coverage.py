"""Summarize Flutter LCOV line coverage by layer, without extra dependencies."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', nargs='?', default='coverage/lcov.info')
parser.add_argument('--min-total', type=float, default=0,
                    help='Minimum total line coverage percentage required (0–100).')
args = parser.parse_args()
if not 0 <= args.min_total <= 100:
    parser.error('--min-total doit être compris entre 0 et 100')
source = Path(args.report)
if not source.is_file():
    parser.exit(1, f'Rapport absent : {source}. Lancez flutter test --coverage.\n')
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
if not total:
    parser.exit(1, 'Le rapport ne contient aucune ligne instrumentée.\n')
print(f'Total: {covered}/{total} executable lines ({covered / total:.1%})')
if covered / total * 100 < args.min_total:
    parser.exit(1, f'Couverture insuffisante : minimum {args.min_total:g} % requis.\n')
