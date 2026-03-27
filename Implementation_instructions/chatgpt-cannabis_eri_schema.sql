-- Do not use this schema. It is an alternative schema to the one in the sql_schema.sql file.

-- ============================================================================
-- Medical Cannabis Evidence & CDS Platform
-- Single PostgreSQL Schema
--
-- Source basis:
--   Derived from the architecture document provided by the user, including:
--   reference/terminology, publication, study, intervention, outcome,
--   quality/bias, provenance, evidence scoring, evidence aggregation,
--   explainable CDS, and regulatory defensibility layers.
--
-- Design notes:
--   1) PostgreSQL JSONB is used where the source explicitly called for flexible
--      logic or patient context.
--   2) BIGINT identity keys are used consistently for operational simplicity.
--   3) TIMESTAMPTZ is used for all audit-sensitive timestamps.
--   4) The Recommendation model implemented here is the later/canonical model:
--      reusable guidance keyed by ConceptId and ProductId, with
--      RecommendationInstance for patient-specific generation.
--   5) Comments are intentionally verbose so engineers and auditors can infer
--      design intent directly from the database.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS cannabis_eri;
SET search_path TO cannabis_eri, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- Utility trigger: maintain updated_at timestamps
-- ============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION set_updated_at() IS
'Generic trigger function that stamps updated_at whenever a row is modified.';

-- ============================================================================
-- 1. REFERENCE & TERMINOLOGY LAYER
-- ============================================================================

CREATE TABLE concept (
    concept_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    system                  TEXT NOT NULL,
    code                    TEXT NOT NULL,
    display_text            TEXT NOT NULL,
    definition              TEXT,
    version                 TEXT,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_concept_system_code UNIQUE (system, code)
);

COMMENT ON TABLE concept IS
'Canonical terminology concept used to normalize findings across vocabularies such as ICD-11, SNOMED CT, and RxNorm.';
COMMENT ON COLUMN concept.system IS 'Terminology source or namespace.';
COMMENT ON COLUMN concept.code IS 'Canonical identifier within the source terminology.';
COMMENT ON COLUMN concept.display_text IS 'Preferred human-readable label for display to clinicians and analysts.';
COMMENT ON COLUMN concept.definition IS 'Optional editorial or imported definition.';
COMMENT ON COLUMN concept.version IS 'Version of the terminology system, where known.';
COMMENT ON COLUMN concept.is_active IS 'Soft-active flag to preserve historical mappings while preventing new use of deprecated terms.';
COMMENT ON COLUMN concept.created_at IS 'Timestamp the concept record was created.';
COMMENT ON COLUMN concept.updated_at IS 'Timestamp the concept record was last updated.';

CREATE TABLE concept_relationship (
    concept_relationship_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_concept_id       BIGINT NOT NULL REFERENCES concept(concept_id),
    target_concept_id       BIGINT NOT NULL REFERENCES concept(concept_id),
    relationship_type       TEXT NOT NULL,
    relationship_source     TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_concept_relationship_no_self
        CHECK (source_concept_id <> target_concept_id),
    CONSTRAINT uq_concept_relationship
        UNIQUE (source_concept_id, target_concept_id, relationship_type)
);

COMMENT ON TABLE concept_relationship IS
'Semantic relationship between two concepts. Enables ontology traversal, synonym resolution, reasoning, and explainability.';
COMMENT ON COLUMN concept_relationship.relationship_type IS
'Relationship type such as is_a, treats, causes, associated_with, broader_than, narrower_than.';
COMMENT ON COLUMN concept_relationship.relationship_source IS
'Provenance of the relationship, such as imported ontology, curator assessment, or algorithmic derivation.';

CREATE TABLE registry (
    registry_id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    organization            TEXT,
    url                     TEXT,
    country_code            TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_registry_name UNIQUE (name)
);

COMMENT ON TABLE registry IS
'Clinical trial or study registry used to validate study provenance and support traceability.';

CREATE TABLE journal (
    journal_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    issn_print              TEXT,
    issn_electronic         TEXT,
    rating                  NUMERIC(6,4),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_journal_name UNIQUE (name)
);

COMMENT ON TABLE journal IS
'Journal reference entity. Rating may be used as a weak prior only and should never replace direct methodological assessment.';

CREATE TABLE publisher (
    publisher_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    rating                  NUMERIC(6,4),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_publisher_name UNIQUE (name)
);

COMMENT ON TABLE publisher IS
'Publisher reference entity for publications and source artifacts.';

CREATE TABLE institution (
    institution_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    country_code            TEXT,
    rating                  NUMERIC(6,4),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_institution_name UNIQUE (name)
);

COMMENT ON TABLE institution IS
'Institution associated with a study, such as an academic center, hospital, network, or coordinating site.';

-- ============================================================================
-- 2. PUBLICATION LAYER
-- ============================================================================

CREATE TABLE paper (
    paper_id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title                   TEXT NOT NULL,
    doi                     TEXT,
    url                     TEXT,
    retrieval_date          DATE,
    journal_id              BIGINT REFERENCES journal(journal_id),
    publisher_id            BIGINT REFERENCES publisher(publisher_id),
    publication_date        DATE,
    abstract_text           TEXT,
    full_text_text          TEXT,
    full_text_binary        BYTEA,
    full_text_mime_type     TEXT,
    peer_reviewed           BOOLEAN NOT NULL DEFAULT FALSE,
    altmetric_score         INTEGER,
    source_language         TEXT,
    source_type             TEXT NOT NULL DEFAULT 'publication',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_paper_doi UNIQUE (doi),
    CONSTRAINT chk_paper_source_type
        CHECK (source_type IN ('publication', 'preprint', 'report', 'guideline', 'registry_record', 'other'))
);

COMMENT ON TABLE paper IS
'Scientific publication or source document from which evidence is extracted.';
COMMENT ON COLUMN paper.full_text_text IS
'Full extracted text retained so the source can be reprocessed as extraction methods improve.';
COMMENT ON COLUMN paper.full_text_binary IS
'Original binary artifact, such as the source PDF bytes, retained for replay and defensibility.';
COMMENT ON COLUMN paper.peer_reviewed IS
'Whether the source is peer-reviewed. Important as one prior signal in evidence assessment.';
COMMENT ON COLUMN paper.altmetric_score IS
'Optional dissemination signal, not a substitute for scientific quality.';

CREATE TABLE author (
    author_id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    orcid                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_author_orcid UNIQUE (orcid)
);

COMMENT ON TABLE author IS
'Unique author entity, independent of publications, enabling cross-paper disambiguation.';

CREATE TABLE paper_author (
    paper_id                BIGINT NOT NULL REFERENCES paper(paper_id) ON DELETE CASCADE,
    author_id               BIGINT NOT NULL REFERENCES author(author_id),
    author_order            INTEGER NOT NULL,
    is_corresponding        BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (paper_id, author_id),
    CONSTRAINT chk_paper_author_order_positive CHECK (author_order > 0)
);

COMMENT ON TABLE paper_author IS
'Many-to-many mapping between papers and authors, preserving author order and corresponding-author status.';

-- ============================================================================
-- 3. STUDY LAYER
-- ============================================================================

CREATE TABLE study_type (
    study_type_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    rating                  NUMERIC(6,4),
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_study_type_name UNIQUE (name)
);

COMMENT ON TABLE study_type IS
'Methodological category of a study, such as RCT, cohort, case-control, case series, or qualitative study.';
COMMENT ON COLUMN study_type.rating IS
'Baseline prior quality signal associated with the study type.';

CREATE TABLE study (
    study_id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    study_type_id           BIGINT REFERENCES study_type(study_type_id),
    registry_id             BIGINT REFERENCES registry(registry_id),
    registry_identifier     TEXT,
    sample_size             INTEGER,
    institution_id          BIGINT REFERENCES institution(institution_id),
    sponsor                 TEXT,
    protocol_url            TEXT,
    start_date              DATE,
    end_date                DATE,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_study_sample_size_nonnegative CHECK (sample_size IS NULL OR sample_size >= 0)
);

COMMENT ON TABLE study IS
'Unique clinical investigation independent of publications. One study may have multiple associated papers, follow-ups, or subgroup analyses.';

CREATE TABLE paper_study_map (
    paper_study_map_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paper_id                BIGINT NOT NULL REFERENCES paper(paper_id) ON DELETE CASCADE,
    study_id                BIGINT NOT NULL REFERENCES study(study_id) ON DELETE CASCADE,
    relationship_type       TEXT NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_paper_study_map UNIQUE (paper_id, study_id, relationship_type),
    CONSTRAINT chk_paper_study_relationship_type
        CHECK (relationship_type IN ('primary_publication', 'follow_up', 'subgroup_analysis', 'secondary_analysis', 'protocol', 'registry_link', 'other'))
);

COMMENT ON TABLE paper_study_map IS
'Links publications to the underlying study they describe and distinguishes the type of relationship.';

CREATE TABLE population_characteristic (
    population_characteristic_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id                BIGINT NOT NULL REFERENCES study(study_id) ON DELETE CASCADE,
    characteristic_type     TEXT NOT NULL,
    value_numeric           NUMERIC(18,6),
    value_text              TEXT,
    unit                    TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE population_characteristic IS
'Structured baseline or demographic descriptor for a study population. Supports subgrouping, external validity, and CDS targeting.';

-- ============================================================================
-- 4. INTERVENTION MODEL
-- ============================================================================

CREATE TABLE product (
    product_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    format                  TEXT,
    route                   TEXT,
    description             TEXT,
    thc_cbd_ratio_text      TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_product_name UNIQUE (name)
);

COMMENT ON TABLE product IS
'Cannabis formulation or product evaluated in studies or referenced by clinical guidance.';

CREATE TABLE ingredient (
    ingredient_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    concept_id              BIGINT REFERENCES concept(concept_id),
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_ingredient_name UNIQUE (name)
);

COMMENT ON TABLE ingredient IS
'Canonical active substance or constituent, such as THC, CBD, or a terpene.';

CREATE TABLE product_ingredient (
    product_id              BIGINT NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
    ingredient_id           BIGINT NOT NULL REFERENCES ingredient(ingredient_id),
    amount                  NUMERIC(18,6),
    unit                    TEXT,
    PRIMARY KEY (product_id, ingredient_id)
);

COMMENT ON TABLE product_ingredient IS
'Composition map for a product, enabling ratio analysis and dose normalization.';

CREATE TABLE arm (
    arm_id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id                BIGINT NOT NULL REFERENCES study(study_id) ON DELETE CASCADE,
    arm_type                TEXT NOT NULL,
    size                    INTEGER,
    product_id              BIGINT REFERENCES product(product_id),
    name                    TEXT,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_arm_type
        CHECK (arm_type IN ('intervention', 'placebo', 'active_comparator', 'usual_care', 'control', 'other')),
    CONSTRAINT chk_arm_size_nonnegative CHECK (size IS NULL OR size >= 0)
);

COMMENT ON TABLE arm IS
'Experimental or control group within a study; this is the analytic unit to which doses and outcomes are usually attached.';

CREATE TABLE dose (
    dose_id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    arm_id                  BIGINT NOT NULL REFERENCES arm(arm_id) ON DELETE CASCADE,
    ingredient_id           BIGINT REFERENCES ingredient(ingredient_id),
    amount                  NUMERIC(18,6),
    unit                    TEXT,
    frequency               TEXT,
    duration                TEXT,
    schedule_text           TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE dose IS
'Structured dosing regimen. Separates actual exposure from product identity to support dose-response analysis and explainability.';

-- ============================================================================
-- 5. OUTCOME MODEL
-- ============================================================================

CREATE TABLE outcome_measure (
    outcome_measure_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    unit                    TEXT,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_outcome_measure_name_unit UNIQUE (name, unit)
);

COMMENT ON TABLE outcome_measure IS
'Normalized outcome scale or instrument, such as VAS pain, anxiety index, sleep score, or event rate.';

CREATE TABLE outcome (
    outcome_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    arm_id                  BIGINT NOT NULL REFERENCES arm(arm_id) ON DELETE CASCADE,
    comparator_arm_id       BIGINT REFERENCES arm(arm_id),
    concept_id              BIGINT NOT NULL REFERENCES concept(concept_id),
    outcome_measure_id      BIGINT REFERENCES outcome_measure(outcome_measure_id),
    effect_size             NUMERIC(18,8),
    effect_type             TEXT,
    ci_low                  NUMERIC(18,8),
    ci_high                 NUMERIC(18,8),
    p_value                 NUMERIC(18,8),
    timepoint               TEXT,
    summary                 TEXT,
    event_count             INTEGER,
    denominator_count       INTEGER,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_outcome_effect_type
        CHECK (effect_type IS NULL OR effect_type IN ('RR', 'OR', 'HR', 'MD', 'SMD', 'ARR', 'NNT', 'percent_change', 'correlation', 'other')),
    CONSTRAINT chk_outcome_p_value
        CHECK (p_value IS NULL OR (p_value >= 0 AND p_value <= 1)),
    CONSTRAINT chk_outcome_counts_nonnegative
        CHECK (
            (event_count IS NULL OR event_count >= 0) AND
            (denominator_count IS NULL OR denominator_count >= 0)
        )
);

COMMENT ON TABLE outcome IS
'Central evidence table representing measured effects for a concept within an arm and optionally against a comparator arm.';

CREATE TABLE outcome_adverse_event (
    outcome_adverse_event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outcome_id              BIGINT NOT NULL REFERENCES outcome(outcome_id) ON DELETE CASCADE,
    concept_id              BIGINT NOT NULL REFERENCES concept(concept_id),
    event_rate              NUMERIC(18,8),
    event_count             INTEGER,
    denominator_count       INTEGER,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_outcome_adverse_event_counts
        CHECK (
            (event_count IS NULL OR event_count >= 0) AND
            (denominator_count IS NULL OR denominator_count >= 0)
        )
);

COMMENT ON TABLE outcome_adverse_event IS
'Structured adverse event record attached to an outcome to support risk-benefit assessment and safety-aware CDS.';

-- ============================================================================
-- 6. QUALITY & BIAS
-- ============================================================================

CREATE TABLE bias_domain (
    bias_domain_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_bias_domain_name UNIQUE (name)
);

COMMENT ON TABLE bias_domain IS
'Catalog of bias domains, for example selection, detection, reporting, attrition, or conflict-of-interest bias.';

CREATE TABLE algorithm_version (
    algorithm_version_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    version                 TEXT NOT NULL,
    description             TEXT,
    validation_report_url   TEXT,
    effective_date          DATE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_algorithm_version UNIQUE (name, version)
);

COMMENT ON TABLE algorithm_version IS
'Versioned algorithm package used for scoring, synthesis, or recommendation logic.';

CREATE TABLE llm_run (
    llm_run_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name              TEXT NOT NULL,
    prompt_version          TEXT NOT NULL,
    temperature             NUMERIC(4,3),
    run_date                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    human_validated         BOOLEAN NOT NULL DEFAULT FALSE,
    training_data_description TEXT,
    intended_use            TEXT,
    validation_dataset      TEXT,
    approved_for_production BOOLEAN NOT NULL DEFAULT FALSE,
    algorithm_version_id    BIGINT REFERENCES algorithm_version(algorithm_version_id),
    notes                   TEXT
);

COMMENT ON TABLE llm_run IS
'Record of an LLM/AI processing event. Central audit object for extraction, summarization, reasoning, and explanation.';

CREATE TABLE risk_of_bias (
    risk_of_bias_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id                BIGINT REFERENCES study(study_id) ON DELETE CASCADE,
    outcome_id              BIGINT REFERENCES outcome(outcome_id) ON DELETE CASCADE,
    bias_domain_id          BIGINT NOT NULL REFERENCES bias_domain(bias_domain_id),
    rating                  TEXT NOT NULL,
    supporting_quote        TEXT,
    analysis_text           TEXT,
    overall_certainty_grade TEXT,
    assessed_by_llm_run_id  BIGINT REFERENCES llm_run(llm_run_id),
    assessed_by_user        TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_risk_of_bias_scope
        CHECK ((study_id IS NOT NULL) OR (outcome_id IS NOT NULL)),
    CONSTRAINT chk_risk_of_bias_rating
        CHECK (rating IN ('Low', 'High', 'Unclear')),
    CONSTRAINT chk_risk_of_bias_overall_grade
        CHECK (overall_certainty_grade IS NULL OR overall_certainty_grade IN ('High', 'Moderate', 'Low', 'Very Low'))
);

COMMENT ON TABLE risk_of_bias IS
'Bias assessment at study or outcome level. Outcome-level assessment enables finer-grained evidence scoring and explainability.';

CREATE TABLE generated_text (
    generated_text_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    llm_run_id              BIGINT NOT NULL REFERENCES llm_run(llm_run_id) ON DELETE CASCADE,
    entity_type             TEXT NOT NULL,
    entity_id               BIGINT NOT NULL,
    text_output             TEXT NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE generated_text IS
'AI-generated text output linked to the entity it describes, such as a paper summary, outcome explanation, or recommendation rationale.';

-- ============================================================================
-- 7. EVIDENCE SCORING FRAMEWORK
-- ============================================================================

CREATE TABLE evidence_framework (
    framework_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    TEXT NOT NULL,
    description             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_evidence_framework_name UNIQUE (name)
);

COMMENT ON TABLE evidence_framework IS
'Named evidence-scoring framework such as GRADE, a cannabis-specific framework, or another future regulatory model.';

CREATE TABLE evidence_component (
    component_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    name                    TEXT NOT NULL,
    description             TEXT,
    weight                  NUMERIC(10,6) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_evidence_component UNIQUE (framework_id, name)
);

COMMENT ON TABLE evidence_component IS
'Scorable dimension inside an evidence framework, such as Study Design, Risk of Bias, Consistency, Precision, Effect Size, or Directness.';

CREATE TABLE outcome_evidence_component_score (
    outcome_evidence_component_score_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outcome_id              BIGINT NOT NULL REFERENCES outcome(outcome_id) ON DELETE CASCADE,
    component_id            BIGINT NOT NULL REFERENCES evidence_component(component_id) ON DELETE CASCADE,
    raw_value               NUMERIC(18,8),
    raw_text                TEXT,
    normalized_score        NUMERIC(18,8) NOT NULL,
    calculation_method      TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_outcome_component_score UNIQUE (outcome_id, component_id)
);

COMMENT ON TABLE outcome_evidence_component_score IS
'Transparent component-level scoring at the outcome level. This is the atomic layer from which evidence grades can be reproduced.';

CREATE TABLE study_type_score (
    study_type_score_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    study_type_id           BIGINT NOT NULL REFERENCES study_type(study_type_id) ON DELETE CASCADE,
    score                   NUMERIC(18,8) NOT NULL,
    CONSTRAINT uq_study_type_score UNIQUE (framework_id, study_type_id)
);

COMMENT ON TABLE study_type_score IS
'Framework-specific mapping from study type to numeric score.';

CREATE TABLE bias_score_map (
    bias_score_map_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    bias_rating             TEXT NOT NULL,
    score                   NUMERIC(18,8) NOT NULL,
    CONSTRAINT chk_bias_score_map_rating CHECK (bias_rating IN ('Low', 'High', 'Unclear')),
    CONSTRAINT uq_bias_score_map UNIQUE (framework_id, bias_rating)
);

COMMENT ON TABLE bias_score_map IS
'Framework-specific mapping from bias ratings to numeric values.';

CREATE TABLE effect_normalization_rule (
    effect_normalization_rule_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    effect_type             TEXT NOT NULL,
    transformation          TEXT NOT NULL,
    notes                   TEXT,
    CONSTRAINT uq_effect_normalization_rule UNIQUE (framework_id, effect_type)
);

COMMENT ON TABLE effect_normalization_rule IS
'Rules for converting heterogeneous effect types into a normalized scoring or synthesis representation.';

CREATE TABLE precision_score_rule (
    precision_score_rule_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    min_sample_size         INTEGER,
    max_ci_width            NUMERIC(18,8),
    score                   NUMERIC(18,8) NOT NULL
);

COMMENT ON TABLE precision_score_rule IS
'Rules for assigning a precision score based on sample size, confidence interval width, or both.';

CREATE TABLE evidence_grade_threshold (
    evidence_grade_threshold_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id) ON DELETE CASCADE,
    min_score               NUMERIC(18,8) NOT NULL,
    grade                   TEXT NOT NULL,
    CONSTRAINT chk_evidence_grade_threshold_grade
        CHECK (grade IN ('High', 'Moderate', 'Low', 'Very Low')),
    CONSTRAINT uq_evidence_grade_threshold UNIQUE (framework_id, min_score)
);

COMMENT ON TABLE evidence_grade_threshold IS
'Thresholds converting continuous evidence scores into named grades.';

-- ============================================================================
-- 8. META-ANALYSIS & EVIDENCE AGGREGATION
-- ============================================================================

CREATE TABLE effect_size_transformation (
    transformation_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    effect_type             TEXT NOT NULL,
    transformation_formula  TEXT NOT NULL,
    output_metric           TEXT NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_effect_size_transformation UNIQUE (effect_type, output_metric)
);

COMMENT ON TABLE effect_size_transformation IS
'Catalog of transformations used to convert reported effect estimates into canonical statistical inputs.';

CREATE TABLE standardized_effect (
    standardized_effect_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outcome_id              BIGINT NOT NULL REFERENCES outcome(outcome_id) ON DELETE CASCADE,
    standardized_effect     NUMERIC(18,8) NOT NULL,
    variance                NUMERIC(18,8),
    standard_error          NUMERIC(18,8),
    transformation_id       BIGINT NOT NULL REFERENCES effect_size_transformation(transformation_id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_standardized_effect_outcome UNIQUE (outcome_id)
);

COMMENT ON TABLE standardized_effect IS
'Canonical statistical representation of an outcome after effect transformation and normalization.';

CREATE TABLE clinical_finding (
    clinical_finding_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    concept_id              BIGINT NOT NULL REFERENCES concept(concept_id),
    product_id              BIGINT REFERENCES product(product_id),
    effect_direction        TEXT,
    aggregate_certainty     TEXT,
    weighted_effect         NUMERIC(18,8),
    sum_sample_size         INTEGER,
    consistency_score       NUMERIC(18,8),
    meta_analysis_id        BIGINT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_clinical_finding_effect_direction
        CHECK (effect_direction IS NULL OR effect_direction IN ('benefit', 'harm', 'mixed', 'neutral', 'uncertain')),
    CONSTRAINT chk_clinical_finding_aggregate_certainty
        CHECK (aggregate_certainty IS NULL OR aggregate_certainty IN ('High', 'Moderate', 'Low', 'Very Low'))
);

COMMENT ON TABLE clinical_finding IS
'Aggregated evidence conclusion across studies for a concept and optionally a specific product. Represents meta-evidence, not direct clinician advice.';

CREATE TABLE meta_analysis (
    meta_analysis_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    outcome_measure_id      BIGINT REFERENCES outcome_measure(outcome_measure_id),
    model_type              TEXT NOT NULL,
    method                  TEXT NOT NULL,
    pooled_effect           NUMERIC(18,8),
    pooled_ci_low           NUMERIC(18,8),
    pooled_ci_high          NUMERIC(18,8),
    heterogeneity_i2        NUMERIC(18,8),
    tau2                    NUMERIC(18,8),
    q_statistic             NUMERIC(18,8),
    study_count             INTEGER,
    total_sample_size       INTEGER,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              TEXT,
    notes                   TEXT,
    CONSTRAINT chk_meta_analysis_model_type CHECK (model_type IN ('fixed', 'random')),
    CONSTRAINT uq_meta_analysis UNIQUE (clinical_finding_id, outcome_measure_id, model_type, method)
);

COMMENT ON TABLE meta_analysis IS
'Pooled analysis definition and results for a clinical finding.';
COMMENT ON COLUMN meta_analysis.heterogeneity_i2 IS
'Heterogeneity estimate I-squared, where calculable.';
COMMENT ON COLUMN meta_analysis.tau2 IS
'Between-study variance estimate for random-effects models.';
COMMENT ON COLUMN meta_analysis.q_statistic IS
'Cochran Q statistic, where available.';

ALTER TABLE clinical_finding
    ADD CONSTRAINT fk_clinical_finding_meta_analysis
    FOREIGN KEY (meta_analysis_id) REFERENCES meta_analysis(meta_analysis_id);

CREATE TABLE meta_analysis_member (
    meta_analysis_member_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meta_analysis_id        BIGINT NOT NULL REFERENCES meta_analysis(meta_analysis_id) ON DELETE CASCADE,
    outcome_id              BIGINT NOT NULL REFERENCES outcome(outcome_id) ON DELETE CASCADE,
    standardized_effect_id  BIGINT REFERENCES standardized_effect(standardized_effect_id),
    inclusion_reason        TEXT,
    exclusion_reason        TEXT,
    weight_used             NUMERIC(18,8),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_meta_analysis_member UNIQUE (meta_analysis_id, outcome_id)
);

COMMENT ON TABLE meta_analysis_member IS
'Membership table identifying which outcomes were considered in a meta-analysis and what statistical weight they contributed.';

CREATE TABLE clinical_finding_version (
    clinical_finding_version_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    version_number          INTEGER NOT NULL,
    model_version           TEXT,
    evidence_cutoff_date    DATE,
    generated_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    algorithm_version_id    BIGINT REFERENCES algorithm_version(algorithm_version_id),
    notes                   TEXT,
    CONSTRAINT uq_clinical_finding_version UNIQUE (clinical_finding_id, version_number)
);

COMMENT ON TABLE clinical_finding_version IS
'Versioned snapshot of synthesized evidence so historical CDS outputs can be reconstructed exactly.';

CREATE TABLE clinical_finding_study_map (
    clinical_finding_study_map_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    study_id                BIGINT NOT NULL REFERENCES study(study_id) ON DELETE CASCADE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_clinical_finding_study_map UNIQUE (clinical_finding_id, study_id)
);

COMMENT ON TABLE clinical_finding_study_map IS
'Tracks which studies contributed to a synthesized finding.';

CREATE TABLE evidence_consistency (
    evidence_consistency_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    study_count             INTEGER NOT NULL,
    i2                      NUMERIC(18,8),
    direction_agreement     NUMERIC(18,8),
    consistency_score       NUMERIC(18,8),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_evidence_consistency_finding UNIQUE (clinical_finding_id)
);

COMMENT ON TABLE evidence_consistency IS
'Derived consistency and heterogeneity metrics associated with a clinical finding.';

CREATE TABLE evidence_score_calculation (
    evidence_score_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    framework_id            BIGINT NOT NULL REFERENCES evidence_framework(framework_id),
    score                   NUMERIC(18,8) NOT NULL,
    grade                   TEXT,
    calculation_version     TEXT NOT NULL,
    calculated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_evidence_score_grade
        CHECK (grade IS NULL OR grade IN ('High', 'Moderate', 'Low', 'Very Low'))
);

COMMENT ON TABLE evidence_score_calculation IS
'Final deterministic evidence score for a clinical finding under a given framework and implementation version.';

CREATE TABLE evidence_score_contribution (
    evidence_score_contribution_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evidence_score_id       BIGINT NOT NULL REFERENCES evidence_score_calculation(evidence_score_id) ON DELETE CASCADE,
    component_id            BIGINT NOT NULL REFERENCES evidence_component(component_id),
    component_score         NUMERIC(18,8) NOT NULL,
    weighted_contribution   NUMERIC(18,8) NOT NULL,
    CONSTRAINT uq_evidence_score_contribution UNIQUE (evidence_score_id, component_id)
);

COMMENT ON TABLE evidence_score_contribution IS
'Per-component contribution to the final evidence score, enabling reviewable explainability.';

CREATE TABLE evidence_score_component (
    evidence_score_component_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    component_type          TEXT NOT NULL,
    value                   NUMERIC(18,8) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE evidence_score_component IS
'Simple reviewer-facing component breakdown associated directly with a clinical finding.';

-- ============================================================================
-- 9. CDS LAYER / EXPLAINABILITY
-- ============================================================================

CREATE TABLE recommendation (
    recommendation_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    concept_id              BIGINT NOT NULL REFERENCES concept(concept_id),
    product_id              BIGINT REFERENCES product(product_id),
    title                   TEXT NOT NULL,
    clinical_intent         TEXT,
    recommendation_text     TEXT NOT NULL,
    version                 TEXT NOT NULL,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recommendation_identity UNIQUE (concept_id, product_id, title, version)
);

COMMENT ON TABLE recommendation IS
'Reusable clinician-facing guidance artifact keyed by clinical concept and optionally product. Distinct from evidence synthesis and later instantiated for a patient context.';

CREATE TABLE recommendation_evidence (
    recommendation_evidence_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_id       BIGINT NOT NULL REFERENCES recommendation(recommendation_id) ON DELETE CASCADE,
    clinical_finding_id     BIGINT NOT NULL REFERENCES clinical_finding(clinical_finding_id) ON DELETE CASCADE,
    strength_contribution   NUMERIC(18,8) NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recommendation_evidence UNIQUE (recommendation_id, clinical_finding_id)
);

COMMENT ON TABLE recommendation_evidence IS
'Explicit support map linking reusable recommendations to the synthesized findings that justify them.';

CREATE TABLE recommendation_rule (
    recommendation_rule_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_id       BIGINT NOT NULL REFERENCES recommendation(recommendation_id) ON DELETE CASCADE,
    rule_type               TEXT NOT NULL,
    description             TEXT,
    logic_json              JSONB NOT NULL,
    priority                INTEGER NOT NULL DEFAULT 100,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recommendation_rule_type
        CHECK (rule_type IN ('inclusion', 'exclusion', 'caution'))
);

COMMENT ON TABLE recommendation_rule IS
'Rule engine table describing when a reusable recommendation applies. Logic is stored as JSONB for flexibility and forward compatibility.';

CREATE TABLE patient_context (
    patient_context_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_context_key    TEXT,
    age                     INTEGER,
    sex                     TEXT,
    diagnoses               JSONB,
    symptoms                JSONB,
    current_medications     JSONB,
    contraindications       JSONB,
    additional_context      JSONB,
    is_ephemeral            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_patient_context_age CHECK (age IS NULL OR age >= 0)
);

COMMENT ON TABLE patient_context IS
'Minimal patient-specific context required to drive recommendation selection and safety checks. Intended to avoid replicating the full EMR.';
COMMENT ON COLUMN patient_context.is_ephemeral IS
'Whether the row is intended as session-scoped/temporary rather than durable clinical record storage.';

CREATE TABLE recommendation_instance (
    recommendation_instance_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_id       BIGINT NOT NULL REFERENCES recommendation(recommendation_id) ON DELETE CASCADE,
    patient_context_id      BIGINT REFERENCES patient_context(patient_context_id) ON DELETE SET NULL,
    generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    evidence_score          NUMERIC(18,8),
    confidence_level        TEXT,
    algorithm_version       TEXT,
    llm_run_id              BIGINT REFERENCES llm_run(llm_run_id),
    framework_id            BIGINT REFERENCES evidence_framework(framework_id),
    status                  TEXT NOT NULL DEFAULT 'generated',
    CONSTRAINT chk_recommendation_instance_confidence
        CHECK (confidence_level IS NULL OR confidence_level IN ('High', 'Moderate', 'Low', 'Very Low')),
    CONSTRAINT chk_recommendation_instance_status
        CHECK (status IN ('generated', 'reviewed', 'accepted', 'rejected', 'superseded'))
);

COMMENT ON TABLE recommendation_instance IS
'Patient-specific recommendation generation event. This is the medico-legal audit history of what the system produced for a specific context.';

CREATE TABLE recommendation_explanation (
    recommendation_explanation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_instance_id BIGINT NOT NULL REFERENCES recommendation_instance(recommendation_instance_id) ON DELETE CASCADE,
    evidence_summary        TEXT,
    benefit_summary         TEXT,
    risk_summary            TEXT,
    certainty_explanation   TEXT,
    generated_by            TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recommendation_explanation_instance UNIQUE (recommendation_instance_id)
);

COMMENT ON TABLE recommendation_explanation IS
'Core explainability artifact attached to a recommendation instance. Intended for clinician display and regulatory transparency.';

CREATE TABLE explanation_dimension (
    explanation_dimension_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_explanation_id BIGINT NOT NULL REFERENCES recommendation_explanation(recommendation_explanation_id) ON DELETE CASCADE,
    dimension_type          TEXT NOT NULL,
    source_entity_type      TEXT,
    source_entity_id        BIGINT,
    contribution_score      NUMERIC(18,8),
    display_order           INTEGER NOT NULL DEFAULT 1
);

COMMENT ON TABLE explanation_dimension IS
'Structured explanation dimensions used to break an explanation into transparent components such as pooled effect, bias, consistency, subgroup effect, and adverse events.';

CREATE TABLE safety_rule (
    safety_rule_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id              BIGINT REFERENCES product(product_id),
    concept_id              BIGINT REFERENCES concept(concept_id),
    severity                TEXT NOT NULL,
    rule_logic              JSONB NOT NULL,
    description             TEXT,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_safety_rule_severity
        CHECK (severity IN ('warning', 'contraindicated'))
);

COMMENT ON TABLE safety_rule IS
'Safety or contraindication rule applied during recommendation generation. Supports regulator-facing safety guardrails.';

CREATE TABLE safety_alert (
    safety_alert_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_instance_id BIGINT NOT NULL REFERENCES recommendation_instance(recommendation_instance_id) ON DELETE CASCADE,
    safety_rule_id          BIGINT NOT NULL REFERENCES safety_rule(safety_rule_id),
    alert_text              TEXT NOT NULL,
    severity                TEXT NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_safety_alert_severity
        CHECK (severity IN ('warning', 'contraindicated'))
);

COMMENT ON TABLE safety_alert IS
'Materialized safety alert produced for a patient-specific recommendation instance.';

CREATE TABLE recommendation_strength (
    recommendation_strength_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_id       BIGINT NOT NULL REFERENCES recommendation(recommendation_id) ON DELETE CASCADE,
    aggregate_score         NUMERIC(18,8) NOT NULL,
    strength_label          TEXT NOT NULL,
    framework_id            BIGINT REFERENCES evidence_framework(framework_id),
    calculated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recommendation_strength_label
        CHECK (strength_label IN ('Strong', 'Conditional', 'Weak'))
);

COMMENT ON TABLE recommendation_strength IS
'Derived recommendation-strength label and score. Separates evidence certainty from clinician-action strength.';

CREATE TABLE recommendation_snapshot (
    recommendation_snapshot_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_instance_id BIGINT NOT NULL REFERENCES recommendation_instance(recommendation_instance_id) ON DELETE CASCADE,
    display_json            JSONB NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE recommendation_snapshot IS
'Stores the exact clinician-facing snapshot rendered at the time of recommendation generation, protecting against later UI disputes.';

-- ============================================================================
-- 10. REGULATORY DEFENSIBILITY / TRACEABILITY
-- ============================================================================

CREATE TABLE evidence_trace (
    evidence_trace_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recommendation_id       BIGINT NOT NULL REFERENCES recommendation(recommendation_id) ON DELETE CASCADE,
    clinical_finding_version_id BIGINT NOT NULL REFERENCES clinical_finding_version(clinical_finding_version_id) ON DELETE CASCADE,
    generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_evidence_trace UNIQUE (recommendation_id, clinical_finding_version_id)
);

COMMENT ON TABLE evidence_trace IS
'Critical replay table linking reusable recommendations to the exact synthesized evidence version that justified them. This supports regulatory replay from recommendation to finding version to study to paper to source artifact.';

-- ============================================================================
-- 11. OPTIONAL HUMAN VS LLM EXTRACTION BENCHMARKING
-- Included because benchmarking human and model extraction quality is a likely
-- near-term requirement for this platform and materially improves defensibility.
-- ============================================================================

CREATE TABLE extraction_run (
    extraction_run_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paper_id                BIGINT NOT NULL REFERENCES paper(paper_id) ON DELETE CASCADE,
    run_type                TEXT NOT NULL,
    llm_run_id              BIGINT REFERENCES llm_run(llm_run_id),
    human_reviewer          TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_extraction_run_type
        CHECK (run_type IN ('llm', 'human', 'hybrid', 'gold_standard'))
);

COMMENT ON TABLE extraction_run IS
'Logical extraction session for a paper. Supports comparing multiple extraction methods, including human, LLM, hybrid, and adjudicated gold-standard runs.';

CREATE TABLE extraction_assertion (
    extraction_assertion_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    extraction_run_id       BIGINT NOT NULL REFERENCES extraction_run(extraction_run_id) ON DELETE CASCADE,
    entity_type             TEXT NOT NULL,
    entity_id               BIGINT,
    assertion_type          TEXT NOT NULL,
    assertion_payload       JSONB NOT NULL,
    confidence_score        NUMERIC(18,8),
    source_span_text        TEXT,
    source_page_ref         TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE extraction_assertion IS
'Normalized assertion emitted by an extraction run. This supports row-level benchmarking between extraction sources without forcing every comparison to operate against final relational tables only.';

CREATE TABLE extraction_comparison (
    extraction_comparison_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    left_extraction_run_id  BIGINT NOT NULL REFERENCES extraction_run(extraction_run_id) ON DELETE CASCADE,
    right_extraction_run_id BIGINT NOT NULL REFERENCES extraction_run(extraction_run_id) ON DELETE CASCADE,
    comparison_scope        TEXT NOT NULL,
    similarity_score        NUMERIC(18,8),
    precision_score         NUMERIC(18,8),
    recall_score            NUMERIC(18,8),
    f1_score                NUMERIC(18,8),
    comparison_notes        TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_extraction_comparison_scope
        CHECK (comparison_scope IN ('paper', 'study', 'outcome', 'finding', 'recommendation', 'custom'))
);

COMMENT ON TABLE extraction_comparison IS
'Benchmark result comparing two extraction runs, such as human versus LLM, or LLM version A versus B.';

-- ============================================================================
-- 12. INDEXES
-- ============================================================================

CREATE INDEX idx_concept_display_text ON concept USING btree (display_text);
CREATE INDEX idx_concept_relationship_source ON concept_relationship (source_concept_id);
CREATE INDEX idx_concept_relationship_target ON concept_relationship (target_concept_id);

CREATE INDEX idx_paper_title ON paper USING btree (title);
CREATE INDEX idx_paper_publication_date ON paper (publication_date);
CREATE INDEX idx_paper_journal_id ON paper (journal_id);

CREATE INDEX idx_study_type_id ON study (study_type_id);
CREATE INDEX idx_study_registry_id ON study (registry_id);
CREATE INDEX idx_population_characteristic_study_id ON population_characteristic (study_id);

CREATE INDEX idx_arm_study_id ON arm (study_id);
CREATE INDEX idx_dose_arm_id ON dose (arm_id);
CREATE INDEX idx_product_ingredient_ingredient_id ON product_ingredient (ingredient_id);

CREATE INDEX idx_outcome_arm_id ON outcome (arm_id);
CREATE INDEX idx_outcome_comparator_arm_id ON outcome (comparator_arm_id);
CREATE INDEX idx_outcome_concept_id ON outcome (concept_id);
CREATE INDEX idx_outcome_measure_id ON outcome (outcome_measure_id);
CREATE INDEX idx_outcome_effect_type ON outcome (effect_type);
CREATE INDEX idx_outcome_adverse_event_outcome_id ON outcome_adverse_event (outcome_id);

CREATE INDEX idx_risk_of_bias_study_id ON risk_of_bias (study_id);
CREATE INDEX idx_risk_of_bias_outcome_id ON risk_of_bias (outcome_id);
CREATE INDEX idx_risk_of_bias_domain_id ON risk_of_bias (bias_domain_id);

CREATE INDEX idx_generated_text_entity ON generated_text (entity_type, entity_id);

CREATE INDEX idx_outcome_component_score_outcome_id ON outcome_evidence_component_score (outcome_id);
CREATE INDEX idx_standardized_effect_outcome_id ON standardized_effect (outcome_id);
CREATE INDEX idx_meta_analysis_finding_id ON meta_analysis (clinical_finding_id);
CREATE INDEX idx_meta_analysis_member_meta_id ON meta_analysis_member (meta_analysis_id);

CREATE INDEX idx_clinical_finding_concept_id ON clinical_finding (concept_id);
CREATE INDEX idx_clinical_finding_product_id ON clinical_finding (product_id);
CREATE INDEX idx_clinical_finding_study_map_finding_id ON clinical_finding_study_map (clinical_finding_id);
CREATE INDEX idx_evidence_score_calculation_finding_id ON evidence_score_calculation (clinical_finding_id);

CREATE INDEX idx_recommendation_concept_id ON recommendation (concept_id);
CREATE INDEX idx_recommendation_product_id ON recommendation (product_id);
CREATE INDEX idx_recommendation_rule_logic_json_gin ON recommendation_rule USING gin (logic_json);
CREATE INDEX idx_patient_context_diagnoses_gin ON patient_context USING gin (diagnoses);
CREATE INDEX idx_patient_context_symptoms_gin ON patient_context USING gin (symptoms);
CREATE INDEX idx_patient_context_medications_gin ON patient_context USING gin (current_medications);
CREATE INDEX idx_patient_context_contras_gin ON patient_context USING gin (contraindications);
CREATE INDEX idx_safety_rule_logic_gin ON safety_rule USING gin (rule_logic);
CREATE INDEX idx_recommendation_instance_recommendation_id ON recommendation_instance (recommendation_id);
CREATE INDEX idx_recommendation_instance_context_id ON recommendation_instance (patient_context_id);

CREATE INDEX idx_extraction_run_paper_id ON extraction_run (paper_id);
CREATE INDEX idx_extraction_assertion_run_id ON extraction_assertion (extraction_run_id);
CREATE INDEX idx_extraction_assertion_payload_gin ON extraction_assertion USING gin (assertion_payload);

-- ============================================================================
-- 13. UPDATED_AT TRIGGERS
-- ============================================================================

CREATE TRIGGER trg_concept_updated_at
BEFORE UPDATE ON concept
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_paper_updated_at
BEFORE UPDATE ON paper
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_study_updated_at
BEFORE UPDATE ON study
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_clinical_finding_updated_at
BEFORE UPDATE ON clinical_finding
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_recommendation_updated_at
BEFORE UPDATE ON recommendation
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 14. SEED REFERENCE VALUES (OPTIONAL BUT HELPFUL)
-- These inserts are safe/idempotent patterns for common baseline rows.
-- ============================================================================

INSERT INTO evidence_framework (name, description, is_active)
VALUES
    ('Default Cannabis Evidence Framework v1', 'Initial deterministic framework for cannabis evidence assessment.', TRUE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO bias_domain (name, description)
VALUES
    ('Selection', 'Bias arising from how participants were selected or allocated.'),
    ('Detection', 'Bias arising from outcome measurement or assessor knowledge.'),
    ('Reporting', 'Bias arising from selective reporting of results.'),
    ('Attrition', 'Bias arising from differential dropout or missing data.'),
    ('Performance', 'Bias arising from differences in care or exposure outside the intervention.'),
    ('Conflict of Interest', 'Bias potentially arising from sponsorship or author financial relationships.')
ON CONFLICT (name) DO NOTHING;

COMMIT;
