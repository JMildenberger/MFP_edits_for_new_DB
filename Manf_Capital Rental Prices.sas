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

/****************************************** Rental Price Calcualations ********************************************/
options notes source errors=0;

/*****Calculating inventories (final goods, work in process, and materials and supplies) for each industry*/

 /*Preparing inventory deflators. Finished goods and Work in process use industry implicit price deflator 
   (deflator.implpi4d).
   Materials supplies use Intermediate Purchases deflator (IP.Kmsdfi)*/
proc transpose data=deflator.implpi4d out=work.Implicit_Price_Deflator (rename=(col1=Implicit_Deflator));
by naics;
run;
data work.Implicit_Price_Deflator;
set work.Implicit_Price_Deflator;
Year= substr(_name_,9) *1;
Finished_Goods_Deflator = Implicit_Deflator/100;
Work_In_Process_Deflator = Implicit_deflator/100;
drop _name_ implicit_deflator;
run;


/*Rebasing IP deflators to 1997=1*/
data work.IP_deflators;
set IP.Kmsdfi;
array years {*} y1987-y&last;
array years2 {*} _1987-_&last;
	do i= 1 to dim(years);
	years2 {i} = years {i}/y1997;
	end;
drop y: i;
run;

proc transpose data=work.ip_deflators out=work.ip_deflators;
by naics;
run;

data work.Materials_Supplies_Deflator;
set work.ip_deflators;
year=substr(_name_,2)*1;
Materials_Supplies_Deflator=col1;
drop _name_ col1;
run;

/*Making sure the NAICS variable from IP and Excel is character*/
data work.intories (rename=(naics=naics2));
set comp.intories;
run;
data work.intories;
retain naics;
set work.intories;
if Vtype(naics2)="N" then NAICS=put(naics2,4.);
Else NAICS=NAICS2;
drop naics2 ;
run;
data work.Materials_Supplies_Deflator (rename=(naics=naics2));
set work.Materials_Supplies_Deflator;
run;
data work.Materials_Supplies_Deflator;
retain naics;
set work.Materials_Supplies_Deflator;
if Vtype(naics2)="N" then NAICS=put(naics2,4.);
Else NAICS=NAICS2;
drop naics2 ;
run;


/*Deflating Inventories*/
data Comp.real_inventories;
merge work.intories work.implicit_price_deflator work.Materials_Supplies_Deflator;
by naics year;
real_Finished_Goods = Final_Goods / Finished_Goods_Deflator;
real_Work_in_Process = Work_in_Process / Work_in_Process_Deflator;
real_Materials_Supplies = Materials_Supplies / Materials_Supplies_Deflator;
drop final_goods work_in_process materials_supplies;
run;

%macro intories;
%do indy=1 %to 86;
	data comp.real_inventories&&NAICS_Indy&indy;
	set comp.real_inventories (where=(NAICS="&&NAICS_Indy&indy"));
	run;
	/*transposing so that years are columns*/
	proc transpose data=comp.real_inventories&&NAICS_Indy&indy (drop=NAICS) out=work.real_inventories&&NAICS_Indy&indy;
	id year;
	run;
	/*Creating deflators for 1984, 85, and 86 based on the rate of change between 1987 and 1988*/
	data work.real_inventories&&NAICS_Indy&indy;
	set work.real_inventories&&NAICS_Indy&indy;
	_1986= (_1987/_1988) * _1987;
	_1985= (_1986/_1987) * _1986;
	_1984= (_1985/_1986) * _1985;
	run;
	proc transpose data=work.real_inventories&&NAICS_Indy&indy out=work.real_inventories&&NAICS_Indy&indy;
	run;
	data work.real_inventories&&NAICS_Indy&indy;
	set work.real_inventories&&NAICS_Indy&indy;
	year=substr(_name_,2)*1;
	drop _name_;
	run;
	proc sort data=work.real_inventories&&NAICS_Indy&indy out=comp.real_inventories&&NAICS_Indy&indy;
	by year;
	run;

%end;
%mend intories;
%intories;

/************Calculating deflators for land for 1958-forward by weighting structure deflators with structure stock*******/
%macro land;
%do indy= 1 %to 86;
data deflator.land_deflator&&NAICS_Indy&indy;
merge beadfnew.structure_pri stock.structure_net_stock&&NAICS_Indy&indy;
/*replacing missing deflators with zeroes*/
array structures {*} struct_pri1 - struct_pri10;
	do i= 1 to dim(structures);
	if structures {i}= . then structures {i} = 0;
	end;
Sum_of_Stocks= sum (of struct_net_stocks: );
Land_Deflator= (struct_pri1*struct_net_stocks_&&NAICS_Indy&indy.._1 + struct_pri2*struct_net_stocks_&&NAICS_Indy&indy.._2 + 
                struct_pri3*struct_net_stocks_&&NAICS_Indy&indy.._3 + struct_pri4*struct_net_stocks_&&NAICS_Indy&indy.._4 +
				struct_pri5*struct_net_stocks_&&NAICS_Indy&indy.._5 + struct_pri6*struct_net_stocks_&&NAICS_Indy&indy.._6 +
				struct_pri7*struct_net_stocks_&&NAICS_Indy&indy.._7 + struct_pri8*struct_net_stocks_&&NAICS_Indy&indy.._8 +
				struct_pri9*struct_net_stocks_&&NAICS_Indy&indy.._9 + struct_pri10*struct_net_stocks_&&NAICS_Indy&indy.._10)/
                Sum_of_Stocks;
keep year land_deflator;
run;
%end;
%mend land;
%land;

/*Adding a year variable to structure deflators and making it to be from 1985-forward*/
data work.structure_deflators (where=(year>1983)) ;
merge beadfnew.structure_pri capital.structureyears;
year=years;
drop years;
run;

/****Creating a fake structure deflators file where 1984-1997 deflators for assets 5,6,7 and 9 are held constant with
     their 1998 values. This will be used in the change in capital gain calculations***/
proc transpose data=work.structure_deflators out=work.structure_deflators_fake;
id year;
run;
data work.structure_deflators_fake;
set work.structure_deflators_fake;
array back {*} _&last - _1984;
	do i=2 to dim (back);
	if back {i} = . then back {i} = back {i-1};
	end;
drop i;
run;
proc transpose data=work.structure_deflators_fake out=structure_deflators_fake;
run;
data work.structure_deflators_fake;
set work.structure_deflators_fake;
year=substr(_name_,2)*1;
array original {*} struct_pri1 - struct_pri10;
array names {*} struct_deflator_cap_gain1 - struct_deflator_cap_gain10;
	do i=1 to dim(names);
	names {i} = original {i};
	end;
drop struct_pri: _name_;
run;


/*Adding a year varaible to real land net stock*/
data stock.real_land_stock;
merge stock.real_land_stock capital.structureyears;
year=years;
drop years;
run;

/*Putting real net stock, real wealth stock, deflators, and capcomp for all equipment, structures, inventories and land
  into one dataset for each industry */

/*Transposing equipment deflators so that years are rows and making the dataset be from 1984-forward*/
/*First, replacing missing deflators with with the first non-zero value for each year.  
This needs to be done in order to correctly calculate the average change in the capital 
gain term.*/
%macro trial;
%do indy=1 %to 86;
data work.deflator&&NAICS_Indy&indy;
set deflator.deflator&&NAICS_Indy&indy;
array back {*} deflator_&last - Deflator_1947;
do i= 1 to dim(back);
	if back {i} = . then back {i} = back {i-1};
end;
drop i;
run;

proc transpose data=work.deflator&&NAICS_Indy&indy out=work.equip_deflator&&NAICS_Indy&indy
prefix = Equip_Deflator_&&NAICS_Indy&indy.._;
id aces_asset;
run;
data work.equip_deflator&&NAICS_Indy&indy (where=(year>1983));
set work.equip_deflator&&NAICS_Indy&indy;
year=substr(_name_,10)*1;
drop _name_;
run;

data rental.RP_&&NAICS_Indy&indy;
merge work.equip_deflator&&NAICS_Indy&indy
	  stock.equipment_net_stock&&NAICS_Indy&indy (firstobs=27)
	  stock.equipment_depreciation&&NAICS_Indy&indy (firstobs=27)
      stock.equipment_wealth_stock&&NAICS_Indy&indy (firstobs=27)
      work.structure_deflators
	  work.structure_deflators_fake
	  stock.structure_net_stock&&NAICS_Indy&indy (firstobs=84)
	  stock.structure_depreciation&&NAICS_Indy&indy (firstobs=84)
	  stock.structure_wealth_stock&&NAICS_Indy&indy (firstobs=84)
	  comp.real_inventories&&NAICS_Indy&indy
	  stock.real_land_stock (where=(year>1983) keep=year real_land&&NAICS_Indy&indy)
	  deflator.land_deflator&&NAICS_Indy&indy (where=(year>1983))
	  Capital.Taxfac
	  Comp.CapCom2 (keep= year CapComp_&&NAICS_Indy&indy);
by year;
if NAICS= . then NAICS = &&NAICS_Indy&indy;

/*Calculating change in the 3-year average of Capital Gain*/
%macro equip_assets;
%do asset=1 %to 24;
Capital_Gain_Equipment&asset= (lag2(equip_deflator_&&NAICS_Indy&indy.._&asset) + lag1(equip_deflator_&&NAICS_Indy&indy.._&asset) + 
							   equip_deflator_&&NAICS_Indy&indy.._&asset)/ 3;
Change_Capital_Gain_Equipment&asset= Capital_Gain_Equipment&asset - lag1(Capital_Gain_Equipment&asset);
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Capital_Gain_Structure&asset= (lag2(struct_deflator_cap_gain&asset) + lag1(struct_deflator_cap_gain&asset) + struct_deflator_cap_gain&asset)/ 3;
Change_Capital_Gain_Structure&asset= Capital_Gain_Structure&asset - lag1(Capital_Gain_Structure&asset);
%end;
%mend structure_assets;
%structure_assets;
Capital_Gain_FG= (lag2(Finished_Goods_Deflator) + lag1(Finished_Goods_Deflator) + Finished_Goods_Deflator)/3;
Capital_Gain_WP= (lag2(Work_In_Process_Deflator) + lag1(Work_In_Process_Deflator) + Work_In_Process_Deflator)/3;
Capital_Gain_MS= (lag2(Materials_Supplies_Deflator) + lag1(Materials_Supplies_Deflator) + Materials_Supplies_Deflator)/3;
Change_Capital_Gain_FG= Capital_Gain_FG - lag1(Capital_Gain_FG);
Change_Capital_Gain_WP= Capital_Gain_WP - lag1(Capital_Gain_WP);
Change_Capital_Gain_MS= Capital_Gain_MS - lag1(Capital_Gain_MS);
Capital_Gain_Land=(lag2(Land_Deflator) + lag1(Land_Deflator) + Land_Deflator)/3;
Change_Capital_Gain_Land= Capital_Gain_Land - lag1(Capital_Gain_Land);

/*Calculating average net and wealth stocks*/
%macro equip_assets;
%do asset=1 %to 24;
Wealth_Stocks_&&NAICS_Indy&indy.._&asset= round(Wealth_Stocks_&&NAICS_Indy&indy.._&asset,0.0000000001);
average_stock_equip&asset= (Net_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Net_stocks_&&NAICS_Indy&indy.._&asset))/2;
average_wealth_equip&asset= (Wealth_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Wealth_stocks_&&NAICS_Indy&indy.._&asset))/2;
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset= round(Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset,0.0000000001);
average_stock_struct&asset= (Struct_Net_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Struct_Net_stocks_&&NAICS_Indy&indy.._&asset))/2;
average_wealth_struct&asset= (Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Struct_Wealth_stocks_&&NAICS_Indy&indy.._&asset))/2;
%end;
%mend structure_assets;
%structure_assets;

/*Cacluating the Rate of Depreciation */
%macro equip_assets;
%do asset=1 %to 24;
Depreciation_&&NAICS_Indy&indy.._&asset= round(Depreciation_&&NAICS_Indy&indy.._&asset,0.0000000001);
if Depreciation_&&NAICS_Indy&indy.._&asset = . then Depreciation_&&NAICS_Indy&indy.._&asset = 0;
Depreciation_Rate_Equipment&asset = Depreciation_&&NAICS_Indy&indy.._&asset / average_wealth_equip&asset; 
if Depreciation_Rate_Equipment&asset = . then Depreciation_Rate_Equipment&asset = 0;
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Struct_Depreciation_&&NAICS_Indy&indy.._&asset= round(Struct_Depreciation_&&NAICS_Indy&indy.._&asset,0.0000000001);
if Struct_Depreciation_&&NAICS_Indy&indy.._&asset = . then Struct_Depreciation_&&NAICS_Indy&indy.._&asset = 0;
Depreciation_Rate_Structure&asset = Struct_Depreciation_&&NAICS_Indy&indy.._&asset / average_wealth_struct&asset;
if Depreciation_Rate_Structure&asset = . then Depreciation_Rate_Structure&asset = 0;
%end;
%mend structure_assets;
%structure_assets;
Depreciation_Rate_FG = 0;
Depreciation_Rate_WP = 0;
Depreciation_Rate_MS = 0;
Depreciation_Rate_Land = 0;
Average_Wealth_FG = 1;
Average_Wealth_WP = 1;
Average_Wealth_MS = 1;
Average_Wealth_Land = 1;

/*Calculaing the the internal rate of return*/
%macro sum1a;
%do asset=1 %to 11;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            EqTaxf;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * EqTaxf;
%end;
%mend sum1a;
%sum1a;
%macro sum1a;
%do asset=14%to 24;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            EqTaxf;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * EqTaxf;
%end;
%mend sum1a;
%sum1a;
%macro sum1b;
%do asset=12 %to 13;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            CarTaxF;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * CarTaxF;
%end;
%mend sum1b;
%sum1b;
%macro sum1c;
%do asset=1 %to 10;
	Sum1_Structure&asset= average_stock_struct&asset * (struct_pri&asset * Depreciation_Rate_Structure&asset - Change_Capital_Gain_Structure&asset) *
	            STRTaxF;
	Sum2_Structure&asset= average_stock_struct&asset * struct_pri&asset * STRTaxF;
%end;
%mend sum1c;
%sum1c;
Sum1_FG= real_finished_goods * (Finished_Goods_Deflator * Depreciation_Rate_FG - Change_Capital_Gain_FG) * INLTaxf;
Sum1_WP= real_work_in_process * (work_in_process_Deflator * Depreciation_Rate_WP - Change_Capital_Gain_WP) * INLTaxf;
Sum1_MS= real_materials_supplies * (Materials_Supplies_Deflator * Depreciation_Rate_MS - Change_Capital_Gain_MS) * INLTaxf;
Sum1_Land= real_Land&&NAICS_Indy&indy * (Land_Deflator * Depreciation_Rate_Land - Change_Capital_Gain_Land) * INLTaxf;
Sum2_FG= real_finished_goods * Finished_Goods_Deflator * INLTaxf;
Sum2_WP= real_work_in_process * work_in_process_Deflator * INLTaxf;
Sum2_MS= real_materials_supplies * Materials_Supplies_Deflator * INLTaxf;
Sum2_Land= real_Land&&NAICS_Indy&indy * Land_Deflator * INLTaxf;

SUM1_Total= sum (of sum1_:);
SUM2_Total= sum (of sum2_:);

/*Internal Rate of Return Calculation*/
IRR_&&NAICS_Indy&indy= (CapComp_&&NAICS_Indy&indy - Sum1_Total) / Sum2_Total;

/*Rental price calculations using the internal rate of return and an external rate of 3.5%*/
%macro rp1;
%do asset= 1 %to 11;
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * EqTaxf;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * EqTaxf;
%end;
%do asset= 14 %to 24;
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * EqTaxf;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * EqTaxf;
%end;
%do asset= 12 %to 13;
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * CarTaxF;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * CarTaxF;
%end;
%mend rp1;
%rp1;
%macro rp1;
%do asset= 1 %to 10;
	Rental_Price_Structure&asset= (struct_pri&asset * IRR_&&NAICS_Indy&indy + struct_pri&asset * Depreciation_Rate_Structure&asset - Change_Capital_Gain_Structure&asset) * StrTaxf;
	RP_with_ERR_Structure&asset= (struct_pri&asset * 0.035 + struct_pri&asset * Depreciation_Rate_Structure&asset) * StrTaxf;
%end;
%mend rp1;
%rp1;
Rental_Price_FG= (Finished_Goods_Deflator * IRR_&&NAICS_Indy&indy + Finished_Goods_Deflator * Depreciation_Rate_FG - Change_Capital_Gain_FG ) * INLTaxf;
Rental_Price_WP= (work_in_process_Deflator * IRR_&&NAICS_Indy&indy + work_in_process_Deflator * Depreciation_Rate_WP - Change_Capital_Gain_WP) * INLTaxf;
Rental_Price_MS= (Materials_Supplies_Deflator *IRR_&&NAICS_Indy&indy +  Materials_Supplies_Deflator *Depreciation_Rate_MS - Change_Capital_Gain_MS) * INLTaxf;
Rental_Price_Land= (Land_Deflator * IRR_&&NAICS_Indy&indy + Land_Deflator * Depreciation_Rate_Land - Change_Capital_Gain_Land) * INLTaxf;
RP_with_ERR_FG= (Finished_Goods_Deflator * 0.035 + Finished_Goods_Deflator * Depreciation_Rate_FG ) * INLTaxf;
RP_with_ERR_WP= (work_in_process_Deflator * 0.035 + work_in_process_Deflator * Depreciation_Rate_WP) * INLTaxf;
RP_with_ERR_MS= (Materials_Supplies_Deflator *0.035 +  Materials_Supplies_Deflator *Depreciation_Rate_MS) * INLTaxf;
RP_with_ERR_Land= (Land_Deflator * 0.035 + Land_Deflator * Depreciation_Rate_Land) * INLTaxf;


run;

%end;
%mend trial;
%trial

/***********Calculating rental prices for industries with Special Tools (NAICS 3361, 2,3)****************************/

%macro trial;
%do indy=75 %to 77;

/*Adding Special tools deflator as the 25th equipment asset*/

data work.equip_deflator&&NAICS_Indy&indy ;
retain year equip_deflator: ;
merge work.equip_deflator&&NAICS_Indy&indy sptools.special_tools (where=(year>1983)); 
by year;
Equip_Deflator_&&NAICS_Indy&indy.._25=defspt;
drop nomspt defspt;
run;

/*Adding special tools net stock as the 25th equipment asset*/
data work.equipment_net_stock&&NAICS_Indy&indy;
retain year net_stocks: ;
merge stock.equipment_net_stock&&NAICS_Indy&indy sptools.sptools_net_stock&&NAICS_Indy&indy (rename=(col1=year));
by year;
Net_Stocks_&&NAICS_Indy&indy.._25=col2;
drop col2;
run;
/*Adding special tools depreciation as the 25th equipmet asset*/
data work.equipment_depreciation&&NAICS_Indy&indy;
retain year depreciation_:;
merge stock.equipment_depreciation&&NAICS_Indy&indy sptools.sptools_depreciation&&NAICS_Indy&indy (rename=(col1=year));
by year;
Depreciation_&&NAICS_Indy&indy.._25=col2;
drop col2;
run;
/*Adding speical tools wealth stock as the 25th equipment asset*/
data work.equipment_wealth_stock&&NAICS_Indy&indy;
retain year wealth_:;
merge stock.equipment_wealth_stock&&NAICS_Indy&indy sptools.sptools_wealth_stock&&NAICS_Indy&indy (rename=(col1=year));
by year;
Wealth_Stocks_&&NAICS_Indy&indy.._25=col2;
drop col2;
run;


data Rental.RP_&&NAICS_Indy&indy;
merge work.equip_deflator&&NAICS_Indy&indy
	  work.equipment_net_stock&&NAICS_Indy&indy (firstobs=27)
	  work.equipment_depreciation&&NAICS_Indy&indy (firstobs=27)
      work.equipment_wealth_stock&&NAICS_Indy&indy (firstobs=27)
      work.structure_deflators
	  work.structure_deflators_fake
	  stock.structure_net_stock&&NAICS_Indy&indy (firstobs=84)
	  stock.structure_depreciation&&NAICS_Indy&indy (firstobs=84)
	  stock.structure_wealth_stock&&NAICS_Indy&indy (firstobs=84)
	  comp.real_inventories&&NAICS_Indy&indy
	  stock.real_land_stock (where=(year>1983) keep=year real_land&&NAICS_Indy&indy)
	  deflator.land_deflator&&NAICS_Indy&indy (where=(year>1983))
	  Capital.Taxfac
	  Comp.CapCom2 (keep= year CapComp_&&NAICS_Indy&indy);
by year;
if NAICS= . then NAICS = &&NAICS_Indy&indy;

/*Calculating change in the 3-year average of Capital Gain*/
%macro equip_assets;
%do asset=1 %to 25;
Capital_Gain_Equipment&asset= (lag2(equip_deflator_&&NAICS_Indy&indy.._&asset) + lag1(equip_deflator_&&NAICS_Indy&indy.._&asset) + 
							   equip_deflator_&&NAICS_Indy&indy.._&asset)/ 3;
Change_Capital_Gain_Equipment&asset= Capital_Gain_Equipment&asset - lag1(Capital_Gain_Equipment&asset);
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Capital_Gain_Structure&asset= (lag2(struct_deflator_cap_gain&asset) + lag1(struct_deflator_cap_gain&asset) + struct_deflator_cap_gain&asset)/ 3;
Change_Capital_Gain_Structure&asset= Capital_Gain_Structure&asset - lag1(Capital_Gain_Structure&asset);
%end;
%mend structure_assets;
%structure_assets;
Capital_Gain_FG= (lag2(Finished_Goods_Deflator) + lag1(Finished_Goods_Deflator) + Finished_Goods_Deflator)/3;
Capital_Gain_WP= (lag2(Work_In_Process_Deflator) + lag1(Work_In_Process_Deflator) + Work_In_Process_Deflator)/3;
Capital_Gain_MS= (lag2(Materials_Supplies_Deflator) + lag1(Materials_Supplies_Deflator) + Materials_Supplies_Deflator)/3;
Change_Capital_Gain_FG= Capital_Gain_FG - lag1(Capital_Gain_FG);
Change_Capital_Gain_WP= Capital_Gain_WP - lag1(Capital_Gain_WP);
Change_Capital_Gain_MS= Capital_Gain_MS - lag1(Capital_Gain_MS);
Capital_Gain_Land=(lag2(Land_Deflator) + lag1(Land_Deflator) + Land_Deflator)/3;
Change_Capital_Gain_Land= Capital_Gain_Land - lag1(Capital_Gain_Land);

/*Calculating average net and wealth stocks*/
%macro equip_assets;
%do asset=1 %to 25;
Wealth_Stocks_&&NAICS_Indy&indy.._&asset= round(Wealth_Stocks_&&NAICS_Indy&indy.._&asset,0.0000000001);
average_stock_equip&asset= (Net_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Net_stocks_&&NAICS_Indy&indy.._&asset))/2;
average_wealth_equip&asset= (Wealth_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Wealth_stocks_&&NAICS_Indy&indy.._&asset))/2;
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset= round(Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset,0.0000000001);
average_stock_struct&asset= (Struct_Net_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Struct_Net_stocks_&&NAICS_Indy&indy.._&asset))/2;
average_wealth_struct&asset= (Struct_Wealth_Stocks_&&NAICS_Indy&indy.._&asset + lag1(Struct_Wealth_stocks_&&NAICS_Indy&indy.._&asset))/2;
%end;
%mend structure_assets;
%structure_assets;

/*Cacluating the Rate of Depreciation */
%macro equip_assets;
%do asset=1 %to 25;
Depreciation_&&NAICS_Indy&indy.._&asset= round(Depreciation_&&NAICS_Indy&indy.._&asset,0.0000000001);
if Depreciation_&&NAICS_Indy&indy.._&asset = . then Depreciation_&&NAICS_Indy&indy.._&asset = 0;
Depreciation_Rate_Equipment&asset = Depreciation_&&NAICS_Indy&indy.._&asset / average_wealth_equip&asset; 
if Depreciation_Rate_Equipment&asset = . then Depreciation_Rate_Equipment&asset = 0;
%end;
%mend equip_assets;
%equip_assets;
%macro structure_assets;
%do asset=1 %to 10;
Struct_Depreciation_&&NAICS_Indy&indy.._&asset= round(Struct_Depreciation_&&NAICS_Indy&indy.._&asset,0.0000000001);
if Struct_Depreciation_&&NAICS_Indy&indy.._&asset = . then Struct_Depreciation_&&NAICS_Indy&indy.._&asset = 0;
Depreciation_Rate_Structure&asset = Struct_Depreciation_&&NAICS_Indy&indy.._&asset / average_wealth_struct&asset;
if Depreciation_Rate_Structure&asset = . then Depreciation_Rate_Structure&asset = 0;
%end;
%mend structure_assets;
%structure_assets;
Depreciation_Rate_FG = 0;
Depreciation_Rate_WP = 0;
Depreciation_Rate_MS = 0;
Depreciation_Rate_Land = 0;
Average_Wealth_FG = 1;
Average_Wealth_WP = 1;
Average_Wealth_MS = 1;
Average_Wealth_Land = 1;

/*Calculaing the the internal rate of return*/
%macro sum1a;
%do asset=1 %to 11;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            EqTaxf;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * EqTaxf;
%end;
%mend sum1a;
%sum1a;
%macro sum1a;
%do asset=14%to 25;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            EqTaxf;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * EqTaxf;
%end;
%mend sum1a;
%sum1a;
%macro sum1b;
%do asset=12 %to 13;
	Sum1_&asset= average_stock_equip&asset * (equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) *
	            CarTaxF;
	Sum2_&asset= average_stock_equip&asset * equip_deflator_&&NAICS_Indy&indy.._&asset * CarTaxF;
%end;
%mend sum1b;
%sum1b;
%macro sum1c;
%do asset=1 %to 10;
	Sum1_Structure&asset= average_stock_struct&asset * (struct_pri&asset * Depreciation_Rate_Structure&asset - Change_Capital_Gain_Structure&asset) *
	            STRTaxF;
	Sum2_Structure&asset= average_stock_struct&asset * struct_pri&asset * STRTaxF;
%end;
%mend sum1c;
%sum1c;
Sum1_FG= real_finished_goods * (Finished_Goods_Deflator * Depreciation_Rate_FG - Change_Capital_Gain_FG) * INLTaxf;
Sum1_WP= real_work_in_process * (work_in_process_Deflator * Depreciation_Rate_WP - Change_Capital_Gain_WP) * INLTaxf;
Sum1_MS= real_materials_supplies * (Materials_Supplies_Deflator * Depreciation_Rate_MS - Change_Capital_Gain_MS) * INLTaxf;
Sum1_Land= real_Land&&NAICS_Indy&indy * (Land_Deflator * Depreciation_Rate_Land - Change_Capital_Gain_Land) * INLTaxf;
Sum2_FG= real_finished_goods * Finished_Goods_Deflator * INLTaxf;
Sum2_WP= real_work_in_process * work_in_process_Deflator * INLTaxf;
Sum2_MS= real_materials_supplies * Materials_Supplies_Deflator * INLTaxf;
Sum2_Land= real_Land&&NAICS_Indy&indy * Land_Deflator * INLTaxf;

SUM1_Total= sum (of sum1_:);
SUM2_Total= sum (of sum2_:);

/*Internal Rate of Return Calculation*/
IRR_&&NAICS_Indy&indy= (CapComp_&&NAICS_Indy&indy - Sum1_Total) / Sum2_Total;

/*Rental price calculations using the internal rate of return and an external rate of 3.5%*/
%macro rp1;
%do asset= 1 %to 25;
	
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * EqTaxf;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * EqTaxf;
%end;
%do asset= 14 %to 25;
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * EqTaxf;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * EqTaxf;
	
%end;
%do asset= 12 %to 13;
	Rental_Price&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * IRR_&&NAICS_Indy&indy + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset - Change_Capital_Gain_Equipment&asset) * CarTaxF;
	RP_with_ERR&asset= (equip_deflator_&&NAICS_Indy&indy.._&asset * 0.035 + equip_deflator_&&NAICS_Indy&indy.._&asset * Depreciation_Rate_Equipment&asset) * CarTaxF;
%end;
%mend rp1;
%rp1;
%macro rp1;
%do asset= 1 %to 10;
	Rental_Price_Structure&asset= (struct_pri&asset * IRR_&&NAICS_Indy&indy + struct_pri&asset * Depreciation_Rate_Structure&asset - Change_Capital_Gain_Structure&asset) * StrTaxf;
	RP_with_ERR_Structure&asset= (struct_pri&asset * 0.035 + struct_pri&asset * Depreciation_Rate_Structure&asset) * StrTaxf;
%end;
%mend rp1;
%rp1;
Rental_Price_FG= (Finished_Goods_Deflator * IRR_&&NAICS_Indy&indy + Finished_Goods_Deflator * Depreciation_Rate_FG - Change_Capital_Gain_FG ) * INLTaxf;
Rental_Price_WP= (work_in_process_Deflator * IRR_&&NAICS_Indy&indy + work_in_process_Deflator * Depreciation_Rate_WP - Change_Capital_Gain_WP) * INLTaxf;
Rental_Price_MS= (Materials_Supplies_Deflator *IRR_&&NAICS_Indy&indy +  Materials_Supplies_Deflator *Depreciation_Rate_MS - Change_Capital_Gain_MS) * INLTaxf;
Rental_Price_Land= (Land_Deflator * IRR_&&NAICS_Indy&indy + Land_Deflator * Depreciation_Rate_Land - Change_Capital_Gain_Land) * INLTaxf;
RP_with_ERR_FG= (Finished_Goods_Deflator * 0.035 + Finished_Goods_Deflator * Depreciation_Rate_FG ) * INLTaxf;
RP_with_ERR_WP= (work_in_process_Deflator * 0.035 + work_in_process_Deflator * Depreciation_Rate_WP) * INLTaxf;
RP_with_ERR_MS= (Materials_Supplies_Deflator *0.035 +  Materials_Supplies_Deflator *Depreciation_Rate_MS) * INLTaxf;
RP_with_ERR_Land= (Land_Deflator * 0.035 + Land_Deflator * Depreciation_Rate_Land) * INLTaxf;
run;

%end;
%mend trial;
%trial;
