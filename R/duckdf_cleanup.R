duckdf_cleanup <- function(query = ""){

  if (file.exists(query))
    file.remove(query)

  if (file.exists(paste0(query,".wal")))
    file.remove(paste0(query,".wal"))

  if (file.exists(paste0(query,".tmp")))
    file.remove(paste0(query,".tmp"))
}
