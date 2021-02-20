cleanup <- function(query = "") {

  # check if the files exist and if they do, remove them
  if (file.exists(query))
    file.remove(query)

  if (file.exists(paste0(query, ".wal")))
    file.remove(paste0(query, ".wal"))

  if (file.exists(paste0(query, ".tmp")))
    file.remove(paste0(query, ".tmp"))
}
