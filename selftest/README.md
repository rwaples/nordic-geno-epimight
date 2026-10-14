# Self-test data

## The toy study

`toy/` is a small simulated study in the kit's input formats. It is not real data.

- `pedigree.tsv`: 7,500 people in five generations of 1,500, with `id, mother, father,
  sex, birth_date`. The first two generations are founders' lines with no trait rows.
- `trait1.tsv`, `trait2.tsv`: one row for each of the 4,500 people in generations 2 to 4,
  with `id, trait, status, age, date`. Status 2 (a competing event) occurs in both.
- `traits.tsv`, `analyses.tsv`, `study.yaml`: h² for both traits and rg in both
  directions, for PO, FS and HS, stratified by birth year in 25-year bins (1900, 1925,
  1950).

simACE simulated the pedigree and both traits (seed 20261008; 1,500 people per
generation; follow-up ending at age 80, 75 and 65 in generations 2, 3 and 4).
fitACE_epimight's `create_input` built the first kit's pool from it, and 803 censored
outcomes became competing events. `dev/make_toy.R` rebuilt that toy in these formats
without changing any outcome: it draws birth dates per generation, 25 years apart, so
every date falls before `study_end`, and adds a fraction of a year to each age, so the
cohort table's whole-year ages equal the first toy's. To rebuild it:

```sh
git show python-v0:selftest/toy/pedigree.tsv > /tmp/old_pedigree.tsv
git show python-v0:selftest/toy/pool.tsv > /tmp/old_pool.tsv
pixi run Rscript dev/make_toy.R /tmp/old_pedigree.tsv /tmp/old_pool.tsv selftest/toy
```

`python-v0` is a local branch, not on GitHub.
