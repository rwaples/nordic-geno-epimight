# Step 6, export: OUT/6_export/ is the only folder a site sends to the other sites (D26,
# preliminary). It holds the result tables with small counts suppressed, run.yaml without
# file paths, and a report rendered from those. Individual-level files (the cohort table,
# inputs.rds, pedsum's output, the check findings with their example ids) never go there.
#
# A count from 1 to `export_min_count` (5 by default, as R/Summarise_incidence.R does) is
# suppressed. No rule yet covers counts that can be derived from neighbouring cells, such as
# the increment between two CIF ages.

EXPORT_TABLES <- c("h2.tsv", "rg.tsv", "cif.tsv", "cohort_summary.tsv")
SUMMARY_COUNTS <- c("probands", "cases", "competing", "censored", "with_relatives",
                    "with_affected_relatives", "relatives", "affected_relatives")
OUTCOME_COUNTS <- c("cases", "competing", "censored")

small <- function(x, min_count) !is.na(x) & x > 0 & x <= min_count

# cohort_summary.tsv with every count from 1 to min_count set to NA. Probands are cases plus
# competing plus censored, so when one of those three is suppressed the other two are too.
suppress_summary <- function(summary, min_count) {
  d <- copy(summary)
  outcome_hidden <- Reduce(`|`, lapply(OUTCOME_COUNTS, function(col) small(d[[col]], min_count)))
  hidden <- 0L
  for (col in SUMMARY_COUNTS) {
    drop <- small(d[[col]], min_count) | (col %in% OUTCOME_COUNTS & outcome_hidden)
    hidden <- hidden + sum(drop & !is.na(d[[col]]))
    set(d, i = which(drop), j = col, value = NA)
  }
  list(table = d, hidden = hidden)
}

# cif.tsv without the rows whose cumulative cases are from 1 to min_count.
suppress_cif <- function(cif, min_count) {
  drop <- small(cif$cases, min_count)
  list(table = cif[!drop], hidden = sum(drop))
}

# run.yaml with each input's path cut to its file name.
export_record <- function(run, min_count, hidden) {
  run$inputs <- lapply(run$inputs, function(i) list(file = basename(i$path), md5 = i$md5))
  run$export <- list(min_count = min_count, preliminary = TRUE,
                     summary_counts_suppressed = hidden$summary, cif_rows_dropped = hidden$cif)
  run
}

run_export <- function(study_path, out, dir) {
  study <- readRDS(file.path(step_dir(out, "check"), "inputs.rds"))$study
  min_count <- study$export_min_count
  read <- function(name) {
    fread(file.path(out, name), colClasses = list(character = study$stratify), na.strings = "NA")
  }
  for (name in c("h2.tsv", "rg.tsv")) file.copy(file.path(out, name), file.path(dir, name))
  summary <- suppress_summary(read("cohort_summary.tsv"), min_count)
  cif <- suppress_cif(read("cif.tsv"), min_count)
  fwrite(summary$table, file.path(dir, "cohort_summary.tsv"), sep = "\t", na = "NA", quote = FALSE)
  fwrite(cif$table, file.path(dir, "cif.tsv"), sep = "\t", na = "NA", quote = FALSE)
  run <- export_record(yaml::read_yaml(file.path(out, "run.yaml")), min_count,
                       list(summary = summary$hidden, cif = cif$hidden))
  yaml::write_yaml(run, file.path(dir, "run.yaml"))
  scratch <- file.path(tempdir(), "export_report")
  dir.create(scratch, showWarnings = FALSE)
  render_report(dir, scratch)
  cat(sprintf(paste("export: %s is ready to share; counts from 1 to %d suppressed",
                    "(%d summary counts, %d CIF rows)\n"),
              dir, min_count, summary$hidden, cif$hidden))
  TRUE
}
