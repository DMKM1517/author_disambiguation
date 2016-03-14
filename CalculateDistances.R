
#install.packages("RPostgreSQL")
#install.packages("reshape")
#install.packages("reshape2")
#install.packages("vegan")
#install.packages("stringr")
#install.packages("tm")
#install.packages("splitstackshape")
library(stringr)
require("RPostgreSQL")
library(reshape2)
library(vegan)
library(tm)
library(splitstackshape)



######################################################
#################### FUNCTIONS #######################

# Function that calculates the JaccarDistance according to a received DataFrame
calculateJaccardDistance <- function(df, column, currentLastName)
{
  # str(df)
  df[,eval(column)]<- as.factor(df[,eval(column)])
  
  # creates new dummy variables, with names "value.[column]"
  df <- data.frame(df, value = TRUE)
  
  #   head(df)
  df_bin <-
    reshape(df, idvar = c("id"), timevar = column, direction = "wide")
  
  # NA to 0, TRUE to 1
  df_bin[is.na(df_bin)] <- 0
  df_bin[df_bin == TRUE] = 1
  #write.csv(df_bin, file = "df_bin.csv")
  
  # Moves the first column to the row names
  rownames(df_bin) <- df_bin[,1]
  df_bin <- df_bin[,-1]
  
  # prepare the distance matrix
  dist.mat <- vegdist(df_bin, method = "jaccard")
  # str(dist.mat)
  class(dist.mat)
  
  # transform dist type into a matrix
  attributes(dist.mat)$Diag <- FALSE
  distmat <- as(dist.mat, "matrix")
  
  # melt the matrix
  resultDist <- melt(distmat)
  colnames(resultDist) <- c("id1", "id2", "dist")
  resultDist$last_name <- rep(currentLastName, nrow(resultDist))
  resultDist
  
}


# Function that calculates the JaccarDistance according to a received DataFrame
writeDistanceTable <- function(con, dbTable, df)
{
  #Writes into the table
  dbSendQuery(con, paste("truncate table ", dbTable))
  dbWriteTable(
    con, dbTable, value = df, append = TRUE, row.names = FALSE
  )
}

#Function that evaluated NOT IN
'%nin%' <- Negate('%in%')

# Function that cleans a field
cleanField <- function(field) {
  # To lower Case
  t <- tolower(field)
  #Removes Punctuation
  t <- gsub("[[:punct:]]", "", t) 
  #Removes Extra Whitespaces
  t <- gsub("\\s+"," ",t)
  #Splits by whitespace
  t <- unlist(strsplit(t, " "))
  #remove stopwords
  t[t %nin% stopwords(kind="en")]
}

############### END OF FUNCTIONS #####################
######################################################


############# START OF SCRIPT ##################

#assigns the current last name to cluster
currentLastName <- "JKMS"

######### CONNECTION TO DB ###############

pw <- {
  "test"
}

# loads the PostgreSQL driver
drv <- dbDriver("PostgreSQL")
# creates a connection to the postgres database
# note that "con" will be used later in each connection to the database
con <- dbConnect(
  drv, dbname = "ArticlesDB",
  host = "25.39.131.139", port = 5433,
  user = "test", password = pw
)
rm(pw) # removes the password
dbExistsTable(con, "articles")


######### DISTANCE FOR KEYWORDS ###############

#query to get the currentAuthor cluster
query_kw <- 
"select 
  distinct a.id, 
  lower(k.keyword) as keyword 
from
  xref_articles_authors a
  join articles_keywords k on a.id = k.id
where lastname_phon_12 = ':LAST_NAME:'
order by a.id;"

query_kw <- str_replace_all(query_kw, ":LAST_NAME:", currentLastName)

# Retreives the table from the database
df_kw <-
  dbGetQuery(con, query_kw)
head(df_kw, n = 20)
dim(df_kw)

# Clean the Fields
df_kw$keyword <- lapply(df_kw$keyword, cleanField)
head(df_kw, n=10)

# Expands the keywords into individual rows
df_kw_separated <- data.frame(id=rep(df_kw$id, sapply(df_kw$keyword, FUN=length)), keyword=unlist(df_kw$keyword))
head(df_kw_separated, n=20)

# Calculate the distances of the keywords
dist_keywords <-
  calculateJaccardDistance(df_kw_separated, "keyword", currentLastName)

#Correct the names of the dataframe
names(dist_keywords) <-
  c("id1", "id2", "dist_keywords", "last_name")
head(dist_keywords)

#Writes into the table
writeDistanceTable(con, "d_keywords", dist_keywords)


######### DISTANCE FOR TITLE ###############

#query to get the currentAuthor cluster
query_tt <- 
"select 
  distinct aa.id, 
  art.title
from
  xref_articles_authors aa
  join articles art on aa.id = art.id
where lastname_phon_12 = ':LAST_NAME:'
order by aa.id;"

query_tt <- str_replace_all(query_tt, ":LAST_NAME:", currentLastName)

query_tt
# Retreives the table from the database
df_tt <-
  dbGetQuery(con, query_tt)
head(df_tt, n = 10)
dim(df_tt)

# Clean the Fields
df_tt$title <- lapply(df_tt$title, cleanField)
head(df_tt, n = 20)

# Expands the keywords into individual rows
df_tt_separated <- data.frame(id=rep(df_tt$id, sapply(df_tt$title, FUN=length)), title=unlist(df_tt$title))
head(df_tt_separated, n=20)

# Calculate the distances of the keywords
dist_title <-
  calculateJaccardDistance(df_tt_separated, "title", currentLastName)

#Correct the names of the dataframe
names(dist_title) <-
  c("id1", "id2", "dist_title", "last_name")
head(dist_title)

#Writes into the table
writeDistanceTable(con, "d_title", dist_title)



######### DISTANCE FOR REFS ###############


#query to get the currentAuthor cluster
query_ref <- 
  "select 
    distinct aa.id, 
    refs.journal
  from
    xref_articles_authors aa
    join articles_refs_clean refs on aa.id = refs.id
  where 
  	lastname_phon_12 = ':LAST_NAME:'
  order by aa.id;"

query_ref <- str_replace_all(query_ref, ":LAST_NAME:", currentLastName)

# Retreives the table from the database
df_ref <-
  dbGetQuery(con, query_ref)
head(df_ref, n = 10)
dim(df_ref)

# Calculate the distances of the keywords
dist_ref <-
  calculateJaccardDistance(df_ref, "journal", currentLastName)

#Correct the names of the dataframe
names(dist_title) <-
  c("id1", "id2", "dist_refs", "last_name")
head(dist_ref)

#Writes into the table
writeDistanceTable(con, "d_refs", dist_ref)



######### DISTANCE FOR SUBJECT ###############



#query to get the currentAuthor cluster
query_sub <- 
  "select distinct *
from
((select 
distinct aa.id, 
sub.subject
from
xref_articles_authors aa
join articles_subjects sub on aa.id = sub.id
where 
aa.lastname_phon_12 = ':LAST_NAME:'
order by aa.id)  
UNION
(select 
distinct aa.id, 
sub.subject
from
xref_articles_authors aa
join subject_asociations sub on aa.id = sub.id
where 
aa.lastname_phon_12 = ':LAST_NAME:'
order by aa.id)  ) subs
order by id;"

query_sub <- str_replace_all(query_sub, ":LAST_NAME:", currentLastName)

# Retreives the table from the database
df_sub <-
  dbGetQuery(con, query_sub)
head(df_sub, n = 10)
dim(df_sub)

# Calculate the distances of the keywords
dist_sub <-
  calculateJaccardDistance(df_sub, "subject", currentLastName)

#Correct the names of the dataframe
names(dist_title) <-
  c("id1", "id2", "dist_subject", "last_name")
head(dist_sub)

#Writes into the table
writeDistanceTable(con, "d_subject", dist_sub)



