duckdf_ingest <- function(name,
                          file,
                          persist = TRUE,
                          object_type = "data.frame") {

if (persist == TRUE) {

    # open db connection
    con <- DBI::dbConnect(duckdb::duckdb(), paste(name))

    # read in the csv to a duckdb table
    duckdb::duckdb_read_csv(con, name = name, files = file)

    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)

} else {

# create a DuckDB connection, either as a temporary in-memory database (default)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

# read in the csv to a duckdb table
duckdb::duckdb_read_csv(con, name = name, files = file)

# read the data back to a dataframe
df_name <- DBI::dbReadTable(con, paste(name))

    if (isTRUE(object_type == "tibble")) {

        # check if tibble package is installed
        if (requireNamespace("fst", quietly = TRUE)) {

            # assign the correct name to the new tibble
            assign(paste(name), tibble::as.tibble(df_name), envir = .GlobalEnv)
            

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