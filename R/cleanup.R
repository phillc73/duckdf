# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# cleanup(): removes the named on-disk database and sidecar files;
# also closes the shared connection. Returns the files removed,
# invisibly.

#' Clean up your duckdbs
#'
#' \code{cleanup} removes all traces of the named duckdb database from
#'   disk and closes the shared in-memory connection.
#'
#' @param db_name String. The specific name of the duckdb database to
#'   be removed. Required.
#'
#' @return Invisibly, the character vector of files removed. Missing
#'   files are not errors.
#'
#' @examples
#' \dontrun{
#'
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'        persist = TRUE)
#'
#' # Remove all traces of the on-disk duckdb database called mtcars
#' duckdf::cleanup("mtcars")
#'
#' }
#'
#' @export
#'

cleanup <- function(db_name) {
  assert_input(checkmate::assert_string(db_name, min.chars = 1,
                                        .var.name = "db_name"))
  duckdf_shutdown()
  candidates <- c(db_name, paste0(db_name, ".wal"), paste0(db_name, ".tmp"))
  existing <- candidates[file.exists(candidates)]
  if (length(existing) > 0) {
    file.remove(existing)
  }
  invisible(existing)
}
