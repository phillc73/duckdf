hatch <- function(query = "") {

# Extract dataframe name using string splits
query_split <- stringi::stri_split_fixed(query, "INTO",
                                         omit_empty = TRUE,
                                         opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

query_split <- trimws(unlist(query_split))

from_df <- stringi::stri_extract_first_words(query_split[2], 
                                                   locale = NULL)

query_split_values <- stringi::stri_split_fixed(query_split[2], "VALUES (",
                                         omit_empty = TRUE,
                                         opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

query_split_values <- trimws(unlist(query_split_values))

query_split_values <- stringi::stri_split_fixed(query_split_values[2], ")",
                                         omit_empty = TRUE,
                                         opts_fixed = stringi::stri_opts_fixed(case_insensitive = TRUE))

query_split_values <- trimws(unlist(query_split_values))

new_df <- get(from_df)

new_values <- as.list(scan(text = query_split_values, what = "", sep = ","))

new_df[nrow(new_df) + 1,] <- new_values

assign(paste(from_df), new_df)

}
