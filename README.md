# Fallweise

An interactive German course covering A1, A2, and B1 grammar, tenses, vocabulary, pronunciation, and practical communication.

Pre-generated Vivian pronunciation audio is delivered from Cloudflare R2 at Slow, Learn, and Natural speeds. Learner progress and spaced review are persisted with Supabase.

Operational setup, safe project identifiers, recovery commands, and credential boundaries are documented in [OPERATIONS.md](OPERATIONS.md).

## Run locally

Serve the directory with any static web server:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Then open `http://127.0.0.1:4173`.
