# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# duckdf() and duckdf_views(): the query surface on the shared
# connection - spec-api-contract.md; README covers the user-facing
# story. duckdf() never opens or closes a connection: lifecycle.R owns
# that.

# Registration candidates from the caller's frame: objects
# duckdb_register() accepts (data.frame, data.table, tibble)
duckdf_frame_candidates <- function(env) {
  names <- ls(envir = env)
  ok <- vapply(names, function(n) {
    obj <- tryCatch(get(n, envir = env), error = function(e) NULL)
    !is.null(obj) && is.data.frame(obj)
  }, logical(1))
  names[ok]
}

# Return-class helper: data.table is Suggests, absence is package_error
# with an install hint (spec-api-contract.md cross-cutting)
duckdf_coerce_result <- function(result, as.data.table) {
  if (!isTRUE(as.data.table)) {
    return(result)
  }
  if (!requireNamespace("data.table", quietly = TRUE)) {
    duckdf_stop("package_error",
      paste0("data.table is required for as.data.table = TRUE; ",
             "install it with install.packages('data.table')"))
  }
  data.table::as.data.table(result)
}

#' Query your dataframes with SQL
#'
#' \code{duckdf} runs a SQL query against R dataframes registered as
#'   zero-copy DuckDB views. Like SQL? Like dataframes? Like ducks?
#'
#' @param query String. The SQL query. Required.
#' @param persist Logical. If TRUE, delegate to \code{persist()} for an
#'   on-disk database (see that function).
#' @param df_name Character vector of variable names holding
#'   dataframes - registered verbatim, the extractor is not invoked.
#' @param df Named list of dataframes - registered under their list
#'   names; those names are the extraction candidate scope. Preferred
#'   form inside functions: no caller-frame dependency.
#' @param params Parameter list forwarded to \code{DBI::dbGetQuery()}
#'   untouched; use DuckDB \code{?}/\code{$1} placeholders in the query.
#' @param db_name String. On-disk database name for the persist path.
#' @param as.data.table Logical. Return a data.table instead of a plain
#'   data.frame.
#'
#' @return The query result: data.frame by default, data.table when
#'   \code{as.data.table = TRUE}.
#'
#' @examples
#' \dontrun{
#'
#' # Query the mtcars dataframe
#' duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
#'
#' # Parameterised, function-safe form
#' cyl_query <- function(x) {
#'   duckdf("SELECT mpg FROM mtcars WHERE cyl = $1", df = list(mtcars = mtcars),
#'          params = list(x))
#' }
#'
#' # Read a csv without registering anything - DuckDB reads it natively
#' duckdf("SELECT * FROM read_csv_auto('myfile.csv')")
#'
#' }
#'
#' @export
#'

duckdf <- function(query, persist = FALSE, df_name = NULL, df = NULL,
                   params = NULL, db_name = NULL, as.data.table = FALSE) {
  # validation before any connection work (taxonomy order)
  assert_input(checkmate::assert_string(query, .var.name = "query"))
  if (trimws(query) == "") {
    duckdf_stop("input_error", "query must not be empty")
  }
  assert_input(checkmate::assert_flag(persist, .var.name = "persist"))
  assert_input(checkmate::assert_character(df_name, any.missing = FALSE,
    min.chars = 1, unique = TRUE, null.ok = TRUE, .var.name = "df_name"))
  assert_input(checkmate::assert_list(df, types = "data.frame",
    names = "unique", null.ok = TRUE, .var.name = "df"))
  assert_input(checkmate::assert_list(params, null.ok = TRUE,
    .var.name = "params"))
  assert_input(checkmate::assert_string(db_name, null.ok = TRUE,
    .var.name = "db_name"))
  assert_input(checkmate::assert_flag(as.data.table,
    .var.name = "as.data.table"))
  if (isTRUE(as.data.table) && !requireNamespace("data.table", quietly = TRUE)) {
    duckdf_stop("package_error",
      paste0("data.table is required for as.data.table = TRUE; ",
             "install it with install.packages('data.table')"))
  }

  if (isTRUE(persist)) {
    duckdf_stop("package_error",
      "persist() lands in Slice 4; the on-disk path is not available yet")
  }

  env <- parent.frame()
  dfs <- list()
  if (!is.null(df)) {
    dfs <- c(dfs, df)
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
    dfs <- c(dfs, setNames(resolved, df_name))
  }
  if (is.null(df) && is.null(df_name)) {
    con <- duckdf_con()
    refs <- table_refs(query, con, duckdf_frame_candidates(env))
    dfs <- setNames(lapply(refs, function(n) get(n, envir = env)), refs)
  }

  con <- duckdf_con()
  result <- with_registered_views(dfs, if (is.null(params)) {
    DBI::dbGetQuery(con, query)
  } else {
    DBI::dbGetQuery(con, query, params = params)
  })
  duckdf_coerce_result(result, as.data.table)
}
