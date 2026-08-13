# Provenance and supply chain

The package consumes hash-pinned release assets from the upstream OpenWhispr
GitHub release service. The version and fixed hashes are recorded in
`release.json`; changing them requires a reviewed update to the source URL,
hash, and release notes.

The packaged application includes native helpers and model assets distributed
by upstream. Their licenses remain upstream-owned and must be reviewed from
the corresponding release source before a version update is merged.

The Nix derivation uses `sourceProvenance = binaryNativeCode` because the
release asset is a pre-built application bundle. Release workflows publish
checksums and GitHub build provenance for the artifacts produced here.

## Update procedure

1. Select a concrete upstream release tag.
2. Record the Apple Silicon and Intel asset URLs and SHA-256 hashes.
3. Confirm the application release contains local transcription, meeting
   capture, diarization, speaker profiles, and semantic search support.
4. Run `nix flake check --all-systems` and the publication guard.
5. Build and inspect both Darwin application bundles before publishing.
