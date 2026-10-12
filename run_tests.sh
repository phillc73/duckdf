#!/bin/sh
# duckdf test runner - exits nonzero on failure, prints RESULT: pass on green
cd "$(dirname "$0")" || exit 1
Rscript -e '
  out <- testthat::test_local(".", reporter = "silent", stop_on_failure = FALSE);
  failed <- sum(vapply(out, function(t) sum(t$n_fail) + sum(t$n_error) > 0, logical(1)));
  quit(status = if (failed > 0) 1 else 0)
' && echo "RESULT: pass"
