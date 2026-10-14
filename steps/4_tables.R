# pixi run tables study.yaml OUT/
#
# Step 4: checks every EPIMIGHT call's outcome and writes OUT/h2.tsv, rg.tsv, cif.tsv,
# cohort_summary.tsv and run.yaml.

suppressPackageStartupMessages(library(nordicepimight))
run_step("tables", run_tables)
