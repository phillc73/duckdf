duckdf <- function(query = ""){

# Extract dataframe name using sting splits
query_split <- stringi::stri_split_fixed(query, "FROM", omit_empty=TRUE)
query_split <- trimws(unlist(query_split))

from_df <- stringi::stri_extract_first_words(query_split[2], locale = NULL)

# create a DuckDB connection, either as a temporary in-memory database (default) or with a file
con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

# register a dataframe view in duckdb
duckdb::duckdb_register(con, paste(from_df), get(from_df))

# execute required SQL query against the new DuckDB table
statement_result <- DBI::dbGetQuery(con, query)

# close the connection
DBI::dbDisconnect(con, shutdown = TRUE)

# return results
return(statement_result)

}
