{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.programs.openwhispr;
  package = cfg.package;
  app = "${package}/Applications/OpenWhispr.app";
  cacheDir = "${config.home.homeDirectory}/.cache/openwhispr";
in
{
  options.programs.openwhispr = {
    enable = lib.mkEnableOption "OpenWhispr";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.default;
      defaultText = lib.literalExpression "openwhispr.packages.\${system}.default";
      description = "OpenWhispr application package.";
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
      description = "Local transcription engine selected at startup.";
    };
    whisperModel = lib.mkOption {
      type = lib.types.str;
      default = "base";
      description = "Pinned upstream Whisper model name used for local transcription.";
    };
    parakeetModel = lib.mkOption {
      type = lib.types.str;
      default = "parakeet-tdt-0.6b-v3";
      description = "Default Parakeet model when localTranscriptionProvider is parakeet.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];
    home.sessionVariables = {
      OPENWHISPR_CHANNEL = "production";
      LOCAL_TRANSCRIPTION_PROVIDER = cfg.localTranscriptionProvider;
      LOCAL_WHISPER_MODEL = cfg.whisperModel;
      PARAKEET_MODEL = cfg.parakeetModel;
      DIARIZATION_MODEL_DIR = "${cacheDir}/diarization-models";
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
          DIARIZATION_MODEL_DIR = "${cacheDir}/diarization-models";
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
