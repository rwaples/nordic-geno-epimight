# pixi run report study.yaml OUT/
#
# Step 5: renders OUT/report.html from the step-4 tables: each analysis's estimates, CIF
# curves and counts, then h2 by trait, rg by relationship and a summary table.

suppressPackageStartupMessages(library(nordicepimight))
run_step("report", run_report)
