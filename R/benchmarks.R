library(dplyr)
library(microbenchmark)
library(sqldf)
library(data.table)
library(ggplot2)

# Load the package or at least the functions in duckdf first

# Make a data.table
mtcars_data_table <- data.table(mtcars)

# dplyr db prep
dsrc <- duckdb::src_duckdb()
mtcars_db <-
  copy_to(dsrc, mtcars, "mtcars", temporary = FALSE)


duck_bench <- microbenchmark(times=50,
                             sqldf_out <- sqldf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             duckdf_out <- duckdf("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             duckdf_out_persist <- duckdf_persist("SELECT mpg, cyl FROM mtcars WHERE disp >= 200"),
                             dplyr_out <- mtcars %>%
                               dplyr::filter(disp >= 200) %>%
                               dplyr::select(mpg,cyl),
                             data_table_out <- mtcars_data_table[disp >= 200, c("mpg", "cyl"),],
                             duckdf_dt_out <- duckdf("SELECT mpg, cyl FROM mtcars_data_table WHERE disp >= 200"),
                             sqldf_dt_out <- sqldf("SELECT mpg, cyl FROM mtcars_data_table WHERE disp >= 200"),
                             mtcars_db <- tbl(dsrc, "mtcars") %>%
                               dplyr::filter(disp >= 200) %>%
                               dplyr::select(mpg,cyl)
)

autoplot(duck_bench)
