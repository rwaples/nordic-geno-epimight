# nordic-geno-epimight

A kit that collaborators run on their own register data to estimate heritability and
genetic correlation with EPIMIGHT, with pedigree-pair sandwich standard errors.

## Language

**Kit**:
This repository as a collaborator runs it: install, checks, building the cohort table, EPIMIGHT, output and plots.
_Avoid_: runner, pipeline (EPIMIGHT's `Pipeline` is a different thing)

**Plan**:
One plan file in `plan/` with the tables it names: the traits, the analyses and the shared settings, run unchanged at every site. There are two: the initial plan (`initial.yaml`, `analyses_initial.tsv`) and the complete plan (`complete.yaml`, `analyses_complete.tsv`); both use `traits.tsv`. A site file names one.
_Avoid_: config, study.yaml

**Site**:
One country's register data and the people who run the kit on it; a site file in `local/` says where its data are and when its follow-up ends.
_Avoid_: country (a country may have more than one site), node

**Export folder**:
`OUT/6_export/`, the only output a site sends on: aggregate results with small counts suppressed.
_Avoid_: results (the rest of `OUT/` holds individual-level data)

**Pedigree file**:
One row per person with their id, mother, father, sex and birth date, plus any stratify columns and the optional `birth_year`, multiple-birth id and `birth_place`.
_Avoid_: genealogy, parent table

**Multiple-birth set**:
Full siblings born in one delivery: twins, triplets and so on. pedsum finds them from birth dates (born at most a day apart), or reads them from the register's own id in the site's `multiple_birth_column`. A pair from one set is not an `FS` pair unless their known sexes differ; both stay probands and every other kind of relative.
_Avoid_: twin pair (a set may hold three or more), MZ (zygosity is unknown)

**Trait**:
A named definition in the trait list: one trait file plus the follow-up and second-trait rules applied to it.
_Avoid_: phenotype, variant

**Trait file**:
One file per trait, one row per person, with that person's status, status date and, for a case, ICD code.
_Avoid_: TTE table, phenotype file

**SAP**:
The statistical analysis plan the collaborators agreed, version 8: `docs/SAP_Scandinavian_Genealogy.md`. "SAP 4.1" means its section 4.1.
_Avoid_: protocol

**Window**:
One of the SAP's three analysis windows, W1, W2 and W3 (SAP 4.2): which diagnoses count, when follow-up ends and which probands enter. The kit can run W1 only, with one data folder per window.
_Avoid_: period

**pedsum**:
The Python tool that checks and repairs the pedigree file. It comes with the kit; the site runs it during step 0 and the check step runs it again.
_Avoid_: pedigree_summary.py (its old name)

**Founder row**:
A row pedsum adds to the pedigree for a parent who has no row of their own, with unknown parents and no birth date.

**Proband**:
A person whose own outcome is analysed, with their relatives' outcomes as family history. Every person in the study population is a proband for each trait, unless the trait's rules drop them. In the output tables the proband's trait is the `index_trait` (or `trait`).
_Avoid_: index person, case (a case is a proband with status 1)

**Study population**:
The people followed for every trait; each has exactly one row in every trait file.
_Avoid_: sample

**Status**:
A person's outcome for one trait: 1 the trait, 2 a competing event, 0 censored.
_Avoid_: failure status, affection

**Status date**:
The date that set a person's status: onset for 1, the competing event for 2, end of follow-up for 0. It lies between the person's birth date and `study_end`.
_Avoid_: event date, onset date (for anything but status 1)

**Age**:
A person's age at their status date, derived by the kit as `(status_date - birth_date) / 365.25`, then changed by the trait's rules where they censor at a follow-up limit or set a competing event at a second trait's onset, and floored to whole years in the cohort table. Never an input.
_Avoid_: failure time, trait time

**Stratum**:
One group of the study population by the plan's `stratify` columns, such as a `birth_year_bin`-year birth-year bin. EPIMIGHT estimates each stratum and then pools them with fixed effects into a pooled row.
_Avoid_: batch, cohort

**Relationship**:
One of eight fixed kinds of relative (PO, FS, HS, mHS, pHS, Av, 1G, 1C), each with a fixed relatedness.
_Avoid_: relationship kind; `relatives_kind` is EPIMIGHT's column name for it, kept in `cohort.tsv` and `cohort_summary.tsv`

**h², rg, CIF**:
Heritability (h², the share of liability to a trait due to additive genetics), genetic correlation (rg, between two traits) and cumulative incidence (CIF, the share of people with the trait by each age, allowing for competing events). EPIMIGHT estimates h² and rg from how much more often probands with an affected relative have the trait.
_Avoid_: CIP

**Sandwich SE**:
A standard error that allows for the same person appearing in many relative pairs, computed from the pedigree's pairs up to the plan's `max_degree`. Report its interval. `se_native` is EPIMIGHT's SE that treats every pair as independent, kept only for comparison.
_Avoid_: robust SE

**Analysis**:
One EPIMIGHT estimate requested in the analysis list: h² for a trait, or rg for one direction between two traits, for one relationship.
_Avoid_: job, call

**Cohort table**:
EPIMIGHT's input table, one row per proband, trait and relationship, built by the kit.
_Avoid_: pool (EPIMIGHT's argument name), TTE, long table

**Population cohort**, **family-history cohort**, **cross cohort**:
The subsets of the cohort table EPIMIGHT draws for one analysis: everyone with the trait's rows; those with an affected relative of one relationship; the same for another trait's relatives.
_Avoid_: bare "cohort" for any of these

**Step**:
One of the kit's commands, run in order: check, cohort, epimight, tables, report, export, each writing `OUT/<n>_<step>/`. `pixi run study` runs all six. **Step 0** is the site's own data preparation before them (`docs/step-0.md`); `pixi run setup`, which builds the software, is not a step.
_Avoid_: stage, phase

**Finding**:
One problem a step found, with a code and a severity: STOP ends the run, WARN doesn't. Written to `findings.tsv` in the step's folder.
_Avoid_: error, issue

## Relationships

- A **Trait file** gives each person one **Status** and one **Status date**; the kit derives the **Age** from it and the **Pedigree file**'s birth date
- Every **Trait file** covers the same **Study population**
- A **Trait** uses exactly one **Trait file**; a **Trait file** may serve several **Traits**
- An **Analysis** names one or two **Traits** and one **Relationship**
- Every **Site** runs the same **Plan** on its own **Pedigree file** and **Trait files**, and sends only its **Export folder**
- The kit builds one **Cohort table** from the **Pedigree file** and every **Trait**
- Each **Analysis** draws a **Population cohort** and a **family-history** or **cross cohort** from the **Cohort table**

## Flagged ambiguities

- "pool" (EPIMIGHT's word) and "cohort" both named the kit's built table: resolved as **Cohort table**; a bare "cohort" is avoided, since EPIMIGHT's subsets are also cohorts.
- "study" survives in code for the site file and plan read together (`read_study`, `inputs$study`), in the all-steps command `pixi run study`, and in the `config_*` finding codes. These names are kept; in prose say site file, plan or **Step**.
