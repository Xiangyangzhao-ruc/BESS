est clear
capture postclose buffer 
capture mkdir "SubGroup_Results" 
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

capture drop treat_post treat_post_ln_pol treat_post_ln_rate adopt_year
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

foreach m in A M K {
    display ">>> Processing Sub-group Analysis for Method `m' ..."
    
    quietly {
        reghdfe ln_IPAG_`m' treat_post $controls, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Bin_All
        
        reghdfe ln_IPAG_`m' treat_post $controls if east == 1, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Bin_East
        
        reghdfe ln_IPAG_`m' treat_post $controls if east == 0, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Bin_West
    }
    esttab `m'_Bin_All `m'_Bin_East `m'_Bin_West using "SubGroup_Results/Sub_Bin_`m'.csv", replace ///
        b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
        keep(treat_post $controls) ///
        mtitles("All" "East" "Non-East") title("Binary DID Sub-group: `m'")

    quietly {
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Log_All
        
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls if east == 1, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Log_East
        
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls if east == 0, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Log_West
    }
    esttab `m'_Log_All `m'_Log_East `m'_Log_West using "SubGroup_Results/Sub_Log_`m'.csv", replace ///
        b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
        keep(treat_post treat_post_ln_pol $controls) ///
        mtitles("All" "East" "Non-East") title("Log_Count DID Sub-group: `m'")

    quietly {
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Rate_All
        
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls if east == 1, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Rate_East
        
        reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls if east == 0, absorb(city_code year) vce(cluster city_code)
        eststo `m'_Rate_West
    }
    esttab `m'_Rate_All `m'_Rate_East `m'_Rate_West using "SubGroup_Results/Sub_Rate_`m'.csv", replace ///
        b(3) se(3) star(* 0.1 ** 0.05 *** 0.01) r2 obslast nogaps compress plain ///
        keep(treat_post treat_post_ln_rate $controls) ///
        mtitles("All" "East" "Non-East") title("Log_Rate DID Sub-group: `m'")
}
display ">>> SUB-GROUP ANALYSIS COMPLETED."

display ">>> Generating Marginal Effects Plots for Both East and Non-East Samples..."

foreach m in A M K {
    
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
           xtitle("Log of Maximum Policy Number") ///
           ytitle("Marginal Effect of BESS Policy") ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogPol_`m'_East, replace)
           
    graph export "Margins_Plots/ME_LogPol_`m'_East.png", width(2000) replace
    restore 

    quietly reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls if east == 1, absorb(city_code year) vce(cluster city_code)
    
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
           xtitle("Log of Maximum Policy Rate") ///
           ytitle("Marginal Effect of BESS Policy") ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogRate_`m'_East, replace)
           
    graph export "Margins_Plots/ME_LogRate_`m'_East.png", width(2000) replace
    restore

    quietly reghdfe ln_IPAG_`m' treat_post treat_post_ln_pol $controls if east == 0, absorb(city_code year) vce(cluster city_code)
    
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
           (line plot_me plot_x, lcolor(orange) lwidth(medthick)), /// 
           yline(0, lpattern(dash) lcolor(maroon) lwidth(medium)) ///
           xtitle("Log of Maximum Policy Number") ///
           ytitle("Marginal Effect of BESS Policy") ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogPol_`m'_West, replace)
           
    graph export "Margins_Plots/ME_LogPol_`m'_West.png", width(2000) replace
    restore 

    quietly reghdfe ln_IPAG_`m' treat_post treat_post_ln_rate $controls if east == 0, absorb(city_code year) vce(cluster city_code)
    
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
           (line plot_me plot_x, lcolor(cranberry) lwidth(medthick)), /// 
           yline(0, lpattern(dash) lcolor(maroon) lwidth(medium)) ///
           xtitle("Log of Maximum Policy Rate") ///
           ytitle("Marginal Effect of BESS Policy") ///
           legend(off) ///
           graphregion(color(white)) name(ME_LogRate_`m'_West, replace)
           
    graph export "Margins_Plots/ME_LogRate_`m'_West.png", width(2000) replace
    restore
}

display ">>> ALL MARGINAL EFFECTS PLOTS (EAST & NON-EAST) GENERATED SUCCESSFULLY. CHECK 'Margins_Plots' FOLDER."