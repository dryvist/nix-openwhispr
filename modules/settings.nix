# Declarative renderer settings for OpenWhispr.
#
# OpenWhispr keeps its model settings in renderer localStorage and reads no
# runtime file or variable for them. mkApply returns a script that writes the
# given keys into that store while the app is closed. The module and the
# fixture check both build their script with this function.
{
  lib,
  pkgs,
}:
let
  # Store key prefix of each inference scope, from upstream src/config/inferenceScopes.ts.
  scopePrefixes = {
    dictationCleanup = "cleanup";
    noteFormatting = "noteFormatting";
    dictationAgent = "dictationAgent";
    chatIntelligence = "chatAgent";
    dictationTranslation = "translation";
  };
in
{
  inherit scopePrefixes;

  mkApply =
    {
      settings,
      isRunning ? "/usr/bin/pgrep -x OpenWhispr",
    }:
    let
      python = pkgs.python3.withPackages (p: [ p.plyvel ]);
      settingsFile = pkgs.writeText "openwhispr-settings.json" (builtins.toJSON settings);
    in
    pkgs.writeShellApplication {
      name = "openwhispr-apply-settings";
      runtimeInputs = [ python ];
      text = ''
        if [ "$#" -ne 1 ]; then
          echo "usage: openwhispr-apply-settings LEVELDB_DIR" >&2
          exit 2
        fi
        db=$1
        if [ ! -f "$db/CURRENT" ]; then
          echo "openwhispr settings: skipped, settings store not found; start OpenWhispr once, quit it, and run: $0 '$db'"
          exit 0
        fi
        set +e
        ${isRunning} >/dev/null 2>&1
        running=$?
        set -e
        if [ "$running" -eq 0 ]; then
          echo "openwhispr settings: skipped, OpenWhispr is running; quit it and run: $0 '$db'"
          exit 0
        elif [ "$running" -ne 1 ]; then
          echo "openwhispr settings: skipped, could not check whether OpenWhispr is running"
          exit 0
        fi
        if ! python3 -I ${./settings.py} "$db" ${settingsFile}; then
          echo "openwhispr settings: failed, store unchanged" >&2
        fi
      '';
    };

  # Settings that select a self-hosted OpenAI-compatible endpoint for each scope,
  # plus speech-to-text when `transcription` is set.
  mkInferenceSettings =
    { scopes, transcription }:
    let
      forScope =
        scope: endpoint:
        let
          p = scopePrefixes.${scope};
        in
        lib.optionalAttrs (endpoint != null) {
          "${p}Mode" = "self-hosted";
          "${p}RemoteUrl" = endpoint.url;
          "${p}Model" = endpoint.model;
        };
    in
    lib.foldl' (acc: scope: acc // forScope scope scopes.${scope}) { } (builtins.attrNames scopes)
    // lib.optionalAttrs (transcription != null) {
      transcriptionMode = "self-hosted";
      # The app pre-warms its bundled Whisper server while this stays true.
      useLocalWhisper = "false";
      remoteTranscriptionType = "openai-compatible";
      remoteTranscriptionUrl = transcription.url;
      remoteTranscriptionModel = transcription.model;
    };
}
