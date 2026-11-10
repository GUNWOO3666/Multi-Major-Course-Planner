import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { conflicts, totalCredits, restoreSelection, layoutMeetings } from '../public/planner.mjs';
const data = JSON.parse(await readFile(new URL('../public/data.json',import.meta.url),'utf8'));
test('snapshot has all 67 sections and 79 normal meetings', () => {
  assert.equal(data.length,67);
  assert.equal(data.filter(x=>x.departmentId===1).length,40);
  assert.equal(data.filter(x=>x.departmentId===2).length,27);
  assert.equal(data.reduce((n,s)=>n+s.meetings.length,0),79);
  assert.equal(new Set(data.map(s=>s.courseId)).size,46);
  assert.equal(data.filter(s=>s.status==='NEEDS_REVIEW').length,4);
  for(const s of data) for(const m of s.meetings) assert.ok(m.start>=1 && m.start<=m.end && m.end<=15 && m.day>=1 && m.day<=7);
});
test('real programming and signals example overlaps Tuesday periods 1–2',()=>{
  assert.deepEqual(conflicts(data.filter(s=>[1,48].includes(s.id))),[{a:1,b:48,day:2,start:1,end:2}]);
});
test('inclusive endpoints overlap, adjacent periods do not, other terms do not',()=>{
  const a={id:1,year:2026,semester:2,meetings:[{day:2,start:1,end:2}]};
  const b={id:2,year:2026,semester:2,meetings:[{day:2,start:2,end:3}]};
  assert.equal(conflicts([a,b]).length,1);
  assert.equal(conflicts([a,{...b,meetings:[{day:2,start:3,end:4}]}]).length,0);
  assert.equal(conflicts([a,{...b,semester:1}]).length,0);
  assert.equal(conflicts([a,{...b,meetings:[{day:3,start:1,end:2}]}]).length,0);
});
test('credits do not double count the same course; invalid stored IDs are discarded',()=>{
  assert.equal(totalCredits(data.filter(s=>[1,2,48].includes(s.id))),6);
  assert.deepEqual(restoreSelection([1,2,1,999,48],data),[1,48]);
  assert.deepEqual(restoreSelection('bad',data),[]);
});
test('overlapping meetings use separate lanes, isolated group uses full width',()=>{
  const events=[{id:1,start:1,end:3},{id:2,start:2,end:4},{id:3,start:3,end:3},{id:4,start:6,end:7}];
  const result=layoutMeetings(events);
  assert.equal(result.find(x=>x.id===4).lanes,1);
  assert.equal(result[0].lanes,3);
  assert.equal(new Set(result.filter(x=>x.start<=3&&x.end>=3).map(x=>x.lane)).size,3);
});
