# Training/Testing Script Descriptions

A set of R scripts were develped in order to be able to correctly disambiguate the authors for the training and testing sets, so the accuracy of the application could be measured. Below you can find a description of these scripts.

##### LDA Topic Modeling
The script `Topic_modeling.R` was developed to create the model and calculate the LDA Topics of the articles within the Training and Testing sets. Using the `topicmodels` R library, it process the articles information and categorize them in 8 different topics. The script saves the model for calculating the LDA topic in the folder `Models\LDA_model.rds`. The predicted topics are then saved in the `main.lda_topic` table within the database.

##### Ethnicity Prediction for Authors' Last Names
The scripts `ethnic_api.R`, `ethnic_black.R`, `ethnic_2prace.R`, `ethnic_hispanic.R`, `ethnic_aian.R` and `ethnic_white.R` are responsible for create the models to calculate the different possible ethnicities of any last name, based on the information provided by the [US “Demographic Aspects of Surnames from Census 2000”](http://www2.census.gov/topics/genealogy/%202000surnames/surnames.pdf) . Using the 

`CalculateDistances_V2.R`
`Models.R`
