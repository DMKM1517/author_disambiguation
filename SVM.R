
# install.packages("RPostgreSQL")
# install.packages("kernlab")
# install.packages("caret")
# install.packages("e1071")
require("RPostgreSQL")
library(kernlab)
library(caret)
library(stringr)

#################### FUNCTIONS #######################

# function to calculate the confusion matrix and print the measures
measures <- function(predicted, actual){
  cm <- confusionMatrix(predicted, actual)
  precision <- cm$byClass['Pos Pred Value']    
  recall <- cm$byClass['Sensitivity']
  f_measure <- 2 * ((precision * recall) / (precision + recall))
  print('Confusion matrix')
  print(cm$table)
  print('Measures')
  res <- data.frame(cbind(cm$overall['Accuracy'], precision, recall, f_measure), row.names = '1')
  colnames(res) <- c('Accuray','Precision','Recall','F1')
  print(res)
}

######################################################



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
dist_keywords,
dist_refs,
dist_subject,
dist_title,
--dist_coauthor,
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

# transform x train as data matrix
xtr <- df_x.train
xtr$eq_finitial <- as.factor(xtr$eq_finitial)
xtr$eq_sinitial <- as.factor(xtr$eq_sinitial)
xtr$eq_topic <- as.factor(xtr$eq_topic)
xtr <- data.matrix(xtr)
# transform x test as data matrix
xte <- df_x.test
xte$eq_finitial <- as.factor(xte$eq_finitial)
xte$eq_sinitial <- as.factor(xte$eq_sinitial)
xte$eq_topic <- as.factor(xte$eq_topic)
xte <- data.matrix(xte)

# train the model with Hyperbolic tangent kernel
svmmod <- ksvm(xtr, df_y.train, type = "C-svc", C = 100, kernel='tanhdot')

# prediction
svmpre <- predict(svmmod, df_x.test)

# print the measures
measures(svmpre, df_y.test)


# disconnect from the database
dbDisconnect(con)
dbUnloadDriver(drv)
