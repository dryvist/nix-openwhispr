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
  env = {
    OPENWHISPR_CHANNEL = "production";
    LOCAL_TRANSCRIPTION_PROVIDER = cfg.localTranscriptionProvider;
    LOCAL_WHISPER_MODEL = cfg.whisperModel;
    PARAKEET_MODEL = cfg.parakeetModel;
  }
  // lib.optionalAttrs (cfg.openaiBaseUrl != null) {
    OPENAI_BASE_URL = cfg.openaiBaseUrl;
  }
  // cfg.environment;
in
{
  options.programs.openwhispr = {
    enable = lib.mkEnableOption "OpenWhispr";
    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "OpenWhispr upstream version ('latest' or specific version string).";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/openwhispr {
        inherit (cfg) version;
      };
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
    notesDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/alice/notes/openwhispr";
      description = ''
        Directory where OpenWhispr writes notes when "Save notes as files" is enabled.
        Symlinks ~/Library/Application Support/open-whispr/notes to this target directory.
      '';
    };
    openaiBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://localhost:4000/v1";
      description = "Base URL for local OpenAI-compatible routers (sets OPENAI_BASE_URL).";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        DEBUG = "true";
      };
      description = ''
        Extra non-secret environment variables passed to the application session and launchd agent.
        Warning: Do not place API keys, tokens, or credentials here; launchd environment plists
        are readable by any process running under your user account.
      '';
    };
    launchdLabel = lib.mkOption {
      type = lib.types.str;
      default = "com.dryvist.nix-openwhispr";
      description = "Label identifier for the launchd agent plist.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "nix-openwhispr only supports macOS (darwin) platforms.";
      }
      {
        assertion = cfg.notesDirectory != null -> lib.strings.hasPrefix "/" cfg.notesDirectory;
        message = "programs.openwhispr.notesDirectory must be an absolute path.";
      }
    ];

    home = {
      packages = [ package ];
      sessionVariables = env;
      file = lib.mkMerge [
        (lib.mkIf cfg.modelBootstrap {
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
        })
        (lib.mkIf (cfg.notesDirectory != null) {
          "Library/Application Support/open-whispr/notes".source =
            config.lib.file.mkOutOfStoreSymlink cfg.notesDirectory;
        })
      ];
    };
    launchd.agents.openwhispr = lib.mkIf cfg.autoStart {
      enable = true;
      config = {
        Label = cfg.launchdLabel;
        ProgramArguments = [ "${app}/Contents/MacOS/OpenWhispr" ];
        EnvironmentVariables = env;
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
