#install.packages("stringdist")
#install.packages("e1071")
#install.packages("gtools")
#install.packages("sqldf")


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

surnames <- read.csv('app_c.csv', header = TRUE, stringsAsFactors = FALSE)
surnames <- surnames[sample(nrow(surnames)),]

# head(surnames)

##### BEGIN BALANCING THE DATAS

surnames[surnames=="(S)"] <- 0

# category = max percentage 

surnames$cat <- colnames(surnames[,6:11])[max.col(surnames[,6:11],ties.method="first")]

ind0 <- which(surnames[,"cat"]=='pctwhite')
ind1 <- which(surnames[,"cat"]!='pctwhite')


sampsize <- 1000

sampind0 <- sample(ind0, sampsize, replace = TRUE)
sampind1 <- sample(ind1, sampsize, replace = TRUE)

sur_white <- surnames[unique(c(sampind1,sampind0)),]


##### END BALANCING THE DATAS


# take surname + percentage

sur_white <- sur_white[,c(1,6)]
# head(sur_white)

# separating surname by spaces

sur_white$new <- gsub("(.)", "\\1 \\2", sur_white[,1])

# adding phonetic column

sur_white[,4] <- phonetic(sur_white[,1])

colnames(sur_white) <- c("name", "pctwhite", "letters", "soundex")

sur_white_new <- NULL

# getting bigrams

for (i in 1:length(sur_white[,3])){
  tmp <- ngram(sur_white[i,3], n=2)
  for (j in 1:length(get.ngrams(tmp))){
    sur_white_new <- rbind(sur_white_new, c(sur_white[i,1], get.ngrams(tmp)[j]))
  }
}

colnames(sur_white_new) <- c("surname", "bigram")
# head(sur_white_new)

sur_white_new <- as.data.frame(sur_white_new)


# binary matrix

sur_white_bin <- acast(sur_white_new, formula = surname ~ bigram, fun.aggregate = length)
sur_white_bin <- as.data.frame(sur_white_bin)

# head(sur_white_bin)

# matrix with all possible bigrams

full_ngram <- data.frame(gtools::permutations(26,2,v=LETTERS,repeats.allowed=T))

full_ngram <- paste(full_ngram[,1], full_ngram[,2])

full_ngram_table <- data.frame(R = 1, bigram = full_ngram)
full_ngram_table <- acast(full_ngram_table, formula = R ~ bigram, fun.aggregate = length)
full_ngram_table <- full_ngram_table[0,]

# which columns need to be added

add_bigrams <- colnames(full_ngram_table)[!(colnames(full_ngram_table) %in% colnames(sur_white_bin))]

zeros <- matrix(0, ncol = length(add_bigrams), nrow = length(sur_white_bin[,1]))
zeros <- as.data.frame(zeros)

colnames(zeros) <- add_bigrams

sur_white_bin <- cbind(sur_white_bin, zeros)


# adding soundex and percentage to binary matrix

tmp <- sur_white[c("soundex", "pctwhite")]
colnames(tmp) <- c("soundex", "percent")
rownames(tmp) <- sur_white$name

# merging according to rownames

sur_white_bin <- merge(sur_white_bin, tmp, by=0)

# first column of rownames was added, bringing it back

rownames(sur_white_bin) <- sur_white_bin[,1]
sur_white_bin <- sur_white_bin[,-1]

# sur_white_bin <- cbind(sur_white_bin, soundex = sur_white$soundex, percent = sur_white$pctwhite)
# head(sur_white_bin)


sur_white_bin$percent <- as.numeric(sur_white_bin$percent)
sur_white_bin$percent[is.na(sur_white_bin$percent)] <- 0

sur_white_bin$cat[sur_white_bin$percent>60] <- 1
sur_white_bin$cat[sur_white_bin$percent<=60] <- 0


sur_white_bin$cat <- factor(sur_white_bin$cat)

#transform soundex to numeric

for (i in 1:length(sur_white_bin$soundex)){
  sur_white_bin$soundex_num[i] <- as.numeric(paste(as.vector(asc(as.character(sur_white_bin$soundex[i]), simplify=TRUE)), collapse = ""))
}


# head(sur_white_bin)

sur_mach_learn <-  cbind(sur_white_bin[,1:(length(sur_white_bin)-4)], sur_white_bin[length(sur_white_bin)], cat=sur_white_bin$cat)

# mix it

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

saveRDS(svm_model, "../models/ethnic_white.rds")


