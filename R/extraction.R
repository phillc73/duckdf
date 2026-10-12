# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# Table extraction via the DuckDB parse tree (json_serialize_sql AST
# walk) - spec-table-extraction.md; README covers the user-facing
# story. No regex fallback: extraction failure is an error pointing at
# df_name/df.

# DuckDB parse tree as JSON. The probe separates "engine without
# json_serialize_sql" from "query will not parse": the SQL function
# returns {"error":true,...} JSON for parse failures but errors itself
# when the json machinery is missing.
duckdf_serialize_sql <- function(con, query) {
  probe <- tryCatch(
    DBI::dbGetQuery(con,
      "SELECT json_serialize_sql(CAST(? AS VARCHAR)) AS j",
      params = list("SELECT 1")),
    error = function(e) e)
  if (inherits(probe, "error")) {
    duckdf_stop("serialize_unavailable_error",
      paste0("json_serialize_sql is unavailable in the linked DuckDB (",
             conditionMessage(probe), "); pass df_name or df explicitly"))
  }
  ast <- tryCatch(
    DBI::dbGetQuery(con,
      "SELECT json_serialize_sql(CAST(? AS VARCHAR)) AS j",
      params = list(query)),
    error = function(e) {
      duckdf_stop("parse_error",
        paste0("DuckDB could not parse the query: ", conditionMessage(e)))
    })
  tree <- jsonlite::fromJSON(ast$j, simplifyVector = FALSE)
  if (isTRUE(tree$error)) {
    duckdf_stop("parse_error",
      paste0("DuckDB could not parse the query: ", tree$error_message))
  }
  tree$statements
}

# BASE_TABLE names (order of first appearance) and CTE keys from the
# serialized statements; generic recursion covers joins, subqueries,
# CTE bodies and table-function arguments
duckdf_ast_tables <- function(statements) {
  refs <- character(0)
  ctes <- character(0)
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
    for (part in x) {
      if (is.list(part)) {
        walk(part)
      }
    }
  }
  for (statement in statements) {
    walk(statement)
  }
  list(refs = refs, ctes = ctes)
}

# A name DuckDB reads natively from disk: csv/parquet suffix or glob
# metacharacters (spec-table-extraction.md mechanism 3)
duckdf_is_file_path <- function(name) {
  grepl("\\.(csv|parquet)$", name, ignore.case = TRUE) ||
    grepl("[*?\\[\\]]", name)
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
  paths <- character(0)
  missing <- character(0)
  keep <- character(0)
  for (name in ast$refs) {
    if (name %in% keep || name %in% paths) {
      next
    }
    if (duckdf_is_file_path(name)) {
      paths <- c(paths, name)
    } else if (name %in% candidates) {
      keep <- c(keep, name)
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
  structure(keep, file_paths = paths)
}
