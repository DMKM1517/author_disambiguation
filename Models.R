# install.packages('devtools')
# install.packages("RPostgreSQL")
# install.packages("randomForest")
# install.packages("xgboost")
# install.packages("caret")
# install.packages("e1071")
# install.packages("glmnet")
# install.packages("kernlab")
# install.packages("Ckmeans.1d.dp")
# install.packages("combinat")

require("RPostgreSQL")
library(randomForest)
library(xgboost)
library(stringr)
library(caret)
library(glmnet)
library(kernlab)
library(reshape2)
library(fpc)
library(combinat)

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

# Function that calculates the clusters based on the distance table of the signatures
calculateClusters <- function(con, distTable) {
    
    tree_cut <- 0.5
    # 
    # query_max_cluster <-"
    # select case when max(cluster) is null then 0 else max(cluster) end as max_cluster
    # from xref_authors_clusters;
    # "
    # df.max <- dbGetQuery(con, query_max_cluster)
    # #Current max number of cluster
    # df.max[1,1]
    df.max <- as.matrix(0)
    
    
    
    #Create the distance matrix
    # head(rf$test$votes, n=20)
    # distTable <- cbind(str_split_fixed(row.names(rf$test$votes), "_", n=3), (rf$test$votes[,1] ))
    # colnames(distTable) <- c("id1_d1", "id2_d2", "last_name", "dist")
    
    # distTable<- rf_distTable
    # distTable <- as.data.frame(distTable, stringsAsFactors = FALSE)
    # distTable$dist <- as.numeric(distTable$dist)
    # head(distTable)
    
    # Reshapes the table into a wide format
    distMatrix <- acast(distTable, formula = id1_d1 ~ id2_d2, fun.aggregate = mean, fill = 1)
    
    clusters <- hclust(as.dist(distMatrix))
    plot(clusters, cex=0.5)
    # head(clusters)
    cut <- as.data.frame(cutree(clusters, h = tree_cut))
    # head(cut)
    
    dbClusters <- cbind(str_split_fixed(row.names(cut), "-", n=2), (cut[,1] + df.max[1,1]))
    dbClusters <- as.data.frame(dbClusters, stringsAsFactors=FALSE)
    colnames(dbClusters) <- c("id1", "d1", "cluster")
    
    # head(dbClusters, n=30)
    
    #Writes into the table
    dbSendQuery(con, "TRUNCATE TABLE xref_authors_clusters;")
    dbWriteTable(
        con, "xref_authors_clusters", value = dbClusters, append = TRUE, row.names = FALSE
    )
    
    # bring the real cluster
    query_cluster_test <- 
        "select 
            c.id,
            c.d,
            ad.authorid as real_cluster,
            c.cluster as computed_cluster
        from
            xref_authors_clusters c
            join xref_articles_authors_disambiguated ad on c.id = ad.id and c.d = ad.d
    ;"
    clusterTest <- dbGetQuery(con, query_cluster_test)
    
    
    # Validating results
    results <- cbind(method = "Pairwise", pairwiseMetrics(clusterTest$computed_cluster, clusterTest$real_cluster))
    results <- rbind(results, cbind(method = "B3", b3Metrics(clusterTest$computed_cluster, clusterTest$real_cluster)))
    results
}


# Function that retreives all multiple pairs of elements in the same cluster
getPairsOfClusters <- function(r){
    names(r) <- c(1:length(r))
    pairs <- matrix(NA, 2, 0)
    for(i in unique(r)){
        c <- names(r[r==i])
        if(length(c) > 1) 
            pairs <- cbind(pairs, combn(c, 2))
    }
    paste(pairs[1,], "-", pairs[2,])
}

# Function that calculates the Pairwise metrics for validating a clustering
pairwiseMetrics <- function(r, s){
    pairsR <- getPairsOfClusters(r)
    pairsS <- getPairsOfClusters(s)
    precision <- length(intersect(pairsR, pairsS)) / length(pairsR)
    recall <- length(intersect(pairsR, pairsS)) / length(pairsS)
    f1 <- (2 * precision * recall) / (precision + recall)
    cbind(precision, recall, f1)
}

#Function that calculates the B3 precission of a clustering
b3Precision <- function(r, s){
    names(r) <- c(1:length(r))
    names(s) <- c(1:length(s))
    sum <- 0
    for(i in 1:length(r)){
        cR <- names(r[r==r[i]])
        cS <- names(s[s==s[i]])
        sum <- sum + (length(intersect(cR,cS)) / length(cR))
    }
    sum / length(r)
}

#Function that calculates the B3 recall of a clustering
b3Recall <- function(r, s){
    names(r) <- c(1:length(r))
    names(s) <- c(1:length(s))
    sum <- 0
    for(i in 1:length(r)){
        cR <- names(r[r==r[i]])
        cS <- names(s[s==s[i]])
        sum <- sum + (length(intersect(cR,cS))/ length(cS))
    }
    sum / length(r)
}

# Function that calculates the B3 metrics for validating a clustering
b3Metrics <- function(r, s){
    precision <- b3Precision(r, s)
    recall <- b3Recall(r, s)
    f1 <- (2 * precision * recall) / (precision + recall)
    cbind(precision, recall, f1)
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
id1 || '-' || d1 || '_' || id2 || '-' || d2 || '_' || last_name as id_distances, 
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
# svm_model <- ksvm(xtrain, df_y.train, type = "C-svc", C = 100, kernel='besseldot', prob.model=T)
# model with Bessel kernel (probabilistic)
svm_model <- ksvm(xtrain, df_y.train, type = "C-svc", C = 100, kernel='besseldot', prob.model=T)
# prediction
svm_prediction <- predict(svm_model, df_x.test, type = "p")
# measures
measures(svm_prediction[,2], df_y.test)

# Logistic Regression
# model with cross-validation
cvglm_model <- cv.glmnet(xtrain2, df_y.train, family = 'binomial', keep=TRUE)
# predict with the best lambda
cvglm_prediction <- predict.cv.glmnet(cvglm_model, xtest, type = 'response', s="lambda.min")
# measures
measures(cvglm_prediction, df_y.test)


######################################################

######################## CLUSTERING  ########################

# Random Forest Clustering
rf_distTable <- cbind(str_split_fixed(row.names(rf_model$test$votes), "_", n=3), (rf_model$test$votes[,1] ))
colnames(rf_distTable) <- c("id1_d1", "id2_d2", "last_name", "dist")
rf_distTable <- as.data.frame(rf_distTable, stringsAsFactors = FALSE)
rf_distTable$dist <- as.numeric(rf_distTable$dist)
calculateClusters(con, rf_distTable)

# Generalized Boosted Regression Clustering
gbr_distTable <- cbind(rf_distTable[, 1:3], dist = matrix(xgb_prediction,  byrow = T))
# head(gbr_distTable)
calculateClusters(con, gbr_distTable)

# Support Vector Machines Clustering
svm_distTable <- cbind(rf_distTable[, 1:3], dist = matrix(svm_prediction[,1],  byrow = T))
# head(svm_distTable)
calculateClusters(con, gbr_distTable)

# Logistic Regression Clustering
cvglm_distTable <- cbind(rf_distTable[, 1:3], dist = matrix(cvglm_prediction,  byrow = T))
# head(svm_distTable)
calculateClusters(con, cvglm_distTable)

######################################################

# disconnect from the database
dbDisconnect(con)
dbUnloadDriver(drv)
