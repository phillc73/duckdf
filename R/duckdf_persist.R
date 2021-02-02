duckdf_persist <- function(query = "") {

  # Extract dataframe name using sting splits
  query_split <- stringi::stri_split_fixed(query, "FROM",
                                           omit_empty = TRUE,
                                           opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

  query_split <- trimws(unlist(query_split))

  from_df <- stringi::stri_extract_first_words(query_split[2], locale = NULL)

  # If the database exists, just execute the query
  if (file.exists(paste(from_df)) == TRUE) {

    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), paste(from_df))

    # execute required SQL query against the existing DuckDB table
    statement_result <- DBI::dbGetQuery(con, query)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    # return results
    return(statement_result)

    # if the db doesn't exist, create it and then execute the query
  } else {
    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), paste(from_df))

    # write a data.frame to the database
    DBI::dbWriteTable(con, paste(from_df), get(from_df))

    # execute required SQL query against the new DuckDB table
    statement_result <- DBI::dbGetQuery(con, query)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    # return results
    return(statement_result)
  }

}
