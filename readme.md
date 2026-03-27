# GuideRx MVP

GuideRx MVP is a clinical evidence platform focused on cannabis-related interventions, designed to support safer, explainable treatment recommendations with a strong regulatory and audit trail foundation.

## What this project does

- Ingests and normalizes medical terminology (ICD-11, SNOMED-CT, RxNorm, and custom concepts).
- Tracks publications, studies, trial arms, products, ingredients, dosing, outcomes, and adverse events.
- Scores evidence quality using configurable frameworks (for example, GRADE-like dimensions such as bias and consistency).
- Produces clinician-facing recommendations that are context-aware, rule-driven, and linked to supporting evidence.
- Captures LLM generation provenance and decision traceability to support SaMD Class II defensibility.

## Current repository focus

The primary artifact in this repository is a PostgreSQL schema located at `Implementation_instructions/sql_schema.sql`.

That schema defines a layered data model:

1. **Reference & terminology**: canonical concepts and relationships.
2. **Publication & study**: papers, authors, registries, and study metadata.
3. **Intervention & outcomes**: products, doses, trial arms, efficacy, and harms.
4. **Quality & aggregation**: risk of bias, pooled findings, and evidence scoring.
5. **CDS (clinical decision support)**: recommendation logic, patient context, safety alerts, and explanations.
6. **Regulatory traceability**: evidence trace links and LLM run metadata for reproducibility.

## Why this matters

Healthcare decision support systems need to be transparent, reproducible, and clinically grounded. This project structures evidence end-to-end so recommendations can be explained, audited, and tied back to source literature.

## Next steps (suggested)

- Add schema migrations and seed data for local development.
- Add API/service layers for evidence ingestion and recommendation generation.
- Add validation tests for recommendation rules and traceability constraints.
