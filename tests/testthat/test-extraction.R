# Table extraction, one test per spec rule
# (spec-table-extraction.md test mirror obligations)

con <- duckdf:::duckdf_con()
cands <- c("df1", "df2", "df3", "my df")

# FROM
test_that("a simple FROM extracts the dataframe name", {
  res <- duckdf:::table_refs("SELECT a FROM df1", con, cands)
  expect_identical(as.vector(res), "df1")
  expect_identical(attr(res, "file_paths"), character(0))
})

# JOIN
test_that("a JOIN extracts both sides in order", {
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM df1 JOIN df2 ON df1.x = df2.x",
                        con, cands)),
    c("df1", "df2"))
})

# multiple JOINs
test_that("multiple JOINs extract all three sides in order", {
  expect_identical(as.vector(
    duckdf:::table_refs(paste0(
      "SELECT * FROM df1 JOIN df2 ON df1.x = df2.x ",
      "JOIN df3 ON df2.x = df3.x"), con, cands)),
    c("df1", "df2", "df3"))
})

# subquery, issue #3 case: the inner dataframe must register
test_that("a subquery extracts the inner dataframe, not the alias", {
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM (SELECT x FROM df1) sub", con, cands)),
    "df1")
})

# CTE: the CTE name is dropped, the CTE body's dataframe registers
test_that("a CTE registers the body dataframe and drops the CTE name", {
  expect_identical(as.vector(
    duckdf:::table_refs(
      "WITH c AS (SELECT x FROM df1) SELECT * FROM c", con, cands)),
    "df1")
})

# quoted identifier
test_that("a quoted identifier is extracted verbatim", {
  expect_identical(as.vector(
    duckdf:::table_refs('SELECT * FROM "my df"', con, cands)),
    "my df")
})

# string literal containing FROM must not become a reference
test_that("a string literal containing FROM is not extracted", {
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM df1 WHERE y = 'FROM df2'", con, cands)),
    "df1")
})

# duplicates: order of first appearance, deduplicated
test_that("duplicate names deduplicate, order stable", {
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM df2 JOIN df1 ON df2.x = df1.x",
                        con, cands)),
    c("df2", "df1"))
  expect_identical(as.vector(
    duckdf:::table_refs(
      "SELECT * FROM df1 a JOIN df1 b ON a.x = b.x", con, cands)),
    "df1")
})

# file paths: csv, parquet, glob - recorded, not registered
test_that("file paths are recorded, not registered", {
  res <- duckdf:::table_refs(
    "SELECT * FROM 'data/f.csv'", con, cands)
  expect_identical(as.vector(res), character(0))
  expect_identical(attr(res, "file_paths"), "data/f.csv")
  res <- duckdf:::table_refs(
    "SELECT * FROM read_parquet('data/*.parquet')", con, cands)
  expect_identical(as.vector(res), character(0))
  res <- duckdf:::table_refs(
    "SELECT * FROM read_csv_auto('data/*.csv')", con, cands)
  expect_identical(as.vector(res), character(0))
  expect_identical(attr(res, "file_paths"), "data/*.csv")
})

# params passthrough: placeholders do not disturb extraction
test_that("placeholders in the query do not disturb extraction", {
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM df1 WHERE x = ? AND y = $1",
                        con, cands)),
    "df1")
})

# input_error: empty or whitespace-only query, before connection work
test_that("empty query is an input_error", {
  expect_error(duckdf:::table_refs("", con, cands),
               regexp = "empty", class = "input_error")
  expect_error(duckdf:::table_refs("   ", con, cands),
               regexp = "empty", class = "input_error")
})

# parse_error: DuckDB's message passed through, no guessing layer
test_that("an unparseable query is a parse_error naming the failure", {
  expect_error(duckdf:::table_refs("SELECT FROM FROM", con, cands),
               regexp = "syntax error", class = "parse_error")
})

# missing_object_error: extracted name unresolvable in the candidates
test_that("unresolvable names are a missing_object_error with the hint", {
  expect_error(
    duckdf:::table_refs("SELECT * FROM df1 JOIN nope ON df1.x = nope.x",
                        con, cands),
    regexp = "nope.*df_name or df", class = "missing_object_error")
})

# serialize_unavailable_error: mock connection without json_serialize_sql
# (no regex fallback - the error directs to df_name/df)
test_that("unavailable json_serialize_sql directs to df_name/df", {
  if (!isClass("nojson_con")) {
    setClass("nojson_con", contains = "DBIConnection")
    setMethod(DBI::dbGetQuery,
      signature(conn = "nojson_con", statement = "character"),
      function(conn, statement, ...) {
        stop("json extension not installed")
      })
  }
  nojson <- new("nojson_con")
  expect_error(duckdf:::table_refs("SELECT * FROM df1", nojson, cands),
               regexp = "df_name or df",
               class = "serialize_unavailable_error")
})

# df-list form: candidates from the named list register under list
# names (the duckdf()-level bypass test lands with Slice 3)
test_that("df-list candidate names extract like any other names", {
  dfs <- list(iris_df = iris, mtcars_df = mtcars)
  expect_identical(as.vector(
    duckdf:::table_refs("SELECT * FROM iris_df JOIN mtcars_df ON 1 = 1",
                        con, names(dfs))),
    c("iris_df", "mtcars_df"))
})

# purity: no side effects on the passed-in connection
test_that("table_refs does not open, close or mutate the connection", {
  views_before <- DBI::dbGetQuery(con,
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  res <- duckdf:::table_refs("SELECT * FROM df1", con, cands)
  expect_true(DBI::dbIsValid(con))
  views_after <- DBI::dbGetQuery(con,
    "SELECT view_name FROM duckdb_views() WHERE NOT internal")
  expect_identical(views_before, views_after)
  expect_identical(as.vector(res), "df1")
})
