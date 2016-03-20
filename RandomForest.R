
# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("caret")
# install.packages("e1071")
require("RPostgreSQL")
library(randomForest)
library(caret)

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



#query to get the view of distances
query_distances <- 
  "select id1 || '_' || xid1 || '_' || id2 || '_' || xid2 || '_' || last_name as id_distances, 
eq_finitial, eq_sinitial, dist_keywords, dist_refs, dist_subject, dist_title, same_author
from v_authors_distance_disambiguated;"

# Retreives the table from the database
df_distances <- dbGetQuery(con, query_distances)
head(df_distances, n = 10)
dim(df_distances)

# id as row name
df_bin <- data.frame(df_distances[,-1], row.names=df_distances[,1])
head(df_bin, n = 10)

# divide training and testing sets
bound <- floor((nrow(df_bin)/4)*3)                  #define % of training and test set
df_sampled <- df_bin[sample(nrow(df_bin)), ]        #sample rows 
df.train <- df_sampled[1:bound, ]                   #get training set
df.test <- df_sampled[(bound+1):nrow(df_sampled), ] #get test set

# separate x and y
df_x.train <- df.train[,1:6]
df_y.train <- as.factor(df.train$same_author)
df_x.test <- df.test[,1:6]
df_y.test <- as.factor(df.test$same_author)

# random forest
rf <- randomForest(df_x.train, df_y.train, df_x.test, df_y.test)
rf$confusion
head(rf$predicted, n=10)
head(rf$test$predicted, n=20)

confusionMatrix(rf$test$predicted, df_y.test)
