#!/usr/bin/env python3
"""
Filtra un volcado JSONL de Photon para conservar solo los registros
dentro del Área Metropolitana de Bucaramanga (AMB).

Bounding box AMB:
  Lat: 6.95 - 7.25  (Sur: Piedecuesta → Norte: Lebrija)
  Lon: -73.35 - -72.90
"""
import sys
import json

LAT_MIN, LAT_MAX = 6.95, 7.25
LNG_MIN, LNG_MAX = -73.35, -72.90

accepted = 0
rejected = 0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        obj_type = obj.get('type', '')

        if obj_type == 'Place':
            places = obj.get('content', [])
            filtered = []
            for p in places:
                centroid = p.get('centroid') or []
                if len(centroid) < 2:
                    continue
                lon, lat = centroid[0], centroid[1]
                if LNG_MIN <= lon <= LNG_MAX and LAT_MIN <= lat <= LAT_MAX:
                    filtered.append(p)
                    accepted += 1
                else:
                    rejected += 1
            if not filtered:
                continue
            obj['content'] = filtered

        sys.stdout.write(json.dumps(obj) + '\n')

    except Exception:
        pass

sys.stderr.write(f'[filter_bbox] Aceptados: {accepted} | Rechazados: {rejected}\n')
