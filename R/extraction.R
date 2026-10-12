# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# Table extraction via the DuckDB parse tree (json_serialize_sql AST
# walk) - spec-table-extraction.md; README covers the user-facing
# story. No regex fallback: extraction failure is an error pointing at
# df_name/df.

# DuckDB parse tree as JSON. Parse failures come back as
# {"error":true,...} JSON; the SQL call itself errors when the json
# machinery is missing - the probe (only run on that error path)
# separates serialize_unavailable from a genuine parse failure.
duckdf_serialize_sql <- function(con, query) {
  ast <- tryCatch(
    DBI::dbGetQuery(con,
      "SELECT json_serialize_sql(CAST(? AS VARCHAR)) AS j",
      params = list(query)),
    error = function(e) duckdf_classify_serialize_error(con, e))
  tree <- jsonlite::fromJSON(ast$j, simplifyVector = FALSE)
  if (isTRUE(tree$error)) {
    duckdf_stop("parse_error",
      paste0("DuckDB could not parse the query: ", tree$error_message))
  }
  tree$statements
}

# Error-path classifier: if a trivial query also fails to serialize,
# the engine lacks json_serialize_sql; otherwise the caller's query is
# the problem and DuckDB's message passes through unguessed
duckdf_classify_serialize_error <- function(con, e) {
  probe <- tryCatch(
    DBI::dbGetQuery(con,
      "SELECT json_serialize_sql(CAST(? AS VARCHAR)) AS j",
      params = list("SELECT 1")),
    error = function(pe) pe)
  if (inherits(probe, "error")) {
    duckdf_stop("serialize_unavailable_error",
      paste0("json_serialize_sql is unavailable in the linked DuckDB (",
             conditionMessage(probe), "); pass df_name or df explicitly"))
  }
  duckdf_stop("parse_error",
    paste0("DuckDB could not parse the query: ", conditionMessage(e)))
}

# BASE_TABLE names (order of first appearance) and CTE keys from the
# serialized statements; generic recursion covers joins, subqueries,
# CTE bodies and table-function arguments
duckdf_ast_tables <- function(statements) {
  refs <- character(0)
  ctes <- character(0)
  paths <- character(0)
  walk <- function(x) {
    if (!is.list(x)) {
      return(NULL)
    }
    if (identical(x$type, "BASE_TABLE") &&
        length(x$table_name) == 1L && nzchar(x$table_name)) {
      if (!(x$table_name %in% refs)) {
        refs <<- c(refs, x$table_name)
      }
      return(NULL)
    }
    cte_map <- x$cte_map
    if (is.list(cte_map) && !is.null(cte_map$map)) {
      for (entry in cte_map$map) {
        if (!is.null(entry$key) && !(entry$key %in% ctes)) {
          ctes <<- c(ctes, entry$key)
        }
      }
    }
    if (identical(x$type, "TABLE_FUNCTION")) {
      for (path in duckdf_func_paths(x)) {
        if (!(path %in% paths)) {
          paths <<- c(paths, path)
        }
      }
    }
    for (part in x) {
      if (is.list(part)) {
        walk(part)
      }
    }
  }
  for (statement in statements) {
    walk(statement)
  }
  list(refs = refs, ctes = ctes, paths = paths)
}

# A name DuckDB reads natively from disk: csv/parquet suffix or glob
# metacharacters (spec-table-extraction.md mechanism 3)
duckdf_is_file_path <- function(name) {
  grepl("\\.(csv|parquet)$", name, ignore.case = TRUE) ||
    grepl("[*?\\[\\]]", name)
}

# File arguments of table-function calls (read_csv_auto/read_parquet):
# constant strings anywhere under the call that look like file paths
duckdf_func_paths <- function(node) {
  out <- character(0)
  scan <- function(y) {
    if (is.list(y)) {
      for (part in y) {
        scan(part)
      }
    } else if (is.character(y) && length(y) == 1L &&
               duckdf_is_file_path(y) && !(y %in% out)) {
      out <<- c(out, y)
    }
  }
  scan(node)
  out
}

#' Candidate dataframe references in a SQL query
#'
#' Parses the query with DuckDB's own parser (json_serialize_sql),
#' walks the AST, and returns the table references that resolve to
#' dataframes in the candidate set - in order of first appearance,
#' deduplicated. File paths (csv, parquet, glob) are DuckDB-native
#' reads: recorded in the "file_paths" attribute, never registered.
#' Subquery aliases and CTE names are the engine's business. Pure
#' function: the connection is passed in, never opened or closed.
#'
#' @param query SQL query string.
#' @param con A DBI connection (the shared duckdf connection).
#' @param candidates Character vector of dataframe names visible to
#'   the caller (names of the \code{df} list, or the caller's frame).
#'
#' @return Character vector of dataframe names to register, with
#'   attribute "file_paths" listing pass-through file references.
#'
#' @keywords internal
#' @noRd
table_refs <- function(query, con, candidates = NULL) {
  assert_input(checkmate::assert_string(query, .var.name = "query"))
  if (trimws(query) == "") {
    duckdf_stop("input_error", "query must not be empty")
  }
  assert_input(checkmate::assert_class(con, "DBIConnection",
                                       .var.name = "con"))
  assert_input(checkmate::assert_character(candidates, any.missing = FALSE,
    null.ok = TRUE, .var.name = "candidates"))
  ast <- duckdf_ast_tables(duckdf_serialize_sql(con, query))
  missing <- character(0)
  keep <- character(0)
  for (name in ast$refs) {
    if (name %in% keep || name %in% ast$paths) {
      next
    }
    if (name %in% candidates) {
      keep <- c(keep, name)
    } else if (duckdf_is_file_path(name)) {
      ast$paths <- c(ast$paths, name)
    } else if (!(name %in% ast$ctes)) {
      missing <- c(missing, name)
    }
  }
  if (length(missing) > 0) {
    duckdf_stop("missing_object_error",
      sprintf(paste0("object(s) %s not found in the dataframe scope; ",
                     "pass them via df_name or df"),
              paste0("'", missing, "'", collapse = ", ")))
  }
  structure(keep, file_paths = ast$paths)
}
