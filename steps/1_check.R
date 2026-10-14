# pixi run check study.yaml OUT/
#
# Step 1: checks study.yaml, the trait and analysis lists, the pedigree (with pedsum) and
# every trait file, and lists every problem in OUT/1_check/findings.tsv. A STOP ends the
# run here; warnings are recorded and the run goes on.

suppressPackageStartupMessages(library(nordicepimight))
run_step("check", run_check)
