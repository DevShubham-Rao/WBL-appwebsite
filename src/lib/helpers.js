export const VISIT_KINDS = ['In person', 'Zoom', 'Phone call', 'Message'];
export const PROGRAMS = ['WBL', 'YAP'];
export const HOURS_LIMIT = 72;
export function totalHours(rows = [], studentId) {
  return Math.round(rows.filter(r => r.student_id === studentId).reduce((a, r) => a + Number(r.hours), 0) * 100) / 100;
}
export function remainingHours(rows, studentId) { return Math.max(0, Math.round((HOURS_LIMIT - totalHours(rows, studentId)) * 100) / 100); }
export function canLogHours(rows, studentId, amount) {
  const n = Number(amount);
  return Number.isFinite(n) && n > 0 && Math.abs(Math.round(n * 100) - n * 100) < 0.0000001 && n <= remainingHours(rows, studentId);
}
export function expirationDate(graduationYear) {
  const year = Number(graduationYear);
  return Number.isInteger(year) && year >= 1900 && year <= 2100 ? `${year + 1}-07-01` : null;
}
export function formatDateTime(value) { return value ? new Date(value).toLocaleString() : '—'; }
export function formatDate(value) { return value ? new Date(`${String(value).slice(0,10)}T12:00:00`).toLocaleDateString() : '—'; }
export const today = () => { const d = new Date(); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0,10); };
export function isoFromLocal(value) { return new Date(value).toISOString(); }
export function safeDate(value) { return value ? String(value).slice(0, 10) : ''; }
export function getStudentName(student) { return student ? `${student.first_name} ${student.last_name}`.trim() : 'Unknown student'; }
export function escapeCSV(value) { return `"${String(value ?? '').replaceAll('"', '""')}"`; }
export function csvString(headers, rows) { return [headers.map(escapeCSV).join(','), ...rows.map(row => row.map(escapeCSV).join(','))].join('\r\n'); }
export function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a'); anchor.href = url; anchor.download = filename;
  document.body.appendChild(anchor); anchor.click(); anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 120000);
}
export function mapsLink(stops, origin, roundTrip) {
  if (!stops.length || !origin.trim()) return null;
  const destinations = stops.map(s => s.address.trim()).filter(Boolean);
  if (!destinations.length) return null;
  const last = roundTrip ? origin : destinations[destinations.length - 1];
  const waypointAddresses = roundTrip ? destinations : destinations.slice(0,-1);
  const query = new URLSearchParams({ api: '1', origin, destination: last, travelmode: 'driving' });
  if (waypointAddresses.length) query.set('waypoints', waypointAddresses.join('|'));
  return `https://www.google.com/maps/dir/?${query}`;
}
export function normalizeHeader(value) { return String(value ?? '').toLowerCase().replace(/[^a-z0-9]/g,''); }
export function rowsToStudents(rows) {
  if (!rows.length) return [];
  const aliases = [
    ['firstname','first'],['lastname','last'],['graduationyear','gradyear','graduation'],
    ['grade','gradelevel'],['employername','employer','company'],['employeraddress','address','workplaceaddress'],
    ['phonenumber','phone','telephone'],['program','studenttype','wbloryap']
  ];
  const header = rows[0].map(normalizeHeader);
  const indices = aliases.map(options => header.findIndex(h => options.includes(h)));
  const hasHeaders = indices.filter(i => i !== -1).length >= 3;
  return (hasHeaders ? rows.slice(1) : rows).map(row => {
    const field = i => String(row[hasHeaders && indices[i] !== -1 ? indices[i] : i] ?? '').trim();
    const program = field(7).toUpperCase();
    return { first_name:field(0),last_name:field(1),graduation_year: Number(field(2)) || null,
      grade:field(3), employer:field(4),address:field(5),phone:field(6),
      program:program === 'YAP' ? 'YAP' : 'WBL' };
  }).filter(s => s.first_name && s.last_name);
}
