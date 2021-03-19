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

# Put the dataframe from the query into a new object
new_df <- get(from_df)

# put the values from the query into a list
new_values <- as.list(scan(text = query_split_values, what = "", sep = ","))

# add a new row to the new dataframe
new_df[nrow(new_df) + 1,] <- new_values

# assign the new dataframe to the dataframe from the query
result_statement <- assign(paste(from_df), new_df)

# return the result
return(result_statement)

}
