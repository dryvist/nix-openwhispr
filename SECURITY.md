# Security policy

Please report suspected security issues privately to the repository
maintainers rather than opening a public issue with exploit details.

This project packages a pre-built desktop application. Review the pinned
upstream release, fixed hashes, bundled native helpers, and model provenance
before approving version updates.

Pull-request workflows must not receive signing keys, notarization credentials,
cloud credentials, or homelab credentials. Release environments are separate
from ordinary CI and require trusted refs and review.
