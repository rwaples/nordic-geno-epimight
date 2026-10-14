# pixi run epimight study.yaml OUT/
#
# Step 3: runs EPIMIGHT on the cohort table, one call per distinct estimate the analyses
# need, and keeps every call's result and outcome in OUT/3_epimight/ for the tables step.

suppressPackageStartupMessages(library(nordicepimight))
run_step("epimight", run_epimight)
