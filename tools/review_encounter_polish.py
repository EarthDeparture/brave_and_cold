"""Retain local diagnostic receipts; these are not sealed game-dev runs."""
from pathlib import Path
import json, re, hashlib, statistics, shutil

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / 'brave-and-cold/shots/encounter-polish'
OUT = ROOT / 'docs/reviews/encounter-polish-2026-10-07'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    suites = []
    for label, file in [
        ('Skin / collapse / slopes', 'death-tests.log'),
        ('Stock signals / cache hinge', 'stock-tests.log'),
        ('Reserve identities', 'reserve-tests.log'),
        ('Clinic / cohort / reload / ramps', 'collapse-final-tests.log'),
        ('Route resources / reload', 'core-tests.log'),
        ('Pacing / overnight / carried relay', 'pacing-final-tests.log'),
        ('First-week story / finite stock', 'story-tests.log'),
        ('Habitats / field plan / persistence', 'quality-tests.log'),
    ]:
        path = SHOTS / file
        content = path.read_text(encoding='utf-8-sig')
        found = re.search(r'(\w+_TEST)\s+checks=(\d+)\s+failures=(\d+)', content)
        assert found, f'Missing completion: {file}'
        assert int(found[3]) == 0 and 'SCRIPT ERROR' not in content, f'Failed suite: {file}'
        assert not re.search(r'^FAIL\b', content, re.M), f'Failed assertion: {file}'
        suites.append(dict(suite=label, summary=found[0], checks=int(found[2]),
                           failures=0, log=f'brave-and-cold/shots/encounter-polish/{file}',
                           log_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    tests = dict(checks=sum(s['checks'] for s in suites), failures=0, suites=suites,
                 scope='Local Godot checks; no human play session is claimed.')
    (OUT / 'tests.json').write_text(json.dumps(tests, indent=2) + '\n')

    baseline = json.loads((SHOTS / 'fixed-baseline/manifest.json').read_text())
    candidate = json.loads((SHOTS / 'final/manifest.json').read_text())
    assert baseline['opening_seed'] == candidate['opening_seed'] == 20261004
    assert baseline['resolution'] == candidate['resolution'] == [1920, 1080]
    assert baseline['population_target'] == candidate['population_target'] == 250
    assert baseline['gpu'] == candidate['gpu']
    assert len(baseline['samples']) == len(candidate['samples']) == 12
    rows = []
    for case in dict.fromkeys(r['case'] for r in baseline['samples']):
        row = {'case': case}
        for name, run in [('baseline', baseline), ('candidate', candidate)]:
            samples = [r for r in run['samples'] if r['case'] == case]
            assert len(samples) == 3
            row[name] = dict(
                median_of_run_medians_ms=statistics.median(r['median_ms'] for r in samples),
                p95_range_ms=[min(r['p95_ms'] for r in samples), max(r['p95_ms'] for r in samples)],
                warm_hitches_over_33ms=sum(r['hitches_over_33ms'] for r in samples),
                entry_max_ms=[r['entry_max_ms'] for r in samples],
                entry_population_max_us=[r['entry_population_tick_max_us'] for r in samples],
                active_peaks=[r['active_infected_max'] for r in samples],
                pool_min=[r['pool_min'] for r in samples],
            )
        # Seeded moving AI still depends on elapsed frames; retain differences.
        row['active_peaks_equal'] = row['baseline']['active_peaks'] == row['candidate']['active_peaks']
        rows.append(row)
    comparison = dict(
        baseline_runtime='579f58c', candidate_runtime='0f13238', seed=20261004,
        renderer='Forward+ D3D12', resolution=[1920, 1080], gpu=candidate['gpu'],
        rows=rows, limitations=candidate['limitations'],
        notes='Baseline runtime precedes the implementation; both use the corrected seed check and entry timers. The baseline manifest inherited wording from a former visual-profile comparison. This comparison records the actual runtime revisions. Host power/load are uncontrolled; timings do not prove statistical causality. Actual active peaks are retained: the final first clinic pass has 56 instead of 55; both later passes reach 59. These are comparable local scenarios, not identical fixed-step AI workloads. Final harness changes only receipt labels. The final diagnostic does not exercise deaths; real-ground death update cost is recorded in the collapse test log.',
    )
    (OUT / 'performance-comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
    for src, dst in [
        ('fixed-baseline/manifest.json', 'performance-baseline.json'),
        ('final/manifest.json', 'performance-candidate.json'),
        ('presentation-baseline.json', 'presentation-baseline.json'),
        ('presentation-candidate.json', 'presentation-candidate.json'),
        ('collapse/rigid-before.png', 'rigid-before.png'),
        ('collapse/settled.png', 'settled-after.png'),
        ('world/clinic-settled.png', 'clinic-settled.png'),
        ('world/clinic-stock-full.png', 'clinic-stock-full.png'),
        ('world/clinic-stock-withdrawn.png', 'clinic-stock-withdrawn.png'),
    ]:
        shutil.copy2(SHOTS / src, OUT / dst)
    print(json.dumps(dict(tests=tests['checks'], failures=0, performance=rows), indent=2))


if __name__ == '__main__':
    main()
