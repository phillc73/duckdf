hatch <- function(query = "",
                           db_name = NULL) {

  # Extract dataframe name using sting splits
  query_split <- stringi::stri_split_fixed(query, "INTO",
                                           omit_empty = TRUE,
                                           opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

  query_split <- trimws(unlist(query_split))

  to_df <- stringi::stri_extract_first_words(query_split[2], locale = NULL)

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
                  }

# check for a user set db_name, otherwise use first dataframe name
if (is.null(db_name)) {
  db_name <- to_df
}

  # If the database exists, just execute the query
  if (file.exists(db_name) == TRUE) {

    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), db_name)

    # execute required SQL query against the existing DuckDB table
    statement_result <- DBI::dbGetQuery(con, query)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    # return results
    return(statement_result)

    # if the db doesn't exist, create it and then execute the query
  } else {

    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), db_name)

    # write a data.frame to the database
    DBI::dbWriteTable(con, paste(from_df), get(from_df))

    if (exists("from_df_second") == TRUE) {
      # register a second table in duckdb if a second table is required
      DBI::dbWriteTable(con, paste(from_df_second), get(from_df_second))
      }
    }

    # execute required SQL query against the new DuckDB table
    statement_result <- DBI::dbGetQuery(con, query)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    # return results
    return(statement_result)
  }
