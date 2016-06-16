
# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("caret")
# install.packages("e1071")
# install.packages("fpc")
require("RPostgreSQL")
library(randomForest)
library(caret)
library(stringr)
library(reshape2)
library(fpc)
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

# function to calculate the confusion matrix and print the measures
measures <- function(predicted, actual){
    cm <- confusionMatrix(predicted, actual)
    precision <- cm$byClass['Pos Pred Value']    
    recall <- cm$byClass['Sensitivity']
    f_measure <- 2 * ((precision * recall) / (precision + recall))
    print('Confusion matrix')
    print(cm$table)
    print('Measures')
    res <- data.frame(cbind(cm$overall['Accuracy'], precision, recall, f_measure), row.names = '1')
    colnames(res) <- c('Accuray','Precision','Recall','F1')
    print(res)
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

######################################################


# Gets the connection from the DB
con <- getDBConnection()

#query to get the view of distances
query_distances <- 
    "select 
id1 || '-' || d1 || '_' || id2 || '-' || d2 || '_' || last_name as id_distances, 
eq_finitial,
eq_sinitial,
eq_topic,
diff_year,
dist_keywords,
dist_refs,
dist_subject,
dist_title,
dist_coauthor,
same_author
from v_authors_distance_disambiguated_:TABLE:
-- where last_name in (
--     select distinct last_name
--     from v_authors_distance_disambiguated_:TABLE:
--     limit 1
-- );"
#Query for the training set
query_distances_training <- str_replace_all(query_distances, ":TABLE:", "training")
#Query for the testing set
query_distances_testing <- str_replace_all(query_distances, ":TABLE:", "testing")


# Retreives the training set from the database
df.train <- dbGetQuery(con, query_distances_training)
rownames(df.train) <- df.train[,1]
df.train <- df.train[,-1]
head(df.train, n = 10)
dim(df.train)

# Retreives the testing set from the database
df.test <- dbGetQuery(con, query_distances_testing)
rownames(df.test) <- df.test[,1]
df.test <- df.test[,-1]
head(df.test, n = 10)
dim(df.test)


# separate x and y
df_x.train <- df.train[,1:(length(df.train) - 1)]
df_y.train <- as.factor(df.train$same_author)
df_x.test <- df.test[,1:(length(df.train) - 1)]
df_y.test <- as.factor(df.test$same_author)


# random forest
rf <- randomForest(df_x.train, df_y.train, df_x.test, df_y.test)#, proximity=TRUE)
# rf$confusion
# head(rf$predicted, n=10)
# head(rf$test$predicted, n=20)


calculateClusters <- function(distTable) {
    ## Calculate the clusters
    
    query_max_cluster <-"
    select case when max(cluster) is null then 0 else max(cluster) end as max_cluster
    from xref_authors_clusters;
    "
    df.max <- dbGetQuery(con, query_max_cluster)
    #Current max number of cluster
    df.max[1,1]
    
    
    #Create the distance matrix
    head(rf$test$votes, n=20)
    # distTable <- cbind(str_split_fixed(row.names(rf$test$votes), "_", n=3), (rf$test$votes[,1] ))
    colnames(distTable) <- c("id1_d1", "id2_d2", "last_name", "dist")
    distTable <- as.data.frame(distTable, stringsAsFactors = FALSE)
    distTable$dist <- as.numeric(distTable$dist)
    head(distTable)
    
    # Reshapes the table into a wide format
    distMatrix <- acast(distTable, formula = id1_d1 ~ id2_d2, fun.aggregate = mean, fill = 1)
    
    
    clusters <- hclust(as.dist(distMatrix))
    #plot(clusters, cex=0.5)
    head(clusters)
    cut <- as.data.frame(cutree(clusters, h = 0.1))
    head(cut)
    
    dbClusters <- cbind(str_split_fixed(row.names(cut), "-", n=2), (cut[,1] + df.max[1,1]))
    dbClusters <- as.data.frame(dbClusters, stringsAsFactors=FALSE)
    colnames(dbClusters) <- c("id1", "d1", "cluster")
    
    head(dbClusters, n=30)
    #Writes into the table
    dbSendQuery(con, "TRUNCATE TABLE xref_authors_clusters;")
    dbWriteTable(
        con, "xref_authors_clusters", value = dbClusters, append = TRUE, row.names = FALSE
    )
    
    # bring the real cluster
    query_cluster_test <- 
        "select 
    c.id,
    c.d,
    ad.authorid as real_cluster,
    c.cluster as computed_cluster
    from
    xref_authors_clusters c
    join xref_articles_authors_disambiguated ad on c.id = ad.id and c.d = ad.d
    ;"
    clusterTest <- dbGetQuery(con, query_cluster_test)
    
    
    # comparing 2 cluster solutions
    
    pairwiseMetrics(clusterTest$computed_cluster, clusterTest$real_cluster)
    b3Metrics(clusterTest$computed_cluster, clusterTest$real_cluster)
    
    
    # disconnect from the database
    dbDisconnect(con)
    # dbUnloadDriver(drv)
}