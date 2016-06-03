#install.packages("stringdist")
#install.packages("e1071")
#install.packages("gtools")
#install.packages("sqldf")
# install.packages("ngram")
# install.packages("R.utils")



library(gtools)
library(devtools)
library(ngram)
library(reshape2)
library(stringdist)
library(e1071)
library(caret)
library(randomForest)
library(R.utils)

# setwd("~/R/ethnic")

#################### FUNCTIONS #######################

#Function that returns the connection to the database
getDBConnection <- function(){
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
    #return the connection
    con
}

# Function that cleans a Last Name
cleanLastName <- function(last_name) {
    # To lower Case
    t <- toupper(last_name)
    #Removes Punctuation
    t <- gsub("[[:punct:]]", "", t) 
    #Removes Extra Whitespaces
    t <- gsub("\\s+","",t)
    # Returns the clean last_name
    t
}
# Function that performs a safe upsert into the DB
safeUpsert <- function(con, data, destTable, id_columns){
    # data <- final_last_names
    # destTable <- c('main', 'last_name_ethnicities')
    # id_column <- 'last_name'
    # id_columns <- c('id1', 'id2')
    
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
    query_upsert <- str_replace_all(query_upsert, ":null_id_columns:", query_null_id_columns)
    query_upsert <- str_replace_all(query_upsert, ":assign_columns:", query_assign_columns)
    query_upsert <- str_replace_all(query_upsert, ":dest_table:", query_dest_table)
    query_upsert <- str_replace_all(query_upsert, ":temp_table:", query_temp_table)
    query_upsert <- str_replace_all(query_upsert, ":query_equal_id_columns:", query_equal_id_columns)
    query_upsert <- str_replace_all(query_upsert, ":columns:", query_columns)
    query_upsert <- str_replace_all(query_upsert, ":temp_columns:", query_temp_columns)
    query_upsert <- str_replace_all(query_upsert, ":dest_column:", query_dest_columns)
    
    # Execute the query
    dbSendQuery(con, query_upsert)
    
    #Drop the temp table
    query_drop_temp <- str_replace_all("DROP TABLE IF EXISTS :temp_table:;", ":temp_table:", query_temp_table)
    dbSendQuery(con, query_drop_temp)
    
}

#################### CHANGE WORKING DIRECTORY #######################

# Changes the working directory to the one of the current file
this.dir <- NULL
this.dir <- dirname(sys.frame(1)$ofile)
if(is.null(this.dir))
    this.dir <-dirname(rstudioapi::getActiveDocumentContext()$path)
if(is.null(this.dir)){
    print("Setting working directory failed. Script might fail to work.")
}else{
    setwd(this.dir)
    print(paste("Working directory changed successfully to: ", this.dir))
}


#################### DATA ACQUISITION #######################

# Gets the DB Connection
con <- getDBConnection()

#query to get the view of distances
query_last_names <- "
    select distinct
        aa.last_name
    from
        main.articles_authors aa
        left join main.last_name_ethnicities e on aa.last_name = e.last_name
    where e.last_name is null
    limit 500;
;"

last_names <- dbGetQuery(con, query_last_names)

#cleans the last_names 
last_names$last_name_clean <- sapply(last_names, cleanLastName)

#unique last names after cleaning
last_names_unique <- data.frame(last_name_clean = unique(last_names$last_name_clean))
colnames(last_names_unique)<- c('last_name_clean')
    
# separating last_names by spaces
last_names_unique$letters <- gsub("(.)", "\\1 \\2", last_names_unique$last_name_clean)

# adding phonetic column
last_names_unique$soundex  <- phonetic(last_names_unique$last_name_clean)

#Gets the full binary table with all ngrams
full_ngram <- data.frame(gtools::permutations(26,2,v=LETTERS,repeats.allowed=T))

full_ngram <- paste(full_ngram[,1], full_ngram[,2])

full_ngram_table <- data.frame(R = 1, bigram = full_ngram)
full_ngram_table <- acast(full_ngram_table, formula = R ~ bigram, fun.aggregate = length)
full_ngram_table <- full_ngram_table[0,]

# puts the bigrams in the table
for (i in 1:length(last_names_unique$letters)){
    currentRow <- nrow(full_ngram_table) + 1
    full_ngram_table <-  rbind(full_ngram_table, rep(0, ncol(full_ngram_table)))
    # Gets the current letters, if is only one it duplicates it to form a bigram
    currentLetters <- ifelse(nchar(last_names_unique$letters[i]) <= 2, 
                             paste(last_names_unique$letters[i], last_names_unique$letters[i], sep = ''), 
                             last_names_unique$letters[i])
    ngrams <- get.ngrams(ngram(currentLetters))
    for (j in 1:length(ngrams)){
        full_ngram_table[currentRow, ngrams[j]] <- full_ngram_table[currentRow, ngrams[j]] + 1
        # sur_white_new <- rbind(sur_white_new, c(sur_white[i,1], get.ngrams(tmp)[j]))
    }
}
ngtable_colnames <- colnames(full_ngram_table)
rownames(full_ngram_table) <- last_names_unique$last_name_clean

#Make it data.frame
full_ngram_table <- data.frame(full_ngram_table, stringsAsFactors = FALSE)
colnames(full_ngram_table) <- ngtable_colnames

#transform soundex to numeric and add it to the binary table
# full_ngram_table$soundex_num <- '0'
for (i in 1:length(last_names_unique$soundex)){
    # full_ngram_table$soundex_num[i] <- as.numeric(paste(as.vector(asc(as.character(full_ngram_table$soundex[i]), simplify=TRUE)), collapse = ""))
    full_ngram_table$soundex_num[rownames(full_ngram_table)==last_names_unique$last_name_clean[i]] <-
        as.numeric(paste(as.vector(asc(as.character(last_names_unique$soundex[i]), simplify=TRUE)), collapse = ""))
}

# load the models 
prace_model <- readRDS("../models/ethnic_2prace.rds")
aian_model <- readRDS("../models/ethnic_aian.rds")
api_model <- readRDS("../models/ethnic_api.rds")
black_model <- readRDS("../models/ethnic_black.rds")
hispanic_model <- readRDS("../models/ethnic_hispanic.rds")
white_model <- readRDS("../models/ethnic_white.rds")

#Predict the ethnicities
prace_pred <- predict(prace_model, full_ngram_table)
aian_pred <- predict(aian_model, full_ngram_table)
api_pred <- predict(api_model, full_ngram_table)
black_pred <- predict(black_model, full_ngram_table)
hispanic_pred <- predict(hispanic_model, full_ngram_table)
white_pred <- predict(white_model, full_ngram_table)

#create the dataframe with the predictions
preds <- data.frame(last_name_clean = names(black_pred),
                    aian = as.integer(levels(aian_pred))[aian_pred],
                    api = as.integer(levels(api_pred))[api_pred], 
                    black = as.integer(levels(black_pred))[black_pred],
                    hispanic = as.integer(levels(hispanic_pred))[hispanic_pred],
                    tworace = as.integer(levels(prace_pred))[prace_pred], 
                    white = as.integer(levels(white_pred))[white_pred], stringsAsFactors = FALSE)


final_last_names <- merge(x = last_names, y = preds, by = "last_name_clean", all.x = TRUE)
final_last_names <- final_last_names[,-1]

#Perform the upsert of the records into the DB
safeUpsert(con, data = final_last_names, destTable = c('main', 'last_name_ethnicities'), id_columns = 'last_name')

#Close the connection
dbDisconnect(con)



