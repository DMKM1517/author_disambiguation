
# install.packages("topicmodels")
# install.packages("RTextTools")

library(stringr)
require("RPostgreSQL")
library(reshape)
library(vegan)
library(tm)
library(RTextTools)
library(topicmodels)
library("rjson")

######################################################
#################### FUNCTIONS #######################

#Function that returns the connection to the database
getDBConnection <- function(){
    
    login <- fromJSON(paste(readLines("../db_login.json"), collapse=""))
    
    # loads the PostgreSQL driver
    drv <- dbDriver("PostgreSQL")
    
    # creates a connection to the postgres database
    con <- dbConnect(
        drv, dbname = login$dbname,
        host = login$host,
        port = login$port,
        user = login$user,
        password = login$password
    )
    
    rm(login) # removes the login file
    
    #return the connection
    con
}

######### START OF THE SCRIPT ###############

# Gets the connection from the DB
con <- getDBConnection()

query_words <- 
    "SELECT 
        k.id,
        concat_ws(', ', lower(k.keywords)::text, lower(a.title::text)) as tt
    FROM
        (SELECT id, string_agg(keyword, ', ') as keywords
        FROM public.articles_keywords --TODO: Change schema to source
        GROUP BY id) k,
        public.articles a --TODO: Change schema to source
    WHERE 
        k.id = a.id
        and a.id in (
            select distinct id
            from training.articles_authors
        )"

# GRAB the article ids and keywords+titles

df_articlesKwT <- dbGetQuery(con, query_words)
colnames(df_articlesKwT)<-c("id", "text")
# test
# df_articlesKwT[1,]
# head(df_articlesKwT)
# dim(df_articlesKwT)

# set article ids as rownames

df_articlesKwT <- data.frame(df_articlesKwT[,-1], row.names=df_articlesKwT[,1])
head(df_articlesKwT)

# create the DocumentTermMatrix
matrix <- create_matrix(as.vector(df_articlesKwT), language="english", removeNumbers=TRUE, stemWords=TRUE, weighting=weightTf)
lda <- LDA(matrix, 10) # LDA with 30 topics

terms(lda,5) # 5 most frequent terms of all topics

# gammaDF - relevance of articles to each of the topics

gammaDF <- as.data.frame(lda@gamma) 
names(gammaDF) <- c(1:10) # 30 topics
head(gammaDF)

# toptopics - which article corresponds most to which topic

toptopics <- as.data.frame(cbind(document = row.names(df_articlesKwT), 
                                 topic = apply(gammaDF,1,function(x) names(gammaDF)[which(x==max(x))])))
# itest
names(toptopics) <- c("id", "topic")
head(toptopics)
str(toptopics)

#Store the values into the DB
dbWriteTable(
    con, c("main", "fda_topic"), value = toptopics, append = TRUE, row.names = FALSE
)

#close the db connection
dbDisconnect(con)

