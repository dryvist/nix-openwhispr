# Fixture check for the renderer settings apply script.
{
  pkgs,
  rendererSettings,
}:
let
  settings =
    rendererSettings.mkInferenceSettings {
      scopes = {
        dictationCleanup = {
          url = "http://127.0.0.1:4100/v1";
          model = "fast";
        };
        noteFormatting = null;
      };
      transcription = {
        url = "http://127.0.0.1:4100/v1";
        model = "speech";
      };
    }
    // {
      noteLabel = "Notiz ✓";
      "label✓" = "x";
    };
  # Exit status of the running check: 0 means running, 1 means not running.
  apply = rendererSettings.mkApply {
    inherit settings;
    isRunning = "${pkgs.coreutils}/bin/false";
  };
  running = rendererSettings.mkApply {
    inherit settings;
    isRunning = "${pkgs.coreutils}/bin/true";
  };
  python = pkgs.python3.withPackages (p: [ p.plyvel ]);
in
assert !(settings ? noteFormattingMode);
pkgs.runCommand "openwhispr-settings-seed" { nativeBuildInputs = [ python ]; } ''
  python3 -I ${./settings-seed.py} \
    ${apply}/bin/openwhispr-apply-settings \
    ${running}/bin/openwhispr-apply-settings
  touch $out
''
