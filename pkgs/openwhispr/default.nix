{
  lib,
  stdenvNoCC,
  undmg,
  fetchurl,
  system,
}:
let
  release = builtins.fromJSON (builtins.readFile ../../release.json);
  asset = release.releaseAssets.${system};
in
assert lib.assertMsg (asset != null) "Unsupported system: ${system}";
stdenvNoCC.mkDerivation {
  pname = "openwhispr";
  version = release.upstreamVersion;
  src = fetchurl {
    inherit (asset) url hash;
  };
  nativeBuildInputs = [ undmg ];
  dontPatchShebangs = true;
  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    test -d OpenWhispr.app
    /usr/bin/ditto --rsrc --extattr --acl OpenWhispr.app "$out/Applications/OpenWhispr.app"
  '';
  meta = {
    description = "Privacy-first local voice dictation, meeting transcription, and notes";
    homepage = "https://openwhispr.com/";
    changelog = "https://github.com/OpenWhispr/openwhispr/releases/tag/${release.upstreamTag}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "OpenWhispr";
  };
}
