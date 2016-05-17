# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("caret")
# install.packages("doParallel")
require("RPostgreSQL")
library(randomForest)
library(caret)
library(doParallel)

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
