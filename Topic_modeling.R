library(stringr)
require("RPostgreSQL")
library(reshape)
library(vegan)
library(tm)
library(RTextTools)
library(topicmodels)

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

###########################################


query_words <- "SELECT k.id, concat_ws(', ', 
lower(k.keywords)::text, lower(a.title::text)) as tt
FROM
(SELECT id, string_agg(keyword, ', ') as keywords
FROM articles_keywords
GROUP BY id) k, articles a
WHERE k.id=a.id 
LIMIT 2000"

# GRAB the article ids and keywords+titles

df_articlesKwT <- dbGetQuery(con, query_words)
colnames(df_articlesKwT)<-c("id", "text")
# test
# df_articlesKwT[1,]
# head(df_articlesKwT)

# set article ids as rownames

df_articlesKwT <- data.frame(df_articlesKwT[,-1], row.names=df_articlesKwT[,1])
head(df_articlesKwT)

# create the DocumentTermMatrix

matrix <- create_matrix(as.vector(df_articlesKwT), language="english", removeNumbers=TRUE, stemWords=TRUE, weighting=weightTf)
lda <- LDA(matrix, 30) # LDA with 30 topics
terms(lda,5) # 5 most frequent terms of all topics

# gammaDF - relevance of articles to each of the topics

gammaDF <- as.data.frame(lda@gamma) 
names(gammaDF) <- c(1:30) # 30 topics
head(gammaDF)

# toptopics - which article corresponds most to which topic

toptopics <- as.data.frame(cbind(document = row.names(df_articlesKwT), 
                                 topic = apply(gammaDF,1,function(x) names(gammaDF)[which(x==max(x))])))
# itest
head(toptopics)