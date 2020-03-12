########

# duckdb()
# query <- paste('SELECT "Species", MIN("Sepal.Width") FROM iris GROUP BY "Species"')

########

duckdf <- function(query = ""){

# Extract dataframe name using sting splits
query_split <- stri_split_fixed(query, "FROM", omit_empty=TRUE)
query_split <- trimws(unlist(query_split))

from_df <- stri_extract_first_words(query_split[2], locale = NULL)

# create a DuckDB connection, either as a temporary in-memory database (default) or with a file
con <- dbConnect(duckdb::duckdb(), ":memory:")

# write a data.frame to the database
dbWriteTable(con, paste(from_df), get(from_df))

# execute required SQL query against the new DuckDB table
statement_result <- dbGetQuery(con, query)

# close the connection
dbDisconnect(con, shutdown = TRUE)

# return results
return(statement_result)

}
