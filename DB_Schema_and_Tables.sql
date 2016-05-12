-- Installs the fuzzystrmatch (soundex) functions
DROP EXTENSION IF EXISTS fuzzystrmatch;
CREATE EXTENSION fuzzystrmatch;


---------------------------------------------------------------------------
------------------------- MAIN TABLES -------------------------

-- creates the schema main schema
create schema main;

-- creates the main table that connects information for authors and articles and focus name
drop table if exists main.articles_authors;
create table main.articles_authors as
select 
	aa.*,
	substring(trim(aa.author) FROM '^(.*) [\w]+$') as last_name,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 1 for 1) as fn_initial,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 2 for 1) as mn_initial,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 5) as focus_name
from
	"public".articles_authors aa; --TODO: Change this to the source schema

-- Create the indexes
CREATE UNIQUE INDEX ON main.articles_authors (id, d);
CREATE INDEX ON main.articles_authors (author);
CREATE INDEX ON main.articles_authors (last_name);
CREATE INDEX ON main.articles_authors (focus_name);

-- Update the cases when the person has only one word in their name
update main.articles_authors
set 
	last_name = author,
	fn_initial = null,
	mn_initial = null,
	focus_name = metaphone(author, 5)
where last_name is null;

-- Creates the table that contains the disambiguated authors
drop table if exists main.authors_disambiguated;
create table main.authors_disambiguated as
select
	authorid as author_id,
	id,
	d
from "public".articles_authors_disambiguated;

CREATE INDEX ON main.authors_disambiguated (author_id);
CREATE UNIQUE INDEX ON main.authors_disambiguated (id, d);

---------------------------------------------------------------------------
------------------------- DISTANCES TABLES -------------------------

--create the schema for distances
create schema distances;

-- Creates the distance tables
drop table if exists distances.keywords;
CREATE TABLE distances.keywords (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_keywords float DEFAULT NULL,
  focus_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.keywords (id1, id2);
create index on distances.keywords (focus_name);

drop table if exists distances.title;
CREATE TABLE distances.title (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_title float DEFAULT NULL,
  focus_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.title (id1, id2);
create index on distances.title (focus_name);

drop table if exists distances.refs;
CREATE TABLE distances.refs (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_refs float DEFAULT NULL,
  focus_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.refs (id1, id2);
create index on distances.refs (focus_name);

drop table if exists distances.subject;
CREATE TABLE distances.subject (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_subject float DEFAULT NULL,
  focus_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.subject (id1, id2);
create index on distances.subject (focus_name);

drop table if exists distances.coauthor;
CREATE TABLE distances.coauthor (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_coauthor float DEFAULT NULL,
  focus_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.coauthor (id1, id2);
create index on distances.coauthor (focus_name);

-- Creates the table for the FDA Topic
drop table if exists main.fda_topic;
CREATE TABLE main.fda_topic (
  id int NOT NULL,
  topic int DEFAULT NULL,
  PRIMARY KEY (id)
);
create index on main.fda_topic (topic);


---------------------------------------------------------------------------
------------------------- AGGREGATION VIEWS -------------------------
-- View that joins all the distances
drop view if exists main.v_articles_distance;
CREATE VIEW main.v_articles_distance AS
select
	tl.id1,
	tl.id2,
	tl.focus_name,
	kw.dist_keywords,
	rf.dist_refs,
	sb.dist_subject,
	tl.dist_title,
	ca.dist_coauthor
from 
	distances.title tl
	LEFT JOIN distances.refs rf ON tl.id1 = rf.id1 AND tl.id2 = rf.id2 AND tl.focus_name = rf.focus_name
	LEFT JOIN distances.subject sb ON tl.id1 = sb.id1 AND tl.id2 = sb.id2 AND tl.focus_name = sb.focus_name
	LEFT JOIN distances.keywords kw ON tl.id1 = kw.id1 AND tl.id2 = kw.id2 AND tl.focus_name = kw.focus_name
	LEFT JOIN distances.coauthor ca ON ca.id1 = kw.id1 AND ca.id2 = kw.id2 AND tl.focus_name = ca.focus_name;
	
	
-- View that joins the authors with the distances of their articles
drop view if exists main.v_authors_distance;
CREATE VIEW main.v_authors_distance AS
select
	vad.id1,
	a1.d as d1,
	vad.id2,
	a2.d as d2,
	vad.focus_name,
	case when a1.fn_initial = a2.fn_initial then 1 else 0 end as eq_fn_initial,
	case when a1.mn_initial = a2.mn_initial then 1 else 0 end as eq_mn_initial,
	case when topic1.topic = topic2.topic then 1 else 0 end as eq_lda_topic,
	abs(art1.year - art2.year) as diff_year,
	case when vad.dist_keywords is null then 1 else vad.dist_keywords end as dist_keywords,
	case when vad.dist_refs is null then 1 else vad.dist_refs end as dist_refs,
	case when vad.dist_subject is null then 1 else vad.dist_subject end as dist_subject,
	case when vad.dist_title is null then 1 else vad.dist_title end as dist_title,
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor
from 
	main.v_articles_distance vad
	join main.articles_authors a1 on vad.id1 = a1.id and vad.focus_name = a1.focus_name
	join main.articles_authors a2 on vad.id2 = a2.id and vad.focus_name = a2.focus_name
	join public.articles art1 on vad.id1 = art1.id --TODO: Change to source schema
	join public.articles art2 on vad.id2 = art2.id
	join main.fda_topic topic1 on vad.id1 = topic1.id
	join main.fda_topic topic2 on vad.id2 = topic2.id;


---------------------------------------------------------------------------
------------------------- TESTING TABLES & VIEWS -------------------------

-- creates the schema for training tables
create schema training;

--Create the cross-reference table
drop table if exists training.articles_authors;
create table training.articles_authors as
select 
	aa.*,
	ad.author_id
from
	main.articles_authors aa
	join main.authors_disambiguated ad on aa.id = ad.id and aa.d = ad.d;

-- Create the indexes
CREATE UNIQUE INDEX ON training.articles_authors (id, d);
CREATE INDEX ON training.articles_authors (author_id);
CREATE INDEX ON training.articles_authors (focus_name);



-- View that joins the authors disambiguated with the distances of their articles
-- and creates the views for the training and testing sets
drop view if exists training.v_authors_distance_testing;
drop view if exists training.v_authors_distance_training;
drop view if exists training.v_authors_distance;

CREATE VIEW training.v_authors_distance AS
select
	vad.id1,
	a1.d as d1,
	vad.id2,
	a2.d as d2,
	vad.focus_name,
	case when a1.fn_initial = a2.fn_initial then 1 else 0 end as eq_fn_initial,
	case when a1.mn_initial = a2.mn_initial then 1 else 0 end as eq_mn_initial,
	case when topic1.topic = topic2.topic then 1 else 0 end as eq_lda_topic,
	abs(art1.year - art2.year) as diff_year,
	case when vad.dist_keywords is null then 1 else vad.dist_keywords end as dist_keywords,
	case when vad.dist_refs is null then 1 else vad.dist_refs end as dist_refs,
	case when vad.dist_subject is null then 1 else vad.dist_subject end as dist_subject,
	case when vad.dist_title is null then 1 else vad.dist_title end as dist_title,
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor
from 
	main.v_articles_distance vad
	join training.articles_authors a1 on vad.id1 = a1.id and vad.focus_name = a1.focus_name
	join training.articles_authors a2 on vad.id2 = a2.id and vad.focus_name = a2.focus_name
	join public.articles art1 on vad.id1 = art1.id --TODO: Change to source schema
	join public.articles art2 on vad.id2 = art2.id
	join main.fda_topic topic1 on vad.id1 = topic1.id
	join main.fda_topic topic2 on vad.id2 = topic2.id;
	

CREATE VIEW training.v_authors_distance_training AS
select ad.* 
from 
	training.v_authors_distance ad
	join (
		SELECT focus_name
		FROM(
		  SELECT DISTINCT focus_name, cume_dist() OVER (ORDER BY focus_name)
		  FROM training.v_authors_distance
		) s
		WHERE cume_dist < 0.7) fns on ad.focus_name = fns.focus_name;

CREATE VIEW training.v_authors_distance_testing AS
select dis.* 
from 
	training.v_authors_distance dis
	left join training.v_authors_distance_training train on (dis.id1 = train.id1 and dis.d1 = train.d1) and (dis.id2 = train.id2 and dis.d2 = train.d2)
where train.id1 is null;


