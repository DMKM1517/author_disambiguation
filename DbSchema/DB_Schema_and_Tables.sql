-- Installs the fuzzystrmatch (soundex) functions
DROP EXTENSION IF EXISTS fuzzystrmatch;
CREATE EXTENSION fuzzystrmatch;


---------------------------------------------------------------------------
------------------------- SOURCE TABLES -------------------------

--articles
--drop table if exists source.articles;
CREATE TABLE source.articles (
	processId int NOT NULL,
	id int NOT NULL,
	title varchar(500),
	journal varchar(200),
	type text,
	doi varchar(50),
	"year" int
);

CREATE INDEX ON source.articles (processId);
CREATE INDEX ON source.articles (id);
CREATE INDEX ON source.articles (title);

INSERT INTO "source".articles
	(processid, id, title, journal, "type", doi, "year")
SELECT 
	'10000' as processid, id, title, journal, "type", doi, "year"
FROM "public".articles;


--articles_authors
--drop table if exists source.signatures;
CREATE TABLE source.signatures (
	id int,
	d int,
	first_name varchar(100),
	fn_initial varchar(1),
	mn_initial varchar(1),
	last_name varchar(100),
	PRIMARY KEY (id, d)
);


INSERT INTO "source".signatures
	(id, d, first_name, fn_initial, mn_initial, last_name)
SELECT 
	id, d, finitial, finitial, sinitial, lastname
FROM "public".xref_articles_authors;


--articles_institutions
--drop table if exists source.institutions;
CREATE TABLE source.institutions (
	id int,
	d int,
	institution varchar(250)
);
CREATE INDEX ON source.institutions (id, d);
CREATE INDEX ON source.institutions (institution);


INSERT INTO "source".institutions
	(id, d, institution)
SELECT 
	id, d1, institution
FROM "public".articles_institutions
where d2 = 0;


--articles_keywords
--drop table if exists source.keywords;
CREATE TABLE source.keywords (
	id int,
	type_keyword varchar(50),
	keyword varchar(250)
);
CREATE INDEX ON source.keywords (id);
CREATE INDEX ON source.keywords (keyword);

INSERT INTO "source".keywords
	(id, type_keyword, keyword)
SELECT 
	id, type_keyw, keyword
FROM "public".articles_keywords;



--articles_refs
--drop table if exists source.references;
CREATE TABLE source.references (
	id int,
	first_author varchar(100),
	journal varchar(250),
	year int
);
CREATE INDEX ON source.references (id);
CREATE INDEX ON source.references (journal);

INSERT INTO "source"."references"
	(id, first_author, journal, "year")
SELECT 
	id, first_author, journal, "year"
FROM "public".articles_refs;




--articles_subjects & subject_asociations
--drop table if exists source.subjects;
CREATE TABLE source.subjects (
	id int,
	subject varchar(200)
);
CREATE INDEX ON source.subjects (id);
CREATE INDEX ON source.subjects (subject);

INSERT INTO "source".subjects
	(id, subject)
select distinct *
from
	(SELECT id, subject
	FROM "public".articles_subjects
	UNION
	SELECT id, subject
	FROM "public".subject_asociations )  sub
order by id;


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
	source.signatures aa; 

	
-- Create the indexes
CREATE UNIQUE INDEX ON main.articles_authors (id, d);
CREATE INDEX ON main.articles_authors (last_name);
CREATE INDEX ON main.articles_authors (focus_name);
CREATE INDEX ON main.articles_authors (id, focus_name);

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


-- Creates the table that contains the autors that are the same
drop table if exists main.same_authors;
create table main.same_authors(
	id1 int NOT NULL,
	d1 int NOT NULL,
	id2 int NOT NULL,
	d2 int NOT NULL,
	focus_name varchar(15),
	same boolean,
	PRIMARY KEY (id1, d1, id2, d2, focus_name)
);
CREATE INDEX ON main.same_authors (id1, d1);
CREATE INDEX ON main.same_authors (id2, d2);
CREATE INDEX ON main.same_authors (id1);
CREATE INDEX ON main.same_authors (id2);
CREATE INDEX ON main.same_authors (focus_name);




-- Creates the table that contains all the information for calculating the distances 
drop table if exists main.info_for_distances;
select
	a.processid,
	aa.id,
	aa.d,
	aa.focus_name,
	a.title,
	k.keywords,
	refs.references,
	sub.subjects,
	aa2.coauthors,
	aa.last_name,
	et.eth_aian_api_bck_hsp_twr_wht
into main.info_for_distances
from
	main.articles_authors aa
	join (
		select id, string_agg(focus_name, ':::') as coauthors
		from main.articles_authors 
		group by id) aa2 on aa.id = aa2.id
	join source.articles a on a.id = aa.id
	left join (
		select id, string_agg(keyword, ':::') as keywords
		from source.keywords
		group by id) k on aa.id = k.id
	left join (
		select id, string_agg(journal, ':::') as references
		from source.references
		group by id) refs on aa.id = refs.id
	left join (
		select id, string_agg(subject, ':::') as subjects
		from source.subjects 
		group by id) sub on aa.id = sub.id
	left join (
		select last_name, api|| '_' || aian || '_' || black|| '_' || hispanic|| '_' || tworace|| '_' || white as eth_aian_api_bck_hsp_twr_wht
		from main.last_name_ethnicities) et on aa.last_name = et.last_name;

CREATE UNIQUE INDEX ON main.info_for_distances (id, d);
CREATE INDEX ON main.info_for_distances (last_name);
CREATE INDEX ON main.info_for_distances (focus_name);
CREATE INDEX ON main.info_for_distances (id);

-- Creates the table for the Last Name Ethnicities
drop table if exists main.last_name_ethnicities;
create table main.last_name_ethnicities(
	last_name varchar(250),
	aian int,
	api int,
	black int,
	hispanic int,
	tworace int,
	white int,
	PRIMARY KEY (last_name)
);

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
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.keywords (id1);
create index on distances.keywords (id2);
create index on distances.keywords (id1, id2);
create index on distances.keywords (focus_name);

drop table if exists distances.title;
CREATE TABLE distances.title (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_title float DEFAULT NULL,
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.title (id1);
create index on distances.title (id2);
create index on distances.title (id1, id2);
create index on distances.title (focus_name);

drop table if exists distances.refs;
CREATE TABLE distances.refs (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_refs float DEFAULT NULL,
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.refs (id1);
create index on distances.refs (id2);
create index on distances.refs (id1, id2);
create index on distances.refs (focus_name);

drop table if exists distances.subject;
CREATE TABLE distances.subject (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_subject float DEFAULT NULL,
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.subject (id1);
create index on distances.subject (id2);
create index on distances.subject (id1, id2);
create index on distances.subject (focus_name);

drop table if exists distances.coauthor;
CREATE TABLE distances.coauthor (
  id1 int NOT NULL,
  id2 int NOT NULL,
  dist_coauthor float DEFAULT NULL,
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (id1, id2, focus_name)
);
create index on distances.coauthor (id1);
create index on distances.coauthor (id2);
create index on distances.coauthor (id1, id2);
create index on distances.coauthor (focus_name);

drop table if exists distances.ethnicity;
CREATE TABLE distances.ethnicity (
  last_name_1 varchar(250) NOT NULL,
  last_name_2 varchar(250) NOT NULL,
  dist_ethnicity float DEFAULT NULL,
  focus_name varchar(15) DEFAULT NULL,
  PRIMARY KEY (last_name_1, last_name_2, focus_name)
);
create index on distances.ethnicity (last_name_1);
create index on distances.ethnicity (last_name_2);
create index on distances.ethnicity (last_name_1, last_name_2);
create index on distances.ethnicity (focus_name);

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

drop view if exists main.v_authors_distance;
drop view if exists main.v_articles_distance;

-- View that joins all the distances
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
	FULL OUTER JOIN distances.refs rf ON tl.id1 = rf.id1 AND tl.id2 = rf.id2 AND tl.focus_name = rf.focus_name
	FULL OUTER JOIN distances.subject sb ON tl.id1 = sb.id1 AND tl.id2 = sb.id2 AND tl.focus_name = sb.focus_name
	FULL OUTER JOIN distances.keywords kw ON tl.id1 = kw.id1 AND tl.id2 = kw.id2 AND tl.focus_name = kw.focus_name
	FULL OUTER JOIN distances.coauthor ca ON tl.id1 = ca.id1 AND tl.id2 = ca.id2 AND tl.focus_name = ca.focus_name;
	
-- View that joins the authors with the distances of their articles
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
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor,
	case when et.dist_ethnicity is null then 1 else et.dist_ethnicity end as dist_ethnicity
from 
	main.v_articles_distance vad
	join main.articles_authors a1 on vad.id1 = a1.id and vad.focus_name = a1.focus_name
	join main.articles_authors a2 on vad.id2 = a2.id and vad.focus_name = a2.focus_name
	join source.articles art1 on vad.id1 = art1.id
	join source.articles art2 on vad.id2 = art2.id
	join main.fda_topic topic1 on vad.id1 = topic1.id
	join main.fda_topic topic2 on vad.id2 = topic2.id
	left join distances.ethnicity et on a1.last_name = et.last_name_1 and a2.last_name = et.last_name_2;


---------------------------------------------------------------------------
------------------------- TRAINING TABLES & VIEWS -------------------------

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

--Soften the focus name of the training set so it gets better cluster groups
update training.articles_authors
set focus_name = metaphone(last_name, 2);

-- View that joins the authors disambiguated with the distances of their articles
-- and creates the views for the training and testing sets
drop view if exists training.v_authors_distance_testing;
drop view if exists training.v_testing_focus_names;
drop view if exists training.v_authors_distance_training;
drop view if exists training.v_training_focus_names;
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
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor,
	case when et.dist_ethnicity is null then 1 else et.dist_ethnicity end as dist_ethnicity,
	case when a1.author_id = a2.author_id then 1 else 0 end as same_author
from 
	main.v_articles_distance vad
	join training.articles_authors a1 on vad.id1 = a1.id and vad.focus_name = a1.focus_name
	join training.articles_authors a2 on vad.id2 = a2.id and vad.focus_name = a2.focus_name
	join source.articles art1 on vad.id1 = art1.id 
	join source.articles art2 on vad.id2 = art2.id
	join main.fda_topic topic1 on vad.id1 = topic1.id
	join main.fda_topic topic2 on vad.id2 = topic2.id
	left join distances.ethnicity et on a1.last_name = et.last_name_1 and a2.last_name = et.last_name_2;

	
CREATE VIEW training.v_training_focus_names AS
SELECT focus_name
FROM(
  SELECT DISTINCT focus_name, cume_dist() OVER (ORDER BY focus_name)
  FROM training.v_authors_distance
) s
WHERE cume_dist < 0.7;

CREATE VIEW training.v_testing_focus_names AS
SELECT fn.focus_name
FROM
	(
	  SELECT DISTINCT focus_name
	  FROM training.v_authors_distance
	) fn
	left join training.v_training_focus_names tfn on fn.focus_name = tfn.focus_name
WHERE tfn.focus_name is null;

CREATE VIEW training.v_authors_distance_training AS
select ad.* 
from 
	training.v_authors_distance ad
	join training.v_training_focus_names fns on ad.focus_name = fns.focus_name;

CREATE VIEW training.v_authors_distance_testing AS
select ad.* 
from 
	training.v_authors_distance ad
	join training.v_testing_focus_names fns on ad.focus_name = fns.focus_name;
