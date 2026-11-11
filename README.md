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
| API and MCP | Not exposed locally by this upstream desktop release | The hosted API/MCP service is account-backed and rate-limited |
| Team spaces, hosted sharing, billing | Hosted service | Requires the upstream service/account |
| Optional remote inference | Explicit LAN endpoint | Must be configured and authenticated separately |

No local word, duration, speaker-count, retention, or subscription limit is
introduced by this package. Intel Macs are supported for the application where
upstream dependencies permit; upstream currently documents that local speaker
identification and voice fingerprints are unavailable on Intel because of its
ONNX Runtime dependency.

## Install with Nix

```sh
nix run "github:dryvist/nix-openwhispr?ref=v1.11.0"
```

### Standalone Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-openwhispr.url = "github:dryvist/nix-openwhispr?ref=v1.11.0";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-openwhispr,
      ...
    }:
    {
      homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          nix-openwhispr.homeManagerModules.default
          {
            programs.openwhispr = {
              enable = true;
              autoStart = true;
              notesDirectory = "/Users/alice/notes/openwhispr";
              openaiBaseUrl = "http://localhost:4000/v1";
            };
          }
        ];
      };
    };
}
```

### nix-darwin integration

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-openwhispr.url = "github:dryvist/nix-openwhispr?ref=v1.11.0";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-openwhispr,
      ...
    }:
    {
      darwinConfigurations."my-mac" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.alice = {
                imports = [ nix-openwhispr.homeManagerModules.default ];
                programs.openwhispr = {
                  enable = true;
                  autoStart = true;
                  notesDirectory = "/Users/alice/notes/openwhispr";
                  openaiBaseUrl = "http://localhost:4000/v1";
                };
              };
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

The launch agent starts the application's own named executable directly, so
privacy and background-item entries carry the application's name rather than a
shell or interpreter.

## Module options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `programs.openwhispr.enable` | boolean | `false` | Enable OpenWhispr and its Home Manager integration. |
| `programs.openwhispr.version` | string | `"latest"` | Upstream release version to package (`"latest"`, `"1.11.0"`, `"1.8.3"`). |
| `programs.openwhispr.package` | package | `openwhispr.packages.${system}.default` | Application package derivation. |
| `programs.openwhispr.models` | package | `openwhispr.packages.${system}.models` | Local models package linked into upstream cache paths. |
| `programs.openwhispr.modelBootstrap` | boolean | `true` | Link hash-pinned local Whisper, diarization, and semantic-search models into `~/.cache/openwhispr`. |
| `programs.openwhispr.autoStart` | boolean | `true` | Start OpenWhispr at user login via a macOS launchd agent. |
| `programs.openwhispr.launchdLabel` | string | `"com.dryvist.nix-openwhispr"` | Label identifier for the launchd agent plist. |
| `programs.openwhispr.localTranscriptionProvider` | `"whisper"` or `"parakeet"` | `"whisper"` | Local engine pre-warmed by OpenWhispr at startup (`LOCAL_TRANSCRIPTION_PROVIDER`). |
| `programs.openwhispr.whisperModel` | string | `"base"` | Pinned Whisper model name pre-warmed for local transcription (`LOCAL_WHISPER_MODEL`). |
| `programs.openwhispr.parakeetModel` | string | `"parakeet-tdt-0.6b-v3"` | Parakeet model pre-warmed when local transcription provider is parakeet (`PARAKEET_MODEL`). |
| `programs.openwhispr.notesDirectory` | null or string (absolute path) | `null` | Target directory where OpenWhispr writes markdown notes. When set, creates an out-of-store symlink from `~/Library/Application Support/open-whispr/notes` to this directory. Must be an absolute path. |
| `programs.openwhispr.openaiBaseUrl` | null or string | `null` | Base URL for OpenAI-compatible local model router (sets `OPENAI_BASE_URL`). |
| `programs.openwhispr.environment` | attribute set of strings | `{}` | Additional non-secret environment variables passed to the session and launchd agent. Do not place credentials or secrets here. |

## Runtime settings

OpenWhispr combines declarative Nix packaging with macOS-managed state:

- **Declarative (managed by Nix and Home Manager)**:
  - Application binary packaging and version pinning.
  - Hash-pinned baseline model cache layout in `~/.cache/openwhispr/`.
  - User launch agent lifecycle (`~/Library/LaunchAgents/com.dryvist.nix-openwhispr.plist`).
  - Session and launchd environment variables (`OPENWHISPR_CHANNEL`, `LOCAL_TRANSCRIPTION_PROVIDER`, `LOCAL_WHISPER_MODEL`, `PARAKEET_MODEL`, `OPENAI_BASE_URL`, and custom `environment`).
  - Target directory symlink for notes (`~/Library/Application Support/open-whispr/notes` -> `cfg.notesDirectory`).

- **One-time UI configuration (set once in OpenWhispr Settings)**:
  - **Local processing mode**: Open Settings and set Dictation, Meeting, and Audio Import transcription modes to **Local**. Upstream stores this in internal browser storage (IndexedDB/localStorage) without a declarative configuration interface.
  - **Save notes as files**: In Settings > Notes, enable **Save notes as files**. When enabled, OpenWhispr writes markdown notes to `~/Library/Application Support/open-whispr/notes`, which points to your configured `notesDirectory`.
  - **macOS system permissions**: Grant Microphone, Accessibility, Input Monitoring, and System Audio permissions in macOS System Settings when prompted on first use.

The package preserves and verifies the upstream Developer ID signature and
notarization; it does not replace them with an ad-hoc signature. `models.json`
records the helper and model provenance used by the pinned release.

Home Manager enables the pinned Whisper, diarization, and semantic-search
bootstrap by default. Parakeet and local LLM models remain owned by the
upstream model manager or the consuming `nix-ai`/`nix-darwin` configuration;
this package does not duplicate or scan the shared Hugging Face/MLX cache.

## Plan-boundary policy

Every locally implementable desktop capability is available without a package
quota: local transcription, local meeting processing, diarization, speaker
fingerprints, local notes/search, and locally configured agents. The upstream
Business and Enterprise plans also include managed cloud transcription, cloud
sync/mobile, hosted API/MCP, organization administration, SSO/SCIM, audit
logs, and retention controls. Those are proprietary account services, so this
repository neither claims to provide them locally nor attempts to bypass their
plans or rate limits.

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

Pull requests run on GitHub-hosted Linux and Apple Silicon runners. The release
workflow reserves the Apple Silicon artifact for a disposable Tart macOS VM on
the Mac Studio, using one-job JIT runner registration; this isolated runner
must be provisioned and accepted before a release can use its label. The Intel
compatibility artifact uses a GitHub-hosted Intel macOS runner. The self-hosted
label is restricted to this repository and trusted release refs. Any private
signing material is restricted to reviewed release environments. See
`docs/mac-studio-runner.md` and `docs/acceptance.md`.

## License and upstream provenance

The Nix integration in this repository is MIT licensed. The packaged
application and its bundled dependencies retain their upstream licenses; see
`docs/provenance.md` and the upstream release metadata.
