# Database Installation & Description

[PostgreSQL 9.5](https://www.postgresql.org/) is used as the RDBMS of the system. Below you will find the description of how to create the Database for the application along with the description of the most important relations of the database.


## Deployment

### Install PostgreSQL

Follow any guide, for example the [official one for Ubuntu](https://www.postgresql.org/download/linux/ubuntu/), or follow these steps:

 - Create the file `/etc/apt/sources.list.d/pgdg.list`, and add a line for the repository
`deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main`
 - Import the repository running
     - `wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
      sudo apt-key add -`
     - `sudo apt-get update`
 - Install postgresql
     - `sudo apt-get install postgresql-9.4`

Now, make the database accesible:

 - Change to postgres user
    `sudo su - postgres`
 - Change these config files using `vi` or any other editor
     - `vi /etc/postgresql/9.5/main/postgresql.conf`
        Change this line `listen_addresses = '*'`
     - `vi /etc/postgresql/9.5/main/pg_hba.conf`
        Change this line `host all all 0.0.0.0/0 md5`
 - Reload configuration and restart
     - `psql`
     - `SELECT pg_reload_conf();`
     - `\q`
     - `service postgresql restart`

Create a user and the database:

 - `psql`
 - `create user dmkm with password '<password>';`
 - `create database ArticlesDB with owner dmkm encoding 'UTF8';`

Install the extension Unaccent (used for searching):

 - `sudo su - postgres`
 - `psql -d ArticlesDB`
 - `CREATE EXTENSION unaccent;`
 - `SELECT unaccent('H�tel');`


### Database Schema Definition

Within the GitHub repository, the necessary scriptsthat defines the different relations and views of the applicaiton can be found on `DbSchema\DB_Schema_and_Tables.sql`. 


## Description

Below you will find the description of the main relations in the database

### Schema `Training`
This schema is used to store the information of the training and testing sets used for calculating for checking the accuracy of the application:

 - `training.articles_authors`: Contains the information of the signatures used for the training and testing sets. It links to complete information of the articles and signatures located in the `source` tables.
 - `training.v_authors_distance`: View that agregates the information needed for the training/testing sets of the application.
 - `training.v_training_focus_names`: View that contains the focus names used for the training set.
 - `training.v_testing_focus_names`: View that contains the focus names used for the testing set.
 - `training.v_authors_distance_training`: View that contains the aggregated information for the training set, using the views `training.v_authors_distance` and `training.v_training_focus_names`.
 - `training.v_authors_distance_testing`: View that contains the aggregated information for the testing set, using the views `training.v_authors_distance` and `training.v_testing_focus_names`.

### Schema `Source`
This schema contains the information of the source data of the articles, preprocessed and organized according the schema of the application:

 - `source.articles`: Table that contains the information of the articles present in the system. This is an important table as it contains the `id` of the articles (referenced by most of the other relations) and the `processid` for processing information from the web application.
 - `source.signatures`: Table that contains the information of the signature of an author present in an specific article. A signature is identified by the combination of the `id` of the article and the position of the signature in the article `d`.
 - `source.keywords`: Table that contains the different keywords for every article. 
 - `source.subjects`: Table that contains the different subjects which each article belongs to.
 - `source.references`: Table that contains the different journals referenced by each article.

### Schema  `Distances`
This schema contains the tables to temporaly store the calculated distances of the different features of the application:

 - `distances.title`: Table that contains the distances between the titles of a pair of articles.
 - `distances.subject`: Table that contains the distances between the subjects of a pair of articles.
 - `distances.refs`: Table that contains the distances between the subjects referenced by a pair of articles.
 - `distances.keywords`: Table that contains the distances between the keywords of a pair of articles.
 - `distances.coauthor`: Table that contains the distances between the coauthors of a pair of articles.
 - `distances.ethnicity`: Table that contains the distances between the posible ethnicities of a pair of signatures.

### Schema `Main`
This schema contains the main information of the application:

 - `main.articles_authors`:  Table that contains the information of the signatures and the link to the articles. This also includes `the focus_name` of the signature.
 - `main.lda_topic`: Table that contains the LDA Topics of each article in the application.
 - `main.last_name_ethnicities`: Table that contains the possible ethnicities for each last name in the application.
 - `main.info_for_distances`: Table that aggregates the information needed to calculate the distances between two signatures in the application.
 - `main.v_articles_distance`: View that aggregates the different distances between a pair of articles.
 - `main.v_authors_distance`: View that aggregates the different distances between a pair of signatures.
 - `main.same_authors`: Table that contains the result of calculating if a pair of authors are the same or not.
 - `main.authors_disambiguated`: Table that contains the result of disambiguating and clustering the authors of the application.

