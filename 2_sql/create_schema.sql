
DROP TABLE IF EXISTS movie_principals;
DROP TABLE IF EXISTS persons;
DROP TABLE IF EXISTS movies;



CREATE TABLE movies (
movie_id TEXT PRIMARY KEY,
title TEXT,
year INT
);



CREATE TABLE persons (
person_id TEXT PRIMARY KEY,
person_name TEXT,
born INT,
died INT
);



CREATE TABLE movie_principals (
movie_id TEXT,
person_id TEXT,
category TEXT,
PRIMARY KEY (movie_id, person_id, category)
);



COMMENT ON TABLE movies IS '电影信息表';
COMMENT ON TABLE persons IS '演职员信息表';
COMMENT ON TABLE movie_principals IS '电影与演职员的关联表';
