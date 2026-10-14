# Rscript dev/make_toy.R OLD_PEDIGREE OLD_POOL OUT_DIR
#
# Rebuilds the self-test toy in the kit's input formats from the first kit's toy
# (`git show python-v0:selftest/toy/pedigree.tsv` and `.../pool.tsv`), which simACE
# simulated with seed 20261008 and fitACE_epimight's create_input turned into a pool.
#
# Every outcome is kept. Probands are generations 2-4; their follow-up ended at age 80, 75
# and 65. Birth dates are drawn per generation, 25 years apart, so that every date falls
# before study_end (2023-12-31); birth_year binned by 25 then gives the old strata, 1962,
# 1963 and 1964, as 1900, 1925 and 1950. Ages get a uniform fraction of a year, so the
# cohort table's floored ages equal the old ones. Writes pedigree.tsv, trait1.tsv and
# trait2.tsv.

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3)
set.seed(20261014)

ped <- fread(args[1], sep = "\t", colClasses = "integer")
pool <- fread(args[2], sep = "\t")

ped[mother == -1, mother := NA]
ped[father == -1, father := NA]
gen <- rep(NA_integer_, nrow(ped))
names(gen) <- ped$id
while (anyNA(gen)) {
  parents_gen <- pmax(gen[as.character(ped$mother)], gen[as.character(ped$father)])
  founder <- is.na(ped$mother) & is.na(ped$father)
  ready <- is.na(gen) & (founder | !is.na(parents_gen))
  gen[ready] <- ifelse(founder[ready], 0L, parents_gen[ready] + 1L)
}
ped[, generation := gen[as.character(id)]]

windows <- data.table(
  generation = 0:4,
  from = as.IDate(c("1850-01-01", "1875-01-01", "1900-01-01", "1925-01-01", "1950-01-01")),
  to = as.IDate(c("1859-12-31", "1884-12-31", "1909-12-31", "1934-12-31", "1957-12-31"))
)
ped <- windows[ped, on = "generation"]
ped[, birth_date := as.IDate(from + floor(runif(.N) * (as.integer(to - from) + 1)))]

own <- unique(pool[, .(id = person_id, trait, status = trait_status, old_age = trait_age,
                       born_at_year)])
stopifnot(!anyDuplicated(own[, .(id, trait)]))
own <- ped[, .(id, birth_date, generation)][own, on = "id"]
stopifnot(identical(sort(unique(own$generation)), 2:4),
          own[, uniqueN(born_at_year), by = generation]$V1 == 1)
own[, age := old_age + floor(runif(.N) * 1e4) / 1e4]
own[, date := birth_date + as.integer(round(age * 365.25))]
stopifnot(own$date <= as.IDate("2023-12-31"),
          abs(as.integer(own$date - own$birth_date) / 365.25 - own$age) <= 1 / 365.25)

out <- args[3]
dir.create(out, showWarnings = FALSE, recursive = TRUE)
fwrite(ped[order(id), .(id, mother, father, sex, birth_date)],
       file.path(out, "pedigree.tsv"), sep = "\t", na = "NA")
for (t in sort(unique(own$trait))) {
  fwrite(own[trait == t][order(id), .(id, trait, status, age = sprintf("%.4f", age), date)],
         file.path(out, paste0(t, ".tsv")), sep = "\t", quote = FALSE)
}
strata <- own[, .(s = paste(unique(born_at_year), collapse = ",")), by = generation]
cat(sprintf("%d people, %d probands; old strata by generation: %s\n", nrow(ped),
            uniqueN(own$id),
            strata[order(generation), paste(generation, s, sep = "=", collapse = " ")]))
