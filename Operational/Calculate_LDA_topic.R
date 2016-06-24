
# install.packages("topicmodels")
# install.packages("RTextTools")
# install.packages("R.utils")

library(stringr)
require("RPostgreSQL")
library(reshape)
library(vegan)
library(tm)
library(RTextTools)
library(topicmodels)
library("rjson")
library("R.utils")

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

# Function that performs a safe upsert into the DB
safeUpsert <- function(con, data, destTable, id_columns){
  # data <- final_last_names
  # destTable <- c('main', 'fda_topic')
  # id_columns <- 'id'
  
  #load R.utils library (needed otherwise it breaks)
  library(R.utils)
  
  #sets the temp table
  tempTable <- destTable
  tempTable[length(tempTable)] <- paste(tempTable[length(tempTable)], ceiling(System$currentTimeMillis()), sep = "_")
  
  dbWriteTable(con, tempTable, value = data, row.names = FALSE)
  
  query_id_columns <- paste(id_columns, collapse = ", ")
  query_equal_id_columns <- paste(paste('dest', id_columns, sep='.'), paste('temp', id_columns, sep='.'), sep='=', collapse = " AND ")
  query_null_id_columns <- paste(paste('dest', id_columns, sep='.'), 'is null', sep=' ', collapse = " AND ")
  
  query_dest_table <- paste(destTable, collapse = '.')
  query_temp_table <- paste(tempTable, collapse = '.')
  
  columns <- colnames(data)
  query_columns <- paste(columns, collapse = ", ")
  query_temp_columns <- paste('temp', columns, sep='.', collapse = ", ")
  query_dest_columns <- paste('dest', columns, sep='.', collapse = ", ")
  
  query_assign_columns <- paste(columns, paste('temp', columns, sep='.'), sep='=', collapse = ", ")
  
  query_upsert <- "
  CREATE INDEX ON :temp_table: (:id_columns:);
  
  UPDATE :dest_table: AS dest 
  SET 
  :assign_columns:
  FROM :temp_table: AS temp
  WHERE :query_equal_id_columns:;
  
  INSERT INTO :dest_table:
  (:columns:)
  SELECT 
  :temp_columns:
  FROM
  :dest_table: dest
  right join :temp_table: temp on :query_equal_id_columns:
  where
  :null_id_columns:;
  "
  query_upsert <- str_replace_all(query_upsert, ":id_columns:", query_id_columns)
  query_upsert <- str_replace_all(query_upsert, ":query_equal_id_columns:", query_equal_id_columns)
  query_upsert <- str_replace_all(query_upsert, ":null_id_columns:", query_null_id_columns)
  query_upsert <- str_replace_all(query_upsert, ":dest_table:", query_dest_table)
  query_upsert <- str_replace_all(query_upsert, ":temp_table:", query_temp_table)
  query_upsert <- str_replace_all(query_upsert, ":assign_columns:", query_assign_columns)
  query_upsert <- str_replace_all(query_upsert, ":columns:", query_columns)
  query_upsert <- str_replace_all(query_upsert, ":temp_columns:", query_temp_columns)
  query_upsert <- str_replace_all(query_upsert, ":dest_column:", query_dest_columns)
  
  # cat(query_upsert)
  dbSendQuery(con, query_upsert)
  
  #Drop the temp table
  query_drop_temp <- str_replace_all("DROP TABLE IF EXISTS :temp_table:;", ":temp_table:", query_temp_table)
  dbSendQuery(con, query_drop_temp)
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

query2 <- "
SELECT 
    a.id, 
    concat_ws(', ', lower(k.keywords)::text, lower(a.title::text)) as tt
FROM
    source.articles a
    left JOIN (SELECT id, string_agg(keyword, ', ') as keywords
        FROM source.keywords
        GROUP BY id) k ON k.id = a.id
    LEFT JOIN main.fda_topic f ON a.id = f.id
WHERE 
    f.topic IS NULL
LIMIT 2000;"

df_articlesTEST <- dbGetQuery(con, query2)
colnames(df_articlesTEST)<-c("id", "text")

# test
# df_articlesTEST[1,]
# head(df_articlesTEST)
# dim(df_articlesTEST)

# set article ids as rownames

df_articlesTEST <- data.frame(df_articlesTEST[,-1], row.names=df_articlesTEST[,1])
head(df_articlesTEST)

# read LDA model

lda <- readRDS("../models/LDA_model.rds")

# create the DocumentTermMatrix
matrix2 <- create_matrix(as.vector(df_articlesTEST), language="english", removeNumbers=TRUE, stemWords=TRUE, weighting=weightTf)

lda_pred <- posterior(lda, matrix2) # LDA with 10 topics
#print(lda_pred)


# toptopics - which article corresponds most to which topic

toptopics_TEST <- data.frame(cbind(document = row.names(df_articlesTEST), 
                                      topic = apply(lda_pred$topics,1,function(x) rownames(lda_pred$topics)[which(x==max(x))] [1])  ), stringsAsFactors = F)
# itest
names(toptopics_TEST) <- c("id", "topic")
# head(toptopics_TEST)
toptopics_TEST$id <- as.numeric(toptopics_TEST$id)
toptopics_TEST$topic <- as.numeric(toptopics_TEST$topic)

#Store the values into the DB

safeUpsert(con, toptopics_TEST, c('main', 'fda_topic'), 'id')

#close the db connection
dbDisconnect(con)

