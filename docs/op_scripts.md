# Training/Testing Script Descriptions

A set of R scripts were developed in order to be able to process the signatures present in an article that is coming from the web application. Below you can find a description of these scripts.

##### Process Web Article
The script `Process_Web_Article.R` is the main script of this process and is called directly by the Web Application. It receives the `processid` of the article to process and then it runs the following 6 steps:

 1.  It calculates the `focus_name`'s of the signatures in the article (by using the fuzzystrmatch contrib library of PostgreSQL) and it adds them to the table `main.articles_authors`.
 2. It calculates the LDA Topic by calling the script `Calculate_LDA_topic.R`
 3. It calculates the possible Ethnicities of the last names by calling the script `Calculate_Ethnicity.R`.
 4. It aggregates all the information required to calculate the distances features (title, the keywords, the journals referenced, the subjects, the coauthors and the ethnicities) and then it stores them in the `main.info_for_distances` table.
 5. It calculates the distances features by calling the script `Calculate_Distances.R`.
 6. It predicts which signatures belong to the article's authors by calling the script `Predict_Equal_Authors.R`.

##### LDA Topic Modeling
The script `Calculate_LDA_topic.R` was developed to calculate the LDA Topics of the articles. Using the `topicmodels` R library, and the previously created LDA model (located in `Models\LDA_model.rds`), this script calculates the LDA topics of all the articles in the database that have no LDA topic yet. The predicted topics are then saved in the `main.lda_topic` table within the database.

##### Ethnicity Prediction for Authors' Last Names
The script `Calculate_Ethnicity.R` is responsible for calculating the possible ethinicities for the last names of the different articles' signatures. With the `ngram` R library along with the library `stringdist` to calculate the phonetics, the script uses the `ethnic_*.R` models (located in the `Models\` folder) to calculate these possible ethnicities the scripts create the different models (one per ethnicity) which are stored in the `Models` folder. The results of this process are then stored in the `main.last_name_ethnicities` table within the database.

##### Calculate Distances Between Pairs of Signatures
The script `Calculate_Distances.R` calculates the distances features between the incoming signatures and every other signature in its respective focus name. Using the R library `vegan` the Jaccard distance is calculated between the title (using each word), the keywords (using each word), the journals referenced, the subjects (using each word), the coauthors (using the focus names) and the ethnicities (using each ethnicity value), which are retrieved form the `main.info_for_distances` table in the database. The results of this process are then stored in the different distances tables located in the `distances` schema of the database.

##### Predict Signatures that Belongs to the Same Author
The script `Predict_Equal_Authors.R` is responsible for which signatures already present in the database belong to the same author as the signatures of the article received. This script uses the Logistic Regression Model (located in `Models\model_cvglm.rds`) to predict the signatures of the same authors received (using the `glmnet` R library). The results of this process are then stored in the `main.same_authors` table within the database.
