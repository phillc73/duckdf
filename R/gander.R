# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# gander(): brief look at an on-disk database - spec-api-contract.md.
# The 2021 two-table cap and its dead duckdf_persist call are gone; a
# missing database is a db_error, not a returned string.

#' Gander at duckdbs
#'
#' \code{gander} returns some brief information about an on-disk
#'   duckdb database.
#'
#' @param db_name String. The specific name of the duckdb database to
#'   have a gander at. Required.
#' @param show_types Logical. Add column type information to each
#'   element. Default FALSE.
#'
#' @return A named list, one element per table in the database, each
#'   holding the table's first five rows. Element names are the table
#'   names. With \code{show_types = TRUE} each element gains a
#'   "types" attribute naming the columns and their types.
#'
#' @examples
#' \dontrun{
#'
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'        persist = TRUE)
#'
#' # Gander at the tables in the on-disk duckdb database for mtcars,
#' # showing column types
#' duckdf::gander("mtcars", show_types = TRUE)
#'
#' }
#'
#' @export
#'

gander <- function(db_name, show_types = FALSE) {
  assert_input(checkmate::assert_string(db_name, min.chars = 1,
    .var.name = "db_name"))
  assert_input(checkmate::assert_flag(show_types, .var.name = "show_types"))
  if (!file.exists(db_name)) {
    duckdf_stop("db_error",
      sprintf("no database exists at '%s' in the current directory", db_name))
  }
  tables <- with_disk_con(db_name, function(con) {
    names <- DBI::dbListTables(con)
    out <- lapply(names, function(t) {
      # battery F5: table names are identifiers, never raw
      # interpolation - double-quote escaping
      quoted <- paste0('"', gsub('"', '""', t), '"')
      head <- DBI::dbGetQuery(con,
        sprintf("SELECT * FROM %s LIMIT 5", quoted))
      if (isTRUE(show_types)) {
        # battery F6: type metadata only when asked for
        types <- DBI::dbGetQuery(con,
          paste0("SELECT column_name, data_type FROM ",
                 "information_schema.columns WHERE table_name = ?"),
          params = list(t))
        attr(head, "types") <- types
      }
      head
    })
    stats::setNames(out, names)
  }, read_only = TRUE)
  tables
}
