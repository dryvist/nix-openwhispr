# Isolated Mac Studio release runner

The release workflow is designed to package inside a disposable macOS VM rather
than on the Studio's host operating system. Use the [community-supported Tartelet fleet manager](https://github.com/shapehq/tartelet)
on the Studio, backed by [Tart](https://github.com/cirruslabs/tart) and GitHub's one-job JIT runner configuration
endpoint. Tartelet is the lifecycle owner; this repository only supplies the
runner label in the workflow. The runner is not considered enabled until the
base-VM acceptance gate below has completed with retained evidence.

1. Tartelet obtains a short-lived GitHub App-backed runner credential.
2. It requests a repository-scoped JIT configuration with the restricted
   `openwhispr-macos` label.
3. It clones a clean, credential-free base macOS VM snapshot.
4. The guest registers, runs exactly one job, removes its runner registration,
   and shuts down.
5. Tartelet deletes the VM before requesting another job.

The base VM must contain the matching GitHub Actions runner binary and the
Tartelet guest integration. It must not contain a GitHub
token, SSH key, cloud credential, homelab credential, personal home-directory
share, or reusable runner registration. Rebuild the snapshot after macOS and
runner updates, then test it with a disposable repository before enabling the
release label.

## Host configuration

Install and configure Tartelet on the Studio using its native macOS UI/config
path. The GitHub App private key is the only secret boundary; obtain it from
the approved host secret broker and keep it in the macOS Keychain or Tartelet's
documented protected storage. Do not place it in a plist, command-line
argument, Nix file, or VM image.

The runner group must be restricted to this repository. Pull requests from
forks must not be allowed to select the self-hosted label. The release
workflow's trusted-ref gate remains required even though the VM is disposable.

## Base VM acceptance gate

Before enabling the label, verify on the Studio:

```sh
tart list
```

Confirm through Tartelet that the guest can reach GitHub, can start and remove one JIT runner,
cannot read the host home directory, and is destroyed after the job. Keep the
output of `tart list`, the runner registration audit event, and the VM cleanup
event with the release evidence; never retain the JIT config.
