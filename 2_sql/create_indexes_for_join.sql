
CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(person_name);
CREATE INDEX IF NOT EXISTS idx_principals_person_id ON movie_principals(person_id);
CREATE INDEX IF NOT EXISTS idx_principals_movie_id ON movie_principals(movie_id);



CREATE INDEX IF NOT EXISTS idx_movies_year ON movies(year);




CREATE INDEX IF NOT EXISTS idx_movies_title ON movies(title);
