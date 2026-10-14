# Rscript kit/selftest/build/cohort_oracle.R R/make_epimight_tte.R kit/selftest/cohort_cases OUT.tsv
#
# Builds the cohort table of the study in the given folder with the collaborators'
# make_epimight_tte, one call per trait and relationship, from the same trait files,
# pedigree pairs and rules the kit reads. The kit's cohort step must reproduce it row for
# row (tests/testthat/test-cohort.R). Pairs come straight from pedigreegraph: a
# directional relationship is written with the person as id1 and the relative as id2
# (relative_is = "id2"), the others are read both ways. Stratifies on unbinned birth_year.

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3)
source(args[1])
folder <- args[2]
site <- yaml::read_yaml(file.path(folder, "site.yaml"))
plan_dir <- dirname(file.path(folder, site$plan))
study <- yaml::read_yaml(file.path(folder, site$plan))
stopifnot(identical(study$stratify, "birth_year"), is.null(study$birth_year_bin))
in_plan <- function(path) file.path(plan_dir, path)
in_data <- function(path) file.path(folder, site$data, path)

pedigree <- fread(in_data("pedigree.tsv"), colClasses = "character", na.strings = c("", "NA"))
traits <- fread(in_plan(study$traits), colClasses = "character", na.strings = "")
analyses <- fread(in_plan(study$analyses), colClasses = "character")
windows <- fread(in_plan(study$relative_windows), colClasses = "character")

codes <- list(PO = c("MO", "FO"), FS = c("FS", "MZ"), HS = c("MHS", "PHS"), mHS = "MHS",
              pHS = "PHS", Av = "Av", `1G` = "GP", `1C` = "1C")
directional <- c("PO", "Av", "1G")
graph <- pedigreegraph::pedigree_graph(data.frame(
  id = seq_len(nrow(pedigree)), mother = match(pedigree$mother, pedigree$id),
  father = match(pedigree$father, pedigree$id)
))
pairs <- as.data.table(pedigreegraph::relationship_pairs(graph, categories = unlist(codes),
                                                         progress = FALSE))
genealogy <- pairs[, .(id1 = pedigree$id[first_id], id2 = pedigree$id[second_id],
                       relationship_kind = as.character(code), kinship = 0.25)]

phenotype <- function(file, name) {
  d <- fread(in_data(file), colClasses = c(id = "character", status = "integer"))
  ped <- pedigree[match(d$id, pedigree$id)]
  d[, .(ID = id, Sex = ped$sex, BirthDate = ped$birth_date, Phenotype = name, Status = status,
        FailureTime = age)]
}
number <- function(x) if (is.na(x) || x == "none") NULL else as.numeric(x)
or_default <- function(x, default) if (is.na(x)) default else x

tables <- list()
for (i in seq_len(nrow(traits))) {
  t <- traits[i]
  if (!(t$trait %in% c(analyses$trait, analyses$relatives_trait))) next
  for (rel in unique(analyses$relationship)) {
    w <- windows[trait == t$trait & relationship == rel, max_followup_relatives]
    w_rel <- if (length(w) == 1) {
      number(w)
    } else if (is.na(t$max_followup_relatives)) {
      number(t$max_followup)
    } else {
      number(t$max_followup_relatives)
    }
    exclude <- or_default(t$exclude_trait2, "none")
    second <- if (exclude != "none") {
      phenotype(traits[trait == t$trait2, file], t$trait2)
    }
    capture.output(out <- make_epimight_tte(
      mainPhenotype = phenotype(t$file, t$trait), secondaryPhenotype = second,
      genealogy = genealogy, trait = t$trait, relatives_kind = codes[[rel]],
      relatives_label = rel, relative_is = if (rel %in% directional) "id2" else "either",
      min_followup = number(t$min_followup), max_followup = number(t$max_followup),
      max_followup_relatives = w_rel, study_end = site$study_end,
      trait2 = if (exclude != "none") t$trait2, exclude_trait2 = exclude,
      trait2_window = number(t$trait2_window),
      trait2_window_type = or_default(t$trait2_window_type, "within"),
      trait2_action = or_default(t$trait2_action, "exclude"),
      filter_relatives = identical(t$filter_relatives, "TRUE"), keep_columns = "birth_year"
    ))
    tables[[length(tables) + 1]] <- out
  }
}
cohort <- rbindlist(tables)
setorderv(cohort, c("trait", "relatives_kind", "person_id"))
fwrite(cohort, args[3], sep = "\t", quote = FALSE)
cat(sprintf("%d rows, %d traits x %d relationships\n", nrow(cohort), uniqueN(cohort$trait),
            uniqueN(cohort$relatives_kind)))
