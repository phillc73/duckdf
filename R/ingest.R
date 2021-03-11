#' Ingest data
#'
#' \code{ingest} loads a CSV file from the current working directory and
#'   returns either a new data.frame, data.table, tibble or an on-disk
#'   duckdb.
#'
#' @param name String. The name of the new data.frame. data.table, tibble
#'   or on-disk duckdb. Required.
#'
#' @param files String. The name of the CSV file to ingest. File must be
#'   located in the current working directory. Required.
#'
#' @param persist Boolean. If TRUE and new duckdb is written to disk.
#'   If FALSE by default a data.frame is returned. Default TRUE.
#'
#' @param object_type String. The type of object to return. Default
#'   is a data.frame. Both data.table and tibble are supported. Only
#'   relevant if \code{persist] is set to FALSE.
#'
#' @param header Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param na.strings Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param nrow.check Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param delim Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param quote Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param col.names Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param lower.case.names Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param sep Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @param transaction Parameter to support all duckdb options. See duckdb
#'   documentation for \code{duckdb_read_csv}.
#'   \url{https://cran.r-project.org/web/packages/duckdb/index.html}
#'
#' @return If a CSV file with corresponding name is found in the current
#'   working directory, this function ingests that file, returning either
#'   a data.frame, data.table, tibble or on-disk duckdb.
#'
#' @examples
#' \dontrun{
#'
#' # Ingest the filename.csv file as an on-disk duckdb
#' # database named `descriptive_name`
#'
#' duckdf::ingest(name = "descriptive_name",
#'               file = "filename.csv",
#'               persist = TRUE)
#'
#' # Ingest the filename.csv file, as a data.table
#' # named `descriptive_name`
#'
#' duckdf::ingest(name = "descriptive_name",
#'               file = "filename.csv",
#'               persist = FALSE,
#'               object_type = "data.table")
#'
#'  }
#'
#' @export
#'

ingest <- function(name,
                  files,
                  persist = TRUE,
                  object_type = "data.frame",
                  header = TRUE,
                  na.strings = "",
                  nrow.check = 500,
                  delim = ",",
                  quote = "\"",
                  col.names = NULL,
                  lower.case.names = FALSE,
                  sep = delim,
                  transaction = TRUE) {

if (persist == TRUE) {

    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), paste(name))

    # read in the csv to a duckdb table
    duckdb::duckdb_read_csv(con,
                            name = name, 
                            files = files, 
                            header = header,
                            na.strings = na.strings,
                            nrow.check = nrow.check,
                            delim = delim,
                            quote = quote,
                            col.names = col.names,
                            lower.case.names = lower.case.names,
                            sep = sep,
                            transaction = transaction)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

} else {

# create a DuckDB connection, either as a temporary in-memory database (default)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

# read in the csv to a duckdb table
duckdb::duckdb_read_csv(con, 
                        name = name, 
                        files = files, 
                        header = header,
                        na.strings = na.strings,
                        nrow.check = nrow.check,
                        delim = delim,
                        quote = quote,
                        col.names = col.names,
                        lower.case.names = lower.case.names,
                        sep = sep,
                        transaction = transaction
                        )

# read the data back to a dataframe
df_name <- DBI::dbReadTable(con, paste(name))

    if (isTRUE(object_type == "tibble")) {

        # check if tibble package is installed
        if (requireNamespace("tibble", quietly = TRUE)) {

            # assign the correct name to the new tibble
            assign(paste(name), tibble::as_tibble(df_name), envir = .GlobalEnv)
            

         } else {

            # Error that tibble is not installed
             print("Package `tibble` is not installed")

             }

    } else if (isTRUE(object_type == "data.table")) {

        # check if data.table package is installed
        if (requireNamespace("data.table", quietly = TRUE)) {

            # assign the correct name to the new data.table
            assign(paste(name), data.table::as.data.table(df_name), envir = .GlobalEnv)

            } else {

                # Error that data.table is not installed
                print("Package `data.table` is not installed")

                }

     } else {

            # assign the correct name to the new dataframe
            assign(paste(name), df_name, envir = .GlobalEnv)
            }

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

    }

}