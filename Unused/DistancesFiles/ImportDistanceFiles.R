# install.packages("RPostgreSQL")
# install.packages("stringr")
# install.packages("splitstackshape")
# install.packages("foreach")
# install.packages("doParallel")
# install.packages("R.utils")
# install.packages("rstudioapi")
# install.packages("rjson")

require("RPostgreSQL")
library(stringr)
library(splitstackshape)
library(R.utils)
library(foreach)
library(doParallel)
library("rjson")



######################################################
#################### FUNCTIONS #######################

#Function that returns the connection to the database
getDBConnection <- function(){
    
    login <- fromJSON(paste(readLines("../../db_login.json"), collapse=""))
    
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
calculateJaccardDistance <- function(df, column, focusName, id_column = "id")
{
    # df <- df_tt_separated
    # column <- "title"
    # #TEST
    # print(fun_id_vs_column)
    
    # "Function" to reshape the matrix
    fun_id_vs_column <- paste(id_column , "~", column)
    
    # Reshapes the table into a wide format
    df_bin <- acast(df, formula = fun_id_vs_column, fun.aggregate = length, value.var = column)
    
    #cleanup
    rm(df)
    
    # prepare the distance matrix
    distances <- vegdist(df_bin, method = "jaccard")
    
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
    resultDist$focus_name <- rep(focusName, nrow(resultDist))
    
    return(resultDist)
}

# Function that performs a safe upsert into the DB
safeUpsert <- function(con, data, destTable, id_columns){
    # data <- final_last_names
    # destTable <- c('main', 'last_name_ethnicities')
    # id_column <- 'last_name'
    # id_columns <- c('id1', 'id2')
    # data = dist_et, destTable = c("distances", "ethnicity"), id_columns = c("last_name_1", "last_name_2", "focus_name")
    
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


############################################################################################################
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

############# START OF SCRIPT ##################


distance_files <- dir(".", pattern = "^.*[-].*[.].*", full.names = FALSE, ignore.case = TRUE)


#setup parallel backend to use 8 processors
cl<-makeCluster(3)
registerDoParallel(cl)

#Parallel Loop
strt<-Sys.time()
ls<-foreach(
    current_file = distance_files[],
    .packages = c("stringr","RPostgreSQL","splitstackshape","foreach","doParallel", "rjson")) %dopar% {
        
    # for(i in 1:length(distance_files)){
    # current_file <- distance_files[i]

    # Loads the current table with the file name
    current_table <- readRDS(current_file)

    #Removes all lower diagonal and distances equal to 1 and same id's
    current_table <- current_table[current_table$id2>=current_table$id1 & current_table[,3]<1 & current_table$id1 != current_table$id2,]

    #splits the file name (1.focus_name, 2.schema, 3.table)
    file_info <- str_split_fixed(current_file, pattern = "-|[.]", n = 3)

    #Get DB Connection
    con <- getDBConnection()

    #Inserts into the DB
    safeUpsert(con, current_table, destTable = file_info[,2:3], id_columns = colnames(current_table)[c(1,2,4)])

    #Close connection
    dbDisconnect(con)

    #move file to processed folder
    file.rename(from = paste("./", current_file, sep=""),  to = paste("./processed/", current_file, sep=""))
}

print("Parallel Loop Duration:")
print(Sys.time()-strt)
stopCluster(cl)

