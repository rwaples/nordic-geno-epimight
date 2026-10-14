# Self-test data

## The toy site

`toy/` is a small simulated site in the kit's input formats. It is not real data.
`toy/site.yaml` is its site file, `toy/plan/` its plan and `toy/data/` its data.

- `data/pedigree.tsv`: 7,500 people in five generations of 1,500, with `id, mother, father,
  sex, birth_date`. The first two generations are founders' lines with no trait rows.
- `data/trait1.tsv`, `data/trait2.tsv`: one row for each of the 4,500 people in generations 2 to 4,
  with `id, trait, status, age, date`. Status 2 (a competing event) occurs in both.
- `plan/`: h² for both traits and rg in both
  directions, for PO, FS and HS, stratified by birth year in 25-year bins (1900, 1925,
  1950).

simACE simulated the pedigree and both traits (seed 20261008; 1,500 people per
generation; follow-up ending at age 80, 75 and 65 in generations 2, 3 and 4).
fitACE_epimight's `create_input` built the first kit's pool from it, and 803 censored
outcomes became competing events. `build/make_toy.R` rebuilt that toy in these formats
without changing any outcome: it draws birth dates per generation, 25 years apart, so
every date falls before `study_end`, and adds a fraction of a year to each age, so the
cohort table's whole-year ages equal the first toy's. To rebuild it:

```sh
git show python-v0:selftest/toy/pedigree.tsv > /tmp/old_pedigree.tsv
git show python-v0:selftest/toy/pool.tsv > /tmp/old_pool.tsv
pixi run Rscript kit/selftest/build/make_toy.R /tmp/old_pedigree.tsv /tmp/old_pool.tsv kit/selftest/toy/data
```

`python-v0` is a local branch, not on GitHub.

The self-test also checks `out/6_export/`: it holds only the shareable files, no count
from 1 to 5 is left in it, and its `run.yaml` names no paths.

## The cohort-table cases

`cohort_cases/` is a site on the toy's data in which each trait is one set of the
trait rules: follow-up windows, the relatives' window (with `relative_windows.tsv`
overrides), each `trait2` rule and action, and `filter_relatives`. Every trait is
analysed for all eight relationships. `expected/cohort_cases.tsv.gz` is its cohort table
as the collaborators' `R/make_epimight_tte.R` builds it, one call per trait and
relationship, with the same pedigree pairs:

```sh
pixi run Rscript kit/selftest/build/cohort_oracle.R R/make_epimight_tte.R kit/selftest/cohort_cases kit/selftest/expected/cohort_cases.tsv
gzip -n -9 kit/selftest/expected/cohort_cases.tsv
```

`pixi run test` checks that the kit's cohort step reproduces it row for row.

The first kit's pool differs from the toy's cohort table in one place: PO for people born
1900-1909 (3,000 rows). simACE gave their parents outcomes, but the parents are not in
the study population, and the kit counts only relatives with a trait-file row.
