# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("caret")
# install.packages("doParallel")
require("RPostgreSQL")
library(randomForest)
library(caret)
library(doParallel)
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

#########################################

#query to get the view of distances
query_distances <- 
  "select 
id1 || '_' || xid1 || '_' || id2 || '_' || xid2 || '_' || last_name as id_distances, 
eq_finitial,
eq_sinitial,
eq_topic,
dist_keywords,
dist_refs,
dist_subject,
dist_title,
dist_coauthor,
same_author
from v_authors_distance_disambiguated_:TABLE:;"
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
df_y.test2 <- as.numeric(df.test$same_author)

df_x <- df_x.test
df_y <- df_y.test2

# sets of number of variables to test
subsets <- c(2:8)

# function for rfe
rfe_functions <-  list(summary = defaultSummary,
               fit = function(x, y, first, last, ...){
                 library(randomForest)
                 randomForest(x, as.vector(y), importance = first, ...)
               },
               pred = function(object, x)  predict(object, x),
               rank = function(object, x, y) {
                 vimp <- varImp(object)
                 vimp <- vimp[order(vimp$Overall,decreasing = TRUE),,drop = FALSE]
                 vimp$var <- rownames(vimp)
                 vimp
               },
               selectSize = pickSizeBest,
               selectVar = pickVars)

# options for rfe
rfe_ctrl <- rfeControl(functions = rfe_functions,
                   method = "repeatedcv",
                   repeats = 4,
                   returnResamp = "all",
                   verbose = T)

# parallelize
cl<-makeCluster(detectCores() - 1)
registerDoParallel(cl)
set.seed(1234)
strt <- Sys.time()
# recursive feature elimination
rfe_profile <- rfe(df_x, df_y, sizes = subsets, rfeControl = rfe_ctrl)
cat("Selection Duration:", Sys.time()-strt)
stopCluster(cl)

# see results
rfe_profile

# plot the results
trellis.par.set(caretTheme())
plot1 <- plot(rfe_profile, type = c("g", "o"))
plot2 <- plot(rfe_profile, type = c("g", "o"), metric = "Rsquared")
print(plot1, split=c(1,1,1,2), more=TRUE)
print(plot2, split=c(1,2,1,2))

# disconnect from the database
dbDisconnect(con)
