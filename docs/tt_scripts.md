# Training/Testing Script Descriptions

A set of R scripts were developed in order to be able to correctly disambiguate the authors for the training and testing sets, so the accuracy of the application could be measured. Below you can find a description of these scripts.

##### LDA Topic Modeling
The script `Topic_modeling.R` was developed to create the model and calculate the LDA Topics of the articles within the Training and Testing sets. Using the `topicmodels` R library, it process the articles information and categorize them in 8 different topics. The script saves the model for calculating the LDA topic in the folder `Models\LDA_model.rds`. The predicted topics are then saved in the `main.lda_topic` table within the database.

##### Ethnicity Prediction for Authors' Last Names
The scripts `ethnic_api.R`, `ethnic_black.R`, `ethnic_2prace.R`, `ethnic_hispanic.R`, `ethnic_aian.R` and `ethnic_white.R` are responsible for create the models to calculate the different possible ethnicities of any last name, based on the information provided by the [US “Demographic Aspects of Surnames from Census 2000”](http://www2.census.gov/topics/genealogy/%202000surnames/surnames.pdf) . Using the `ngram` R library along with the library `stringdist` to calculate the phonetics, the scripts create the different models (one per ethnicity) which are stored in the `Models` folder.

##### Calculate Distances Between Pairs of Signatures
The script `CalculateDistancesTraining.R` calculates the distances features between every pair of signatures for each focus name. Using the R library `vegan` the Jaccard distance is calculated between the title (using each word), the keywords (using each word), the journals referenced, the subjects (using each word), the coauthors (using the focus names) and the ethnicities (using each ethnicity value), for every pair of signatures. The results of this process are then stored in the different distances tables located in the `distances` schema of the database. __Warning:__ The script has the ability to calculate the distances for only the training and testing sets or for the whole database as well. If you want the first case make sure the variable `testing` is set to `TRUE`.

##### Create the different Models
The script `Models.R` is responsible for creating the different models for disambiguating the signatures in the database. This script creates four models: Random Forest (using the `randomForest` R library), Gradient Boost (using the `xgboost` R library), Support Vector Machine (using the `kernlab` R library) and Logistic Regression (using the `glmnet` R library); which are then stored in the `Models` folder and whose results are then used to run hierarchical clustering (using the base `stats` R library) to cluster and finally disambiguate the authors. The results of the disambiguation process are then stored in the `main.authors_disambiguated` table within the database.
