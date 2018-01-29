/* ASM Cost Program 
  Created by - Jennifer Kim
  Last Modified - 01/29/2018 
  Modifed by - Jennifer Kim */

options symbolgen;

libname IP 'Q:\MFP\SAS Libraries\Manufacturing\IP';
libname capital 'Q:\MFP\SAS Libraries\Manufacturing\Capital\capital';
libname comp 'Q:\MFP\SAS Libraries\Manufacturing\Capital\comp';


/*Creates macro variable from textfile*/
data _null_;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
	  length dataset $29;
      input dataset firstyr lastyr baseperiod;
      call symput('lastyr', trim(left(put(lastyr, 4.))));
run;


/* Read in Nonemployer ratios and Intrasectorals */
data work.NE (rename=(Value=NE_ratio));
	length NAICS $4;
	set IP.Final_NonEmpRatios;
run;

proc sort data=work.NE nodupkey;
	by NAICS year;
run;

data work.Intrasectorals (rename=(Value=Intrasectoral));
	length NAICS $4;
	set IP.Final_Intrasectorals;
run;

proc sort data=work.Intrasectorals nodupkey;
	by NAICS year;
run;


/* Import ASM MFP Cost files from Excel */
libname ASM XLSX 'R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\ASM MFP Cost Files.xlsx';

data work.Cost_Elect;
	set ASM.Cost_Elect;
run;

data work.Quan_Elect;
	set ASM.Quan_Elect;
run;

data work.Cost_Fuels;
	set ASM.Cost_Fuels;
run;

data work.Cost_Mat;
	set ASM.Cost_Mat;
run;

data work.Inv_1987_2011;
	set ASM.Inv_1987_2011;
run;

data work.Inv_2012_fwd;
	set ASM.Inv_2012_fwd;
run;

data work.ASM_Capital;
	set ASM.ASM_Capital;
run;

data work.ASM_Capital_hist;
	set ASM.ASM_Capital_hist;
run;

/* Cost of Electricity $thousands*/
proc sql;
create table	IP.CostofElectricity as
select			a.NAICS, a.Year,
			 	a.Cost_Elect*b.NE_ratio as CostofElectricity
from			work.Cost_Elect a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.;
quit;

/* Cost of Fuels $thousands*/
proc sql;
create table	IP.CostofFuels as
select			a.NAICS, a.Year,
			 	(a.Cost_Fuels*b.NE_ratio) as CostofFuels
from			work.Cost_Fuels a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.;
quit;

/* Cost of Materials $thousands*/
proc sql;
create table	IP.CostofSupplies_NE as  /* i.e., unadjusted cost of materials */
select			a.NAICS, a.Year,
			 	(a.Cost_Mat*b.NE_ratio) as CostofSupplies_NE
from			work.Cost_Mat a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.;
quit;

/*Removing intrasectorals from cost of materials*/
proc sql;
create table	IP.CostofSupplies as /* i.e., final cost of materials */
select			a.NAICS, a.Year,
				a.CostofSupplies_NE - b.Intrasectoral*1000 as CostofSupplies
from			IP.CostofSupplies_NE a, work.Intrasectorals b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.;
quit;

/* Quantity of Electricity $thousands*/
proc sql;
create table	IP.QuanofElectricity as
select			a.NAICS, a.Year,
			 	(a.Quan_Elect*b.NE_ratio) as QuanofElectricity
from			work.Quan_Elect a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.;
quit;

/*Averaging end of year and beginning of year for each for 2012-forward*/
proc sql;
create table	work.Inv_2012_fwd2 as
select			NAICS, Year, 
				mean(Finished_goods_BOY, Finished_goods_EOY) as Finished_goods,
				mean(Work_in_process_BOY, Work_in_process_EOY) as Work_in_process,
				mean(Materials_and_supplies_BOY, Materials_and_supplies_EOY) as Materials_and_supplies
from 			work.Inv_2012_fwd
order by		Year, NAICS;
quit;

/*1987-2011 inventories are read into SAS already averaged; the proc append stacks the 1987-2011 and the 2012-forward
  data*/
proc append base=work.Inv_1987_2011 data=work.Inv_2012_fwd2;
run;

/*Final inventories data set, saved to the Comp library ($millions)*/
proc sql;
create table	comp.intories as
select			a.NAICS, a.Year, 
				(a.Finished_goods*b.NE_ratio)/1000 as Final_Goods,
				(a.Work_in_process*b.NE_ratio)/1000 as Work_in_Process,
				(a.Materials_and_supplies*b.NE_ratio)/1000 as Materials_Supplies
from 			work.Inv_1987_2011 a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.
order by		NAICS, Year;
quit;

/* Capital Expenditures ($millions) */
proc sql;
create table	capital.NewCapExp as
select			a.NAICS, a.Year, 
                (a.Structures*b.NE_ratio)/1000 as Structures,
				(a.Vehicles*b.NE_ratio)/1000 as Vehicles,
				(a.Computers*b.NE_ratio)/1000 as Computers,
				(a.All_Other_Equipment*b.NE_ratio)/1000 as All_Other_Equipment,
				(a.Total*b.NE_ratio)/1000 as Total
from			work.ASM_Capital a, work.NE b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.
order by		NAICS, Year;
quit;

/* Update ASM Capital Historical Data from 1958-2005 to 1958-update year by holding 2005 values constant */
proc sql;
create table	work.temp as
select			*
from 			work.NE a full join work.ASM_capital_hist b
on				a.NAICS=b.NAICS and a.Year=b.Year;
quit;

data work.temp2 (drop=NE_ratio);
set work.temp;
if Year<2006 then delete;
run;

proc sql;
create table	work.temp3 as
select			a.NAICS, a.Year, b.Structures, b.Equipment, b.Total
from 			work.temp2 a, work.ASM_capital_hist b
where			a.NAICS=b.NAICS and b.Year=2005;
quit;

proc append base=work.ASM_capital_hist data=work.temp3;
run;


/* Generate Nonemployer ratios back to 1958 by holding 2002 ratios constant */
proc sql;
create table	work.NE2002 as
select			a.NAICS, a.Year,
				b.NE_ratio as NE_ratio_2002
from			work.ASM_Capital_hist a, work.NE b
where			a.NAICS=b.NAICS and b.Year=2002;
quit;

proc sql;
create table	work.NE_hist as
select			a.NAICS, a.Year, a.NE_ratio_2002, b.NE_ratio
from			work.NE2002 a left join work.NE b
on				a.NAICS=b.NAICS and a.Year=b.Year;
quit;

data work.NE_hist;
   set work.NE_hist;
   if year<1987 then NE_ratio_hist = NE_ratio_2002;
   if year>=1987 then NE_ratio_hist = NE_ratio;
run;

/* Capital Expenditures - historical ($millions) */
proc sql;
create table	capital.Naicscapexp as
select			a.NAICS, a.Year, 
                (a.Structures*b.NE_ratio_hist)/1000 as Structures,
				(a.Equipment*b.NE_ratio_hist)/1000 as Equipment,
				(a.Total*b.NE_ratio_hist)/1000 as Total
from			work.ASM_Capital_hist a, work.NE_hist b
where			a.NAICS=b.NAICS and a.Year=b.Year and a.Year<=&lastyr.
order by		NAICS, Year;
quit;

proc datasets library=work kill noprint;
run;
quit;
