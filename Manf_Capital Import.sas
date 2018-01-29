/*Allows SEG to replace variable names with spaces from Excel files with an underscore*/
options validvarname=v7;

/**********************************************************************************************************************
*   Last change: June 21, 2017 by CG to incorporate new tab names in DMSP data                                        *
*   Previous changes: July 18, 2016                                                                                   *
*   By: Corby Garner                                                                                                  *
*   Changes: Changed all proc import statements to libname statements where possible                                  * 
*            For the 2014 update, input files were centralized. This program now reads data in from the new files.    *																						  
**********************************************************************************************************************/	


/***************************************************************************************/
/*STEP 1*/
/***************************************************************************************/
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

/*reading in BEA constant dollar 3-digit NAICS investment data gathered from DMSP"*/
libname BEA XLSX "P:\MFP Data\Capital\&last. Manufacturing Update\Manufacturing constant dollar investments 1901 to &last..xlsx";
	proc contents data=bea._all_ out=work.out noprint;
	run;
	data work.out;
	set work.out (where=(Name="constant"));
	if memname="README" then delete;
	Number_of_Observations + Type;
	run;
	/*Creating a macro variable for total number of tabs in the file*/
	 data work.asset_number;
	 set work.out end=last;
	 if last then output;
	 keep Number_of_Observations;
	 run;
	 data _null_;
	 set work.asset_number;
	 call symputx ("Last_Asset",Number_of_Observations);
	 run;
	 %put &Last_Asset;
	/*Creating macro variables for the names of BEA Assets in the raw data*/
	data _null_;
	set work.out nobs=x;
	      call symputx ("BEA_Asset"!!left(_n_),memname);
	 run;
	/*Writing data to the Capital library*/
	%macro importasset;
		%do asset = 1 %to &last_asset;
		data capital.&&BEA_Asset&asset;
			set BEA.&&BEA_Asset&asset;
		run;
		%end;
		%mend importasset;
		%importasset;
libname bea clear;

/*Reading in the list of NAICS indudstries*/
libname indys "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\INDYS.xlsx" ;
	data capital.indys;
	set indys.'INDYS$'n;
	run;
libname indys clear;

/*Reading all years data*/
libname years "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\Years.xlsx";
	/*1987-forward*/
	data capital.naicsyears; 
	set years.'years$'n;
	RUN;
	data capital.years; 
	set years.'years$'n;
	RUN;
	/*1958-forward*/
	data capital.allyears; 
	set years.'Allyears$'n;
	RUN;
	/*1901-forward*/
	data capital.structureyears;
	set years.'structureyears$'n;
	run;
	data capital.endyear ;
	set years.'endyear$'n;
	RUN;
libname years clear;

/*importing in BEA total deflators for each year for each asset type 1947-forward*/
libname btot "P:\MFP Data\Capital\&last Manufacturing Update\asset deflators 1901 to &last..xlsx";
	data deflator.btot;
	set btot.'BTOTN$'n;
	run;
libname btot clear;

/*Importing nominal investment, deflator and real investment*/
libname sptool "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\Special Tools.xlsx";
	data sptools.special_tools;
	set sptool.'Final_Data$'n;
	run;
libname sptool clear;

/*importing tax special tools series starting 1987; Tax factor for special tools is the same
as equipment tax factor*/
libname taxes "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\taxspt.xlsx";
	data sptools.taxspt;
	set taxes.'taxspt$'n;
	RUN;
libname taxes clear;

/*CFT Commodity Flow Table PPIs*/
libname ppi "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\Capital Deflators.xlsx";
	data deflator.commodity_flow_PPI;
	set ppi.'Commodity_PPIs$'n;
	run;

	data deflator.capdefasset5;
	set ppi.'Asset5$'n;
	run;
libname ppi clear;

/*tax factors beginning year 1987*/
libname taxes "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\Taxfac.xlsx";
	data capital.taxfac;
	set taxes.'Sheet1$'n;
	run;
libname taxes clear; 

/*
*******************************************************************************************************************
*                                                                                                                  *  
*                The following data is read in but is static and not updated every year                            *
*                                                                                                                  *
********************************************************************************************************************

/*Capital Flow Table taken from the BEA: http://www.bea.gov/bea/dn2/home/benchmark.htm*/
PROC IMPORT OUT= CAPITAL.equipment 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\equipmentcapitalflow.xls" 
            DBMS=EXCEL REPLACE;
RUN;
/*Capital Flow Table taken from the BEA: http://www.bea.gov/bea/dn2/home/benchmark.htm*/
PROC IMPORT OUT= CAPITAL.Structures 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\structurescapitalflow.xls" 
            DBMS=EXCEL REPLACE;
RUN;

/*2008 ACES Detailed Equipment*/
PROC IMPORT OUT= CAPITAL.ACES_2008_Equip_Original 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\ACES Equipment 2008.xlsx" 
            DBMS=EXCEL REPLACE;
			sheet="SAS_Import";
RUN;
/*2008 ACES Detailed Structures*/
PROC IMPORT OUT= CAPITAL.ACES_2008_Structures 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\ACES Structures 2008.xlsx" 
            DBMS=EXCEL REPLACE;
			sheet="SAS_Import";
RUN;
/*2012 ACES Detailed Equipment*/
PROC IMPORT OUT= CAPITAL.ACES_2012_Equip_Original 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\ACES Equipment 2012.xlsx" 
            DBMS=EXCEL REPLACE;
			sheet="SAS_Import";
RUN;
/*2012 ACES Detailed Structures*/
PROC IMPORT OUT= CAPITAL.ACES_2012_Structures 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\ACES Structures 2012.xlsx" 
            DBMS=EXCEL REPLACE;
			sheet="SAS_Import";
RUN;

/*CFT Commodity Flow Table*/
PROC IMPORT OUT= capital.commodity_flow_table 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\CFT Commodity Table.xlsx" 
            DBMS=EXCEL REPLACE;
RUN;
/*importing in single value for special tools for 1997 and single value of the deflator
for special tools years 1997- because that is the year of the capital flow chart - 
will need to change the value according to what year is used on capital flow chart*/
PROC IMPORT OUT= SPTOOLS.cfsptyr 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\cfsptyr.xls" 
            DBMS=EXCEL REPLACE;
RUN;
/*importing in single value for implicit price deflators for 4-digit output measures used
with finished goods and work-in-process.  The value is 1997 and single value of the deflator
1997- because that is the year of the capital flow chart - will need to change the value 
according to what year is used on capital flow chart*/
PROC IMPORT OUT= deflator.pfgbase 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\pfgbase.xls" 
            DBMS=EXCEL REPLACE;
RUN;

/*importing in service lives of the assets*/
/*Mean service life for each asset*/
libname livein xlsx "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs\All Service Lives.xlsx";
	data lives.lives_1_8;
	set livein.assets1_8;
	RUN;
	data lives.lives_12_24;
	set livein.Assets12_24;
	RUN;
	data lives.lives_9;
	set livein.Asset9;
	RUN;
	data lives.lives_10;
	set livein.Asset10;
	RUN;
	data lives.lives_11;
	set livein.Asset11;
	RUN;
	data lives.structures;
	set livein.Structures;
	RUN;
libname livein clear;

/*importing pre-1948 structures BEA deflators*/
PROC IMPORT OUT= deflator.strpre1948deflator 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\Strdfp48.xls" 
            DBMS=EXCEL REPLACE;
RUN;

/*importing historical structures capital expenditure times series beginning 1890 for NAICS
4 digit industries*/
PROC IMPORT OUT= CAPITAL.NAICSpre1958structures 
            DATAFILE= "R:\MFP DataSets\Manufacturing\Capital\SAS Inputs archive\NAICSstructures1890to1958_Nonemployer_Ratios.xls" 
            DBMS=EXCEL REPLACE;
			SHEET = 'Structures 1890-1958';
RUN;
 
/*Creating macro variables for the names of NAICS Industries*/
data _null_;
set capital.indys nobs=x;
      call symputx ("NAICS_Indy"!!left(_n_),NAICS);
 run;
