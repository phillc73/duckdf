Fixed in 0.2.0 - closing as resolved.

The root cause was 0.1.2's extraction: it split the query string on
FROM, so any table referenced inside a subquery (or a CTE, or after
more than one FROM) was never registered and the query failed.

0.2.0 replaces string matching entirely. Table names now come from
DuckDB's own parse tree (`json_serialize_sql`), so subqueries, joins,
CTEs, quoted identifiers and string literals containing the word FROM
are all handled by the same engine that will run the query. Your
report's case is covered by the test suite.

The repository has been dormant since 2021; it is active again with
0.2.0 (duckdb 1.5.6 or later, same API surface plus a few additions).
Thanks for the report - it directly shaped the rewrite.
