{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.openwhispr;
  inherit (cfg) models package;
  app = "${package}/Applications/OpenWhispr.app";
in
{
  options.programs.openwhispr = {
    enable = lib.mkEnableOption "OpenWhispr";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/openwhispr { };
      defaultText = lib.literalExpression "openwhispr.packages.\${system}.default";
      description = "OpenWhispr application package.";
    };
    models = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/openwhispr-models { };
      defaultText = lib.literalExpression "openwhispr.packages.\${system}.models";
      description = "Hash-pinned local models linked into the upstream cache layout.";
    };
    modelBootstrap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link the pinned local Whisper, diarization, and semantic-search models.";
    };
    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch OpenWhispr when the user logs in.";
    };
    localTranscriptionProvider = lib.mkOption {
      type = lib.types.enum [
        "whisper"
        "parakeet"
      ];
      default = "whisper";
      description = "Local engine pre-warmed by the upstream application at startup.";
    };
    whisperModel = lib.mkOption {
      type = lib.types.str;
      default = "base";
      description = "Pinned upstream Whisper model name pre-warmed for local transcription.";
    };
    parakeetModel = lib.mkOption {
      type = lib.types.str;
      default = "parakeet-tdt-0.6b-v3";
      description = "Parakeet model pre-warmed when localTranscriptionProvider is parakeet.";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [ package ];
      sessionVariables = {
        OPENWHISPR_CHANNEL = "production";
        LOCAL_TRANSCRIPTION_PROVIDER = cfg.localTranscriptionProvider;
        LOCAL_WHISPER_MODEL = cfg.whisperModel;
        PARAKEET_MODEL = cfg.parakeetModel;
      };
      file = lib.mkIf cfg.modelBootstrap {
        ".cache/openwhispr/diarization-models/3dspeaker_speech_campplus_sv_en_voxceleb_16k.onnx" = {
          source = "${models}/diarization-models/3dspeaker_speech_campplus_sv_en_voxceleb_16k.onnx";
          force = true;
        };
        ".cache/openwhispr/diarization-models/sherpa-onnx-pyannote-segmentation-3-0/model.onnx" = {
          source = "${models}/diarization-models/sherpa-onnx-pyannote-segmentation-3-0/model.onnx";
          force = true;
        };
        ".cache/openwhispr/diarization-models/silero_vad.onnx" = {
          source = "${models}/diarization-models/silero_vad.onnx";
          force = true;
        };
        ".cache/openwhispr/embedding-models/all-MiniLM-L6-v2/model.onnx" = {
          source = "${models}/embedding-models/all-MiniLM-L6-v2/model.onnx";
          force = true;
        };
        ".cache/openwhispr/embedding-models/all-MiniLM-L6-v2/tokenizer.json" = {
          source = "${models}/embedding-models/all-MiniLM-L6-v2/tokenizer.json";
          force = true;
        };
        ".cache/openwhispr/whisper-models/ggml-base.bin" = {
          source = "${models}/whisper-models/ggml-base.bin";
          force = true;
        };
      };
    };
    launchd.agents.openwhispr = lib.mkIf cfg.autoStart {
      enable = true;
      config = {
        Label = "com.dryvist.nix-openwhispr";
        ProgramArguments = [ "${app}/Contents/MacOS/OpenWhispr" ];
        EnvironmentVariables = {
          OPENWHISPR_CHANNEL = "production";
          LOCAL_TRANSCRIPTION_PROVIDER = cfg.localTranscriptionProvider;
          LOCAL_WHISPER_MODEL = cfg.whisperModel;
          PARAKEET_MODEL = cfg.parakeetModel;
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        ProcessType = "Interactive";
        ThrottleInterval = 10;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/OpenWhispr/stdout.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/OpenWhispr/stderr.log";
      };
    };
  };
}
