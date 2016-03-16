
# install.packages("RPostgreSQL")
# install.packages("randomForest")
require("RPostgreSQL")
library(randomForest)

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



#query to get the view of distances
query_distances <- 
  "select id1 || '_' || xid1 || '_' || id2 || '_' || xid2 || '_' || last_name as id_distances, 
eq_finitial, eq_sinitial, dist_keywords, dist_refs, dist_subject, dist_title, same_author
from v_authors_distance_disambiguated;"

# Retreives the table from the database
df_distances <- dbGetQuery(con, query_distances)
head(df_distances, n = 10)
dim(df_distances)

df_bin <- data.frame(df_distances[,-1], row.names=df_distances[,1])
head(df_bin, n = 10)

df_x <- df_bin[,1:6]
df_y <- as.factor(df_bin$same_author)

rf <- randomForest(df_x,df_y)
rf
