# Fallweise for iPhone

Native SwiftUI voice-first German learning app. It uses the same authored A1 vocabulary source as the web app and connects directly to the existing Supabase, Cloudflare, LiveKit, Deepgram, and Cartesia stack.

## Run

1. Open `Fallweise.xcodeproj` in Xcode.
2. Select the `Fallweise` scheme and an iPhone simulator or connected iPhone.
3. Choose your Apple Development team under Signing & Capabilities when installing on a physical phone.
4. Run. The app creates an anonymous Fallweise account automatically and asks for microphone permission when Mia starts.

Regenerate the project after changing `project.yml` with `xcodegen generate`. Regenerate bundled vocabulary from the repository root with `node scripts/export-a1-vocabulary.mjs`.

## Architecture

- SwiftUI native interface; no WebView.
- LiveKit Swift SDK for real-time audio and data.
- Deepgram STT and Cartesia TTS via the existing LiveKit agent.
- Supabase REST/Auth for anonymous identity and lesson progress.
- `UserDefaults` local-first resume when offline.
- 27 units, 108 five-word sessions, and all 540 A1 vocabulary entries.
