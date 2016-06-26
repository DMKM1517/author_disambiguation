#install.packages("RPostgreSQL")
#install.packages("reshape")
#install.packages("reshape2")
#install.packages("vegan")
#install.packages("stringr")
#install.packages("tm")
#install.packages("splitstackshape")
#install.packages("foreach")
#install.packages("doParallel")
# install.packages("R.utils")
# install.packages("rjson")

library(stringr, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
require("RPostgreSQL", quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(reshape2, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(vegan, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(tm, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(splitstackshape, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)

library(R.utils, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(foreach, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library(doParallel, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
library("rjson", quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)

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

# Function that calculates the JaccarDistance according to a received DataFrame
calculateJaccardDistance <- function(df, column, focus_name, id_column = "id")
{
    # df <- df_tt_separated
    
    # "Function" to reshape the matrix
    fun_id_vs_column <- paste(id_column , "~", column)
    
    # Reshapes the table into a wide format
    df_bin <- acast(df, formula = fun_id_vs_column, fun.aggregate = length, value.var = column)
    
    #cleanup
    rm(df)
    
    # prepare the distance matrix
    distances <- vegdist(df_bin, method = "jaccard", upper = FALSE)
    
    #cleanup
    rm(df_bin)
    
    # transform dist type into a matrix
    attributes(distances)$Diag <- FALSE
    distmat <- as(distances, "matrix")
    
    #cleanup
    rm(distances)
    
    # melt the matrix
    resultDist <- melt(distmat)
    
    #cleanup
    rm(distmat)
    
    #Rename the columns
    colnames(resultDist) <- c("id1", "id2", "dist")
    resultDist$focus_name <- focus_name
    
    return(resultDist)
}



# Function that performs a safe upsert into the DB
safeUpsert <- function(con, data, destTable, id_columns){
    # data <- final_last_names
    # destTable <- c('main', 'fda_topic')
    # id_columns <- 'id'
    
    #load R.utils library (needed otherwise it breaks)
    library(R.utils, quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE)
    
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


calculateDistancesOfPair <- function (pair_data) {

    #Focus name of the pair
    focus_name <- pair_data$focus_name
    
    pair_distances <- pair_data[c('id1', 'id2', 'focus_name')]
    
    ######### DISTANCE FOR TITLE ###############
    # print(paste("Starting Distance for Title:", focusName))
    
    #Creates the df for the title
    df_tt <- rbind(
                cbind(id = pair_data$id1, title = pair_data$title1),
                cbind(id = pair_data$id2, title = pair_data$title2))
    df_tt <- data.frame(df_tt, stringsAsFactors = FALSE)
    
    # Clean the Fields
    df_tt$title <- lapply(df_tt$title, cleanField)
    # head(df_tt, n = 20)
    
    # Expands the keywords into individual rows
    df_tt_separated <- data.frame(id=rep(df_tt$id, sapply(df_tt$title, FUN=length)), title=unlist(df_tt$title), stringsAsFactors = FALSE)
    # head(df_tt_separated, n=20)
    
    # Calculate the distances of the keywords
    dist_title <- calculateJaccardDistance(df_tt_separated, "title", focus_name)
    pair_distances$dist_title <- dist_title$dist[dist_title$id1 == pair_data$id1 & dist_title$id2 == pair_data$id2]
    
    #cleanup
    rm(df_tt, df_tt_separated, dist_title)
    
    
    ######### DISTANCE FOR KEYWORDS ###############
    # print(paste("Starting Distance for Keywords: ", focusName))
    
    #Creates the df for the keywords
    df_kw <- rbind(
        cbind(id = pair_data$id1, keyword = unlist(str_split(pair_data$keywords1, ":::"))),
        cbind(id = pair_data$id2, keyword = unlist(str_split(pair_data$keywords2, ":::"))))
    df_kw <- data.frame(df_kw, stringsAsFactors = FALSE)
    # head(df_kw, n = 20)
    # dim(df_kw)
    
    # Clean the Fields
    df_kw$keyword <- lapply(df_kw$keyword, cleanField)
    # head(df_kw, n=10)
    
    # Expands the keywords into individual rows
    df_kw_separated <- data.frame(id=rep(df_kw$id, sapply(df_kw$keyword, FUN=length)), keyword=unlist(df_kw$keyword), stringsAsFactors = FALSE)
    # head(df_kw_separated, n=20)
    
    # Calculate the distances of the keywords
    dist_keywords <- calculateJaccardDistance(df_kw_separated, "keyword", focus_name)
    pair_distances$dist_keywords <- dist_keywords$dist[dist_keywords$id1 == pair_data$id1 & dist_keywords$id2 == pair_data$id2]
   
    #cleanup
    rm(df_kw, df_kw_separated, dist_keywords)
    
    
    ######### DISTANCE FOR REFS ###############
    # print(paste("Starting Distance for References: ", focusName))
    
    #Creates the df for the references
    df_ref <- rbind(
        cbind(id = pair_data$id1, journal = unlist(str_split(pair_data$references1, ":::"))),
        cbind(id = pair_data$id2, journal = unlist(str_split(pair_data$references2, ":::"))))
    df_ref <- data.frame(df_ref, stringsAsFactors = FALSE)
    # head(df_ref, n = 10)
    # dim(df_ref)
    
    # Clean the Fields
    df_ref$journal <- lapply(df_ref$journal, cleanField)
    df_ref$journal <- lapply(df_ref$journal, FUN='paste', collapse=" ")
    df_ref$journal <- sapply(df_ref$journal, '[[', 1)
    # head(df_ref, n=10)

    # Calculate the distances of the keywords
    dist_ref <- calculateJaccardDistance(df_ref, "journal", focus_name)
    pair_distances$dist_refs <- dist_ref$dist[dist_ref$id1 == pair_data$id1 & dist_ref$id2 == pair_data$id2]
    
    #cleanup
    rm( df_ref, dist_ref) 
    
    
    ######### DISTANCE FOR SUBJECT ###############
    # print(paste("Starting Distance for Subject: ", focusName))

    #Creates the df for the subjects
    df_sub <- rbind(
        cbind(id = pair_data$id1, subject = unlist(str_split(pair_data$subjects1, ":::"))),
        cbind(id = pair_data$id2, subject = unlist(str_split(pair_data$subjects2, ":::"))))
    df_sub <- data.frame(df_sub, stringsAsFactors = FALSE)
    # head(df_sub, n = 10)
    # dim(df_sub)
    
    # Clean the Fields
    df_sub$subject <- lapply(df_sub$subject, cleanField)
    # head(df_sub, n = 20)
    
    # Expands the keywords into individual rows
    df_sub_separated <- data.frame(id=rep(df_sub$id, sapply(df_sub$subject, FUN=length)), subject=unlist(df_sub$subject), stringsAsFactors = FALSE)
    # head(df_sub_separated, n=20)
    
    # Calculate the distances of the keywords
    dist_sub <- calculateJaccardDistance(df_sub_separated, "subject", focus_name)
    pair_distances$dist_subject <- dist_sub$dist[dist_sub$id1 == pair_data$id1 & dist_sub$id2 == pair_data$id2]
    
    #cleanup
    rm(df_sub, df_sub_separated, dist_sub)
    
    
    ######### DISTANCE FOR COAUTORS ###############
    # print(paste("Starting Distance for Coautors: ", focusName))
    
    #Creates the df for the coauthors
    df_ca <- rbind(
        cbind(id = pair_data$id1, author = unlist(str_split(pair_data$coauthors1, ":::"))),
        cbind(id = pair_data$id2, author = unlist(str_split(pair_data$coauthors2, ":::"))))
    df_ca <- data.frame(df_ca, stringsAsFactors = FALSE)
    # head(df_ca, n = 10)
    # dim(df_ca)
    
    # Calculate the distances of the keywords
    dist_ca <- calculateJaccardDistance(df_ca, "author", focus_name)
    pair_distances$dist_coauthor <- dist_ca$dist[dist_ca$id1 == pair_data$id1 & dist_ca$id2 == pair_data$id2]
    
    #cleanup
    rm(df_ca, dist_ca)

        
    ######### DISTANCE FOR ETHNICITY ###############
    # print(paste("Starting Distance for Ethnicity: ", focusName))
    
    #Creates the df for the coauthors
    df_et <- rbind(
        c(pair_data$last_name1, unlist(str_split(pair_data$eth_aian_api_bck_hsp_twr_wht1, "_"))),
        c(pair_data$last_name2, unlist(str_split(pair_data$eth_aian_api_bck_hsp_twr_wht2, "_"))))
    df_et <- data.frame(df_et, stringsAsFactors = FALSE)
    names(df_et) <- c('last_name', 'aian', 'api', 'black', 'hispanic', 'tworace', 'white')
    # head(df_et, n = 10)
    # dim(df_et)
    
    #Melt the table so we have the ethnicities in one column only
    df_et_molten = melt(df_et, na.rm = TRUE, id = "last_name")
    df_et_molten[,2] <- paste(df_et_molten[,3], df_et_molten[,2], sep = "_")
    df_et_molten <- df_et_molten[,1:2]
    colnames(df_et_molten) <- c('last_name', 'ethnicity')
    
    # Calculate the distances of the keywords
    dist_et <- calculateJaccardDistance(df_et_molten, "ethnicity", focus_name, id_column = "last_name")
    pair_distances$last_name_1 <- pair_data$last_name1
    pair_distances$last_name_2 <- pair_data$last_name2
    pair_distances$dist_ethnicity <- dist_et$dist[dist_et$id1 == pair_data$last_name1 & dist_et$id2 ==pair_data$last_name2]
    
    #cleanup
    rm(df_et, df_et_molten, dist_et)
    
    #Return the distances of the pair
    return(pair_distances)
    
}

############### END OF FUNCTIONS #####################
######################################################



############################################################################################################
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

############# START OF SCRIPT ##################

#Get the arguments it only expects the focus_name to handle
args <- commandArgs(TRUE)

process_id <- ifelse(is.null(args), "ERROR", args[1])
# process_id <- ifelse(is.null(args), "10009", args[1])

# if(TRUE){
if(process_id == 'ERROR' | is.na(as.numeric(process_id))){
    stop("Non-valid processid received. Please pass a valid processid as parameter.")
}else{
    
    # Gets the connection from the DB
    con <- getDBConnection()
    
    # Query to retrieve all focus names
    query_to_process <- "
        select
            i1.id as id1,
            i1.d as d1,
            i2.id as id2,
            i2.d as d1,
            i1.focus_name,
            i1.title as title1,
            i2.title as title2,
            i1.keywords as keywords1,
            i2.keywords as keywords2,
            i1.references as references1,
            i2.references as references2,
            i1.subjects as subjects1,
            i2.subjects as subjects2,
            i1.coauthors as coauthors1,
            i2.coauthors as coauthors2,
            i1.last_name as last_name1,
            i2.last_name as last_name2,
            i1.eth_aian_api_bck_hsp_twr_wht as eth_aian_api_bck_hsp_twr_wht1,
            i2.eth_aian_api_bck_hsp_twr_wht as eth_aian_api_bck_hsp_twr_wht2
        from
            (   select * 
                from main.info_for_distances
                where processid = :PROCESSID:) i1
            join main.info_for_distances i2 on i1.focus_name = i2.focus_name
        where
            (i1.id <> i2.id or i1.d <> i2.d);"
    query_to_process <- str_replace_all(query_to_process, ":PROCESSID:", process_id)
    df_to_process <- dbGetQuery(con, query_to_process)
    
    # head(df_to_process, n = 20)
    
    #setup parallel backend to use 8 processors
    cl<-makeCluster(detectCores() - 1)
    # cl<-makeCluster(1)
    registerDoParallel(cl)

    #Parallel Loop
    strt<-Sys.time()
    full_pair_distances <- foreach(
        i = 1:nrow(df_to_process),
         # i = 1:5,
        .packages = c("stringr","RPostgreSQL","reshape2","vegan","tm","splitstackshape","foreach","doParallel", "rjson"),
        .combine = rbind) %dopar% {

        # i <- 1
        pair_distances <- calculateDistancesOfPair(pair_data = df_to_process[i,])

        #return the distances of the pair
        pair_distances
    }
    full_pair_distances <- as.data.frame(full_pair_distances, stringsAsFactors = FALSE)    
    
    print("Parallel Loop Duration:")
    print(Sys.time()-strt)
    stopCluster(cl)
    
    #Store results into DB
    if(nrow(full_pair_distances) > 0) {
        #Store dist_title
        unique_title <- unique(full_pair_distances[,c('id1', 'id2', 'dist_title', 'focus_name')])
        safeUpsert(con, unique_title, c('distances', 'title'), c('id1', 'id2', 'focus_name'))
        
        #Store dist_keywords
        unique_kw <- unique(full_pair_distances[,c('id1', 'id2', 'dist_keywords', 'focus_name')])
        safeUpsert(con, unique_kw, c('distances', 'keywords'), c('id1', 'id2', 'focus_name'))
        
        #Store dist_refs
        unique_refs <- unique(full_pair_distances[,c('id1', 'id2', 'dist_refs', 'focus_name')])
        safeUpsert(con, unique_refs, c('distances', 'refs'), c('id1', 'id2', 'focus_name'))
        
        #Store dist_subject
        unique_subs <- unique(full_pair_distances[,c('id1', 'id2', 'dist_subject', 'focus_name')])
        safeUpsert(con, unique_subs, c('distances', 'subject'), c('id1', 'id2', 'focus_name'))
        
        #Store dist_coauthor
        unique_coauth <- unique(full_pair_distances[,c('id1', 'id2', 'dist_coauthor', 'focus_name')])
        safeUpsert( con, unique_coauth, c('distances', 'coauthor'), c('id1', 'id2', 'focus_name'))
        
        #Store dist_ethnicity
        unique_eths <- unique(full_pair_distances[,c('last_name_1', 'last_name_2', 'dist_ethnicity', 'focus_name')])
        safeUpsert(con, unique_eths, c('distances', 'ethnicity'), c('last_name_1', 'last_name_2', 'focus_name'))
        
        #Cleanup
        rm(unique_title, unique_kw, unique_refs, unique_subs, unique_coauth, unique_eths)
    }
    
    #Close connection
    dbDisconnect(con)
    
}
    
