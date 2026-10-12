# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# Shared in-memory connection lifecycle - spec-lifecycle-and-errors.md
# rules 1-8; README covers the user-facing story.

.duckdf <- new.env(parent = emptyenv())

# Classed base-R error; taxonomy in spec-lifecycle-and-errors.md
duckdf_stop <- function(class, message) {
  err <- structure(class = c(class, "duckdf_error", "error", "condition"),
                   list(message = message))
  stop(err)
}

# checkmate failures are re-classed as input_error (taxonomy: before
# connection)
assert_input <- function(expr) {
  tryCatch(force(expr),
           error = function(e) duckdf_stop("input_error", conditionMessage(e)))
}

# Rules 1 + 3 + 5: lazy open of the shared :memory: connection, warm
# reuse, GC/session-end finalizer registered once
duckdf_con <- function() {
  if (is.null(.duckdf$con) || !DBI::dbIsValid(.duckdf$con)) {
    drv <- duckdb::duckdb()
    con <- DBI::dbConnect(drv, dbdir = ":memory:", read_only = FALSE)
    .duckdf$con <- con
    if (!isTRUE(.duckdf$finalizer_registered)) {
      reg.finalizer(.duckdf, function(e) duckdf_shutdown(e), onexit = TRUE)
      .duckdf$finalizer_registered <- TRUE
    }
  }
  .duckdf$con
}

# Rule 4: cleanup() and the finalizer both land here; the next call
# reopens lazily
duckdf_shutdown <- function(e = .duckdf) {
  con <- e$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    tryCatch(DBI::dbDisconnect(con, shutdown = TRUE), error = function(err) NULL)
  }
  e$con <- NULL
  invisible(NULL)
}

# Rule 8: a name already visible as a view is a collision error, not a
# silent overwrite (0.1.2 behaviour). The check runs only on the
# engine's own re-register error (a precheck round trip costs
# 1.21 ms per registration)
duckdf_register_view <- function(con, name, df) {
  tryCatch(duckdb::duckdb_register(con, name, df),
           error = function(e) {
             views <- tryCatch(
               DBI::dbGetQuery(con,
                 "SELECT view_name FROM duckdb_views() WHERE NOT internal"),
               error = function(pe) NULL)
             if (!is.null(views) && name %in% views$view_name) {
               duckdf_stop("collision_error",
                           sprintf(paste0("a view named '%s' is already ",
                                          "registered on the shared ",
                                          "connection; unregister or rename"),
                                   name))
             }
             stop(e)
           })
  .duckdf$classes[[name]] <- class(df)[1]
  invisible(name)
}

# Rules 2 + 7: per-call registration with guaranteed unregister on
# every exit path, success or error
with_registered_views <- function(dfs, expr) {
  con <- duckdf_con()
  registered <- character(0)
  on.exit({
    for (name in registered) {
      tryCatch(duckdb::duckdb_unregister(con, name), error = function(err) NULL)
      .duckdf$classes[[name]] <- NULL
    }
  }, add = TRUE)
  for (name in names(dfs)) {
    duckdf_register_view(con, name, dfs[[name]])
    registered <- c(registered, name)
  }
  force(expr)
}

# Rule 6: on-disk paths get a dedicated per-operation connection,
# disconnect-with-shutdown on every exit path (rule 7); the shared
# in-memory connection is never pointed at a file. Read-only for
# pure readers (gander never writes)
with_disk_con <- function(db_name, fn, read_only = FALSE) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_name,
                        read_only = read_only)
  on.exit({
    if (DBI::dbIsValid(con)) {
      tryCatch(DBI::dbDisconnect(con, shutdown = TRUE), error = function(err) NULL)
    }
  }, add = TRUE)
  fn(con)
}
