duckdf <- function(query = "",
                   persist = FALSE,
                   df_name = NULL,
                   db_name = NULL) {
  
  # If they want a DuckDB on disk.....
  if (persist == TRUE) {
    
    duckdf::persist(query,
                    db_name)
    
  } else {
    
    # create a DuckDB connection, either as a temporary in-memory database (default)
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)
    
    # if there's NOT a named dataframe (or multiple), find them in the query
    if (is.null(df_name)) {
      query_dfs=stringr::str_match_all(query, '(?i)(\\bfrom\\b|\\bjoin\\b)\\s*(\\w+)')[[1]][,3]
      query_dfs=unique(query_dfs)
      if_df_exists=function(x){
        tryCatch(
          expr = {  is(eval.parent(parse(text=x)), "data.frame")  },
          error = function(e){  F  } )
        }
      df_name= query_dfs[ sapply(query_dfs,if_df_exists) ]
    }
      
      duckdb_reg <- function(x) {  
        
        duckdb::duckdb_register(con, paste(x), get(x))}
      
      sapply(df_name, duckdb_reg)
      
    
    
    # execute required SQL query against the new DuckDB table
    statement_result <- DBI::dbGetQuery(con, query)
    
    # close the connection
    DBI::dbDisconnect(con, shutdown = TRUE)
    
    # return results
    return(statement_result)
    
  }
}
