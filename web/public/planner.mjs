export function conflicts(sections) {
  const result = [];
  for (let i = 0; i < sections.length; i++) for (let j = i + 1; j < sections.length; j++) {
    const a = sections[i], b = sections[j];
    if (a.year !== b.year || a.semester !== b.semester) continue;
    for (const x of a.meetings || []) for (const y of b.meetings || []) {
      if (x.day === y.day && x.start <= y.end && y.start <= x.end) {
        result.push({ a: a.id, b: b.id, day: x.day, start: Math.max(x.start, y.start), end: Math.min(x.end, y.end) });
      }
    }
  }
  return result;
}
export function totalCredits(sections) {
  return [...new Map(sections.map(s => [s.courseId, Number(s.credits)])).values()].reduce((a, b) => a + b, 0);
}
export function restoreSelection(ids, sections) {
  if (!Array.isArray(ids)) return [];
  const byId = new Map(sections.map(s => [s.id, s]));
  const courses = new Set();
  return [...new Set(ids)].filter(id => {
    const s = byId.get(id);
    if (!s || courses.has(s.courseId)) return false;
    courses.add(s.courseId); return true;
  });
}
// Assign columns within each overlapping group so every selected class remains visible.
export function layoutMeetings(events) {
  const sorted = [...events].sort((a, b) => a.start - b.start || a.end - b.end || a.id - b.id);
  const groups = []; let group = [], end = -1;
  for (const event of sorted) {
    if (group.length && event.start > end) { groups.push(group); group = []; end = -1; }
    group.push({ ...event }); end = Math.max(end, event.end);
  }
  if (group.length) groups.push(group);
  return groups.flatMap(items => {
    const ends = [];
    for (const item of items) {
      let lane = ends.findIndex(value => value < item.start);
      if (lane < 0) lane = ends.length;
      ends[lane] = item.end; item.lane = lane;
    }
    return items.map(item => ({ ...item, lanes: ends.length }));
  });
}
