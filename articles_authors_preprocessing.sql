
select 
	aa.id,
	aa.d,
	aa.author,
	aad."authorId",
	aad."completeName" 
from 
	"public".articles_authors aa 
	  JOIN "public".articles_authors_disambiguated aad on aa.id = aad.id and aa.d = aad.d
order by aad."authorId" limit 50;


select
	aa.*,
	art.title,
	art.type,
	ars.subject as subject1,
	sa.subject as subject2
from
	articles_authors aa
	join articles art on aa.id = art.id
	left join articles_subjects ars on art.id = ars.id
	left join subject_asociations sa on art.id = sa.id
limit 500;





-- Installs the fuzzystrmatch (soundex) functions
DROP EXTENSION IF EXISTS fuzzystrmatch;
CREATE EXTENSION fuzzystrmatch;

--Create the Index
drop sequence if exists seq;
create sequence seq;

--Create the cross-reference table
drop table if exists xref_articles_authors;
create table xref_articles_authors as
select 
	nextval('seq') as xref_id,
	aa.*,
	substring(trim(aa.author) FROM '^(.*) [\w]+$') as lastname,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 1 for 1) as finitial,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 2 for 1) as sinitial,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 5) as lastname_phon_5,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 8) as lastname_phon_8,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 12) as lastname_phon_12
--	,
--	ars.subject as subject1,
--	sa.subject as subject2
from
	"public".articles_authors aa
--	join articles art on aa.id = art.id
--	left join articles_subjects ars on art.id = ars.id
--	left join subject_asociations sa on art.id = sa.id
	;


	
-- Create the indexes
CREATE UNIQUE INDEX xref_articles_authors_id ON articles_authors (id, d);
CREATE INDEX ON xref_articles_authors (xref_id);
CREATE INDEX ON xref_articles_authors (author);
CREATE INDEX ON xref_articles_authors (lastname);
CREATE INDEX ON xref_articles_authors (lastname_phon_5);
CREATE INDEX ON xref_articles_authors (lastname_phon_8);
CREATE INDEX ON xref_articles_authors (subject1);
CREATE INDEX ON xref_articles_authors (subject2);

-- Update the cases when the person has only one word in their name
update xref_articles_authors
set 
	lastname = author,
	finitial = null,
	sinitial = null,
	lastname_phon_5 = metaphone(author, 5),
	lastname_phon_8 = metaphone(author, 8),
	lastname_phon_12 = metaphone(author, 12)
where lastname is null;

-- -- Clean the subjects
--update xref_articles_authors
--set
--	subject1 = subject2,
--	subject2 = null
--where
--	subject1 is null
--	and subject2 is not null;
--	
--update xref_articles_authors
--set
--	subject2 = null
--where
--	subject1 = subject2;

--Create the Index
drop sequence if exists seq_d;
create sequence seq_d;

--Create the cross-reference table
drop table if exists xref_articles_authors_disambiguated;
create table xref_articles_authors_disambiguated as
select 
	nextval('seq_d') as xref_id,
	aa.*,
	substring(trim(aa.author) FROM '^(.*) [\w]+$') as lastname,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 1 for 1) as finitial,
	substring(substring(trim(aa.author) FROM '([^ ]+)$') from 2 for 1) as sinitial,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 5) as lastname_phon_5,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 8) as lastname_phon_8,
	metaphone(substring(trim(aa.author) FROM '^(.*) [\w]+$'), 12) as lastname_phon_12
from
	"public".articles_authors_disambiguated aa;

-- Create the indexes
CREATE UNIQUE INDEX xref_articles_authors_disambiguated_id ON xref_articles_authors_disambiguated (id, d);
CREATE INDEX ON xref_articles_authors_disambiguated (xref_id);
CREATE INDEX ON xref_articles_authors_disambiguated (authorid);
CREATE INDEX ON xref_articles_authors_disambiguated (author);
CREATE INDEX ON xref_articles_authors_disambiguated (lastname);
CREATE INDEX ON xref_articles_authors_disambiguated (lastname_phon_5);
CREATE INDEX ON xref_articles_authors_disambiguated (lastname_phon_8);

-- Update the cases when the person has only one word in their name
update xref_articles_authors_disambiguated
set 
	lastname = author,
	finitial = null,
	sinitial = null,
	lastname_phon_5 = metaphone(author, 5),
	lastname_phon_8 = metaphone(author, 8),
	lastname_phon_12 = metaphone(author, 12)
where lastname is null;

select lastname_phon_12, count(lastname_phon_12) 
from xref_articles_authors_disambiguated
group by lastname_phon_12
order by count(lastname_phon_12) desc
limit 500;

-- ============================================= END OF SETUP =================================================

-- Matching!
select
	aa1.xref_id as master_id,
	aa1.xref_id as id1,
	aa1.author as a1,
	aa2.xref_id as id2,
	aa2.author as a2,
	aa1.subject1,
	aa1.subject2
from
	xref_articles_authors aa1,
	xref_articles_authors aa2
where
	aa1.id <> aa2.id
	and	aa1.subject1 is not null
	and aa2.subject2 is not null
	and (aa1.subject1 = aa2.subject1
		or aa1.subject1 = aa2.subject2
		or aa1.subject2 = aa2.subject1)
	and aa1.lastname_phon_5 = aa2.lastname_phon_5
	and (aa1.finitial = aa2.finitial
		or (aa1.finitial = aa2.sinitial and aa1.sinitial is null)
		or (aa1.sinitial = aa2.finitial and aa2.sinitial is null))
order by aa1.xref_id
limit 500;


-- gets the top lastnames phonetic repeated 
select lastname_phon_12, count(*) as CountLN
from "public".xref_articles_authors t
group by lastname_phon_12
order by CountLN desc
limit 500;


-- gets the top lastnames phonetic repeated 
select lastname_phon_12, count(*) as CountLN
from "public".xref_articles_authors t
group by lastname_phon_12
having count(*) > 50
order by CountLN asc
limit 500;


-- Creates the distance tables
drop table if exists d_keywords;
CREATE TABLE "d_keywords" (
  "id1" int NOT NULL,
  "id2" int NOT NULL,
  "dist_keywords" float DEFAULT NULL,
  "last_name" varchar(100) DEFAULT NULL,
  PRIMARY KEY ("id1", "id2", "last_name")
 );
create index on d_keywords (id1, id2);
create index on d_keywords (last_name);
drop table if exists d_title;
CREATE TABLE "d_title" (
  "id1" int NOT NULL,
  "id2" int NOT NULL,
  "dist_title" float DEFAULT NULL,
  "last_name" varchar(100) DEFAULT NULL,
  PRIMARY KEY ("id1", "id2", "last_name")
 );
create index on d_title (id1, id2);
create index on d_title (last_name);
 drop table if exists d_refs;
CREATE TABLE "d_refs" (
  "id1" int NOT NULL,
  "id2" int NOT NULL,
  "dist_refs" float DEFAULT NULL,
  "last_name" varchar(100) DEFAULT NULL,
  PRIMARY KEY ("id1", "id2", "last_name")
 );
create index on d_refs (id1, id2);
create index on d_refs (last_name);
 drop table if exists d_subject;
CREATE TABLE "d_subject" (
  "id1" int NOT NULL,
  "id2" int NOT NULL,
  "dist_subject" float DEFAULT NULL,
  "last_name" varchar(100) DEFAULT NULL,
  PRIMARY KEY ("id1", "id2", "last_name")
 );
create index on d_subject (id1, id2);
create index on d_subject (last_name);
  drop table if exists d_coauthor;
 CREATE TABLE "d_coauthor" (
  "id1" int NOT NULL,
  "id2" int NOT NULL,
  "dist_coauthor" float DEFAULT NULL,
  "last_name" varchar(100) DEFAULT NULL,
  PRIMARY KEY ("id1", "id2", "last_name")
 );
create index on d_keywords (id1, id2)
create index on d_keywords (last_name)
drop table if exists f_article_topic;
CREATE TABLE "f_article_topic" (
  "id" int NOT NULL,
  "topic" int DEFAULT NULL,
  PRIMARY KEY ("id")
 );


-- View that joins all the distances
drop view if exists v_articles_distance;
CREATE VIEW v_articles_distance AS
select
	tl.id1,
	tl.id2,
	tl.last_name,
	kw.dist_keywords,
	rf.dist_refs,
	sb.dist_subject,
	tl.dist_title,
	ca.dist_coauthor
from 
	d_title tl
	LEFT JOIN d_refs rf ON tl.id1 = rf.id1 AND tl.id2 = rf.id2 AND tl.last_name = rf.last_name
	LEFT JOIN d_subject sb ON tl.id1 = sb.id1 AND tl.id2 = sb.id2 AND tl.last_name = sb.last_name
	LEFT JOIN d_keywords kw ON tl.id1 = kw.id1 AND tl.id2 = kw.id2 AND tl.last_name = kw.last_name
	LEFT JOIN d_coauthor ca ON ca.id1 = kw.id1 AND ca.id2 = kw.id2 AND tl.last_name = ca.last_name
	
	
-- View that joins the authors with the distances of their articles
drop view if exists v_authors_distance;
CREATE VIEW v_authors_distance AS
select
	vad.id1,
	a1.xref_id as xid1,
	vad.id2,
	a2.xref_id as xid2,
	vad.last_name,
	case when a1.finitial = a2.finitial then 1 else 0 end as eq_finitial,
	case when a1.sinitial = a2.sinitial then 1 else 0 end as eq_sinitial,
	case when vad.dist_keywords is null then 1 else vad.dist_keywords end as dist_keywords,
	case when vad.dist_refs is null then 1 else vad.dist_refs end as dist_refs,
	case when vad.dist_subject is null then 1 else vad.dist_subject end as dist_subject,
	case when vad.dist_title is null then 1 else vad.dist_title end as dist_title,
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor
from 
	v_articles_distance vad
	join xref_articles_authors a1 on vad.id1 = a1.id and vad.last_name = a1.lastname_phon_12
	join xref_articles_authors a2 on vad.id2 = a2.id and vad.last_name = a2.lastname_phon_12;

	
	
-- View that joins the authors disambiguated with the distances of their articles
-- and creates the views for the training and testing sets
drop view if exists v_authors_distance_disambiguated_testing;
drop view if exists v_authors_distance_disambiguated_training;
drop view if exists v_authors_distance_disambiguated;

CREATE VIEW v_authors_distance_disambiguated AS
select
	vad.id1,
	a1.xref_id as xid1,
	vad.id2,
	a2.xref_id as xid2,
	vad.last_name,
	case when a1.finitial = a2.finitial then 1 else 0 end as eq_finitial,
	case when a1.sinitial = a2.sinitial then 1 else 0 end as eq_sinitial,
	case when topic1.topic = topic2.topic then 1 else 0 end as eq_topic,
	abs(art1.year - art2.year) as diff_year,
	case when vad.dist_keywords is null then 1 else vad.dist_keywords end as dist_keywords,
	case when vad.dist_refs is null then 1 else vad.dist_refs end as dist_refs,
	case when vad.dist_subject is null then 1 else vad.dist_subject end as dist_subject,
	case when vad.dist_title is null then 1 else vad.dist_title end as dist_title,
	case when vad.dist_coauthor is null then 1 else vad.dist_coauthor end as dist_coauthor,
	case when a1.authorid = a2.authorid then 1 else 0 end as same_author
from 
	v_articles_distance vad
	join xref_articles_authors_disambiguated a1 on vad.id1 = a1.id and vad.last_name = a1.lastname_phon_12
	join xref_articles_authors_disambiguated a2 on vad.id2 = a2.id and a1.id <= a2.id and vad.last_name = a2.lastname_phon_12
	join articles art1 on vad.id1 = art1.id
	join articles art2 on vad.id2 = art2.id
	join f_article_topic topic1 on vad.id1 = topic1.id
	join f_article_topic topic2 on vad.id2 = topic2.id;

CREATE VIEW v_authors_distance_disambiguated_training AS
select * 
from v_authors_distance_disambiguated
where last_name IN
	(SELECT last_name
	FROM(
	  SELECT DISTINCT last_name, cume_dist() OVER (ORDER BY last_name)
	  FROM v_authors_distance_disambiguated
	) s
	WHERE cume_dist < 0.7);

CREATE VIEW v_authors_distance_disambiguated_testing AS
select dis.* 
from 
	v_authors_distance_disambiguated dis
	left join (
		select *
		from v_authors_distance_disambiguated_training) train on dis.xid1 = train.xid1 and dis.xid2 = train.xid2
where train.xid1 is null;
--	
--CREATE VIEW v_authors_distance_disambiguated_testing AS
--select * 
--from v_authors_distance_disambiguated
--where last_name NOT IN
--	(select distinct last_name
--	from v_authors_distance_disambiguated_training);


/*
    -- Truncate Distances
    TRUNCATE TABLE d_keywords;
    TRUNCATE TABLE d_refs;
    TRUNCATE TABLE d_subject;
    TRUNCATE TABLE d_title;
 */

	
--drop table if exists x_articles_distance;
--CREATE TABLE "x_articles_distance" (
--  "id1" int NOT NULL,
--  "id2" int NOT NULL,
--  "last_name" varchar(100) DEFAULT NULL,
--  "dist_keywords" float DEFAULT NULL,
--  "dist_title" float DEFAULT NULL,
--  "dist_refs" float DEFAULT NULL,
--  "dist_subject" float DEFAULT NULL,
--  PRIMARY KEY ("id1", "id2", "last_name")
-- );




SELECT query,* FROM pg_stat_activity ;


select count(*) from  (
        select distinct
            aa1.id,
            aa2.lastname_phon_12 as author
        from
            xref_articles_authors_disambiguated aa1
            join xref_articles_authors aa2 on aa1.id = aa2.id 
        where aa1.lastname_phon_12 = 'AB'
        order by aa1.id
        ) x;
            
        
        select * 
from d_coauthor
where id1<>id2 
order by dist_coauthor
limit 500;

select * 
from v_authors_distance_disambiguated
limit 500;

select last_name, count(*)
from v_authors_distance_disambiguated t
group by last_name
order by last_name
limit 500;

select count(*) from d_keywords;
select count(*) from d_refs;
select count(*) from d_subject;
select count(*) from d_title;
select count(*) from d_coauthor;

select *
from v_articles_distance
where last_name = 'L'
limit 500;

select 
        lastname_phon_12,
        count(lastname_phon_12)
    from xref_articles_authors_disambiguated
    group by lastname_phon_12
    order by count(lastname_phon_12) desc

select 
    lastname_phon_12,
    count(lastname_phon_12)
from xref_articles_authors_disambiguated
group by lastname_phon_12
order by lastname_phon_12 asc


select 
    last_name,
    count(last_name)
from d_refs
group by last_name
order by last_name asc


select id1, id2, last_name, count(*)
from d_coauthor t
group by id1, id2, last_name 
order by count(*) desc
limit 500;


select * 
from d_coauthor
where id1 = 178932
limit 500;


SELECT blocked_locks.pid     AS blocked_pid,
         blocked_activity.usename  AS blocked_user,
         blocking_locks.pid     AS blocking_pid,
         blocking_activity.usename AS blocking_user,
         blocked_activity.query    AS blocked_statement,
         blocking_activity.query   AS current_statement_in_blocking_process
   FROM  pg_catalog.pg_locks         blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks         blocking_locks 
        ON blocking_locks.locktype = blocked_locks.locktype
/*        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid*/
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
   WHERE NOT blocked_locks.GRANTED;
   
   select * 
from pg_catalog.pg_stat_activity blocking_activity
limit 500;