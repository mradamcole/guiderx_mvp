-- Mock medicinal cannabis seed data for GuideRx MVP.
-- Designed for demo and testing only (not real clinical guidance).
--
-- Canonical mock taxonomy used in this seed:
-- - Product.format: oil, capsule, flower, spray
-- - Product.route: oral, inhalation, oromucosal
-- - Units: mg/mL, mg/capsule, %, mg/spray, mL, inhalations
-- - Frequency: once_daily, twice_daily, bedtime, three_times_daily, as_needed
-- - Duration: 14 days, 28 days, 8 weeks, chronic

BEGIN;

--------------------------------------------------------------------------------
-- 1) Concepts (indications, adverse events, and risk factors)
--------------------------------------------------------------------------------
INSERT INTO Concept (concept_id, system, code, display_text) VALUES
('10000000-0000-0000-0000-000000000001', 'Custom', 'CAN-CP', 'Chronic non-cancer pain'),
('10000000-0000-0000-0000-000000000002', 'Custom', 'CAN-NP', 'Neuropathic pain'),
('10000000-0000-0000-0000-000000000003', 'Custom', 'CAN-SPASTICITY', 'Spasticity symptoms'),
('10000000-0000-0000-0000-000000000004', 'Custom', 'CAN-SLEEP', 'Insomnia related to chronic symptoms'),
('10000000-0000-0000-0000-000000000005', 'Custom', 'CAN-ANX-SX', 'Anxiety symptoms (adjunctive)'),
('10000000-0000-0000-0000-000000000006', 'Custom', 'CAN-CINV', 'Chemotherapy-induced nausea and vomiting (adjunctive)'),
('10000000-0000-0000-0000-000000000007', 'Custom', 'CAN-BTP', 'Breakthrough pain episodes'),
('10000000-0000-0000-0000-000000000008', 'Custom', 'CAN-AE-DIZZ', 'Dizziness adverse event'),
('10000000-0000-0000-0000-000000000009', 'Custom', 'CAN-AE-SED', 'Sedation or somnolence adverse event'),
('10000000-0000-0000-0000-000000000010', 'Custom', 'CAN-AE-ANX', 'Paradoxical anxiety adverse event'),
('10000000-0000-0000-0000-000000000011', 'Custom', 'CAN-RISK-PSYCHOSIS', 'History of psychotic disorder'),
('10000000-0000-0000-0000-000000000012', 'Custom', 'CAN-RISK-PREGNANCY', 'Pregnancy'),
('10000000-0000-0000-0000-000000000013', 'Custom', 'CAN-RISK-BREASTFEED', 'Breastfeeding'),
('10000000-0000-0000-0000-000000000014', 'Custom', 'CAN-RISK-UNSTABLE-CVD', 'Unstable cardiovascular disease'),
('10000000-0000-0000-0000-000000000015', 'Custom', 'CAN-RISK-FRAILTY', 'Frailty or high falls risk'),
('10000000-0000-0000-0000-000000000016', 'Custom', 'CAN-RISK-HEPATIC', 'Hepatic impairment'),
('10000000-0000-0000-0000-000000000017', 'Custom', 'CAN-RISK-SUD', 'History of substance use disorder')
ON CONFLICT (concept_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 2) Ingredients
--------------------------------------------------------------------------------
INSERT INTO Ingredient (ingredient_id, name) VALUES
('20000000-0000-0000-0000-000000000001', 'THC'),
('20000000-0000-0000-0000-000000000002', 'CBD'),
('20000000-0000-0000-0000-000000000003', 'CBG'),
('20000000-0000-0000-0000-000000000004', 'CBN'),
('20000000-0000-0000-0000-000000000005', 'CBC'),
('20000000-0000-0000-0000-000000000006', 'myrcene'),
('20000000-0000-0000-0000-000000000007', 'beta-caryophyllene'),
('20000000-0000-0000-0000-000000000008', 'limonene'),
('20000000-0000-0000-0000-000000000009', 'linalool'),
('20000000-0000-0000-0000-000000000010', 'alpha-pinene'),
('20000000-0000-0000-0000-000000000011', 'terpinolene')
ON CONFLICT (ingredient_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 3) Products
--------------------------------------------------------------------------------
INSERT INTO Product (product_id, name, format, route, description) VALUES
('30000000-0000-0000-0000-000000000001', 'Balanced Oral Oil 10:10', 'oil', 'oral', 'Balanced THC/CBD oral oil for baseline pain and sleep support.'),
('30000000-0000-0000-0000-000000000002', 'CBD-Dominant Oral Oil 20:1', 'oil', 'oral', 'CBD-focused oral oil for daytime symptoms with lower intoxication burden.'),
('30000000-0000-0000-0000-000000000003', 'THC-Dominant Night Oil 25:1', 'oil', 'oral', 'THC-leaning oil for refractory nighttime pain and insomnia.'),
('30000000-0000-0000-0000-000000000004', 'Balanced Softgel 5mg/5mg', 'capsule', 'oral', 'Fixed-dose balanced softgel for adherence and predictable titration.'),
('30000000-0000-0000-0000-000000000005', 'CBD Softgel 25mg', 'capsule', 'oral', 'CBD-dominant capsule for anxiety and inflammatory symptom adjunct use.'),
('30000000-0000-0000-0000-000000000006', 'Vaporized Flower Balanced 8/8', 'flower', 'inhalation', 'Balanced inhaled flower for rapid onset breakthrough symptom control.'),
('30000000-0000-0000-0000-000000000007', 'Vaporized Flower THC 18/CBD<1', 'flower', 'inhalation', 'THC-heavy inhaled flower for severe breakthrough symptoms.'),
('30000000-0000-0000-0000-000000000008', 'Sublingual Spray 2.7 THC / 2.5 CBD', 'spray', 'oromucosal', 'Oromucosal spray enabling fine-grained titration with moderate onset.')
ON CONFLICT (product_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 4) Product composition
--------------------------------------------------------------------------------
INSERT INTO ProductIngredient (product_id, ingredient_id, amount, unit) VALUES
('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 10.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 10.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000006', 0.6, 'mg/mL'),
('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000007', 0.4, 'mg/mL'),
('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 1.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 20.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000008', 0.3, 'mg/mL'),
('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000009', 0.2, 'mg/mL'),
('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', 25.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 1.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000004', 2.0, 'mg/mL'),
('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000006', 0.8, 'mg/mL'),
('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', 5.0, 'mg/capsule'),
('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', 5.0, 'mg/capsule'),
('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000007', 0.2, 'mg/capsule'),
('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001', 0.5, 'mg/capsule'),
('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002', 25.0, 'mg/capsule'),
('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000008', 0.1, 'mg/capsule'),
('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001', 8.0, '%'),
('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000002', 8.0, '%'),
('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000006', 0.5, '%'),
('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000007', 0.7, '%'),
('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000010', 0.2, '%'),
('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000001', 18.0, '%'),
('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000002', 0.5, '%'),
('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000006', 0.4, '%'),
('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000011', 0.6, '%'),
('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000001', 2.7, 'mg/spray'),
('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000002', 2.5, 'mg/spray'),
('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000008', 0.1, 'mg/spray')
ON CONFLICT (product_id, ingredient_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 5) Core study + arm + dose lineage for demo flows
--------------------------------------------------------------------------------
INSERT INTO Study (study_id, name, registry_identifier, sample_size, sponsor) VALUES
('40000000-0000-0000-0000-000000000001', 'Mock RCT: Balanced oral oil for chronic pain', 'MOCK-RCT-001', 180, 'GuideRx Demo Consortium'),
('40000000-0000-0000-0000-000000000002', 'Mock RCT: CBD-dominant oral oil for anxiety symptoms', 'MOCK-RCT-002', 140, 'GuideRx Demo Consortium'),
('40000000-0000-0000-0000-000000000003', 'Mock Pragmatic trial: inhaled rescue strategies', 'MOCK-PRAG-003', 110, 'GuideRx Demo Consortium')
ON CONFLICT (study_id) DO NOTHING;

INSERT INTO Arm (arm_id, study_id, arm_type, size, product_id) VALUES
('41000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'intervention', 90, '30000000-0000-0000-0000-000000000001'),
('41000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'active_comparator', 90, '30000000-0000-0000-0000-000000000004'),
('41000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002', 'intervention', 70, '30000000-0000-0000-0000-000000000002'),
('41000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000002', 'placebo', 70, NULL),
('41000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000003', 'intervention', 55, '30000000-0000-0000-0000-000000000006'),
('41000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000003', 'active_comparator', 55, '30000000-0000-0000-0000-000000000007')
ON CONFLICT (arm_id) DO NOTHING;

INSERT INTO Dose (dose_id, arm_id, ingredient_id, amount, unit, frequency, duration) VALUES
('42000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0.25, 'mL', 'bedtime', '14 days'),
('42000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0.25, 'mL', 'twice_daily', '8 weeks'),
('42000000-0000-0000-0000-000000000003', '41000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 1.00, 'capsule', 'bedtime', '8 weeks'),
('42000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 0.25, 'mL', 'twice_daily', '28 days'),
('42000000-0000-0000-0000-000000000005', '41000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 0.75, 'mL', 'twice_daily', '8 weeks'),
('42000000-0000-0000-0000-000000000006', '41000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001', 2.00, 'inhalations', 'as_needed', 'chronic'),
('42000000-0000-0000-0000-000000000007', '41000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001', 1.00, 'inhalations', 'as_needed', 'chronic'),
('42000000-0000-0000-0000-000000000008', '41000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001', 3.00, 'inhalations', 'three_times_daily', '28 days')
ON CONFLICT (dose_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 6) Recommendations and rule logic
--------------------------------------------------------------------------------
INSERT INTO Recommendation (
    recommendation_id, concept_id, product_id, title, clinical_intent, recommendation_text, version, is_active
) VALUES
('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Balanced Oral Oil for Baseline Chronic Pain', 'Reduce persistent pain while preserving daytime function', 'Start low and titrate slowly: begin 0.25 mL nightly, then 0.25 mL twice daily if tolerated.', 'mock-v1', TRUE),
('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000003', 'THC-Dominant Night Oil for Sleep Disruption', 'Improve sleep continuity in pain-related insomnia', 'Restrict use to nighttime, titrate cautiously, and reassess sedation risk at each increase.', 'mock-v1', TRUE),
('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002', 'CBD-Dominant Oral Oil for Anxiety Symptoms', 'Support anxiety symptom reduction with lower intoxication burden', 'Begin at 0.25 mL twice daily and increase every 3-4 days based on symptom response.', 'mock-v1', TRUE),
('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000006', 'Balanced Inhaled Rescue for Breakthrough Pain', 'Provide rapid-onset breakthrough symptom relief', 'Use 1-2 inhalations as needed, with daily cap and sedation counseling.', 'mock-v1', TRUE),
('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000007', 'THC-Heavy Rescue for Severe Breakthrough Episodes', 'Rescue severe breakthrough symptoms when lower THC options are insufficient', 'Use only when balanced rescue fails and monitor anxiety or dysphoria adverse effects.', 'mock-v1', TRUE),
('50000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000008', 'Oromucosal Balanced Spray for Spasticity', 'Enable flexible titration for daytime spasticity symptoms', 'Start 1 spray at bedtime, then titrate to 1-2 sprays up to three times daily if tolerated.', 'mock-v1', TRUE)
ON CONFLICT (recommendation_id) DO NOTHING;

INSERT INTO RecommendationRule (rule_id, recommendation_id, rule_type, logic_json, priority) VALUES
('51000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'inclusion', '{"diagnosis":"CAN-CP"}', 10),
('51000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'caution', '{"age":{"min":25},"contraindications":["CAN-RISK-PSYCHOSIS"]}', 20),
('51000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000002', 'inclusion', '{"diagnosis":"CAN-SLEEP"}', 10),
('51000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000002', 'exclusion', '{"contraindications":["CAN-RISK-PREGNANCY","CAN-RISK-BREASTFEED"]}', 5),
('51000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000003', 'inclusion', '{"diagnosis":"CAN-ANX-SX"}', 10),
('51000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000003', 'caution', '{"hepatic_impairment":true,"cbd_daily_mg":{"gt":100}}', 20),
('51000000-0000-0000-0000-000000000007', '50000000-0000-0000-0000-000000000004', 'inclusion', '{"diagnosis":"CAN-BTP"}', 10),
('51000000-0000-0000-0000-000000000008', '50000000-0000-0000-0000-000000000004', 'caution', '{"route":"inhalation","contains":"THC","conditions":["CAN-RISK-UNSTABLE-CVD"]}', 25),
('51000000-0000-0000-0000-000000000009', '50000000-0000-0000-0000-000000000005', 'exclusion', '{"history":["CAN-RISK-SUD"]}', 5),
('51000000-0000-0000-0000-000000000010', '50000000-0000-0000-0000-000000000006', 'inclusion', '{"diagnosis":"CAN-SPASTICITY"}', 10)
ON CONFLICT (rule_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 7) Safety rules
--------------------------------------------------------------------------------
INSERT INTO SafetyRule (safety_rule_id, product_id, concept_id, severity, rule_logic, description) VALUES
('52000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000011', 'contraindicated', '{"history":["psychotic_disorder"],"thc_daily_mg":{"gt":10}}', 'Avoid THC-dominant night oil in patients with psychosis history.'),
('52000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000012', 'contraindicated', '{"pregnant":true}', 'Avoid THC-dominant products during pregnancy.'),
('52000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000013', 'contraindicated', '{"breastfeeding":true}', 'Avoid THC-dominant products during breastfeeding.'),
('52000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000014', 'warning', '{"conditions":["unstable_cvd"],"route":["inhalation"],"contains":["THC"]}', 'Use caution with inhaled THC products in unstable cardiovascular disease.'),
('52000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000015', 'warning', '{"frailty":true,"fall_risk":true}', 'Frailty and high fall risk increase harm from sedating THC-heavy products.'),
('52000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000017', 'warning', '{"history":["substance_use_disorder"],"route":["inhalation"],"contains":["THC"]}', 'Monitor closely for misuse risk with inhaled THC in SUD history.'),
('52000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000016', 'warning', '{"hepatic_impairment":true,"cbd_daily_mg":{"gt":100}}', 'Consider dose reduction and monitoring with high oral CBD in hepatic impairment.'),
('52000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000015', 'warning', '{"current_medications":["benzodiazepine","opioid","z-drug"]}', 'Concurrent sedatives increase cognitive impairment and falls risk.')
ON CONFLICT (safety_rule_id) DO NOTHING;

--------------------------------------------------------------------------------
-- 8) Evidence aggregation and traceability links
--------------------------------------------------------------------------------
INSERT INTO ClinicalFinding (
    clinical_finding_id, concept_id, product_id, effect_direction, aggregate_certainty, weighted_effect, sum_sample_size, consistency_score
) VALUES
('53000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'benefit', 'moderate', 0.43, 620, 0.78),
('53000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000003', 'benefit', 'low', 0.29, 260, 0.61),
('53000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002', 'benefit', 'moderate', 0.36, 410, 0.74),
('53000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000006', 'benefit', 'moderate', 0.48, 330, 0.70),
('53000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000010', '30000000-0000-0000-0000-000000000007', 'harm', 'moderate', 0.31, 295, 0.67),
('53000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000008', 'benefit', 'low', 0.25, 180, 0.58)
ON CONFLICT (clinical_finding_id) DO NOTHING;

INSERT INTO EvidenceTrace (trace_id, recommendation_id, clinical_finding_id) VALUES
('54000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001'),
('54000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000002'),
('54000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003', '53000000-0000-0000-0000-000000000003'),
('54000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000004', '53000000-0000-0000-0000-000000000004'),
('54000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000005', '53000000-0000-0000-0000-000000000005'),
('54000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000006', '53000000-0000-0000-0000-000000000006')
ON CONFLICT (trace_id) DO NOTHING;

COMMIT;
