import { supabase } from './supabase.js';

export function ensure(result) {
  if (result.error) throw result.error;
  return result.data;
}
export async function allRows(table, filter) {
  const rows = [];
  for (let offset = 0; offset < 20000; offset += 500) {
    let q = supabase.from(table).select('*').order(table === 'teachers' ? 'user_id' : 'id', {ascending:true}).range(offset, offset + 499);
    if (filter) q = filter(q);
    const chunk = ensure(await q);
    rows.push(...chunk);
    if (chunk.length < 500) return rows;
  }
  throw new Error(`Too many ${table} records; contact the site administrator to paginate or export safely.`);
}
export async function loadTeacherData(userId) {
  const [students, visits, notes, trips, stops, hours, assignments, teachers] = await Promise.all([
    allRows('students', q => q.eq('owner_id', userId)),
    allRows('visits'), allRows('student_notes'),
    allRows('trips', q => q.eq('owner_id', userId)),
    allRows('trip_stops'), allRows('yap_hours'), allRows('supervisor_assignments'),
    allRows('teachers', q => q.eq('user_id',userId))
  ]);
  return { students, visits, notes, trips, stops, hours, assignments, teacher: teachers[0] };
}
export async function loadSupervisorData() {
  const students = ensure(await supabase.rpc('my_yap_students'));
  const hours = await allRows('yap_hours');
  return { students, hours };
}
export async function insert(table, row) { return ensure(await supabase.from(table).insert(row).select().single()); }
export async function update(table, id, changes) { return ensure(await supabase.from(table).update(changes).eq('id',id).select().single()); }
export async function remove(table, id) { ensure(await supabase.from(table).delete().eq('id',id)); }
export async function call(name, args={}) { return ensure(await supabase.rpc(name, args)); }
