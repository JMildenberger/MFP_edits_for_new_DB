/*NonEmployer Program 
  Created by - Chris Morris
  Last Modified - 01/29/2018 
  Modifed by - Jennifer Kim */

options symbolgen;

libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";
libname SQL ODBC DSN=IPSTestDB schema=sas;


/*Creates macro variables from textfile*/
data _null_;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
	  length dataset $29;
      input dataset firstyr lastyr baseperiod;
	  call symput('dataset',trim(dataset));
      call symput('lastyr', trim(left(put(lastyr, 4.))));
      call symput('baseperiod', trim(left(put(baseperiod, 2.))));
run;


/*Read in ValProd and LComp files*/
Proc sql;
	Create table 	work.ManufacturingSource as 
	select Distinct IndustryID, Industry as IndustryCodeID, DataSeriesID, DataArrayID, YearID, CensusPeriodID, Year, input(substr(YearID,5,1),1.) as YearNo, Value
	from 			&dataset
	where 			DataSeriesID in ('XT38','XT39', 'XT49') and (substr(IndustryID,3,1)="3") and DigitID = "6-Digit"
	order by 		IndustryID, DataSeriesID, YearID;
quit;


/*Create table for employer, non-employer, and total value of shipments*/
proc sql;
	create table	work.VsIndAnn as
	select			*
	from			work.ManufacturingSource
	where			(DataSeriesID = 'XT38' or DataSeriesID ='XT39') and CensusPeriodID>=12;

	create table	work.VsNonEmp as
	select			*
	from			work.ManufacturingSource
	where			DataSeriesID = 'XT49' and CensusPeriodID>=12;

	create table 	work.VsTotal as
	select 			a.IndustryCodeID,"VsTotal" as DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.Year, a.YearNo, a.Value+b.Value as Value
	from 			work.VsIndAnn a
	inner join		work.VsNonEmp b
	on				(a.IndustryCodeID=b.IndustryCodeID) and (a.YearID=b.YearID) and (a.CensusPeriodID=b.CensusPeriodID)
					and (a.Year=b.Year) and (a.YearNo=b.YearNo);
quit;


/*Aggregate  Employer and Non-Employer Industry Value of Shipments to 4 Digit Naics*/
proc sql;
	create table 	work.Final_VsIndAnn_agg as
	select 			substr(IndustryCodeID,1,4) as NAICS, DataSeriesID, YearID, CensusPeriodID, YearNo, Year,
					sum(value) as Value
	from			work.VsIndAnn 
	group by		NAICS, DataSeriesID, YearID, CensusPeriodID, YearNo, Year;

	create table 	work.Final_VsNonEmp_agg as
	select 			substr(IndustryCodeID,1,4) as NAICS, DataSeriesID, YearID, CensusPeriodID, YearNo, Year,
					sum(value) as Value
	from			work.VsNonEmp 
	group by		NAICS, DataSeriesID, YearID, CensusPeriodID, YearNo, Year;

	create table 	work.Final_VsTotal_agg as
	select 			substr(IndustryCodeID,1,4) as NAICS, DataSeriesCodeID, YearID, CensusPeriodID, YearNo, Year,
					sum(value) as Value
	from			work.VsTotal
	group by		NAICS, DataSeriesCodeID, YearID, CensusPeriodID, YearNo, Year;
quit;


/*--------------------------------------------*/
/*--------Calculate linked VsIndAnn-----------*/
/*--------------------------------------------*/

/*	Forward linking ratios are calculated for each CensusPeriodID (Year 6/ Year 1) */
Proc sql;
	Create table	work.CensusRatioAdjForward as
	Select 			a.Naics, a.DataSeriesID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Final_VsIndAnn_agg a
	inner join		work.Final_VsIndAnn_agg b
	on				(a.Naics=b.Naics) and (a.DataSeriesID=b.DataSeriesID) and 
					(a.CensusPeriodID-1=b.CensusPeriodID) and (a.YearNo=1) and (b.YearNo=6)
	where			a.CensusPeriodID>&baseperiod;

/*	Backward linking ratios are calculated for each CensusPeriodID (Year 1 / Year 6) */
	Create table	work.CensusRatioAdjBack as
	Select 			a.Naics, a.DataSeriesID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Final_VsIndAnn_agg a
	inner join		work.Final_VsIndAnn_agg b	
	on				(a.Naics=b.Naics) and (a.DataSeriesID=b.DataSeriesID) and 
					(a.CensusPeriodID+1=b.CensusPeriodID) and (a.YearNo=6) and (b.YearNo=1)
	where			a.CensusPeriodID<&baseperiod;
quit;

/*	Working files for the compounding of linking ratios are created */
data work.BackWorking;
	set work.CensusRatioAdjBack;
run;

data work.ForwardWorking;
	set work.CensusRatioAdjForward;
run;


/*  Define Census Period Linking Macro
	This macro compounds the linking ratios for the CensusPeriods prior to the base period in step 1. In step 2
   	the macro compounds the linking ratios for the Census Periods after the base period
	Step 1 counts down from the base period to Census Period 9 which is the first period of published data. 
	Step 2 counts up from the base period to Census Period 20. Once measures are published beyond Period 20 the code 
	will need to be updated. */
%macro compound;
%do i = %eval(&baseperiod-1) %to 9 %by -1;
	Proc sql;
		Create table	work.BackCompound&i as
		Select			a.Naics, a.DataSeriesID, a.CensusPeriodID, 
						case 	when a.CensusPeriodID>=&i then c.ratio 
								else a.ratio*b.ratio 
						end as ratio
		from			work.CensusRatioAdjBack a
		left 			join work.BackWorking b
		on 				(a.Naics=b.Naics) and (a.DataSeriesID=b.DataSeriesID) and 
						(b.CensusPeriodID=a.CensusPeriodID+1) 
		left 			join work.BackWorking c
		on 				(a.Naics=c.Naics) and (a.DataSeriesID=c.DataSeriesID) and 
						(c.CensusPeriodID=a.CensusPeriodID)
		order by 		Naics, DataSeriesID, CensusPeriodID;
	quit;

	data work.BackWorking;
		set work.BackCompound&i;
	run;
%end;

%do i = %eval(&baseperiod+1) %to 20;
	Proc sql;
		Create table	work.ForwardCompound&i as
		Select			a.Naics, a.DataSeriesID, a.CensusPeriodID, 
						case 	when a.CensusPeriodID<=&i then c.ratio 
								else a.ratio*b.ratio
						end as ratio
		from			work.CensusRatioAdjForward a
		left join 		work.ForwardWorking b
		on 				(a.Naics=b.Naics) and (a.DataSeriesID=b.DataSeriesID) and
						(b.CensusPeriodID=a.CensusPeriodID)
		left join 		work.ForwardWorking c
		on 				(a.Naics=c.Naics) and (a.DataSeriesID=c.DataSeriesID) and 
						(c.CensusPeriodID=a.CensusPeriodID)
		order by 		Naics, DataSeriesID, CensusPeriodID;
		quit;

	data work.ForwardWorking;
		set work.ForwardCompound&i;
	run;
%end;
%mend compound;


/*Call Census Period Linking Ratio Macro*/
%compound;


/*	The compounded linking ratios are multiplied by the Census chunk values to create a continuous series */
Proc sql;
	Create table	work.Final_VsIndAnn as
	Select			a.Naics, a.DataSeriesID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year,
					case	when a.CensusPeriodID<&baseperiod then a.Value*b.Ratio
							when a.CensusPeriodID>&baseperiod then a.Value*c.Ratio
							when a.CensusPeriodID=&baseperiod then a.Value
					end as Value
	from			work.Final_VsIndAnn_agg a
	left join		work.BackWorking b
	on				(a.Naics=b.Naics) and (a.DataSeriesID=b.DataSeriesID) and (a.CensusPeriodID=b.CensusPeriodID)
	left join		work.ForwardWorking c
	on				(a.Naics=c.Naics) and (a.DataSeriesID=c.DataSeriesID) and (a.CensusPeriodID=c.CensusPeriodID)
	order by		Naics, DataSeriesID, YearID;
quit;


/*----------------------------------------*/
/*------Calculating linked VsTotal--------*/
/*----------------------------------------*/

/*	Forward linking ratios are calculated for each CensusPeriodID (Year 6/ Year 1) */
Proc sql;
	Create table	work.CensusRatioAdjForward as
	Select 			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Final_VsTotal_agg a
	inner join		work.Final_VsTotal_agg b
	on				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and 
					(a.CensusPeriodID-1=b.CensusPeriodID) and (a.YearNo=1) and (b.YearNo=6)
	where			a.CensusPeriodID>&baseperiod;

/*	Backward linking ratios are calculated for each CensusPeriodID (Year 1 / Year 6) */
	Create table	work.CensusRatioAdjBack as
	Select 			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Final_VsTotal_agg a
	inner join		work.Final_VsTotal_agg b	
	on				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and 
					(a.CensusPeriodID+1=b.CensusPeriodID) and (a.YearNo=6) and (b.YearNo=1)
	where			a.CensusPeriodID<&baseperiod;
quit;

/*	Working files for the compounding of linking ratios are created */
data work.BackWorking;
	set work.CensusRatioAdjBack;
run;

data work.ForwardWorking;
	set work.CensusRatioAdjForward;
run;


/*  Define Census Period Linking Ratio 	
	This macro compounds the linking ratios for the CensusPeriods prior to the base period in step 1. In step 2
   	the macro compounds the linking ratios for the Census Periods after the base period
	Step 1 counts down from the base period to Census Period 9 which is the first period of published data. 
	Step 2 counts up from the base period to Census Period 20. Once measures are published beyond Period 20 the code 
	will need to be updated. */
%macro compound;
%do i = %eval(&baseperiod-1) %to 9 %by -1;
	Proc sql;
		Create table	work.BackCompound&i as
		Select			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, 
						case 	when a.CensusPeriodID>=&i then c.ratio 
								else a.ratio*b.ratio 
						end as ratio
		from			work.CensusRatioAdjBack a
		left 			join work.BackWorking b
		on 				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and 
						(b.CensusPeriodID=a.CensusPeriodID+1) 
		left 			join work.BackWorking c
		on 				(a.Naics=c.Naics) and (a.DataSeriesCodeID=c.DataSeriesCodeID) and 
						(c.CensusPeriodID=a.CensusPeriodID)
		order by 		Naics, DataSeriesCodeID, CensusPeriodID;
	quit;

	data work.BackWorking;
		set work.BackCompound&i;
	run;
%end;

%do i = %eval(&baseperiod+1) %to 20;
	Proc sql;
		Create table	work.ForwardCompound&i as
		Select			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, 
						case 	when a.CensusPeriodID<=&i then c.ratio 
								else a.ratio*b.ratio
						end as ratio
		from			work.CensusRatioAdjForward a
		left join 		work.ForwardWorking b
		on 				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and
						(b.CensusPeriodID=a.CensusPeriodID)
		left join 		work.ForwardWorking c
		on 				(a.Naics=c.Naics) and (a.DataSeriesCodeID=c.DataSeriesCodeID) and 
						(c.CensusPeriodID=a.CensusPeriodID)
		order by 		Naics, DataSeriesCodeID, CensusPeriodID;
		quit;

	data work.ForwardWorking;
		set work.ForwardCompound&i;
	run;
%end;
%mend compound;


/*Call Census Period Linking Ratio*/
%compound;


/*	The compounded linking ratios are multiplied by the Census chunk values to create a continuous series */
Proc sql;
	Create table	work.Final_VsTotal as
	Select			a.Naics, a.DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year,
					case	when a.CensusPeriodID<&baseperiod then a.Value*b.Ratio
							when a.CensusPeriodID>&baseperiod then a.Value*c.Ratio
							when a.CensusPeriodID=&baseperiod then a.Value
					end as Value
	from			work.Final_VsTotal_agg a
	left join		work.BackWorking b
	on				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and (a.CensusPeriodID=b.CensusPeriodID)
	left join		work.ForwardWorking c
	on				(a.Naics=c.Naics) and (a.DataSeriesCodeID=c.DataSeriesCodeID) and (a.CensusPeriodID=c.CensusPeriodID)
	order by		Naics, DataSeriesCodeID, YearID;
quit;


/*Calculate Non-Employer Ratio*/
proc sql;
	create table	work.NonEmpRat_02&lastyr. as
	select			a.Naics, "NonEmpRat" as DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year, 
					case when a.value >0 and b.value is null then . 
						 else b.value/a.value
					end as value
	from			work.Final_VsIndAnn_agg as a
	left join		work.Final_VsTotal_agg as b
	on				(a.Naics=b.Naics) and (a.YearID=b.YearID) and (a.CensusPeriodID=b.CensusPeriodID) and (a.YearNo=b.YearNo) and (a.Year=b.Year);

	create table	template as
	select			Naics, YearID, CensusPeriodID, YearNo, Year,. as Value
	from			IP.Final_Intrasectorals
	order by		Naics, YearID, CensusPeriodID, YearNo, Year;

	create table	work.NonEmpRat_8702 as
	select			a.Naics, "NonEmpRat" as DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year, 
					case when a.value is null and a.CensusPeriodID<12 then b.value
					end as value
	from			work.template as a
	left join		work.NonEmpRat_02&lastyr. as b
	on				(a.Naics=b.Naics) and (b.YearID ='C12Y1A01');

	create table	work.NonEmpRat_87&lastyr. as
	select			a.Naics, "NonEmpRat" as DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year, 
					case when a.CensusPeriodID>12 and a.value is null then b.value
					end as value
	from			work.NonEmpRat_8702 as a
	left join		work.NonEmpRat_02&lastyr. as b
	on				(a.Naics=b.Naics) and (a.YearID=b.YearID) and (a.CensusPeriodID=b.CensusPeriodID) and (a.YearNo=b.YearNo) and (a.Year=b.Year);

	create table	work.NonEmpRat_87EY as
	select			a.Naics, "NonEmpRat" as DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year, 
					case when a.value is null then b.value
					     else a.value
					end as value
	from			work.Nonemprat_8702 as a
	left join		work.NonEmpRat_02&lastyr. as b
	on				(a.Naics=b.Naics) and (a.YearID=b.YearID);

quit;

/*LagtheNulls - Estimates missing data by holding the value constant to the prior year*/
data work.AdjustedNonEmpRat;
		set work.NonEmpRat_87EY;
run;

Proc sql;
	Create table 	work.NonEmpRatAdjustmentWorking as 
	select			a.Naics, a.CensusPeriodID, a.DataSeriesCodeID, a.Yearid, a.YearNo, a.Year,
					case 	when a.Value is null then b.Value 
							else a.Value 
					end 	as Value
	from			work.AdjustedNonEmpRat a 
	left join 		work.AdjustedNonEmpRat b
	on				(a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) and 
					(a.DataSeriesCodeID=b.DataSeriesCodeID) and (b.YearNo=a.YearNo-1);
quit;

data IP.Final_NonEmpRatios;
	set NonEmpRatAdjustmentWorking;
run;

proc datasets library=work kill noprint;
run;
quit;
