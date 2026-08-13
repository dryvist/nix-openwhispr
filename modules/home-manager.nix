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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];
    launchd.agents.openwhispr = lib.mkIf cfg.autoStart {
      enable = true;
      config = {
        ProgramArguments = [ "${app}/Contents/MacOS/OpenWhispr" ];
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
