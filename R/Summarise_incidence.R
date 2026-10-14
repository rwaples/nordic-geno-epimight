# x_col      = column indicating either year of birth or year of diagnosis (as year-month-day)
# age_col    = column indicating age at diagnosis
# status_col = column indicating case control status
# case_value = defines who is a case, so 1 but if you use "case" that could work
# min_cases  = minimum number of cases per cell (for denmark this is 5)

bin_cases = function(dat, x_col = NULL, age_col = NULL, status_col = NULL, case_value   = 1, min_cases    = 5) 
{
  library(dplyr)
  need = c(x_col, age_col, status_col)
  miss = setdiff(need, names(dat))
  if (length(miss)) stop("column(s) not found: ", paste(miss, collapse = ", "))

  cases = dat %>% filter(.data[[status_col]] == case_value)
  if (nrow(cases) == 0) stop("no rows where ", status_col, " == ", case_value)
  
  cases[[x_col]] = as.integer(substr(as.character(cases[[x_col]]), 1, 4))

  out = cases %>%
    mutate(x_bin   = floor(as.numeric(.data[[x_col]])), age_bin = floor(as.numeric(.data[[age_col]]))) %>%
    filter(!is.na(x_bin), !is.na(age_bin)) %>%
    group_by(x_bin, age_bin) %>%
    summarise(n_cases = n(), .groups = "drop")

  n_parsed = sum(out$n_cases)
  if (n_parsed < nrow(cases))
    message(sprintf("%s: %d of %d cases dropped as NA in %s or %s",
                    x_col, nrow(cases) - n_parsed, nrow(cases), x_col, age_col))

  n_supp = sum(out$n_cases[out$n_cases <= min_cases])
  if (n_supp > 0)
    message(sprintf("%s: %d cases in %d cells suppressed (n <= %d)",
                    x_col, n_supp, sum(out$n_cases <= min_cases), min_cases))

  out = out %>% filter(n_cases > min_cases)
  colnames(out) = c("Year", "Age", "N")
  return(data.frame(out))
}

