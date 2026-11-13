# Declarative app data for OpenWhispr.
#
# mkApply returns a script that writes folders, dictionary words, and actions
# into the application's SQLite database. The module and the fixture check
# both build their script with this function.
{
  lib,
  pkgs,
}:
let
  # A SQL string literal ends a quote by doubling it. Nothing else needs escaping.
  escapeSql = lib.replaceStrings [ "'" ] [ "''" ];
in
{
  mkApply =
    {
      folders ? [ ],
      dictionary ? [ ],
      dictionaryFile ? null,
      actions ? [ ],
      isRunning ? "/usr/bin/pgrep -x OpenWhispr",
    }:
    let
      manifest = builtins.toJSON {
        inherit
          folders
          dictionary
          dictionaryFile
          actions
          ;
      };
      sql = pkgs.writeText "openwhispr-app-data.sql" ''
        .timeout 5000
        CREATE TEMP TABLE manifest (doc TEXT NOT NULL);
        INSERT INTO temp.manifest VALUES ('${escapeSql manifest}');
        ${builtins.readFile ./app-data.sql}
      '';
      runtimePaths = lib.unique (
        lib.filter (p: p != null) ([ dictionaryFile ] ++ map (a: a.promptFile) actions)
      );
    in
    pkgs.writeShellApplication {
      name = "openwhispr-apply-app-data";
      runtimeInputs = [ pkgs.sqlite ];
      text = ''
        if [ "$#" -ne 1 ]; then
          echo "usage: openwhispr-apply-app-data DATABASE" >&2
          exit 2
        fi
        db=$1
        if [ ! -f "$db" ]; then
          echo "openwhispr app data: skipped, database not found"
          exit 0
        fi
        set +e
        ${isRunning} >/dev/null 2>&1
        running=$?
        set -e
        if [ "$running" -eq 0 ]; then
          echo "openwhispr app data: skipped, OpenWhispr is running"
          exit 0
        elif [ "$running" -ne 1 ]; then
          echo "openwhispr app data: skipped, could not check whether OpenWhispr is running"
          exit 0
        fi
        ${lib.concatMapStrings (p: ''
          if [ ! -r ${lib.escapeShellArg p} ]; then
            echo "openwhispr app data: skipped, cannot read ${p}"
            exit 0
          fi
        '') runtimePaths}
        sqlite3 -bail "$db" < ${sql}
        echo "openwhispr app data: applied"
      '';
    };
}
