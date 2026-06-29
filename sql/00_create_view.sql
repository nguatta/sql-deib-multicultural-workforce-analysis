DROP VIEW IF EXISTS v_employees_cleaned;

CREATE VIEW v_employees_cleaned AS
SELECT *,
    CASE WHEN inclusion_score > 5 THEN inclusion_score / 100.0 ELSE inclusion_score END AS inclusion_score_clean,
    CASE WHEN belonging_index > 5 THEN belonging_index / 100.0 ELSE belonging_index END AS belonging_index_clean,
    CASE WHEN manager_inclusion_score > 5 THEN manager_inclusion_score / 100.0 ELSE manager_inclusion_score END AS manager_score_clean
FROM P2_SQL_cleaned;
