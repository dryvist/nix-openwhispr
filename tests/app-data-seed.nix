# Fixture check for the declarative app data apply script.
{
  pkgs,
  appData,
}:
let
  emailPrompt = "Draft a reply.\nUse \"plain\" words and 'short' sentences.\n";
  summaryPrompt = "Summarize the note in three bullets.\n";
  emailPromptFile = pkgs.writeText "openwhispr-email-prompt.txt" emailPrompt;
  summaryPromptFile = pkgs.writeText "openwhispr-summary-prompt.txt" summaryPrompt;
  dictionaryFile = pkgs.writeText "openwhispr-dictionary.txt" ''
    # Comment line
    Quartz

       padded
    acme corp
  '';
  actions = [
    {
      name = "Email draft";
      kind = "template";
      description = "Draft a reply";
      icon = null;
      prompt = emailPrompt;
      promptFile = null;
    }
    {
      name = "Summarize";
      kind = "action";
      description = "";
      icon = "notes";
      prompt = null;
      promptFile = "${summaryPromptFile}";
    }
    {
      name = "Builtin summary";
      kind = "action";
      description = "Must not change";
      icon = null;
      prompt = "replacement prompt";
      promptFile = null;
    }
  ];
  # Exit status of the running check: 0 means running, 1 means not running.
  alwaysRunning = "${pkgs.coreutils}/bin/true";
  neverRunning = "${pkgs.coreutils}/bin/false";
  apply = appData.mkApply {
    folders = [
      "clients/acme"
      "Meetings"
    ];
    dictionary = [
      "Acme Corp"
      "O'Brien"
    ];
    dictionaryFile = "${dictionaryFile}";
    inherit actions;
    isRunning = neverRunning;
  };
  running = appData.mkApply {
    folders = [ "clients/acme" ];
    isRunning = alwaysRunning;
  };
  missing = appData.mkApply {
    dictionaryFile = "/nonexistent/openwhispr-app-data/dictionary.txt";
    isRunning = neverRunning;
  };
in
pkgs.runCommand "openwhispr-app-data-seed"
  {
    nativeBuildInputs = [ pkgs.sqlite ];
  }
  ''
    bash ${./app-data-seed.sh} \
      ${apply}/bin/openwhispr-apply-app-data \
      ${running}/bin/openwhispr-apply-app-data \
      ${missing}/bin/openwhispr-apply-app-data \
      ${./app-data-schema.sql} \
      ${emailPromptFile} \
      ${summaryPromptFile}
    touch $out
  ''
