
# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("caret")
# install.packages("e1071")
require("RPostgreSQL")
library(randomForest)
library(caret)
library(stringr)

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

##########################################


#query to get the view of distances
query_distances <- 
    "select 
        id1 || '_' || xid1 || '_' || id2 || '_' || xid2 || '_' || last_name as id_distances, 
        eq_finitial,
        eq_sinitial,
        eq_topic,
        diff_year,
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
df_y.test <- as.factor(df.test$same_author)


# random forest
rf <- randomForest(df_x.train, df_y.train, df_x.test, df_y.test)
rf$confusion
head(rf$predicted, n=10)
head(rf$test$predicted, n=20)

confusionMatrix(rf$test$predicted, df_y.test)

dbDisconnect(con)
dbUnloadDriver(drv)
