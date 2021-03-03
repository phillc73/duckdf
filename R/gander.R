#' Gander at duckdbs
#'
#' \code{gander} returns some brief information about an on-disk duckdb database
#'
#' @param db_name String. The specific name of the duckdb database to have a
#'   gander at. Default is empty. Required.
#' 
#'  @param show_types Boolean. Show table column types in returned list. 
#'   Default FALSE
#' 
#' @return If the database is found in the current working directory, this
#'  function returns a list of the first five rows from each table. Each
#'  list item name corresponds with the database table name.
#'
#' @section Note on \code{gander}: Currently only databases with up to a maximum
#'  of two tables are supported.
#'
#' @examples
#' \dontrun{
#' 
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'        persist = TRUE)
#' 
#' # Gander at the tables in the on-disk duckdbdatabase for mtcars, 
#' # showing column types
#' duckdf::gander("mtcars", show_types = TRUE)
#' 
#'  }
#'
#' @export 
#' 

gander <- function(db_name,
                           show_types = FALSE) {

    if (file.exists(db_name) == FALSE) {

    # Display error message if no table exists by that name
    gander_result <-
    "No database exists with that name in the current directory"

    return(gander_result)

    } else {

    # Open a databse connection
    con <- DBI::dbConnect(duckdb::duckdb(), db_name)

    # Return the database metadata
    gander_result <- DBI::dbListTables(con, db_name)

    # Close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    # Check to see if there are two tables
    if (exists(stringi::stri_extract_first_words(gander_result[2])) == TRUE) {

    # Make a list containing both tables
    gander_result_tables <- list(
        duckdf_persist(paste0("SELECT * from ",
                       stringi::stri_extract_first_words(gander_result[1],
                       locale = NULL), " LIMIT 5;")),

        duckdf_persist(paste0("SELECT * from ",
                       stringi::stri_extract_first_words(gander_result[2],
                       locale = NULL), " LIMIT 5;"),
                       db_name = stringi::stri_extract_first_words(gander_result[1]))
                       )

    # Give each list element a name
    names(gander_result_tables) <-
    c(paste(stringi::stri_extract_first_words(gander_result[1])),
    paste(stringi::stri_extract_first_words(gander_result[2])))

    } else {

    # If there's only one table, just make a one item list
    gander_result_tables <- list(
        duckdf_persist(paste0("SELECT * from ",
                       stringi::stri_extract_first_words(gander_result[1],
                       locale = NULL), " LIMIT 5;"))
                       )

    # Give each list element a name
    names(gander_result_tables) <-
    c(paste(stringi::stri_extract_first_words(gander_result[1])))

    }

    if (show_types == TRUE) {

    # return results showing element types
    return(str(gander_result_tables))

    } else {

    # return results with showing each element type
    return(gander_result_tables)
    }

    }

}
