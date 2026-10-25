"""Read-only standing-body clearance audit of the exported lookout triangles.

python validate_lookout_clearance.py MODEL.glb GEOMETRY.json
python validate_lookout_clearance.py OLD.glb OLD.json --expect-first-landing-obstruction

The route exercises every tread with lateral offsets, dense switchback turns,
the upper connector and the landing immediately beneath the deck. It does not
substitute for the Godot movement test. Low triangles are excluded only below
the foot plus one riser plus 3cm. The next riser's lip can reach the rounded
capsule foot while departing a landing; those narrowly identified stair-board
contacts are reported separately from above-ground obstacles.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

import numpy as np

RADIUS = 0.35
HEIGHT = 1.85
SPACING = 0.05
EPSILON = 1e-5


def exported_triangles(model: Path):
    raw = model.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    jlen, jkind = struct.unpack_from('<II', raw, 12)
    assert jkind == 0x4E4F534A
    gltf = json.loads(raw[20:20 + jlen])
    boff = 20 + jlen
    blen, bkind = struct.unpack_from('<II', raw, boff)
    assert bkind == 0x004E4942
    binary = raw[boff + 8:boff + 8 + blen]
    # This procedural export stores metres and Godot axes directly in vertices.
    # Refuse transformed nodes rather than silently auditing the wrong geometry.
    assert all(not any(k in n for k in ('matrix', 'translation', 'rotation', 'scale'))
               for n in gltf['nodes']), 'Bake node transforms before this audit'
    components = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
    sizes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

    def accessor(index):
        a = gltf['accessors'][index]
        assert 'sparse' not in a, 'Sparse accessors are not used by this export'
        v = gltf['bufferViews'][a['bufferView']]
        fmt = '<' + components[a['componentType']] * sizes[a['type']]
        stride = v.get('byteStride', struct.calcsize(fmt))
        offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.asarray([struct.unpack_from(fmt, binary, offset + i * stride)
                           for i in range(a['count'])])

    triangles, owners = [], []
    names = {n['mesh']: n.get('name', str(n['mesh']))
             for n in gltf['nodes'] if 'mesh' in n}
    for mid, mesh in enumerate(gltf['meshes']):
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4
            vertices = accessor(primitive['attributes']['POSITION']).astype(float)
            indices = accessor(primitive['indices']).reshape(-1).astype(int)
            faces = vertices[indices.reshape(-1, 3)]
            triangles.extend(faces)
            owners.extend([names[mid]] * len(faces))
    return np.asarray(triangles), owners, hashlib.sha256(raw).hexdigest()


def point_triangle_distance_squared(point, triangle):
    """Closest-point regions, from Real-Time Collision Detection (Ericson)."""
    a, b, c = triangle
    ab, ac, ap = b - a, c - a, point - a
    d1, d2 = float(ab @ ap), float(ac @ ap)
    if d1 <= 0 and d2 <= 0:
        return float(ap @ ap)
    bp = point - b
    d3, d4 = float(ab @ bp), float(ac @ bp)
    if d3 >= 0 and d4 <= d3:
        return float(bp @ bp)
    vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0:
        delta = point - (a + ab * (d1 / (d1 - d3)))
        return float(delta @ delta)
    cp = point - c
    d5, d6 = float(ab @ cp), float(ac @ cp)
    if d6 >= 0 and d5 <= d6:
        return float(cp @ cp)
    vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0:
        delta = point - (a + ac * (d2 / (d2 - d6)))
        return float(delta @ delta)
    va = d3 * d6 - d5 * d4
    if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0:
        bc = c - b
        delta = point - (b + bc * ((d4 - d3) / (d4 - d3 + d5 - d6)))
        return float(delta @ delta)
    denominator = 1.0 / (va + vb + vc)
    delta = point - (a + ab * (vb * denominator) + ac * (vc * denominator))
    return max(0.0, float(delta @ delta))


def segment_segment_distance_squared(p1, q1, p2, q2):
    d1, d2, r = q1 - p1, q2 - p2, p1 - p2
    a, e, f = float(d1 @ d1), float(d2 @ d2), float(d2 @ r)
    if a <= 1e-20 and e <= 1e-20:
        return float(r @ r)
    if a <= 1e-20:
        s, t = 0.0, min(1.0, max(0.0, f / e))
    else:
        c = float(d1 @ r)
        if e <= 1e-20:
            t, s = 0.0, min(1.0, max(0.0, -c / a))
        else:
            b = float(d1 @ d2)
            denominator = a * e - b * b
            s = min(1.0, max(0.0, (b * f - c * e) / denominator)) if denominator > 1e-20 else 0.0
            t = (b * s + f) / e
            if t < 0:
                t, s = 0.0, min(1.0, max(0.0, -c / a))
            elif t > 1:
                t, s = 1.0, min(1.0, max(0.0, (b - c) / a))
    delta = p1 + d1 * s - p2 - d2 * t
    return max(0.0, float(delta @ delta))


def segment_triangle_distance_squared(start, end, triangle):
    a, b, c = triangle
    direction, edge1, edge2 = end - start, b - a, c - a
    h = np.cross(direction, edge2)
    det = float(edge1 @ h)
    if abs(det) > 1e-12:
        s = start - a
        u = float(s @ h) / det
        q = np.cross(s, edge1)
        v = float(direction @ q) / det
        t = float(edge2 @ q) / det
        if -EPSILON <= u and -EPSILON <= v and u + v <= 1 + EPSILON and 0 <= t <= 1:
            return 0.0
    distances = [point_triangle_distance_squared(start, triangle),
                 point_triangle_distance_squared(end, triangle)]
    distances.extend(segment_segment_distance_squared(start, end, triangle[i], triangle[(i + 1) % 3])
                     for i in range(3))
    return min(distances)


def sample_route(meta):
    stairs = meta['stairs']
    count, steps = int(stairs['flights']), int(stairs['steps_per_flight'])
    riser, run = float(stairs['riser']), float(stairs['run'])
    flight_height = steps * riser
    samples = []

    def add(label, x, y, z):
        samples.append((label, np.array([x, y, z], dtype=float)))

    def line(label, begin, end):
        begin, end = np.asarray(begin, dtype=float), np.asarray(end, dtype=float)
        n = max(1, math.ceil(float(np.linalg.norm(end - begin)) / SPACING))
        for j in range(n + 1):
            p = begin + (end - begin) * j / n
            add(label, *p)

    for flight in range(count):
        lane = float(stairs['lane_x'][flight])
        start_z, end_z = float(stairs['z_start'][flight]), float(stairs['z_end'][flight])
        direction = 1 if end_z > start_z else -1
        for step in range(steps):
            height = flight * flight_height + (step + 1) * riser
            z = start_z + direction * (step + 0.5) * run
            for offset in [-0.12, 0.0, 0.12]:
                add(f'flight_{flight + 1}_tread_{step + 1}', lane + offset, height, z)
        height = (flight + 1) * flight_height
        landing_z = float(stairs['landing_z'][flight])
        line(f'landing_{flight + 1}_arrival', [lane, height, end_z], [lane, height, landing_z])
        if flight + 1 < count:
            next_lane = float(stairs['lane_x'][flight + 1])
            line(f'landing_{flight + 1}_turn', [lane, height, landing_z], [next_lane, height, landing_z])
            line(f'landing_{flight + 1}_departure', [next_lane, height, landing_z], [next_lane, height, end_z])
        else:
            line('upper_connector', [lane, height, landing_z], [3.2, height, landing_z])
            line('upper_balcony_corner', [3.2, height, landing_z], [3.2, height, 2.75])
    # At a flight's entrance the controller selects its first tread, including
    # the exact boundary. Keeping that pose at landing height invents contact.
    for label, foot in samples:
        if label.endswith('_departure'):
            flight = int(label.split('_')[1])
            start = float(stairs['z_start'][flight])
            end = float(stairs['z_end'][flight])
            progress = (foot[2] - start) * (1 if end > start else -1)
            if progress >= -EPSILON:
                step = min(steps, max(1, math.ceil(max(0.0, progress) / run)))
                foot[1] = flight * flight_height + step * riser
    # Exercise the platform's left usable edge below the top deck, not merely
    # the normal flight-centre route that can miss under-deck joists.
    below = count - 2
    if below >= 0:
        h = (below + 1) * flight_height
        z = float(stairs['landing_z'][below])
        line('below_deck_landing_left_edge', [4.05, h, z - 0.05], [4.05, h, z + 0.05])
    return samples


def outgoing_step_contact(label, owner, triangle, foot, meta):
    """Identify only the low second-riser lip beside an outgoing landing.

    The fixed capsule rounds its foot 35cm forward across a 30cm tread. This
    touches the next low riser before the controller raises its foot. Do not
    exempt braces, guardrails, overhead steps or unrelated wood surfaces.
    """
    if owner != 'lookout_boards' or not label.endswith('_departure'):
        return False
    flight = int(label.split('_')[1])  # Landing one departs onto flight index one.
    stairs = meta['stairs']
    if flight >= int(stairs['flights']):
        return False
    riser, run = float(stairs['riser']), float(stairs['run'])
    lane, start = float(stairs['lane_x'][flight]), float(stairs['z_start'][flight])
    end = float(stairs['z_end'][flight])
    direction = 1 if end > start else -1
    progress = (triangle[:, 2] - start) * direction
    width = float(stairs['width'])
    return (triangle[:, 1].max() <= foot[1] + 2 * riser + .03 + EPSILON
            and np.max(np.abs(triangle[:, 0] - lane)) <= width * .5 + .015
            and progress.min() >= -.02 - EPSILON
            and progress.max() <= int(stairs['steps_per_flight']) * run + .02 + EPSILON)


def audit(model, receipt):
    meta = json.loads(receipt.read_text(encoding='utf-8'))
    triangles, owners, digest = exported_triangles(model)
    assert digest == meta['sha256'], 'Model and geometry receipt differ'
    low, high = triangles.min(axis=1), triangles.max(axis=1)
    minimum_margin = math.inf
    minimum_raw_margin = math.inf
    route_margins = {}
    closest = None
    hits, samples_with_hits = Counter(), 0
    step_hits, step_samples = Counter(), 0
    examples = []
    first_landing_timber = None
    exact_checks = 0
    samples = sample_route(meta)
    step_allowance = float(meta['stairs']['riser']) + 0.03
    for label, foot in samples:
        if label.startswith('flight_'):
            route_part = 'stair_treads'
        elif label.startswith('landing_'):
            route_part = 'landing_' + label.rsplit('_', 1)[1]
        else:
            route_part = label
        start = foot + np.array([0, RADIUS, 0])
        end = foot + np.array([0, HEIGHT - RADIUS, 0])
        # Ten extra centimetres provide a useful near-clearance measurement.
        bounds_low = foot - np.array([RADIUS + .10, .10, RADIUS + .10])
        bounds_high = foot + np.array([RADIUS + .10, HEIGHT + .10, RADIUS + .10])
        candidate = np.flatnonzero((high[:, 1] > foot[1] + step_allowance + EPSILON)
                                  & np.all(high >= bounds_low, axis=1)
                                  & np.all(low <= bounds_high, axis=1))
        sample_hit = False
        sample_step_contact = False
        worst = None
        for tid in candidate:
            distance = math.sqrt(segment_triangle_distance_squared(start, end, triangles[tid]))
            margin = distance - RADIUS
            exact_checks += 1
            minimum_raw_margin = min(minimum_raw_margin, margin)
            detail = {'sample': label, 'foot_godot': foot.tolist(), 'mesh': owners[tid],
                      'triangle': int(tid), 'clearance_margin_m': round(margin, 6),
                      'triangle_godot': triangles[tid].tolist()}
            intended_step = margin < -EPSILON and outgoing_step_contact(label, owners[tid], triangles[tid], foot, meta)
            if intended_step:
                sample_step_contact = True
                step_hits[owners[tid]] += 1
                continue
            route_margins[route_part] = min(route_margins.get(route_part, math.inf), margin)
            if margin < minimum_margin:
                minimum_margin, closest = margin, detail
            if margin < -EPSILON:
                sample_hit = True
                hits[owners[tid]] += 1
                if worst is None or margin < worst['clearance_margin_m']:
                    worst = detail
                if label == 'landing_1_turn' and owners[tid] == 'lookout_timber':
                    first_landing_timber = detail
        if sample_hit:
            samples_with_hits += 1
            if len(examples) < 24:
                examples.append(worst)
        if sample_step_contact:
            step_samples += 1
    bounds = [triangles.min(axis=(0, 1)).tolist(), triangles.max(axis=(0, 1)).tolist()]
    return {'ok': samples_with_hits == 0, 'model_sha256': digest,
            'bounds_godot': bounds, 'roof_height_above_origin_m': bounds[1][1],
            'body': {'height_m': HEIGHT, 'radius_m': RADIUS, 'tread_offsets_m': [-.12, 0, .12],
                     'turn_spacing_m': SPACING, 'ignored_step_contact_height_m': step_allowance},
            'triangles': len(triangles), 'route_samples': len(samples), 'exact_triangle_checks': exact_checks,
            'obstructed_samples': samples_with_hits, 'triangle_contacts_by_mesh': dict(hits),
            'intended_outgoing_riser_contact_samples': step_samples,
            'intended_outgoing_riser_triangle_contacts': dict(step_hits),
            'minimum_clearance_margin_m': None if not math.isfinite(minimum_margin) else round(max(0.0, minimum_margin) if abs(minimum_margin) < EPSILON else minimum_margin, 6),
            'minimum_margin_by_route_part_m': {key: round(max(0.0, value) if abs(value) < EPSILON else value, 6)
                                             for key, value in route_margins.items()},
            'minimum_raw_margin_before_step_contact_classification_m': None if not math.isfinite(minimum_raw_margin) else round(minimum_raw_margin, 6),
            'closest_geometry': closest, 'obstruction_examples': examples,
            'first_landing_support_regression': first_landing_timber,
            'limits': 'Sampled route and lateral tread offsets, not every possible position; low contacts excluded, narrowly identified outgoing second-riser contacts reported separately.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', type=Path)
    parser.add_argument('receipt', type=Path)
    parser.add_argument('--expect-first-landing-obstruction', action='store_true',
                        help='Regression succeeds only if timber obstructs the old first landing turn')
    args = parser.parse_args()
    result = audit(args.model, args.receipt)
    if args.expect_first_landing_obstruction:
        result['expected_old_asset_failure_confirmed'] = result['first_landing_support_regression'] is not None
        success = result['expected_old_asset_failure_confirmed']
    else:
        success = result['ok']
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if success else 1)


if __name__ == '__main__':
    main()
