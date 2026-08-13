# nix-openwhispr

Reproducible Nix packaging and macOS lifecycle integration for
[OpenWhispr](https://github.com/OpenWhispr/openwhispr), a local-first voice
dictation, meeting transcription, speaker identification, and notes application.

This repository packages the upstream application; it does not fork or
reimplement the application. The default path is local processing on macOS.

## What is available locally

The upstream application provides local speech-to-text, meeting capture,
speaker diarization, voice fingerprints, notes, semantic search, local
reasoning, audio import, and a menu-bar/tray application. Local processing is
not subject to the hosted service's word quota.

| Capability | Default path | Boundary |
| --- | --- | --- |
| Dictation and translation | Local models | Uses the Mac's local resources |
| Meeting transcription | Local models | Requires microphone/system-audio permissions |
| Speaker labels and voice fingerprints | Local ONNX models | Best supported on Apple Silicon |
| Notes and semantic search | Local SQLite/vector data | Search quality depends on downloaded models |
| AI agent | Local model or explicit provider | Provider credentials are user-selected |
| Local MCP access | Read local notes while the app runs | Hosted API/MCP synchronization remains account-backed |
| Team spaces, hosted sharing, billing | Hosted service | Requires the upstream service/account |
| Optional remote inference | Explicit LAN endpoint | Must be configured and authenticated separately |

No local word, duration, speaker-count, retention, or subscription limit is
introduced by this package. Intel Macs are supported for the application where
upstream dependencies permit; upstream currently documents that local speaker
identification and voice fingerprints are unavailable on Intel because of its
ONNX Runtime dependency.

## Install with Nix

```sh
nix run github:dryvist/nix-openwhispr
```

For a Home Manager configuration:

```nix
{
  inputs.nix-openwhispr.url = "github:dryvist/nix-openwhispr";

  outputs = { nix-openwhispr, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      modules = [
        nix-openwhispr.homeManagerModules.default
        {
          programs.openwhispr = {
            enable = true;
            autoStart = true;
          };
        }
      ];
    };
  };
}
```

The module installs the application and manages a user launch agent. The
application's own menu bar controls remain available independently of the
launch agent.

The upstream application owns its menu-bar item and runtime model lifecycle.
This integration selects the local transcription engine and model through
native environment configuration and links hash-pinned baseline models into
the cache paths the upstream application actually reads. The package preserves
and verifies the
upstream Developer ID signature and notarization; it does not replace them
with an ad-hoc signature. `models.json` records the helper and model provenance
used by the pinned release.

Home Manager enables the pinned Whisper, diarization, and semantic-search
bootstrap by default. Parakeet and local LLM models remain owned by the
upstream model manager or the consuming `nix-ai`/`nix-darwin` configuration;
this package does not duplicate or scan the shared Hugging Face/MLX cache.

## First-run permissions

macOS will request microphone, input monitoring, accessibility, and system
audio permissions as features are used. Grant only the permissions required
for the workflows you enable. Verify the installed bundle and launch state with:

```sh
nix run .#verify-local -- "$HOME/Applications/OpenWhispr.app"
```

## Optional homelab routing

Remote inference, vector storage, backups, and MCP/API gateways are optional
extensions. They belong in the owning infrastructure and application
repositories, not in this public client package. A future deployment should
provision infrastructure through OpenTofu, configure services through Ansible,
obtain credentials through OpenBao, and expose only authenticated LAN routes.

The local client must remain fully useful when every remote service is offline.
No recording, transcript, or voice profile is uploaded unless the user
explicitly selects a remote route.

## Development and release

```sh
nix develop
nix flake check --all-systems
nix fmt -- --fail-on-change
./scripts/check-publication.sh
```

Pull requests run on GitHub-hosted Linux runners for static checks. Trusted
release jobs build the Apple Silicon artifact inside a disposable Tart macOS
VM on the Mac Studio, with a one-job JIT runner registration; the Intel
compatibility artifact uses a GitHub-hosted Intel macOS runner. The self-hosted
label is restricted to this repository and trusted release refs. Any private
signing material is restricted to reviewed release environments. See
`docs/mac-studio-runner.md` and `docs/acceptance.md`.

## License and upstream provenance

The Nix integration in this repository is MIT licensed. The packaged
application and its bundled dependencies retain their upstream licenses; see
`docs/provenance.md` and the upstream release metadata.
