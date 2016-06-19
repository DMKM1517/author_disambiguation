
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

#################### CHANGE WORKING DIRECTORY #######################

# Changes the working directory to the folder of the current file
this.dir <- NULL
tryCatch(this.dir <- dirname(sys.frame(1)$ofile), error = function(e) print('Getting file path from location of the file.'))

if(is.null(this.dir))
    this.dir <-dirname(rstudioapi::getActiveDocumentContext()$path)
if(is.null(this.dir)){
    print("Setting working directory failed. Script might fail to work.")
}else{
    setwd(this.dir)
    print(paste("Working directory changed successfully to: ", this.dir))
}

######### START OF THE SCRIPT ###############

# Gets the connection from the DB
con <- getDBConnection()

# get top 27 articles in each subject (distinct~5100 rows)

query_words <- 
"SELECT distinct sub.id, sub.tt FROM (       
WITH TOPTEN AS (
SELECT *, ROW_NUMBER() 
over (
PARTITION BY tab.subject 
order by id
) AS RowNo 
FROM (SELECT 
k.id, s.subject,
concat_ws(', ', lower(k.keywords)::text, lower(a.title::text)) as tt
FROM
(SELECT id, string_agg(keyword, ', ') as keywords
FROM source.keywords
GROUP BY id) k,
source.articles a,
source.subjects s
WHERE 
k.id = a.id
and k.id = s.id) tab
)
SELECT * FROM TOPTEN WHERE RowNo <= 27) sub"

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
lda <- LDA(matrix, 10) # LDA with 10 topics

# save the lda model

saveRDS(lda, "../models/LDA_model.rds")

#close the db connection
dbDisconnect(con)