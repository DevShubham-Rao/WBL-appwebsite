import JSZip from 'jszip';
import { csvString, downloadBlob, getStudentName } from './helpers.js';

const headers = {
  students: ['ID','First name','Last name','Graduation year','Grade','Program','Employer','Employer address','Phone','Archived','Created'],
  visits: ['ID','Student','Visit type','Date/time','Note','Trip ID','Recorded by'],
  mileage: ['Trip ID','Trip date','Origin','Round trip','In-person stops','Actual miles','Completed'],
  yap_hours: ['Entry ID','Student','Date worked','Hours','Note','Logged at','Logged by'],
  notes: ['Note ID','Student','Note','Created at','Created by']
};
function inDateRange(value, start, end) {
  const d = String(value ?? '').slice(0,10);
  return (!start || d >= start) && (!end || d <= end);
}
export function reportData(kind, data, start='', end='') {
  const {students,visits,trips,stops,hours,notes} = data;
  const names = Object.fromEntries(students.map(s => [s.id,getStudentName(s)]));
  switch(kind) {
  case 'students': return {headers:headers.students, rows:students.map(s=>[s.id,s.first_name,s.last_name,s.graduation_year,s.grade,s.program,s.employer,s.address,s.phone,s.archived_at ?? '',s.created_at])};
  case 'visits': return {headers:headers.visits, rows:visits.filter(v=>inDateRange(v.visited_at,start,end)).map(v=>[v.id,names[v.student_id],v.kind,v.visited_at,v.note,v.trip_id,v.created_by])};
  case 'mileage': return {headers:headers.mileage, rows:trips.filter(t=>t.completed_at && inDateRange(t.trip_date,start,end)).map(t=>[t.id,t.trip_date,t.origin,t.round_trip ? 'Yes':'No',stops.filter(s=>s.trip_id===t.id && s.visit_kind==='In person').map(s=>names[s.student_id]).join('; '),t.actual_miles ?? '',t.completed_at])};
  case 'yap_hours': return {headers:headers.yap_hours, rows:hours.filter(h=>inDateRange(h.performed_on,start,end)).map(h=>[h.id,names[h.student_id],h.performed_on,h.hours,h.note,h.created_at,h.created_by])};
  case 'notes': return {headers:headers.notes, rows:notes.filter(n=>inDateRange(n.created_at,start,end)).map(n=>[n.id,names[n.student_id],n.body,n.created_at,n.created_by])};
  default: throw new Error('Unknown report');
  }
}
export function exportReport(kind, data, start='', end='') {
  const {headers,rows} = reportData(kind,data,start,end);
  downloadBlob(new Blob(['\uFEFF'+csvString(headers,rows)],{type:'text/csv;charset=utf-8'}), `timestamp-${kind}-${start || 'all'}-${end || 'all'}.csv`);
}
export async function exportBackup(data) {
  const zip = new JSZip();
  for (const kind of Object.keys(headers)) {
    const {headers:fields,rows}=reportData(kind,data);
    zip.file(`${kind}.csv`, '\uFEFF'+csvString(fields,rows));
  }
  zip.file('full-backup.json',JSON.stringify({format:'timestamp-web-v1',exported_at:new Date().toISOString(),...data},null,2));
  zip.file('READ_ME.txt','Student data is sensitive. Store this export in your school-approved secure location. This ZIP is not password-encrypted.');
  const blob = await zip.generateAsync({type:'blob'});
  downloadBlob(blob,`timestamp-full-backup-${new Date().toISOString().slice(0,10)}.zip`);
}
