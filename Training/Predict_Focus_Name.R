# install.packages("RPostgreSQL")
# install.packages("stringr")
# install.packages("glmnet")
# install.packages("reshape2")
# install.packages("rjson")

require("RPostgreSQL")
library(stringr)
library(glmnet)
library(reshape2)
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


# Function that calculates the clusters based on the distance table of the signatures
calculateClusters <- function(con, distTable) {
    # distTable<- cvglm_distTable

    # Reshapes the table into a wide format
    distMatrix <- acast(distTable, formula = id1_d1 ~ id2_d2, value.var = "dist", fun.aggregate = mean, fill = 1)
    
    # Create the Hierarchical Clustering
    clusters <- hclust(as.dist(distMatrix), method = "complete")
    cut <- as.data.frame(cutree(clusters, h = best_cut))

    #Gets the current max number of author_id (cluster) and locks the main.authors_disambiguated table
    query_max_cluster <-"
        BEGIN WORK;
        LOCK TABLE main.authors_disambiguated IN ACCESS EXCLUSIVE MODE;
    
        select case when max(author_id) is null then 0 else max(author_id) end as max_cluster
        from main.authors_disambiguated;
    "
    max_author_id <- dbGetQuery(con, query_max_cluster)
    max_author_id <- as.numeric(max_author_id)


    #Creates the table that is going to be update in the DB
    dbClusters <- cbind((cut[,1] + max_author_id), str_split_fixed(row.names(cut), "-", n=2))
    dbClusters <- as.data.frame(dbClusters, stringsAsFactors=FALSE)
    colnames(dbClusters) <- c("author_id", "id", "d")
    dbClusters$author_id <- as.numeric(dbClusters$author_id)
    dbClusters$id <- as.numeric(dbClusters$id)
    dbClusters$d <- as.numeric(dbClusters$d)

    # str(dbClusters)
    # head(dbClusters, n=30)

    #Writes into the table
    safeUpsert(con, dbClusters, c("main","authors_disambiguated"), c("id", "d"))
    
    #Commits and unlocks the table
    query_commit <- "COMMIT WORK;"
    dbSendQuery(con, query_commit)
    
}


#Removes all the distances of the focus name
removeFocusNameDistances <- function(con, focus_name)
{
    queryRemove <- "
        DELETE FROM distances.keywords WHERE focus_name = ':FOCUS_NAME:';
        DELETE FROM distances.refs WHERE focus_name = ':FOCUS_NAME:';
        DELETE FROM distances.subject WHERE focus_name = ':FOCUS_NAME:';
        DELETE FROM distances.title WHERE focus_name = ':FOCUS_NAME:';
        DELETE FROM distances.coauthor WHERE focus_name = ':FOCUS_NAME:';
        DELETE FROM distances.ethnicity WHERE focus_name = ':FOCUS_NAME:';"
    queryRemove <- str_replace_all(queryRemove, ":FOCUS_NAME:", focus_name)
    
    dbSendQuery(con, queryRemove)
}

######################################################


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

#################### DATA ACQUISITION #######################

# Calculated treshold and tree cuts from training
best_treshold <- 0.340
best_cut <- 0.8

#Get the arguments it only expects the focus_name to handle
args <- commandArgs(TRUE)

focus_name <- ifelse(is.null(args), "XNK", args[1])

# Gets the DB Connection
con <- getDBConnection()

#query to get the view of distances
query_distances <- "
    select 
        id1 || '-' || d1 || '_' || id2 || '-' || d2 || '_' || focus_name as id_distances, 
        eq_fn_initial,
        eq_mn_initial,
        eq_lda_topic,
        diff_year,
        dist_keywords,
        dist_refs,
        dist_subject,
        dist_title,
        dist_coauthor,
        dist_ethnicity
    from main.v_authors_distance
    where focus_name = ':FOCUS_NAME:';
"

#Query for the distances of the current focus_name
query_distances <- str_replace_all(query_distances, ":FOCUS_NAME:", focus_name)

# Retreives the distances set from the database
df_dist <- dbGetQuery(con, query_distances)
rownames(df_dist) <- df_dist[,1]
df_dist <- df_dist[,-1]
head(df_dist, n = 5)
dim(df_dist)

# transform df_dist as data matrix
df_dist$eq_finitial <- as.factor(df_dist$eq_fn_initial)
df_dist$eq_sinitial <- as.factor(df_dist$eq_mn_initial)
df_dist$eq_topic <- as.factor(df_dist$eq_lda_topic)
df_dist <- data.matrix(df_dist)


#### 1 LOGISTIC REGRESSION ####

# loads the Logistic Regression model
model_cvglm <- readRDS("../models/model_cvglm.rds")

# predict with the model
prediction_cvglm <- predict.cv.glmnet(model_cvglm, df_dist, type = 'response', s="lambda.min")
# # Use the best treshold
# prediction_cvglm <- ifelse(prediction_cvglm >= best_treshold, 1, 0)

#### 2. CLUSTERING ####

#Creates the dist table based on the 1st step
cvglm_distTable <- cbind(str_split_fixed(row.names(prediction_cvglm), "_", n=3), (1-prediction_cvglm))
colnames(cvglm_distTable) <- c("id1_d1", "id2_d2", "focus_name", "dist")
cvglm_distTable <- as.data.frame(cvglm_distTable, stringsAsFactors = FALSE)
cvglm_distTable$dist <- as.numeric(cvglm_distTable$dist)

#Calculates and stores the clusters in the DB
calculateClusters(con, cvglm_distTable)


#Removes all the distances of the focus name
removeFocusNameDistances(con, focus_name)

######################################################

# disconnect from the database
dbDisconnect(con)
# dbUnloadDriver(drv)
