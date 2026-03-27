-- PostgreSQL Schema for ERI (Evidence Research Instrument)
-- Optimized for SaMD (Software as a Medical Device) Class II compliance.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

--------------------------------------------------------------------------------
-- LAYER 0: ENUMERATIONS (Domain Constraints)
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'concept_system') THEN
        CREATE TYPE concept_system AS ENUM ('ICD11', 'SNOMED-CT', 'RxNorm', 'Custom');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'concept_rel_type') THEN
        CREATE TYPE concept_rel_type AS ENUM ('is_a', 'treats', 'causes', 'associated_with');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'arm_type') THEN
        CREATE TYPE arm_type AS ENUM ('intervention', 'placebo', 'active_comparator');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'effect_type') THEN
        CREATE TYPE effect_type AS ENUM ('RR', 'OR', 'SMD', 'Mean Difference');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bias_rating') THEN
        CREATE TYPE bias_rating AS ENUM ('Low', 'High', 'Unclear', 'Some Concerns');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rule_type') THEN
        CREATE TYPE rule_type AS ENUM ('inclusion', 'exclusion', 'caution');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'severity_level') THEN
        CREATE TYPE severity_level AS ENUM ('warning', 'contraindicated');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rec_strength_label') THEN
        CREATE TYPE rec_strength_label AS ENUM ('Strong', 'Conditional', 'Weak');
    END IF;
END $$;

--------------------------------------------------------------------------------
-- 1️⃣ REFERENCE & TERMINOLOGY LAYER
-- Intent: Standardize clinical/pharmacological findings across global datasets[cite: 16].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Concept (
    concept_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    system concept_system NOT NULL,
    code VARCHAR(100) NOT NULL, -- Canonical ID (e.g., ICD-11 code) [cite: 25]
    display_text TEXT NOT NULL,
    UNIQUE(system, code)
);
COMMENT ON COLUMN Concept.code IS 'Canonical identifier enabling interoperability and deduplication[cite: 25].';

CREATE TABLE IF NOT EXISTS ConceptRelationship (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_concept_id UUID REFERENCES Concept(concept_id) ON DELETE CASCADE,
    target_concept_id UUID REFERENCES Concept(concept_id) ON DELETE CASCADE,
    relationship_type concept_rel_type NOT NULL
);

CREATE TABLE IF NOT EXISTS Registry (
    registry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    organization VARCHAR(255),
    url TEXT
);

--------------------------------------------------------------------------------
-- 2️⃣ PUBLICATION LAYER
-- Intent: Track source documents and their bibliometrics[cite: 49].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Journal (
    journal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    rating DECIMAL(3, 2) -- Optional credibility prior [cite: 332]
);

CREATE TABLE IF NOT EXISTS Publisher (
    publisher_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    rating DECIMAL(3, 2)
);

CREATE TABLE IF NOT EXISTS Paper (
    paper_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    doi VARCHAR(100) UNIQUE,
    url TEXT,
    retrieval_date DATE DEFAULT CURRENT_DATE,
    journal_id UUID REFERENCES Journal(journal_id),
    publisher_id UUID REFERENCES Publisher(publisher_id),
    full_text_pdf BYTEA, -- Actual PDF storage 
    is_peer_reviewed BOOLEAN DEFAULT TRUE,
    altmetric_score INTEGER
);

CREATE TABLE IF NOT EXISTS Author (
    author_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    orcid VARCHAR(20) UNIQUE -- Enables author disambiguation [cite: 74]
);

CREATE TABLE IF NOT EXISTS PaperAuthor (
    paper_id UUID REFERENCES Paper(paper_id) ON DELETE CASCADE,
    author_id UUID REFERENCES Author(author_id) ON DELETE CASCADE,
    author_order INTEGER, -- Distinguishes first/senior authors [cite: 85]
    is_corresponding BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (paper_id, author_id)
);

--------------------------------------------------------------------------------
-- 3️⃣ STUDY LAYER
-- Intent: Isolate the clinical investigation logic from its publication format[cite: 99].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Institution (
    institution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    rating DECIMAL(3, 2)
);

CREATE TABLE IF NOT EXISTS StudyType (
    study_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    rating DECIMAL(3, 2) -- Prior quality weight (e.g., RCT > Observational) [cite: 121]
);

CREATE TABLE IF NOT EXISTS Study (
    study_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    study_type_id UUID REFERENCES StudyType(study_type_id),
    registry_id UUID REFERENCES Registry(registry_id),
    registry_identifier VARCHAR(100), -- Registry ID for external verification [cite: 111]
    sample_size INTEGER,
    institution_id UUID REFERENCES Institution(institution_id),
    sponsor TEXT -- Identified confounder for bias modeling [cite: 112]
);

CREATE TABLE IF NOT EXISTS PopulationCharacteristic (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    study_id UUID REFERENCES Study(study_id) ON DELETE CASCADE,
    characteristic_type VARCHAR(100), -- e.g., 'mean_age', '%female' [cite: 133]
    value DECIMAL,
    unit VARCHAR(50),
    notes TEXT
);

--------------------------------------------------------------------------------
-- 4️⃣ INTERVENTION MODEL
-- Intent: Model specific cannabis compositions and dosing regimens[cite: 134].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Product (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    format VARCHAR(100), -- flower, oil, capsule [cite: 145]
    route VARCHAR(100), -- Critical PK determinant [cite: 146]
    description TEXT
);

CREATE TABLE IF NOT EXISTS Ingredient (
    ingredient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL -- THC, CBD, Terpenes, etc. [cite: 154]
);

CREATE TABLE IF NOT EXISTS ProductIngredient (
    product_id UUID REFERENCES Product(product_id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES Ingredient(ingredient_id) ON DELETE CASCADE,
    amount DECIMAL,
    unit VARCHAR(50),
    PRIMARY KEY (product_id, ingredient_id)
);

CREATE TABLE IF NOT EXISTS Arm (
    arm_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    study_id UUID REFERENCES Study(study_id) ON DELETE CASCADE,
    arm_type arm_type NOT NULL,
    size INTEGER,
    product_id UUID REFERENCES Product(product_id)
);

CREATE TABLE IF NOT EXISTS Dose (
    dose_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    arm_id UUID REFERENCES Arm(arm_id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES Ingredient(ingredient_id),
    amount DECIMAL,
    unit VARCHAR(50),
    frequency VARCHAR(100),
    duration VARCHAR(100)
);

--------------------------------------------------------------------------------
-- 5️⃣ OUTCOME MODEL
-- Intent: Structured capture of efficacy and adverse events[cite: 192].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS OutcomeMeasure (
    outcome_measure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255), -- Normalizes scales (VAS pain, etc.) [cite: 201]
    unit VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS Outcome (
    outcome_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    arm_id UUID REFERENCES Arm(arm_id) ON DELETE RESTRICT,
    comparator_arm_id UUID REFERENCES Arm(arm_id) ON DELETE RESTRICT,
    concept_id UUID REFERENCES Concept(concept_id), -- Target condition/symptom
    outcome_measure_id UUID REFERENCES OutcomeMeasure(outcome_measure_id),
    effect_size DECIMAL,
    effect_type effect_type, -- e.g., SMD, Mean Difference [cite: 220]
    ci_low DECIMAL,
    ci_high DECIMAL,
    p_value DECIMAL,
    timepoint VARCHAR(100), -- Acute vs Chronic [cite: 222]
    summary TEXT
);

CREATE TABLE IF NOT EXISTS OutcomeAdverseEvent (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outcome_id UUID REFERENCES Outcome(outcome_id) ON DELETE CASCADE,
    concept_id UUID REFERENCES Concept(concept_id), -- Specific harm code
    event_rate DECIMAL
);

--------------------------------------------------------------------------------
-- 6️⃣ QUALITY & BIAS
-- Intent: Quantifiable assessment of research reliability[cite: 233].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS BiasDomain (
    bias_domain_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL -- Selection, Detection, Reporting [cite: 240]
);

CREATE TABLE IF NOT EXISTS RiskOfBias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    study_id UUID REFERENCES Study(study_id) ON DELETE CASCADE,
    outcome_id UUID REFERENCES Outcome(outcome_id) ON DELETE SET NULL,
    bias_domain_id UUID REFERENCES BiasDomain(bias_domain_id),
    rating bias_rating NOT NULL
);

--------------------------------------------------------------------------------
-- 7️⃣ PROVENANCE (LLM AUDIT TRAIL)
-- Intent: Regulatory reproducibility for AI-generated data[cite: 252].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS LLMRun (
    llm_run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name VARCHAR(100) NOT NULL,
    prompt_version VARCHAR(50) NOT NULL,
    temperature DECIMAL(3, 2),
    run_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_human_validated BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS GeneratedText (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    llm_run_id UUID REFERENCES LLMRun(llm_run_id) ON DELETE CASCADE,
    entity_type VARCHAR(50), -- e.g., 'Paper', 'Outcome'
    entity_id UUID,
    text_output TEXT
);

--------------------------------------------------------------------------------
-- 8️⃣ EVIDENCE AGGREGATION & SCORING
-- Intent: Pooled conclusions across the literature[cite: 277].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ClinicalFinding (
    clinical_finding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept_id UUID REFERENCES Concept(concept_id),
    product_id UUID REFERENCES Product(product_id),
    effect_direction VARCHAR(50),
    aggregate_certainty VARCHAR(50),
    weighted_effect DECIMAL,
    sum_sample_size INTEGER,
    consistency_score DECIMAL -- Heterogeneity metric [cite: 292]
);

CREATE TABLE IF NOT EXISTS EvidenceFramework (
    framework_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255), -- "GRADE" or "RonsWeb v1.0" [cite: 392]
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS EvidenceDimension (
    dimension_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    framework_id UUID REFERENCES EvidenceFramework(framework_id) ON DELETE CASCADE,
    name VARCHAR(100), -- Risk of Bias, Consistency, etc. [cite: 409]
    weight DECIMAL(3, 2)
);

CREATE TABLE IF NOT EXISTS OutcomeEvidenceDimensionScore (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outcome_id UUID REFERENCES Outcome(outcome_id) ON DELETE CASCADE,
    dimension_id UUID REFERENCES EvidenceDimension(dimension_id) ON DELETE CASCADE,
    raw_value DECIMAL,
    normalized_score DECIMAL,
    calculation_method VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS EvidenceScoreCalculation (
    evidence_score_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinical_finding_id UUID REFERENCES ClinicalFinding(clinical_finding_id) ON DELETE CASCADE,
    framework_id UUID REFERENCES EvidenceFramework(framework_id),
    score DECIMAL,
    grade VARCHAR(50),
    calculation_version VARCHAR(50),
    calculated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------------------------------------
-- 9️⃣ CDS LAYER (The Clinician-Facing System)
-- Intent: Turn synthesis into actionable, patient-specific advice[cite: 314, 441].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Recommendation (
    recommendation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept_id UUID REFERENCES Concept(concept_id), -- Primary condition
    product_id UUID REFERENCES Product(product_id),
    title VARCHAR(255),
    clinical_intent VARCHAR(255), -- e.g., 'reduce anxiety' [cite: 471]
    recommendation_text TEXT,
    version VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS RecommendationRule (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recommendation_id UUID REFERENCES Recommendation(recommendation_id) ON DELETE CASCADE,
    rule_type rule_type,
    logic_json JSONB, -- Defines structured reasoning [cite: 503]
    priority INTEGER
);
COMMENT ON COLUMN RecommendationRule.logic_json IS 'Schema: {"age": {"min": int}, "diagnosis": string, "contraindications": [string]} .';

CREATE TABLE IF NOT EXISTS PatientContext (
    context_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    age INTEGER,
    sex VARCHAR(20),
    diagnoses JSONB, -- List of ICD-11/SNOMED IDs
    symptoms JSONB,
    current_medications JSONB,
    contraindications JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON COLUMN PatientContext.diagnoses IS 'Array of Concept IDs representing patient history.';

CREATE TABLE IF NOT EXISTS RecommendationInstance (
    instance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recommendation_id UUID REFERENCES Recommendation(recommendation_id),
    context_id UUID REFERENCES PatientContext(context_id),
    generated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_score DECIMAL,
    confidence_level VARCHAR(50),
    algorithm_version VARCHAR(50) -- Critical for medico-legal audit [cite: 538, 540]
);

CREATE TABLE IF NOT EXISTS RecommendationExplanation (
    explanation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    instance_id UUID REFERENCES RecommendationInstance(instance_id) ON DELETE CASCADE,
    evidence_summary TEXT, -- "Moderate-certainty evidence from 6 RCTs..." [cite: 556]
    benefit_summary TEXT,
    risk_summary TEXT,
    certainty_explanation TEXT,
    generated_by_llm UUID REFERENCES LLMRun(llm_run_id)
);

CREATE TABLE IF NOT EXISTS SafetyRule (
    safety_rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES Product(product_id),
    concept_id UUID REFERENCES Concept(concept_id),
    severity severity_level,
    rule_logic JSONB, -- e.g., {"history": ["psychosis"]} [cite: 591]
    description TEXT
);

CREATE TABLE IF NOT EXISTS SafetyAlert (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    instance_id UUID REFERENCES RecommendationInstance(instance_id) ON DELETE CASCADE,
    safety_rule_id UUID REFERENCES SafetyRule(safety_rule_id),
    alert_text TEXT,
    severity severity_level
);

--------------------------------------------------------------------------------
-- 🔟 REGULATORY DEFENSIBILITY PILLAR A
-- Intent: Enable "Replaying" of a clinical decision[cite: 651, 654, 681].
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS EvidenceTrace (
    trace_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recommendation_id UUID REFERENCES Recommendation(recommendation_id),
    clinical_finding_id UUID REFERENCES ClinicalFinding(clinical_finding_id),
    generated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE EvidenceTrace IS 'Links recommendations back to specific findings, which link to studies, papers, and raw PDFs [cite: 676-681].';

--------------------------------------------------------------------------------
-- INDEXES FOR PERFORMANCE
--------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_concept_code ON Concept(code);
CREATE INDEX IF NOT EXISTS idx_outcome_concept ON Outcome(concept_id);
CREATE INDEX IF NOT EXISTS idx_paper_doi ON Paper(doi);
CREATE INDEX IF NOT EXISTS idx_study_registry ON Study(registry_identifier);
CREATE INDEX IF NOT EXISTS idx_rec_rule_logic ON RecommendationRule USING GIN (logic_json);
CREATE INDEX IF NOT EXISTS idx_patient_ctx_diagnoses ON PatientContext USING GIN (diagnoses);