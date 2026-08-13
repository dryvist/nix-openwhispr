# nix-openwhispr

This repository owns reproducible Nix packaging and macOS lifecycle
integration for the upstream OpenWhispr application.

## Boundaries

- Keep local processing usable without an account or hosted-service credential.
- Do not add local word, duration, speaker-count, retention, or subscription
  limits.
- Keep cloud, team, billing, and hosted API behavior explicitly service-backed.
- Infrastructure belongs in the owning OpenTofu repository; guest configuration
  belongs in the owning Ansible repository.
- Never commit credentials, private host details, local-machine paths, or
  private project identifiers.

## Validation

```sh
nix flake check --all-systems --no-build
nix fmt -- --check
./scripts/check-publication.sh
```

Every change uses a feature branch and an isolated worktree. Release jobs are
trusted-ref only and must not expose long-lived credentials to pull requests.
