#!/usr/bin/env bash
# Checks the app data apply script against a schema-only database.
#
# Usage: app-data-seed.sh APPLY RUNNING MISSING SCHEMA EMAIL_PROMPT SUMMARY_PROMPT
#   APPLY         apply script built with the sample data
#   RUNNING       apply script built with a check that reports the app running
#   MISSING       apply script built with a dictionary file that does not exist
#   SCHEMA        schema-only fixture
#   EMAIL_PROMPT  file holding the inline prompt of the "Email draft" action
#   SUMMARY_PROMPT file used as the prompt of the "Summarize" action
set -euo pipefail

apply=$1
running=$2
missing=$3
schema=$4
email_prompt=$5
summary_prompt=$6
work=$(mktemp -d)

fail() {
  echo "app-data-seed: FAIL: $*" >&2
  exit 1
}

new_db() {
  sqlite3 "$1" < "$schema"
  sqlite3 "$1" "INSERT INTO spaces (id, kind, name) VALUES (1, 'private', 'Private'), (2, 'team', 'Team');"
}

# expect WANT SQL: run SQL against $db and fail unless the output equals WANT.
expect() {
  local want=$1
  local sql=$2
  local got
  got=$(sqlite3 "$db" "$sql")
  if [ "$got" != "$want" ]; then
    fail "expected $want, got $got: $sql"
  fi
}

# expect_skip OUTPUT REASON: fail unless the runner skipped for REASON.
expect_skip() {
  case "$1" in
    *"skipped, $2"*) ;;
    *) fail "runner did not skip for '$2': $1" ;;
  esac
}

db="$work/transcriptions.db"
new_db "$db"
sqlite3 "$db" "
  INSERT INTO folders (name, space_id, deleted_at) VALUES ('Meetings', 1, '2026-01-01 00:00:00');
  INSERT INTO custom_dictionary (word, deleted_at) VALUES ('Quartz', '2026-01-01 00:00:00');
  INSERT INTO actions (name, prompt, icon, kind, client_id) VALUES ('Summarize', 'old prompt', 'sparkles', 'action', 'user-1');
  INSERT INTO actions (name, prompt, icon, is_builtin, translation_key, client_id, kind) VALUES ('Builtin summary', 'built-in prompt', 'sparkles', 1, 'summary', 'builtin-1', 'action');
"

"$apply" "$db"

expect 1 "SELECT count(*) FROM folders WHERE name = 'clients/acme' AND space_id = 1 AND account_id IS NULL AND deleted_at IS NULL AND client_folder_id IS NOT NULL;"
expect 1 "SELECT count(*) FROM folders WHERE name = 'Meetings' AND space_id = 1 AND deleted_at IS NULL;"
expect 0 "SELECT count(*) FROM folders WHERE space_id = 2;"

expect 1 "SELECT count(*) FROM custom_dictionary WHERE word = 'Acme Corp' AND deleted_at IS NULL;"
expect 1 "SELECT count(*) FROM custom_dictionary WHERE lower(word) = 'acme corp';"
expect 1 "SELECT count(*) FROM custom_dictionary WHERE word = 'O''Brien' AND deleted_at IS NULL;"
expect 1 "SELECT count(*) FROM custom_dictionary WHERE word = 'padded' AND deleted_at IS NULL;"
expect 1 "SELECT count(*) FROM custom_dictionary WHERE word = 'Quartz' AND deleted_at IS NULL;"
expect 0 "SELECT count(*) FROM custom_dictionary WHERE word = '' OR word LIKE '#%' OR word LIKE ' %';"

expect 1 "SELECT count(*) FROM actions WHERE name = 'Email draft' AND kind = 'template' AND description = 'Draft a reply' AND prompt = CAST(readfile('$email_prompt') AS TEXT);"
expect 1 "SELECT count(*) FROM actions WHERE name = 'Summarize' AND is_builtin = 0 AND kind = 'action' AND icon = 'notes' AND prompt = CAST(readfile('$summary_prompt') AS TEXT);"
expect 1 "SELECT count(*) FROM actions WHERE name = 'Summarize';"
expect 1 "SELECT count(*) FROM actions WHERE name = 'Builtin summary' AND is_builtin = 1 AND prompt = 'built-in prompt';"
expect 1 "SELECT count(*) FROM actions WHERE name = 'Builtin summary';"

before="$work/before.sql"
after="$work/after.sql"
sqlite3 "$db" .dump > "$before"
"$apply" "$db" > /dev/null
sqlite3 "$db" .dump > "$after"
cmp -s "$before" "$after" || fail "second run changed the database"

guard_db="$work/running.db"
new_db "$guard_db"
out=$("$running" "$guard_db")
expect_skip "$out" "OpenWhispr is running"
db="$guard_db"
expect 0 "SELECT count(*) FROM folders;"
expect 0 "SELECT count(*) FROM actions;"

missing_db="$work/missing-file.db"
new_db "$missing_db"
out=$("$missing" "$missing_db")
expect_skip "$out" "cannot read"
db="$missing_db"
expect 0 "SELECT count(*) FROM folders;"
expect 0 "SELECT count(*) FROM custom_dictionary;"

out=$("$apply" "$work/absent.db")
expect_skip "$out" "database not found"
if [ -e "$work/absent.db" ]; then
  fail "runner created a missing database"
fi

echo "app-data-seed: all checks passed"
