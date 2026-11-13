-- Schema-only fixture for the app data check. No rows.
-- Copied from the .schema output of the OpenWhispr 1.11.0 database. It keeps
-- the tables the apply script writes (folders, custom_dictionary, actions),
-- the spaces table it reads for the private space, and their indexes and
-- triggers.

CREATE TABLE spaces (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          client_space_id TEXT,
          cloud_team_id   TEXT,
          workspace_id    TEXT,
          kind            TEXT NOT NULL DEFAULT 'team' CHECK (kind IN ('private','team')),
          name            TEXT NOT NULL,
          emoji           TEXT,
          sort_order      INTEGER NOT NULL DEFAULT 0,
          my_role         TEXT,
          member_count    INTEGER,
          sync_status     TEXT NOT NULL DEFAULT 'pending',
          deleted_at      TEXT,
          created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
        , cloud_space_id TEXT, teams TEXT, my_direct_role TEXT, capabilities TEXT);
CREATE UNIQUE INDEX idx_spaces_client_space_id ON spaces(client_space_id);
CREATE UNIQUE INDEX idx_spaces_cloud_team_id ON spaces(cloud_team_id) WHERE cloud_team_id IS NOT NULL;
CREATE UNIQUE INDEX idx_spaces_cloud_space_id ON spaces(cloud_space_id) WHERE cloud_space_id IS NOT NULL;

CREATE TABLE "folders" (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              client_folder_id TEXT,
              cloud_id TEXT,
              sync_status TEXT DEFAULT 'pending',
              deleted_at TEXT,
              space_id INTEGER
            , left_team INTEGER NOT NULL DEFAULT 0, account_id TEXT);
CREATE UNIQUE INDEX idx_folders_client_folder_id ON folders(client_folder_id);
CREATE INDEX idx_folders_space_sort ON folders(space_id, sort_order);
CREATE INDEX idx_folders_account_id ON folders(account_id);
CREATE UNIQUE INDEX idx_folders_space_legacy_name ON folders(space_id, name) WHERE deleted_at IS NULL AND account_id IS NULL;
CREATE UNIQUE INDEX idx_folders_space_account_name ON folders(space_id, account_id, name) WHERE deleted_at IS NULL AND account_id IS NOT NULL;

CREATE TABLE custom_dictionary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL UNIQUE,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        , client_dict_id TEXT, cloud_id TEXT, source TEXT NOT NULL DEFAULT 'manual', sync_status TEXT DEFAULT 'pending', deleted_at TEXT, updated_at DATETIME, shared_at TEXT, shared_at_dirty INTEGER NOT NULL DEFAULT 0, fallback_retired INTEGER NOT NULL DEFAULT 0);
CREATE UNIQUE INDEX idx_custom_dictionary_client_id ON custom_dictionary(client_dict_id);
CREATE TRIGGER custom_dictionary_client_id_default
        AFTER INSERT ON custom_dictionary
        WHEN new.client_dict_id IS NULL
        BEGIN
          UPDATE custom_dictionary SET client_dict_id =
            lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
            substr(lower(hex(randomblob(2))), 2) || '-' ||
            substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) ||
            '-' || lower(hex(randomblob(6)))
          WHERE id = new.id;
        END;

CREATE TABLE actions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          prompt TEXT NOT NULL,
          icon TEXT NOT NULL DEFAULT 'sparkles',
          is_builtin INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        , translation_key TEXT, client_id TEXT, kind TEXT NOT NULL DEFAULT 'template', sections TEXT, output TEXT);
CREATE UNIQUE INDEX idx_actions_client_id ON actions(client_id) WHERE client_id IS NOT NULL;
