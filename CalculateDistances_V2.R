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

# Function that calculates the JaccarDistance according to a received DataFrame
calculateJaccardDistance <- function(df, fun_id_vs_column, column, currentLastName)
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
    resultDist$last_name <- rep(currentLastName, nrow(resultDist))
    
    return(resultDist)
}
# # Function that calculates the JaccarDistance according to a received DataFrame
# calculateJaccardDistance <- function(df, column, currentLastName)
# {
#     # str(df)
#     df[,eval(column)]<- as.factor(df[,eval(column)])
#     
#     # creates new dummy variables, with names "value.[column]"
#     df <- data.frame(df, value = TRUE)
#     
#     #   head(df)
#     df_bin <-
#         reshape(df, idvar = c("id"), timevar = column, direction = "wide")
#     
#     # NA to 0, TRUE to 1
#     df_bin[is.na(df_bin)] <- 0
#     df_bin[df_bin == TRUE] = 1
#     #write.csv(df_bin, file = "df_bin.csv")
#     
#     # Moves the first column to the row names
#     rownames(df_bin) <- df_bin[,1]
#     df_bin <- df_bin[,-1]
#     
#     # prepare the distance matrix
#     dist.mat <- vegdist(df_bin, method = "jaccard")
#     # str(dist.mat)
#     class(dist.mat)
#     
#     # transform dist type into a matrix
#     attributes(dist.mat)$Diag <- FALSE
#     distmat <- as(dist.mat, "matrix")
#     
#     # melt the matrix
#     resultDist <- melt(distmat)
#     colnames(resultDist) <- c("id1", "id2", "dist")
#     resultDist$last_name <- rep(currentLastName, nrow(resultDist))
#     resultDist
#     
# }


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
        TRUNCATE TABLE d_keywords;
        TRUNCATE TABLE d_refs;
        TRUNCATE TABLE d_subject;
        TRUNCATE TABLE d_title;
        TRUNCATE TABLE d_coauthor;"
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


calculateDistancesForFocusName <- function (con, testing, currentLastName) {

    
    ######### DISTANCE FOR TITLE ###############
    print(paste("Starting Distance for Title: ", currentLastName))
    
    #query to get the currentAuthor cluster
    query_tt <- 
        "select 
    distinct aa.id, 
    art.title
    from
    xref_articles_authors:DISAMBIGUATED: aa
    join articles art on aa.id = art.id
    where lastname_phon_12 = ':LAST_NAME:'
    order by aa.id;"
    
    # Replace the last name and the environment if neccesary
    query_tt <- str_replace_all(query_tt, ":LAST_NAME:", currentLastName)
    if(testing){
        query_tt <- str_replace_all(query_tt, ":DISAMBIGUATED:", "_disambiguated")
    } else {
        query_tt <- str_replace_all(query_tt, ":DISAMBIGUATED:", "")
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
        calculateJaccardDistance(df_tt_separated, fun_id_vs_column, "title", currentLastName)
    
    #Correct the names of the dataframe
    names(dist_title) <-
        c("id1", "id2", "dist_title", "last_name")
    head(dist_title)
    
    #Writes into the table
    writeDistanceTable(con, "d_title", dist_title)
    
    #cleanup
    rm(df_tt)
    rm(df_tt_separated)
    rm(dist_title)
    
    ######### DISTANCE FOR KEYWORDS ###############
    print(paste("Starting Distance for Keywords: ", currentLastName))
    
    #query to get the currentAuthor cluster
    query_kw <- 
        "select 
    distinct a.id, 
    lower(k.keyword) as keyword 
    from
    xref_articles_authors:DISAMBIGUATED: a
    join articles_keywords k on a.id = k.id
    where lastname_phon_12 = ':LAST_NAME:'
    order by a.id;"
    
    # Replace the last name and the environment if neccesary
    query_kw <- str_replace_all(query_kw, ":LAST_NAME:", currentLastName)
    if(testing){
        query_kw <- str_replace_all(query_kw, ":DISAMBIGUATED:", "_disambiguated")
    } else {
        query_kw <- str_replace_all(query_kw, ":DISAMBIGUATED:", "")
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
        calculateJaccardDistance(df_kw_separated, fun_id_vs_column, "keyword", currentLastName)
    
    #Correct the names of the dataframe
    names(dist_keywords) <-
        c("id1", "id2", "dist_keywords", "last_name")
    head(dist_keywords)
    
    #Writes into the table
    writeDistanceTable(con, "d_keywords", dist_keywords)
    
    #cleanup
    rm(df_kw)
    rm(df_kw_separated)
    rm(dist_keywords)
    
    ######### DISTANCE FOR REFS ###############
    print(paste("Starting Distance for References: ", currentLastName))
    
    #query to get the currentAuthor cluster
    query_ref <- 
        "select 
    distinct aa.id, 
    refs.journal
    from
    xref_articles_authors:DISAMBIGUATED: aa
    join articles_refs_clean refs on aa.id = refs.id
    where 
    lastname_phon_12 = ':LAST_NAME:'
    order by aa.id;"
    
    # Replace the last name and the environment if neccesary
    query_ref <- str_replace_all(query_ref, ":LAST_NAME:", currentLastName)
    if(testing){
        query_ref <- str_replace_all(query_ref, ":DISAMBIGUATED:", "_disambiguated")
    } else {
        query_ref <- str_replace_all(query_ref, ":DISAMBIGUATED:", "")
    }
    
    # Retreives the table from the database
    df_ref <-
        dbGetQuery(con, query_ref)
    head(df_ref, n = 10)
    dim(df_ref)

    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ journal
    dist_ref <-
        calculateJaccardDistance(df_ref, fun_id_vs_column, "journal", currentLastName)
    
    #Correct the names of the dataframe
    names(dist_ref) <-
        c("id1", "id2", "dist_refs", "last_name")
    head(dist_ref)
    
    #Writes into the table
    writeDistanceTable(con, "d_refs", dist_ref)
    
    #cleanup
    rm(df_ref)
    rm(dist_ref) 
    
    
    ######### DISTANCE FOR SUBJECT ###############
    print(paste("Starting Distance for Subject: ", currentLastName))
    
    #query to get the currentAuthor cluster
    query_sub <- 
        "select distinct *
    from
    ((select 
    distinct aa.id, 
    sub.subject
    from
    xref_articles_authors:DISAMBIGUATED: aa
    join articles_subjects sub on aa.id = sub.id
    where 
    aa.lastname_phon_12 = ':LAST_NAME:'
    order by aa.id)    
    UNION
    (select 
    distinct aa.id, 
    sub.subject
    from
    xref_articles_authors:DISAMBIGUATED: aa
    join subject_asociations sub on aa.id = sub.id
    where 
    aa.lastname_phon_12 = ':LAST_NAME:'
    order by aa.id)    ) subs
    order by id;"
    
    # Replace the last name and the environment if neccesary
    query_sub <- str_replace_all(query_sub, ":LAST_NAME:", currentLastName)
    if(testing){
        query_sub <- str_replace_all(query_sub, ":DISAMBIGUATED:", "_disambiguated")
    } else {
        query_sub <- str_replace_all(query_sub, ":DISAMBIGUATED:", "")
    }
    
    # Retreives the table from the database
    df_sub <-
        dbGetQuery(con, query_sub)
    head(df_sub, n = 10)
    dim(df_sub)
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ subject
    dist_sub <-
        calculateJaccardDistance(df_sub, fun_id_vs_column, "subject", currentLastName)
    
    #Correct the names of the dataframe
    names(dist_sub) <-
        c("id1", "id2", "dist_subject", "last_name")
    head(dist_sub)
    
    #Writes into the table
    writeDistanceTable(con, "d_subject", dist_sub)
    
    #cleanup
    rm(df_sub)
    rm(dist_sub) 
    
    
    ######### DISTANCE FOR COAUTORS ###############
    print(paste("Starting Distance for Coautors: ", currentLastName))
    #query to get the authors of each article for the current last name
    query_ca <- 
        "select distinct
            aa1.id,
            aa2.lastname_phon_12 as author
        from
            xref_articles_authors:DISAMBIGUATED: aa1
            join xref_articles_authors aa2 on aa1.id = aa2.id 
        where aa1.lastname_phon_12 = ':LAST_NAME:' 
        order by aa1.id;"
    
    # Replace the last name and the environment if neccesary
    query_ca <- str_replace_all(query_ca, ":LAST_NAME:", currentLastName)
    if(testing){
        query_ca <- str_replace_all(query_ca, ":DISAMBIGUATED:", "_disambiguated")
    } else {
        query_ca <- str_replace_all(query_ca, ":DISAMBIGUATED:", "")
    }

        # Retreives the table from the database
    df_ca <-
        dbGetQuery(con, query_ca)
    head(df_ca, n = 10)
    dim(df_ca)
    
    # Calculate the distances of the keywords
    fun_id_vs_column = id ~ author
    dist_ca <-
        calculateJaccardDistance(df_ca, fun_id_vs_column, "author", currentLastName)
    
    #Correct the names of the dataframe
    names(dist_ca) <-
        c("id1", "id2", "dist_coauthor", "last_name")
    head(dist_ca)
    
    #Writes into the table
    writeDistanceTable(con, "d_coauthor", dist_ca)
    
    #cleanup
    rm(df_ca)
    rm(dist_ca) 
    
}


############### END OF FUNCTIONS #####################
######################################################


############# START OF SCRIPT ##################

#assigns the current last name to cluster
currentLastName <- "BLS"

######### CONNECTION TO DB ###############

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

# Query to retrieve all last names
queryLN <- 
    "select 
        lastname_phon_12,
        count(lastname_phon_12)
    from xref_articles_authors_disambiguated
    group by lastname_phon_12
    order by count(lastname_phon_12) desc
    --limit 8"

lastNames <- dbGetQuery(con, queryLN)

head(lastNames, n = 20)

#Truncate all the distance tables
truncateDistanceTables(con)

#setup parallel backend to use 8 processors
cl<-makeCluster(8)
registerDoParallel(cl)


#loop
strt<-Sys.time()
ls<-foreach(
    lastname = lastNames[,1],
    .packages = c("stringr","RPostgreSQL","reshape2","vegan","tm","splitstackshape","foreach","doParallel")) %dopar% {
    
    # loads the PostgreSQL driver
    drvIter <- dbDriver("PostgreSQL")
    pw <- {
        "test"
    }
    # creates a connection to the postgres database
    # note that "con" will be used later in each connection to the database
    conIter <- dbConnect(
        drvIter, dbname = "ArticlesDB",
        host = "25.39.131.139", port = 5433,
        user = "test", password = pw
    )
    calculateDistancesForFocusName(con = conIter, testing = TRUE, currentLastName = lastname)
    dbDisconnect(conIter)
    dbUnloadDriver(drvIter)
}
dbDisconnect(con)
dbUnloadDriver(drv)
print("Parallel Loop Duration:")
print(Sys.time()-strt)
stopCluster(cl)


strt<-Sys.time()
print("Loop Duration:")
for(lastname in lastNames[,1]) {
    # Call the main function that calculates all the distances
    calculateDistancesForFocusName(con = con, testing = TRUE, currentLastName = lastname)
}
print(Sys.time()-strt)


