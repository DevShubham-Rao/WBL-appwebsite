# Timestamp — Test Version Setup (GitHub + Supabase + Cloudflare)

This gets a **test copy** of the app online so one teacher can sign in, try everything, and report bugs.
Use **fake students only** while testing.

You need roughly 30–45 minutes. No coding required — just copy/paste.

---

## Step 1 — Put the code on GitHub

1. Go to <https://github.com/new>.
2. Name it something like `timestamp-test`. Choose **Private**. Click **Create repository**.
3. On the new repo page click **uploading an existing file**.
4. Unzip this project on your computer, open the folder, select **everything inside it**
   (`src`, `public`, `supabase`, `tests`, `.github`, `package.json`, `index.html`, etc.) and drag it into the browser.
   - Hidden files like `.gitignore`, `.node-version`, `.env.example` and the `.github` folder matter.
     On Mac press **Cmd+Shift+.** in Finder to see them; on Windows turn on **View → Show → Hidden items**.
   - **Do NOT upload** `node_modules`, `dist`, or any `.env.local` file.
5. Click **Commit changes**.

> If dragging hidden files is a pain, install **GitHub Desktop**, clone the empty repo, copy the files into that folder, then Commit + Push.

---

## Step 2 — Create the Supabase database

1. Go to <https://supabase.com> → **New project**. Name it `timestamp-test`, set a database password (save it somewhere), pick the region closest to you, click **Create**. Wait ~2 minutes.
2. Left sidebar → **SQL Editor** → **New query**.
3. Open `supabase/schema.sql` from this project, copy **all** of it, paste it in, click **Run**. You should see "Success. No rows returned".
   - Only run it **once**. If you get "already exists" errors you already ran it — that's fine.
   - **Already ran the OLD version (72 hours) earlier?** Run `supabase/upgrade-to-720.sql` instead. It switches to 720 hours and fixes a security bug.
4. Left sidebar → **Project Settings → API Keys**. Copy and keep these two handy:
   - **Project URL** (looks like `https://abcd1234.supabase.co`, also shown under **Project Settings → Data API**)
   - **Publishable key** (starts with `sb_publishable_…`). If you only see "legacy" keys, the **anon public** key also works.
   - ⚠️ **Never** use the `service_role` / secret key anywhere in this app.

---

## Step 3 — Deploy on Cloudflare Pages

1. Go to <https://dash.cloudflare.com> → **Workers & Pages** → **Create** → **Pages** tab → **Connect to Git**.
2. Connect GitHub and pick your `timestamp-test` repo → **Begin setup**.
3. Fill in:
   | Setting | Value |
   |---|---|
   | Framework preset | **React (Vite)** (or None) |
   | Build command | `npm run build` |
   | Build output directory | `dist` |
   | Root directory | *(leave blank)* |
4. Open **Environment variables (advanced)** and add these three:
   | Variable name | Value |
   |---|---|
   | `VITE_SUPABASE_URL` | your Project URL |
   | `VITE_SUPABASE_PUBLISHABLE_KEY` | your publishable key |
   | `VITE_TEST_MODE` | `true` |
5. Click **Save and Deploy**. After a couple of minutes you get a link like `https://timestamp-test.pages.dev`.

> **Changed an environment variable later?** Cloudflare only applies it on the next build: go to **Deployments → ⋯ → Retry deployment**.
>
> **"Set up Timestamp first" screen on the live site** = the variables are missing or misspelled. Fix them and retry the deployment.

---

## Step 4 — Tell Supabase your website address

Supabase → **Authentication → URL Configuration**:

- **Site URL**: `https://timestamp-test.pages.dev` (your real Cloudflare link)
- **Redirect URLs** → **Add URL**: the same link, plus `https://*.timestamp-test.pages.dev` (preview builds) and `http://localhost:5173` (only if you test on your own computer).

Save. Without this, verification and password-reset emails send people to the wrong place.

---

## Step 5 — Create your teacher's sign-in

Easiest way (no confirmation email needed):

1. Supabase → **Authentication → Users → Add user → Create new user**.
2. Enter the teacher's email and a temporary password. Leave **Auto Confirm User** ticked. Click **Create user**.
3. **SQL Editor → New query**: open `supabase/make-teacher.sql`, paste it, change `teacher@school.edu` to the teacher's email, click **Run**. The check at the bottom should show their email.

Now send your teacher:

- the link (`https://timestamp-test.pages.dev`)
- their email + temporary password
- "Use fake students only — it's a test version."

They sign in → accept the privacy notice once → they're in. They can change their password any time with **Forgot password?** on the sign-in screen.

> Supabase's built-in email sender is limited to a few emails per hour on the free plan. Creating the teacher by hand (above) avoids that. If reset emails don't arrive, wait an hour or check spam.

---

## Step 6 (optional) — Test a YAP supervisor

1. Open the site in a private/incognito window → **Sign up** with a second email → click the verification email.
2. As the teacher: **Students → add a YAP student → Approved YAP supervisors** → enter that email → **Grant access**.
3. Refresh the supervisor window. They see only that student and can log hours, up to **720 total**.

---

## Making fixes after your teacher reports bugs

Edit the file on GitHub (open file → ✏️ pencil → **Commit changes**). Cloudflare rebuilds automatically in ~2 minutes. Refresh the site to see it.

Database changes (anything in `supabase/`) don't deploy automatically — paste the SQL into the Supabase SQL Editor.

## Running it on your own computer (optional)

Install **Node.js 22** from <https://nodejs.org>, then in the project folder:

```bash
cp .env.example .env.local      # Windows: copy .env.example .env.local
# edit .env.local and paste your URL + key
npm install
npm run dev
```

Open <http://localhost:5173>.

## Quick troubleshooting

| What you see | Fix |
|---|---|
| "Set up Timestamp first" | Cloudflare env vars missing → add them, retry deployment |
| Cloudflare build fails on `npm` / Node version | Add env var `NODE_VERSION` = `22`, retry |
| "Account pending approval" | Run `make-teacher.sql` with the exact email, then sign out and back in |
| "Wrong email or password" | Use **Forgot password?**, or reset the password in Supabase → Users |
| "Email not confirmed" | Supabase → Users → ⋯ on that user → confirm, or click the email link |
| Reset/verify link opens localhost or a blank page | Fix Step 4 (Site URL + Redirect URLs) |
| "permission denied" / "relation does not exist" | `schema.sql` didn't run fully → re-run it in a **new** project |
