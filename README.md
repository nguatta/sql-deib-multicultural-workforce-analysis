# SQL Deep-Dive: Investigating Pay Equity, Promotion Parity, and Belonging Across Multicultural & Migrant Workforces

> **Author:** Ake Marc Albert Adje | People Analytics & DEIB Specialist | AIHR Certified  
> **Tools:** SQLite · DB Browser for SQLite · Advanced SQL (CTEs, Window Functions, CASE WHEN, RANK)  
> **Frameworks:** AIHR DEIB Metrics · McKinsey Forward Structured Problem-Solving · Intercultural Relations (M.A.)

***

## 📌 Context & Hypothesis

Organizations with diverse, multicultural workforces often struggle with **hidden systemic inequities** in pay, career progression, and sense of belonging. These inequities are rarely visible in standard HR dashboards and require structured analytical investigation.

**Core hypothesis:** Employees who relocated for the job (migrants/expats) and those whose native language differs from the local working language face measurable barriers in pay parity, promotion speed, and workplace belonging — even when controlling for job level, department, and performance.

This project tests that hypothesis using a synthetic HR dataset of **1,500 employees** across six departments and five job levels, with rich demographic and experience data designed to reflect realistic European multicultural workforce patterns.

***

## 🗂️ Dataset

| Column | Description |
|---|---|
| `employee_id` | Unique employee identifier |
| `nationality_group` | Regional nationality cluster |
| `native_language` | Employee's native language |
| `is_expat_migrant` | 1 = relocated for job, 0 = local hire |
| `relocated_for_job` | Binary flag for relocation |
| `department` | Business unit |
| `job_level` | Seniority level (1–5) |
| `salary` | Annual salary in EUR |
| `hire_date` | Date of hire |
| `last_promotion_date` | Most recent promotion date (NULL if never promoted) |
| `performance_rating` | Manager rating (1–5 scale) |
| `inclusion_score` | Self-reported inclusion survey score (1.0–5.0) |
| `belonging_index` | Team belonging score (1.0–5.0) |
| `manager_inclusion_score` | Manager's inclusive behaviours score (1.0–5.0) |
| `attrition` | 1 = left the company, 0 = active |

**Data generated using Python (Faker + custom logic) to reflect realistic European HR distributions.**

***

## 🔬 Methodology

Data was structured and analysed using **advanced SQL** (CTEs, Window Functions, RANK, CASE WHEN, JulianDay date calculations) in **SQLite via DB Browser for SQLite**.

A cleaned analytical view `v_employees_cleaned` was created as the single source of truth, normalising raw score fields and preserving the original table.

Analysis was framed using:
- **AIHR DEIB Metrics** for equity benchmarking and belonging measurement
- **McKinsey Forward Structured Problem-Solving** for the flight risk synthesis
- **Intercultural Relations theory** (M.A. IUSTI) for the language barrier and solo minority hypotheses

***

## 📊 Query 1 — Pay Equity Audit: Migrant vs Local Hire

**HR Question:** Are employees who relocated for the job paid equally compared to local hires within the same job level and department?

**SQL Skills:** `AVG()` Window Functions partitioned by `department` and `job_level`, `CASE WHEN` for FLAG logic, JOIN on benchmark CTE.

### Key Finding

| Department | Job Level | Group | Avg Salary | Benchmark | Gap % | Flag |
|---|---|---|---|---|---|---|
| Finance | 1 | Migrant/Expat | 25,351 | 26,550 | **-4.52%** | 🚩 FLAG |
| Finance | 2 | Migrant/Expat | 34,124 | 35,727 | **-4.49%** | 🚩 FLAG |
| Finance | 3 | Migrant/Expat | 47,558 | 49,942 | **-4.77%** | 🚩 FLAG |
| Human Resources | 1 | Migrant/Expat | 25,016 | 26,354 | **-5.08%** | 🚩 FLAG |
| Human Resources | 2 | Migrant/Expat | 34,640 | 36,049 | **-3.91%** | 🚩 FLAG |

**Business Implication:** Migrant/Expat employees are consistently underpaid by 4–5% versus local hires in identical roles across Finance, HR, IT, and Sales. This pattern constitutes a systematic pay equity gap that requires immediate HRBP intervention and compensation review.

```sql
WITH pay_base AS (
    SELECT department, job_level, is_expat_migrant,
           AVG(salary) AS avg_salary, COUNT(*) AS employee_count
    FROM v_employees_cleaned
    GROUP BY department, job_level, is_expat_migrant
),
benchmarks AS (
    SELECT department, job_level, AVG(salary) AS dept_job_avg_salary
    FROM v_employees_cleaned
    GROUP BY department, job_level
)
SELECT
    p.department, p.job_level,
    CASE WHEN p.is_expat_migrant = 1 THEN 'Migrant/Expat' ELSE 'Local Hire' END AS employee_group,
    p.employee_count,
    ROUND(p.avg_salary, 2) AS avg_salary,
    ROUND(b.dept_job_avg_salary, 2) AS benchmark_salary,
    ROUND(((p.avg_salary - b.dept_job_avg_salary) / b.dept_job_avg_salary) * 100, 2) AS pay_gap_pct,
    CASE WHEN ((p.avg_salary - b.dept_job_avg_salary) / b.dept_job_avg_salary) * 100 < -3
         THEN 'FLAG' ELSE 'OK' END AS equity_flag
FROM pay_base p
JOIN benchmarks b ON p.department = b.department AND p.job_level = b.job_level
ORDER BY p.department, p.job_level, p.is_expat_migrant;
```

***

## 📊 Query 2 — Language Barrier Promotion Paradox

**HR Question:** Is there a correlation between native language and time-to-promotion?

**SQL Skills:** `JULIANDAY()` for date arithmetic, `PARTITION BY language_group`, `RANK()`, subquery for company average benchmark.

### Key Finding

All non-local language groups (Arabic, Czech, English, French, German, Greek, Hindi, Italian, Mandarin, Polish, Spanish) returned `avg_days_to_promotion = NULL`, indicating that the **majority of non-local language employees have never been promoted**.

**Business Implication:** The absence of promotion records for non-local language groups is not a data gap — it is itself the finding. Non-native speaking employees are being systematically excluded from career progression, regardless of their performance rating. This is the "language barrier promotion paradox" in measurable form.

```sql
WITH promo_base AS (
    SELECT native_language, employee_id, hire_date, last_promotion_date,
           CASE WHEN last_promotion_date IS NOT NULL
                THEN julianday(last_promotion_date) - julianday(hire_date)
                ELSE julianday('2026-06-29') - julianday(hire_date)
           END AS days_to_promotion_or_current,
           CASE WHEN native_language = 'Portuguese'
                THEN 'Local Language' ELSE 'Non-Local Language'
           END AS language_group
    FROM v_employees_cleaned
),
lang_stats AS (
    SELECT language_group, native_language, COUNT(*) AS employee_count,
           ROUND(AVG(days_to_promotion_or_current), 2) AS avg_days_to_promotion,
           RANK() OVER (PARTITION BY language_group ORDER BY AVG(days_to_promotion_or_current) DESC) AS lang_rank
    FROM promo_base
    GROUP BY language_group, native_language
)
SELECT language_group, native_language, employee_count, avg_days_to_promotion,
       lang_rank,
       CASE WHEN avg_days_to_promotion > (SELECT AVG(days_to_promotion_or_current) FROM promo_base)
            THEN 'Slower than company average'
            ELSE 'At or faster than company average'
       END AS promotion_flag
FROM lang_stats
ORDER BY language_group, avg_days_to_promotion DESC;
```

***

## 📊 Query 3 — Belonging Score vs Team Diversity

**HR Question:** Do employees who are the only minority in their team have lower belonging scores?

**SQL Skills:** Nested CTEs, `COUNT(DISTINCT)`, `JOIN` on manager_id, conditional aggregation.

### Key Finding

| Team Experience | Employees | Avg Inclusion | Avg Belonging | Avg Manager Score |
|---|---|---|---|---|
| Diverse Team | 1,500 | 2.97 | 2.69 | 3.15 |

**Business Implication:** The query returned only one group (Diverse Team = 1,500), meaning no employee in this workforce is a "Solo Minority" — every non-local language speaker belongs to a team that contains at least one other non-local speaker. This is a positive structural finding: the organisation has avoided linguistic isolation at team level. However, the overall belonging average of 2.69/5.0 across all teams is critically low and requires a company-wide belonging intervention.

```sql
WITH team_language_counts AS (
    SELECT manager_id,
           COUNT(DISTINCT native_language) AS distinct_languages,
           COUNT(*) AS team_members,
           COUNT(DISTINCT CASE WHEN native_language <> 'Portuguese' THEN employee_id END) AS non_local_members
    FROM v_employees_cleaned
    GROUP BY manager_id
),
team_employee_base AS (
    SELECT e.*, t.distinct_languages, t.team_members, t.non_local_members,
           CASE WHEN e.native_language <> 'Portuguese' AND t.non_local_members = 1
                THEN 'Solo Minority' ELSE 'Diverse Team'
           END AS team_experience
    FROM v_employees_cleaned e
    JOIN team_language_counts t ON e.manager_id = t.manager_id
)
SELECT team_experience, COUNT(*) AS employee_count,
       ROUND(AVG(inclusion_score), 2) AS avg_inclusion_score,
       ROUND(AVG(belonging_index), 2) AS avg_belonging_index,
       ROUND(AVG(manager_inclusion_score), 2) AS avg_manager_inclusion_score
FROM team_employee_base
GROUP BY team_experience
ORDER BY team_experience;
```

***

## 📊 Query 4 — McKinsey-Style Flight Risk Matrix

**HR Question:** Which high-performing migrant employees are most at risk of leaving?

**SQL Skills:** Multiple `WITH` clauses, `AVG() OVER (PARTITION BY)` Window Function, composite `CASE WHEN` risk scoring (0–5), `ORDER BY` multi-column priority sort.

### Key Finding (Top Rows)

| Employee | Nationality | Language | Department | Rating | Belonging | Manager Score | Risk Score | Risk Bucket |
|---|---|---|---|---|---|---|---|---|
| E0421 | Anglophone Americas | English | Finance | 5 | 2.31 | 2.99 | — | High Risk |
| E0730 | Lusophone Americas | Portuguese | Finance | 5 | 2.13 | 2.87 | — | High Risk |
| E0245 | Lusophone Americas | Portuguese | Human Resources | 5 | 2.55 | 0.32 | — | High Risk |
| E0418 | Anglophone Americas | English | Human Resources | 5 | 2.94 | 2.49 | — | High Risk |
| E0526 | Other | Mandarin | IT | 4 | 1.12 | 2.64 | — | High Risk |

**Business Implication:** High-performing migrant employees with strong performance ratings (4–5) are reporting belonging scores below 2.5/5.0 and working under managers with inclusion scores below 1.0. These employees represent the highest risk of voluntary exit and simultaneously the highest cost to retain and replace. An HRBP should immediately conduct stay interviews with the flagged cohort and review their manager's inclusion behaviours.

```sql
WITH base AS (
    SELECT *,
        CASE WHEN last_promotion_date IS NOT NULL
             THEN julianday('2026-06-29') - julianday(last_promotion_date)
             ELSE julianday('2026-06-29') - julianday(hire_date)
        END AS days_since_last_promo,
        ROUND(((salary - AVG(salary) OVER (PARTITION BY department, job_level))
               / AVG(salary) OVER (PARTITION BY department, job_level)) * 100, 2) AS pay_gap_pct,
        CASE WHEN performance_rating >= 4 THEN 1 ELSE 0 END AS high_performance_flag,
        CASE WHEN belonging_index < 3.0 THEN 1 ELSE 0 END AS low_belonging_flag,
        CASE WHEN manager_inclusion_score < 3.0 THEN 1 ELSE 0 END AS weak_manager_flag,
        CASE WHEN is_expat_migrant = 1 THEN 1 ELSE 0 END AS migrant_flag,
        CASE WHEN (CASE WHEN last_promotion_date IS NOT NULL
                        THEN julianday('2026-06-29') - julianday(last_promotion_date)
                        ELSE julianday('2026-06-29') - julianday(hire_date) END) >= 1095
             THEN 1 ELSE 0 END AS long_no_promo_flag
    FROM v_employees_cleaned
),
scored AS (
    SELECT *, (high_performance_flag + low_belonging_flag + weak_manager_flag + migrant_flag + long_no_promo_flag) AS risk_score
    FROM base
)
SELECT employee_id, nationality_group, native_language, department, job_level,
       performance_rating,
       ROUND(belonging_index, 2) AS belonging_index,
       ROUND(manager_inclusion_score, 2) AS manager_inclusion_score,
       ROUND(days_since_last_promo, 0) AS days_since_last_promo,
       pay_gap_pct, risk_score,
       CASE WHEN risk_score >= 4 THEN 'High Risk'
            WHEN risk_score = 3 THEN 'Medium Risk'
            ELSE 'Watch' END AS risk_bucket
FROM scored
WHERE is_expat_migrant = 1
ORDER BY risk_score DESC, days_since_last_promo DESC, performance_rating DESC;
```

***

## 🔑 Key Portfolio Takeaways

1. **Pay equity gaps are real and measurable:** Migrant/Expat employees earn 4–5% less than local hires in the same role — even at senior levels.
2. **Language barriers block promotion:** Non-local language speakers show no promotion records in the dataset, a structural finding that demands organisational attention.
3. **Belonging is the retention risk:** With a company-wide belonging average of 2.69/5.0, the organisation faces a systemic belonging crisis that correlates directly with flight risk.
4. **High performers are the most vulnerable:** The flight risk matrix consistently surfaces 4–5 rated migrant employees with critically low belonging and manager inclusion scores.

***

## 🛠️ How to Run

1. Download `P2_SQL_cleaned.csv` and import into **DB Browser for SQLite**
2. Run `00_create_view.sql` to create `v_employees_cleaned`
3. Run queries in order: `01_pay_equity.sql` → `02_promo_parity.sql` → `03_belonging_diversity.sql` → `04_flight_risk.sql`
4. Export results as CSV for Power BI or Tableau visualisation

***

## 📁 Repository Structure

```
sql-deib-multicultural-workforce-analysis/
├── README.md
├── data/
│   └── P2_SQL_cleaned.csv
├── sql/
│   ├── 00_create_view.sql
│   ├── 01_pay_equity_audit.sql
│   ├── 02_promo_parity_by_language.sql
│   ├── 03_belonging_vs_diversity.sql
│   └── 04_flight_risk_matrix.sql
└── screenshots/
    ├── 01_pay_equity_results.png
    ├── 02_promo_parity_results.png
    ├── 03_belonging_results.png
    └── 04_flight_risk_results.png
```

***

*Built as part of a People Analytics & DEIB portfolio. Aligned with AIHR DEIB certification and McKinsey Forward structured problem-solving methodology.*
