# A finding is one problem a check found: a stable code, STOP or WARN, the file it is in,
# how many rows or values are affected, what is wrong, and up to ten examples. Checks
# return a data.table of findings (possibly empty); the check step collects every one
# before deciding whether the run stops.

FINDING_COLUMNS <- c("code", "severity", "file", "count", "message", "examples")

finding <- function(code, message, file = NA_character_, examples = character(),
                    count = length(examples), severity = "STOP") {
  stopifnot(severity %in% c("STOP", "WARN"))
  data.table::data.table(
    code = code, severity = severity, file = as.character(file), count = as.integer(count),
    message = message, examples = paste(utils::head(as.character(examples), 10), collapse = "; ")
  )
}

no_findings <- function() {
  data.table::data.table(code = character(), severity = character(), file = character(),
                         count = integer(), message = character(), examples = character())
}

# A finding when any of `bad` is TRUE, else NULL; `examples` is aligned with `bad`.
flag <- function(bad, code, message, file = NA_character_, examples = NULL, severity = "STOP") {
  bad <- !is.na(bad) & bad
  if (!any(bad)) {
    return(NULL)
  }
  finding(code, message, file, if (is.null(examples)) character() else examples[bad],
          count = sum(bad), severity = severity)
}

# Binds findings given as data.tables, NULLs, or lists of either.
collect <- function(...) {
  flatten <- function(x) {
    if (is.null(x) || is.data.frame(x)) list(x) else do.call(c, lapply(x, flatten))
  }
  out <- data.table::rbindlist(c(list(no_findings()), flatten(list(...))), use.names = TRUE)
  out[]
}

has_stop <- function(findings) any(findings$severity == "STOP")

write_findings <- function(findings, path) {
  data.table::fwrite(findings, path, sep = "\t", na = "NA")
}

format_findings <- function(findings) {
  if (nrow(findings) == 0) {
    return("no findings")
  }
  sprintf("%s %s%s: %s (%d)%s", findings$severity, findings$code,
          ifelse(is.na(findings$file), "", paste0(" [", basename(findings$file), "]")),
          findings$message, findings$count,
          ifelse(findings$examples == "", "", paste0("\n      e.g. ", findings$examples)))
}
