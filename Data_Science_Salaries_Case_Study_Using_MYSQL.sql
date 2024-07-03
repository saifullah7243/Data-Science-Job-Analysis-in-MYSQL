USE saif;

-- 1. Pinpoint countries with fully remote 'Manager' titles paying salaries exceeding $90,000 USD
SELECT * 
FROM salaries
WHERE remote_ratio = 100 
  AND job_title LIKE '%Manager%' 
  AND salary_in_usd > 90000;

-- 2. Identify top 5 countries with the greatest count of large companies hiring freshers
SELECT company_location, COUNT(company_size) AS count_size
FROM (
    SELECT * 
    FROM salaries
    WHERE experience_level = 'EN' AND company_size = 'L'
) t
GROUP BY company_location
ORDER BY count_size DESC
LIMIT 5;

-- 3. Calculate the percentage of employees in fully remote roles with salaries exceeding $100,000 USD
SET @count = (
    SELECT COUNT(*) 
    FROM salaries
    WHERE remote_ratio = 100 AND salary_in_usd >= 100000
);

SET @total = (
    SELECT COUNT(*)
    FROM salaries
    WHERE salary_in_usd >= 100000
);

SET @percentage = ROUND(((@count / @total) * 100), 2);

SELECT @percentage AS '% Salary people work remotely with 100000 USD';

-- 4. Identify locations where entry-level average salaries exceed the market average for that job title
SELECT company_location, t.job_title, avg_salary_per_country, avg_salary
FROM (
    SELECT company_location, job_title, AVG(salary_in_usd) AS avg_salary_per_country
    FROM salaries
    WHERE experience_level = 'EN'
    GROUP BY company_location, job_title
) AS t
INNER JOIN (
    SELECT job_title, AVG(salary_in_usd) AS avg_salary
    FROM salaries
    WHERE experience_level = 'EN'
    GROUP BY job_title
) AS n ON t.job_title = n.job_title
WHERE avg_salary_per_country > avg_salary;

-- 5. Find the country that pays the maximum average salary for each job title
SELECT company_location, job_title, avg_salary
FROM (
    SELECT company_location, job_title, AVG(salary_in_usd) AS avg_salary,
           DENSE_RANK() OVER (PARTITION BY job_title ORDER BY avg_salary DESC) AS rank_
    FROM salaries
    GROUP BY company_location, job_title
) AS ranked_salaries
WHERE rank_ = 1;

-- 6. Pinpoint locations where the average salary has consistently increased over the past three years
WITH s AS (
    SELECT * 
    FROM salaries 
    WHERE company_location IN (
        SELECT company_location
        FROM (
            SELECT company_location, COUNT(DISTINCT(work_year)) AS num_years
            FROM salaries 
            WHERE work_year >= YEAR(CURRENT_DATE) - 2
            GROUP BY company_location
            HAVING num_years = 3
        ) AS valid_locations
    )
)
SELECT company_location,
       MAX(CASE WHEN work_year = 2022 THEN avg_salary END) AS avg_salary_2022,
       MAX(CASE WHEN work_year = 2023 THEN avg_salary END) AS avg_salary_2023,
       MAX(CASE WHEN work_year = 2024 THEN avg_salary END) AS avg_salary_2024
FROM (
    SELECT company_location, work_year, AVG(salary_in_usd) AS avg_salary
    FROM s
    GROUP BY company_location, work_year
) AS yearly_salaries
GROUP BY company_location
HAVING avg_salary_2024 > avg_salary_2023 AND avg_salary_2023 > avg_salary_2022;

-- 7. Determine the percentage of fully remote work for each experience level in 2021 and 2024
WITH t1 AS (
    SELECT a.experience_level, total_remote, total_2021, 
           ROUND((total_remote / total_2021) * 100, 2) AS '2021 remote %'
    FROM (
        SELECT experience_level, COUNT(*) AS total_remote
        FROM salaries
        WHERE work_year = 2021 AND remote_ratio = 100
        GROUP BY experience_level
    ) AS a
    INNER JOIN (
        SELECT experience_level, COUNT(*) AS total_2021
        FROM salaries
        WHERE work_year = 2021
        GROUP BY experience_level
    ) AS b ON a.experience_level = b.experience_level
), t2 AS (
    SELECT a.experience_level, total_remote, total_2024, 
           ROUND((total_remote / total_2024) * 100, 2) AS '2024 remote %'
    FROM (
        SELECT experience_level, COUNT(*) AS total_remote
        FROM salaries
        WHERE work_year = 2024 AND remote_ratio = 100
        GROUP BY experience_level
    ) AS a
    INNER JOIN (
        SELECT experience_level, COUNT(*) AS total_2024
        FROM salaries
        WHERE work_year = 2024
        GROUP BY experience_level
    ) AS b ON a.experience_level = b.experience_level
)
SELECT t1.experience_level, t1.`2021 remote %`, t2.`2024 remote %`
FROM t1
INNER JOIN t2 ON t1.experience_level = t2.experience_level;
