# The shared analysis plan

Every site runs these plans unchanged, so the results can be compared and combined. A
change to them is a commit that every site pulls; `run.yaml` records the plan's
checksum, and two sites ran the same plan when their checksums match.

There are two plans over the same traits and settings. Run the initial analysis first:

| Plan | Analyses | h² | rg |
|---|---|---|---|
| `initial.yaml` | `analyses_initial.tsv` | every trait | the psychiatric traits with each other and with the cardiometabolic traits |
| `complete.yaml` | `analyses_complete.tsv` | every trait | every pair of traits |

Every rg is listed in both directions, and every analysis uses full siblings (FS), half
siblings (HS) and parents (PO). The initial plan has 57 h² and 480 rg analyses; the
complete one 57 h² and 1,026 rg analyses.

**These plans are preliminary.**

- `traits.tsv` has the 19 phenotypes of `Definitions/Phenotype_list.tsv`, named by their
  abbreviation, with no follow-up or second-trait rules yet: 5 psychiatric (MDD, ASD,
  BD, SCZ, SSD) and 14 cardiometabolic. Each site provides one trait file per phenotype,
  named `<abbreviation>.tsv` (for example `MDD.tsv`), in its data folder, built from the
  ICD-8, ICD-9 and ICD-10 codes in that list.
- Both plan files stratify by 5-year birth cohort and suppress counts from 1 to 5 in the
  exported results. Their settings must stay the same; the kit's tests check it.
