duckdf_variant <- function(query = ""){

  # Extract dataframe name using sting splits
  query_split <- stringi::stri_split_fixed(query, "FROM", omit_empty=TRUE)
  query_split <- trimws(unlist(query_split))

  from_df <- stringi::stri_extract_first_words(query_split[2], locale = NULL)

  # name for dataframe view to be created
  from_df_view <- paste0(from_df,"_view")

  # create a DuckDB connection, either as a temporary in-memory database (default) or with a file
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  # register a dataframe view in duckdb
  duckdb::duckdb_register(con, paste(from_df_view), get(from_df))

  # re-write query to use dataframe_view
  qsplit_view <- stri_replace_all_fixed(query_split[2], paste(from_df), paste(from_df_view))
  query_view <- paste(query_split[1], "FROM", qsplit_view)

  # execute required SQL query against the new DuckDB table
  statement_result <- DBI::dbGetQuery(con, query_view)

  # close the connection
  DBI::dbDisconnect(con, shutdown = TRUE)

  # return results
  return(statement_result)

}
