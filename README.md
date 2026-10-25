# Alex 2.0 — native iPhone project

## What is included
- Native SwiftUI iPhone app, animated vector avatar with speech-state mouth animation
- Speech-to-text using Apple's Speech framework; tap mic to dictate, tap again to stop, then send
- Spoken replies with Apple's AVSpeechSynthesizer; select any installed English voice
- AI chat through a separate Node.js server, with OpenAI API key kept server-side
- Investor presentation mode for RepairLens and OhmLoom, with an introduction button
- Local conversation history and clear-history action
- Dark visual design, cup-holder Easter egg

## Honest limitations
- This is **source**, not a compiled or signed IPA. An actual iOS IPA must be compiled on a Mac with Xcode (or a macOS CI service), then signed for the device. Linux Swift cannot compile UIKit/SwiftUI iOS apps.
- The supplied avatar is procedural and reacts while speech plays; it does not perform phoneme-accurate lip synchronization.
- A voice called **Marco** is not bundled. If the iPhone has a compatible voice installed, choose it in Settings; otherwise a licensed third-party voice/TTS integration is required to reproduce a specific Marco voice.
- The backend is required for real AI responses. No secret OpenAI key is shipped in the IPA.
- Speech recognition may depend on Apple's services, depending on locale/device.
- Memory here is **local saved conversation history**, not long-term semantic memory across devices.
- LiveContainer compatibility is **not verified** on the user's device. Some iOS frameworks and permissions can behave differently inside LiveContainer.

## iOS build (Mac or macOS CI)
1. Install Xcode 15.4 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. In this folder run `xcodegen generate`.
3. Open `Alex2.xcodeproj` in Xcode.
4. Choose a signing team and a unique bundle ID, then build for a physical iPhone.
5. For an IPA, use Product > Archive > Distribute App with a signing method your account supports. Exporting a development IPA may require a compatible Apple signing setup.
6. Transfer the signed IPA into LiveContainer if your LiveContainer version supports it. Test microphone and speech permissions.

## Backend setup
Node.js 20+ required; no npm dependencies.

```bash
cd Server
export OPENAI_API_KEY='your-api-key'
export ALEX_APP_TOKEN='long-random-token'
node server.mjs
```

Deploy behind HTTPS with a reverse proxy or a trusted HTTPS hosting provider. In Alex Settings, enter the server base URL, e.g. `https://alex.example.com`, and the same app access token. The app POSTs to `/chat`. For local simulator testing only, localhost HTTP is permitted in the app URL validator; actual iPhone requests need a reachable HTTPS URL.

**Security:** Do not publish your API key or access token. The access token is stored in iOS UserDefaults in this prototype; production should use Keychain and rate limiting, user authentication, request quotas, and server-side abuse protection. Protect HTTPS endpoints and avoid logging chat text. Do not publicly expose an unprotected server.

## Investor demo
Enable Investor presentation mode, then tap Start investor introduction. The assistant describes concepts and caveats, rather than inventing validated results. The project does not include prerecorded investor video, financial promises, or real-time avatar video rendering.

## Testing checklist
- App launches, Settings persist, server health endpoint works
- Typed chat returns a reply and speaks it
- Microphone and speech recognition permissions granted, dictation fills composer
- Investor introduction works and avoids unsupported promises
- App reopens and conversation history persists
- IPA launches under target LiveContainer version and speech APIs work

## Next-stage enhancements
For a fully production-ready Alex: streaming audio, true viseme-based lip sync, a licensed Marco voice, Keychain secrets, cloud memory with user controls, real-time interruption/barge-in, backend accounts, and actual iPhone/LiveContainer QA are still required.

## GitHub Actions cloud build (Windows-friendly)
The repository includes `.github/workflows/build-ios.yml`. Upload the **contents of this project folder** to the repository root (including the hidden `.github` folder), not the parent directory or a ZIP. Go to GitHub > Actions > Build Alex 2.0 iOS IPA > Run workflow. After the job succeeds, download `Alex2-unsigned-ipa` from the run's Artifacts section and unzip that artifact to obtain `Alex2-unsigned.ipa`.

This IPA is **unsigned** and must be signed by a compatible tool before installation. A successful cloud build does not guarantee LiveContainer compatibility. The workflow has not yet been run on GitHub; build errors, if any, will be visible in the Actions log.

## Repair notes
Fixed Swift syntax error in speech handler; added speech availability check; updated investor architecture and budget. iOS build and LiveContainer are not yet verified.
i
