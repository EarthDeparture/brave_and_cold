"""Read-only validation of the actual exported GLB, independent of Blender's receipt.
python tools/blender/validate_survivor_hands.py MODEL.glb RECEIPT.json
"""
import hashlib
import json
import math
import struct
import sys
from collections import Counter
from pathlib import Path


def inspect(model, receipt):
    raw = Path(model).read_bytes()
    meta = json.loads(Path(receipt).read_text(encoding='utf-8'))
    magic, version, length = struct.unpack_from('<III', raw, 0)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    jlen, jkind = struct.unpack_from('<II', raw, 12)
    assert jkind == 0x4E4F534A
    gltf = json.loads(raw[20:20+jlen])
    blen, bkind = struct.unpack_from('<II', raw, 20+jlen)
    assert bkind == 0x004E4942
    buf = raw[28+jlen:28+jlen+blen]
    assert hashlib.sha256(raw).hexdigest() == meta['sha256'], 'Stale provenance receipt'
    gloves = meta['name'] == 'survivor_gloves'
    assert len(gltf['meshes']) == (6 if gloves else 8)
    assert len(gltf['materials']) == (1 if gloves else 2)
    assert len(gltf['images']) == 2 and len(gltf['textures']) == 2
    assert all('bufferView' in im and 'uri' not in im for im in gltf['images']), 'Textures must be embedded'
    assert not gltf.get('skins') and not gltf.get('animations'), 'Rigid grip variants should not add a skeleton'
    sizes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    formats = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}

    def values(aid):
        a = gltf['accessors'][aid]
        view = gltf['bufferViews'][a['bufferView']]
        fmt = '<' + formats[a['componentType']] * sizes[a['type']]
        stride = view.get('byteStride', struct.calcsize(fmt))
        offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from(fmt, buf, offset+i*stride) for i in range(a['count'])]

    report = {}
    total = 0
    for mesh in gltf['meshes']:
        name = mesh['name']
        assert len(mesh['primitives']) == 1
        prim = mesh['primitives'][0]
        assert prim.get('mode', 4) == 4
        attr = prim['attributes']
        assert all(k in attr for k in ['POSITION', 'NORMAL', 'COLOR_0'])
        if 'sleeve' not in name:
            assert 'TEXCOORD_0' in attr
            uv = values(attr['TEXCOORD_0'])
            assert all(math.isfinite(v) and 0 <= v <= 1 for row in uv for v in row)
        p, n, col = (values(attr[k]) for k in ['POSITION', 'NORMAL', 'COLOR_0'])
        assert len(p) == len(n) == len(col)
        assert all(math.isfinite(v) for row in p+n for v in row)
        assert all(0.95 < sum(v*v for v in row) < 1.05 for row in n)
        idx = [v[0] for v in values(prim['indices'])]
        assert len(idx) % 3 == 0 and max(idx) < len(p)
        triangles = len(idx)//3
        total += triangles
        assert triangles == meta['validation'][name]['triangles'], name
        # glTF duplicates vertices along color/normal seams. Weld exact positions
        # for topological checks, retaining the original indices for raster checks.
        weld, unique, welded = {}, [], []
        for pt in p:
            if pt not in weld:
                weld[pt] = len(unique); unique.append(pt)
            welded.append(weld[pt])
        edges, adjacency = Counter(), [set() for _ in unique]
        signed_volume = 0.0
        for j in range(0, len(idx), 3):
            a, b, c = [p[idx[j+k]] for k in range(3)]
            u, v = [b[k]-a[k] for k in range(3)], [c[k]-a[k] for k in range(3)]
            cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
            assert sum(x*x for x in cross) > 1e-18, (name, 'Degenerate triangle')
            bc = [b[1]*c[2]-b[2]*c[1], b[2]*c[0]-b[0]*c[2], b[0]*c[1]-b[1]*c[0]]
            signed_volume += sum(a[k]*bc[k] for k in range(3))/6
            ids = [welded[idx[j+k]] for k in range(3)]
            for ia, ib in zip(ids, ids[1:]+ids[:1]):
                edges[tuple(sorted([ia, ib]))] += 1
                adjacency[ia].add(ib); adjacency[ib].add(ia)
        remaining, components = set(range(len(unique))), 0
        while remaining:
            components += 1; stack = [remaining.pop()]
            while stack:
                for q in adjacency[stack.pop()]:
                    if q in remaining:
                        remaining.remove(q); stack.append(q)
        assert all(n == 2 for n in edges.values()), (name, 'Open or nonmanifold skin')
        assert signed_volume > 0, (name, 'Inverted winding')
        assert components == (2 if 'sleeve' in name else 1), (name, components)
        bounds = [[min(row[k] for row in p), max(row[k] for row in p)] for k in range(3)]
        expected = meta['validation'][name]['bounds_godot']
        assert max(abs(bounds[k][j]-expected[k][j]) for k in range(3) for j in range(2)) < 1e-6
        report[name] = {'triangles': triangles, 'components': components, 'surfaces': 1, 'bounds_godot': bounds}
    assert total == meta['total_triangles'] and total <= 100000
    return {'ok': True, 'triangles': total, 'bytes': len(raw), 'materials': len(gltf['materials']),
            'sha256': meta['sha256'], 'meshes': report}


if __name__ == '__main__':
    print(json.dumps(inspect(sys.argv[1], sys.argv[2]), indent=2))
