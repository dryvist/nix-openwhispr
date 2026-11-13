-- Applies the manifest in temp.manifest to the OpenWhispr database.
-- The manifest is a JSON object with folders, dictionary, dictionaryFile,
-- and actions. The script writes in one transaction. It never deletes or
-- renames a row, and it never changes a built-in action (is_builtin = 1).
--
-- Folder and action write values follow the upstream application's own
-- insert paths (version 1.11.0): a random UUID for client_folder_id and
-- client_id, the private space for folders, and a NULL account_id.

BEGIN IMMEDIATE;

-- Folders -----------------------------------------------------------------

-- Restore a soft-deleted folder only when no active folder has the name.
UPDATE folders
SET deleted_at = NULL, updated_at = CURRENT_TIMESTAMP
WHERE id IN (
  SELECT (
    SELECT f.id
    FROM folders AS f
    WHERE f.name = j.value AND f.space_id = s.id AND f.deleted_at IS NOT NULL
    ORDER BY f.id DESC
    LIMIT 1
  )
  FROM json_each((SELECT doc FROM temp.manifest), '$.folders') AS j
  CROSS JOIN (SELECT id FROM spaces WHERE kind = 'private' ORDER BY id LIMIT 1) AS s
  WHERE NOT EXISTS (
    SELECT 1
    FROM folders AS a
    WHERE a.name = j.value AND a.space_id = s.id AND a.deleted_at IS NULL
  )
);

CREATE TEMP TABLE wanted_folders AS
SELECT j.value AS name, s.id AS space_id, MIN(j.key) AS first_key
FROM json_each((SELECT doc FROM temp.manifest), '$.folders') AS j
CROSS JOIN (SELECT id FROM spaces WHERE kind = 'private' ORDER BY id LIMIT 1) AS s
WHERE NOT EXISTS (
  SELECT 1
  FROM folders AS a
  WHERE a.name = j.value AND a.space_id = s.id
)
GROUP BY j.value, s.id;

INSERT INTO folders (name, sort_order, space_id, client_folder_id, account_id, updated_at)
SELECT
  w.name,
  (SELECT COALESCE(MAX(f.sort_order), 0) FROM folders AS f WHERE f.space_id = w.space_id)
    + ROW_NUMBER() OVER (ORDER BY w.first_key),
  w.space_id,
  lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4'
    || substr(lower(hex(randomblob(2))), 2) || '-'
    || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-'
    || lower(hex(randomblob(6))),
  NULL,
  CURRENT_TIMESTAMP
FROM temp.wanted_folders AS w
ORDER BY w.first_key;

-- Dictionary --------------------------------------------------------------

-- Inline words come first, then file words. Lines in the file are trimmed.
-- Blank lines and lines that start with # are skipped. Matching ignores
-- case, and the first spelling wins.
CREATE TEMP TABLE wanted_words AS
WITH RECURSIVE file_lines(n, line, rest) AS (
  SELECT
    0,
    '',
    CAST(COALESCE(readfile((SELECT json_extract(doc, '$.dictionaryFile') FROM temp.manifest)), '') AS TEXT)
      || char(10)
  UNION ALL
  SELECT
    n + 1,
    substr(rest, 1, instr(rest, char(10)) - 1),
    substr(rest, instr(rest, char(10)) + 1)
  FROM file_lines
  WHERE rest <> ''
),
candidates(word, src, pos) AS (
  SELECT j.value, 0, j.key
  FROM json_each((SELECT doc FROM temp.manifest), '$.dictionary') AS j
  UNION ALL
  SELECT trim(line, ' ' || char(9) || char(13)), 1, n
  FROM file_lines
  WHERE trim(line, ' ' || char(9) || char(13)) <> ''
    AND substr(trim(line, ' ' || char(9) || char(13)), 1, 1) <> '#'
),
ranked AS (
  SELECT
    word,
    src,
    pos,
    ROW_NUMBER() OVER (PARTITION BY lower(word) ORDER BY src, pos) AS dup_rank
  FROM candidates
)
SELECT word, ROW_NUMBER() OVER (ORDER BY src, pos) AS ord
FROM ranked
WHERE dup_rank = 1;

-- Restore a soft-deleted word only when no active word matches it, ignoring case.
UPDATE custom_dictionary
SET deleted_at = NULL, updated_at = CURRENT_TIMESTAMP
WHERE deleted_at IS NOT NULL
  AND word IN (SELECT word FROM temp.wanted_words)
  AND NOT EXISTS (
    SELECT 1
    FROM custom_dictionary AS a
    WHERE a.deleted_at IS NULL AND lower(a.word) = lower(custom_dictionary.word)
  );

INSERT INTO custom_dictionary (word, updated_at)
SELECT w.word, CURRENT_TIMESTAMP
FROM temp.wanted_words AS w
WHERE NOT EXISTS (
    SELECT 1
    FROM custom_dictionary AS c
    WHERE c.deleted_at IS NULL AND lower(c.word) = lower(w.word)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM custom_dictionary AS c
    WHERE c.word = w.word
  )
ORDER BY w.ord;

-- Actions -----------------------------------------------------------------

-- A prompt comes from the inline value or from a file. File contents are used as is.
CREATE TEMP TABLE wanted_actions AS
SELECT
  j.key AS ord,
  json_extract(j.value, '$.name') AS name,
  json_extract(j.value, '$.kind') AS kind,
  json_extract(j.value, '$.description') AS description,
  COALESCE(json_extract(j.value, '$.icon'), 'sparkles') AS icon,
  COALESCE(
    json_extract(j.value, '$.prompt'),
    CAST(readfile(json_extract(j.value, '$.promptFile')) AS TEXT)
  ) AS prompt
FROM json_each((SELECT doc FROM temp.manifest), '$.actions') AS j;

-- Update only user actions, and only when a value differs.
UPDATE actions
SET
  description = w.description,
  prompt = w.prompt,
  icon = w.icon,
  kind = w.kind,
  updated_at = CURRENT_TIMESTAMP
FROM temp.wanted_actions AS w
WHERE actions.name = w.name
  AND actions.is_builtin = 0
  AND (
    actions.description IS NOT w.description
    OR actions.prompt IS NOT w.prompt
    OR actions.icon IS NOT w.icon
    OR actions.kind IS NOT w.kind
  );

-- Insert only names that no row uses yet.
INSERT INTO actions (
  name, description, prompt, icon, is_builtin, sort_order, client_id,
  kind, sections, output, created_at, updated_at
)
SELECT
  w.name,
  w.description,
  w.prompt,
  w.icon,
  0,
  (SELECT COALESCE(MAX(a.sort_order), 0) FROM actions AS a) + ROW_NUMBER() OVER (ORDER BY w.ord),
  lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4'
    || substr(lower(hex(randomblob(2))), 2) || '-'
    || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))), 2) || '-'
    || lower(hex(randomblob(6))),
  w.kind,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM temp.wanted_actions AS w
WHERE NOT EXISTS (SELECT 1 FROM actions AS a WHERE a.name = w.name)
ORDER BY w.ord;

SELECT 'openwhispr app data: skipped action name used by a built-in action: ' || w.name
FROM temp.wanted_actions AS w
WHERE EXISTS (SELECT 1 FROM actions AS a WHERE a.name = w.name AND a.is_builtin = 1);

COMMIT;
