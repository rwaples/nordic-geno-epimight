# pixi run cohort study.yaml OUT/
#
# Step 2: applies each trait's rules and counts every proband's relatives, writing
# EPIMIGHT's cohort table to OUT/2_cohort/cohort.tsv, with cohort_summary.tsv and the
# number of people each rule changed (rules.tsv).

suppressPackageStartupMessages(library(nordicepimight))
run_step("cohort", run_cohort)
