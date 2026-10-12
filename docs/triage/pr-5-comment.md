Closing as superseded, with the good part adopted - thank you for
this contribution.

What the PR proposed: fix the table-name extraction by string
matching with a filter that only registers names that actually exist
as objects in the caller's scope.

What 0.2.0 did instead: string matching is gone entirely. Table names
now come from DuckDB's own parse tree (`json_serialize_sql`), which
resolves the subquery and CTE cases string matching cannot (see also
issue #3). Your existence filter is the part that survived: the
extractor keeps only names that resolve to dataframes visible to the
caller, and everything else (aliases, CTE names, file paths) is left
to the engine.

The API has also grown `df = list(...)` (a named-list form with no
caller-scope dependency) and `df_name` as the verbatim escape hatch,
which together cover the cases the PR was working around.

If any of the old behaviour you were fixing still looks wrong in
0.2.0, please reopen - the repository is active again.
