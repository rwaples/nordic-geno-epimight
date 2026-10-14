# The shared analysis plan

Every site runs this plan unchanged, so the results can be compared and combined. A
change to it is a commit that every site pulls; `run.yaml` records its checksum, and two
sites ran the same plan when their checksums match.

**This plan is preliminary.**

- `traits.tsv` has the 19 phenotypes of `Definitions/Phenotype_list.tsv`, named by their
  abbreviation, with no follow-up or second-trait rules yet. Each site provides one trait
  file per phenotype, named `<abbreviation>.tsv` (for example `MDD.tsv`), in its data
  folder, built from the ICD-8, ICD-9 and ICD-10 codes in that list.
- `analyses.tsv` is a placeholder until the analyses are agreed: h² of every trait from
  full siblings (FS), half siblings (HS) and parents (PO), and no rg.
- `plan.yaml` stratifies by 5-year birth cohort and suppresses counts from 1 to 5 in the
  exported results.

The trait `HS` (haemorrhagic stroke) shares its code with the half-sibling relationship
`HS`. The kit keeps them apart, but tables that show both are easy to misread.
