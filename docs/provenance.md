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

`models.json` is the local-bootstrap manifest consumed by the Nix model package. It pins SHA-256 values
for the diarization segmentation model, speaker-embedding model, VAD model,
semantic-search model/tokenizer, Qdrant helper, and sherpa-onnx helper release.
Each entry records the declared license when the upstream artifact provides one;
where the release does not declare model-specific terms, that uncertainty is
recorded explicitly rather than inferred.
Home Manager links the resulting Nix store paths into the upstream cache layout,
so first use does not depend on an unverified runtime download. Parakeet and
LLM model caches remain upstream/consumer-owned.

## Update procedure

1. Select a concrete upstream release tag.
2. Record the Apple Silicon and Intel asset URLs and SHA-256 hashes.
3. Confirm the application release contains local transcription, meeting
   capture, diarization, speaker profiles, and semantic search support.
4. Run `nix flake check --all-systems` and the publication guard.
5. Build and inspect both Darwin application bundles before publishing.
6. Recalculate every `models.json` digest from the exact URL and verify the
   upstream release's model/helper downloader still uses those artifacts.
