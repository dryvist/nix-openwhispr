# Apple Silicon acceptance protocol

The repository checks source, Nix evaluation, and bundle structure in CI. The
following workflows require a real logged-in Apple Silicon macOS session
because microphone, system-audio, accessibility, input-monitoring, Keychain,
and menu-bar behavior cannot be proved by a Linux evaluator.

Record the date, macOS version, OpenWhispr version, selected local models, and
the exact commands used. A failed item is evidence of a release gap; do not
mark it passed because the application opened.

## Install and lifecycle

```sh
nix run github:dryvist/nix-openwhispr
nix run github:dryvist/nix-openwhispr#verify-local
```

- [ ] The package hash and bundle identifier match the release metadata.
- [ ] The first-run permission prompts are understood and only the required
      microphone, input-monitoring, accessibility, and system-audio permissions
      are granted.
- [ ] Home Manager activation installs the application and launchd agent.
- [ ] A logout/login starts the app in the menu bar without opening an
      unwanted foreground window.
- [ ] The upstream menu-bar item can open the panel, start dictation, and
      start/stop meeting capture.
- [ ] Killing the process causes launchd to restart it; an intentional stop
      remains stopped until the user starts it again.

## Local dictation and meetings

- [ ] With cloud credentials absent and the network route disabled, a local
      dictation produces a transcript.
- [ ] A meeting capture records microphone and system audio after the user
      grants both permissions.
- [ ] The meeting transcript contains speaker labels from local diarization.
- [ ] A speaker fingerprint can be enrolled, then recognized in a later
      recording without a hosted account.
- [ ] A long recording crosses the hosted quota boundary without a package-
      imposed word, duration, speaker-count, retention, or entitlement failure.
- [ ] Semantic note search returns a relevant result with the local embedding
      model and local vector database.
- [ ] Local notes and the local agent remain usable with all remote routes
      disabled.

## Optional remote routing

- [ ] An explicitly configured authenticated LAN inference route works.
- [ ] Removing or blocking that route returns the client to local operation;
      recordings and transcripts are not silently uploaded.
- [ ] Optional API/MCP endpoints are reachable only when explicitly enabled and
      authenticated.

## Intel and recovery

- [ ] On an Intel Mac, the application starts and local transcription behavior
      is recorded.
- [ ] Intel speaker identification/fingerprinting is reported as unavailable
      when the upstream ONNX limitation applies; it is never reported as
      silently working.
- [ ] An upgrade preserves local notes, fingerprints, and model caches.
- [ ] Removing the application bundle and reinstalling from the same pinned
      release leaves the user data and recovery path intact.
- [ ] A failed model download is rejected by SHA-256 verification and can be
      retried without leaving a partial model treated as valid.

The checklist is intentionally manual. Until a run is recorded against a real
Apple Silicon Mac, these items remain unverified rather than being represented
as CI-passed behavior.

## Current evidence

As of 2026-08-13, the pinned Apple Silicon application package at
`/nix/store/y05ixyq29fj39d6fz7zxgw8kw34pz8fd-openwhispr-1.8.3` passed strict
nested-code signature verification and Gatekeeper assessment. Its bundle
reports identifier `com.gizmolabs.openwhispr`, the upstream Developer ID
certificate, Team ID `T832773L2J`, and a stapled notarization ticket. The Nix
model package also builds from the hash-pinned manifest and installs the
expected local cache layout.

The packaged application was also started hidden in a logged-in Apple Silicon
session and remained running. That proves launchability only; the accessibility
tree was unavailable to automation, so this is not evidence that a menu-bar
control, permission prompt, or capture workflow passed.

The interactive permission, menu-bar, dictation, meeting, speaker-fingerprint,
and recovery items above remain unverified. They require a real logged-in
Apple Silicon session; opening the application or passing a non-interactive
bundle check is not sufficient evidence.
