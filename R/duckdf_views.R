# duckdf - SQL for dataframes on DuckDB (AGPL-3)
# duckdf_views(): read-only listing of views on the shared connection -
# spec-api-contract.md. Backing classes tracked at registration in
# lifecycle.R (duckdb-r keeps the objects on the C side, unqueryable).

#' List your registered views
#'
#' \code{duckdf_views} lists the views currently registered on the
#'   shared duckdf connection.
#'
#' @return A data.frame with one row per registered view: the view name
#'   and the class of the backing R object. Empty (not an error) when
#'   nothing is registered. Read-only: no unregistration happens here.
#'
#' @examples
#' \dontrun{
#'
#' # See what duckdf is currently quacking about
#' duckdf::duckdf_views()
#'
#' }
#'
#' @export
#'

duckdf_views <- function() {
  con <- duckdf_con()
  views <- DBI::dbGetQuery(con,
    "SELECT view_name FROM duckdb_views() WHERE NOT internal ORDER BY view_name")
  backing <- vapply(views$view_name, function(n) {
    cls <- .duckdf$classes[[n]]
    if (is.null(cls)) "native-view" else cls
  }, character(1), USE.NAMES = FALSE)
  data.frame(view_name = views$view_name, backing_class = backing,
             stringsAsFactors = FALSE)
}
