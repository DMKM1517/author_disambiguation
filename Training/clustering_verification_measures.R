
# install.packages("combinat")
library(combn)

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



r <- c("A", "A", "B", "B", "C")
s <- c("A", "A", "B", "C", "C")
r <- clusterTest$computed_cluster
s <- clusterTest$real_cluster


b3Precision(r,s)
b3Recall(r,r)



