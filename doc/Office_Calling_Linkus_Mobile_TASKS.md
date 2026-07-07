# Office Calling (Linkus SDK) — Mobile | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. Then read the companion document: `linkus-sdk-guide-appliance-edition-en.pdf` (focus: 'Linkus SDK for Android' pages 4-36, and 'Linkus SDK for iOS' pages 37-55). Then start at Task F.0 and work top to bottom. Never skip ahead.

> **File placement note:** This file deliberately does NOT prescribe folder structure, file paths, or file names. You know this codebase and its conventions — place all new code where it best fits the existing architecture, consistent with how the app is already organized. The tasks below describe WHAT to build and HOW it should behave, not WHERE files go.

---

## 0. About This Work

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**. This task file covers the **MOBILE** half of integrating in-app office calling via the **Yeastar Linkus SDK**.

### The feature in one sentence
A call button appears on chat conversations. Tapping it places an office phone call (via the company PBX) to the chat participant. The app can also receive incoming office calls.

### THE KEY CHALLENGE — read this first
The Linkus SDK is **native only**:
- **Android:** a `.aar` library (Java 11)
- **iOS:** a native framework (Objective-C / Swift)

**There is NO official Flutter SDK.** You cannot import it directly into Dart.

Therefore the core of this work is building a **Flutter Platform Channel bridge** — a native wrapper layer on each platform that exposes the Linkus SDK to Flutter via MethodChannels (Dart → native commands) and EventChannels (native → Dart events).

This is a well-known Flutter pattern, but it is the bulk of the effort. Treat the native bridge as the foundation — everything else depends on it.

### Scope — CALLING ONLY
- ✅ In scope: 1:1 voice call (make, answer, reject, hang up), in-call controls (mute, hold/resume, speaker, DTMF keypad), incoming call handling, call state UI, push notifications for incoming calls
- ❌ Out of scope (Phase 2): conference call, multi-party call, attended/blind transfer, call recording, CDR sync/history

### Stack
- Flutter (existing app)
- **Android native:** Kotlin/Java wrapping `linkus-sdk-x.x.x.aar`
- **iOS native:** Swift wrapping the Linkus iOS framework
- Platform Channels (MethodChannel + EventChannel)
- Firebase (already set up in the app) — for Android push
- APNs — for iOS push
- Riverpod — state management (use the app's existing state management approach if different)

---

## 1. Code Placement & Conventions

You own all decisions about file structure, naming, and placement. Follow these principles:

- Place new code consistent with how the existing app is already organized — match its feature/layer structure, its naming conventions, and its module boundaries.
- The native bridge code (Kotlin, Swift) goes in the existing Android and iOS project folders following whatever pattern the app already uses for platform code.
- The Linkus `.aar` and iOS framework go wherever the app already keeps native dependencies.
- Keep the office-calling feature self-contained and consistent with how other features in this app are structured.
- Do not create a parallel or inconsistent structure just for this feature.

If the existing app has an established pattern for a given concern (API clients, repositories, controllers, platform channels, screens), follow that pattern exactly.

---

## 2. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **Backend brokers authentication** | The app NEVER holds AccessID/AccessKey. It calls the backend's `/api/office_call/credentials` to get a login signature. |
| **The app logs in with the signature, not a password** | Linkus SDK uses signature-based auth. |
| **SDK initialization happens ONCE, in the main process** | Per the SDK guide — re-initializing is not allowed. |
| **Native bridge is the foundation** | Build and verify the bridge before any call UI. |
| **Microphone permission required before any call** | Request and verify at runtime. |
| **Incoming calls need a foreground service (Android 11+)** | The SDK guide explicitly notes background calls require a foreground service. |
| **Match the backend's connection model** | Internal-only users get LAN IP; anywhere users get LAN + public. The app passes whatever the backend returns. |
| **Identical bridge contract on Android and iOS** | Dart code must be platform-agnostic. Both natives implement the same MethodChannel/EventChannel contract. |
| **One commit per task** | Format: `feat(office-call): <TASK_ID> <description>` |
| **Never log the signature** | Sensitive. |
| **Two native codebases** | Android and iOS each need their own wrapper — they are separate tasks. |

---

## 3. Architecture

```
                  FLUTTER (Dart)
   ┌─────────────────────────────────────────────┐
   │  Chat screen → Call button                  │
   │  Call screens (outgoing / incoming / in-call)│
   │  Call state controller (Riverpod)            │
   │  Call orchestration service (Dart) ──────┐  │
   └──────────────────────────────────────────┼──┘
                                              │
                MethodChannel (Dart → native commands)
                EventChannel  (native → Dart events)
                                              │
   ┌──────────────────────────────────────────┼──┐
   │  ANDROID native bridge (Kotlin)           │  │
   │    wraps YlsBaseManager / YlsLoginManager │  │
   │    / YlsCallManager from linkus-sdk.aar   │  │
   └───────────────────────────────────────────┘
   ┌───────────────────────────────────────────┐
   │  iOS native bridge (Swift)                 │
   │    wraps the Linkus iOS framework          │
   └───────────────────────────────────────────┘
                                              │
                                              ▼
                            Yeastar PBX (office phone system)
```

### Call setup flow
```
User taps "Call" on a chat
        │
        ▼
App resolves chat participant → extension (via /api/office_call/directory)
        │
        ▼
App ensures it has a valid Linkus session:
   - If not logged into SDK → call backend /credentials → get signature
   - → SDK login with signature + connection info
        │
        ▼
App calls native bridge: makeCall(extension)
        │
        ▼
Native bridge → YlsCallManager.makeNewCall(...)
        │
        ▼
Call state events flow back via EventChannel → UI updates
```

### Recommended layering (place files per your own conventions)
- **Platform channel layer** — the only code that talks to MethodChannel/EventChannel
- **API layer** — calls the backend's office-call endpoints
- **Orchestration service** — owns the call lifecycle, login, signature refresh
- **State controller** — exposes call state to the UI (Riverpod or the app's existing approach)
- **UI** — call button + call screens; never touches the bridge directly

The UI must never call the platform channel directly. It goes through the controller → service → bridge.

---

## 4. Functional Knowledge

### 4.1 The native bridge contract
Define ONE consistent contract that both Android and iOS implement, so the Dart side is platform-agnostic.

**MethodChannel `office_call/methods` — Dart calls native:**
| Method | Args | Purpose |
|--------|------|---------|
| `initSdk` | config | Initialize Linkus SDK (once) |
| `login` | signature, extension, lanIp, lanPort, publicIp, publicPort | Log into SDK |
| `logout` | — | Log out |
| `isLoggedIn` | — | Query login status |
| `makeCall` | number | Start outgoing call |
| `answerCall` | callId | Answer incoming |
| `rejectCall` | callId | Reject incoming |
| `hangUp` | callId | End call |
| `hold` | callId | Hold |
| `unhold` | callId | Resume |
| `mute` | callId, muted | Mute/unmute |
| `setSpeaker` | enabled | Speaker on/off |
| `sendDtmf` | callId, digit | DTMF tone |
| `setPushToken` | platform, token | Register push token |

**EventChannel `office_call/events` — native sends to Dart:**
| Event | Payload | Meaning |
|-------|---------|---------|
| `callStateChanged` | callId, state, number, name | ringing / connecting / active / held / ended |
| `incomingCall` | callId, number, name | An incoming call arrived |
| `callEnded` | callId, reason, duration | Call finished |
| `loginStateChanged` | state | Logged in / out / reconnecting |
| `connectionChanged` | connected | PBX connection up/down |
| `callQuality` | callId, level | Network/quality indicator |
| `error` | code, message | Something failed |

Keep these channel names and the method/event names IDENTICAL across Android and iOS.

### 4.2 Android SDK key classes (from the SDK guide)
- `YlsBaseManager` — init, SDK callbacks, push info
- `YlsLoginManager` — loginBlock(...), cacheLogin(...), isLoginEd(), isConnected()
- `YlsCallManager` — makeNewCall, answerCall, answerBusy (reject), hangUpCall, holdCall, unHoldCall, mute, sendDtmf, setCallStateCallback, setActionCallback
- Init must be in `Application#onCreate`
- `loginBlock` signature: (context, userName, password=signature, localeIp, localePort, remoteIp, remotePort, callback)
- Login return codes: 1 = can't connect, -5 = no response, 403 = bad signature, 405 = client disabled, 407 = account locked, 416 = IP blocked

### 4.3 iOS SDK
The iOS framework follows the same conceptual model (login with signature, call manager, callbacks) with Swift/Obj-C syntax. See SDK guide pages 37-55. The bridge contract in §4.1 stays identical — only the native implementation differs.

### 4.4 Login signature — where it comes from
- The app does NOT generate it
- App calls backend `POST /api/office_call/credentials`
- Backend returns: extension, signature, pbx_lan_ip/port, pbx_public_ip/port, access_mode
- The app passes these into the native `login` method
- For internal_only users, public IP fields are null — pass empty/0 for those

### 4.5 Connection path (internal vs anywhere)
- `loginBlock` accepts both a LAN address set and a public address set
- The SDK guide says: "at least one set must be filled in"
- Anywhere users → pass both; SDK uses whichever is reachable
- Internal-only users → pass LAN only

### 4.6 Incoming calls + push
- When the app is foregrounded, the SDK delivers incoming calls directly via callbacks
- When backgrounded/killed, the PBX sends a push notification (Firebase on Android, APNs on iOS)
- The push payload is handled and passed to `YlsCallManager.handlerPushMessage(...)` (Android)
- The app already has Firebase set up — reuse it; register the push token with the SDK via `setPushInfo` / `setPushToken`
- Android 11+: a background call requires a **foreground service** — the SDK guide explicitly notes this

### 4.7 Permissions
- Microphone (mandatory for any call)
- Android: foreground service permission, post-notifications (Android 13+)
- iOS: microphone usage description in Info.plist, background audio mode, VoIP/PushKit considerations for incoming calls

### 4.8 Call state model (Dart)
Define a clean enum: `idle, dialing, ringing, connecting, active, held, ended, failed`.
The native bridge maps the SDK's raw call states to this enum so the Dart UI stays simple.

---

## 5. Backend API Contracts (consumed — already specified in backend task file)

```
POST /api/office_call/credentials   (Bearer auth)
→ { extension, display_name, signature, pbx_lan_ip, pbx_lan_port,
    pbx_public_ip, pbx_public_port, access_mode, signature_expires_at }

GET /api/office_call/directory      (Bearer auth)
→ [ { user_id, display_name, extension }, ... ]
```

---

## 6. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`
>
> For every task: place files per the existing app's conventions (see §1). The task describes behavior, not location.

---

### Phase 0 — Setup & SDK Acquisition

#### `[TODO]` F.0 — Confirm prerequisites
- [ ] Backend `/api/office_call/credentials` and `/directory` endpoints are available (or being built in parallel)
- [ ] Download `linkus-sdk-x.x.x.aar` from the Yeastar GitHub repo (Android)
- [ ] Obtain the Linkus iOS framework from the Yeastar GitHub repo
- [ ] Confirm app min Android version is 8.0+ (SDK requirement)
- [ ] Confirm Firebase is set up and you can get an FCM token
- [ ] Confirm the existing chat module — where exactly the call button should appear, and how to get the chat participant's identity
- [ ] Record the SDK version numbers

**Definition of done:** SDK files in hand, prerequisites recorded in §10.

#### `[TODO]` F.1 — Try the official demo apps first
- The SDK guide references official demo apps + source on GitHub for Android and iOS
- Build and run BOTH demos against the company PBX before integrating
- This validates: PBX reachable, Linkus SDK enabled, signature flow works, a call actually connects
- Do NOT start the bridge until the demo apps successfully make a call

**Definition of done:** Official Android demo AND iOS demo each successfully place a call on the company PBX. This proves the PBX side works before you write any bridge code.

---

### Phase 1 — Android Native Bridge

#### `[TODO]` AND.1 — Import the AAR
- Add `linkus-sdk-x.x.x.aar` to the Android project where the app keeps native libs
- Add the flatDir repo and the implementation dependency per the SDK guide (build.gradle)
- Confirm the project's Java/Gradle versions are compatible (Java 11; the guide notes Gradle 6.5 / AGP 4.1.1 as tested — newer may need debugging)
- Build the Android project — confirm the AAR resolves

**Definition of done:** Android project builds with the AAR linked.

#### `[TODO]` AND.2 — SDK initialization
- Initialize the SDK in `Application#onCreate` (the existing app's Application class) via `YlsBaseManager.getInstance().initYlsSDK(...)`
- Use default config initially (iLBC codec, NC on) — custom config later if needed
- Initialization must happen exactly once

**Definition of done:** SDK initializes on app start without error.

#### `[TODO]` AND.3 — MethodChannel + EventChannel plugin
- Create the Android bridge that registers MethodChannel `office_call/methods` and EventChannel `office_call/events`
- Wire each method from the §4.1 contract to the corresponding Linkus SDK call
- Wire the SDK's callbacks (`setSdkCallback`, `setCallStateCallback`, `setActionCallback`) to emit EventChannel events per the §4.1 contract
- Map raw SDK call states → the clean state enum (§4.8)

**Definition of done:** Dart can call methods and receive events. Verified with simple log-only handlers.

#### `[TODO]` AND.4 — Login implementation
- Implement `login`: call `YlsLoginManager.getInstance().loginBlock(...)` with signature + LAN/public addresses
- Handle the login return codes (403 bad signature, 1 can't connect, etc.) → emit `error` events with clear messages
- Implement `isLoggedIn`, `logout`
- Emit `loginStateChanged` events

**Definition of done:** App can log into the SDK with a backend-provided signature. Login failures surface clear errors.

#### `[TODO]` AND.5 — Call operations
- Implement: `makeCall`, `answerCall`, `rejectCall` (answerBusy), `hangUp`, `hold`, `unhold`, `mute`, `setSpeaker`, `sendDtmf`
- Each maps to the corresponding `YlsCallManager` method
- Emit `callStateChanged` / `callEnded` / `incomingCall` events from the SDK callbacks

**Definition of done:** All call operations callable from Dart and produce correct events.

#### `[TODO]` AND.6 — Foreground service for background calls
- Implement a foreground service for calls running in the background
- Android 11+ requires a foreground service for background calls (SDK guide explicitly notes this)
- Start it when a call goes active; stop it when the call ends (the SDK provides `onStopMicroPhoneService` callback)
- Add the service + required permissions to AndroidManifest

**Definition of done:** A call continues correctly when the app is backgrounded. No Android service crash.

#### `[TODO]` AND.7 — Push notifications (Android)
- The app already has Firebase — get the FCM token
- Register it with the SDK via `setPushInfo("firebase", token, ...)`
- In the existing Firebase message handler, detect Linkus call pushes and route them to `YlsCallManager.handlerPushMessage(...)`
- This makes incoming calls work when the app is backgrounded/killed

**Definition of done:** An incoming office call rings the app even when backgrounded.

---

### Phase 2 — iOS Native Bridge

#### `[TODO]` IOS.1 — Import the framework
- Add the Linkus iOS framework to the iOS project where the app keeps native frameworks
- Link it in the Xcode project / Podfile as appropriate
- Build the iOS project — confirm the framework resolves

**Definition of done:** iOS project builds with the framework linked.

#### `[TODO]` IOS.2 — SDK initialization (iOS)
- Initialize the SDK per the iOS section of the SDK guide
- Once only, at app launch

**Definition of done:** SDK initializes on iOS app start.

#### `[TODO]` IOS.3 — MethodChannel + EventChannel plugin (iOS)
- Create the iOS bridge registering the SAME channel names and the SAME method/event contract as Android (§4.1)
- This is critical — the Dart side must not care which platform it runs on

**Definition of done:** Dart can call methods and receive events on iOS, identical contract to Android.

#### `[TODO]` IOS.4 — Login, call operations (iOS)
- Implement login (signature-based) and all call operations from §4.1
- Map iOS SDK call states to the same clean enum (§4.8)

**Definition of done:** All call operations work on iOS, behavior matches Android.

#### `[TODO]` IOS.5 — Push notifications (iOS / APNs + PushKit)
- iOS incoming calls typically use APNs; VoIP calls often need PushKit + CallKit for proper behavior
- Register the push token with the SDK
- Confirm the APNs certificate is bound on the PBX (backend/PBX side)
- Handle incoming-call push → route to the SDK
- Consider CallKit integration for native incoming-call UI (recommended for iOS; can be a sub-task)

**Definition of done:** Incoming office calls ring on iOS when backgrounded. CallKit decision documented.

---

### Phase 3 — Dart Layer

#### `[TODO]` D.1 — Dart bridge wrapper
- Build the Dart side that wraps the MethodChannel (typed Dart methods) and EventChannel (a broadcast Stream of typed events)
- Parse event payloads into Dart models
- This must be the ONLY Dart code that touches platform channels — everything above it is pure Dart

**Definition of done:** Dart code can call SDK operations and listen to a typed event stream, with no MethodChannel knowledge leaking upward.

#### `[TODO]` D.2 — API client + models
- Build the API client for `/api/office_call/credentials` and `/directory` — follow the app's existing API/networking pattern
- Create the models for credentials, directory entries, and call state
- Build a repository (or equivalent in the app's pattern) combining API + bridge

**Definition of done:** App can fetch credentials and directory, and reach the bridge through a clean abstraction.

#### `[TODO]` D.3 — Office call orchestration service
- Build the service that owns the whole call lifecycle:
  - Ensure SDK is initialized
  - Ensure logged in: if not, fetch credentials → SDK login
  - Handle signature expiry: on auth failure, re-fetch credentials and retry once
  - Expose: `startCall(extension)`, `answer()`, `reject()`, `hangUp()`, `toggleMute()`, `toggleHold()`, `toggleSpeaker()`, `sendDtmf(digit)`
  - Expose a stream of `CallState`

**Definition of done:** A single service encapsulates the whole call lifecycle. UI never touches the bridge directly.

#### `[TODO]` D.4 — State controller
- Build the controller (Riverpod or the app's existing state approach) that exposes call state to the UI
- Handle permission checks (microphone) before starting a call
- Drive navigation to call screens on state changes (e.g., incoming call → push incoming screen)

**Definition of done:** UI can observe call state reactively.

---

### Phase 4 — UI

#### `[TODO]` U.1 — Call button on chat
- Build the call button and place it in the existing chat screen (match the chat module's existing UI patterns)
- On tap:
  1. Resolve the chat participant → extension (via directory)
  2. If the participant has no extension → disable the button or show "Not available for calls"
  3. Otherwise → start the call flow, navigate to outgoing call screen

**Definition of done:** Call button visible on chat, disabled gracefully when participant has no extension.

#### `[TODO]` U.2 — Outgoing call screen
- Shows: callee name, extension, call status (dialing / ringing / connecting)
- Hang-up button
- Transitions to in-call screen when the call becomes active

**Definition of done:** Outgoing call screen reflects live state.

#### `[TODO]` U.3 — Incoming call screen
- Triggered by an `incomingCall` event
- Shows: caller name (resolve via directory if possible) + extension
- Answer and Reject buttons
- Must show even when the app was backgrounded (works with the push + foreground service)

**Definition of done:** Incoming calls present a full-screen answer/reject UI.

#### `[TODO]` U.4 — In-call screen
- Shows: party name, call timer, connection/quality indicator
- Controls: mute, hold/resume, speaker
- DTMF keypad — opens a dialpad, each digit sends a DTMF tone
- Hang-up button

**Definition of done:** In-call screen with all controls works during a live call.

#### `[TODO]` U.5 — Permissions + error states
- Request microphone permission before the first call; if denied, show a clear message
- Handle: not logged in, PBX unreachable, signature expired, call failed
- Every error path leads somewhere sensible — never a frozen screen

**Definition of done:** Permissions handled. All error states have UI.

---

### Phase 5 — Verification

#### `[TODO]` V.1 — Outgoing call (both platforms)
- From a chat, call another extension
- Verify: dialing → ringing → active → hang up
- Verify mute, hold/resume, speaker, DTMF all work
- Test on Android AND iOS

#### `[TODO]` V.2 — Incoming call (both platforms)
- Have another extension call the app
- Test app foregrounded → rings immediately
- Test app backgrounded → push wakes it, rings, full-screen incoming UI
- Test app killed → push wakes it
- Answer and reject both paths
- Android AND iOS

#### `[TODO]` V.3 — Connection modes
- Internal-only user on office WiFi → call works via LAN
- Anywhere user on mobile data / outside office → call works via public IP
- Internal-only user OUTSIDE office → call correctly fails with a clear message

#### `[TODO]` V.4 — Resilience
- Signature expiry → app re-fetches and recovers
- Network drop mid-call → handled gracefully
- Backgrounding mid-call → call continues (foreground service)
- Low-end Android device → acceptable call quality and UI responsiveness

#### `[TODO]` V.5 — Sign-off
- `flutter analyze` clean
- Both platforms tested for outgoing + incoming
- All call controls verified
- Decisions Log §10 updated

---

## 7. Anti-patterns (do NOT do these)

| Anti-pattern | Why wrong | Do instead |
|--------------|-----------|-----------|
| Putting AccessID/AccessKey in the app | Master credential leak | App only ever holds a per-extension signature from the backend |
| Skipping the official demo apps | You debug PBX + app issues at once, can't tell which is broken | Run the demos first — prove the PBX works |
| Different channel contracts on Android vs iOS | Dart code becomes platform-specific spaghetti | Identical MethodChannel/EventChannel contract on both |
| Re-initializing the SDK | The guide forbids it | Initialize once in Application/AppDelegate |
| No foreground service on Android | Background calls die on Android 11+ | Implement the foreground service |
| Call UI touching MethodChannel directly | Unmaintainable, untestable | UI → controller → service → bridge layering |
| Ignoring signature expiry | Calls suddenly fail after hours | Re-fetch credentials on auth failure, retry once |
| No microphone permission check | Call silently fails | Request + verify before every first call |
| Building bridge before demos pass | Wasted effort if PBX side is misconfigured | F.1 demos are a gate |
| Inventing a new file structure for this feature | Inconsistent with the rest of the app | Follow the existing app's conventions (§1) |

---

## 8. Definition of Mobile Complete

- [ ] Official Android + iOS demos placed a call on the company PBX (F.1)
- [ ] Android native bridge: init, login, all call ops, foreground service, push
- [ ] iOS native bridge: init, login, all call ops, push (CallKit decision documented)
- [ ] Identical channel contract on both platforms
- [ ] Dart bridge + service + controller layered cleanly
- [ ] Call button integrated into the chat module
- [ ] Outgoing, incoming, in-call screens complete
- [ ] Mute / hold / speaker / DTMF all work
- [ ] Incoming calls work foregrounded, backgrounded, killed — both platforms
- [ ] Internal vs anywhere connection modes verified
- [ ] Signature expiry recovery works
- [ ] Microphone permission + all error states handled
- [ ] All new code placed consistent with the existing app structure
- [ ] `flutter analyze` clean
- [ ] Decisions Log §10 complete

---

## 9. Open Questions for Architect

- Confirm exact Linkus SDK versions (Android .aar + iOS framework)
- Chat module: exact placement of the call button + how to get the participant's identity
- iOS: use CallKit for native incoming-call UI? (Recommended — better UX, but adds work)
- Should call history / CDR be shown in-app? (Currently OUT of scope — Phase 2)
- Min device specs to support for call-quality testing

---

## 10. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

### F.0 confirmations (fill in)
- [ ] Linkus SDK Android version: __________
- [ ] Linkus SDK iOS version: __________
- [ ] Backend endpoints ready: YES / NO
- [ ] Firebase FCM token obtainable: YES / NO
- [ ] Chat module call-button placement: __________
- [ ] CallKit on iOS: YES / NO

— End of Mobile Task File —
