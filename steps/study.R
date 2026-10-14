# pixi run study study.yaml OUT/
#
# Runs steps 1 to 5 (check, cohort, epimight, tables, report) in order and stops at the
# first that fails. Each can also be run on its own: pixi run <step> study.yaml OUT/.

suppressPackageStartupMessages(library(nordicepimight))
run_study()
