import Papa from 'papaparse';
import { readSheet } from 'read-excel-file/browser';
import { rowsToStudents } from './helpers.js';
export async function studentsFromFile(file) {
  const lower = file.name.toLowerCase();
  if (!/\.(csv|tsv|xlsx)$/.test(lower)) throw new Error('Choose an Excel .xlsx, CSV, or TSV file.');
  if (file.size > 8 * 1024 * 1024) throw new Error('File too large; split it into files smaller than 8 MB.');
  let rows;
  if (lower.endsWith('.xlsx')) rows = await readSheet(file);
  else {
    const contents = await file.text();
    const parsed = Papa.parse(contents,{skipEmptyLines:'greedy',delimiter: lower.endsWith('.tsv') ? '\t' : ','});
    if (parsed.errors.length) throw new Error(parsed.errors[0].message);
    rows=parsed.data;
  }
  const students = rowsToStudents(rows);
  if (!students.length) throw new Error('No students found. Check the column names and data.');
  if (students.length > 500) throw new Error('Import up to 500 students at a time.');
  return students;
}
