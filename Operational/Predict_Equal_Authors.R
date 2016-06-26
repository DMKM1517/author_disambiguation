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
    
    columns <- paste('"', colnames(data), '"', sep = "")
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
removeDistances <- function(con, process_id)
{
    queryRemove <- "
        DELETE FROM distances.keywords WHERE id1 in (select id from source.articles where processid = :PROCESS_ID:);
        DELETE FROM distances.refs WHERE id1 in (select id from source.articles where processid = :PROCESS_ID:);
        DELETE FROM distances.subject WHERE id1 in (select id from source.articles where processid = :PROCESS_ID:);
        DELETE FROM distances.title WHERE id1 in (select id from source.articles where processid = :PROCESS_ID:);
        DELETE FROM distances.coauthor WHERE id1 in (select id from source.articles where processid = :PROCESS_ID:);
        DELETE FROM distances.ethnicity 
        WHERE last_name_1 in (
            select distinct s.last_name 
            from source.articles a join source.signatures s on a.id = s.id
            where a.processid = :PROCESS_ID:);"
    queryRemove <- str_replace_all(queryRemove, ":PROCESS_ID:", process_id)
    
    dbSendQuery(con, queryRemove)
}

######################################################


#################### CHANGE WORKING DIRECTORY #######################
# 
# # Changes the working directory to the folder of the current file
# this.dir <- NULL
# tryCatch(this.dir <- dirname(sys.frame(1)$ofile), error = function(e) print('Getting file path from location of the file.'))
# 
# if(is.null(this.dir))
#     this.dir <-dirname(rstudioapi::getActiveDocumentContext()$path)
# if(is.null(this.dir)){
#     print("Setting working directory failed. Script might fail to work.")
# }else{
#     setwd(this.dir)
#     print(paste("Working directory changed successfully to: ", this.dir))
# }

#################### DATA ACQUISITION #######################

# Calculated treshold
best_treshold <- 0.340

#Get the arguments it only expects the focus_name to handle
args <- commandArgs(TRUE)

# process_id <- ifelse(is.null(args), "ERROR", args[1])
process_id <- ifelse(is.null(args), "10009", args[1])

if(process_id == 'ERROR' | is.na(as.numeric(process_id))){
    stop("Non-valid processid received. Please pass a valid processid as parameter.")
}else{
    
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
        from
            source.articles a
            join main.v_authors_distance ad on a.id = ad.id1
        where a.processid = :PROCESS_ID:;
    "
    
    #Query for the distances of the current focus_name
    query_distances <- str_replace_all(query_distances, ":PROCESS_ID:", process_id)
    
    # Retreives the distances set from the database
    df_dist <- dbGetQuery(con, query_distances)
    rownames(df_dist) <- df_dist[,1]
    df_dist <- df_dist[,-1]
    # head(df_dist, n = 5)
    # dim(df_dist)
    
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
    # Use the best treshold
    prediction_cvglm <- prediction_cvglm >= best_treshold
    
    #Creates the prediction table based on the 1st step
    cvglm_eqTable <- cbind(str_split_fixed(row.names(prediction_cvglm), "_|-", n=5), prediction_cvglm)
    colnames(cvglm_eqTable) <- c("id1", "d1", "id2", "d2", "focus_name", "same")
    cvglm_eqTable <- data.frame(cvglm_eqTable, stringsAsFactors = FALSE)
    cvglm_eqTable$id1 <- as.numeric(cvglm_eqTable$id1)
    cvglm_eqTable$d1 <- as.numeric(cvglm_eqTable$d1)
    cvglm_eqTable$id2 <- as.numeric(cvglm_eqTable$id2)
    cvglm_eqTable$d2 <- as.numeric(cvglm_eqTable$d2)
    cvglm_eqTable$same <- as.logical(cvglm_eqTable$same)
    
    #Store the equalities
    safeUpsert(con, cvglm_eqTable, c("main", "same_authors"), c("id1", "d1", "id2", "d2", "focus_name"))
    
    #Removes all the distances of the focus name
    removeDistances(con, process_id)
    
    ######################################################
    
    # disconnect from the database
    dbDisconnect(con)
    # dbUnloadDriver(drv)
}
