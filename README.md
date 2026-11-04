# Timestamp Web — WBL + YAP teacher app

**A mobile-friendly web rewrite of the uploaded SwiftUI Timestamp project.** Opens in Safari/Chrome without an IPA or sideloader. Built with React + Vite + Supabase Auth/Postgres, including row-level access control.

## What it does

- Teacher dashboard, student roster, direct `.csv`, `.tsv`, and `.xlsx` spreadsheet import
- **WBL / YAP** program field when adding/editing students
- Archive/restore students without deleting visits or hours; archived students are excluded from current planning. **Archiving removes their supervisor assignments**; reassign a supervisor after restoring a YAP student next school year.
- Student visit timeline, timestamps, notes (add/edit/delete), numeric visit counts, filters and sorting
- Plan In-person, Zoom, Phone call and Message contacts; only **In person** appears in Google Maps or Apple Maps links
- Mark visits completed, save sessions, manually enter and edit actual mileage
- Complete ZIP/JSON + CSV exports for dates you choose, including separate visits, mileage, YAP hours, roster, and notes
- Separate **supervisor account**: can select only YAP students assigned to them and add worked hours. No access to student employer addresses, phone numbers or teacher notes.
- YAP total enforced at **72 hours** in the database, including when people submit simultaneously
- Teacher-only full reset, configurable light blue/white or alternate colors, graduation-based retention checks
- Add to iPhone Home Screen from Safari (no Apple developer membership or sideloader required)

## How data stays saved between visits

**Student records and all changes are saved to Supabase Postgres over HTTPS.** They are *not* stored only in the webpage or lost when a tab closes. When a teacher or authorized supervisor signs back in (even on another approved phone/computer) they retrieve the same information from their Supabase project. Supabase Auth saves the sign-in session in browser storage; the app stores only the chosen color theme locally. The server protects rows through RLS rules.

**This is online-first**: you need an internet connection to load/save records. Do not assume edits made while offline are saved. Use the app's error messages and check the new entry appears. A removed or unauthorized account cannot read your class data through the API.

The complete ZIP export is for *manual backup*, not a one-click restore. Protect it separately; the ZIP isn't encrypted. The `full-backup.json` file should not be posted or stored publicly.

## Setup (Windows 11, no Mac required)

### 1. Create Supabase database

1. Sign in at [supabase.com](https://supabase.com) and create a **new project** dedicated to Timestamp.
2. Open **SQL Editor → New query**. Copy **all** of `supabase/schema.sql` and run it **once on the new project**. It creates tables, safe RLS policies, functions, indexes, and the database-enforced YAP hour ceiling. Do not apply casually to a database containing unrelated application tables.
3. Under **Authentication → Providers**, keep **Email** enabled. Keep email verification on. Consider limiting account signups to approved users before using real data. Enable an approved email service for actual deployment if required.
4. Under **Integrations → Data API**, confirm your `public` schema / the required tables and functions are exposed. New Supabase projects do not automatically expose every SQL-created table. `schema.sql` explicitly grants `authenticated` access, but the project Data API must also allow the schema.
5. From the project's **Connect** panel or API Keys page, copy **Project URL** and **Publishable key** (sometimes labeled `sb_publishable_...`). **NEVER use a service_role/secret key in a web application.**

### 2. Test it on your PC

You need **Node.js 20+** installed.

```bash
# In the extracted timestamp-web-source folder:
copy .env.example .env.local
npm install
npm run dev
```

Edit `.env.local` with the values from Supabase:

```dotenv
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key_here
```

Open the URL Vite prints, usually `http://localhost:5173`.

### 3. Authorize the first teacher

1. In the web app, choose **Sign up** using the teacher's approved email and a strong password. Verify the email using Supabase's email message.
2. Sign in. Initially the app says **Account pending approval**; this is intentional.
3. Go back to your Supabase project → **SQL Editor**. Run this statement, replacing the sample email with the *teacher's verified email address*:

```sql
insert into public.teachers(user_id)
select id from auth.users
where lower(email) = lower('teacher@school.edu')
on conflict do nothing;
```

4. Sign out and back in. The teacher sees a privacy acknowledgement before they can access their workspace. **Only an administrator with Supabase SQL access can grant teacher access.** Don't run this for people who should only log YAP hours.

### 4. Deploy the site (Cloudflare Pages)

1. Create a **new, private GitHub repository** for the **WEB version**. It is not an Xcode project. Upload **the contents** of `timestamp-web-source/` to the repository root. Don't upload `.env.local`, secrets, or exported student data.
2. In [Cloudflare](https://dash.cloudflare.com/), open **Workers & Pages → Create → Pages → Connect to Git**, select your repository.
3. Set **Framework preset: React (Vite)**; **Build command: `npm run build`**; **Build output directory: `dist`**; **Root directory: repository root**.
4. Under **Environment variables** (Production and Preview if previews will be used), create `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` with your project values.
5. Save and deploy. Cloudflare supplies an HTTPS URL like `https://timestamp-yourname.pages.dev`. Follow the latest Cloudflare Pages dashboard labels if they differ.
6. In Supabase **Authentication → URL Configuration**, set the **Site URL** to your live HTTPS Pages URL and add that URL to the **Redirect URLs** so confirmation emails can return to your site. If testing locally, allow `http://localhost:5173` as an additional redirect URL.
7. For iPhone: open that HTTPS URL in **Safari → Share → Add to Home Screen**. The teacher can use Timestamp like an app. No IPA or sideloader required.

### 5. Give a YAP workplace supervisor access to a specific student

1. The supervisor **signs up** at the same Timestamp URL using their own email/password and **confirms their email**.
2. The teacher goes to **Students → select a YAP student → Approved YAP supervisors**.
3. The teacher enters the supervisor's exact verified email and selects **Grant access**.
4. The supervisor signs out/in or refreshes the page and sees only their assigned YAP student names, graduation years, worked hours, and their hour history.
5. They select the student and log a dated number of hours (e.g. `4.5`). Total hours cannot exceed 72. **The database refuses entries over the limit**, even if two people submit at once.
6. Teachers may remove an incorrect entry. Archiving a student revokes supervisor access; restoring the student does not automatically grant that access again.

**Do not share teacher logins or give the supervisor a teacher account.**

## Imports and exports

Student import header example:

```csv
First Name,Last Name,Graduation Year,Grade,Employer Name,Employer Address,Phone Number,Program
Ava,Example,2028,11,Example Workplace,"100 Main St, Columbus, GA",555-0100,YAP
```

You can save a Google Sheet as **File → Download → Microsoft Excel (.xlsx)** or CSV and directly import it in **Students → Import sheet**. The importer previews the rows; blank Program values default to WBL. Keep real student data out of public sample files.

In **Exports**, select Visits, Mileage, YAP worked hours, Students or Notes; enter inclusive From/Through dates; and download CSV. You can also download an all-records ZIP. Export does **not** clear the database. For privacy, store exports only where school policy permits.

## Retention and school privacy

- Default retention enabled. Class of `2028` is due **July 1, 2029**, one year after the graduation year. The app calls a database function to remove expired records **at login and when the teacher returns to the web app**, after the teacher accepts the privacy notice. It also deletes trips containing expired students, so their route history isn't retained; independent visits for other students stay intact.
- **This is NOT a 24/7 background deletion system**. If nobody signs in or returns to the app for a year, old records may remain until the next check. A server-side scheduled job must be configured separately if the school requires a strict deletion date. Do not promise automatic overnight deletion based on this version.
- Missing graduation years are flagged and not automatically deleted. Archiving does not override retention rules. External exports, browser downloads and separately managed backups must be deleted separately.
- There is an option in Settings to turn retention off, with a warning. Teacher is responsible for following school policy and securely transferring any required records before deleting.
- **Do not put real student data in this app until your school/district reviews and authorizes it**, including its Supabase account, access management, retention policy, incident response, backups, and any required data-processing agreements under FERPA and applicable laws.
- Sign out on shared devices. Avoid storing records or exports on personal/unmanaged devices, and use strong authentication. The included RLS is a starting point, not an independent security certification.
- Google Maps and Apple Maps receive route addresses **only when you open a map link**. This web version cannot use native Apple MapKit to estimate mileage, and does **not automatically optimize stops**. Move planned stops up/down manually and enter actual mileage at the end.
- Supervisors never see the teacher's notes/phone/address roster through the app's policies. Teacher notes remain teacher-only.

## Upgrading from the SwiftUI iPhone app

**Existing iPhone-only records do not automatically sync to the new web database.** In the old Timestamp app, export a full backup **before changing phones or uninstalling**. The old export's `students.csv` may be imported into the new site's student roster. Other old visit, trip, and note history is **not automatically migrated by this version**. Do not discard the original encrypted/protected school backup just because students were reimported. Importing old CSV defaults Program to WBL unless a Program column is present.

## Development and testing

```bash
npm install
npm test
npm run build
```

Code in `src/`, SQL in `supabase/schema.sql`, tests in `tests/`.

**Current verification status:** The helper tests and a JSX source syntax check passed in the file-authoring environment. Full Vite build, real Supabase SQL deployment, RLS role tests, iOS Safari testing and a formal student-data privacy review have **not** been run here. Deploy with fictional students first, then test (a) teacher can edit only own roster, (b) supervisor cannot read student notes/address and cannot add hours to unassigned student, (c) two concurrent hour logs cannot exceed 72, (d) archived supervisor loses access, and (e) exports and retention operate as intended.

Current Supabase documentation: [React quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/reactjs) and [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security); Cloudflare's [Vite build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/).
