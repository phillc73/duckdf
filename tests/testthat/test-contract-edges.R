# Contract-edge tests: engine passthrough, escape hatches and guards

# Non-collision registration failures keep their engine error; the
# collision check runs only on the error path
test_that("non-collision register failures stay engine errors", {
  df_bad <- data.frame(x = 1:2)
  df_bad$cc <- list(complex(1, 2), complex(3, 4))
  expect_error(
    duckdf:::duckdf_register_view(duckdf:::duckdf_con(), "bad_df", df_bad),
    class = "duckdb_error")
  views <- DBI::dbGetQuery(duckdf:::duckdf_con(),
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  expect_false("bad_df" %in% views$view_name)
})

# Multi-statement queries are rejected, not silent last-wins
test_that("multi-statement queries are input_error", {
  skip_if_not(duckdf:::duckdf_json_available())
  mtcars <- datasets::mtcars
  expect_error(
    duckdf("SELECT COUNT(*) AS n FROM mtcars; SELECT COUNT(*) AS n2 FROM mtcars"),
    regexp = "single statement",
    class = "input_error")
  expect_error(
    persist("SELECT COUNT(*) AS n FROM mtcars; SELECT 1 AS one"),
    regexp = "single statement",
    class = "input_error")
})

# Non-SELECT via the extractor is parse_error with a message
# directing to df_name, not a false "could not parse"
test_that("non-SELECT queries direct to df_name, no false parse claim", {
  skip_if_not(duckdf:::duckdf_json_available())
  expect_error(
    duckdf("CREATE TABLE zz_tri AS SELECT 1 AS a"),
    regexp = "Only SELECT.*df_name",
    class = "parse_error")
})

# The df_name bypass keeps raw DBI semantics - multi-statement runs
# there (documented escape hatch)
test_that("df_name bypass retains multi-statement raw behaviour", {
  df1 <- data.frame(x = 1:3)
  res <- duckdf("SELECT COUNT(*) AS n FROM df1; SELECT COUNT(*) AS n2 FROM df1",
                df_name = "df1")
  expect_equal(res$n2, 3)
})

# Table names containing a double quote do not break gander
test_that("gander survives quote-bearing table names", {
  path <- file.path(tempdir(), "quote_test.duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal"), paste0(path, ".tmp"))),
          add = TRUE)
  duckdf:::with_disk_con(path, function(con) {
    DBI::dbExecute(con, 'CREATE TABLE "we""ird" (x INTEGER)')
    DBI::dbExecute(con, "INSERT INTO \"we\"\"ird\" VALUES (1), (2)")
  })
  res <- gander(path)
  expect_equal(nrow(res[["we\"ird"]]), 2)
})

# persist onto an existing database with df/df_name given is an
# error, not a silent data-source switch
test_that("persist existing db plus df is input_error", {
  path <- file.path(tempdir(), "exists_test.duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal"), paste0(path, ".tmp"))),
          add = TRUE)
  duckdf:::with_disk_con(path, function(con) {
    DBI::dbWriteTable(con, "mtcars", datasets::mtcars)
  })
  expect_error(
    persist("SELECT COUNT(*) AS n FROM mtcars", db_name = path,
            df = list(mtcars = head(datasets::mtcars, 5))),
    regexp = "already exists",
    class = "input_error")
})

# gander opens on-disk databases read-only
test_that("read-only disk connections refuse writes", {
  path <- file.path(tempdir(), "ro_test.duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal"), paste0(path, ".tmp"))),
          add = TRUE)
  duckdf:::with_disk_con(path, function(con) {
    DBI::dbWriteTable(con, "t", data.frame(x = 1))
  })
  duckdf:::with_disk_con(path, function(con) {
    expect_error(DBI::dbExecute(con, "INSERT INTO t VALUES (2)"))
  }, read_only = TRUE)
  expect_equal(nrow(gander(path)$t), 1)
})
