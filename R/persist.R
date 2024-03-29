#' Write persistent duckdb to disk
#'
#' \code{persist} writes a named dataframe to a persistent on disk
#'   duckdb database in the current working directory.
#'
#' @param query String. The SQL query to execute. The name of the
#'   on-disk database will be the same as the first named dataframe
#'   in this query string, unless specified differently in
#'   \code{db_name} parameter. Required.
#' 
#' @param db_name String. Specifies the name of the on disk duckdb to
#'   read from or write to. If an on-disk duckdb matching this name is
#'   not found in the current working directory, one will be created.
#'   if multiple dataframes are name in the \code{query} string, multiple
#'   tables will be created within that duckdb database.
#' 
#' @return If the corresponding database is found in the current working
#'   directory, this function executes an SQL query against it. If no 
#'   matching database is found, one is created and the relevant SQL
#'   executed against it. The results of the SQL statement are returned.
#'
#' @examples
#' \dontrun{
#' 
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf::persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
#' 
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' # with a different name
#' duckdf::persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'                  db_name = "mtcars_duckdb")
#' 
#'  }
#'
#' @export 
#' 

persist <- function(query = "",
                           db_name = NULL) {

  # Extract dataframe name using sting splits
  query_split <- stringi::stri_split_fixed(query, "FROM",
                                           omit_empty = TRUE,
                                           opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

  query_split <- trimws(unlist(query_split))

  from_df <- stringi::stri_extract_first_words(query_split[2], locale = NULL)

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
  db_name <- from_df
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

