/*Cost of Services Program 
  Created by - Jason McClellan
  Last Modified - 01/29/2018 
  Modifed by - Jennifer Kim */

/*ABSTRACT 
  Cost of Services is calculated using a combination of sources including DMSP KLEMS, BEA KLEMS, and BEA IO Use. Cost of Capital is calculated as a residual once 
  Labor Compensation and Intermediate Purchases are removed from the Value of Production. In order to make sure that Cost of Capital doesn't become negative,
  we need to pull in the other IP Costs to calculate Cost of Capital. When Cost of Capital is negative, Cost of Capital is set to equal Capital Expenditures and
  Cost of Services is adjusted accordingly. */

options symbolgen; 
options validvarname=v7;

/*Define Permanent SAS Libraries*/
libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";
libname Capital "Q:\MFP\SAS Libraries\Manufacturing\Capital\capital";


/*Creates a macro variables from textfile*/
data _null_;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
	  length dataset $29;
      input dataset firstyr lastyr baseperiod;
	  year = trim(left(put(lastyr, 4.)));
	  lastyear_2 = substr(year,3,2);
	  lastyear_3 = substr(year,2,3);
	  call symput('dataset',trim(dataset));
	  call symputx ("lastyear", year);
	  call symputx ("lastyear_2", lastyear_2);
	  call symputx ("lastyear_3", lastyear_3);
run;


/*--------------------------------------------------------
Section 1, pull in the source files
----------------------------------------------------------*/
/*The three use tables below plus the classification file will probably not be updated until the 2012 Use table is released and the earlier IO tables are revised.*/
%let path_IO97=%str("R:\MFP DataSets\Manufacturing\IP\Inputs\IO Tables\1997 Use on 2012 Basis.xlsb");
%let path_IO02=%str("R:\MFP DataSets\Manufacturing\IP\Inputs\IO Tables\2002 Use on 2012 Basis.xlsb");
%let path_IO07=%str("R:\MFP DataSets\Manufacturing\IP\Inputs\IO Tables\2007 Use on 2012 Basis.xlsb");
%let path_Class=%str("R:\MFP DataSets\Manufacturing\IP\Inputs\IO Tables\Commodity Classification.xlsb");

/*The following three files come from DMSP's public MFP flat files found here (http://download.bls.gov/pub/time.series/mp/). Right now I manually download these
  files, but they could probably be pulled programatically. These are used to move our pre-1997 service values.*/
%let path_DMSP_sector=%nrstr('R:\MFP DataSets\Manufacturing\IP\SAS Inputs\mp.sector');
%let path_DMSP_measure=%nrstr('R:\MFP DataSets\Manufacturing\IP\SAS Inputs\mp.measure');
%let path_DMSP_Data=%nrstr('R:\MFP DataSets\Manufacturing\IP\SAS Inputs\mp.data.1.AllData');

/*This next file is the KLEMS file from the BEA. File can be found here: http://www.bea.gov/industry/gdpbyind_data.htm */
%let path_BEA=%str("R:\MFP DataSets\Manufacturing\IP\SAS Inputs\GDPbyInd_KLEMS_NAICS_1997-&lastyear..xlsx");

/*In this section, import the IO tables and calculate the SERFAC ratios. This step can probably be done outside of this program, but I like the idea
of calculating the SERFAC ratio dynamically just so I know the most recent values are being used. This section could be shortened with a macro.*/

PROC IMPORT 
OUT=Work.IO97
DataFile=&path_IO97
REPLACE;
RUN;

data work.IO97 (keep=NAICS IO Pro97 TC97 WHS97 RET97 PUR97);
set work.IO97;
if NAICS^="" then output; /*Sometimes there are blank rows. Remove them.*/
run;

PROC IMPORT 
OUT=Work.IO02
DataFile=&path_IO02
REPLACE;
RUN;

data work.IO02 (keep=NAICS IO Pro02 TC02 WHS02 RET02 PUR02);
set work.IO02;
if NAICS^="" then output; /*Sometimes there are blank rows. Remove them.*/
run;

PROC IMPORT 
OUT=Work.IO07
DataFile=&path_IO07
REPLACE;
RUN;

data work.IO07 (keep=NAICS IO Pro07 TC07 WHS07 RET07 PUR07);
set work.IO07;
if NAICS^="" then output; /*Sometimes there are blank rows. Remove them.*/
run;

/*The Class file lets use know whether an industry/commodity combination is a material, service, or something else.*/
PROC IMPORT 
OUT=Work.Class
DataFile=&path_Class.
DBMS=Excel
REPLACE;
RUN;

/*Read in Cost of Supplies*/
data work.Supplies_rawflat;
set ip.costofsupplies_ne;
CostofSupplies_NE = CostofSupplies_NE;
run;

proc sort data=work.Supplies_rawflat nodupkey;
by NAICS Year;
run;

PROC TRANSPOSE data=work.Supplies_rawflat out=work.Supplies_Raw (drop=_NAME_) prefix=y;
by NAICS;
ID Year;
Var CostofSupplies_NE;
run;

PROC IMPORT 
OUT=work.DMSP_Sector
DataFile=&path_DMSP_Sector.
DBMS=dlm
REPLACE;
Delimiter='09'x; /*Indicates that this is a tab delimited file*/
RUN;

/*Pull out the NAICS code from the jumble of the 'sector_name' series*/
data DMSP_Sector;
set DMSP_Sector;
	Start=find(sector_name,"(");
	End = length(sector_name);
	NAICS=substr(sector_name,start+7,End-Start-7);
run;

PROC IMPORT 
OUT=work.DMSP_Measure
DataFile=&path_DMSP_Measure.
DBMS=dlm
REPLACE;
Delimiter='09'x;
RUN;

PROC IMPORT 
OUT=work.DMSP_data
DataFile=&path_DMSP_data.
DBMS=dlm
REPLACE;
Delimiter='09'x;
RUN;

PROC IMPORT 
OUT=work.BEA
DataFile=&path_BEA.
DBMS=EXCEL
REPLACE;
sheet="E,M,S";
RUN;

data work.bea2 (drop=Code i Industry_Title rename=(temp=Industry_Title));
set work.bea;
	array aYear _997-_999 _000-_&lastyear_3;
	array aYear2 BEA_1997-BEA_&lastyear;
	do i=1 to dim(aYear);
		aYear2[i]=aYear[i];
	end;
	drop _997-_999 _000-_&lastyear_3;
	temp=strip(Industry_Title);
	if code="S" then output;
run;

PROC IMPORT 
OUT=work.BEA_Codes
DataFile=&path_BEA.
DBMS=EXCEL
REPLACE;
sheet="NAICS codes";
RUN;

data work.BEA_Codes2 (keep=F2 F3 rename=(F2=BEA_Code F3=Title));
set work.BEA_Codes;
if F2="" OR F3="" then delete;
run; 	


/*--------------------------------------------------------
Section 2, Match the Class with each Serfac
----------------------------------------------------------*/
PROC SQL;
	CREATE TABLE work.IO97_Match AS
	SELECT a.*, substr(a.NAICS,1,4) as Industry_4, b.classification
	FROM work.IO97 a inner join work.class b 
	ON (a.NAICS=b.NAICS) AND (a.IO=b.IO);
QUIT;

PROC SQL;
	CREATE TABLE work.IO02_Match AS
	SELECT a.*, substr(a.NAICS,1,4) as Industry_4, b.classification
	FROM work.IO02 a inner join work.class b 
	ON (a.NAICS=b.NAICS) AND (a.IO=b.IO);
QUIT;

PROC SQL;
	CREATE TABLE work.IO07_Match AS
	SELECT a.*, substr(a.NAICS,1,4) as Industry_4, b.classification
	FROM work.IO07 a inner join work.class b 
	ON (a.NAICS=b.NAICS) AND (a.IO=b.IO);
QUIT;


/*--------------------------------------------------------
Section 3, Sum up the material and services for each IO table
----------------------------------------------------------*/
PROC SQL;
	CREATE TABLE work.IO97_Sum AS
	SELECT Industry_4, sum(case when classification="M" THEN Pur97 ELSE 0 END) as Mat, 
						sum(case when classification="S" THEN Pro97 ELSE 0 END) as Serv,
						calculated Serv/calculated Mat as SerFac
	FROM work.IO97_Match
	Group By Industry_4;

	CREATE TABLE work.IO02_Sum AS
	SELECT Industry_4, sum(case when classification="M" THEN Pur02 ELSE 0 END) as Mat, 
						sum(case when classification="S" THEN Pro02 ELSE 0 END) as Serv,
						calculated Serv/calculated Mat as SerFac
	FROM work.IO02_Match
	Group By Industry_4;

	CREATE TABLE work.IO07_Sum AS
	SELECT Industry_4, sum(case when classification="M" THEN Pur07 ELSE 0 END) as Mat, 
						sum(case when classification="S" THEN Pro07 ELSE 0 END) as Serv,
						calculated Serv/calculated Mat as SerFac
	FROM work.IO07_Match
	Group By Industry_4;
QUIT;


/*--------------------------------------------------------
Section 4, Interpolate the SerFac Ratios
----------------------------------------------------------*/
data SerFac97_07;
merge IO97_sum(drop=Mat Serv rename=(Serfac=SerFac1997)) IO02_sum(drop=Mat Serv rename=(Serfac=SerFac2002)) 
			IO07_sum(drop=Mat Serv rename=(SerFac=SerFac2007));
by Industry_4;
run;

data SerFac97_07_inter;
retain Industry_4 SerFac1997-SerFac2007;
set SerFac97_07;
	SerFac1998=(SerFac2002-SerFac1997)/5+SerFac1997;
	SerFac1999=(SerFac2002-SerFac1997)/5+SerFac1998;
	SerFac2000=(SerFac2002-SerFac1997)/5+SerFac1999;
	SerFac2001=(SerFac2002-SerFac1997)/5+SerFac2000;

	SerFac2003=(SerFac2007-SerFac2002)/5+SerFac2002;
	SerFac2004=(SerFac2007-SerFac2002)/5+SerFac2003;
	SerFac2005=(SerFac2007-SerFac2002)/5+SerFac2004;
	SerFac2006=(SerFac2007-SerFac2002)/5+SerFac2005;
run;


/*--------------------------------------------------------
Section 5, Take the DMSP service values for 1987-1997
----------------------------------------------------------*/
/*Duration = 1 (Level)*/
/*Measure = 66 (Cost of Purchased Services, billions of current dollars)*/
data work.DMSP_Data2;
set work.DMSP_Data;
	Sector_Code=substr(series_id,4,4);
	Measure=substr(series_id,8,2);
	Duration=substr(series_id,10,1);
	if duration=1 AND Measure=66 then output;
run;

/*Match this data set to the sector name*/
PROC SQL;
	CREATE TABLE work.DMSP_Data3 AS
	SELECT a.sector_code, a.NAICS, b.year, b.value
	FROM work.DMSP_sector a inner join work.DMSP_data2 b
	ON (a.sector_code=input(b.sector_code,10.));
QUIT;

/*Find the ratio of current year to 'base year' 1997*/
PROC SQL;
	CREATE Table work.DMSP_rate AS
	SELECT a.sector_code, a.NAICS, b.year, (b.value/a.value) as rate
	FROM work.DMSP_data3 a inner join work.DMSP_data3 b
	ON (a.sector_code=b.sector_code)
	WHERE a.year=1997;
QUIT;


/*--------------------------------------------------------
Section 6, Find the 1997-2007 Cost of services
----------------------------------------------------------*/
/*Multiply the serfac ratio by the cost of supplies*/
data work.Service_97_07 (drop=y1987-y1996 y2008-y&lastyear);
length NAICS $6;
merge work.Supplies_raw work.Serfac97_07_inter(rename=(Industry_4=NAICS));
by NAICS;
%macro loop;
	%do i=1997 %to 2007;
		Services_&i.=y&i.*SerFac&i.;
	%end;
%mend loop;
%loop
drop y1997-y2007 serfac1997-serfac2007 ;
run;


/*--------------------------------------------------------
Section 7, Find the 1987-2006 Cost of services based on DMSP data
----------------------------------------------------------*/
/*First, create a DMSP to NAICS correspondence*/
data work.NAICS_IPS (keep=NAICS NAICS_3);
format NAICS_3 $8.;
set work.Service_97_07;
NAICS_3=substr(NAICS,1,3);
if NAICS_3 in ("311","312") then NAICS_3="311, 312"; 
if NAICS_3 in ("313", "314") then NAICS_3="313, 314";
if NAICS_3 in ("315", "316") then NAICS_3="315, 316";
run;

/*Now, merge to the DMSP rate dataset*/
PROC SQL;
	CREATE TABLE work.DMSP_Rate2 AS
	SELECT a.sector_code, a.NAICS as NAICS_3, a.year, a.rate, b.NAICS as NAICS_4
	FROM work.DMSP_rate a INNER JOIN work.NAICS_ips b
	ON (a.NAICS=b.NAICS_3);
QUIT;

/*Transpose the rates*/
PROC SORT data=work.DMSP_Rate2;
	by NAICS_4 year;
RUN;

PROC TRANSPOSE data=work.DMSP_Rate2 out=work.DMSP_Rate_wide prefix=DMSP_;
	by NAICS_4;
	id year;
	var rate;
run;

data work.DMSP_Rate_Wide (drop=DMSP_1997-DMSP_&lastyear _NAME_);
set work.DMSP_Rate_Wide;
run;

/*Multiply the DMSP rate by the 1987 Cost of services*/
data work.Service_87_07;
retain NAICS Services_1987-Services_2007;
merge work.Service_97_07 work.DMSP_Rate_Wide (rename=(NAICS_4=NAICS));
	%macro loop;
		%do i=1987 %to 1996;
			Services_&i.=DMSP_&i.*Services_1997;
		%end;
	%mend loop;
	%loop
	drop DMSP_1987-DMSP_1996;
run;


/*--------------------------------------------------------
Section 8, Find the 2008-forward Cost of services based on BEA data
----------------------------------------------------------*/
/*Merge the title with the descriptions*/
PROC SQL;
	CREATE TABLE work.BEA3 AS
	SELECT a.*, b.BEA_Code
	FROM work.BEA2 a Left Join work.BEA_Codes2 b
	on (a.Industry_Title=b.Title);
QUIT;

data work.BEA4;
retain BEA_Code Industry_Title BEA_1997-BEA_&lastyear;
set work.BEA3;
	if substr(BEA_Code,1,1)^="3" then delete;
run;

/*Find the ratio of year n divided by 1997*/
data work.BEA_Rate (drop=i);
set work.BEA4;
	array aYear BEA_2007-BEA_&lastyear;
	array aRate BEA_Rate_2007-BEA_Rate_&lastyear;
	do i = 1 to dim(aYear);
		aRate[i]=aYear[i]/aYear[1];
	end;
	drop BEA_1997-BEA_&lastyear;
run;

/*Attach the BEA rates to the main cost of services file*/
data work.Service_87_07_2;
length NAICS_3 $6.;
set work.Service_87_07;
	NAICS_3=substr(NAICS,1,3);
	if NAICS in ("3361", "3362", "3363") then NAICS_3="3361MV";
	if NAICS in ("3364", "3365", "3366", "3369") then NAICS_3="3364OT";
	if NAICS in ("3111", "3112", "3113", "3114", "3115", "3116", "3117", "3118", "3119", "3121", "3122") then NAICS_3="311FT";
	if NAICS in ("3131", "3132", "3133", "3141", "3149") then NAICS_3="313TT";
	if NAICS in ("3151", "3152", "3159", "3161", "3162", "3169") then NAICS_3="315AL";
run;

/*Merge the BEA rates to the Service dataset*/
PROC SQL;
	CREATE TABLE work.Service_87_&lastyear_2 AS
	SELECT a.*, b.* 
	FROM work.Service_87_07_2 a Left Join work.Bea_rate b
	ON (a.NAICS_3=b.BEA_Code);
QUIT;

data work.Service_87_&lastyear_2._Prelim (drop= i NAICS_3 BEA_RATE_2007-BEA_RATE_&lastyear Industry_Title BEA_Code);
Retain NAICS Services_1987-Services_&lastyear;
set work.Service_87_&lastyear_2;
	array aServ Services_2008-Services_&lastyear;
	array aRate BEA_Rate_2008-BEA_Rate_&lastyear;

	do i=1 to dim(aServ);
		aServ[i]=aRate[i]*Services_2007;
	end;
run;

/*TRANSPOSE the Service file*/
PROC SORT data=work.Service_87_&lastyear_2._Prelim;
by NAICS;
run;
PROC TRANSPOSE data=work.Service_87_&lastyear_2._Prelim OUT=work.Service_Prelim_Flat prefix=Services_1987;
by NAICS;
RUN;
data work.Service_Prelim_Flat2 (drop=_NAME_ rename=(Services_19871=value temp=year));
retain NAICS DataSeriesCodeID Value Year;
set work.Service_Prelim_Flat;
	_NAME_=substr(_NAME_,10,4);
	temp=input(_NAME_,8.);
	DataSeriesCodeID="Pre_Serv";
run;


/*--------------------------------------------------------
Section 9, Pull in other IP files Transpose them to be a flat file
----------------------------------------------------------*/
/*Cost of Electricity*/
data work.Elect_flat (rename=(CostofElectricity=Value));
retain NAICS DataSeriesCodeID Value Year;
set ip.costofelectricity;
DataSeriesCodeID="CostElec";
run;

/*Cost of Fuels*/
data work.Fuels_flat (rename=(CostofFuels=Value));
retain NAICS DataSeriesCodeID Value Year;
set ip.costoffuels;
DataSeriesCodeID="CostFuel";
run;

/*Cost of Supplies*/
data work.Supplies_final_flat (rename=(CostofSupplies=Value));
retain NAICS DataSeriesCodeID Value Year;
set ip.costofsupplies;
DataSeriesCodeID="CostSupl";
run;

/*Capital Expenditures*/
data work.CapEx1;
set capital.naicscapexp;
run;

data work.CapEx1 (keep=NAICS year Total);
set work.CapEx1;
if Year>=1987 AND Year <2002 then output;
run;

data work.CapEx2;
set capital.newcapexp;
run;

data work.CapEx2 (keep=NAICS year Total);
set work.CapEx2;
run;

data work.CapEx_all (drop=NAICS rename=(temp=NAICS));
set work.CapEx1 work.CapEx2;
temp=input(compress(NAICS),$4.);
run;

/* This part of the program pulls in the source data from IPS*/
Libname SQL ODBC DSN=IPSTestDB schema=sas;

/*Read in ValProd and LComp files*/
Proc sql;
	Create table 	work.valprod_lcomp as 
	select Distinct Industry as NAICS, DataSeries as DataSeriesCodeID, DataSeriesID, Year, Value
	from 			&dataset
	where 			DataSeriesID in ('T30','L02') and (substr(IndustryID,3,1)="3") and DigitID = "4-Digit"
	order by 		NAICS, DataSeriesID, Year;
quit;

proc sql;
	create table 	work.ValProd as
	select			*
	from 			work.valprod_lcomp
	where 			DataSeriesID = "T30"
	order by 		NAICS, Year;

	create table 	work.LComp as 
	select 			*
	from 			work.valprod_lcomp
	where 			DataSeriesID = "L02"
	order by 		NAICS, Year;
quit;

/*Subtract ValProd minus LComp minus Cost of Supplies minus Fuels minus Elec minus Services (prelim). This is cost*/
/*of capital (prelim).*/

PROC SQL;
	CREATE TABLE work.CapCost_Prelim AS
	SELECT a.NAICS, "Pre_CapC" as DataSeriesCodeID, a.Value-b.Value-c.Value/1000-d.Value/1000-e.Value/1000-f.Value/1000 as Value, a.year
	FROM work.ValProd a inner join work.LComp b
		ON (a.NAICS=b.NAICS) AND (a.Year=b.Year)
			INNER JOIN work.Elect_flat c
			on (a.NAICS=c.NAICS) AND (a.Year=c.Year)
				INNER JOIN work.Fuels_flat d
				on (a.NAICS=d.NAICS) and (a.Year=d.Year)
					INNER JOIN work.supplies_final_flat e
					on (a.NAICS=e.NAICS) AND (a.Year=e.Year)
						INNER JOIN work.service_prelim_flat2 f
						ON (a.NAICS=f.NAICS) and (a.Year=f.Year);
QUIT;

/* Write-out file with Preliminary CapCost, including negative values */
data work.CapCost_Prelim_analysis;
	retain NAICS DataSeriesCodeID Year Value;
	length NAICS $8;
	set work.CapCost_Prelim;
run;

data work.CapCost_Prelim_negative;
	set work.CapCost_Prelim_analysis;
	if Value>0 then delete;
run;

proc export
	data=work.CapCost_Prelim_analysis
	outfile="J:\SAS Testing\MFP Re-write\Output Data\CapCost_prelim.xlsx"
	DBMS=xlsx replace;
	sheet="CapCost_prelim";
quit;

proc export
	data=work.CapCost_Prelim_negative
	outfile="J:\SAS Testing\MFP Re-write\Output Data\CapCost_prelim.xlsx"
	DBMS=xlsx replace;
	sheet="CapCost_prelim_negative";
quit;

/*Now, if the CapCost_Prelim is less than 0, then set CapCost equal to CapExpenditure*/
PROC SQL;
	CREATE TABLE work.CapCost_Adjust AS
	SELECT a.NAICS, "CapCostF" as DataSeriesCodeID, (case when a.Value<0 then b.Total ELSE a.Value END) as Value, a.year
	FROM work.CapCost_prelim a inner join work.CapEx_all b
	ON (a.NAICS=b.NAICS) and (a.year=b.year);
QUIT;

/*Now, the adjusted cost of services is equal to Service_prelim_flat2-(capcost_adjust-CapCost_prelim)*/
PROC SQL;
	CREATE TABLE work.Service_Final AS
	SELECT a.NAICS, "Serv_Fin" as DataSeriesCodeID, (a.value-(b.value-c.value)*1000) as value, a.year
	FROM work.Service_prelim_flat2 a Inner Join work.CapCost_adjust b
	ON (a.NAICS=b.NAICS) and (a.Year=b.Year)
		INNER JOIN work.CapCost_prelim c
		ON (a.NAICS=c.NAICS) and (a.Year=c.Year);	
QUIT;

PROC Sort data=work.service_Final;
by NAICS year;
run;

/*Save Final Cost of Services to IP SAS Library*/
data ip.Cost_Srv;
set work.service_final;
run;

proc datasets library=work kill noprint;
run;
quit;
