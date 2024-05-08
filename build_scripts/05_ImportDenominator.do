clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/ImportDenominator", text replace

local lookup_dir "Z:\Database guidelines and info\CPRD\CPRD_Latest_Lookups_Linkages_Denominators\Aurum_Lookups_May_2021"
local linked_dir "E:\AUK-BLF COPD Prevalence\CPRD Full Linked Data (2)\21_000596_Results\Aurum_linked\Final"

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts

local first_year = year(`study_start')
local last_year = year(`study_end')
local month = 7



//Open and format denominator file

import delimited "`raw_data_dir'/CPRD/Aurum_Denominators_May_2021/202105_CPRDAurum_AcceptablePats.txt", stringcols(1)


drop mob  //not needed - only children have month of birth

cprddate emis_ddate regstartdate regenddate cprd_ddate lcd

cprdlabel region, lookup("Region") location("`lookup_dir'")


tab1 gender patienttypeid acceptable region, missing

//reformat gender to have same numeric format as in Patient file
tab gender
replace gender = "1" if gender == "M"
replace gender = "2" if gender == "F"
replace gender = "3" if gender == "I"
replace gender = "4" if gender == "U"
destring gender, replace
cprdlabel gender, lookup("Gender") location("`lookup_dir'")
tab gender

//restrict to male and female patients
tab gender, missing
keep if gender == 1 | gender == 2
tab gender, missing

drop patienttypeid  //all "Regular"
drop acceptable  //all acceptable


summarize yob emis_ddate regstartdate regenddate cprd_ddate uts lcd, format

drop uts  //no up-to-standard date yet in Aurum
drop emis_ddate  //apparently not very reliable, use cprd_ddate instead


//Check all date variables & remove if after cut date (May 2021)
summarize yob regstartdate regenddate cprd_ddate lcd, format detail
drop if regstartdate >= mdy(5, 1, 2021)
drop if regenddate >= mdy(5, 1, 2021) & regenddate != .
drop if cprd_ddate >= mdy(5, 1, 2021) & cprd_ddate != .
drop if lcd >= mdy(5, 1, 2021)
summarize yob regstartdate regenddate cprd_ddate lcd, format


//Assume born on 1st Jan for max follow-up
gen dob = mdy(1, 1, yob)
gen do35 = mdy(1, 1, yob+35)
order dob do35, after(yob)
format %td dob do35


preserve //=====================================================================

//Import linkage information

import delimited "`raw_data_dir'/CPRD/Aurum_Linkages_Set_21/linkage_eligibility.txt", clear stringcols(1)

drop death_e cr_e mh_e

cprddate linkdate
tab linkdate, missing
drop linkdate  //they're all the same and this does not affect follow-up time

compress
tempfile link_eligibility
save `link_eligibility'


import delimited "`raw_data_dir'/CPRD/Aurum_Linkages_Set_21/linkage_coverage.txt", clear varnames(1)

cprddate start end

compress
tempfile link_coverage
save `link_coverage'


//Import IMD Data

import delimited "`linked_dir'/patient_imd2015_21_000596_request2.txt", clear stringcols(1)

tempfile imd
save `imd'

restore //======================================================================

//Merge linkage information with denomiantor file
count
merge 1:1 patid using `link_eligibility'
keep if _merge == 3
drop _merge

tab1 hes_e lsoa_e, missing
keep if hes_e == 1 & lsoa_e == 1
tab1 hes_e lsoa_e, missing
drop hes_e lsoa_e

gen data_source = "hes_apc"
merge m:1 data_source using `link_coverage'
drop if _merge == 2
drop _merge data_source
rename start hes_start
rename end hes_end


//Merge with linked IMD data
merge 1:1 patid using `imd'
drop if _merge == 2
drop _merge


//Calculate follow-up
//require to be at least 35
//require 1 year of follow-up before entering cohort
gen start_fu = max(regstartdate+365.25, hes_start, `study_start', do35)
gen end_fu = min(regenddate, cprd_ddate, lcd, hes_end, `study_end')
format %td start_fu end_fu
drop if start_fu >= end_fu

summarize start_fu end_fu, format detail



compress
save builds/Denominator, replace


//Add denominator to cohorts
foreach cohort in prevalent incident qof {
	
	display "Cohort: `cohort'"
	
	use builds/cohort_`cohort'_copd_stratvars_value, clear

	merge 1:1 patid using builds/Denominator
	
	generate byte `cohort' = (_merge != 2)
	order `cohort', after(end_fu)
	drop _merge
	
	//Make sure at least 35 years old at diagnosis
	display "Dropping patients under 35 at time of diagnosis..."
	drop if copd_`cohort'_age < 35
	
	//Generate age for each year
	forvalues year = `first_year'/`last_year' {
		
		generate age`year' = `year' - yob
	}

	//Remove patients with awkward event dates
	display "Dropping patients considered for PR before their diagnosis..."
	drop if pr_considered < copd_`cohort'_first & copd_`cohort'_first != .
	
	display "Dropping patients who commenced PR before their diagnosis..."
	drop if pr_commenced < copd_`cohort'_first & copd_`cohort'_first != .
	
	display "Removing eligibility events that occur after completion of PR..."
	replace pr_eligible = . if pr_completed < pr_eligible
	
	display "Events before diagnosis..."
	count if pr_eligible < copd_`cohort'_first
	count if pr_considered < copd_`cohort'_first
	count if pr_referred < copd_`cohort'_first
	count if pr_commenced < copd_`cohort'_first
	count if pr_completed < copd_`cohort'_first
	
	display "Events before eligible..."
	count if pr_considered < pr_eligible & pr_eligible != .
	count if pr_referred < pr_eligible & pr_eligible != .
	count if pr_commenced < pr_eligible & pr_eligible != .
	count if pr_completed < pr_eligible & pr_eligible != .
	
	display "Events before referred..."
	count if pr_commenced < pr_referred & pr_referred != .
	count if pr_completed < pr_referred & pr_referred != .

	compress
	save builds/cohort_`cohort'_copd_stratvars_value_denom, replace
}



log close