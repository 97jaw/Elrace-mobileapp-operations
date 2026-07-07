const fs = require('fs');

const content = \`# Face Anti-Spoofing (Liveness) --- Mobile \| Cursor
Task File

> **How to use this file:** Read it top to bottom before touching any
> code. This adds a liveness / anti-spoofing layer to the EXISTING face
> recognition feature in Site Management. Start at Task F.0 and work top
> to bottom. **F.0 is a HARD LEGAL GATE --- do not write feature code
> until it passes.**

> **File placement:** You own all file structure, naming, and placement
> decisions. Place new code consistent with the existing app's
> conventions and the existing face recognition feature's structure. The
> tasks describe WHAT to build and HOW it behaves, not WHERE files go.

------------------------------------------------------------------------

## 0. About This Work

You are extending the **existing face recognition feature** in the
**Site Management** module of a Flutter app for **Pandora Tech LLC**.

### The problem this solves

The current face recognition answers "is this the right person?" --- and
it works. But it has a critical hole: **it accepts a photo of a person
held up to the camera.** A laborer can cheat by showing a printed photo
or a photo on another phone screen. This was confirmed in testing.

### What this adds

A **liveness / anti-spoofing layer** that runs BEFORE recognition and
answers a different question: **"is this a real, live human --- or a
photo / screen / video?"**

### The use case context (important)

- The face capture is **UNATTENDED** --- a laborer uses a site tablet
  themselves; no foreman watching.
- Budget is **ZERO** --- no paid SDK. This uses free, open-source
  components only.
- The goal is NOT "perfect / bank-grade." The goal is: **make photo and
  screen cheating fail, make cleverer attacks hard and likely to be
  caught.**

### The solution --- a layered free approach

\`\`\` Laborer at the tablet │ ▼ LAYER 1 --- Silent liveness
(MiniFASNet, open-source model) Single-frame classify: live /
print-attack / replay-attack │ ├── spoof detected → BLOCK + warn │ ▼
live LAYER 2 --- Active challenge (Google ML Kit, already in the app)
Random action: blink / turn head / smile --- a photo can't do this │ ├──
challenge failed → retry, then flag │ ▼ passed LAYER 3 --- Face
recognition (the EXISTING feature --- unchanged) │ ▼ LAYER 4 --- Audit
trail (backend task file) Save photo + liveness score + GPS + device +
time; flag low-confidence \`\`\`

This task file covers **Layers 1, 2, and the integration**. Layer 4
(audit trail + HR review) is in the companion backend task file.

### Stack

- Flutter (existing app)
- **MiniFASNet** --- open-source silent anti-spoofing model
  (Silent-Face-Anti-Spoofing by Minivision). DUAL model setup.
- **Google ML Kit** --- face detection + landmarks (already in the app)
  --- for the active challenge
- TFLite (\`tflite_flutter\`) --- to run the MiniFASNet models on-device
- Riverpod --- state (or the app's existing approach)

------------------------------------------------------------------------

## 1. ⚠️ HARD GATE --- License Verification (F.0)

The MiniFASNet model comes from the open-source
**Silent-Face-Anti-Spoofing** project by Minivision. Open-source does
NOT automatically mean free for commercial use.

**Task F.0 below requires verifying the license BEFORE any other work.**
If the license does not permit commercial use, STOP and report --- do
not build on it. There are alternative open-source anti-spoofing models;
we would switch rather than risk a legal problem.

This is non-negotiable. F.0 is a gate, not a formality.

------------------------------------------------------------------------

## 2. Critical Rules (NEVER violate these)

  -----------------------------------------------------------------------
  Rule                           Reason
  ------------------------------ ----------------------------------------
  **F.0 license check passes     Legal risk. Hard gate.
  before ANY feature code**      

  **Liveness runs BEFORE         No point recognizing a photo. Liveness
  recognition**                  is the gate.

  **All processing on-device**   The model is \~2MB. Tablet may have weak
                                 internet. No AWS round-trip for
                                 liveness.

  **Never hard-block honest      A bad camera or poor light is not
  users permanently**            cheating. Failed checks → retry, then
                                 FLAG, not permanent block.

  **The challenge action must be A fixed action can be defeated with a
  RANDOM each time**             pre-recorded video.

  **Preprocessing must match the MiniFASNet expects a specific crop size
  model's training**             and format. Get it exact.

  **Log every liveness score**   Needed for tuning and for the audit
                                 trail.

  **Dual-model fusion**          Run both MiniFASNet variants, fuse the
                                 scores --- the project's recommended
                                 setup.

  **One commit per task**        Format: \`feat(anti-spoof):
                                 `<TASK_ID>`{=html}
                                 `<description>`{=html}\`

  **Follow existing app          Do not invent a parallel structure.
  conventions for file           
  placement**                    
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 3. Functional Knowledge

### 3.1 MiniFASNet --- what it is

- Open-source single-image face anti-spoofing classifier
- Input: a face crop at a specific size (the common variant uses 80×80;
  confirm exact size + scale per the model variant chosen in F.1)
- Output: a 3-class softmax → \[live, print-attack, replay-attack\]
- Two variants exist (e.g., MiniFASNetV2 and MiniFASNetV1SE). The
  project's recommended strong setup runs BOTH on two different
  scales/crops of the same face and FUSES the scores.
- Tiny (\~2MB each) --- runs fast on-device, even on a tablet

### 3.2 Dual-model fusion

- Run model A on its expected crop scale → score A
- Run model B on its expected crop scale → score B
- Fuse: sum or average the per-class probabilities, then take the argmax
- A face is "live" only if the fused result says live with confidence
  above a threshold
- This is more robust than a single model --- it is the project's own
  recommended approach

### 3.3 The MiniFASNet pipeline (per capture)

1.  ML Kit detects the face (already done by the existing feature) →
    bounding box
2.  Crop the face region with the specific margin/scale each MiniFASNet
    variant expects
3.  Resize to the model's input size, convert to the model's expected
    color format
4.  Run model A and model B
5.  Fuse scores → live / print-attack / replay-attack + confidence
6.  Decision: live with confidence ≥ threshold → pass; otherwise → spoof
    suspected

### 3.4 Layer 2 --- the active challenge (ML Kit, free)

After Layer 1 says "live", run a randomized challenge as a second
barrier: - Randomly pick ONE action: "Blink twice" / "Turn your head
left" / "Turn your head right" / "Look up" / "Smile" - ML Kit already
provides what's needed: \`leftEyeOpenProbability\`,
\`rightEyeOpenProbability\`, \`headEulerAngleY\` (yaw),
\`headEulerAngleX\` (pitch), \`smilingProbability\` - The app watches
the live ML Kit stream and confirms the requested action happened - A
printed photo cannot perform any action. A pre-recorded video cannot
perform the RIGHT RANDOM action on demand. - Give a short time window
(e.g., 5-7 seconds) to complete the challenge

### 3.5 Decision logic --- the full gate

\`\`\` Capture attempt: Run Layer 1 (MiniFASNet dual fusion) result =
print-attack OR replay-attack → SPOOF. Block this attempt. Warn. Allow
retry. result = live, confidence low → UNCERTAIN. Proceed to Layer 2 but
mark uncertain. result = live, confidence high → Proceed to Layer 2.

Run Layer 2 (random active challenge) challenge passed → Proceed to
Layer 3 (existing recognition) challenge failed → Retry the challenge
once with a NEW random action failed again → Allow the check-in BUT flag
it "liveness_failed" for HR review (do not permanently block --- could
be a bad camera / honest user)

Layer 3 (existing face recognition) runs as before.

Every attempt logs: layer1 scores, layer1 verdict, challenge given,
challenge result, final liveness verdict, recognition result. \`\`\`

### 3.6 Why "flag, don't block" on repeated failure

A hard permanent block punishes honest laborers when the tablet camera
is poor or lighting is bad. Flagging for HR review catches the cheater
(a human sees the suspicious record) without locking out the honest
worker. The audit trail (backend) is what makes flagging effective.

### 3.7 Thresholds

- MiniFASNet "live" confidence threshold --- start at a sensible default
  (e.g., 0.7 fused) and make it a single named constant, tunable
- Challenge time window --- start 6 seconds, tunable
- Log everything during the pilot so thresholds can be tuned from real
  data

------------------------------------------------------------------------

## 4. Tasks (work top to bottom)

> **Status legend:** \`\[TODO\]\` \`\[IN_PROGRESS\]\` \`\[DONE\]\`
> \`\[BLOCKED\]\` \`\[NEEDS_REVIEW\]\`

------------------------------------------------------------------------

### Phase 0 --- License Gate & Setup

#### \`\[TODO\]\` F.0 --- License verification ⚠️ HARD GATE --- DO THIS FIRST

- Locate the Silent-Face-Anti-Spoofing project on GitHub
  (minivision-ai/Silent-Face-Anti-Spoofing)
- Read the actual LICENSE file in that repository
- Also check the license of the specific model export you intend to use
  (e.g., the ONNX export on Hugging Face) --- confirm it inherits /
  states the upstream license
- Determine clearly: **does the license permit COMMERCIAL use in a
  closed-source product?**
- Write the finding into §9 Decisions Log with the exact license name
  and a one-line conclusion
- **DECISION GATE:**
  - License permits commercial use → proceed to F.1
  - License does NOT permit commercial use, OR is unclear/ambiguous →
    **STOP. Do not write any feature code.** Report to the architect.
    Recommend an alternative open-source anti-spoofing model with a
    clear permissive license (MIT / Apache-2.0). Wait for the
    architect's decision.

**Definition of done:** License status is definitively known and
recorded. Either a clear GO, or a STOP with an alternative recommended.
No feature code written before this is GO.

#### \`\[TODO\]\` F.1 --- Acquire and convert the models

- Only after F.0 = GO
- Obtain the two MiniFASNet model variants for the dual-model setup
- Convert / obtain them in TFLite format for on-device Flutter use (ONNX
  exports exist; convert ONNX→TFLite, or use existing TFLite
  conversions)
- Record for each model: variant name, input size, expected crop scale,
  color format, output classes, file size, SHA256
- Bundle both model files as app assets (place per the app's asset
  conventions)
- Add \`tflite_flutter\` to dependencies if not already present

**Definition of done:** Both TFLite models bundled. Their exact input
specs recorded in §9.

#### \`\[TODO\]\` F.2 --- Confirm integration points

- Confirm the existing face recognition feature's capture flow --- where
  Layer 1 + 2 will be inserted (BEFORE recognition)
- Confirm the existing ML Kit setup exposes: eye-open probabilities,
  head Euler angles, smiling probability
- Confirm the Add Timesheet / attendance capture screen where this all
  runs
- Record findings in §9

**Definition of done:** Integration points confirmed.

------------------------------------------------------------------------

### Phase 1 --- Layer 1: Silent Liveness (MiniFASNet)

#### \`\[TODO\]\` L1.1 --- MiniFASNet preprocessing

- Build the preprocessing for each model variant:
  - Take the ML Kit face bounding box
  - Apply the specific crop margin/scale that variant expects (the two
    variants use different scales --- this is the point of dual-model)
  - Resize to the model's input size
  - Convert to the model's expected color format and value range
- Get this EXACT --- wrong preprocessing makes the model output
  meaningless
- Reference the Silent-Face-Anti-Spoofing project's preprocessing code
  as the source of truth

**Definition of done:** Preprocessing produces correctly-shaped,
correctly-scaled input for each variant. Unit test with a sample image.

#### \`\[TODO\]\` L1.2 --- MiniFASNet inference (dual model)

- Load both TFLite models --- lazy load once, cache the interpreters
- Method: run model A on its crop → 3-class scores; run model B on its
  crop → 3-class scores
- Fuse: average (or sum) the per-class probabilities across both models
- Return: fused verdict (live / print-attack / replay-attack) + fused
  confidence
- Performance: total dual inference should be fast (target \< 300ms on
  the tablet)

**Definition of done:** Dual-model inference returns a fused verdict.
Tested: a real face → live; a photo of a face → print-attack or
replay-attack.

#### \`\[TODO\]\` L1.3 --- Layer 1 verdict logic

- Wrap L1.2 into a clean liveness-check result:
  - \`live\` (high confidence) → pass
  - \`live\` (low confidence) → pass but mark uncertain
  - \`print-attack\` or \`replay-attack\` → spoof
- Threshold = a single named constant, tunable
- Log the raw scores + verdict for every call

**Definition of done:** Layer 1 returns a clear pass / spoof / uncertain
result with logged scores.

------------------------------------------------------------------------

### Phase 2 --- Layer 2: Active Challenge

#### \`\[TODO\]\` L2.1 --- Challenge definitions

- Define the set of challenge actions: blink twice, turn head left, turn
  head right, look up, smile
- For each, define the ML Kit signal and the threshold that confirms it:
  - Blink: eye-open probability drops below X then rises above Y, twice
  - Turn left/right: \`headEulerAngleY\` crosses a threshold
  - Look up: \`headEulerAngleX\` crosses a threshold
  - Smile: \`smilingProbability\` above a threshold
- Each challenge has a clear "completed" detection

**Definition of done:** Each challenge action is detectable from the ML
Kit stream.

#### \`\[TODO\]\` L2.2 --- Challenge runner

- Randomly select ONE challenge action per attempt (random is essential
  --- defeats pre-recorded video)
- Show the instruction clearly on screen ("Please blink twice")
- Watch the live ML Kit stream for the action within a time window
  (start 6s, tunable)
- Return: passed / failed (timeout or wrong)
- On fail: allow ONE retry with a NEW random action
- On second fail: return "challenge failed" (the integration layer
  decides to flag, not block)

**Definition of done:** Challenge runner picks random actions, detects
completion, handles timeout + one retry.

------------------------------------------------------------------------

### Phase 3 --- Integration

#### \`\[TODO\]\` I.1 --- The combined liveness gate

- Build the orchestration that runs the full gate per §3.5:
  1.  Layer 1 (MiniFASNet dual) --- spoof → block this attempt + warn +
      allow retry
  2.  Layer 2 (random challenge) --- fail twice → flag
  3.  Hand off to the EXISTING face recognition (Layer 3) only after
      liveness passes
- Liveness runs BEFORE recognition --- recognition code stays unchanged,
  it just runs later in the flow
- Produce a combined result object: liveness verdict, scores, challenge
  result, plus the recognition result
- Every attempt fully logged

**Definition of done:** The full gate runs in order. Recognition only
runs on faces that passed (or were flagged through) liveness.

#### \`\[TODO\]\` I.2 --- Wire into the attendance capture flow

- Insert the combined gate into the existing Add Timesheet / attendance
  face capture
- The existing capture UI stays; liveness steps are added before the
  recognition/confirm step
- The flagged-but-allowed path still completes the check-in (with the
  flag attached --- see backend task file)

**Definition of done:** Attendance capture now runs liveness → challenge
→ recognition end to end.

#### \`\[TODO\]\` I.3 --- Send liveness data to backend

- When a check-in is recorded, include the liveness data for the audit
  trail (consumed by the backend task file):
  - Layer 1 fused scores + verdict
  - Challenge given + result
  - Final liveness verdict (passed / flagged)
  - The captured photo (for HR review)
- Use whatever attendance-submission endpoint the app already calls; add
  these fields per the backend task file's contract

**Definition of done:** Liveness data + photo travel to the backend with
the check-in.

------------------------------------------------------------------------

### Phase 4 --- UX

#### \`\[TODO\]\` U.1 --- Spoof warning UI

- When Layer 1 detects a spoof: clear, firm message --- "Spoofing
  detected. Please look at the camera as yourself, without using a photo
  or another screen."
- Allow the laborer to retry
- Do not be ambiguous --- the laborer should understand the system saw
  the cheat

**Definition of done:** Spoof detection shows a clear warning + retry.

#### \`\[TODO\]\` U.2 --- Challenge UI

- Clear, simple instruction display for the active challenge ("Please
  blink twice", "Turn your head to the left")
- A visible countdown / progress for the time window
- Large text --- laborers may not be tech-savvy; keep it simple and
  visual
- Success feedback when the action is detected

**Definition of done:** Challenge UI is clear and easy for a
non-technical laborer.

#### \`\[TODO\]\` U.3 --- Flagged-attempt UX

- When liveness fails twice but the check-in is allowed (flagged):
  - Do NOT tell the laborer "you have been flagged" (that just teaches a
    cheater what to avoid)
  - The check-in completes normally from the laborer's view
  - The flag is silent --- it goes to HR review in the backend
- When liveness clearly fails as a spoof attempt, the warning (U.1) is
  appropriate; the silent-flag is for the ambiguous repeated-failure
  case

**Definition of done:** Flagged check-ins complete normally for the
user; the flag is silent.

#### \`\[TODO\]\` U.4 --- Deterrent notice

- Show a small, calm notice on the capture screen: "Your photo is
  recorded and reviewed for attendance verification."
- This is a deterrent --- a laborer who knows a human reviews the photo
  is far less likely to try a photo trick
- Keep it non-threatening, just factual

**Definition of done:** A visible, calm deterrent notice is on the
capture screen.

------------------------------------------------------------------------

### Phase 5 --- Verification

#### \`\[TODO\]\` V.1 --- Spoof attack tests

Test with the tablet, against employee 4255 (you) and a colleague: -
Real live face → passes Layer 1, passes challenge → check-in - Printed
photo held to camera → Layer 1 detects print-attack → blocked - Photo on
another phone screen → Layer 1 detects replay-attack → blocked - Video
of a person on another phone → Layer 1 may pass, but Layer 2 random
challenge → fails → flagged - Real person but refuses the challenge →
flagged after two fails

#### \`\[TODO\]\` V.2 --- Honest-user tests

- Real laborer, poor lighting → should still pass or at worst flag (not
  hard-block)
- Real laborer, slightly off-angle → should pass
- Confirm honest users are not punished

#### \`\[TODO\]\` V.3 --- Performance

- Full gate (Layer 1 dual + Layer 2 + existing recognition) on the
  actual site tablet
- Confirm it is acceptably fast and the UI stays responsive
- Confirm models are cached (not reloaded each attempt)

#### \`\[TODO\]\` V.4 --- Sign-off

- \`flutter analyze\` clean
- All spoof types tested
- Honest users not blocked
- Liveness scores logged
- Decisions Log §9 complete

------------------------------------------------------------------------

## 5. Anti-patterns (do NOT do these)

  -----------------------------------------------------------------------
  Anti-pattern                Why wrong             Do instead
  --------------------------- --------------------- ---------------------
  Building before F.0 license Legal risk on a       F.0 is a hard gate
  check                       commercial product    

  Running recognition before  You'd recognize a     Liveness gates
  liveness                    photo                 recognition

  Fixed (non-random)          A pre-recorded video  Random action every
  challenge action            defeats it            attempt

  Hard permanent block on     Punishes honest users Retry, then silently
  liveness failure            with bad cameras      flag

  Sending every frame to AWS  Latency, data cost,   On-device; model is
  for liveness                fails on weak site    tiny
                              internet              

  Telling the user "you are   Teaches the cheater   Flag silently; HR
  flagged"                    what to avoid         sees it

  Single MiniFASNet model     Less robust           Dual-model fusion
                                                    (project's
                                                    recommended setup)

  Wrong preprocessing         Model output becomes  Match the project's
  crop/scale                  meaningless           preprocessing exactly

  Skipping score logging      Cannot tune           Log every attempt
                              thresholds            

  Claiming this is bank-grade It is not iBeta       Be honest: strong for
                              certified             labor attendance, not
                                                    bank-grade
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 6. Honest Limitations (acknowledge these)

- This is NOT iBeta certified and NOT bank-grade.
- It reliably stops printed-photo and phone-screen attacks (the common
  laborer cheat).
- A well-prepared video replay timed against the random challenge is
  harder to stop technically --- that case relies on the audit trail
  (backend) catching it after the fact.
- Deepfakes are out of reach of this free solution --- but a laborer at
  a site tablet is not producing deepfakes.
- The audit trail (backend task file) is what covers the gap. Layers 1-2
  reduce cheating; Layer 4 catches the rest.

This is a strong, honest, free solution for labor attendance. It is not,
and does not claim to be, bank security.

------------------------------------------------------------------------

## 7. Definition of Mobile Complete

- [ ] F.0 license verified --- commercial use confirmed (or alternative
  adopted)
- [ ] Dual MiniFASNet models bundled and running on-device
- [ ] Layer 1 silent liveness working --- detects print + replay attacks
- [ ] Layer 2 random active challenge working
- [ ] Combined gate: liveness → challenge → existing recognition
- [ ] Integrated into the attendance capture flow
- [ ] Liveness data + photo sent to backend for audit
- [ ] Spoof warning, challenge UI, silent flagging, deterrent notice all
  done
- [ ] Honest users not hard-blocked
- [ ] All spoof types tested on the actual tablet
- [ ] Scores logged for tuning
- [ ] \`flutter analyze\` clean
- [ ] Decisions Log §9 complete

------------------------------------------------------------------------

## 8. Open Questions for Architect

- F.0 outcome --- is the MiniFASNet license commercial-safe? (If not,
  which alternative?)
- Confirm the tablet model --- for performance expectations
- Threshold tuning --- who reviews the pilot logs and sets final
  thresholds?
- How long should flagged check-ins be retained for HR review?

------------------------------------------------------------------------

## 9. Decisions Log

\`\`\` \[YYYY-MM-DD\] TASK_ID --- Decision: `<what>`{=html}. Rationale:
`<why>`{=html}. \`\`\`

### F.0 --- License finding (REQUIRED)

- [ ] License name: \_\_\_\_\_\_\_\_\_\_
- [ ] Commercial use permitted: YES / NO / UNCLEAR
- [ ] Conclusion: GO / STOP
- [ ] If STOP --- alternative model recommended: \_\_\_\_\_\_\_\_\_\_

### F.1 --- Model specs

- [ ] Model A variant + input size + scale: \_\_\_\_\_\_\_\_\_\_
- [ ] Model B variant + input size + scale: \_\_\_\_\_\_\_\_\_\_

--- End of Anti-Spoofing Mobile Task File --- \`;

fs.writeFileSync('/home/claude/Face_AntiSpoofing_Mobile_TASKS.md',
content); console.log('Anti-spoofing mobile task file created. Size:',
content.length, 'chars');
