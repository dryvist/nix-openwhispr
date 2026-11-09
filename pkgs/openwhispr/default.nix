{
  lib,
  stdenvNoCC,
  undmg,
  fetchurl,
  version ? "latest",
}:
let
  inherit (stdenvNoCC.hostPlatform) system;
  manifest = builtins.fromJSON (builtins.readFile ../../release.json);
  selectedVersion =
    if version == null || version == "latest" then manifest.upstreamVersion else version;
  asset =
    manifest.releases.${selectedVersion}.${system}
      or (if selectedVersion == manifest.upstreamVersion then manifest.releaseAssets.${system} else null);
in
assert lib.assertMsg (
  asset != null
) "Unsupported OpenWhispr version: ${selectedVersion} for system: ${system}";
stdenvNoCC.mkDerivation {
  pname = "openwhispr";
  version = selectedVersion;
  src = fetchurl {
    inherit (asset) url hash;
  };
  nativeBuildInputs = [ undmg ];
  dontPatchShebangs = true;
  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    test -d OpenWhispr.app
    # ponytail: no --acl — copied ACLs deny fixupPhase's chmod (EPERM); rsrc/xattrs still preserved
    /usr/bin/ditto --rsrc --extattr OpenWhispr.app "$out/Applications/OpenWhispr.app"
  '';
  meta = {
    description = "Privacy-first local voice dictation, meeting transcription, and notes";
    homepage = "https://openwhispr.com/";
    changelog = "https://github.com/OpenWhispr/openwhispr/releases/tag/v${selectedVersion}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "OpenWhispr";
  };
}
