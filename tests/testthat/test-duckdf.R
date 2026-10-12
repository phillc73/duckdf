# duckdf() contract (spec-api-contract.md)

test_that("duckdf returns a plain data.frame by default", {
  res <- duckdf("SELECT cyl, COUNT(*) AS n FROM cars_df GROUP BY cyl",
                df = list(cars_df = data.frame(cyl = c(4, 4, 6),
                                               mpg = c(22, 25, 18))))
  expect_s3_class(res, "data.frame")
  expect_false(inherits(res, "data.table"))
  expect_equal(nrow(res), 2)
})

test_that("as.data.table = TRUE returns a data.table", {
  res <- duckdf("SELECT * FROM cars_df",
                df = list(cars_df = data.frame(x = 1:2)),
                as.data.table = TRUE)
  expect_s3_class(res, "data.table")
})

test_that("df list form works inside a function, no caller-frame tie", {
  helper <- function() {
    duckdf("SELECT SUM(x) AS total FROM inner_df",
           df = list(inner_df = data.frame(x = 1:4)))
  }
  expect_equal(helper()$total, 10)
})

test_that("df_name registers verbatim, extractor not invoked", {
  mtc_local <- data.frame(wt = c(2.5, 3.1), gear = c(4, 3))
  res <- duckdf("SELECT gear FROM mtc_local WHERE wt > 3",
                df_name = "mtc_local")
  expect_equal(res$gear, 3)
})

test_that("caller-frame dataframes are found without df or df_name", {
  frame_df <- data.frame(a = 1:3, b = c("p", "q", "r"))
  res <- duckdf("SELECT a FROM frame_df WHERE b = 'q'")
  expect_equal(res$a, 2)
})

test_that("params pass through with ? and $1 placeholders", {
  d <- data.frame(x = 1:5)
  q1 <- duckdf("SELECT x FROM d WHERE x = ?", df = list(d = d),
               params = list(3))
  expect_equal(q1$x, 3)
  q2 <- duckdf("SELECT x FROM d WHERE x > $1 AND x < $2", df = list(d = d),
               params = list(2, 5))
  expect_equal(q2$x, c(3, 4))
})

test_that("file paths pass through, never registered", {
  csv <- file.path(tempdir(), "duckdf_pass.csv")
  on.exit(unlink(csv), add = TRUE)
  write.csv(data.frame(x = 1:3, y = c("a", "b", "c")), csv, row.names = FALSE)
  res <- duckdf(sprintf("SELECT COUNT(*) AS n FROM read_csv_auto('%s')", csv))
  expect_equal(res$n, 3)
  expect_equal(nrow(duckdf_views()), 0)
})

test_that("persist = TRUE delegates to the on-disk path", {
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "del_test",
                           paste0("del_test", c(".wal", ".tmp"))),
                 recursive = TRUE, force = TRUE), add = TRUE)
  withr::with_dir(dir, {
    res <- duckdf("SELECT COUNT(*) AS n FROM dd_df", persist = TRUE,
                  db_name = "del_test", df = list(dd_df = data.frame(x = 1:3)))
    expect_equal(res$n, 3)
    expect_true(file.exists(file.path(dir, "del_test")))
  })
})

test_that("missing object in scope is missing_object_error", {
  expect_error(duckdf("SELECT * FROM absolutely_missing_df"),
               regexp = "absolutely_missing_df",
               class = "missing_object_error")
})

test_that("input errors precede any connection work", {
  duckdf:::duckdf_shutdown()
  expect_error(duckdf(query = 123), class = "input_error")
  expect_error(duckdf("SELECT 1", as.data.table = "yes"), class = "input_error")
  expect_null(duckdf:::.duckdf$con)
})

test_that("a failing query leaves no dangling view, connection reusable", {
  d <- data.frame(x = 1)
  expect_error(
    duckdf("SELECT * FROM d WHERE no_such_col", df = list(d = d)),
    regexp = "no_such_col"
  )
  con <- duckdf:::duckdf_con()
  expect_true(DBI::dbIsValid(con))
  expect_equal(nrow(duckdf_views()), 0)
  expect_equal(duckdf("SELECT 1 AS ok")$ok, 1)
})
