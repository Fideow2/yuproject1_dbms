
















\echo === [load_data.sql] Starting data load ===
\timing on
\set ON_ERROR_STOP on

SET client_encoding = 'UTF8';


\set data_dir '/tmp/data'






BEGIN;


TRUNCATE TABLE movie_principals;
TRUNCATE TABLE persons;
TRUNCATE TABLE movies;

\echo 
\copy movies (movie_id, title, year)
  FROM :'data_dir'/movies.csv
  WITH (FORMAT csv, HEADER true);

\echo 

\copy persons (person_id, person_name)
  FROM :'data_dir'/persons.csv
  WITH (FORMAT csv, HEADER true);

\echo 
\copy movie_principals (movie_id, person_id, category)
  FROM :'data_dir'/movie_principals.csv
  WITH (FORMAT csv, HEADER true);

COMMIT;

\echo 
ANALYZE movies;
ANALYZE persons;
ANALYZE movie_principals;

\echo 
SELECT 'movies' AS table, COUNT(*) AS rows FROM movies
UNION ALL
SELECT 'persons' AS table, COUNT(*) AS rows FROM persons
UNION ALL
SELECT 'movie_principals' AS table, COUNT(*) AS rows FROM movie_principals;

\echo === [load_data.sql] Data load completed ===
