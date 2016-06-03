#install.packages("stringdist")
#install.packages("e1071")
#install.packages("gtools")
#install.packages("sqldf")
#install.packages("rstudioapi")

library(rstudioapi)
library(gtools)
library(devtools)
library(ngram)
library(reshape2)
library(stringdist)
library(e1071)
library(caret)
library(randomForest)

# setwd("~/R/ethnic")

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


surnames <- read.csv('app_c.csv', header = TRUE, stringsAsFactors = FALSE)
surnames <- surnames[sample(nrow(surnames)),]

# head(surnames)

##### BEGIN BALANCING THE DATAS

surnames[surnames=="(S)"] <- 0

# category = max percentage 

surnames$cat <- colnames(surnames[,6:11])[max.col(surnames[,6:11],ties.method="first")]

ind0 <- which(surnames[,"cat"]=='pct2prace')
ind1 <- which(surnames[,"cat"]!='pct2prace')

sampsize <- 140

sampind0 <- sample(ind0, sampsize, replace = TRUE)
sampind1 <- sample(ind1, sampsize, replace = TRUE)

sur_race <- surnames[unique(c(sampind1,sampind0)),]


##### END BALANCING THE DATAS


# take surname + percentage 6 - white, 7 - black, etc !!! changable

sur_race <- sur_race[,c(1,10)]
# head(sur_race)

# separating surname by spaces

sur_race$new <- gsub("(.)", "\\1 \\2", sur_race[,1])

# adding phonetic column

sur_race[,4] <- phonetic(sur_race[,1])

colnames(sur_race) <- c("name", "pct", "letters", "soundex")

sur_race_new <- NULL

# getting bigrams

for (i in 1:length(sur_race[,3])){
  tmp <- ngram(sur_race[i,3], n=2)
  for (j in 1:length(get.ngrams(tmp))){
    sur_race_new <- rbind(sur_race_new, c(sur_race[i,1], get.ngrams(tmp)[j]))
  }
}

colnames(sur_race_new) <- c("surname", "bigram")
# head(sur_race_new)

sur_race_new <- as.data.frame(sur_race_new)


# binary matrix

sur_race_bin <- acast(sur_race_new, formula = surname ~ bigram, fun.aggregate = length)
sur_race_bin <- as.data.frame(sur_race_bin)


# matrix with all possible bigrams

full_ngram <- data.frame(gtools::permutations(26,2,v=LETTERS,repeats.allowed=T))

full_ngram <- paste(full_ngram[,1], full_ngram[,2])

full_ngram_table <- data.frame(R = 1, bigram = full_ngram)
full_ngram_table <- acast(full_ngram_table, formula = R ~ bigram, fun.aggregate = length)
full_ngram_table <- full_ngram_table[0,]

# which columns need to be added

add_bigrams <- colnames(full_ngram_table)[!(colnames(full_ngram_table) %in% colnames(sur_race_bin))]

zeros <- matrix(0, ncol = length(add_bigrams), nrow = length(sur_race_bin[,1]))
zeros <- as.data.frame(zeros)

colnames(zeros) <- add_bigrams

sur_race_bin <- cbind(sur_race_bin, zeros)


# adding soundex and percentage to binary matrix

tmp <- sur_race[c("soundex", "pct")]
colnames(tmp) <- c("soundex", "percent")
rownames(tmp) <- sur_race$name
# head(tmp)

# merging according to rownames

sur_race_bin <- merge(sur_race_bin, tmp, by=0)

# first column of rownames was added, bringing it back

rownames(sur_race_bin) <- sur_race_bin[,1]
sur_race_bin <- sur_race_bin[,-1]

# sur_race_bin <- cbind(sur_race_bin, soundex = sur_race$soundex, percent = sur_race$pctblack)
# head(sur_race_bin)
# str(sur_race_bin$percent)

sur_race_bin$percent <- as.numeric(sur_race_bin$percent)
sur_race_bin$percent[is.na(sur_race_bin$percent)] <- 0

sur_race_bin$cat[sur_race_bin$percent>30] <- 1
sur_race_bin$cat[sur_race_bin$percent<=30] <- 0

# summary(sur_race_bin$cat)

sur_race_bin$cat <- factor(sur_race_bin$cat)

#transform soundex to numeric

for (i in 1:length(sur_race_bin$soundex)){
  sur_race_bin$soundex_num[i] <- as.numeric(paste(as.vector(asc(as.character(sur_race_bin$soundex[i]), simplify=TRUE)), collapse = ""))
}


# head(sur_race_bin)

sur_mach_learn <-  cbind(sur_race_bin[,1:(length(sur_race_bin)-4)], sur_race_bin[length(sur_race_bin)], cat=sur_race_bin$cat)
sur_mach_learn <- sur_mach_learn[sample(nrow(sur_mach_learn)),]
# head(sur_mach_learn)

# separating training and testing

smp_size <- floor(0.75 * nrow(sur_mach_learn))

## set the seed to make your partition reproductible
set.seed(123)
train_ind <- sample(seq_len(nrow(sur_mach_learn)), size = smp_size)

train <- sur_mach_learn[train_ind, ]
test <- sur_mach_learn[-train_ind, ]



x <- subset(train, select=-cat)
y <- train$cat

x_test <- subset(test, select=-cat)
y_test <- test$cat

svm_model <- svm(cat  ~ ., data=train)
summary(svm_model)

pred <- predict(svm_model,x)

confusionMatrix(pred, y)


saveRDS(svm_model, "../models/ethnic_2prace.rds")


