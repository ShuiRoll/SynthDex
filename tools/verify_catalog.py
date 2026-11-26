"""Read-only comparison of the public Supabase catalog to pinned master data."""
import json
import os
import re
import urllib.parse
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / 'lib/main.dart').read_text(encoding='utf-8')
key = re.search(r'sb_publishable_[A-Za-z0-9_]+', main).group()
rows = []
for offset in range(0, 10000, 100):
    query = urllib.parse.urlencode({'select': 'id,game_id,title,available,artists(name),song_units(units(name)),charts(difficulty,level)', 'order':'id', 'offset':offset, 'limit':100})
    base = os.environ.get('SUPABASE_URL','https://sgwucpmxkxlgirgoukri.supabase.co').rstrip('/')
    req = urllib.request.Request(base+'/rest/v1/songs?'+query, headers={'apikey':key})
    with urllib.request.urlopen(req, timeout=30) as response:
        batch = json.load(response)
    rows.extend(batch)
    if len(batch)<100:
        break
source = root / 'tools/catalog-source'
musics = json.loads((source / 'musics.json').read_text(encoding='utf-8'))
charts = json.loads((source / 'musicDifficulties.json').read_text(encoding='utf-8'))
report = json.loads((root / 'docs/catalog-provenance.json').read_text(encoding='utf-8'))
by_id = {r['game_id']:r for r in rows}
assert len(rows)==len(musics)==report['source_songs']
assert sum(r['available'] for r in rows)==report['playable_songs']
assert sum(len(r['charts']) for r in rows if r['available'])==report['playable_charts']
difficulties = ['easy','normal','hard','expert','master','append']
for music in musics:
    row = by_id[music['id']]
    assert row['title']==music['title'], music['id']
    expected = {difficulties.index(c['musicDifficulty']):c['playLevel'] for c in charts if c['musicId']==music['id']}
    actual = {c['difficulty']:c['level'] for c in row['charts']}
    assert actual==expected, music['id']
    assert row['song_units'], music['id']
print(f"Verified public API: {len(rows)} source entries, {report['playable_songs']} playable songs, {report['playable_charts']} charts; every title and level matches.")
