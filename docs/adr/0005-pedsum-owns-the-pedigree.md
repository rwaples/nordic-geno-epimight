# pedsum owns the pedigree; the kit reads only what pedsum wrote

Status: accepted (2026-10-17)

## Context

ADR 0001 gave the pedigree to pedsum, and 7e2f2ed stopped the kit from repairing it. The
kit still read the site's pedigree file itself, and every change and review added pedigree
checks to that reader: required columns, `-1` as an unknown parent, birth dates that
don't parse, a `birth_year` column that disagreed with `birth_date`. The kit then gave
pedsum a rewritten copy. So two programs parsed one file, and they disagreed. pedsum
reads `.`, `NULL` and `None` as unknown parents, and the kit read them as ids. pedsum
never saw the site's own `birth_year` column, because the copy replaced it with the year
of `birth_date` (rwaples/nordic-geno-epimight#3).

The SAP also removes same-multiple-birth pairs from full siblings (section 4.1). Finding
those pairs is pedigree work too (#2, #4).

## Decision

pedsum parses and checks the pedigree file. The kit adds no pedigree checks. When the
pedigree needs a new check, the check goes into pedsum.

- The check step runs `pedsum validate` on the site's pedigree file as it is, with
  `--birth-year-col birth_year --birth-date-col birth_date --twin-max-days 1`. Any
  finding stops the run (ADR 0001, 7e2f2ed).
- The kit then reads the pedigree from pedsum's `validate.tsv.gz`, never from the site's
  file. Once pedsum has passed the file, every known parent has a row, so the kit reads
  a parent without a row as unknown, whatever token pedsum accepted for it.
- pedsum finds multiple births. Full sibs born at most one day apart share a
  `multiple_birth_set`. The cohort step leaves pairs from one set out of `FS` and keeps
  both people as probands and as every other kind of relative. The sets are not passed
  to pedigreegraph as `twin` links, because a `twin` link means MZ co-twins and zygosity
  is unknown.
- The kit keeps the checks that need more than the pedigree. It checks the trait files
  against the pedigree (`trait_id_not_in_pedigree`, `date_before_birth`,
  `age_date_mismatch`, `birth_date_missing` and `stratum_na` for the study population),
  and it checks that the plan's stratify columns are in the pedigree
  (`stratify_not_in_pedigree`). pedsum never sees the trait files or the plan.

## Consequences

- `pedigree_missing_column`, `pedigree_unreadable`, `birth_date_invalid` and the
  `pedigree_birth_year_replaced` warning are gone. pedsum reports these problems, and the
  kit stops with `pedigree_invalid`. A `birth_year` that disagrees with `birth_date` now
  stops the run instead of being replaced.
- A pedigree without a `birth_year` column still has its parents' ages checked: pedsum's
  `birth_date_topology` compares the birth dates, to the day.
- The kit needs a pedsum with `--twin-max-days` and `birth_date_topology`. The pin in
  `pixi.toml` moves to the first pedsum release that has both.
- EPIMIGHT's sandwich SEs sum over every related pair up to `max_degree`, not over the
  analysis's relationship (`SandwichAnalysis-class.R:503` in epimight). Twins stay a
  dependent pair there, as they should, after they leave the `FS` counts.
- Two review proposals now belong in pedsum. One is a check for a placeholder parent
  code such as `9999`, which becomes a founder with thousands of children.
