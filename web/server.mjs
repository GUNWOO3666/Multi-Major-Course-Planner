import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 3000);
let connection = null;
const mysqlBinary = process.env.MYSQL_BIN || (process.platform === 'win32'
  ? 'C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe' : 'mysql');
const query = `SELECT JSON_OBJECT(
 'id',s.section_id,'courseId',c.course_id,'title',c.title,'credits',c.credits,
 'department',d.dept_name,'departmentId',d.dept_id,'sectionNo',s.section_no,
 'professor',s.professor,'type',s.offered_course_type,'year',s.year,'semester',s.semester,
 'rawSchedule',s.raw_schedule,'rawClassrooms',s.raw_classrooms,'status',s.schedule_status,
 'meetings',COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT('day',cs.day_of_week,
 'start',cs.start_period,'end',cs.end_period,'room',cs.classroom))
 FROM ClassSchedule cs WHERE cs.section_id=s.section_id),JSON_ARRAY()))
 FROM Section s JOIN Course c ON c.course_id=s.course_id
 JOIN Department d ON d.dept_id=s.dept_id
 WHERE s.year=2026 AND s.semester=2 ORDER BY d.dept_id,s.section_id`;

function readDatabase(config) {
  return new Promise((resolve, reject) => {
    const child = spawn(mysqlBinary, ['--no-defaults', '--protocol=TCP', '--host=127.0.0.1',
      `--port=${config.port}`, `--user=${config.user}`, '--database=multi_major_planner',
      '--default-character-set=utf8mb4', '--batch', '--raw', '--skip-column-names',
      '--connect-timeout=5', '--execute', query], {
      windowsHide: true, env: { ...process.env, MYSQL_PWD: config.password }
    });
    let output = '', error = '', settled = false;
    const finish = (err, result) => { if (settled) return; settled = true; clearTimeout(timer); err ? reject(err) : resolve(result); };
    const timer = setTimeout(() => { child.kill(); finish(new Error('DB 응답 시간이 초과됐습니다. MySQL이 실행 중인지 확인해 주세요.')); }, 10000);
    child.on('error', () => finish(new Error('MySQL 실행 파일을 찾지 못했습니다. 실행 안내의 MYSQL_BIN 설정을 확인해 주세요.')));
    child.stdout.on('data', chunk => { output += chunk; if (output.length > 5_000_000) { child.kill(); finish(new Error('조회 결과가 너무 큽니다.')); } });
    child.stderr.on('data', chunk => { error += chunk; });
    child.on('close', code => {
      if (code !== 0) {
        const message = /1045/.test(error) ? '사용자 이름이나 비밀번호를 확인해 주세요.'
          : /2003|2005/.test(error) ? 'MySQL에 연결할 수 없습니다. 서버 실행 상태와 포트를 확인해 주세요.'
          : /1054|1146|1049/.test(error) ? 'DB 구조가 맞지 않습니다. 실제 자료 입력 SQL을 완료했는지 확인해 주세요.'
          : /1142/.test(error) ? '이 사용자에게 multi_major_planner 조회 권한이 없습니다.' : 'MySQL 조회에 실패했습니다. 연결 설정과 DB 구조를 확인해 주세요.';
        finish(new Error(message)); return;
      }
      try { finish(null, output.trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line))); }
      catch { finish(new Error('MySQL 결과를 읽지 못했습니다. 문자 인코딩을 확인해 주세요.')); }
    });
  });
}

function json(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(value));
}
async function body(req) {
  let data = ''; for await (const chunk of req) { data += chunk; if (data.length > 8192) throw new Error('요청이 너무 큽니다.'); }
  return JSON.parse(data || '{}');
}
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  const allowedHosts = [`127.0.0.1:${port}`, `localhost:${port}`];
  if (!allowedHosts.includes(req.headers.host)) return json(res, 403, { error: '허용되지 않은 주소입니다.' });
  const origin = req.headers.origin;
  if (origin && !allowedHosts.some(host => origin === `http://${host}`)) return json(res, 403, { error: '허용되지 않은 요청입니다.' });
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'");
  try {
    if (url.pathname === '/api/sections' && req.method === 'GET') {
      if (connection) return json(res, 200, { source: 'mysql', sections: await readDatabase(connection) });
      return json(res, 200, { source: 'snapshot', sections: JSON.parse(await readFile(path.join(root, 'public/data.json'), 'utf8')) });
    }
    if (url.pathname === '/api/connection' && req.method === 'POST') {
      if (!req.headers['content-type']?.startsWith('application/json')) return json(res, 415, { error: 'JSON 요청이 필요합니다.' });
      const input = await body(req);
      if (input.disconnect) { connection = null; return json(res, 200, { ok: true }); }
      if (typeof input.user !== 'string' || !/^[\w.-]{1,64}$/.test(input.user)
        || typeof input.password !== 'string' || input.password.length > 1024
        || !Number.isInteger(Number(input.port)) || Number(input.port) < 1 || Number(input.port) > 65535) {
        return json(res, 400, { error: '연결 정보를 확인해 주세요.' });
      }
      const next = { user: input.user, password: input.password, port: Number(input.port) };
      const sections = await readDatabase(next);
      connection = next;
      return json(res, 200, { source: 'mysql', sections });
    }
    if (url.pathname.startsWith('/api/')) return json(res, 404, { error: '없는 API입니다.' });
    if (!['GET', 'HEAD'].includes(req.method)) return json(res, 405, { error: '지원하지 않는 요청입니다.' });
    const routes = { '/': 'index.html', '/index.html': 'index.html', '/styles.css': 'styles.css',
      '/app.js': 'app.js', '/planner.mjs': 'planner.mjs', '/data.json': 'data.json', '/favicon.svg': 'favicon.svg' };
    const name = routes[url.pathname];
    if (!name) { res.writeHead(404); return res.end('Not found'); }
    const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml' };
    res.writeHead(200, { 'Content-Type': `${types[path.extname(name)]}; charset=utf-8`, 'Cache-Control': 'no-cache' });
    res.end(req.method === 'HEAD' ? '' : await readFile(path.join(root, 'public', name)));
  } catch (err) { json(res, 400, { error: err.message || '요청을 처리하지 못했습니다.' }); }
});
server.listen(port, '127.0.0.1', () => console.log(`Course Planner: http://127.0.0.1:${port}\n종료: Ctrl+C | MySQL 모드는 화면에서 연결하세요.`));
server.on('error', err => { console.error(err.code === 'EADDRINUSE' ? `${port} 포트가 사용 중입니다. 기존 창을 확인하거나 PORT를 변경하세요.` : err.message); process.exitCode = 1; });

