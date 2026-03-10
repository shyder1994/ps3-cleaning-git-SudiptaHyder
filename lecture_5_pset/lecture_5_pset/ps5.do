* PS5 Homework dataset
* Name: Sudipta Hyder

clear all
set more off

* 1. Begin logging
cd "/Users/shyde/Desktop/Ps5"
capture mkdir "logs"
capture mkdir "processed_data"

capture log close
log using "logs/ps5.log", replace text

* 2. Loading dataset (dta file)
use "ps5_data.dta", clear

ds
local nvars : word count `r(varlist)'
display as txt "Number of variables in dataset: `nvars'"

* 3. Defining local macros for variable groups
local numeric_vars "AGEP WAGP WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP PWGTP"
local categorical_vars "NAICSP SOCP"

display as txt "numeric_vars: `numeric_vars'"
display as txt "categorical_vars: `categorical_vars'"

* 4. Clean numeric variables 
foreach v of local numeric_vars {
   capture confirm variable `v'
    if _rc == 0 {
  capture confirm numeric variable `v'
    if _rc {
replace `v' = "" if inlist(strtrim(`v'), "NA", ".", "")
destring `v', replace
        }
    }
    else {
        display as error "Variable not found: `v'"
    }
}

* 5. Encoding and cleaning categorical variables
foreach v of local categorical_vars {

capture confirm variable `v'
if _rc == 0 {

capture confirm string variable `v'
if _rc == 0 {
            replace `v' = strtrim(`v')
            replace `v' = strlower(`v')
            replace `v' = strproper(`v')
        }

        capture confirm variable `v'_id
        if _rc {
            encode `v', gen(`v'_id)
        }

    }
    else {
display as error "Variable not found: `v'"
    }
}

* 6. QA checks
count if missing(SERIALNO)
display as txt "Missing SERIALNO: " r(N)

count if missing(SPORDER)
display as txt "Missing SPORDER: " r(N)

duplicates report SERIALNO SPORDER
isid SERIALNO SPORDER

save "processed_data/ps5_cleaned_full.dta", replace

* 7. Building sample construction table
tempname sample_post
tempfile sample_steps

postfile `sample_post' str80 step int n_remaining int n_excluded using "`sample_steps'", replace

count
local n_prev = r(N)
post `sample_post' ("Start: imported observations") (`n_prev') (0)

keep if inrange(AGEP, 25, 64)
count
local n_now = r(N)
post `sample_post' ("Inclusion: age 25 to 64") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

keep if WAGP > 0 & WKHP >= 35
count
local n_now = r(N)
post `sample_post' ("Inclusion: WAGP > 0 and WKHP >= 35") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

keep if inlist(ESR, 1, 2)
count
local n_now = r(N)
post `sample_post' ("Inclusion: ESR is 1 or 2") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

drop if missing(AGEP, SCHL, PINCP, POVPIP, ESR, COW, MAR, SEX, RAC1P, HISP, PWGTP, NAICSP_id, SOCP_id)
count
local n_now = r(N)
post `sample_post' ("Exclusion: missing key model covariates or encoded IDs") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'


capture gen ln_wage = ln(WAGP)
label var ln_wage "Log wage income"

postclose `sample_post'

preserve
use "`sample_steps'", clear
export delimited using "processed_data/ps5_sample_construction.csv", replace
restore

* 8. Macros for model specification
local outcome "ln_wage"
local covariates_demo "c.AGEP i.SEX i.RAC1P i.HISP i.MAR"
local covariates_humancap "c.SCHL c.PINCP c.POVPIP"
local covariates_labor "c.WKHP i.ESR i.COW"
local covariates_occ "i.NAICSP_id i.SOCP_id"
local model_covariates "`covariates_demo' `covariates_humancap' `covariates_labor' `covariates_occ'"

display as txt "Outcome macro: `outcome'"
display as txt "Model covariates macro: `model_covariates'"

* 9. Means and SDs
local qa_vars "AGEP WAGP WKHP SCHL PINCP POVPIP"

foreach v of local qa_vars {
    quietly summarize `v'
    display as txt "`v': N=" %8.0f r(N) " mean=" %10.3f r(mean) " sd=" %10.3f r(sd)
}

* 10. Hours cutoffs
forvalues cutoff = 35/40 {
quietly count if WKHP >= `cutoff'
display as txt "Observations with WKHP >= `cutoff': " %8.0f r(N)
}

* 11. Doing the regressions
reg `outcome' `covariates_demo', vce(robust)
estimates store m1

reg `outcome' `covariates_demo' `covariates_humancap', vce(robust)
estimates store m2

reg `outcome' `model_covariates', vce(robust)
estimates store m3

* 12. Macro-based keep list
local keepvars "SERIALNO SPORDER PWGTP AGEP WAGP WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP NAICSP SOCP NAICSP_id SOCP_id ln_wage"

foreach v of local keepvars {
capture confirm variable `v'
if _rc {
display as error "Missing keep variable: `v'"
    }
}

keep `keepvars'

save "processed_data/ps5_analysis_data.dta", replace

* 13. Closing log
log close

* END
