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
  res <- data.frame(threshold, cbind(cm$overall['Accuracy'], precision, recall, f_measure), row.names = '1')
  colnames(res) <- c('BestTreshold', 'Accuracy','Precision','Recall','F1')
  print(res)
  res
}

# Function that calculates the clusters based on the distance table of the signatures with the best cut for each focus name
calculateClustersByFocusName <- function(con, distTable) {
    #distTable <- xgb_distTable
    temp.results <- data.frame(last_name = character(0), BestCut = numeric(0), Method = character(0), Precision = numeric(0),
                                    Recall = numeric(0), F1 = numeric(0), stringsAsFactors = FALSE)
    uniqueLastNames <- unique(distTable$last_name)
    for(i in 1:length(uniqueLastNames)){
        # i<-10
        current_last_name <- uniqueLastNames[i]
        if(nrow(distTable[distTable$last_name == current_last_name, ]) > 1){ #prevents from calculating from lonely signatures
            current.results <- calculateClusters(con, distTable[distTable$last_name == current_last_name, ])
            temp.results <- rbind(temp.results,cbind(last_name = current_last_name, current.results))
        }
        
    }
    #unfactorize the data.frame
    temp.results <- as.data.frame(lapply(temp.results, as.character), stringsAsFactors = FALSE)
    
    rbind(
        c(
            Method='Pairwise', 
            Precision =  mean(as.numeric(temp.results$Precision[temp.results$Method == 'Pairwise'])),
            Recall =  mean(as.numeric(temp.results$Recall[temp.results$Method == 'Pairwise'])),
            F1 =  mean(as.numeric(temp.results$F1[temp.results$Method == 'Pairwise']))
        ), c(
            Method='B3', 
            Precision =  mean(as.numeric(temp.results$Precision[temp.results$Method == 'B3'])),
            Recall =  mean(as.numeric(temp.results$Recall[temp.results$Method == 'B3'])),
            F1 =  mean(as.numeric(temp.results$F1[temp.results$Method == 'B3']))
        )
    )
       
}


# Function that calculates the clusters based on the distance table of the signatures
calculateClusters <- function(con, distTable) {


    # query_max_cluster <-"
    # select case when max(cluster) is null then 0 else max(cluster) end as max_cluster
    # from xref_authors_clusters;
    # "
    # df.max <- dbGetQuery(con, query_max_cluster)
    # #Current max number of cluster
    # df.max[1,1]
    df.max <- as.matrix(0)

    # distTable<- rf_distTable

    # Reshapes the table into a wide format
    distMatrix <- acast(distTable, formula = id1_d1 ~ id2_d2, fun.aggregate = mean, fill = 1)

    # Create the Hierarchical Clustering
    clusters <- hclust(as.dist(distMatrix), method = "complete")

    #Values for the loop
    bestModelCut <- NULL
    bestCut <- 0
    bestF1 <- 0
    maxHeight <- max(clusters$height)

    #Drops the temp table if exists
    dbSendQuery(con, "drop table if exists main.temp_author_clusters;")

    #Loop that looks for the best cut of the tree
    for (i in seq(0, ceiling(maxHeight), by=0.05)) {
        if(i>maxHeight)
            break

        cut <- as.data.frame(cutree(clusters, h = i))

        # dbClusters <- cbind(str_split_fixed(row.names(cut), "-", n=2), (cut[,1] + df.max[1,1]))
        dbClusters <- cbind(str_split_fixed(row.names(cut), "-", n=2), cut[,1] )
        dbClusters <- as.data.frame(dbClusters, stringsAsFactors=FALSE)
        colnames(dbClusters) <- c("id", "d", "cluster")
        dbClusters$id <- as.numeric(dbClusters$id)
        dbClusters$d <- as.numeric(dbClusters$d)
        dbClusters$cluster <- as.numeric(dbClusters$cluster)

        # str(dbClusters)
        # head(dbClusters, n=30)

        #Writes into the table
        dbWriteTable(
            con, c("main","temp_author_clusters"), value = dbClusters, append = TRUE, row.names = FALSE
        )

        # bring the real cluster
        query_cluster_test <-
            "select
                c.id,
                c.d,
                ad.author_id as real_cluster,
                c.cluster as computed_cluster
            from
                    main.temp_author_clusters c
                join main.authors_disambiguated ad on c.id = ad.id and c.d = ad.d
        ;"
        clusterTest <- dbGetQuery(con, query_cluster_test)

        currentF1 <- pairwiseMetrics(clusterTest$computed_cluster, clusterTest$real_cluster)[1, 3]

        if(!is.na(currentF1) && currentF1 > bestF1){
            bestF1 <- currentF1
            bestCut <- i
            bestCluster <- clusterTest
            # print(paste(i , " - " , currentF1))
        }

        dbSendQuery(con, "truncate table main.temp_author_clusters;")

    }

    head(bestCluster, n=20)

    #Drops the temp table
    dbSendQuery(con, "drop table if exists main.temp_author_clusters;")


    #Plot the best cluster cut
    plot(clusters, cex=0.5)
    abline(h = bestCut, lty = 2)

    # Final Results
    pairwiseResults <- cbind(BestCut = bestCut, Method = "Pairwise", pairwiseMetrics(bestCluster$computed_cluster, bestCluster$real_cluster))
    b3Results <- cbind(BestCut = bestCut, Method = "B3", b3Metrics(bestCluster$computed_cluster, bestCluster$real_cluster))
    rbind(pairwiseResults, b3Results)

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
    Precision <- length(intersect(pairsR, pairsS)) / length(pairsR)
    Recall <- length(intersect(pairsR, pairsS)) / length(pairsS)
    F1 <- (2 * Precision * Recall) / (Precision + Recall)
    cbind(Precision, Recall, F1)
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
    Precision <- b3Precision(r, s)
    Recall <- b3Recall(r, s)
    F1 <- (2 * Precision * Recall) / (Precision + Recall)
    cbind(Precision, Recall, F1)
}



######################################################



######### CONNECTION TO DB ###############

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

##########################################

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
query_distances <- "
    select 
        id1 || '-' || d1 || '_' || id2 || '-' || d2 || '_' || focus_name as id_distances, 
        eq_fn_initial,
        eq_mn_initial,
        eq_lda_topic,
        diff_year,
        dist_keywords,
        dist_refs,
        dist_subject,
        dist_title,
        dist_coauthor,
        dist_ethnicity,
        same_author
    from training.v_authors_distance_:TABLE:
    --where focus_name in (
    --    select focus_name
    --    from training.v_:TABLE:_focus_names
    --    limit 2
    --);

"

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
df_x.test <- df.test[,1:(length(df.test) - 1)]
df_y.test <- as.factor(df.test$same_author)


# transform x train as data matrix
xtrain <- df_x.train
xtrain$eq_finitial <- as.character(xtrain$eq_fn_initial)
xtrain$eq_sinitial <- as.character(xtrain$eq_mn_initial)
xtrain$eq_topic <- as.character(xtrain$eq_lda_topic)
xtrain <- data.matrix(xtrain)
xtrain2 <- df_x.train
xtrain2$eq_finitial <- as.factor(xtrain2$eq_fn_initial)
xtrain2$eq_sinitial <- as.factor(xtrain2$eq_mn_initial)
xtrain2$eq_topic <- as.factor(xtrain2$eq_lda_topic)
xtrain2 <- data.matrix(xtrain2)
# transform x test as data matrix
xtest <- df_x.test
xtest$eq_finitial <- as.factor(xtest$eq_fn_initial)
xtest$eq_sinitial <- as.factor(xtest$eq_mn_initial)
xtest$eq_topic <- as.factor(xtest$eq_lda_topic)
xtest <- data.matrix(xtest)
# transform y train as factor
ytrain <- as.vector(df_y.train)

# save xtest
saveRDS(xtest, "../models/xtest.rds")

######################################################

#################### MODELS #######################
# save.models <- FALSE
save.models <- TRUE

#Table for the results of the first validation
first.validation <- data.frame(Model = character(0), BestTreshold = numeric(0), Accuracy = numeric(0), Precision = numeric(0),
                               Recall = numeric(0), F1 = numeric(0), stringsAsFactors = FALSE)


#### Random Forest ####
# model
model_rf <- randomForest(df_x.train, df_y.train, df_x.test, df_y.test)

#Save the model if specified
if(save.models)
    saveRDS(model_rf, "../models/model_rf.rds")

# measures
measures_rf <- measures(model_rf$test$votes[,2], df_y.test)
first.validation <- rbind(first.validation, cbind(Model= 'RF', measures_rf))

#### Generalized Boosted Regression ####
# model
model_xgb <- xgboost(xtrain2, ytrain, eta=0.05, max.depth=2, nrounds = 150, objective='binary:logistic')

#Save the model if specified
if(save.models)
    saveRDS(model_xgb, "../models/model_xgb.rds")

# predict
prediction_xgb <- predict(model_xgb, xtest)

# measures
measures_xgb <- measures(prediction_xgb, df_y.test)
first.validation <- rbind(first.validation, cbind(Model= 'XGB', measures_xgb))

# importance of features
importance <- xgb.importance(feature_names = colnames(xtrain), model = model_xgb)
# plot importance
xgb.plot.importance(importance_matrix = importance, numberOfClusters = 8) + ggtitle("Features Importance")


#### Support Vector Machines ####

# model with Hyperbolic tangent kernel
# model_svm <- ksvm(xtrain2, df_y.train, type = "C-svc", C = 100, kernel='tanhdot')
# model with Bessel kernel
# model_svm <- ksvm(xtrain, df_y.train, type = "C-svc", C = 100, kernel='besseldot')
# model with Bessel kernel (probabilistic)
model_svm <- ksvm(xtrain, df_y.train, type = "C-svc", C = 100, kernel='besseldot', prob.model=T)
# model_svm_test <- ksvm(xtrain2, df_y.train[1:200], type = "C-svc", C = 100, kernel='besseldot', prob.model=T)

#Save the model if specified
if(save.models)
    saveRDS(model_svm, "../models/model_svm.rds")

# prediction
prediction_svm <- predict(model_svm, xtest, type = "p")

# measures
measures_svm <- measures(prediction_svm[,1], df_y.test) 
first.validation <- rbind(first.validation, cbind(Model= 'SVM', measures_svm))



#### Logistic Regression ####

# model with cross-validation
model_cvglm <- cv.glmnet(xtrain2, df_y.train, family = 'binomial', keep=TRUE)

if(save.models)
    saveRDS(model_cvglm, "../models/model_cvglm.rds")

# predict with the best lambda
prediction_cvglm <- predict.cv.glmnet(model_cvglm, xtest, type = 'response', s="lambda.min")
# measures
measures_cvglm <- measures(prediction_cvglm, df_y.test)
first.validation <- rbind(first.validation, cbind(Model= 'CVGLM', measures_cvglm))

print('First Step Validation:')
print(first.validation)

######################################################

######################## CLUSTERING  ########################

#Table for the results of the second validation
second.validation <- data.frame(Model = character(0), BestCut = numeric(0), Method = character(0), Precision = numeric(0),
                               Recall = numeric(0), F1 = numeric(0), stringsAsFactors = FALSE)

# Random Forest Clustering
if (!exists('model_rf')) {
  model_rf <- readRDS("../models/model_rf.rds")
}
rf_distTable <- cbind(str_split_fixed(row.names(model_rf$test$votes), "_", n=3), (model_rf$test$votes[,1] ))
colnames(rf_distTable) <- c("id1_d1", "id2_d2", "last_name", "dist")
rf_distTable <- as.data.frame(rf_distTable, stringsAsFactors = FALSE)
rf_distTable$dist <- as.numeric(rf_distTable$dist)
clusResults_rf <- calculateClusters(con, rf_distTable)
second.validation <- rbind(second.validation, cbind(Model='RF', clusResults_rf))

# Generalized Boosted Regression Clustering
if (!exists('prediction_xgb')){
  if (!exists('model_xgb')) {
    model_xgb <- readRDS("../models/model_xgb.rds")
  }
  if (!exists('xtest')) {
    xtest <- readRDS("../models/xtest.rds")
  }
  prediction_xgb <- predict(model_xgb, xtest)
}
xgb_distTable <- cbind(rf_distTable[, 1:3], dist = matrix((1-prediction_xgb),  byrow = T))
# head(gbr_distTable)
clusResults_xgb <- calculateClusters(con, xgb_distTable)
second.validation <- rbind(second.validation, cbind(Model='XGB', clusResults_xgb))

# Support Vector Machines Clustering
if (!exists('prediction_svm')){
  if (!exists('model_svm')) {
    model_svm <- readRDS("../models/model_svm.rds")
  }
  if (!exists('xtest')) {
    xtest <- readRDS("../models/xtest.rds")
  }
  prediction_svm <- predict(model_svm, xtest, type = "p")
}
svm_distTable <- cbind(rf_distTable[, 1:3], dist = matrix((1-prediction_svm[,1]),  byrow = T))
# head(svm_distTable)
clusResults_svm <- calculateClusters(con, svm_distTable)
second.validation <- rbind(second.validation, cbind(Model='SVM', clusResults_svm))

# Logistic Regression Clustering
if (!exists('prediction_cvglm')){
  if (!exists('model_cvglm')) {
    model_cvglm <- readRDS("../models/model_cvglm.rds")
  }
  if (!exists('xtest')) {
    xtest <- readRDS("../models/xtest.rds")
  }
  prediction_cvglm <- predict.cv.glmnet(model_cvglm, xtest, type = 'response', s="lambda.min")
}
cvglm_distTable <- cbind(rf_distTable[, 1:3], dist = matrix((1-prediction_cvglm),  byrow = T))
# head(cvglm_distTable)
clusResults_cvglm <- calculateClusters(con, cvglm_distTable)
second.validation <- rbind(second.validation, cbind(Model='CVGLM', clusResults_cvglm))

print('Second Step Validation:')
print(second.validation)

######################################################

# disconnect from the database
dbDisconnect(con)
# dbUnloadDriver(drv)
