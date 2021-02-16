duckdf <- function(query = "",
                                persist = FALSE) {

if (persist == TRUE){

    duckdf_persist(query)

} else {
    
# create a DuckDB connection, either as a temporary in-memory database (default)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

# Extract dataframe name using sting splits
query_split <- stringi::stri_split_fixed(query, "FROM",
                                         omit_empty = TRUE,
                                         opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

query_split <- trimws(unlist(query_split))

from_df_first <- stringi::stri_extract_first_words(query_split[2], 
                                                   locale = NULL)

# register a dataframe view in duckdb
duckdb::duckdb_register(con, paste(from_df_first), get(from_df_first))

# If a JOIN exists do this
if (stringi::stri_detect_fixed(query, "JOIN",
                  opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE)) == TRUE) {

# Extract dataframe name using sting splits
query_split_second <- stringi::stri_split_fixed(query, "JOIN",
                                                omit_empty = TRUE,
                                                opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

query_split_second <- trimws(unlist(query_split_second))

from_df_second <- stringi::stri_extract_first_words(query_split_second[2],
                                                    locale = NULL)

# register a dataframe view in duckdb
duckdb::duckdb_register(con, paste(from_df_second), get(from_df_second))

}

# execute required SQL query against the new DuckDB table
statement_result <- DBI::dbGetQuery(con, query)

# close the connection
DBI::dbDisconnect(con, shutdown = TRUE)

# return results
return(statement_result)
    }

}

