/*Allows SEG to replace variable names with spaces from Excel files with an underscore*/
options validvarname=v7;

libname capital 'Q:\MFP\SAS Libraries\Manufacturing\Capital\capital';
libname comp 'Q:\MFP\SAS Libraries\Manufacturing\Capital\comp';
libname deflator 'Q:\MFP\SAS Libraries\Manufacturing\Capital\deflator';
libname sptools 'Q:\MFP\SAS Libraries\Manufacturing\Capital\sptools';
libname lives 'Q:\MFP\SAS Libraries\Manufacturing\Capital\lives';
libname ras 'Q:\MFP\SAS Libraries\Manufacturing\Capital\ras';
libname beadfnew 'Q:\MFP\SAS Libraries\Manufacturing\Capital\beadfnew';
libname invest 'Q:\MFP\SAS Libraries\Manufacturing\Capital\invest';
libname rental 'Q:\MFP\SAS Libraries\Manufacturing\Capital\rental';
libname kdetails 'Q:\MFP\SAS Libraries\Manufacturing\Capital\kdetails';
libname kstock4d 'Q:\MFP\SAS Libraries\Manufacturing\Capital\kstock4d';
libname pqfork 'Q:\MFP\SAS Libraries\Manufacturing\Capital\pqfork';
libname stock 'Q:\MFP\SAS Libraries\Manufacturing\Capital\stock';
libname final 'Q:\MFP\SAS Libraries\Manufacturing\Capital\final';
libname exports 'Q:\MFP\SAS Libraries\Manufacturing\Capital\exports';
libname IP 'Q:\MFP\SAS Libraries\Manufacturing\IP';

/*Creating a macro variable for the update year*/
 data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;

 
/*Creating macro variables for the names of NAICS Industries*/
data _null_;
set capital.indys nobs=x;
      call symputx ("NAICS_Indy"!!left(_n_),NAICS);
 run;

/****************************TQ Assets for Final Weighted and Unweighted Capital Indexes*******************************/
options errors=0;
%macro loop;
%do indy=1 %to 86;
data work.tq&&NAICS_Indy&indy;
set rental.rp_&&NAICS_Indy&indy (where=(year>1986));
/*Replacing rental prices calculated with the IRR with rental prices calculated with the ERR if any asset in that year 
  has a negative rental price*/ 
array rp {*} rental_:;
array err {*} rp_with_err:;

negative = min (of rp {*});
do i=1 to dim(rp);
	if negative <0 then  rp (i)  = err (i) ;
end;

/*Calculate value of each asset*/
%macro asset;
%do asset=1 %to 24;
	if average_stock_equip&asset < 0.000000001 then average_stock_equip&asset = 0;
	value_equip&asset = average_stock_equip&asset * Rental_Price&asset;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	if average_stock_struct&asset <0.000000001 then average_stock_struct&asset =0;
	value_struct&asset = average_stock_struct&asset* Rental_Price_structure&asset;
%end;
%mend asset;
%asset;
	value_FG = real_finished_goods * Rental_Price_FG;
	value_WP = real_work_in_process * Rental_Price_WP;
	value_MS = real_materials_supplies * Rental_Price_MS;
	value_Land = real_land&&NAICS_Indy&indy * Rental_Price_Land;
/*Total Value*/
Total_Value= sum (of value:);

/*Value Shares*/
%macro asset;
%do asset=1 %to 24;
	Value_Share_equip&asset = value_equip&asset / Total_Value;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	Value_Share_struct&asset = value_struct&asset / Total_Value;
%end;
%mend asset;
%asset;
	Value_Share_FG = Value_FG / Total_Value;
	Value_Share_WP = Value_WP / Total_Value;
	Value_Share_MS = Value_MS / Total_Value;
	Value_Share_Land = Value_Land / Total_Value;
/*Average Value Shares*/
%macro asset;
%do asset=1 %to 24;
	Avg_Value_Share_equip&asset = (value_share_equip&asset + lag1(value_share_equip&asset))/2;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	Avg_Value_Share_struct&asset = (value_share_struct&asset + lag1(value_share_struct&asset))/2;
%end;
%mend asset;
%asset;	
	Avg_Value_Share_FG = (Value_share_FG + lag1(Value_share_FG)) / 2;
	Avg_Value_Share_WP = (Value_share_WP + lag1(Value_share_WP)) / 2;
	Avg_Value_Share_MS = (Value_share_MS + lag1(Value_share_MS)) / 2;
	Avg_Value_Share_Land = (Value_share_Land + lag1(Value_share_Land)) / 2;
total_average_value_share=sum ( of avg_value_share:);
/*Change in the log of quantity*/
%macro asset;
%do asset=1 %to 24;
	log_equip&asset= log(average_stock_equip&asset);
	Change_In_Log_equip&asset = log(average_stock_equip&asset) - log(lag1(average_stock_equip&asset)) ;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	log_struct&asset = log(average_stock_struct&asset);
	Change_In_Log_struct&asset = log(average_stock_struct&asset) - log(lag1(average_stock_struct&asset)) ;
	%end;
%mend asset;
%asset;
	Change_In_Log_FG = log(real_finished_goods) - log(lag1(real_finished_goods)) ;
	Change_In_Log_WP = log(real_work_in_process) - log(lag1(real_work_in_process)) ;
	Change_In_Log_MS = log(real_materials_supplies) - log(lag1(real_materials_supplies)) ;
	Change_In_Log_Land = log(real_land&&NAICS_Indy&indy) - log(lag1(real_land&&NAICS_Indy&indy)) ;
/*Average share weight times the change in the log of quantity*/
%macro asset;
%do asset=1 %to 24;
	Weight_Log_equip&asset = Avg_Value_Share_equip&asset * Change_In_Log_equip&asset ;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
		Weight_Log_struct&asset = Avg_Value_Share_struct&asset * Change_In_Log_struct&asset ;
	%end;
%mend asset;
%asset;
	Weight_Log_struct_FG = Avg_Value_Share_FG * Change_In_Log_FG ;
	Weight_Log_struct_WP = Avg_Value_Share_WP * Change_In_Log_WP ;
	Weight_Log_struct_MS = Avg_Value_Share_MS * Change_In_Log_MS ;
	Weight_Log_struct_Land = Avg_Value_Share_Land * Change_In_Log_Land ;
/*Sum of Average share weight times the change in the log of quantity*/
	SumWtd= sum (of weight_log_:);
/*Exponent of sum weighted*/
	Exp_SumWtd = exp(sumwtd);
/*Unweighted Capital index*/
Unweighted_Capital = sum (of average_stock:) + real_land&&NAICS_Indy&indy + real_finished_goods + real_work_in_process +
						 real_materials_supplies; 
run;

data work.capital_index&&NAICS_Indy&indy;
set work.tq&&NAICS_Indy&indy (keep= year exp_sumwtd);
run;
data work.unweighted_capital_index&&NAICS_Indy&indy;
set work.tq&&NAICS_Indy&indy (keep = year Unweighted_Capital);
run;

/*Transposing the data so that years are columns*/
proc transpose data=work.capital_index&&NAICS_Indy&indy out=work.capital_index&&NAICS_Indy&indy;
id year;
run;
proc transpose data=work.unweighted_capital_index&&NAICS_Indy&indy out=work.unweighted_capital_index&&NAICS_Indy&indy;
id year;
run;
/*Chain-linking to create the final capital index*/
data kstock4d.capital_index&&NAICS_Indy&indy;
set work.capital_index&&NAICS_Indy&indy;
_name_="&&NAICS_Indy&indy";
NAICS=_name_;
_1987=100;
array years {*} _1987 - _&last;
array years2 {*} y1987 - y&last;
	do i= 2 to dim(years);
	years {i} = years(i-1) * years {i};
	end;
	do i=1 to dim(years);
	years2 {i} = years {i};
	end;
drop _: i:;
run;
/*Indexing to create the final unweighted index*/
data kstock4d.diraggcap&&NAICS_Indy&indy;
set work.unweighted_capital_index&&NAICS_Indy&indy;
_name_="&&NAICS_Indy&indy";
NAICS=_name_;
array years {*} _1987 - _&last;
array years2 {*} y1987 - y&last;
	do i= 1 to dim(years);
	years2 {i} = years(i) / _1987 * 100;
	end;
drop _: i:;
run;

%end;
%mend loop;
%loop;


/**********Doing the same as above for industries with the 25th equipment asset (special tools)***********/
%macro loop;
%do indy=75 %to 77;
data work.tq&&NAICS_Indy&indy;
set rental.rp_&&NAICS_Indy&indy (where=(year>1986));

/*Replacing rental prices calculated with the IRR with rental prices calculated with the ERR if any asset in that year 
  has a negative rental price*/ 
array rp {*} rental_:;
array err {*} RP_with_err:;

negative = min (of rp {*});
do i=1 to dim(rp);
	if negative <0 then  rp (i)  = err (i) ;
end;

/*Calculate value of each asset*/
%macro asset;
%do asset=1 %to 25;
	if average_stock_equip&asset < 0.000000001 then average_stock_equip&asset = 0;
	value_equip&asset = average_stock_equip&asset * Rental_Price&asset;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	if average_stock_struct&asset < 0.000000001 then average_stock_struct&asset = 0;
	value_struct&asset = average_stock_struct&asset* Rental_Price_structure&asset;
%end;
%mend asset;
%asset;
	value_FG = real_finished_goods * Rental_Price_FG;
	value_WP = real_work_in_process * Rental_Price_WP;
	value_MS = real_materials_supplies * Rental_Price_MS;
	value_Land = real_land&&NAICS_Indy&indy * Rental_Price_Land;
/*Total Value*/
Total_Value= sum (of value:);

/*Value Shares*/
%macro asset;
%do asset=1 %to 25;
	Value_Share_equip&asset = value_equip&asset / Total_Value;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	Value_Share_struct&asset = value_struct&asset / Total_Value;
%end;
%mend asset;
%asset;
	Value_Share_FG = Value_FG / Total_Value;
	Value_Share_WP = Value_WP / Total_Value;
	Value_Share_MS = Value_MS / Total_Value;
	Value_Share_Land = Value_Land / Total_Value;
/*Average Value Shares*/
%macro asset;
%do asset=1 %to 25;
	Avg_Value_Share_equip&asset = (value_share_equip&asset + lag1(value_share_equip&asset))/2;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	Avg_Value_Share_struct&asset = (value_share_struct&asset + lag1(value_share_struct&asset))/2;
%end;
%mend asset;
%asset;	
	Avg_Value_Share_FG = (Value_share_FG + lag1(Value_share_FG)) / 2;
	Avg_Value_Share_WP = (Value_share_WP + lag1(Value_share_WP)) / 2;
	Avg_Value_Share_MS = (Value_share_MS + lag1(Value_share_MS)) / 2;
	Avg_Value_Share_Land = (Value_share_Land + lag1(Value_share_Land)) / 2;
total_average_value_share=sum ( of avg_value_share:);
/*Change in the log of quantity*/
%macro asset;
%do asset=1 %to 25;
	Change_In_Log_equip&asset = log(average_stock_equip&asset) - log(lag1(average_stock_equip&asset)) ;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
	Change_In_Log_struct&asset = log(average_stock_struct&asset) - log(lag1(average_stock_struct&asset)) ;
	%end;
%mend asset;
%asset;
	Change_In_Log_FG = log(real_finished_goods) - log(lag1(real_finished_goods)) ;
	Change_In_Log_WP = log(real_work_in_process) - log(lag1(real_work_in_process)) ;
	Change_In_Log_MS = log(real_materials_supplies) - log(lag1(real_materials_supplies)) ;
	Change_In_Log_Land = log(real_land&&NAICS_Indy&indy) - log(lag1(real_land&&NAICS_Indy&indy)) ;
/*Average share weight times the change in the log of quantity*/
%macro asset;
%do asset=1 %to 25;
	Weight_Log_equip&asset = Avg_Value_Share_equip&asset * Change_In_Log_equip&asset ;
	%end;
%mend asset;
%asset;
%macro asset;
%do asset=1 %to 10;
		Weight_Log_struct&asset = Avg_Value_Share_struct&asset * Change_In_Log_struct&asset ;
	%end;
%mend asset;
%asset;
	Weight_Log_struct_FG = Avg_Value_Share_FG * Change_In_Log_FG ;
	Weight_Log_struct_WP = Avg_Value_Share_WP * Change_In_Log_WP ;
	Weight_Log_struct_MS = Avg_Value_Share_MS * Change_In_Log_MS ;
	Weight_Log_struct_Land = Avg_Value_Share_Land * Change_In_Log_Land ;
/*Sum of Average share weight times the change in the log of quantity*/
	SumWtd= sum (of weight_log_:);
/*Exponent of sum weighted*/
	Exp_SumWtd = exp(sumwtd);
/*Unweighted Capital index*/
Unweighted_Capital = sum (of average_stock:) + real_land&&NAICS_Indy&indy + real_finished_goods + real_work_in_process +
						 real_materials_supplies; 
run;

data work.capital_index&&NAICS_Indy&indy;
set work.tq&&NAICS_Indy&indy (keep= year exp_sumwtd);
run;
data work.unweighted_capital_index&&NAICS_Indy&indy;
set work.tq&&NAICS_Indy&indy (keep = year Unweighted_Capital);
run;

/*Transposing the data so that years are columns*/
proc transpose data=work.capital_index&&NAICS_Indy&indy out=work.capital_index&&NAICS_Indy&indy;
id year;
run;
proc transpose data=work.unweighted_capital_index&&NAICS_Indy&indy out=work.unweighted_capital_index&&NAICS_Indy&indy;
id year;
run;
/*Chain-linking to create the final capital index*/
data kstock4d.capital_index&&NAICS_Indy&indy;
set work.capital_index&&NAICS_Indy&indy;
_name_="&&NAICS_Indy&indy";
NAICS=_name_;
_1987=100;
array years {*} _1987 - _&last;
array years2 {*} y1987 - y&last;
	do i= 2 to dim(years);
	years {i} = years(i-1) * years {i};
	end;
	do i=1 to dim(years);
	years2 {i} = years {i};
	end;
drop _: i:;
run;
/*Indexing to create the final unweighted index*/
data kstock4d.diraggcap&&NAICS_Indy&indy;
set work.unweighted_capital_index&&NAICS_Indy&indy;
_name_="&&NAICS_Indy&indy";
NAICS=_name_;
array years {*} _1987 - _&last;
array years2 {*} y1987 - y&last;
	do i= 1 to dim(years);
	years2 {i} = years(i) / _1987 * 100;
	end;
drop _: i:;
run;

%end;
%mend loop;
%loop;

/*Putting all capital indexes into one dataest*/
%macro combine;
data kstock4d.capital;
set 
	%do indy= 1 %to 86;
	kstock4d.capital_index&&NAICS_Indy&indy
	%end;
	;
run;
%mend combine;
%combine;
/*Putting all capital indexes into one dataest*/
%macro combine;
data kstock4d.diraggcap;
set 
	%do indy= 1 %to 86;
	kstock4d.diraggcap&&NAICS_Indy&indy
	%end;
	;
run;
%mend combine;
%combine;

/*Adding NAICS column to CapComp and renaming years */
Data comp.capcomp;
merge kstock4d.capital (keep=naics) comp.capcom;
array years {*} y1987-y&last;
array columns {*} col:;
	do i=1 to dim(years);
	years {i} = columns {i};
	end;
keep naics y:;
run;
/*Writing out average values share for each industry */
%macro loop;
%do indy=1 %to 86;
data work.avg_value_share&&NAICS_Indy&indy;
retain naics year avg:;
set work.tq&&NAICS_Indy&indy;
NAICS= &&NAICS_Indy&indy;
keep naics year avg:;
run;
%end;
%mend loop;
%loop;

%macro combine;
data kstock4d.average_value_shares;
set 
	%do indy= 1 %to 86;
	work.avg_value_share&&NAICS_Indy&indy
	%end;
	;
run;
%mend combine;
%combine;
/*Writing out rental prices for each industry */
%macro loop;
%do indy=1 %to 86;
data work.rental_price&&NAICS_Indy&indy;
retain naics year avg:;
set work.tq&&NAICS_Indy&indy;
NAICS= &&NAICS_Indy&indy;
keep naics year rental:;
run;
%end;
%mend loop;
%loop;

%macro combine;
data kstock4d.rental_prices;
set 
	%do indy= 1 %to 86;
	work.rental_price&&NAICS_Indy&indy
	%end;
	;
run;
%mend combine;
%combine;