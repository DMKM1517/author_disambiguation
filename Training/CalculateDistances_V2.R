#install.packages("RPostgreSQL")
#install.packages("reshape")
#install.packages("reshape2")
#install.packages("vegan")
#install.packages("stringr")
#install.packages("tm")
#install.packages("splitstackshape")
#install.packages("foreach")
#install.packages("doParallel")

library(stringr)
require("RPostgreSQL")
library(reshape2)
library(vegan)
library(tm)
library(splitstackshape)

library(foreach)
library(doParallel)


######################################################
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

# Function that calculates the JaccarDistance according to a received DataFrame
calculateJaccardDistance <- function(df, fun_id_vs_column, column, focusName)
{
    # Reshapes the table into a wide format
    df_bin <- acast(df, formula = fun_id_vs_column, fun.aggregate = length)
    
    # prepare the distance matrix
    distances <- vegdist(df_bin, method = "jaccard")
    
    # transform dist type into a matrix
    attributes(distances)$Diag <- FALSE
    distmat <- as(distances, "matrix")
    rm(distances)
    
    # melt the matrix
    resultDist <- melt(distmat)
    
    #Rename the columns
    colnames(resultDist) <- c("id1", "id2", "dist")
    resultDist$focus_name <- rep(focusName, nrow(resultDist))
    
    return(resultDist)
}

# Function that calculates the JaccarDistance according to a received DataFrame
writeDistanceTable <- function(con, dbTable, df)
{
    #Writes into the table
    dbWriteTable(
        con, dbTable, value = df, append = TRUE, row.names = FALSE
    )
}

truncateDistanceTables <- function(con)
{
    queryTruncate <- "
        TRUNCATE TABLE distances.keywords;
        TRUNCATE TABLE distances.refs;
        TRUNCATE TABLE distances.subject;
        TRUNCATE TABLE distances.title;
        TRUNCATE TABLE distances.coauthor;"
    dbSendQuery(con, queryTruncate)
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


calculateDistancesForFocusName <- function (con, testing, focusName) {

    
    ######### DISTANCE FOR TITLE ###############
    print(paste("Starting Distance for Title: ", focusName))
    
    #query to get the currentAuthor cluster
    query_tt <- 
        "select 
            distinct aa.id, 
            art.title
        from
            :DISAMBIGUATED:.articles_authors aa
            join public.articles art on aa.id = art.id --TODO: Change schema to source
        where focus_name = ':FOCUS_NAME:'
        order by aa.id;"
    
    # Replace the focus name and the environment if neccesary
    query_tt <- str_replace_all(query_tt, ":FOCUS_NAME:", focusName)
    if(testing){
        query_tt <- str_replace_all(query_tt, ":DISAMBIGUATED:", "training")
    } else {
        query_tt <- str_replace_all(query_tt, ":DISAMBIGUATED:", "main")
    }
    
    # Retreives the table from the database
    df_tt <-
        dbGetQuery(con, query_tt)
    head(df_tt, n = 10)
    dim(df_tt)
    
    # Clean the Fields
    df_tt$title <- lapply(df_tt$title, cleanField)
    head(df_tt, n = 20)
    
    # Expands the keywords into individual rows
    df_tt_separated <- data.frame(id=rep(df_tt$id, sapply(df_tt$title, FUN=length)), title=unlist(df_tt$title), stringsAsFactors = FALSE)
    head(df_tt_separated, n=20)
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ title
    dist_title <-
        calculateJaccardDistance(df_tt_separated, fun_id_vs_column, "title", focusName)
    
    #Correct the names of the dataframe
    names(dist_title) <-
        c("id1", "id2", "dist_title", "focusName")
    head(dist_title)
    
    #Writes into the table
    writeDistanceTable(con, c("distances", "title"), dist_title)
    
    #cleanup
    rm(df_tt)
    rm(df_tt_separated)
    rm(dist_title)
    
    ######### DISTANCE FOR KEYWORDS ###############
    print(paste("Starting Distance for Keywords: ", focusName))
    
    #query to get the currentAuthor cluster
    query_kw <- 
        "select 
            distinct a.id, 
            lower(k.keyword) as keyword 
        from
            :DISAMBIGUATED:.articles_authors a
            join public.articles_keywords k on a.id = k.id --TODO: Change schema to source
        where focus_name = ':FOCUS_NAME:'
        order by a.id;"
    
    # Replace the focus name and the environment if neccesary
    query_kw <- str_replace_all(query_kw, ":FOCUS_NAME:", focusName)
    if(testing){
        query_kw <- str_replace_all(query_kw, ":DISAMBIGUATED:", "training")
    } else {
        query_kw <- str_replace_all(query_kw, ":DISAMBIGUATED:", "main")
    }
    
    # Retreives the table from the database
    df_kw <-
        dbGetQuery(con, query_kw)
    head(df_kw, n = 20)
    dim(df_kw)
    
    # Clean the Fields
    df_kw$keyword <- lapply(df_kw$keyword, cleanField)
    head(df_kw, n=10)
    
    # Expands the keywords into individual rows
    df_kw_separated <- data.frame(id=rep(df_kw$id, sapply(df_kw$keyword, FUN=length)), keyword=unlist(df_kw$keyword), stringsAsFactors = FALSE)
    head(df_kw_separated, n=20)
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ keyword
    dist_keywords <-
        calculateJaccardDistance(df_kw_separated, fun_id_vs_column, "keyword", focusName)
    
    #Correct the names of the dataframe
    names(dist_keywords) <-
        c("id1", "id2", "dist_keywords", "focus_name")
    head(dist_keywords)
    
    #Writes into the table
    writeDistanceTable(con, c("distances", "keywords"), dist_keywords)
    
    #cleanup
    rm(df_kw)
    rm(df_kw_separated)
    rm(dist_keywords)
    
    ######### DISTANCE FOR REFS ###############
    print(paste("Starting Distance for References: ", focusName))
    
    #query to get the currentAuthor cluster
    query_ref <- 
        "select 
            distinct aa.id, 
            refs.journal
        from
            :DISAMBIGUATED:.articles_authors aa
            join public.articles_refs_clean refs on aa.id = refs.id --TODO: Change schema to source
        where 
            focus_name = ':FOCUS_NAME:'
        order by aa.id;"
    
    # Replace the focus name and the environment if neccesary
    query_ref <- str_replace_all(query_ref, ":FOCUS_NAME:", focusName)
    if(testing){
        query_ref <- str_replace_all(query_ref, ":DISAMBIGUATED:", "training")
    } else {
        query_ref <- str_replace_all(query_ref, ":DISAMBIGUATED:", "main")
    }
    
    # Retreives the table from the database
    df_ref <-
        dbGetQuery(con, query_ref)
    head(df_ref, n = 10)
    dim(df_ref)

    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ journal
    dist_ref <-
        calculateJaccardDistance(df_ref, fun_id_vs_column, "journal", focusName)
    
    #Correct the names of the dataframe
    names(dist_ref) <-
        c("id1", "id2", "dist_refs", "focus_name")
    head(dist_ref)
    
    #Writes into the table
    writeDistanceTable(con, c("distances", "refs"), dist_ref)
    
    #cleanup
    rm(df_ref)
    rm(dist_ref) 
    
    
    ######### DISTANCE FOR SUBJECT ###############
    print(paste("Starting Distance for Subject: ", focusName))
    
    #query to get the currentAuthor cluster
    query_sub <- 
        "select distinct *
        from
            (
                (select 
                    distinct aa.id, 
                    sub.subject
                from
                    :DISAMBIGUATED:.articles_authors aa
                    join public.articles_subjects sub on aa.id = sub.id --TODO: Change schema to source
                where 
                    aa.focus_name = ':FOCUS_NAME:'
                order by aa.id)    
            UNION
                (select 
                    distinct aa.id, 
                    sub.subject
                from
                    :DISAMBIGUATED:.articles_authors aa
                    join public.subject_asociations sub on aa.id = sub.id --TODO: Change schema to source
                where 
                    aa.focus_name = ':FOCUS_NAME:'
                order by aa.id)    
            ) subs
        order by id;"
    
    # Replace the focus name and the environment if neccesary
    query_sub <- str_replace_all(query_sub, ":FOCUS_NAME:", focusName)
    if(testing){
        query_sub <- str_replace_all(query_sub, ":DISAMBIGUATED:", "training")
    } else {
        query_sub <- str_replace_all(query_sub, ":DISAMBIGUATED:", "main")
    }
    
    # Retreives the table from the database
    df_sub <-
        dbGetQuery(con, query_sub)
    head(df_sub, n = 10)
    dim(df_sub)
    
    
    # Clean the Fields
    df_sub$subject <- lapply(df_sub$subject, cleanField)
    head(df_sub, n = 20)
    
    # Expands the keywords into individual rows
    df_sub_separated <- data.frame(id=rep(df_sub$id, sapply(df_sub$subject, FUN=length)), subject=unlist(df_sub$subject), stringsAsFactors = FALSE)
    head(df_sub_separated, n=20)
    
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ subject
    dist_sub <-
        calculateJaccardDistance(df_sub_separated, fun_id_vs_column, "subject", focusName)
    
    #Correct the names of the dataframe
    names(dist_sub) <-
        c("id1", "id2", "dist_subject", "focus_name")
    head(dist_sub)
    
    #Writes into the table
    writeDistanceTable(con, c("distances", "subject"), dist_sub)
    
    #cleanup
    rm(df_sub)
    rm(df_sub_separated)
    rm(dist_sub) 
    
    
    ######### DISTANCE FOR COAUTORS ###############
    print(paste("Starting Distance for Coautors: ", focusName))
    #query to get the authors of each article for the current focus name
    query_ca <- 
        "select distinct
            aa1.id,
            aa2.focus_name as author
        from
            :DISAMBIGUATED:.articles_authors aa1
            join main.articles_authors aa2 on aa1.id = aa2.id 
        where aa1.focus_name = ':FOCUS_NAME:' 
        order by aa1.id;"
    
    # Replace the focus name and the environment if neccesary
    query_ca <- str_replace_all(query_ca, ":FOCUS_NAME:", focusName)
    if(testing){
        query_ca <- str_replace_all(query_ca, ":DISAMBIGUATED:", "training")
    } else {
        query_ca <- str_replace_all(query_ca, ":DISAMBIGUATED:", "main")
    }

        # Retreives the table from the database
    df_ca <-
        dbGetQuery(con, query_ca)
    head(df_ca, n = 10)
    dim(df_ca)
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ author
    dist_ca <-
        calculateJaccardDistance(df_ca, fun_id_vs_column, "author", focusName)
    
    #Correct the names of the dataframe
    names(dist_ca) <-
        c("id1", "id2", "dist_coauthor", "focus_name")
    head(dist_ca)
    
    #Writes into the table
    writeDistanceTable(con, c("distances", "coauthor"), dist_ca)
    
    #cleanup
    rm(df_ca)
    rm(dist_ca) 
    
}


############### END OF FUNCTIONS #####################
######################################################

############################################################################################################
############# START OF SCRIPT ##################

#assigns the current focus name to cluster
focusName <- "BL"

######### CONNECTION TO DB ###############

con <- getDBConnection()

# Query to retrieve all focus names
queryFN <- 
    "select 
        focus_name,
        count(focus_name)
    from training.articles_authors
    group by focus_name
    order by count(focus_name) desc
    --limit 8"

focusNames <- dbGetQuery(con, queryFN)

head(focusNames, n = 20)

#Truncate all the distance tables
truncateDistanceTables(con)

#setup parallel backend to use 8 processors
cl<-makeCluster(8)
registerDoParallel(cl)


#Parallel Loop
strt<-Sys.time()
ls<-foreach(
    focusName = focusNames[,1],
    .packages = c("stringr","RPostgreSQL","reshape2","vegan","tm","splitstackshape","foreach","doParallel")) %dopar% {
    
    conIter <- getDBConnection()

    calculateDistancesForFocusName(con = conIter, testing = TRUE, focusName = focusName)
    dbDisconnect(conIter)
    # dbUnloadDriver(drvIter)
}
dbDisconnect(con)
# dbUnloadDriver(drv)
print("Parallel Loop Duration:")
print(Sys.time()-strt)
stopCluster(cl)


# strt<-Sys.time()
# print("Loop Duration:")
# for(focusName in focusNames[,1]) {
#     # Call the main function that calculates all the distances
#     calculateDistancesForFocusName(con = con, testing = TRUE, focusName = focusName)
# }
# print(Sys.time()-strt)


