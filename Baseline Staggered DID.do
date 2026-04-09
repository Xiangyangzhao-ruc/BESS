est clear
capture postclose buffer 
capture mkdir "Figures"
capture mkdir "Placebo_Plots"
capture mkdir "Margins_Plots" 
set scheme s1color 

xtset city_code year
capture confirm string variable prov
if _rc==0 encode prov, gen(prov_id)

winsor2 IPAG_A IPAG_M IPAG_K POP PGDP PM25 AKNOWL pol_acc pol_rate, replace cuts(1 99)

foreach v in IPAG_A IPAG_M IPAG_K {
    capture drop ln_`v'
    gen ln_`v' = ln(`v' + 1)
}
capture drop ln_POP ln_PGDP ln_PM25 ln_AKNOWL
gen ln_POP    = ln(POP)
gen ln_PGDP   = ln(PGDP)
gen ln_PM25   = ln(PM25)
gen ln_AKNOWL = ln(AKNOWL + 1)
global controls "ln_POP ln_PGDP STRUC ln_PM25 ln_AKNOWL"

capture drop treat_post treat_post_ln_pol treat_post_ln_rate event_time pre_* post_* current adopt_year
bysort city_code: egen temp_min = min(year) if pol_acc > 0
bysort city_code: egen adopt_year = min(temp_min)
replace adopt_year = 0 if missing(adopt_year)
drop temp_min

gen treat_post = (year >= adopt_year & adopt_year > 0)

bysort city_code: egen max_pol = max(pol_acc)
replace max_pol = 0 if missing(max_pol)
gen ln_max_pol = ln(max_pol + 1)

bysort city_code: egen max_rate = max(pol_rate)
replace max_rate = 0 if missing(max_rate)
gen ln_max_rate = ln(max_rate + 1) 

gen treat_post_ln_pol  = treat_post * ln_max_pol
gen treat_post_ln_rate = treat_post * ln_max_rate

gen event_time = year - adopt_year
replace event_time = . if adopt_year == 0 

gen pre_5 = (event_time <= -5 & event_time != .)
forvalues i = 4(-1)2 {
    gen pre_`i' = (event_time == -`i' & event_time != .)
}
gen pre_1 = 0  

gen current = (event_time == 0 & event_time != .)

forvalues i = 1(1)4 {
    gen post_`i' = (event_time == `i' & event_time != .)
}
gen post_5 = (event_time >= 5 & event_time != .)

local d_list "pre_5 pre_4 pre_3 pre_2 pre_1 current post_1 post_2 post_3 post_4 post_5"
foreach d in `d_list' {
    gen c_`d' = `d' * ln_max_pol
    gen r_`d' = `d' * ln_max_rate
}

global event_dummies "pre_5 pre_4 pre_3 pre_2 pre_1 current post_1 post_2 post_3 post_4 post_5"
global c_event_dummies "c_pre_5 c_pre_4 c_pre_3 c_pre_2 c_pre_1 c_current c_post_1 c_post_2 c_post_3 c_post_4 c_post_5"
global r_event_dummies "r_pre_5 r_pre_4 r_pre_3 r_pre_2 r_pre_1 r_current r_post_1 r_post_2 r_post_3 r_post_4 r_post_5"

local rnm_rule "pre_5=-5 pre_4=-4 pre_3=-3 pre_2=-2 pre_1=-1 current=0 post_1=1 post_2=2 post_3=3 post_4=4 post_5=5"
local c_rnm_rule "c_pre_5=-5 c_pre_4=-4 c_pre_3=-3 c_pre_2=-2 c_pre_1=-1 c_current=0 c_post_1=1 c_post_2=2 c_post_3=3 c_post_4=4 c_post_5=5"
local r_rnm_rule "r_pre_5=-5 r_pre_4=-4 r_pre_3=-3 r_pre_2=-2 r_pre_1=-1 r_current=0 r_post_1=1 r_post_2=2 r_post_3=3 r_post_4=4 r_post_5=5"

foreach m in A M K {
    display ">>> Processing Method `m' ..."
    
    reghdfe ln_IPAG_`m' treat_post, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Bas_Bin
    reghdfe ln_IPAG_`m' treat_post $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Avg_Bin
    global TB_`m'_Bin = _b[treat_post] 
    
    reghdfe ln_IPAG_`m' $event_dummies $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Evt_Bin
    coefplot `m'_Evt_Bin, keep($event_dummies) omitted vertical rename(`rnm_rule') ///
        recast(connected) lcolor(gs5) lwidth(medthick) msymbol(O) mfcolor(white) mlcolor(gs5) msize(medlarge) ///
        ciopts(recast(rcap) lpattern(dash) color(gs5)) ///
        yline(0, lpattern(dash) lcolor(gs10)) xline(5, lpattern(dash) lcolor(maroon)) ///
        xtitle("Years relative to BESS policy", size(vlarge)) ytitle("Coefficients", size(vlarge)) ///
        xlabel(, labsize(vlarge)) ylabel(, labsize(vlarge)) ///
        graphregion(color(white)) name(`m'_Bin_Plt, replace)
    graph export "Figures/Event_Binary_`m'.png", width(2000) replace

    reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Bas_Log
    reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Avg_Log
    global TB_`m'_Log = _b[treat_post_ln_pol] 
    
    reghdfe ln_IPAG_`m' $event_dummies $c_event_dummies $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Evt_Log
    coefplot `m'_Evt_Log, keep($c_event_dummies) omitted vertical rename(`c_rnm_rule') ///
        recast(connected) lcolor(gs5) lwidth(medthick) msymbol(O) mfcolor(white) mlcolor(gs5) msize(medlarge) ///
        ciopts(recast(rcap) lpattern(dash) color(gs5)) ///
        yline(0, lpattern(dash) lcolor(gs10)) xline(5, lpattern(dash) lcolor(maroon)) ///
        xtitle("Years relative to BESS policy", size(vlarge)) ytitle("Marginal Coefficient", size(vlarge)) ///
        xlabel(, labsize(vlarge)) ylabel(, labsize(vlarge)) ///
        graphregion(color(white)) name(`m'_Log_Plt, replace)
    graph export "Figures/Event_LogCount_`m'.png", width(2000) replace

    reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Bas_Rate
    reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Avg_Rate
    global TB_`m'_Rate = _b[treat_post_ln_rate] 
    
    reghdfe ln_IPAG_`m' $event_dummies $r_event_dummies $controls, absorb(city_code year) vce(cluster city_code)
    eststo `m'_Evt_Rate
    coefplot `m'_Evt_Rate, keep($r_event_dummies) omitted vertical rename(`r_rnm_rule') ///
        recast(connected) lcolor(gs5) lwidth(medthick) msymbol(O) mfcolor(white) mlcolor(gs5) msize(medlarge) ///
        ciopts(recast(rcap) lpattern(dash) color(gs5)) ///
        yline(0, lpattern(dash) lcolor(gs10)) xline(5, lpattern(dash) lcolor(maroon)) ///
        xtitle("Years relative to BESS policy", size(vlarge)) ytitle("Marginal Coefficient", size(vlarge)) ///
        xlabel(, labsize(vlarge)) ylabel(, labsize(vlarge)) ///
        graphregion(color(white)) name(`m'_Rate_Plt, replace)
    graph export "Figures/Event_Rate_`m'.png", width(2000) replace

    esttab `m'_Bas_Bin `m'_Avg_Bin `m'_Evt_Bin ///
            `m'_Bas_Log `m'_Avg_Log `m'_Evt_Log ///
            `m'_Bas_Rate `m'_Avg_Rate `m'_Evt_Rate ///
            using "Results_Method_`m'.csv", replace ///
            b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
            mtitles("Bin_Bas" "Bin_Avg" "Bin_Evt" "Log_Bas" "Log_Avg" "Log_Evt" "Rate_Bas" "Rate_Avg" "Rate_Evt")
}

display ">>> Generating Marginal Effects Plots for Baseline (All Sample)..."

foreach m in A M K {
    quietly reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls, absorb(city_code year) vce(cluster city_code)
    
    preserve
    drop _all
    quietly set obs 11
    gen plot_x = (_n - 1) * 0.5
    gen plot_me = .
    gen plot_ll = .
    gen plot_ul = .
    
    forvalues i = 1/11 {
        local x = ( `i' - 1 ) * 0.5
        quietly lincom treat_post + treat_post_ln_pol * `x'
        quietly replace plot_me = r(estimate) in `i'
        quietly replace plot_ll = r(estimate) - 1.96 * r(se) in `i'
        quietly replace plot_ul = r(estimate) + 1.96 * r(se) in `i'
    }
    
    twoway (rarea plot_ul plot_ll plot_x, color(gs12%50) lwidth(none)) ///
           (line plot_me plot_x, lcolor(ebblue) lwidth(medthick)), ///
           yline(0, lpattern(dash) lcolor(maroon) lwidth(medium)) ///
           xtitle("Log of Maximum Policy Number", size(vlarge)) ///
           ytitle("Marginal Effect of BESS Policy", size(vlarge)) ///
           xlabel(, labsize(vlarge)) ylabel(, labsize(vlarge)) ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogPol_`m'_All, replace)
           
    graph export "Margins_Plots/ME_LogPol_`m'_All.png", width(2000) replace
    restore

    quietly reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls, absorb(city_code year) vce(cluster city_code)
    
    preserve
    drop _all
    quietly set obs 11
    gen plot_x = (_n - 1) * 0.5
    gen plot_me = .
    gen plot_ll = .
    gen plot_ul = .
    
    forvalues i = 1/11 {
        local x = ( `i' - 1 ) * 0.5
        quietly lincom treat_post + treat_post_ln_rate * `x'
        quietly replace plot_me = r(estimate) in `i'
        quietly replace plot_ll = r(estimate) - 1.96 * r(se) in `i'
        quietly replace plot_ul = r(estimate) + 1.96 * r(se) in `i'
    }
    
    twoway (rarea plot_ul plot_ll plot_x, color(gs12%50) lwidth(none)) ///
           (line plot_me plot_x, lcolor(emerald) lwidth(medthick)), ///
           yline(0, lpattern(dash) lcolor(maroon) lwidth(medium)) ///
           xtitle("Log of Maximum Policy Rate", size(vlarge)) ///
           ytitle("Marginal Effect of BESS Policy", size(vlarge)) ///
           xlabel(, labsize(vlarge)) ylabel(, labsize(vlarge)) ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogRate_`m'_All, replace)
           
    graph export "Margins_Plots/ME_LogRate_`m'_All.png", width(2000) replace
    restore
}
display ">>> BASELINE MARGINAL EFFECTS PLOTS GENERATED SUCCESSFULLY."

set seed 1234567  
tempfile base_data true_treated all_cities fake_treated
save `base_data', replace  

keep city_code
duplicates drop
save `all_cities', replace

use `base_data', clear
keep if adopt_year > 0
keep city_code adopt_year ln_max_pol ln_max_rate
duplicates drop
local n_treat = _N  
save `true_treated', replace

local post_vars ""
foreach y in A M K {
    foreach type in Bin Log Rate {
        local post_vars "`post_vars' b_`y'_`type' p_`y'_`type'"
    }
}
capture postclose buffer
postfile buffer `post_vars' using "Placebo_Results_Final.dta", replace

display ">>> Running 500 Placebo Simulations (Strict Two-Step Permutation)..."
forvalues i = 1/500 {
    quietly {
        use `true_treated', clear
        gen rsort = runiform()
        sort rsort
        gen match_id = _n
        drop city_code 
        save `fake_treated', replace
        
        use `all_cities', clear
        gen rsort = runiform()
        sort rsort
        keep in 1/`n_treat' 
        gen match_id = _n
        
        merge 1:1 match_id using `fake_treated', nogenerate
        drop rsort match_id
        rename adopt_year f_adopt_year
        rename ln_max_pol f_ln_max_pol
        rename ln_max_rate f_ln_max_rate
        
        merge 1:m city_code using `base_data'
        
        replace f_adopt_year = 0 if _merge == 2
        replace f_ln_max_pol = 0 if _merge == 2
        replace f_ln_max_rate = 0 if _merge == 2
        drop _merge
        
        gen f_treat_post = (year >= f_adopt_year & f_adopt_year > 0)
        gen f_treat_post_ln_pol  = f_treat_post * f_ln_max_pol
        gen f_treat_post_ln_rate = f_treat_post * f_ln_max_rate
        
        local current_res ""
        
        foreach y in A M K {
            
            cap reghdfe ln_IPAG_`y' f_treat_post $controls, absorb(city_code year) vce(cluster city_code)
            if _rc == 0 {
                local b_bin = _b[f_treat_post] 
                local p_bin = 2 * ttail(e(df_r), abs(_b[f_treat_post]/_se[f_treat_post])) 
            } 
            else {
                local b_bin = . 
                local p_bin = .
            }
            
            cap reghdfe ln_IPAG_`y' f_treat_post f_treat_post_ln_pol $controls, absorb(city_code year) vce(cluster city_code)
            if _rc == 0 {
                local b_log = _b[f_treat_post_ln_pol] 
                local p_log = 2 * ttail(e(df_r), abs(_b[f_treat_post_ln_pol]/_se[f_treat_post_ln_pol])) 
            } 
            else {
                local b_log = . 
                local p_log = .
            }
            
            cap reghdfe ln_IPAG_`y' f_treat_post f_treat_post_ln_rate $controls, absorb(city_code year) vce(cluster city_code)
            if _rc == 0 {
                local b_rate = _b[f_treat_post_ln_rate] 
                local p_rate = 2 * ttail(e(df_r), abs(_b[f_treat_post_ln_rate]/_se[f_treat_post_ln_rate])) 
            } 
            else {
                local b_rate = . 
                local p_rate = .
            }
            
            local current_res "`current_res' (`b_bin') (`p_bin') (`b_log') (`p_log') (`b_rate') (`p_rate')"
        }
        post buffer `current_res'
    }
    if mod(`i', 50) == 0 display "Iteration `i' finished"
}
postclose buffer

clear
use "Placebo_Results_Final.dta", clear

foreach y in A M K {
    foreach type in Bin Log Rate {
        
        local t_beta = ${TB_`y'_`type'}
        quietly summarize b_`y'_`type'
        local b_min = r(min)
        local b_max = r(max)
        local max_l = max(abs(`b_min'), abs(`b_max'), abs(`t_beta'))
        local bound = `max_l' * 1.3
        
        twoway (kdensity b_`y'_`type', recast(area) color(gs14) yaxis(2)) /// 
               (scatter p_`y'_`type' b_`y'_`type', msymbol(Oh) mcolor(gs8) msize(medlarge) yaxis(1)) /// 
               (function y=0.1, range(-`bound' `bound') yaxis(1) lcolor(blue) lpattern(dash) lwidth(medium)), /// 
               xline(`t_beta', lcolor(red) lwidth(thick) lpattern(solid)) /// 
               xlabel(-`bound' 0 `t_beta' `bound', format(%9.3f) labsize(vlarge)) ///
               xtitle("Placebo Coefficients", size(vlarge)) /// 
               ytitle("P-value", axis(1) size(vlarge)) ytitle("Kernel Density", axis(2) size(vlarge)) ///
               ylabel(, labsize(vlarge) axis(1)) ylabel(, labsize(vlarge) axis(2)) ///
               legend(order(2 "Placebo P-values" 1 "Kernel Density") pos(6) cols(2) size(vlarge)) ///
               graphregion(color(white)) plotregion(lcolor(black) lwidth(medium)) /// 
               name(Plc_`y'_`type', replace)
        
        graph export "Placebo_Plots/Placebo_`y'_`type'.png", width(2000) replace
    }
}

display ">>> ALL PROCESSES COMPLETED SUCCESSFULLY. 9 Placebo plots generated."