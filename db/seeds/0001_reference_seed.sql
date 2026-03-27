-- Deterministic baseline seed data for local development.

INSERT INTO EvidenceFramework (name, description, is_active)
VALUES
    ('Default Cannabis Evidence Framework v1', 'Initial deterministic framework for cannabis evidence assessment.', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO BiasDomain (name)
SELECT value_name
FROM (
    VALUES
        ('Selection'),
        ('Detection'),
        ('Reporting'),
        ('Attrition'),
        ('Performance'),
        ('Conflict of Interest')
) AS seed(value_name)
WHERE NOT EXISTS (
    SELECT 1 FROM BiasDomain bd WHERE bd.name = seed.value_name
);

INSERT INTO StudyType (name, rating)
SELECT seed.name, seed.rating
FROM (
    VALUES
        ('RCT', 0.95::DECIMAL),
        ('Observational', 0.70::DECIMAL),
        ('Case Series', 0.50::DECIMAL)
) AS seed(name, rating)
WHERE NOT EXISTS (
    SELECT 1 FROM StudyType st WHERE st.name = seed.name
);

INSERT INTO Concept (system, code, display_text)
VALUES
    ('ICD11', '8A80', 'Chronic pain'),
    ('ICD11', '6B00', 'Generalized anxiety disorder'),
    ('Custom', 'AE_DIZZINESS', 'Dizziness adverse event')
ON CONFLICT DO NOTHING;

INSERT INTO Product (name, format, route, description)
SELECT 'Balanced THC:CBD Oil', 'oil', 'oral', 'Reference balanced ratio product for local testing'
WHERE NOT EXISTS (
    SELECT 1 FROM Product p WHERE p.name = 'Balanced THC:CBD Oil'
);

INSERT INTO Ingredient (name)
SELECT value_name
FROM (
    VALUES ('THC'), ('CBD')
) AS seed(value_name)
WHERE NOT EXISTS (
    SELECT 1 FROM Ingredient i WHERE i.name = seed.value_name
);
