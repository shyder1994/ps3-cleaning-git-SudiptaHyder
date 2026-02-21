* Problem Set 3 — Cleaning Pipelines, Panel Checks
* Name: Sudipta Hyder

version 17
clear all
set more off

* 1) Set working directory + start log
cd "/Users/shyde/Desktop/pset3_data"

capture mkdir logs
capture mkdir processed_data

log using "logs/ps3.log", replace text

* 2) Part A = Data cleaning

disp "=== Cleaning people_full.csv ==="

import delimited "people_full.csv", clear varnames(1) stringcols(_all)

* Standardize strings: location and sex 
replace location = strtrim(location)
replace location = strlower(location)
replace location = strproper(location)

replace sex = strtrim(sex)
replace sex = strlower(sex)
replace sex = strproper(sex)

* Convert expected numeric columns (handle "NA")
foreach v in person_id household_id age height_cm weight_kg systolic_bp diastolic_bp {
    destring `v', replace ignore("NA")
}

* Convert date/time and  year
gen visit_date = date(date_str, "MDY")
format visit_date %td

* time_str is a time-of-day string; store as %tc with just HH:MM:SS display
gen double visit_time = clock(time_str, "hms")
format visit_time %tcHH:MM:SS

gen people_year = year(visit_date)

* QA checks
assert !missing(person_id)

* unique key
isid person_id people_year

* each non-missing person_id has 5 observations
bysort person_id: assert _N == 5 if !missing(person_id)

* Categorical encodings
encode sex, gen(sex_id)
encode location, gen(location_id)

* Grouping variables
sort household_id person_id people_year

bysort household_id: gen hh_n = _N
bysort household_id: gen hh_row = _n
bysort household_id: egen hh_mean_age = mean(age)

* Export cleaned file
export delimited using "processed_data/ps3_people_clean.csv", replace


* 3) Part A = Clean and validate households.csv

disp "=== Cleaning households.csv ==="

import delimited "households.csv", clear varnames(1) stringcols(_all)

* Convert numeric vars (handle "NA" if present)
foreach v in household_id year region_id income hh_size {
    destring `v', replace ignore("NA")
}

* Encode region into region_code and inspect labels
encode region, gen(region_code)
label list region_code

* Grouped variables
bysort year: egen year_mean_income = mean(income)

* mean income by region_code and year
bysort region_code year: egen region_year_mean_income = mean(income)

* within-region_code row index after sorting by year
sort region_code year
by region_code: gen region_year_row = _n

* Required regression
reg income i.region_code c.hh_size##c.year

* Export cleaned file
export delimited using "processed_data/ps3_households_clean.csv", replace


* 4) Part A = Clean and validate regions.csv as panel data
****************************************************
disp "=== Cleaning regions.csv (panel) ==="

import delimited "regions.csv", clear varnames(1) stringcols(_all)

* Convert numeric variables 
foreach v in region_id year median_income population {
    capture destring `v', replace ignore("NA")
}

* Drop rows with missing panel keys
drop if missing(region_id) | missing(year)

* Verify unique region_id year
isid region_id year

* Declare panel structure
xtset region_id year

*Generate YoY change + growth rate
gen yoy_change_median_income = median_income - L.median_income

gen median_income_growth_rate = .
replace median_income_growth_rate = (median_income - L.median_income) / L.median_income ///
    if !missing(median_income, L.median_income) & L.median_income != 0

*Panel summaries
xtdescribe
xtsum median_income population yoy_change_median_income median_income_growth_rate

* Export cleaned file
export delimited using "processed_data/ps3_regions_clean.csv", replace

* 6) Finalize, close log

log close
disp "DONE. Outputs saved in processed_data/ and log in logs/ps3.log"

*END*
