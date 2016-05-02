# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("xgboost")
# install.packages("caret")
# install.packages("e1071")
# install.packages("glmnet")
# install.packages("kernlab")
require("RPostgreSQL")
library(randomForest)
library(xgboost)
library(stringr)
library(caret)
library(glmnet)
library(kernlab)

#################### FUNCTIONS #######################

# function to calculate the confusion matrix and print the measures
measures <- function(predicted, actual){
  # if the prediction is not binary, it looks for the best threshold
  if(length(levels(as.factor(predicted))) > length(levels(actual))){
    threshold <- 0
    best_f <- 0
    for (i in seq(0.05, 0.995, by=0.005)) {
      pred <- as.numeric(predicted > i)
      cm <- confusionMatrix(pred, actual)
      precision <- cm$byClass['Pos Pred Value']    
      recall <- cm$byClass['Sensitivity']
      f_measure <- 2 * ((precision * recall) / (precision + recall))
      if(is.finite(f_measure) && f_measure > best_f){
        best_f <- f_measure
        threshold <- i
      }
    }
    cat("Threshold:", threshold, "\n")
    predicted <- as.numeric(predicted > threshold)
  }
  
  cm <- confusionMatrix(predicted, actual)
  precision <- cm$byClass['Pos Pred Value']    
  recall <- cm$byClass['Sensitivity']
  f_measure <- 2 * ((precision * recall) / (precision + recall))
  cat('\nConfusion matrix:\n')
  print(cm$table)
  cat('\nMeasures:\n')
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


#################### DATA ACQUISITION #######################

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
head(df.train, n = 5)
dim(df.train)

# Retreives the testing set from the database
df.test <- dbGetQuery(con, query_distances_testing)
rownames(df.test) <- df.test[,1]
df.test <- df.test[,-1]
head(df.test, n = 5)
dim(df.test)


# separate x and y
df_x.train <- df.train[,1:(length(df.train) - 1)]
df_y.train <- as.factor(df.train$same_author)
df_x.test <- df.test[,1:(length(df.train) - 1)]
df_y.test <- as.factor(df.test$same_author)


# transform x train as data matrix
xtrain <- df_x.train
xtrain$eq_finitial <- as.character(xtrain$eq_finitial)
xtrain$eq_sinitial <- as.character(xtrain$eq_sinitial)
xtrain$eq_topic <- as.character(xtrain$eq_topic)
xtrain <- data.matrix(xtrain)
xtrain2 <- df_x.train
xtrain2$eq_finitial <- as.factor(xtrain2$eq_finitial)
xtrain2$eq_sinitial <- as.factor(xtrain2$eq_sinitial)
xtrain2$eq_topic <- as.factor(xtrain2$eq_topic)
xtrain2 <- data.matrix(xtrain2)
# transform x test as data matrix
xtest <- df_x.test
xtest$eq_finitial <- as.factor(xtest$eq_finitial)
xtest$eq_sinitial <- as.factor(xtest$eq_sinitial)
xtest$eq_topic <- as.factor(xtest$eq_topic)
xtest <- data.matrix(xtest)
# transform y train as factor
ytrain <- as.vector(df_y.train)

######################################################


#################### MODELS #######################

# Random Forest
# model
rf_model <- randomForest(df_x.train, df_y.train, df_x.test, df_y.test)
# measures
measures(rf_model$test$predicted, df_y.test)

# Generalized Boosted Regression
# model
xgb_model <- xgboost(xtrain2, ytrain, eta=0.05, max.depth=2, nrounds = 150, objective='binary:logistic')
# predict
xgb_prediction <- predict(xgb_model, xtest)
# measures
measures(xgb_prediction, df_y.test)
# importance of features
importance <- xgb.importance(feature_names = colnames(xtrain), model = xgb_model)
# plot importance
xgb.plot.importance(importance_matrix = importance)

# Support Vector Machines
# model with Hyperbolic tangent kernel
# svm_model <- ksvm(xtrain2, df_y.train, type = "C-svc", C = 100, kernel='tanhdot')
# model with Bessel kernel
svm_model <- ksvm(xtrain, df_y.train, type = "C-svc", C = 100, kernel='besseldot')
# prediction
svm_prediction <- predict(svm_model, df_x.test)
# measures
measures(svm_prediction, df_y.test)

# Logistic Regression
# model with cross-validation
cvglm_model <- cv.glmnet(xtrain2, df_y.train, family = 'binomial')
# predict with the best lambda
cvglm_prediction <- predict.cv.glmnet(cvglm_model, xtest, type = 'class', s="lambda.min")
# measures
measures(cvglm_prediction, df_y.test)

######################################################


# disconnect from the database
dbDisconnect(con)
dbUnloadDriver(drv)
