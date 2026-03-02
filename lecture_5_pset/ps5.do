* PS5: Real ACS Data Cleaning with Macros and Git
* Name: Sudipta Hyder

clear all
set more off

* 1) Working directory + log

cd "/Users/shyde/Desktop/Ps5"

cap mkdir "logs"
cap mkdir "processed_data"

capture log close
log using "logs/ps5.log", text replace

* 2) Importing CSV file (do NOT force all columns to strings)
import delimited "psam_p50.csv", varnames(1) clear
rename *, upper

* Verify more than 100 vars using ds
ds
local k : word count `r(varlist)'
display "Number of variables in memory = `k'"

* 3) Macros for numeric + categorical vars and cleaning loops
* Required macros
local numeric_vars AGEP WAGP WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP ADJINC PWGTP
local categorical_vars NAICSP SOCP

* Display macro contents in the log
display "numeric_vars: `numeric_vars'"
display "categorical_vars: `categorical_vars'"

* 3a) Loop over numeric_vars
foreach v of local numeric_vars {

    * Verify variable exists
capture confirm variable `v'
if _rc {
display as error "MISSING REQUIRED VAR: `v'"
exit 198
    }

* If already numeric, do nothing. If not, clean and destring
capture confirm numeric variable `v'
if _rc {

* It is string/non-numeric storage
replace `v' = trim(`v')
replace `v' = "" if inlist(`v', "NA", ".", "")
destring `v', replace
    }
}

* 3b. Loop over categorical_vars: clean + encode to _id
foreach c of local categorical_vars {

capture confirm variable `c'
if _rc {
display as error "MISSING REQUIRED VAR: `c'"
exit 198
    }

* Make sure to have a string to encode
capture confirm string variable `c'
 if _rc {
tostring `c', replace
    }

* Clean formatting
replace `c' = trim(`c')
replace `c' = upper(`c')
replace `c' = "" if inlist(`c', "NA", ".", "")

* Encode to numeric id variable
    encode `c', gen(`c'_id)
}

* 4) QA checks + save cleaned full file
misstable summarize SERIALNO SPORDER
duplicates report SERIALNO SPORDER
isid SERIALNO SPORDER

save "processed_data/ps5_cleaned_full.dta", replace

* 5) Sample construction table using postfile
tempfile sampsteps
tempname posth

postfile `posth' str50 step long remaining long excluded using `sampsteps', replace

* Baseline
count
local N0 = r(N)
post `posth' ("Start (full cleaned)") (`N0') (0)

* Keep ages 25–64
count
local before = r(N)
keep if inrange(AGEP, 25, 64)
count
local after = r(N)
post `posth' ("Keep AGEP 25-64") (`after') (`before' - `after')

* Keep WAGP > 0 and WKHP >= 35
count
local before = r(N)
keep if WAGP > 0 & WKHP >= 35
count
local after = r(N)
post `posth' ("Keep WAGP>0 & WKHP>=35") (`after') (`before' - `after')

* Keep ESR in employed categories (1 or 2)
count
local before = r(N)
keep if inlist(ESR, 1, 2)
count
local after = r(N)
post `posth' ("Keep ESR in {1,2}") (`after') (`before' - `after')

* Create ln_wage
gen ln_wage = ln(WAGP)

* Drop missing values in key model covariates
count
local before = r(N)
drop if missing(ln_wage, AGEP, WKHP, SCHL, ESR, COW, MAR, SEX, RAC1P, HISP, ///
                PINCP, POVPIP, ADJINC, PWGTP, NAICSP_id, SOCP_id)
count
local after = r(N)
post `posth' ("Drop missing key covariates + IDs") (`after') (`before' - `after')

postclose `posth'

* Export sample construction table without losing analysis dataset
preserve
    use `sampsteps', clear
    export delimited using "processed_data/ps5_sample_construction.csv", replace
restore

* 6) Macros for model specs + QA loops + regressions
local outcome ln_wage

local covariates_demo     c.AGEP i.SEX i.RAC1P i.HISP i.MAR
local covariates_humancap i.SCHL
local covariates_labor    c.WKHP i.COW i.ESR
local covariates_occ      i.NAICSP_id i.SOCP_id

local model_covariates `covariates_demo' `covariates_humancap' `covariates_labor' `covariates_occ'

display "outcome: `outcome'"
display "model_covariates: `model_covariates'"

* Report means/SDs
local qa_vars AGEP WAGP WKHP PINCP POVPIP
foreach q of local qa_vars {
quietly summarize `q'
    display "`q'  mean=" %9.3f r(mean) "   sd=" %9.3f r(sd)
}

* forvalues loop: counts for WKHP >= cutoff
forvalues cutoff = 35(5)55 {
quietly count if WKHP >= `cutoff'
    display "Count with WKHP >= `cutoff' : " r(N)
}

* Regressions
estimates clear

reg `outcome' `covariates_demo' [pw=PWGTP]
estimates store m1

reg `outcome' `covariates_demo' `covariates_humancap' `covariates_labor' [pw=PWGTP]
estimates store m2

reg `outcome' `model_covariates' [pw=PWGTP]
estimates store m3

estimates table m1 m2 m3, b(%9.3f) se(%9.3f) stats(N r2)
* 7) Required macro-based keep list + save analysis dataset
local keepvars SERIALNO SPORDER ///
    AGEP WAGP ln_wage WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP ADJINC PWGTP ///
    NAICSP SOCP NAICSP_id SOCP_id

foreach k of local keepvars {
    capture confirm variable `k'
    if _rc {
        display as error "keepvars contains missing variable: `k'"
        exit 198
    }
}

keep `keepvars'
save "processed_data/ps5_analysis_data.dta", replace


* Close log
log close
* End
