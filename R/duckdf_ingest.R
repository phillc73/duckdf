duckdf_ingest <- function(name, files) {

# create a DuckDB connection, either as a temporary in-memory database (default)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

# read in the csv to a duckdb table
duckdb::duckdb_read_csv(con, name = name, files = files)

# read the data back to a dataframe
df_name <- DBI::dbReadTable(con, paste(name))

# assign the correct name to the new dataframe
assign(paste(name), df_name, envir=.GlobalEnv)

# close the connection
DBI::dbDisconnect(con, shutdown = TRUE)

}