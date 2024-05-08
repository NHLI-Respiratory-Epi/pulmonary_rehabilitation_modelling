clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/CombineNumeratorDenominator_v2_qof", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts

local first_year = year(`study_start')
local last_year = year(`study_end')
local month = 7



use builds/cohort_qof_copd_stratvars_value_denom_eligible, clear


count

summarize copd_qof_first pr_eligible pr_considered pr_referred pr_commenced pr_completed, format


//Prevalent QOF COPD
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte prevalent`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date')
	
	replace prevalent`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (end_fu >= `date')
	
	tab prevalent`year'
}


//Incident QOF COPD
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	local previous_date = mdy(`month', 1, `year'-1)
	
	gen byte incident`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date')
	
	replace incident`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (copd_qof_first > `previous_date') ///
									& (end_fu >= `date')
	
	tab incident`year'
}


//People with QOF COPD eligible for PR
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte eligible`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date') ///
								& (copd_qof_first <= `date')
	
	replace eligible`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (end_fu >= `date')
	
	tab eligible`year'
}


//People with QOF COPD eligible for PR that were considered for PR
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte considered`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date') ///
								& (copd_qof_first <= `date') ///
								& (pr_eligible <= `date') 
	
	replace considered`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_considered <= `date' ///
										| pr_referred <= `date' ///
										| pr_commenced <= `date' ///
										| pr_completed <= `date') ///
									& (end_fu >= `date')
	
	tab considered`year'
}


//People with QOF COPD eligible for PR that were referred for PR
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte referred`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date') ///
								& (copd_qof_first <= `date') ///
								& (pr_eligible <= `date') 
	
	replace referred`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_referred <= `date' ///
										| pr_commenced <= `date' ///
										| pr_completed <= `date') ///
									& (end_fu >= `date')
	
	tab referred`year'
}


//People with QOF COPD eligible for PR that were referred for PR and then commenced PR
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte commenced`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date') ///
								& (copd_qof_first <= `date') ///
								& (pr_eligible <= `date') ///
								& (pr_referred <= `date')
	
	replace commenced`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_referred <= `date') ///
									& (pr_commenced <= `date' ///
										| pr_completed <= `date') ///
									& (end_fu >= `date')
	
	tab commenced`year'
}


//People with COPD eligible for PR that were referred for PR and then completed PR
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte completed`year' = 0 if (start_fu <= `date') ///
								& (end_fu >= `date') ///
								& (copd_qof_first <= `date') ///
								& (pr_eligible <= `date') ///
								& (pr_referred <= `date') ///
								& (pr_commenced <= `date')
	
	replace completed`year' = 1 if (start_fu <= `date') ///
									& (copd_qof_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_referred <= `date') ///
									& (pr_commenced <= `date') ///
									& (pr_completed <= `date') ///
									& (end_fu >= `date')
	
	tab completed`year'
}


compress
save copd_pr_qof, replace


preserve

collapse (count) prevalent20* incident20* eligible20* considered20* referred20* commenced20* completed20*
generate var = "Denominator"

format %9.0g prevalent20* incident20* eligible20* considered20* referred20* commenced20* completed20*

reshape long prevalent incident eligible considered referred commenced completed, i(var) j(year)

rename * *_denom
rename year_denom year
drop var_denom

tempfile denominator
save `denominator'

restore, preserve

collapse (sum) prevalent20* incident20* eligible20* considered20* referred20* commenced20* completed20**
generate var = "Numerator"

reshape long prevalent incident eligible considered referred commenced completed, i(var) j(year)

rename * *_nume
rename year_nume year
drop var_nume

tempfile numerator
save `numerator'

restore

set type double

collapse (mean) prevalent20* incident20* eligible20* considered20* referred20* commenced20* completed20*

generate var = "Prevalence (%)"

reshape long prevalent incident eligible considered referred commenced completed, i(var) j(year)

rename * *_prev
rename year_prev year
drop var_prev

//Convert to %
foreach var of varlist _all {
	
	if strmatch("`var'", "*_prev") {
		display "`var'"
		replace `var' = round(`var' * 100, 0.01)
		format %9.2f `var'
	}
}

merge 1:1 year using `denominator', nogenerate
merge 1:1 year using `numerator', nogenerate


//Order nicely
local previous ""

foreach var in prevalent incident eligible considered referred commenced completed {
	
	if "`previous'" == "" {
		
		order `var'_nume `var'_denom `var'_prev, last
	}
	else {
		
		order `var'_nume `var'_denom `var'_prev, after(`previous'_prev)
	}
	
	local previous "`var'"
}


label var year "Year"
label var prevalent_prev "Prevalent COPD"
label var incident_prev "Incident COPD"
label var eligible_prev "People with prevalent COPD who are eligible for PR"
label var considered_prev "People with prevalent COPD who are eligible for PR that were considered for PR"
label var referred_prev "People with prevalent COPD who are eligible for PR that were referred for PR"
label var commenced_prev "People with prevalent COPD who are eligible for PR that were referred for PR and then commenced a PR programme"
label var completed_prev "People with prevalent COPD who are eligible for PR that were referred for PR and then completed a PR programme"


compress
save "`analysis_dir'/copd_pr_collapsed_qof", replace


xpose, clear varname
order _varname

export excel "`analysis_dir'/outputs/copd_pr_qof.xlsx", replace


use "`analysis_dir'/copd_pr_collapsed_qof", clear  //leave on this one as easier to work with


log close