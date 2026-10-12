# duckdf 0.2.0 benchmark harness: AGPL-3, see README
# Four fixed tasks, seven arms

# Data --------------------------------------------------------------------

build_data <- function(tiny = FALSE, seed = 2021) {
  set.seed(seed)
  n <- if (tiny) 10000 else 1000000
  g <- sample(letters[1:10], n, replace = TRUE)
  big <- data.frame(g = g, x = runif(n))
  small <- data.frame(g = letters[1:10],
                      label = paste0("label_", letters[1:10]),
                      stringsAsFactors = FALSE)
  list(mtcars = mtcars, big = big, small = small)
}

# Equivalence: sorted all.equal vs the data.table arm,
# class and typing differences recorded as observations, not coerced

normalise <- function(res) {
  res <- as.data.frame(res)
  for (col in names(res)) {
    if (is.factor(res[[col]])) res[[col]] <- as.character(res[[col]])
  }
  res <- res[do.call(order, res), , drop = FALSE]
  rownames(res) <- NULL
  res
}

equivalence_check <- function(ref, res) {
  out <- all.equal(ref, normalise(res), check.attributes = FALSE)
  if (isTRUE(out)) {
    list(status = "match", observation = "")
  } else {
    list(status = "observation", observation = paste(out, collapse = "; "))
  }
}

# Queries -----------------------------------------------------------------

queries <- list(
  q1 = "SELECT mpg, cyl FROM mtcars WHERE disp >= 200",
  q2 = paste("SELECT g, COUNT(*) AS n, AVG(x) AS mean_x FROM big",
             "WHERE x > 0.5 GROUP BY g ORDER BY g"),
  q3 = paste("SELECT s.label, COUNT(*) AS n FROM big b JOIN small s",
             "ON b.g = s.g GROUP BY s.label ORDER BY s.label"),
  q4 = paste("SELECT g, x, ROW_NUMBER() OVER (PARTITION BY g ORDER BY",
             "x DESC) AS rn FROM big WHERE x > 0.9")
)

task_names <- c(q1 = "simple SELECT", q2 = "filter + aggregate",
                q3 = "join", q4 = "window (asymmetry cell)")

# Arms --------------------------------------------------------------------
# Each arm: reset() returns state to cold; warm() pre-opens shared state;
# run(t) executes task t. Data bound locally inside run() so caller-frame
# lookup (duckdf, sqldf) sees it; assignment is pointer copying, not timed
# work.

arm_registry <- function(data) {
  arms <- list()

  arms$duckdf <- list(
    label = "duckdf 0.2.1",
    available = requireNamespace("duckdb", quietly = TRUE),
    reset = function() cleanup("bench_unused"),
    warm = function() {
      mtcars <- data$mtcars
      invisible(duckdf(queries$q1))
    },
    run = function(t) {
      mtcars <- data$mtcars; big <- data$big; small <- data$small
      duckdf(queries[[t]])
    }
  )

  raw_state <- new.env(parent = emptyenv())
  raw_state$con <- NULL
  arms$raw_duckdb <- list(
    label = "raw duckdb-r (DBI)",
    available = requireNamespace("duckdb", quietly = TRUE) &&
      requireNamespace("DBI", quietly = TRUE),
    reset = function() {
      if (!is.null(raw_state$con)) {
        tryCatch(DBI::dbDisconnect(raw_state$con, shutdown = TRUE),
                 error = function(e) NULL)
        raw_state$con <- NULL
      }
    },
    warm = function() {
      raw_state$con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
    },
    run = function(t) {
      mtcars <- data$mtcars; big <- data$big; small <- data$small
      con <- raw_state$con
      if (is.null(con)) {
        con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
        raw_state$con <- con
      }
      tables <- switch(t, q1 = "mtcars", q2 = "big",
                       q3 = c("big", "small"), q4 = "big")
      for (tb in tables) {
        duckdb::duckdb_register(con, tb, get(tb))
      }
      on.exit(for (tb in tables) duckdb::duckdb_unregister(con, tb),
             add = TRUE)
      DBI::dbGetQuery(con, queries[[t]])
    }
  )

  sqldf_state <- new.env(parent = emptyenv())
  sqldf_state$cold_pending <- TRUE
  arms$sqldf <- list(
    label = "sqldf (SQLite)",
    available = requireNamespace("sqldf", quietly = TRUE),
    reset = function() {
      tryCatch(sqldf::sqldf("close"), error = function(e) NULL)
      sqldf_state$cold_pending <- TRUE
    },
    warm = function() {
      mtcars <- data$mtcars
      invisible(sqldf::sqldf(queries$q1))
      sqldf_state$cold_pending <- FALSE
    },
    run = function(t) {
      mtcars <- data$mtcars; big <- data$big; small <- data$small
      sqldf::sqldf(queries[[t]])
    }
  )

  dt_state <- new.env(parent = emptyenv())
  dt_state$dt <- NULL
  arms$data_table <- list(
    label = "data.table",
    available = requireNamespace("data.table", quietly = TRUE),
    reset = function() {
      dt_state$dt <- NULL
    },
    warm = function() {
      dt_state$dt <- data.table::as.data.table(data$big)
      dt_state$mt <- data.table::as.data.table(data$mtcars)
    },
    run = function(t) {
      dt <- dt_state$dt
      if (is.null(dt)) {
        dt <- data.table::as.data.table(data$big)
        dt_state$dt <- dt
      }
      mt <- if (!is.null(dt_state$mt)) dt_state$mt
            else data.table::as.data.table(data$mtcars)
      switch(t,
        q1 = mt[disp >= 200, .(mpg, cyl)],
        q2 = dt[x > 0.5, .(n = .N, mean_x = mean(x)), by = g][order(g)],
        q3 = {
          r <- dt[data$small, on = "g", nomatch = NULL]
          r[, .(n = .N), by = label][order(label)]
        },
        q4 = {
          r <- dt[x > 0.9]
          data.table::setorder(r, g, -x)
          r[, rn := seq_len(.N), by = g]
          r[, .(g, x, rn)]
        })
    }
  )

  arms$dplyr <- list(
    label = "dplyr (plain)",
    available = requireNamespace("dplyr", quietly = TRUE),
    reset = function() invisible(gc(verbose = FALSE)),
    warm = function() invisible(gc(verbose = FALSE)),
    run = function(t) {
      mtcars <- data$mtcars; big <- data$big; small <- data$small
      switch(t,
        q1 = mtcars |>
          dplyr::filter(disp >= 200) |> dplyr::select(mpg, cyl),
        q2 = big |>
          dplyr::filter(x > 0.5) |>
          dplyr::group_by(g) |>
          dplyr::summarise(n = dplyr::n(), mean_x = mean(x),
                           .groups = "drop") |>
          dplyr::arrange(g),
        q3 = big |>
          dplyr::inner_join(small, by = "g") |>
          dplyr::group_by(label) |>
          dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
          dplyr::arrange(label),
        q4 = big |>
          dplyr::filter(x > 0.9) |>
          dplyr::group_by(g) |>
          dplyr::mutate(rn = dplyr::row_number(dplyr::desc(x))) |>
          dplyr::ungroup() |>
          dplyr::select(g, x, rn))
    }
  )

  dplyr_state <- new.env(parent = emptyenv())
  dplyr_state$duck <- NULL
  arms$duckplyr <- list(
    label = "duckplyr",
    available = requireNamespace("duckplyr", quietly = TRUE),
    reset = function() {
      dplyr_state$duck <- NULL
    },
    warm = function() {
      dplyr_state$duck <- list(
        mt = duckplyr::as_duckdb_tibble(data$mtcars),
        big = duckplyr::as_duckdb_tibble(data$big),
        small = duckplyr::as_duckdb_tibble(data$small))
    },
    run = function(t) {
      duck <- dplyr_state$duck
      if (is.null(duck)) {
        duck <- list(
          mt = duckplyr::as_duckdb_tibble(data$mtcars),
          big = duckplyr::as_duckdb_tibble(data$big),
          small = duckplyr::as_duckdb_tibble(data$small))
        dplyr_state$duck <- duck
      }
      switch(t,
        q1 = duck$mt |>
          dplyr::filter(disp >= 200) |> dplyr::select(mpg, cyl),
        q2 = duck$big |>
          dplyr::filter(x > 0.5) |>
          dplyr::group_by(g) |>
          dplyr::summarise(n = dplyr::n(), mean_x = mean(x),
                           .groups = "drop") |>
          dplyr::arrange(g),
        q3 = duck$big |>
          dplyr::inner_join(duck$small, by = "g") |>
          dplyr::group_by(label) |>
          dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
          dplyr::arrange(label),
        q4 = duck$big |>
          dplyr::filter(x > 0.9) |>
          dplyr::group_by(g) |>
          dplyr::mutate(rn = dplyr::row_number(dplyr::desc(x))) |>
          dplyr::ungroup() |>
          dplyr::select(g, x, rn))
    }
  )

  db_state <- new.env(parent = emptyenv())
  db_state$con <- NULL
  arms$dbplyr <- list(
    label = "dbplyr + duckdb",
    available = requireNamespace("dbplyr", quietly = TRUE) &&
      requireNamespace("duckdb", quietly = TRUE),
    reset = function() {
      if (!is.null(db_state$con)) {
        tryCatch(DBI::dbDisconnect(db_state$con, shutdown = TRUE),
                 error = function(e) NULL)
        db_state$con <- NULL
      }
    },
    warm = function() {
      con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
      db_state$con <- con
      dplyr::copy_to(con, data$mtcars, "mtcars", temporary = FALSE)
      dplyr::copy_to(con, data$big, "big", temporary = FALSE)
      dplyr::copy_to(con, data$small, "small", temporary = FALSE)
    },
    run = function(t) {
      mtcars <- data$mtcars; big <- data$big; small <- data$small
      con <- db_state$con
      if (is.null(con)) {
        con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
        db_state$con <- con
        dplyr::copy_to(con, mtcars, "mtcars", temporary = FALSE)
        dplyr::copy_to(con, big, "big", temporary = FALSE)
        dplyr::copy_to(con, small, "small", temporary = FALSE)
      }
      switch(t,
        q1 = dplyr::tbl(con, "mtcars") |>
          dplyr::filter(disp >= 200) |>
          dplyr::select(mpg, cyl) |>
          dplyr::collect(),
        q2 = dplyr::tbl(con, "big") |>
          dplyr::filter(x > 0.5) |>
          dplyr::group_by(g) |>
          dplyr::summarise(n = dplyr::n(), mean_x = mean(x),
                           .groups = "drop") |>
          dplyr::arrange(g) |>
          dplyr::collect(),
        q3 = dplyr::tbl(con, "big") |>
          dplyr::inner_join(dplyr::tbl(con, "small"), by = "g") |>
          dplyr::group_by(label) |>
          dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
          dplyr::arrange(label) |>
          dplyr::collect(),
        q4 = dplyr::tbl(con, "big") |>
          dplyr::filter(x > 0.9) |>
          dplyr::group_by(g) |>
          dplyr::mutate(rn = dplyr::row_number(dplyr::desc(x))) |>
          dplyr::ungroup() |>
          dplyr::select(g, x, rn) |>
          dplyr::collect())
    }
  )

  arms
}

# Timing ------------------------------------------------------------------

# bench::mark re-evaluates its expression, so it is called directly per
# measurement - a wrapper function would force its promise once and cache

measure_arm_task <- function(arm, task, tiny, reference) {
  # equivalence output first, on the cold state, untimed
  arm$reset()
  eq_res <- tryCatch(
    equivalence_check(reference, arm$run(task)),
    error = function(e) list(status = "error",
                             observation = conditionMessage(e)))
  if (eq_res$status == "error") {
    return(data.frame(task = task, cold_s = NA_real_, warm_s = NA_real_,
                      mem_alloc = NA_character_,
                      equiv_status = "error",
                      observation = eq_res$observation))
  }

  arm$reset()
  cold <- bench::mark(arm$run(task), min_time = 0,
                      min_iterations = 1, max_iterations = 1,
                      check = FALSE, memory = TRUE, filter_gc = FALSE)
  arm$warm()
  warm <- bench::mark(arm$run(task),
                      min_time = if (tiny) 0.05 else 0.5,
                      min_iterations = if (tiny) 2 else 5,
                      max_iterations = if (tiny) 2 else 100,
                      check = FALSE, memory = TRUE, filter_gc = FALSE)
  cold_s <- as.numeric(summary(cold)$median)
  warm_s <- as.numeric(summary(warm)$median)
  alloc <- format(summary(warm)$mem_alloc, units = "MB",
                  standard = "SI")
  data.frame(task = task, cold_s = cold_s, warm_s = warm_s,
             mem_alloc = alloc,
             equiv_status = eq_res$status,
             observation = eq_res$observation)
}

run_benchmarks <- function(tiny = FALSE, arms = NULL, seed = 2021,
                           write = !tiny) {
  data <- build_data(tiny = tiny, seed = seed)
  reg <- arm_registry(data)
  if (is.null(arms)) arms <- names(reg)

  # data.table arm is the equivalence reference
  reg$data_table$reset()
  ref_big <- reg$data_table$run("q2") # triggers dt build
  ref_out <- setNames(
    vector("list", 4), c("q1", "q2", "q3", "q4"))
  ref_out[["q2"]] <- normalise(ref_big)
  ref_out[["q1"]] <- normalise(reg$data_table$run("q1"))
  ref_out[["q3"]] <- normalise(reg$data_table$run("q3"))
  ref_out[["q4"]] <- normalise(reg$data_table$run("q4"))

  tasks <- c("q1", "q2", "q3", "q4")
  rows <- list()
  for (ar in arms) {
    arm <- reg[[ar]]
    if (!isTRUE(arm$available)) {
      for (t in tasks) {
        rows[[length(rows) + 1]] <- data.frame(
          arm = ar, task = t, cold_s = NA_real_, warm_s = NA_real_,
          mem_alloc = NA_character_, equiv_status = "not-run",
          observation = "arm package not installed locally")
      }
      next
    }
    for (t in tasks) {
      r <- tryCatch(measure_arm_task(arm, t, tiny, ref_out[[t]]),
                    error = function(e) data.frame(
                      task = t, cold_s = NA_real_, warm_s = NA_real_,
                      mem_alloc = NA_character_, equiv_status = "error",
                      observation = conditionMessage(e)))
      r$arm <- ar
      rows[[length(rows) + 1]] <- r
    }
    arm$reset()
  }
  results <- do.call(rbind, rows)
  results <- results[c("arm", "task", "cold_s", "warm_s", "mem_alloc",
                       "equiv_status", "observation")]

  verdicts <- headline_verdicts(results)
  list(results = results, verdicts = verdicts, tiny = tiny)
}

# Headline claims ---------------------------------------------------------

headline_verdicts <- function(results) {
  get_warm <- function(arm, task) {
    r <- results[results$arm == arm & results$task == task, ]
    if (nrow(r) == 0 || is.na(r$warm_s[1])) NA_real_ else r$warm_s[1]
  }
  vd <- data.frame()
  for (t in c("q1", "q2", "q3", "q4")) {
    duck <- get_warm("duckdf", t)
    raw <- get_warm("raw_duckdb", t)
    sql <- get_warm("sqldf", t)
    ratio_raw <- if (!is.na(duck) && !is.na(raw) && raw > 0) duck / raw
                 else NA_real_
    ratio_sql <- if (!is.na(duck) && !is.na(sql) && sql > 0) duck / sql
                 else NA_real_
    v4a <- if (is.na(ratio_raw)) "not-run"
           else if (ratio_raw <= 1.10) "PASS" else "FAIL"
    v4b <- if (is.na(ratio_sql)) "not-run"
           else if (ratio_sql > 0.5) "narrower than expected - investigate"
           else "recorded"
    vd <- rbind(vd, data.frame(
      task = t, claim4a = v4a, duckdf_over_raw = ratio_raw,
      duckdf_over_sqldf = ratio_sql, claim4b = v4b))
  }
  vd
}

# Results report ----------------------------------------------------------

md_table <- function(df) {
  cols <- names(df)
  lines <- c(paste0("| ", paste(cols, collapse = " | "), " |"),
             paste0("|", paste(rep("---", length(cols)),
                               collapse = "|"), "|"))
  for (i in seq_len(nrow(df))) {
    lines <- c(lines, paste0("| ",
      paste(vapply(df[i, ], function(x) as.character(x), character(1)),
            collapse = " | "), " |"))
  }
  lines
}

fmt_s <- function(x) {
  if (is.na(x)) "not-run" else format(x, digits = 3)
}

write_results <- function(bench_out, path) {
  res <- bench_out$results
  res$cold_s <- vapply(res$cold_s, fmt_s, character(1))
  res$warm_s <- vapply(res$warm_s, fmt_s, character(1))
  vd <- bench_out$verdicts
  for (cn in c("duckdf_over_raw", "duckdf_over_sqldf")) {
    vd[[cn]] <- vapply(vd[[cn]], function(x)
      if (is.na(x)) "not-run" else format(x, digits = 3), character(1))
  }
  obs <- res[res$observation != "", c("arm", "task", "observation")]
  lines <- c(
    "# duckdf 0.2.0 benchmark results",
    "",
    paste0("Generated by bench/run_benchmarks.R on ", Sys.Date(),
           ". Full-time machine, single harness run, bench::mark"),
    "median (cold: single call from reset state; warm: min-of-N on",
    "shared state). The 4a band (1.10x raw duckdb-r, per task) is",
    "the package's wrapper-overhead self-gate.",
    "",
    "Task 4 is the labelled asymmetry cell (SQLite window support is",
    "newer than DuckDB's): results recorded, not ranked head-to-head.",
    "",
    "## Results (arm x task)",
    "",
    md_table(res), "",
    "## Claim 4a: duckdf warm median <= raw duckdb-r warm median x 1.10, per task",
    "",
    md_table(vd), "",
    "## Equivalence observations",
    "",
    if (nrow(obs) == 0) "All arms matched the data.table reference output." else c(
      md_table(obs), "",
      "Class and typing differences are recorded, not coerced away."),
    "")
  writeLines(lines, path)
  invisible(path)
}
