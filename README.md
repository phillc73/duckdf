🦆 Ducks all the way down
=======

This is a convenience package for everyone who has a deep and abiding love affair with SQL (and ducks).

Instead of using other incredibly popular and useful packages like [data.table](https://rdatatable.gitlab.io/data.table/) or [dplyr](https://dplyr.tidyverse.org/), one could use `duckdf` instead to slice and dice dataframes with SQL. Precedence exists in the [sqldf](https://github.com/ggrothendieck/sqldf) package, but this one is better because it quacks (although is not nearly as comprehensive, well planned or tested).

It's also meant to be a bit of fun.

## Quick Start

To install this package, first install the very experimental [duckdb](https://github.com/cwida/duckdb):

```r
install.packages("duckdb", 
                        repos=c("http://download.duckdb.org/alias/master/rstats/", 
                        "http://cran.rstudio.com"))
```

Then install install `duckdf` with `devtools`

```r
# install.packages("devtools")
devtools::install_github("phillc73/duckdf")
library("duckdf")
```

## Usage

Write "normal" SQL in an R function:

```r
duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
```

This creates a single-use in-memory `duckdb` database from the well known `mtcars` dataset, then selects just the columns `mpg` and `cyl`, where the `disp` column is greater than 200.

In reality, this function is just a simple wrapper around a collection of `DBI` functions, such as `dbConnect()`, `dbWriteTable()`, `dbGetQuery()` and `dbDisconnect()`

```r
duckdf_persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200")
```
The above is obviously the same SQL statement, however by using `duckdf_persist()` an on-disk `duckdb` database is created in the current working directory. If you intend to use the same dataset multiple times, this is the way to go. After the first SQL statement, where the persistent database is created, subsequent SQL statements will be much quicker, as the original dataframe does not need to be copied to a `duckdb`.

```r
duckdf_cleanup("mtcars")
```
This simply removes all traces of the `duckdb` called `mtcars` from the current working directory.

## Benchmarks

Is this package any good? If some measure of good is the speed at which results are returned, then this package is reasonably good.

The benchmarks below are on a quite old, first generation i7 laptop. If you try these numbers yourself, the results will differ but the general themes should remain the same.

The current `duckdf` SELECT functions have been vaguely tested against other popular approaches including `data.table`, `dplyr` and `sqldf`.

`duckdf()` is significantly faster than `sqldf`, about as fast as `dbplyr`, even allowing for a dbplyr database connection setup in advance, not as fast as `dplyr` and much, much slower than `data.table`.

`duckdf_persist()` is faster than `duckdf()`, after the first run, as the dataframe does not need to be written to a new database every iteration.

If the `duckdf` functions were written in such a way that the `duckdb` database connections weren't closed, the results would be returned even faster, but this results in a pond full of warning messages.

```r
library(duckdf)
library(dplyr)
library(microbenchmark)
library(sqldf)
library(data.table)
library(ggplot2)

# Make a data.table
mtcars_data_table <- data.table(mtcars)

# dbplyr db prep
dsrc <- duckdb::src_duckdb()
mtcars_db <-
  copy_to(dsrc, mtcars, "mtcars", temporary = FALSE)

# Run the benchmark as often as you like
duck_bench <- microbenchmark(times=500,
                             sqldf_out <- sqldf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             duckdf_out <- duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             duckdf_out_pers <- duckdf_persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             dplyr_out <- mtcars %>%
                               dplyr::filter(disp >= 200) %>%
                               dplyr::select(mpg,cyl),
                             data_table_out <- mtcars_data_table[disp >= 200, c("mpg", "cyl"),],
                             mtcars_db <- tbl(dsrc, "mtcars") %>%
                               dplyr::filter(disp >= 200) %>%
                               dplyr::select(mpg,cyl)
                            )

autoplot(duck_bench)

```

<img align="center" src="duckdf_benchmarks.png" height="522">

Of course there are lies, damn lies and benchmarks. Different datasets, of different size or different column types, may produce entirely different results.

