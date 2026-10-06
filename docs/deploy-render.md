# Deploying on Render + Supabase (free, no card)

| Piece | Where | Free-tier limits that matter |
| ----- | ----- | ---------------------------- |
| API (Rails + background jobs) | Render web service, Docker, Singapore | 512 MB RAM; sleeps after 15 min without traffic; 750 hours/month |
| Frontend (React) | Render static site | none that matter |
| Database | Supabase, Singapore | 500 MB; pauses after a week without activity |
| Keep-awake | cron-job.org | one ping every 10 minutes keeps the API (and its jobs) running |

`render.yaml` describes both Render services. Jobs run as threads inside the API process
(`SOLID_QUEUE_MODE=async`); heavy jobs (snapshots, backtest, reference syncs) run one at
a time on the `heavy` queue. Measured locally, the nightly snapshot job peaks around
440 MB. If Render ever reports the API ran out of memory, the fallback is Render's $7/month
instance (which needs a card). `Maintenance::DataRetention` trims old history nightly so
the database stays near 200–300 MB.

## 1. Supabase (database)

1. Sign up at https://supabase.com with GitHub. No card is needed for the free plan.
2. **New project**: name `nepse-journal`, region **Southeast Asia (Singapore)**. Let it
   generate the database password and **save it in your password manager**.
3. When it's ready: **Connect** (top of the project page) → **Session pooler** → copy the
   connection string and put your database password in place of `[YOUR-PASSWORD]`.
   (Use the session pooler, not "Direct connection": Render can't reach the direct one.)

## 2. Copy your data (from your Mac)

```bash
bin/render-copy-data
```

It asks for the Supabase connection string and a **new password** for your account
(nothing you type is shown). It copies your local database to a temporary one, trims it
to fit (30 sessions of broker flows, 130 of snapshots, 25 days of intraday volume), sets
the new password there, and uploads it. Your local database isn't changed.

## 3. Render (API and frontend)

1. Sign up at https://render.com with GitHub. No card is needed.
2. **New → Blueprint** → connect the `bijay3030/nepse-trade-journal` repository, branch
   `initial-app-setup`. Render reads `render.yaml` and shows two services.
3. It asks for two values:
   - `DATABASE_URL`: the Supabase connection string from step 1.
   - `RAILS_MASTER_KEY`: the contents of `config/master.key` (run `pbcopy < config/master.key`
     to copy it).
4. **Apply**. The first API build takes about 10 minutes; the frontend about 2.
5. Check the URLs Render gave the services. If they aren't exactly
   `https://nepse-journal-api.onrender.com` and `https://nepse-journal.onrender.com` (the
   names can be taken), update `FRONTEND_ORIGINS` and `API_HOSTS` on the API and
   `VITE_API_BASE_URL` on the frontend, then redeploy both.

## 4. Keep it awake (cron-job.org)

1. Sign up at https://cron-job.org (free).
2. **Create cronjob**: URL `https://nepse-journal-api.onrender.com/up`, every **10 minutes**,
   all day. Without it the API sleeps after 15 minutes and the 5-minute price sync,
   alerts and nightly jobs stop until someone opens the app.

## 5. Use it

Open `https://nepse-journal.onrender.com` and log in with the email and password from
step 2. The first load after the API has slept takes about a minute.

## Notes

- **Updates:** merging into `initial-app-setup` redeploys both services automatically.
- **Telegram:** the API uses the bot token from the credentials. Your laptop ignores it
  in development (unless `TELEGRAM_IN_DEVELOPMENT=true`), so only the server polls the bot.
- **Shell:** free Render services have none. One-off tasks (a password change, copying
  data again) run from your Mac against Supabase, e.g.
  `DATABASE_URL='<supabase url>' bin/rails 'users:set_password[you@example.com]'`.
- **Copying again** (`bin/render-copy-data`) replaces everything in Supabase with your
  local data, including positions and alerts recorded on the live app.
