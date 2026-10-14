# A small valid study: three generations, six probands (c1-c6) in two trait files.
# `edit` receives the spec and returns it changed; write_fixture writes it to a new folder
# and returns the path of its study.yaml.

fixture_spec <- function() {
  pedigree <- data.table(
    id = c("gp1", "gp2", "p1", "p2", "p3", "p4", "c1", "c2", "c3", "c4", "c5", "c6"),
    mother = c(NA, NA, "gp2", NA, "gp2", NA, "p2", "p2", "p2", "p3", "p3", "p3"),
    father = c(NA, NA, "gp1", NA, "gp1", NA, "p1", "p1", "p1", "p4", "p4", "p4"),
    sex = c(1, 2, 1, 2, 2, 1, 1, 2, 1, 2, 1, 2),
    birth_date = c("1900-03-01", "1902-05-01", "1925-01-01", "1926-01-01", "1928-01-01",
                   "1927-01-01", "1950-02-01", "1952-03-01", "1955-04-01", "1951-05-01",
                   "1953-06-01", "1957-07-01")
  )
  outcome <- function(status, age) data.table(id = paste0("c", 1:6), status = status, age = age)
  list(
    study = list(pedigree = "pedigree.tsv", traits = "traits.tsv", analyses = "analyses.tsv",
                 study_end = "2023-12-31", stratify = "birth_year", birth_year_bin = 25L),
    pedigree = pedigree,
    traits = data.table(trait = c("t1", "t2"), type = "tte", file = c("t1.tsv", "t2.tsv")),
    analyses = data.table(analysis_id = c("h2_t1_FS", "rg_t1_t2_FS"), analysis = c("h2", "rg"),
                          trait = "t1", relatives_trait = c("t1", "t2"), relationship = "FS"),
    relative_windows = NULL,
    trait_files = list(
      t1.tsv = outcome(c(1, 0, 2, 1, 0, 0), c(30.5, 68.25, 40, 45.75, 70.1, 66)),
      t2.tsv = outcome(c(0, 1, 0, 0, 1, 0), c(73.5, 50, 68.5, 72.5, 20.2, 66.3))
    )
  )
}

# Trait file rows with `trait` and a date consistent with age, unless they already have one.
trait_rows <- function(rows, trait, pedigree) {
  rows <- copy(rows)
  if (!("date" %in% names(rows))) {
    birth <- as.IDate(pedigree$birth_date[match(rows$id, pedigree$id)])
    rows[, date := as.character(birth + as.integer(round(age * 365.25)))]
  }
  if (!("trait" %in% names(rows))) rows[, trait := trait]
  setcolorder(rows, intersect(c("id", "trait", "status", "age", "date"), names(rows)))
  rows
}

write_fixture <- function(edit = identity) {
  spec <- edit(fixture_spec())
  dir <- tempfile("study")
  dir.create(dir)
  write_tsv <- function(x, name) fwrite(x, file.path(dir, name), sep = "\t", na = "NA")
  yaml::write_yaml(spec$study, file.path(dir, "study.yaml"))
  write_tsv(spec$pedigree, "pedigree.tsv")
  write_tsv(spec$traits, "traits.tsv")
  write_tsv(spec$analyses, "analyses.tsv")
  if (!is.null(spec$relative_windows)) write_tsv(spec$relative_windows, "relative_windows.tsv")
  for (name in names(spec$trait_files)) {
    write_tsv(trait_rows(spec$trait_files[[name]], sub("\\.tsv$", "", name), spec$pedigree), name)
  }
  file.path(dir, "study.yaml")
}

# pedsum takes a few seconds per run, so only the tests about the pedigree run it.
skip_pedsum <- function(pedigree, dir, ...) {
  list(validated = pedigree[, .(id, mother, father)], findings = no_findings())
}

check_fixture <- function(edit = identity, pedsum = FALSE) {
  path <- write_fixture(edit)
  check_inputs(path, file.path(dirname(path), "out"),
               validate = if (pedsum) validate_pedigree else skip_pedsum)
}

codes <- function(result, sev = c("STOP", "WARN")) result$findings[severity %in% sev, code]
