# The shared analysis plan

Every site runs these plans unchanged, so the results can be compared and combined. A
change to them is a commit that every site pulls, or a new image for sites that use one; `run.yaml` records the plan's
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
- Both plan files stratify by 5-year birth cohort and suppress counts from 1 to 5
  (`export_min_count`) in the exported results. Their settings must stay the same; the kit's tests check it.

## Plan file settings

This section and the next are a reference for whoever changes the plan; a site doesn't
edit these files. Each plan file looks like this:

```yaml
traits: traits.tsv
analyses: analyses_initial.tsv
relative_windows: relative_windows.tsv   # optional
stratify: [birth_year]                   # pedigree columns, or birth_year
birth_year_bin: 5                        # default 1
max_degree: 3                            # 1 to 5, default 3
export_min_count: 5                      # default 5
```

EPIMIGHT estimates each stratum separately and then pools them. `birth_year` is the year
of `birth_date`, grouped into `birth_year_bin`-year bins named by their first year.

`max_degree` sets which relative pairs enter the sandwich SE (see the
[glossary](../docs/glossary.md)). It must reach the furthest
relationship analysed: 1 for PO and FS, 2 for HS, mHS, pHS, Av and 1G, 3 for 1C.

## traits.tsv

One row per trait. A trait is a name, a file and optional rules. Several traits can share
a file.

| Column | Meaning |
|---|---|
| `trait` | Name used in the analyses: letters, digits, `_`, `.` or `-` |
| `type` | `tte` (time to event), the only type so far |
| `file` | The trait file's name in each site's data folder |
| `min_followup` | Drop probands born fewer than this many years before `study_end` |
| `max_followup` | Follow every proband for this many years. Drop those born too late, and censor later events at this age |
| `max_followup_relatives` | The same window for relatives. Empty means the same as `max_followup`; `none` means no window |
| `trait2` | Another trait whose onsets the next four columns use |
| `exclude_trait2` | When a `trait2` onset flags a proband: `none` (default), `before`, `after` or `any`. The same age counts as before |
| `trait2_window` | Years between the two onsets. Empty means any gap |
| `trait2_window_type` | `within` (default): gap at most the window. `at_least`: gap at least the window |
| `trait2_action` | `exclude` (default) drops flagged probands. `competing` keeps them, with a competing event at the `trait2` onset; it needs `before` |
| `filter_relatives` | `TRUE` also applies the proband rules to relatives. Default `FALSE` |

The rules follow `R/make_epimight_tte.R`, and the self-test checks that the kit builds the
same table as that script for every rule. An example, with empty columns left out:

```
trait      type  file      max_followup  trait2  exclude_trait2  trait2_action
adhd_fu20  tte   adhd.tsv  20
adhd_fu30  tte   adhd.tsv  30
mdd        tte   mdd.tsv                 bip     before          competing
bip        tte   bip.tsv
```

`adhd_fu20` and `adhd_fu30` follow the same people for 20 and 30 years. In `mdd`, a BIP
onset before MDD ends MDD follow-up as a competing event.

## relative_windows.tsv

Optional. Sets `max_followup_relatives` for one trait and relationship. This row follows
parents for 50 years while probands get 20:

```
trait      relationship  max_followup_relatives
adhd_fu20  PO            50
```

## The analyses tables

`plan/analyses_initial.tsv` and `plan/analyses_complete.tsv`, one per plan. One row per estimate, with `analysis_id, analysis, trait, relatives_trait, relationship`.
`analysis_id` is your name for the estimate and appears on every output row.

`analysis` is `h2` or `rg`. For h2, `relatives_trait` equals `trait`. For rg, the estimate
uses the `trait` outcomes of probands whose relatives have `relatives_trait`. That is one
direction, so list both rows if you want both.

| `relationship` | Relatives | Relatedness |
|---|---|---|
| `PO` | parents | 0.5 |
| `FS` | full siblings, except members of one multiple birth not known to differ in sex | 0.5 |
| `HS` | half siblings | 0.25 |
| `mHS`, `pHS` | maternal or paternal half siblings | 0.25 |
| `Av` | aunts and uncles | 0.25 |
| `1G` | grandparents | 0.25 |
| `1C` | first cousins | 0.125 |

`HS` is also the abbreviation of the trait haemorrhagic stroke, so an analysis id such as
`h2_HS_HS` is h² of haemorrhagic stroke from half siblings (open question 4 asks to
rename the trait).

### Which relatives count

A relative counts only if they have a row in the trait file. PO, Av and 1G follow the
pedigree, not birth order: an uncle younger than his nephew is still his uncle.

Two members of one multiple-birth set (step 0) are not each other's `FS` relatives when
they have the same sex, or either sex is unknown, since they may be MZ twins. A boy-girl
pair is fraternal and stays `FS` (SAP version 8, 4.1). Each pair in a set of three or more
is judged by its own two sexes. Twins stay probands, and each stays every other kind of
relative: a twin's children are still the co-twin's nieces and nephews. Zygosity is
unknown, so the kit doesn't count any pair as MZ. The sandwich SEs still treat the twins
as a related pair.

