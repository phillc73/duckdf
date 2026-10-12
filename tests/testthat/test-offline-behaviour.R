# CR-001 Track A (option A): offline behaviour of the df-list and
# persist paths when the json extension is unavailable. The cache is
# forced FALSE to simulate a CRAN check farm on a machine where the
# extension is cached (tests must pass in both worlds).

force_offline <- function() {
  # simulate the probe result without triggering a download attempt;
  # environment(duckdf) is the package namespace (the duckdf symbol
  # resolves to the exported function in test contexts)
  cache <- environment(duckdf)$.duckdf
  old <- cache$json_available
  cache$json_available <- FALSE
  function() cache$json_available <- old
}

test_that("serialize_unavailable_error carries the offline install hint", {
  if (!isClass("nojson_con")) {
    setClass("nojson_con", contains = "DBIConnection")
    setMethod(DBI::dbGetQuery,
      signature(conn = "nojson_con", statement = "character"),
      function(conn, statement, ...) {
        stop("json extension not installed")
      })
  }
  nojson <- new("nojson_con")
  expect_error(duckdf:::table_refs("SELECT * FROM df1", nojson,
                                   c("df1")),
               regexp = "extensions.duckdb.org",
               class = "serialize_unavailable_error")
  expect_error(duckdf:::table_refs("SELECT * FROM df1", nojson,
                                   c("df1")),
               regexp = "advanced_installation_methods",
               class = "serialize_unavailable_error")
})

test_that("offline duckdf df-list form works (validation skipped)", {
  restore <- force_offline()
  on.exit(restore(), add = TRUE)
  d <- data.frame(x = 1:3)
  res <- duckdf("SELECT SUM(x) AS s FROM d", df = list(d = d))
  expect_equal(res$s, 6)
})

test_that("offline out-of-scope df-list names error engine-side", {
  restore <- force_offline()
  on.exit(restore(), add = TRUE)
  df1 <- data.frame(x = 1:3)
  err <- tryCatch(
    duckdf("SELECT * FROM df1 JOIN outsider ON 1 = 1",
           df = list(df1 = df1)),
    error = function(e) e)
  expect_s3_class(err, "error")
  expect_false(inherits(err, "missing_object_error"))
})

test_that("offline persist with db_name and df list works", {
  restore <- force_offline()
  on.exit(restore(), add = TRUE)
  dir <- tempdir()
  on.exit(unlink(file.path(dir, "off_test.duckdb"), force = TRUE),
          add = TRUE)
  withr::with_dir(dir, {
    res <- persist("SELECT SUM(x) AS s FROM d",
                   db_name = "off_test.duckdb",
                   df = list(d = data.frame(x = 1:3)))
    expect_equal(res$s, 6)
    expect_true(file.exists("off_test.duckdb"))
  })
})

test_that("offline persist derives db_name from the first df-list name", {
  restore <- force_offline()
  on.exit(restore(), add = TRUE)
  dir <- tempdir()
  withr::with_dir(dir, {
    res <- persist("SELECT SUM(x) AS s FROM first_df JOIN second_df USING (x)",
                   df = list(first_df = data.frame(x = 1:3),
                             second_df = data.frame(x = 1:3)))
    expect_equal(res$s, 6)
    expect_true(file.exists("first_df"))
    on.exit(unlink(c("first_df", "first_df.wal", "first_df.tmp"),
                   force = TRUE), add = TRUE)
  })
})

test_that("offline persist with no tables demands db_name explicitly", {
  restore <- force_offline()
  on.exit(restore(), add = TRUE)
  withr::with_dir(tempdir(), {
    expect_error(persist("SELECT SUM(x) AS s FROM nowhere_df", df = list()),
                 regexp = "pass db_name explicitly",
                 class = "input_error")
  })
})
