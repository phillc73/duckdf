Ducks all the way down
=======

This is a convenience package for everyone who has a deep and abiding love affair with SQL (and ducks).

Instead of using other incredibly popular and useful packages like [data.table](https://rdatatable.gitlab.io/data.table/) or [dplyr](https://dplyr.tidyverse.org/), one could use `duckdf` instead to slice and dice dataframes with SQL. Precedence exists in the [sqldf](https://github.com/ggrothendieck/sqldf) package, but this one is better because it quacks.

It's also meant to be a bit of fun.

## A note on ducks, and the tidyverse

`duckdf` has zero tidyverse dependencies. Not one. This is a specific, deliberate design choice, made playfully and with real affection for the tidyverse packages themselves, which are excellent at what they do. The frame is simple: some of us want SQL strings, an R dataframe in, an R dataframe out, and a dependency tree a duck could waddle across without getting tired. If your dependency tree has more branches than a wetland, that is fine, that is even good, but it is not this package. Because that's better for ducks.

The benchmark arms (dplyr, dbplyr, duckplyr) appear in `Suggests` only, so the comparisons below can be reproduced. They are never loaded by `duckdf` itself.

## Lineage

The idea is old: `sqldf` has been letting R users write SQL against dataframes since 2007, by copying everything into SQLite on every query. The original `duckdf` (v0.1.2, March 2021) took that idea and pointed it at DuckDB, registering dataframes as zero-copy views instead of copying them. It was fast, it quacked, and then life happened and it sat dormant while DuckDB grew enormously.

0.2.0 is the resurrection: the same five functions (`duckdf`, `gander`, `ingest`, `persist`, `cleanup`) plus a new sixth (`duckdf_views`), rebuilt for duckdb-r 1.5.6 and later. Table names now come from DuckDB's own parse tree rather than string splitting on the word FROM, which means subqueries, joins, CTEs and quoted identifiers all just work. There is a lot of new stuff in 0.1.2's old `duckdf` that has been superseded, which the triage of the old issues records, but the quack remains.

## Quick Start

R 4.2.0 or later, and [duckdb](https://duckdb.org/) 1.5.6 or later (the package pins `duckdb (>= 1.5.6)`):

```r
install.packages("duckdb")
```

Then install `duckdf` with the `remotes` package:

```r
# install.packages("remotes")
library("remotes")
remotes::install_github("phillc73/duckdf")
library("duckdf")
```

## Usage

Write "normal" SQL SELECT statements against existing dataframes:

```r
duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
```

This registers the well known `mtcars` dataset as a virtual table on the shared in-memory DuckDB connection, runs the query, unregisters the view and hands you a plain `data.frame`. The connection stays open between calls, so warm queries skip the setup. In reality this function is just a wrapper around a collection of `DBI` functions such as `dbGetQuery()` and the duckdb function `duckdb_register()`, but you do not have to manage any of them.

Table names in the query are found via DuckDB's own parse tree, filtered to dataframes visible in the calling scope. Anything DuckDB can read natively (CSV, Parquet, globs) passes straight through with no registration:

```r
# Read a csv without registering anything - DuckDB reads it natively
duckdf("SELECT * FROM read_csv_auto('myfile.csv')")
```

If you want to fly as fast as possible, name the dataframes explicitly:

```r
duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
       df_name = "mtcars")
```

`df_name` skips the extraction entirely and registers verbatim. Because of that it is also the escape hatch: multi-statement queries and DDL (`CREATE TABLE ...`) work here and nowhere else. Two caveats worth knowing: a table created this way stays on the shared connection, invisible to `duckdf_views()` (which lists registered views only), and only `cleanup()` clears it. Useful for a deliberate `CREATE OR REPLACE TABLE ... AS SELECT`, just tidy up afterwards.

Inside functions, or anywhere the caller's scope is not where your dataframes live, pass them as a named list - those names become the extraction scope, so nothing outside the list is registered:

```r
cyl_query <- function(x) {
  duckdf("SELECT mpg FROM mtcars WHERE cyl = $1",
         df = list(mtcars = mtcars),
         params = list(x))
}
```

`params` is forwarded untouched to `DBI::dbGetQuery()`, which is the SQL-injection-safe path; use DuckDB's `?` or `$1` placeholders in the query.

Multiple dataframes may be named, to support joins:

```r
duckdf(
  "SELECT origin, dest,
     COUNT(flight) AS num_flts,
     round(SUM(seats)) AS num_seats,
     round(AVG(arr_delay)) AS avg_delay
   FROM flights f LEFT OUTER JOIN planes p
     ON f.tailnum = p.tailnum
   WHERE distance BETWEEN 200 AND 300
     AND air_time IS NOT NULL
   GROUP BY origin, dest
   HAVING COUNT(flight) > 3000
   ORDER BY num_seats DESC, avg_delay ASC
   LIMIT 2",
  df = list(flights = flights, planes = planes))
```

(Unlike 0.1.2 there is no two-table cap; name two, name twenty, they are all zero-copy views.)

Want a `data.table` back? One argument:

```r
duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
       as.data.table = TRUE)
```

`data.table` stays in `Suggests`; if it is not installed the error tells you how to fix that rather than guessing.

### persist

```r
duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
       persist = TRUE)
```

Same SQL, but an on-disk DuckDB database is created in the current working directory, the queried dataframes are written into it as real tables, and the query runs against the file. The database's name defaults to the first table in the query; give it a different one with `db_name`. The function `duckdf::persist()` does the same directly:

```r
duckdf::persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
                db_name = "mt_cars")
```

If a database with that name already exists, the query simply runs against what is on disk - and passing `df`/`df_name` at the same time is an error naming the database, so your data source cannot silently switch underneath you. All tables are written before any query executes, and the connection is closed on every exit path, success or failure.

### gander

If you've already created a DuckDB database, or received one from the flock:

```r
duckdf::gander("mtcars")
duckdf::gander("mtcars", show_types = TRUE)
```

Returns a named list holding the first five rows of every table in the database; `show_types = TRUE` adds the column types. Any number of tables (0.1.2 capped at two, arbitrarily; that cap has flown away). A missing database is an error naming the path checked, not a message string pretending to be a result.

### ingest

In the spirit of R packages using obscure verbs to describe functions, in this package we have `duckdf::ingest()`:

```r
# CSV in, on-disk duckdb out
duckdf::ingest(name = "descriptive_name",
               files = "filename.csv")

# CSV in, data.table out, returned for capture
mtcars2 <- duckdf::ingest(name = "mtcars2",
                          files = "filename.csv",
                          persist = FALSE,
                          object_type = "data.table")
```

`ingest` passes every `duckdb_read_csv` option through unchanged (`header`, `na.strings`, `nrow.check`, `delim`, `quote`, `col.names`, `lower.case.names`, `sep`, `transaction`). With `persist = FALSE` it returns the data as `object_type` (`data.frame` by default, `data.table` or `tibble` also welcome) and assigns nothing anywhere - callers capture the return value. Two honest notes on the `persist = TRUE` path: it returns `duckdb_read_csv`'s own result invisibly (a side-effect function), and calling it again with the same `name` on the same existing database re-reads the CSV into the existing table - the rows add up, they do not replace. Remove the database first (`cleanup()`) for a fresh ingest. Also, `duckdb_read_csv` itself leaves an empty file named `duckdb` in the working directory; that is duckdb-r behaviour, not something `duckdf` can tidy.

### cleanup

Removes all traces of the named on-disk DuckDB database (the file plus any `.wal`/`.tmp` sidecars) from the current working directory, and closes the shared connection. Returns, invisibly, the vector of files it removed - missing files are not an error, so no quacking about it.

```r
duckdf::cleanup("mtcars")
```

### duckdf_views

```r
duckdf::duckdf_views()
```

A read-only listing of the views currently registered on the shared connection: the view name and the class of the backing R object. Empty (not an error) when nothing is registered. A pure listing call does open the shared connection if it was not open - an empty listing proves the connection exists.

## Benchmarks

Is this package any good? If some measure of good is the speed at which results are returned, then this package is reasonably good, with one honest asterisk.

The full harness lives in `bench/run_benchmarks.R` (seven arms, four fixed tasks, cold/warm split, memory recorded, results checked for equivalence before anything is timed) and its output article in `bench/results.md`. Warm medians, in milliseconds, from the single official run on a full-time Linux machine:

| arm | simple SELECT | filter + aggregate, 1M rows | join, 1M rows | window, 1M rows |
|---|---|---|---|---|
| duckdf 0.2.0 | 5.3 | 93 | 131 | 65 |
| raw duckdb-r (DBI) | 2.9 | 95 | 156 | 62 |
| sqldf (SQLite) | 30 | 802 | 1190 | 799 |
| data.table | 0.8 | 31 | 80 | 20 |
| dplyr (plain) | 2.5 | 35 | 116 | 31 |
| duckplyr | 4.5 | 80 | 236 | 58 |
| dbplyr + duckdb | 50 | 80 | 143 | 136 |

Reading it honestly:

- Against raw duckdb-r (the wrapper-overhead self-gate), duckdf is within the 1.10x band on the 1M-row tasks: 0.98x, 0.84x and 1.05x. On the trivial SELECT it is 1.82x - the extraction cost dominates a 2.9 ms call, and we state that failure plainly rather than hiding it. If you want to fly as fast as possible on tiny queries, use `df_name`.
- Against sqldf, duckdf is 5.7x to 12.2x faster warm, on every task. The gap lives in the model, not the warm-up: sqldf imports your dataframe into SQLite on every query.
- data.table remains much, much faster than everything on this table. In fact, if you'd like to query a `data.table` more slowly, `duckdf` can support that too - and with `as.data.table = TRUE` it will even hand the result back as one.
- Memory is where zero-copy registration shows: duckdf allocates about 1.8 KB per query on the 1M-row tasks, against data.table's 28-65 MB and dplyr's 43-109 MB of materialisation.

Of course there are lies, damn lies and benchmarks. Different datasets, of different size or different column types, using different queries, may produce entirely different results. The harness is in the package precisely so you can produce your own.

But wait, there's more: [older 2021 benchmarks](duckdf_benchmarks.png) (and the [tidyquery comparison](vs_tidyquery_benchmarks.png)) are kept in the repository as historical artifacts, from when duckdb was 0.2.4 and this package was a younger duck.

## AI assistance

The code in this repository was written with the assistance of a large language model and reviewed by its maintainer.

## License

AGPL-3. See `LICENSE`.
