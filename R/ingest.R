# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# ingest(): duckdb_read_csv passthrough. The
# 2021 .GlobalEnv assign is a deliberate break: ingest() RETURNS the
# object; missing return-class packages are package_error, not print()
# and a NULL path.

#' Ingest data
#'
#' \code{ingest} loads a CSV file via \code{duckdb_read_csv} and
#'   returns either a new data.frame, data.table, tibble or an on-disk
#'   duckdb.
#'
#' @param name String. The name of the new data.frame, data.table,
#'   tibble or on-disk duckdb. Required.
#' @param files String. The name of the CSV file to ingest. File must
#'   be located in the current working directory. Required.
#' @param persist Logical. If TRUE the CSV lands as table \code{name}
#'   in a new on-disk database file \code{name}; the
#'   \code{duckdb_read_csv} result is returned invisibly (a count;
#'   side-effect function). If FALSE the ingested data is
#'   returned as an object of \code{object_type}. Calling again with
#'   the same \code{name} on an existing database re-reads the CSV
#'   into the existing table: the rows add up, they do not replace -
#'   remove the database first (\code{cleanup()}) for a fresh ingest.
#'   Note that \code{duckdb_read_csv} itself leaves an empty file
#'   named \code{duckdb} in the working directory; that is duckdb-r
#'   behaviour.
#' @param object_type String. The type of object to return when
#'   \code{persist = FALSE}: "data.frame" (default), "data.table" or
#'   "tibble".
#' @param ... All \code{duckdb_read_csv} options, passed through
#'   unchanged (header, na.strings, nrow.check, delim, quote,
#'   col.names, lower.case.names, sep, transaction).
#'
#' @return With \code{persist = TRUE}: the duckdb_read_csv result,
#'   invisibly. With \code{persist = FALSE}: the ingested data as an
#'   object of \code{object_type}. Callers capture:
#'   \code{mtcars2 <- ingest("mtcars2", "mtcars.csv", persist = FALSE)}.
#'
#' @examples
#' \dontrun{
#'
#' # Ingest the filename.csv file as an on-disk duckdb
#' # database named `descriptive_name`
#' duckdf::ingest(name = "descriptive_name", files = "filename.csv")
#'
#' # Ingest the filename.csv file as a data.table, returned for capture
#' mtcars2 <- duckdf::ingest(name = "mtcars2", files = "filename.csv",
#'                           persist = FALSE, object_type = "data.table")
#'
#' }
#'
#' @export
#'

ingest <- function(name, files, persist = TRUE, object_type = "data.frame",
                   ...) {
  assert_input(checkmate::assert_string(name, min.chars = 1,
    .var.name = "name"))
  assert_input(checkmate::assert_string(files, min.chars = 1,
    .var.name = "files"))
  assert_input(checkmate::assert_flag(persist, .var.name = "persist"))
  assert_input(checkmate::assert_choice(object_type,
    choices = c("data.frame", "data.table", "tibble"),
    .var.name = "object_type"))
  if (!isTRUE(persist) && object_type != "data.frame" &&
      !requireNamespace(object_type, quietly = TRUE)) {
    duckdf_stop("package_error",
      sprintf(paste0("%s is required for object_type = '%s'; ",
                     "install it with install.packages('%s')"),
              object_type, object_type, object_type))
  }

  if (isTRUE(persist)) {
    result <- with_disk_con(name, function(con) {
      duckdb::duckdb_read_csv(con, name = name, files = files, ...)
    })
    return(invisible(result))
  }

  con <- duckdf_con()
  data <- tryCatch({
    duckdb::duckdb_read_csv(con, name = name, files = files, ...)
    DBI::dbReadTable(con, name)
  }, finally = tryCatch(duckdb::duckdb_unregister(con, name),
                        error = function(e) NULL))
  if (object_type == "tibble") {
    tibble::as_tibble(data)
  } else if (object_type == "data.table") {
    duckdf_coerce_result(data, TRUE)
  } else {
    data
  }
}
