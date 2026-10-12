# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# persist(): on-disk query-or-create. The 2021
# create-branch leaked its connection on write error; with_disk_con()
# closes on every exit path.

# Shared validation/branching for the on-disk create path: tables come
# from the df list or the caller's frame (df_name verbatim)
duckdf_resolve_tables <- function(query, df, df_name, env) {
  con <- duckdf_con()
  tables <- list()
  if (!is.null(df)) {
    tables <- c(tables, df)
    if (is.null(df_name)) {
      # df names are the extraction candidate scope:
      # validation only, the create path registers the whole list
      table_refs(query, con, names(tables))
    }
  }
  if (!is.null(df_name)) {
    resolved <- lapply(df_name, function(n) {
      obj <- tryCatch(get(n, envir = env), error = function(e) NULL)
      if (is.null(obj)) {
        duckdf_stop("missing_object_error",
          sprintf("df_name '%s' not found in the calling scope; pass it via df",
                  n))
      }
      obj
    })
    tables <- c(tables, stats::setNames(resolved, df_name))
  }
  if (is.null(df) && is.null(df_name)) {
    refs <- table_refs(query, con, duckdf_frame_candidates(env))
    tables <- stats::setNames(lapply(refs, function(n) get(n, envir = env)), refs)
  }
  tables
}

#' Write persistent duckdb to disk
#'
#' \code{persist} executes a query against an on-disk duckdb database
#'   in the current working directory, creating it (and writing the
#'   queried dataframes as tables) when it does not exist.
#'
#' @param query String. A single SQL statement (multi-statement
#'   queries are rejected). The name of the
#'   on-disk database will be the same as the first named dataframe
#'   in this query string, unless specified differently in
#'   \code{db_name} parameter. Required.
#' @param db_name String. Specifies the name of the on disk duckdb to
#'   read from or write to. If an on-disk duckdb matching this name is
#'   not found in the current working directory, one will be created
#'   (writing the df/df_name tables); if it exists, df and df_name are
#'   an error - the query runs against the data already on disk.
#' @param df Named list of dataframes to write as tables when creating
#'   the database; those names are the extraction candidate scope.
#' @param df_name Character vector of variable names in the calling
#'   scope to write as tables - registered verbatim, the extractor is
#'   not invoked, so multi-statement queries and DDL also pass
#'   through here.
#' @param params Parameter list forwarded to \code{DBI::dbGetQuery()}
#'   untouched.
#' @param as.data.table Logical. Return a data.table instead of a plain
#'   data.frame.
#'
#' @return The results of the SQL statement: data.frame by default,
#'   data.table when \code{as.data.table = TRUE}. All tables are
#'   written before any query executes; the connection is closed on
#'   every exit path.
#'
#' @examples
#' \dontrun{
#'
#' # Query the mtcars dataframe and write the whole table to an on-disk duckdb
#' duckdf::persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
#'
#' # Same, with a different database name
#' duckdf::persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
#'                 db_name = "mtcars_duckdb")
#'
#' }
#'
#' @export
#'

persist <- function(query, db_name = NULL, df = NULL, df_name = NULL,
                    params = NULL, as.data.table = FALSE) {
  # validation before any connection work (error-class check order)
  assert_input(checkmate::assert_string(query, .var.name = "query"))
  if (trimws(query) == "") {
    duckdf_stop("input_error", "query must not be empty")
  }
  assert_input(checkmate::assert_string(db_name, null.ok = TRUE,
    .var.name = "db_name"))
  assert_input(checkmate::assert_list(df, types = "data.frame",
    names = "unique", null.ok = TRUE, .var.name = "df"))
  assert_input(checkmate::assert_character(df_name, any.missing = FALSE,
    min.chars = 1, unique = TRUE, null.ok = TRUE, .var.name = "df_name"))
  assert_input(checkmate::assert_list(params, null.ok = TRUE,
    .var.name = "params"))
  assert_input(checkmate::assert_flag(as.data.table,
    .var.name = "as.data.table"))
  if (isTRUE(as.data.table) && !requireNamespace("data.table", quietly = TRUE)) {
    duckdf_stop("package_error",
      paste0("data.table is required for as.data.table = TRUE; ",
             "install it with install.packages('data.table')"))
  }

  env <- parent.frame()
  if (is.null(db_name)) {
    con <- duckdf_con()
    tables <- duckdf_resolve_tables(query, df, df_name, env)
    refs <- table_refs(query, con, names(tables))
    if (length(refs) == 0) {
      duckdf_stop("input_error",
        "no table reference in the query; pass db_name explicitly")
    }
    db_name <- refs[1]
    create <- TRUE
  } else {
    create <- !file.exists(db_name)
    if (!create && (!is.null(df) || !is.null(df_name))) {
      # silent data-source switch is a trap
      duckdf_stop("input_error",
        sprintf(paste0("database '%s' already exists; df and df_name ",
                       "are used only when creating it"), db_name))
    }
    tables <- if (create) duckdf_resolve_tables(query, df, df_name, env) else list()
  }

  result <- with_disk_con(db_name, function(con) {
    if (create) {
      for (name in names(tables)) {
        DBI::dbWriteTable(con, name, tables[[name]])
      }
    }
    if (is.null(params)) DBI::dbGetQuery(con, query)
    else DBI::dbGetQuery(con, query, params = params)
  })
  duckdf_coerce_result(result, as.data.table)
}
