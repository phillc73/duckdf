# Lifecycle rules 1-8, one test each (spec-lifecycle-and-errors.md)

# Rule 1: lazy creation on first use
test_that("shared connection opens lazily", {
  duckdf:::duckdf_shutdown()
  expect_null(duckdf:::.duckdf$con)
  con <- duckdf:::duckdf_con()
  expect_s4_class(con, "DBIConnection")
  expect_true(DBI::dbIsValid(con))
})

# Rule 3: warm calls reuse the same connection
test_that("warm calls reuse the shared connection", {
  con1 <- duckdf:::duckdf_con()
  con2 <- duckdf:::duckdf_con()
  expect_identical(con1, con2)
})

# Rule 2: per-call registration, view gone after the call
test_that("views are unregistered after the call completes", {
  df <- data.frame(x = 1:3)
  res <- duckdf:::with_registered_views(
    list(life_df = df),
    DBI::dbGetQuery(duckdf:::duckdf_con(), "SELECT COUNT(*) AS n FROM life_df")
  )
  expect_equal(res$n, 3)
  views <- DBI::dbGetQuery(duckdf:::duckdf_con(),
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  expect_false("life_df" %in% views$view_name)
})

# Rule 4: cleanup() closes and shuts down; next call reopens lazily
test_that("cleanup closes the shared connection which reopens lazily", {
  con1 <- duckdf:::duckdf_con()
  cleanup("nonexistent_db_for_rule4")
  expect_null(duckdf:::.duckdf$con)
  con2 <- duckdf:::duckdf_con()
  expect_false(identical(con1, con2))
  expect_true(DBI::dbIsValid(con2))
})

# Rule 5: finalizer registered once and shuts the driver down
test_that("GC finalizer is registered and shuts the driver down", {
  duckdf:::duckdf_con()
  expect_true(isTRUE(duckdf:::.duckdf$finalizer_registered))
  duckdf:::duckdf_shutdown()
  expect_null(duckdf:::.duckdf$con)
  con <- duckdf:::duckdf_con()
  expect_true(DBI::dbIsValid(con))
})

# Rule 6: on-disk paths use a dedicated connection, closed on exit
test_that("on-disk connections are dedicated and shut down", {
  path <- file.path(tempdir(), "rule6_test.duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal"), paste0(path, ".tmp"))),
          add = TRUE)
  duckdf:::with_disk_con(
    path,
    function(con) {
      expect_false(identical(con, duckdf:::duckdf_con()))
      DBI::dbExecute(con, "CREATE TABLE t (x INTEGER)")
    }
  )
  expect_true(file.exists(path))
  expect_false(file.exists(paste0(path, ".wal")))
  expect_s4_class(duckdf:::duckdf_con(), "DBIConnection")
})

# Rule 7: errors leave no dangling view; connection survives
test_that("errors unregister views and keep the connection usable", {
  df <- data.frame(x = 1:3)
  expect_error(
    duckdf:::with_registered_views(
      list(err_df = df),
      DBI::dbGetQuery(duckdf:::duckdf_con(), "SELECT * FROM err_df WHERE nope")
    ),
    regexp = "nope"
  )
  con <- duckdf:::duckdf_con()
  expect_true(DBI::dbIsValid(con))
  views <- DBI::dbGetQuery(con,
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  expect_false("err_df" %in% views$view_name)
  expect_equal(DBI::dbGetQuery(con, "SELECT 1 AS ok")$ok, 1)
})

# Rule 8: registration collision errors, naming the view
test_that("registration collision errors with the colliding name", {
  con <- duckdf:::duckdf_con()
  duckdf:::duckdf_register_view(con, "collide_df", data.frame(x = 1))
  expect_error(
    duckdf:::with_registered_views(
      list(collide_df = data.frame(x = 2)),
      invisible(NULL)
    ),
    regexp = "collide_df",
    class = "collision_error"
  )
  duckdb::duckdb_unregister(con, "collide_df")
  views <- DBI::dbGetQuery(con,
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  expect_false("collide_df" %in% views$view_name)
})
