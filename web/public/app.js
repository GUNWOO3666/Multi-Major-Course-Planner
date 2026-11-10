import { conflicts, totalCredits, restoreSelection, layoutMeetings } from './planner.mjs';
const $ = s => document.querySelector(s);
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const DAYS = ['월','화','수','목','금','토','일'];
const STORAGE = 'multi-major-planner:2026:2:v1';
let sections = [], selected = [], department = 'all', source = 'snapshot', toastTimer;
function toast(message) { $('#toast').textContent = message; $('#toast').classList.add('visible'); clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 3000); }
function selectedSections() { return selected.map(id => sections.find(s => s.id === id)).filter(Boolean); }
function persist() { try { localStorage.setItem(STORAGE, JSON.stringify(selected)); } catch { toast('브라우저 저장 공간을 사용할 수 없어 이번 선택은 자동 저장되지 않아요.'); } }
function loadStored() { try { return JSON.parse(localStorage.getItem(STORAGE) || '[]'); } catch { return []; } }
function acceptData(data) {
  if (!Array.isArray(data.sections)) throw new Error('강좌 데이터를 읽을 수 없어요.');
  sections = data.sections.map(s => ({ ...s, id:Number(s.id), credits:Number(s.credits), departmentId:Number(s.departmentId), year:Number(s.year), semester:Number(s.semester), meetings:(s.meetings || []).map(m => ({ ...m, day:Number(m.day), start:Number(m.start), end:Number(m.end) })) }));
  source = data.source;
  selected = restoreSelection(selected.length ? selected : loadStored(), sections);
  persist();
  $('#connection-label').textContent = source === 'mysql' ? 'MySQL 연결됨' : '제공 자료 · DB 연결 전';
  $('#connection-button').classList.toggle('live', source === 'mysql');
  $('.catalog-footer').firstChild.textContent = '';
  $('.catalog-footer').innerHTML = `<span class="status-dot"></span> 두 학과 · ${sections.length}개 분반 <button id="reload-button" title="강좌 새로고침" aria-label="강좌 새로고침">↻</button>`;
  $('#reload-button').addEventListener('click', () => load(true));
  render();
}
async function load(notify = false) {
  try {
    const response = await fetch('/api/sections'); const data = await response.json();
    if (!response.ok) throw new Error(data.error);
    acceptData(data); if (notify) toast('최신 강좌 목록을 불러왔어요.');
  } catch (err) {
    if (!sections.length) $('#course-list').innerHTML = `<div class="load-error">${escape(err.message)}<br>서버 실행 상태를 확인한 뒤 새로고침해 주세요.</div>`;
    else toast(`${err.message} 기존 목록을 유지해요.`);
    $('#connection-label').textContent = '연결 확인 필요';
    $('#connection-button').classList.remove('live');
  }
}
function clashesIfAdded(s) { return conflicts([...selectedSections().filter(x => x.courseId !== s.courseId), s]).some(c => c.a === s.id || c.b === s.id); }
function renderCatalog() {
  const search = $('#search').value.trim().toLowerCase(); const type = $('#type-filter').value;
  const hide = $('#hide-conflicts').checked;
  const visible = sections.filter(s => (department === 'all' || String(s.departmentId) === department)
    && (type === 'all' || s.type === type)
    && (!search || `${s.title} ${s.professor} ${s.courseId} ${s.sectionNo}`.toLowerCase().includes(search))
    && (!hide || selected.includes(s.id) || !clashesIfAdded(s)));
  const groups = new Map();
  for (const s of visible) { const key = `${s.departmentId}:${s.courseId}`; if (!groups.has(key)) groups.set(key, []); groups.get(key).push(s); }
  $('#catalog-count').textContent = sections.length;
  $('#results-count').textContent = `${groups.size}개 과목 · ${visible.length}개 분반`;
  if (!groups.size) { $('#course-list').innerHTML = '<div class="list-empty">조건에 맞는 강좌가 없어요.<small>검색어나 필터를 바꿔보세요.</small><button class="subtle-button" id="clear-filters">필터 초기화</button></div>'; $('#clear-filters').onclick = clearFilters; return; }
  $('#course-list').innerHTML = [...groups.values()].map(group => {
    const s = group[0], isSelected = group.some(x => selected.includes(x.id)); const cls = s.departmentId === 1 ? 'cs' : 'ict';
    return `<article class="course-card ${isSelected ? 'has-selection' : ''}"><div class="course-card-header"><h3>${escape(s.title)}</h3><span class="badge ${cls}">${cls === 'cs' ? '컴퓨터공학' : '스마트ICT'}</span></div><div class="course-meta"><span>${escape(s.courseId)}</span><span class="divider">·</span><span>${s.credits}학점</span><span class="divider">·</span><span class="badge ${s.type === '전필' ? 'required' : ''}">${escape(s.type || '구분 미확인')}</span><span>${group.length}개 분반</span></div>${group.map(item => {
      const active = selected.includes(item.id), clash = !active && clashesIfAdded(item), review = item.status === 'NEEDS_REVIEW';
      return `<div class="section-row ${active ? 'selected' : ''}"><div class="section-info"><div><b>${escape(item.professor)}</b><span>${escape(item.sectionNo)}</span>${review ? '<span class="review-text">시간 확인 필요</span>' : clash ? '<span class="conflict-text">시간 겹침</span>' : ''}</div><div class="section-time">${escape(item.rawSchedule || '시간 미확인')}</div></div><button class="add-button" data-add="${item.id}" aria-label="${escape(item.title)} ${escape(item.sectionNo)} ${active ? '빼기' : '담기'}" aria-pressed="${active}">${active ? '담음 ✓' : '담기 +'}</button></div>`;
    }).join('')}</article>`;
  }).join('');
}
function clearFilters() { $('#search').value = ''; $('#type-filter').value = 'all'; $('#hide-conflicts').checked = false; department = 'all'; document.querySelectorAll('[data-dept]').forEach(b => b.classList.toggle('active', b.dataset.dept === 'all')); renderCatalog(); }
function renderCalendar(current, collisions) {
  const calendar = $('#calendar'); const count = $('#weekend-toggle').checked ? 7 : 5;
  calendar.classList.toggle('weekend', count === 7);
  calendar.innerHTML = '<div class="day-heading">교시</div>' + DAYS.slice(0, count).map(d => `<div class="day-heading">${d}</div>`).join('') + `<div class="period-labels">${Array.from({length:15}, (_,i) => `<div class="period-label">${i+1}</div>`).join('')}</div>`;
  for (let day = 1; day <= count; day++) {
    const column = document.createElement('div'); column.className = 'day-column';
    const events = current.flatMap(s => s.meetings.filter(m => m.day === day).map(m => ({ ...m, id:s.id, section:s })));
    for (const e of layoutMeetings(events)) {
      const s = e.section; const clash = collisions.some(c => (c.a === s.id || c.b === s.id) && c.day === day && c.start <= e.end && e.start <= c.end);
      const button = document.createElement('button'); button.className = `calendar-event ${s.departmentId === 2 ? 'ict' : 'cs'} ${clash ? 'clash' : ''} ${e.start === e.end ? 'short' : ''}`;
      button.style.cssText = `top:calc((${e.start} - 1) * var(--period) + 3px);height:calc((${e.end-e.start+1}) * var(--period) - 6px);left:calc(${e.lane/e.lanes*100}% + 3px);width:calc(${100/e.lanes}% - 6px)`;
      const label = `${s.title} · ${s.professor} · ${DAYS[day-1]} ${e.start}~${e.end}교시 · ${e.room || '강의실 배정 확인 필요'}${clash ? ' · 시간 충돌' : ''}`;
      button.title = label; button.setAttribute('aria-label', label);
      button.innerHTML = `<span class="event-title">${escape(s.title)}</span><span class="event-meta">${escape(s.professor)}<br>${escape(e.room || '강의실 확인 필요')}</span><span class="event-period">${e.start === e.end ? e.start : `${e.start}–${e.end}`}교시${clash ? ' · 겹침' : ''}</span>`;
      button.onclick = () => { document.querySelector(`[data-selected="${s.id}"]`)?.scrollIntoView({ behavior:'smooth',block:'nearest' }); toast(label); };
      column.append(button);
    }
    calendar.append(column);
  }
  $('#calendar-empty').hidden = current.length > 0;
}
function renderSelection(current, collisions) {
  $('#selected-count').textContent = current.length; $('#nav-count').textContent = current.length;
  $('#credit-total').textContent = totalCredits(current);
  const pairs = new Set(collisions.map(c => `${c.a}:${c.b}`)).size;
  $('#conflict-total').textContent = pairs; $('#conflict-total').classList.toggle('has-conflict', pairs > 0);
  $('#schedule-subtitle').textContent = current.length ? `${current.length}개 강좌를 담았어요. 나에게 맞는 조합을 찾아보세요.` : '첫 번째 강좌를 담아볼까요?';
  $('#selection-list').innerHTML = current.length ? current.map(s => `<div class="selected-item ${s.departmentId === 2 ? 'ict' : ''}" data-selected="${s.id}"><div class="selected-marker"></div><div><div class="selected-name">${escape(s.title)}</div><div class="selected-detail">${escape(s.sectionNo)} · ${escape(s.professor)} · ${escape(s.rawSchedule)}</div></div><div class="selected-badges">${collisions.some(c => c.a === s.id || c.b === s.id) ? '<span class="badge conflict-text">시간 충돌</span>' : ''}${s.status === 'NEEDS_REVIEW' ? '<span class="badge review-text">시간 확인 필요</span>' : ''}<span class="badge">${s.credits}학점</span></div><button class="remove-button" data-remove="${s.id}" aria-label="${escape(s.title)} 빼기">×</button></div>`).join('') : '<div class="selection-empty">아직 담은 강좌가 없어요. 원하는 분반을 선택해 주세요.</div>';
  const banner = $('#conflict-banner'); const pending = current.filter(s => s.status === 'NEEDS_REVIEW');
  banner.classList.toggle('has-conflict', pairs > 0); banner.classList.toggle('has-review', !pairs && pending.length > 0);
  const lines = collisions.map(c => { const a = current.find(s => s.id === c.a), b = current.find(s => s.id === c.b); return `<span class="conflict-line">! ${escape(a.title)} ↔ ${escape(b.title)} · ${DAYS[c.day-1]} ${c.start === c.end ? c.start : `${c.start}–${c.end}`}교시 겹침</span>`; });
  if (pending.length) lines.push(`<span class="conflict-line">△ ${pending.length}개 강좌는 실제 강의시간 확인이 필요해요. 충돌이 없다고 판단할 수 없어요.</span>`);
  if (!lines.length) lines.push(current.length ? '✓ 확인된 강의시간 사이에 충돌이 없어요.' : '✳ 두 학과의 강좌를 자유롭게 조합해보세요. 겹치는 시간은 바로 알려드릴게요.');
  const hiddenWeekend = current.some(s => s.meetings.some(m => m.day > 5)) && !$('#weekend-toggle').checked;
  if (hiddenWeekend) lines.push('<span class="conflict-line">주말 강의가 있어요. ‘주말 표시’를 켜서 확인해 주세요.</span>');
  banner.innerHTML = lines.join('');
}
function render() { const current = selectedSections(), collisions = conflicts(current); renderCatalog(); renderCalendar(current, collisions); renderSelection(current, collisions); }
function toggle(id) {
  const item = sections.find(s => s.id === id); if (!item) return;
  if (selected.includes(id)) { selected = selected.filter(x => x !== id); toast(`${item.title}을(를) 뺐어요.`); }
  else { const previous = selectedSections().find(s => s.courseId === item.courseId); selected = selected.filter(x => x !== previous?.id); selected.push(id); toast(previous ? `${item.title}의 분반을 ${item.sectionNo}(으)로 바꿨어요.` : `${item.title}을(를) 담았어요.`); }
  persist(); render();
}
function example() {
  const a = sections.find(s => s.courseId === '109004' && s.sectionNo === '11001');
  const b = sections.find(s => s.courseId === '187008' && s.sectionNo === '21001');
  if (!a || !b) return toast('현재 자료에 예시 강좌가 없어요.');
  for (const s of [a,b]) { selected = selected.filter(id => sections.find(x => x.id === id)?.courseId !== s.courseId); selected.push(s.id); }
  persist(); render(); toast('두 전공의 예시 강좌를 담았어요. 화요일 1–2교시 충돌을 확인해보세요.');
}
$('#search').addEventListener('input', renderCatalog); $('#type-filter').addEventListener('change', renderCatalog); $('#hide-conflicts').addEventListener('change', renderCatalog);
document.querySelectorAll('[data-dept]').forEach(b => b.onclick = () => { department = b.dataset.dept; document.querySelectorAll('[data-dept]').forEach(x => x.classList.toggle('active',x === b)); renderCatalog(); });
$('#course-list').addEventListener('click', event => { const b = event.target.closest('[data-add]'); if (b) toggle(Number(b.dataset.add)); });
$('#selection-list').addEventListener('click', event => { const b = event.target.closest('[data-remove]'); if (b) toggle(Number(b.dataset.remove)); });
$('#example-button').onclick = example; $('#empty-example').onclick = example;
$('#weekend-toggle').onchange = render;
$('#reset-button').onclick = () => { if (!selected.length) return toast('초기화할 강좌가 없어요.'); if (confirm('선택한 강좌를 모두 비울까요?')) { selected = []; persist(); render(); toast('새 시간표를 시작할 준비가 됐어요.'); } };
$('#export-button').onclick = () => {
  if (!selected.length) return toast('먼저 강좌를 담아 주세요.');
  const current = selectedSections();
  const content = { title:'서울과학기술대학교 2026-2 다전공 시간표', source, exportedAt:new Date().toISOString(), totalCredits:totalCredits(current), sections:current, conflicts:conflicts(current), note:'개설 화면 기준. 확인 필요 강좌와 학생별 교육과정 이수요건은 별도 확인.' };
  const url = URL.createObjectURL(new Blob([JSON.stringify(content,null,2)], {type:'application/json'}));
  const a = document.createElement('a'); a.href=url; a.download='나의_시간표_2026_2.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000); toast('선택 시간표를 파일로 저장했어요.');
};
$('#connection-button').onclick = () => { $('#connection-error').textContent=''; $('#connection-dialog').showModal(); };
$('#help-button').onclick = () => $('#help-dialog').showModal();
document.querySelectorAll('[data-close]').forEach(b => b.onclick = () => $('#'+b.dataset.close).close());
document.querySelectorAll('dialog').forEach(d => d.addEventListener('click', e => { if (e.target === d) { const r=d.getBoundingClientRect(); if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)d.close(); } }));
$('#connection-form').onsubmit = async e => {
  e.preventDefault(); const button=$('#connect-submit'); button.disabled=true; button.textContent='연결 확인 중…'; $('#connection-error').textContent='';
  try { const response=await fetch('/api/connection',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user:$('#db-user').value.trim(),port:Number($('#db-port').value),password:$('#db-password').value})}); const data=await response.json(); if(!response.ok)throw new Error(data.error); acceptData(data); $('#db-password').value=''; $('#connection-dialog').close(); toast('내 MySQL의 강좌를 불러왔어요.'); }
  catch(err){ $('#connection-error').textContent=err.message; }
  finally{button.disabled=false;button.textContent='MySQL 연결하기';}
};
$('#snapshot-button').onclick = async () => { try { const response=await fetch('/api/connection',{method:'POST',headers:{'Content-Type':'application/json'},body:'{"disconnect":true}'}); if(!response.ok)throw new Error('연결 해제에 실패했어요.'); await load(); $('#db-password').value=''; $('#connection-dialog').close();toast('제공된 시간표 자료로 전환했어요.');}catch(err){$('#connection-error').textContent=err.message;} };
document.querySelectorAll('[data-view]').forEach(b => b.onclick = () => { document.body.classList.toggle('selected-focus', b.dataset.view==='selected'); document.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('active',x===b)); document.querySelector('main').scrollIntoView({behavior:'smooth'}); });
document.addEventListener('keydown',e=>{if(e.key==='/'&&!['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)&&!document.querySelector('dialog[open]')){e.preventDefault();$('#search').focus();}});
load();
