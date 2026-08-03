# Fallweise operations guide

This file is the safe, non-secret handoff for future development sessions. It records how persistence, audio delivery, and deployment are connected. Never add passwords, access tokens, refresh tokens, database passwords, or Supabase service-role keys here.

## System map

- The static application is stored in GitHub and published with GitHub Pages.
- Supabase owns learner identity, progress, mastery, attempts, and review scheduling.
- Cloudflare R2 owns the generated Vivian WAV files.
- The browser calculates a deterministic SHA-256 filename for each requested text and speed, then loads it from R2.
- IndexedDB provides an offline queue if Supabase is temporarily unavailable.

## GitHub and local development

- Repository: `https://github.com/arpithpm/fallweise-german`
- Production site: `https://arpithpm.github.io/fallweise-german/`
- Deployment branch: `main`
- Local workspace used during setup: `/Users/I531058/Documents/Codex/2026-07-31/i`

Run locally:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173`. GitHub Pages deploys after a push to `main`; verify the remote revision before assuming a push or deployment succeeded:

```sh
git rev-parse HEAD
git ls-remote origin refs/heads/main
curl -I https://arpithpm.github.io/fallweise-german/
```

## Supabase

### Project identity

- Project name: `Fallweise`
- Project ref: `xysuwcwgcbbnbpmfdwor`
- Region: `eu-west-1`
- Public project URL: `https://xysuwcwgcbbnbpmfdwor.supabase.co`
- Browser integration: `persistence.js`
- Schema source of truth: `supabase/migrations/20260802083000_learning_foundation.sql`

The Supabase publishable key in `persistence.js` is intentionally public and is safe in a browser application. Its access is constrained by Row Level Security. A service-role key is privileged and must never appear in frontend code or Git.

### Data model

The migration creates:

- `profiles`
- `user_settings`
- `lesson_progress`
- `skill_mastery`
- `review_items`
- `study_sessions`
- `exercise_attempts`
- `learning_dashboard` view
- `get_daily_review(integer)` function

All learner tables use RLS. Authenticated users can access only rows belonging to their own `auth.uid()`. A new auth user automatically receives a profile and settings row.

### Authentication and persistence behavior

- A first visit creates an anonymous Supabase user.
- Supabase JS persists and refreshes the session in browser storage.
- The learner can attach an email from the account dialog and use a secure email link across devices.
- Anonymous/private-browser sessions are separate unless the learner connects an email account.
- Writes first enter the IndexedDB database `fallweise-learning`, store `sync_queue`, and are flushed to Supabase when online.
- The offline queue and last local state remain device-specific.

### CLI access and migrations

Authenticate interactively and link the workspace when required:

```sh
npx supabase@latest login
npx supabase@latest link --project-ref xysuwcwgcbbnbpmfdwor
npx supabase@latest projects list
```

Review migration state before making a schema change, create a new migration rather than editing an already-deployed one, then push it:

```sh
npx supabase@latest migration list
npx supabase@latest migration new descriptive_change_name
npx supabase@latest db push
```

The generated `supabase/.temp/` link metadata is ignored by Git. Supabase CLI credentials are machine-local and must stay outside the repository.

### Supabase smoke test

In a browser, complete one exercise and confirm:

- the status badge reaches `Progress saved`;
- a refresh resumes progress;
- `lesson_progress`, `exercise_attempts`, `skill_mastery`, and `review_items` receive rows for the current user;
- a different authenticated user cannot read those rows.

## Cloudflare R2 audio

### Resource identity

- Cloudflare account ID: `0ee92d856ec9d40bd852b4650d537dd2`
- Bucket: `fallweise-audio`
- Location: Eastern Europe (`EEUR`)
- Storage class: Standard
- Public endpoint: `https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev`
- Browser integration: `speech.js`, constant `AUDIO_CDN`
- Local generated cache: `work/tts-cache/` (ignored by Git)

The `r2.dev` URL is Cloudflare's rate-limited development endpoint. It works for the current learner traffic, but a custom domain should replace it before significant production traffic. When that happens, update `AUDIO_CDN` and the CORS policy.

### Current CORS policy

```json
[
  {
    "AllowedOrigins": [
      "https://arpithpm.github.io",
      "http://127.0.0.1:4173",
      "http://localhost:4173"
    ],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 86400
  }
]
```

Inspect the live bucket configuration:

```sh
npx wrangler@latest login
npx wrangler@latest whoami
npx wrangler@latest r2 bucket info fallweise-audio
npx wrangler@latest r2 bucket cors list fallweise-audio
npx wrangler@latest r2 bucket dev-url get fallweise-audio
```

Wrangler OAuth credentials are machine-local. On this Mac they are managed under `~/Library/Preferences/.wrangler/`; never copy that directory into the repository. The workspace `.wrangler/` directory is also ignored.

### Audio naming contract

The frontend and generator must use the same values:

- Model: `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`
- Speaker: `Vivian`
- Rates: `1.0` Natural, `0.88` Learn, `0.72` Slow
- Format: mono WAV, 24 kHz

The object name is:

```text
SHA256("Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice|Vivian|<rate>|<text>") + ".wav"
```

For nouns, `<text>` includes the article. Word and example-sentence audio are separate objects. Changing the model ID, speaker spelling, rate formatting, or text changes the hash and therefore the object URL.

### Generate and upload audio

Generate missing curriculum audio locally:

```sh
./work/qwen-tts-env/bin/python scripts/generate-a1-audio.py --expanded --batch-size 8
```

Upload one object with Wrangler:

```sh
npx wrangler@latest r2 object put \
  "fallweise-audio/<hash>.wav" \
  --file "work/tts-cache/<hash>.wav" \
  --content-type audio/wav \
  --remote
```

For a bulk upload, use a scoped Cloudflare API token supplied only through the environment and parallelize conservatively. Do not put the token in a script, shell history, documentation, or Git. Uploaded objects should have:

```text
Content-Type: audio/wav
Cache-Control: public, max-age=31536000, immutable
```

The setup run uploaded 7,638 hashed WAV files. Local files remain in `work/tts-cache/`; R2 is now the deployed source and WAV files are intentionally absent from Git.

### Audio verification

Check a representative object from the deployed origin:

```sh
curl -I \
  -H 'Origin: https://arpithpm.github.io' \
  'https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev/<hash>.wav'
```

Expected properties include `200 OK`, `Content-Type: audio/wav`, `Accept-Ranges: bytes`, the matching `Access-Control-Allow-Origin`, and a non-zero `Content-Length`. A range request should return `206 Partial Content`:

```sh
curl -I \
  -H 'Origin: https://arpithpm.github.io' \
  -H 'Range: bytes=0-1023' \
  'https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev/<hash>.wav'
```

Do not audit thousands of `r2.dev` objects with high request concurrency; the development endpoint responds with rate-limit `403`s. Verify representative files at learner-like rates, or use authenticated R2 APIs for inventory checks.

## Credential and secret policy

## Gemini Live voice tutor

- Frontend: `voice-tutor.html`, `voice-tutor.js`, and `voice-tutor.css`
- Token Worker: `worker/`
- Worker name: `fallweise-voice-session`
- Endpoint: `https://fallweise-voice-session.arpithpmuddi-0ee.workers.dev`
- Model: `gemini-3.1-flash-live-preview`

The browser authenticates with its Supabase access token. The Worker verifies that token through Supabase Auth, checks the request origin, and exchanges the server-only Gemini key for a one-use ephemeral token. The long-lived Gemini key must exist only as the Worker secret `GEMINI_API_KEY`.

Deploy after authenticating Wrangler:

```sh
cd worker
npm install
npm run deploy
```

The first browser gesture starts microphone access; after that the lesson speaks, listens, grades, responds, and advances hands-free. The browser sends live microphone PCM to Gemini but does not save recordings. Transcripts and learning progress are persisted through the existing Supabase integration.

Safe to commit:

- project refs, account IDs, bucket names, and public URLs;
- Supabase publishable/anon keys used by browser code;
- CORS configuration, migrations, and operational commands.

Never commit:

- Cloudflare OAuth/API tokens or refresh tokens;
- Supabase access tokens, database passwords, or service-role keys;
- `.wrangler/`, `supabase/.temp/`, `.env`, local browser storage, or generated credential files.

Before committing operational changes:

```sh
git status --short
git diff --check
rg -n -i 'service[_-]?role|access[_-]?token|refresh[_-]?token|client[_-]?secret' \
  --glob '!work/**' --glob '!OPERATIONS.md'
```

Review any matches manually. Do not print credential files to logs or chat.

## Future-session checklist

1. Read this file and `README.md`.
2. Run `git status -sb` and preserve unrelated user changes.
3. Confirm `main`, the GitHub remote, and the deployed site.
4. For database work, run Supabase login/link and inspect migrations before changing schema.
5. For audio work, run Wrangler login and inspect bucket, CORS, and public URL.
6. Keep WAVs in R2/local cache—not Git.
7. Validate curriculum counts, responsive layout, Supabase progress, and real Cloudflare playback.
8. Push only after local validation; verify the remote hash and public GitHub Pages result.
