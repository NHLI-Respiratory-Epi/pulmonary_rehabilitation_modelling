clear all
set more off

cd "E:\Mtech PR Modelling"

local start = clock("$S_DATE $S_TIME", "DMY hms")

local raw_data_dir "E:\AUK-BLF COPD Prevalence"

local analysis_dir "C:\Users\pstone\OneDrive - Imperial College London\Work\Mtech PR Modelling\Stata"

/* Create log file */
capture log close
log using "`analysis_dir'/build_logs/CombineNumeratorDenominator_stratified_v2", text replace

local study_start = date("01/01/2009", "DMY")
local study_end = date("31/12/2019", "DMY")

local split = 4   //number of part file is split in to
local cohorts = 5 //number of cohorts

local first_year = year(`study_start')
local last_year = year(`study_end')
local month = 7


use builds/cohort_prevalent_copd_stratvars_value_denom, clear


count

bysort region: summarize copd_prevalent_first copd_incident_first pr_eligible pr_considered pr_referred pr_commenced pr_completed, format

keep if prevalent == 1

bysort region: summarize pr_eligible pr_considered pr_referred pr_commenced pr_completed, format


/*
//Gender: Male
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte male`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& gender == 1
	
	replace male`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& gender == 1
	
	tab male`year'
}

//Gender: Female
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte female`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& gender == 2
	
	replace female`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& gender == 2
	
	tab female`year'
}



//Age
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen age`year' = `year' - yob if start_fu <= `date' & end_fu >= `date'
}

//40-49
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte age40`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 40 & age`year' < 50
	
	replace age40`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 40 & age`year' < 50
	
	tab age40`year'
}

//50-59
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte age50`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 50 & age`year' < 60
	
	replace age50`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 50 & age`year' < 60
	
	tab age50`year'
}

//60-69
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte age60`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 60 & age`year' < 70
	
	replace age60`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 60 & age`year' < 70
	
	tab age60`year'
}

//70-79
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte age70`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 70 & age`year' < 80
	
	replace age70`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 70 & age`year' < 80
	
	tab age70`year'
}

//80+
forvalues year = `first_year'/`last_year' {
	
	local date = mdy(`month', 1, `year')
	
	gen byte age80`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 80 & age`year' != .
	
	replace age80`year' = 1 if (start_fu <= `date') ///
									& (copd_validated_1st <= `date' ///
										| epistart_firstsecond <= `date') ///
									& (end_fu >= `date') ///
									& age`year' >= 80 & age`year' != .
	
	tab age80`year'
}
*/

//Region
label list Region
local region_min = r(min)
local region_max = 10 //r(max)

forvalues region = `region_min'/`region_max' {

	//People with COPD eligible for PR
	forvalues year = `first_year'/`last_year' {
		
		local date = mdy(`month', 1, `year')
		
		gen byte eligible`region'`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& (copd_prevalent_first <= `date') ///
									& region == `region'
		
		replace eligible`region'`year' = 1 if (start_fu <= `date') ///
										& (copd_prevalent_first <= `date') ///
										& (pr_eligible <= `date') ///
										& (end_fu >= `date') ///
										& region == `region'
		
		tab eligible`region'`year'
	}


	//People with COPD eligible for PR that were considered for PR
	forvalues year = `first_year'/`last_year' {
		
		local date = mdy(`month', 1, `year')
		
		gen byte considered`region'`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& (copd_prevalent_first <= `date') ///
									& (pr_eligible <= `date') ///
									& region == `region'
		
		replace considered`region'`year' = 1 if (start_fu <= `date') ///
										& (copd_prevalent_first <= `date') ///
										& (pr_eligible <= `date') ///
										& (pr_considered <= `date' ///
											| pr_referred <= `date' ///
											| pr_commenced <= `date' ///
											| pr_completed <= `date') ///
										& (end_fu >= `date') ///
										& region == `region'
		
		tab considered`region'`year'
	}


	//People with COPD eligible for PR that were referred for PR
	forvalues year = `first_year'/`last_year' {
		
		local date = mdy(`month', 1, `year')
		
		gen byte referred`region'`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& (copd_prevalent_first <= `date') ///
									& (pr_eligible <= `date') ///
									& region == `region'
		
		replace referred`region'`year' = 1 if (start_fu <= `date') ///
										& (copd_prevalent_first <= `date') ///
										& (pr_eligible <= `date') ///
										& (pr_referred <= `date' ///
											| pr_commenced <= `date' ///
											| pr_completed <= `date') ///
										& (end_fu >= `date') ///
										& region == `region'
		
		tab referred`region'`year'
	}


	//People with COPD eligible for PR that were referred for PR and then commenced PR
	forvalues year = `first_year'/`last_year' {
		
		local date = mdy(`month', 1, `year')
		
		gen byte commenced`region'`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& (copd_prevalent_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_referred <= `date') ///
									& region == `region'
		
		replace commenced`region'`year' = 1 if (start_fu <= `date') ///
										& (copd_prevalent_first <= `date') ///
										& (pr_eligible <= `date') ///
										& (pr_referred <= `date') ///
										& (pr_commenced <= `date' ///
											| pr_completed <= `date') ///
										& (end_fu >= `date') ///
										& region == `region'
		
		tab commenced`region'`year'
	}


	//People with COPD eligible for PR that were referred for PR and then completed PR
	forvalues year = `first_year'/`last_year' {
		
		local date = mdy(`month', 1, `year')
		
		gen byte completed`region'`year' = 0 if (start_fu <= `date') ///
									& (end_fu >= `date') ///
									& (copd_prevalent_first <= `date') ///
									& (pr_eligible <= `date') ///
									& (pr_referred <= `date') ///
									& region == `region'
		
		replace completed`region'`year' = 1 if (start_fu <= `date') ///
										& (copd_prevalent_first <= `date') ///
										& (pr_eligible <= `date') ///
										& (pr_referred <= `date') ///
										& (pr_completed <= `date') ///
										& (end_fu >= `date') ///
										& region == `region'
		
		tab completed`region'`year'
	}
}


compress
save copd_pr_strat, replace


preserve

collapse (count) eligible* considered* referred* commenced* completed*
generate var = "Denominator"

format %9.0g eligible* considered* referred* commenced* completed*

reshape long eligible1 considered1 referred1 commenced1 completed1 ///
			 eligible2 considered2 referred2 commenced2 completed2 ///
			 eligible3 considered3 referred3 commenced3 completed3 ///
			 eligible4 considered4 referred4 commenced4 completed4 ///
			 eligible5 considered5 referred5 commenced5 completed5 ///
			 eligible6 considered6 referred6 commenced6 completed6 ///
			 eligible7 considered7 referred7 commenced7 completed7 ///
			 eligible8 considered8 referred8 commenced8 completed8 ///
			 eligible9 considered9 referred9 commenced9 completed9 ///
			 eligible10 considered10 referred10 commenced10 completed10, i(var) j(year)

rename * *_denom
rename year_denom year
drop var_denom

tempfile denominator
save `denominator'

restore, preserve

collapse (sum) eligible* considered* referred* commenced* completed*
generate var = "Numerator"

reshape long eligible1 considered1 referred1 commenced1 completed1 ///
			 eligible2 considered2 referred2 commenced2 completed2 ///
			 eligible3 considered3 referred3 commenced3 completed3 ///
			 eligible4 considered4 referred4 commenced4 completed4 ///
			 eligible5 considered5 referred5 commenced5 completed5 ///
			 eligible6 considered6 referred6 commenced6 completed6 ///
			 eligible7 considered7 referred7 commenced7 completed7 ///
			 eligible8 considered8 referred8 commenced8 completed8 ///
			 eligible9 considered9 referred9 commenced9 completed9 ///
			 eligible10 considered10 referred10 commenced10 completed10, i(var) j(year)

rename * *_nume
rename year_nume year
drop var_nume

tempfile numerator
save `numerator'

restore

set type double

collapse (mean) eligible* considered* referred* commenced* completed*
generate var = "Prevalence (%)"

reshape long eligible1 considered1 referred1 commenced1 completed1 ///
			 eligible2 considered2 referred2 commenced2 completed2 ///
			 eligible3 considered3 referred3 commenced3 completed3 ///
			 eligible4 considered4 referred4 commenced4 completed4 ///
			 eligible5 considered5 referred5 commenced5 completed5 ///
			 eligible6 considered6 referred6 commenced6 completed6 ///
			 eligible7 considered7 referred7 commenced7 completed7 ///
			 eligible8 considered8 referred8 commenced8 completed8 ///
			 eligible9 considered9 referred9 commenced9 completed9 ///
			 eligible10 considered10 referred10 commenced10 completed10, i(var) j(year)

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

foreach var in eligible1 eligible2 eligible3 eligible4 eligible5 ///
			   eligible6 eligible7 eligible8 eligible9 eligible10 ///
			   considered10 referred10 commenced10 completed10 ///
			   eligible1 eligible2 eligible3 eligible4 eligible5 ///
			   eligible6 eligible7 eligible8 eligible9 eligible10 ///
			   referred1 referred2 referred3 referred4 referred5 ///
			   referred6 referred7 referred8 referred9 referred10 ///
			   commenced1 commenced2 commenced3 commenced4 commenced5 ///
			   commenced6 commenced7 commenced8 commenced9 commenced10 ///
			   completed1 completed2 completed3 completed4 completed5 ///
			   completed6 completed7 completed8 completed9 completed10 {
		
	if "`previous'" == "" {
		
		order `var'_nume `var'_denom `var'_prev, last
	}
	else {
		
		order `var'_nume `var'_denom `var'_prev, after(`previous'_prev)
	}
	
	local previous "`var'"
}

compress
save "`analysis_dir'/copd_pr_strat_collapsed", replace


xpose, clear varname
order _varname

export excel "`analysis_dir'/outputs/copd_pr_strat.xlsx", replace


use "`analysis_dir'/copd_pr_strat_collapsed", clear  //leave on this one as easier to work with


log close