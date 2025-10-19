











SET statement_timeout = '60s';


SELECT * FROM (
    SELECT COUNT(*)
    FROM movies m
    JOIN movie_principals mp ON m.movie_id = mp.movie_id
    JOIN persons p ON mp.person_id = p.person_id
    WHERE p.person_name = 'Tom Hanks' AND mp.category IN ('actor', 'actress')
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT COUNT(*) FROM persons WHERE person_name LIKE 'Tom%'
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM (SELECT person_name FROM persons) sub WHERE person_name LIKE 'Tom%'
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT COUNT(*) FROM movies WHERE movie_id IN (
        SELECT movie_id FROM movie_principals WHERE category = 'actor'
    )
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM movies m WHERE EXISTS (
        SELECT 1 FROM movie_principals mp WHERE mp.movie_id = m.movie_id AND mp.category = 'actor'
    )
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM persons p WHERE p.person_id NOT IN (
        SELECT person_id FROM movie_principals
    )
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM persons p WHERE NOT EXISTS (
        SELECT 1 FROM movie_principals mp WHERE mp.person_id = p.person_id
    )
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT year, COUNT(*) AS number_of_movies FROM movies GROUP BY year
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT year, COUNT(*) AS number_of_movies FROM movies GROUP BY year HAVING COUNT(*) > 10
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT COUNT(*) FROM movies m, movie_principals mp WHERE m.movie_id = mp.movie_id
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM movies m JOIN movie_principals mp ON m.movie_id = mp.movie_id
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT COUNT(*) FROM movies WHERE title LIKE 'The%'
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM movies WHERE title LIKE '%man%'
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM movies WHERE title LIKE 'STAR%'
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM movies WHERE UPPER(title) LIKE 'STAR%'
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT COUNT(*) FROM persons WHERE person_name IS NULL
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(*) FROM persons WHERE person_name IS NOT NULL
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT year,
           COUNT(*) AS cnt,
           ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
    FROM movies
    GROUP BY year
    ORDER BY year
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT title, year,
           ROW_NUMBER() OVER (PARTITION BY year ORDER BY title) AS rn
    FROM movies
    ORDER BY year, rn
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT person_id FROM movie_principals WHERE category = 'actor'
    UNION
    SELECT person_id FROM movie_principals WHERE category = 'director'
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT person_id FROM movie_principals WHERE category = 'actor'
    UNION ALL
    SELECT person_id FROM movie_principals WHERE category = 'director'
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT DISTINCT CASE WHEN UPPER(SUBSTR(title, 1, 1)) BETWEEN 'A' AND 'M' THEN 'A-M' WHEN UPPER(SUBSTR(title, 1, 1)) BETWEEN 'N' AND 'Z' THEN 'N-Z' ELSE 'Other' END AS title_bucket FROM movies WHERE year = 2000
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT COUNT(DISTINCT person_id) FROM movie_principals
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT title, year,
           CASE
               WHEN year < 1950 THEN 'old'
               WHEN year BETWEEN 1950 AND 2000 THEN 'mid'
               ELSE 'new'
           END AS era
    FROM movies
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT title, year FROM movies ORDER BY year DESC LIMIT 5
) AS subquery LIMIT 5;

SELECT * FROM (
    SELECT title, year FROM movies ORDER BY year DESC, title ASC LIMIT 10
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT d.decade,
           COALESCE(COUNT(m.movie_id), 0) AS number_of_movies
    FROM (SELECT DISTINCT (year / 10) * 10 AS decade FROM movies) d
    LEFT JOIN movies m ON (m.year / 10) * 10 = d.decade
    GROUP BY d.decade
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT * FROM (
        SELECT CASE WHEN UPPER(SUBSTR(title, 1, 1)) BETWEEN 'A' AND 'Z' THEN UPPER(SUBSTR(title, 1, 1)) ELSE '#' END AS initial, MIN(year) AS first_year
        FROM movies
        GROUP BY CASE WHEN UPPER(SUBSTR(title, 1, 1)) BETWEEN 'A' AND 'Z' THEN UPPER(SUBSTR(title, 1, 1)) ELSE '#' END
    ) sub
    WHERE first_year < 1940
) AS subquery LIMIT 5;


SELECT * FROM (
    SELECT title, (year / 10) * 10 AS decade, year,
           ROW_NUMBER() OVER (PARTITION BY (year / 10) * 10 ORDER BY year DESC, title) AS rn
    FROM movies
    ORDER BY decade, rn
) AS subquery LIMIT 5;
