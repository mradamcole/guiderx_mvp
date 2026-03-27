-- Admin Console V1: publication-study linkage and deterministic upsert support.

CREATE TABLE IF NOT EXISTS PaperStudyMap (
    paper_id UUID NOT NULL REFERENCES Paper(paper_id) ON DELETE CASCADE,
    study_id UUID NOT NULL REFERENCES Study(study_id) ON DELETE CASCADE,
    relationship_type VARCHAR(50),
    PRIMARY KEY (paper_id, study_id)
);

CREATE INDEX IF NOT EXISTS idx_paperstudy_study_id
    ON PaperStudyMap (study_id);

CREATE INDEX IF NOT EXISTS idx_paper_retrieval_date
    ON Paper (retrieval_date DESC);

-- Normalize duplicate Journal names before adding unique index.
WITH canonical AS (
    SELECT DISTINCT ON (name) name, journal_id AS keep_id
    FROM Journal
    ORDER BY name, journal_id
), remap AS (
    SELECT j.journal_id AS old_id, c.keep_id
    FROM Journal j
    JOIN canonical c ON c.name = j.name
    WHERE j.journal_id <> c.keep_id
)
UPDATE Paper p
SET journal_id = r.keep_id
FROM remap r
WHERE p.journal_id = r.old_id;

DELETE FROM Journal j
USING (
    SELECT DISTINCT ON (name) name, journal_id AS keep_id
    FROM Journal
    ORDER BY name, journal_id
) c
WHERE j.name = c.name
  AND j.journal_id <> c.keep_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_name_unique
    ON Journal (name);

-- Normalize duplicate Publisher names before adding unique index.
WITH canonical AS (
    SELECT DISTINCT ON (name) name, publisher_id AS keep_id
    FROM Publisher
    ORDER BY name, publisher_id
), remap AS (
    SELECT p.publisher_id AS old_id, c.keep_id
    FROM Publisher p
    JOIN canonical c ON c.name = p.name
    WHERE p.publisher_id <> c.keep_id
)
UPDATE Paper p
SET publisher_id = r.keep_id
FROM remap r
WHERE p.publisher_id = r.old_id;

DELETE FROM Publisher p
USING (
    SELECT DISTINCT ON (name) name, publisher_id AS keep_id
    FROM Publisher
    ORDER BY name, publisher_id
) c
WHERE p.name = c.name
  AND p.publisher_id <> c.keep_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_publisher_name_unique
    ON Publisher (name);
