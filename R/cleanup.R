#' Clean up your duckdbs
#'
#' \code{cleanup} removes all traces of the named duckdb database
#'   from disk
#'
#' @param query String. The specific name of the duckdb database to
#'   be removed. Required. Default is an empty string.
#' 
#' @return If the database is found in the current working directory,
#'   this function removes the database, .wal and .tmp files
#'   corresponding to this name.
#'
#' @examples
#' \dontrun{
#' 
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'        persist = TRUE)
#' 
#' # Remove all traces of the on-disk duckdb database called mtcars, 
#' duckdf::cleanup("mtcars")
#' 
#'  }
#'
#' @export 
#' 

cleanup <- function(query = "") {

  # check if the files exist and if they do, remove them
  if (file.exists(query))
    file.remove(query)

  if (file.exists(paste0(query, ".wal")))
    file.remove(paste0(query, ".wal"))

  if (file.exists(paste0(query, ".tmp")))
    file.remove(paste0(query, ".tmp"))
}
