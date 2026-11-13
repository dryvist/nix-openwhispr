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
  appData = import ./app-data.nix { inherit lib pkgs; };
  appDatabase = "${config.home.homeDirectory}/Library/Application Support/open-whispr/transcriptions.db";
  actionList = lib.mapAttrsToList (name: action: action // { inherit name; }) cfg.actions;
  hasAppData =
    cfg.folders != [ ] || cfg.dictionary != [ ] || cfg.dictionaryFile != null || cfg.actions != { };
  appDataApply = appData.mkApply {
    inherit (cfg) folders dictionary dictionaryFile;
    actions = actionList;
  };
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
    folders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "Meetings"
        "clients/acme"
      ];
      description = ''
        Folder names to ensure in the private space of the application database.
        Each name is stored as written, so a slash such as `clients/acme` stays part
        of the name. Existing folders are not changed.
      '';
    };
    dictionary = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "Acme Corp" ];
      description = ''
        Words to ensure in the custom dictionary. Matching ignores case, so a word
        that already exists in another case is kept as it is.
      '';
    };
    dictionaryFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/alice/.config/openwhispr/dictionary.txt";
      description = ''
        Absolute runtime path to a text file with one word per line. Blank lines and
        lines that start with `#` are ignored. The file is read at activation, so its
        contents never enter the Nix store.
      '';
    };
    actions = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            kind = lib.mkOption {
              type = lib.types.enum [
                "action"
                "template"
              ];
              default = "action";
              description = "Kind of the action row in the application database.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Short description shown with the action.";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "notes";
              description = "Icon name. Null uses the application default, `sparkles`.";
            };
            prompt = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Prompt text. Set exactly one of `prompt` or `promptFile`.";
            };
            promptFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Absolute runtime path to a file that holds the prompt. The file is read
                at activation, and its contents are used as they are.
              '';
            };
          };
        }
      );
      default = { };
      example = {
        "Summarize meeting" = {
          icon = "notes";
          prompt = "Summarize the meeting in three bullets.";
        };
      };
      description = ''
        Actions and templates to ensure in the application database. The attribute
        name is the action name. A user action is updated when a value differs.
        Built-in actions are never changed.
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
      {
        assertion = lib.all (name: name != "") cfg.folders;
        message = "programs.openwhispr.folders entries must not be empty.";
      }
      {
        assertion = lib.all (word: word != "") cfg.dictionary;
        message = "programs.openwhispr.dictionary entries must not be empty.";
      }
      {
        assertion = cfg.dictionaryFile == null || lib.strings.hasPrefix "/" cfg.dictionaryFile;
        message = "programs.openwhispr.dictionaryFile must be an absolute path.";
      }
      {
        assertion = lib.all (action: action.name != "") actionList;
        message = "programs.openwhispr.actions names must not be empty.";
      }
      {
        assertion = lib.all (action: (action.prompt == null) != (action.promptFile == null)) actionList;
        message = "Each programs.openwhispr.actions entry must set exactly one of prompt or promptFile.";
      }
      {
        assertion = lib.all (
          action: action.promptFile == null || lib.strings.hasPrefix "/" action.promptFile
        ) actionList;
        message = "programs.openwhispr.actions.<name>.promptFile must be an absolute path.";
      }
    ];

    home = {
      packages = [ package ];
      sessionVariables = env;
      activation = lib.optionalAttrs hasAppData {
        openwhisperAppData = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${appDataApply}/bin/openwhispr-apply-app-data ${lib.escapeShellArg appDatabase}
        '';
      };
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
