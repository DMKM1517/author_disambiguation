# install.packages("RPostgreSQL")
# install.packages("stringr")
# install.packages("glmnet")
# install.packages("reshape2")
# install.packages("rjson")
# install.packages("assertive")
# install.packages("kimisc")

library(RPostgreSQL, quietly = TRUE, warn.conflicts = FALSE)
library(stringr, quietly = TRUE, warn.conflicts = FALSE)
library(glmnet, quietly = TRUE, warn.conflicts = FALSE)
library(reshape2, quietly = TRUE, warn.conflicts = FALSE)
library(rjson, quietly = TRUE, warn.conflicts = FALSE)
library(assertive, quietly = TRUE, warn.conflicts = FALSE)
library(kimisc, quietly = TRUE, warn.conflicts = FALSE)

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

######################################################


#################### CHANGE WORKING DIRECTORY #######################

# Changes the working directory to the folder of the current file
this.dir <- NULL

this.dir <- thisfile()
if(!is.null(this.dir)){
    this.dir <- str_replace_all(this.dir, "\\\\", "/")
    this.dir <- paste(unlist(str_split(this.dir, "/"))[1:length(unlist(str_split(this.dir, "/")))-1], sep = "/", collapse = "/")
}else{
    this.dir <-dirname(rstudioapi::getActiveDocumentContext()$path)
}

if(is.null(this.dir)){
    print("Setting working directory failed. Script might fail to work.")
}else{
    setwd(this.dir)
    print(paste("Working directory changed successfully to: ", this.dir))
}

#################### DATA ACQUISITION #######################

#Get the arguments it only expects the focus_name to handle
args <- commandArgs(TRUE)
print(args)

# process_id <- ifelse(is.null(args), "ERROR", args[1])
process_id <- ifelse(is.null(args), "10009", args[1])

if(process_id == 'ERROR' | is.na(as.numeric(process_id))){
    stop("Non-valid processid received. Please pass a valid processid as parameter.")
}else{
    
    ## Starts the Global Timer
    #Parallel Loop
    processStrt <- Sys.time()
    
    #### 1. Add to main and calculate focus names ####
    print("#### 1. Add to main and calculate focus names ####")
    
    # Gets the DB Connection
    con <- getDBConnection()
    
    #Query to get the signatures of the processid calculating the focus_name
    query_main <- "
        select
        	s.id,
        	s.d,
        	s.last_name || ' ' || s.fn_initial || s.mn_initial as author,
        	s.last_name,
        	s.fn_initial,
        	s.mn_initial,
        	metaphone(s.last_name, 5) as focus_name
        from
        	source.articles a
        	join source.signatures s on a.id = s.id
        where a.processid = :PROCESSID:;"
    query_main <- str_replace_all(query_main, ":PROCESSID:", process_id)
    df_main <- dbGetQuery(con, query_main)

    #adds the signatures to the main table
    safeUpsert(con, df_main, c("main", "articles_authors"), c("id", "d"))

    # disconnect from the database
    dbDisconnect(con)

    #Cleanup
    rm(con, query_main, df_main)


    #### 2. Calculate LDA Topic ####
    print("#### 2. Calculate LDA Topic ####")
    source("./Calculate_LDA_topic.R", local = TRUE) #This process all the articles with no LDA_Topic


    #### 3. Calculate Ethnicities ####
    source("./Calculate_Ethnicity.R", local = TRUE) #This process all the last names with no ethinicities


    #### 4. Aggregate the Distances' Info ####
    print("#### 4. Aggregate the Distances' Info ####")
    
    # Gets the DB Connection
    con <- getDBConnection()

    #Query to get the signatures of the processid calculating the focus_name
    query_info_dist <- "
        select
        	a.processid,
            aa.id,
            aa.d,
            aa.focus_name,
            a.title,
            k.keywords,
            refs.references,
            sub.subjects,
            aa2.coauthors,
            aa.last_name,
            et.eth_aian_api_bck_hsp_twr_wht
        from
            main.articles_authors aa
            join (
                select id, string_agg(focus_name, ':::') as coauthors
                from main.articles_authors
                group by id) aa2 on aa.id = aa2.id
            join source.articles a on a.id = aa.id
            left join (
                select id, string_agg(keyword, ':::') as keywords
                from source.keywords
                group by id) k on aa.id = k.id
            left join (
                select id, string_agg(journal, ':::') as references
                from source.references
                group by id) refs on aa.id = refs.id
            left join (
                select id, string_agg(subject, ':::') as subjects
                from source.subjects
                group by id) sub on aa.id = sub.id
            left join (
                select last_name, api|| '_' || aian || '_' || black|| '_' || hispanic|| '_' || tworace|| '_' || white as eth_aian_api_bck_hsp_twr_wht
                from main.last_name_ethnicities) et on aa.last_name = et.last_name
        where a.processid = :PROCESSID:;"
    query_info_dist <- str_replace_all(query_info_dist, ":PROCESSID:", process_id)
    df_info_dist <- dbGetQuery(con, query_info_dist)
    
    #adds the signatures to the main table
    safeUpsert(con, df_info_dist, c("main", "info_for_distances"), c("id", "d"))

    #Inform
    print(paste("Distances' Info of", nrow(df_info_dist), "articles/signatures where added."))
    
    # disconnect from the database
    dbDisconnect(con)

    #Cleanup
    rm(con, query_info_dist, df_info_dist)
    
    
    #### 5. Calculate Distances ####
    print("#### 5. Calculate Distances ####")
    source("./Calculate_Distances.R", local = TRUE)
    
    
    #### 6. Calculate Equal Authors ####
    print("#### 6. Calculate Equal Authors ####")
    source("./Predict_Equal_Authors.R", local = TRUE)
    
    print(paste("Process completed. It took ", (Sys.time()-strt), ". Results in main.same_authors", sep = ""))
}
