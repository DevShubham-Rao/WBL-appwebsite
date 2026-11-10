import test from 'node:test';
import assert from 'node:assert/strict';
import { HOURS_LIMIT, canLogHours, expirationDate, mapsLink, remainingHours, rowsToStudents, totalHours } from '../src/lib/helpers.js';
test('YAP 720-hour ceiling includes existing entries',()=>{
 const rows = [{student_id:'abc',hours:719.5}];
 assert.equal(HOURS_LIMIT,720);
 assert.equal(totalHours(rows,'abc'),719.5);
 assert.equal(remainingHours(rows,'abc'),.5);
 assert.equal(canLogHours(rows,'abc',.5),true);
 assert.equal(canLogHours(rows,'abc',.6),false);
 assert.equal(canLogHours(rows,'abc',-1),false);
});
test('Graduation retention matches original July 1 rule',()=>{
 assert.equal(expirationDate(2028),'2029-07-01');
 assert.equal(expirationDate('bad'),null);
});
test('Spreadsheet rows include WBL / YAP',()=>{
 const students = rowsToStudents([['First Name','Last Name','Graduation Year','Grade','Employer Name','Employer Address','Phone Number','Program'],['Sam','Test','2028','11','Store','101 Main St','555-0000','YAP']]);
 assert.equal(students.length,1);assert.equal(students[0].program,'YAP');
});
test('Maps only receive supplied in-person stops',()=>{
 const link = mapsLink([{address:'A street'},{address:'B street'}],'My start',true);
 assert.ok(link.includes('waypoints=A+street%7CB+street'));
 assert.ok(!link.includes('Zoom'));
});
