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