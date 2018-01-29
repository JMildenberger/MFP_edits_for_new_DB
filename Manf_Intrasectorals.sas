/* Intrasectoral Program 
  Created by - Chris Morris
  Last Modified - 01/29/2018 
  Modifed by - Jennifer Kim */

options symbolgen;

libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";
libname Input "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs";


/*Creates macro variable from textfile*/
data _null_;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
	  length dataset $29;
      input dataset firstyr lastyr baseperiod;
      call symput('baseperiod', trim(left(put(baseperiod, 2.))));
run;


/*Read in intrasectoral data*/
data work.Intrasectoral_raw;
	set Input.intraload_mfp;
run;


/*  Calculate & Aggregate Intrasectorals | XT09=IntSect2, XT41=VSIntra | (XT09+XT41) */
proc sql;
	create table 	work.IntSect2 as
	select	     	substr(IndustryCodeID,1,4) as Naics, *
	from 			work.intrasectoral_raw
	where			DataSeriesID = 'XT09';

	create table 	work.VsIntra as
	select	    	substr(IndustryCodeID,1,4) as Naics, *
	from 			work.intrasectoral_raw
	where		    DataSeriesID = 'XT41';

	create table	work.Intrasectorals as
	select			a.Naics, a.IndustryCodeID, 'intrasectorals'as DataSeriesCodeID, a.YearID, a.Year,
					a.Value + b.Value as Value
	from			work.intsect2 as a
	inner join 		work.vsintra as b
	on				(a.IndustryCodeID=b.IndustryCodeID) and (a.YearID=b.YearID);

	create table 	work.Intrasectorals_agg as
	select 			Naics, 'intrasectorals_agg' as DataSeriesCodeID, YearID, Year,
					sum(value) as Value
	from			work.Intrasectorals 
	group by		Naics, DataSeriesCodeID, YearID, Year;
quit;


/*	Extract the Year Number and Census Period ID Number from the variable YearID	*/
data work.Intrasectorals_agg;
	set work.Intrasectorals_agg;
	YearNo=input(substr(YearID,5,1),1.);
	CensusPeriodID = input(substr(YearID,2,2),2.);
run;


/*	Forward linking ratios are calculated for each CensusPeriodID (Year 6/ Year 1) */
Proc sql;
	Create table	work.CensusRatioAdjForward as
	Select 			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Intrasectorals_agg a
	inner join		work.Intrasectorals_agg b
	on				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and 
					(a.CensusPeriodID-1=b.CensusPeriodID) and (a.YearNo=1) and (b.YearNo=6)
	where			a.CensusPeriodID>&baseperiod;


/*	Backward linking ratios are calculated for each CensusPeriodID (Year 1 / Year 6) */
	Create table	work.CensusRatioAdjBack as
	Select 			a.Naics, a.DataSeriesCodeID, a.CensusPeriodID, b.Value/a.Value as Ratio
	from 			work.Intrasectorals_agg a
	inner join		work.Intrasectorals_agg b	
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


/* 	Define Census Period Linking Ratio Macro
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
		order by 	   	Naics, DataSeriesCodeID, CensusPeriodID;
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


/*Call Census Period Linking macro*/
%compound;


/*	The compounded linking ratios are multiplied by the Census chunk values to create a continuous series */
Proc sql;
	Create table	ip.Final_Intrasectorals as
	Select			a.Naics, a.DataSeriesCodeID, a.YearID, a.CensusPeriodID, a.YearNo, a.Year,
					case	when a.CensusPeriodID<&baseperiod then a.Value*b.Ratio
							when a.CensusPeriodID>&baseperiod then a.Value*c.Ratio
							when a.CensusPeriodID=&baseperiod then a.Value
					end as Value
	from			work.intrasectorals_agg a
	left join		work.BackWorking b
	on				(a.Naics=b.Naics) and (a.DataSeriesCodeID=b.DataSeriesCodeID) and (a.CensusPeriodID=b.CensusPeriodID)
	left join		work.ForwardWorking c
	on				(a.Naics=c.Naics) and (a.DataSeriesCodeID=c.DataSeriesCodeID) and (a.CensusPeriodID=c.CensusPeriodID)
	order by		Naics, DataSeriesCodeID, YearID;
quit;

proc datasets library=work kill noprint;
run;
quit;
