/* Price of Materials - for Sectoral MFP
   Chris Morris & Jennifer Kim
   Last Modified: January 29, 2018 */
  
options validvarname = V7;
libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";

/*Creates macro variable from textfile*/
data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('lastyr', trim(left(put(lastyr, 4.))));
run;

/*****************************************************************************/
/*  READ-IN INPUT FILES: DOMESTIC DEFLATORS, IMPORT DEFLATORS, AND IO TABLES */
/****************************************************************************/   

/* Read in Domestic Deflators from IP SAS library */
data work.IO_Domestic_all;
	set IP.IO_deflators_all;
run;

/*Read in the import prices and shares. These will be merged with the domestic deflators*/
libname Import xlsx 'R:/MFP DataSets/Manufacturing/IP/Inputs/Import Deflators.xlsx';

data work.Import_Deflators;
	set Import.IO_Import_Deflators_Rebased;
	if IO = "" then delete;
run;

/*Transpose historical deflators. */
Proc Sort data=work.Import_Deflators;
	by IO;
run;

Proc Transpose data=work.Import_Deflators out=work.Import_Deflators_Flat1 (rename=(_NAME_= Year COL1=Value) drop=_LABEL_);
	by IO;
run;

/*Convert year to numeric*/
Proc Sql;
	Create table  	work.Import_Deflators_Flat as 
    Select          IO, input(substr(Year,2,4),4.) as Year, Value
    from 	     	work.Import_Deflators_Flat1;
quit;

/*Read in IO tables and Import matrices. These will be used to both combine import and domestic prices, as well as calculate the final price of
materials and price of services.*/
Proc Import out = work.IO97
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/1997 Use on 2012 Basis.xlsx'
			replace;
run;

Proc Import out = work.IO97_Import
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/1997 Import Matrix on 2012 Basis.xlsx'
			replace;
run;

Proc Import out = work.IO02
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/2002 Use on 2012 Basis.xlsx'
			replace;
run;

Proc Import out = work.IO02_Import
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/2002 Import Matrix on 2012 Basis.xlsx'
			replace;
run;

Proc Import out = work.IO07
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/2007 Use on 2012 Basis.xlsx'
			replace;
run;

Proc Import out = work.IO07_Import
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/2007 Import Matrix on 2012 Basis.xlsx'
			replace;
run;

/*Pull in industry classification table and merge to the previous table (IO_ALL). We only calculate IO ratios for materials
  NOTE: We only want materials and services */
Proc Import out = work.Class
			datafile = 'R:/MFP DataSets/Manufacturing/IP/Inputs/IO Tables/Commodity Classification.xlsb'
			replace;
run;

/*****************************/
/*IMPORT RATIOS AND IO TABLES*/
/*****************************/

/* Stack the IO datasets.*/
Proc Sql;
	Create table 	work.IO_All as
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 1997 as Year   from work.IO97 (rename=(Pro97=PRO TC97=TC WHS97=WHS RET97=RET PUR97=PUR)) union all
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 2002 as Year   from work.IO02 (rename=(Pro02=PRO TC02=TC WHS02=WHS RET02=RET PUR02=PUR)) union all
	Select 			IO, Naics, PRO, TC, WHS, RET, PUR, 2007 as Year   from work.IO07 (rename=(Pro07=PRO TC07=TC WHS07=WHS RET07=RET PUR07=PUR))
	order by		IO, Naics, Year;
quit;

Proc Sql;
	Create table	work.IO_All2 as 
	Select			a.Naics, a.IO, a.PRO, a.TC, a.WHS, a.RET, a.PUR, a.Year, b.classification 
	from 			work.IO_All a
	inner join		work.Class b
	on				(a.IO=b.IO) and (a.Naics=b.Naics)
	where			b.classification in ('M','S')          
	order by		a.Naics, a.IO, a.Year;
quit;

/*Now combine the import matrices into a single datatable*/
Proc Sql;
	Create table 	work.IO_All_Import as
	Select 			IO, Naics, Val, 1997 as Year   from	work.IO97_Import (rename=(Val97=Val)) union all
	Select 		    IO, Naics, Val, 2002 as Year   from	work.IO02_Import (rename=(Val02=Val)) union all
	Select 		    IO, Naics, Val, 2007 as Year   from work.IO07_Import (rename=(Val07=Val))
	order by		IO, Naics, Year;
quit;

/*Merge the IO_All with the IO_All_Import. This will allow us to find the import ratio for each industry/commodity combination*/
Proc Sql;
	Create table	work.IO_Merge2 as 
	Select			a.IO, a.Naics, a.PRO, a.TC, a.WHS, a.RET, a.PUR, a.Year, a.classification as Classification, b.Val,
					case when b.Val/a.Pro is null then 0
						 when b.Val/a.Pro > 1 then 1
						 else b.Val/a.Pro
					end as Import_Ratio
	from 			work.IO_All2 a
	left join		work.IO_All_Import b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

/*Pull out the Import Ratios to interpolate, since we only have ratios for 1997, 2002, and 2007*/
Proc Sql;
	Create table	work.Import_Ratios as
	Select			IO, Naics, Import_Ratio, Year
	from			work.IO_Merge2;
quit;

/*Interpolate import ratios*/
/*Step:1 Create unique Naics - IO combinations with years from 1987-End Year (EY)*/
Proc Sql;
	Create table  	work.YearStructure_87EY as 
    Select          Distinct a.IO, a.Naics, b.Year
    from 	     	work.Import_Ratios a
	inner join		work.IO_Domestic_All b
	on				(a.IO=b.IO);
quit;

/*Step:2 Join IO Import Ratios (every 5 years) to year structure*/
Proc Sql;
	Create table  	work.ImportRatios_5yrs as 
    Select          Distinct a.IO, a.Naics, a.Year, b.Import_Ratio
    from 	     	work.YearStructure_87EY a
	left join		work.Import_Ratios b
	on				(a.IO=b.IO) and (a.Naics = b.Naics) and (a.Year=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

/*Step:3 Add CensusPeriodID and CensusYear from the databse and hold 1997 import ratios constant back to 1987*/
libname SQL ODBC DSN=IPSTestDB  schema=sas;

/*Pull in the YearID map from IPS Database */
data work.Report_YearsCensusPeriod;
	set	sql.Report_YearsCensusPeriod;
	if CensusPeriodID > 10 and CensusPeriodID<13;
run;

/*Add CensusPeriodID and CensusYear from the database for interpolation*/
Proc Sql;
	Create table  	work.AddYearNo_CensusPeriod as 
    Select          Distinct a.IO, a.Naics, a.Year, b.CensusPeriodID, b.CensusYear as YearNo, a.Import_Ratio
    from 	     	work.ImportRatios_5yrs a
	left join		work.Report_YearsCensusPeriod b
	on				(a.Year=b.Year)
	order by		a.IO, a.Naics, b.Year;
quit;

/*Extrapolate 1997 import ratio back to 1987 and 2007 import ratio forward through EY*/
Proc Sql;
	Create table  	work.ExtrapolateImportRatios as 
    Select          Distinct a.IO, a.Naics, a.Year, a.CensusPeriodID, a.YearNo, 
					case when a.Year<1997 then b.Import_Ratio
						 when a.Year>2007 then c.Import_Ratio
						 else a.Import_Ratio
					end as Import_Ratio
    from 	     	work.AddYearNo_CensusPeriod a
	left join		work.AddYearNo_CensusPeriod b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (b.Year=1997)
	left join		work.AddYearNo_CensusPeriod c
	on				(a.IO=c.IO) and (a.Naics=c.Naics) and (c.Year=2007)
	order by		a.IO, a.Naics, a.Year;
quit;

/*Interpolate import ratio benchmarks*/
Proc sql;
	Create table  	work.ImportRatioDiff as 
    Select          a.IO, a.Naics, a.CensusPeriodID, (a.Import_Ratio-b.Import_Ratio)/5 as IncrementValue
    from 	     	work.ExtrapolateImportRatios a
	inner join		work.ExtrapolateImportRatios b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) and (a.YearNo=6) and (b.YearNo=1)
	order by		a.IO, a.Naics, a.CensusPeriodID;
quit;

proc sql;
	Create table	work.ImportRatioWorking as
	Select			a.IO, a.Naics, a.Year, a.CensusPeriodID, a.YearNo, a.Import_Ratio, 
					case 	when b.IncrementValue is null then 0 
							else b.IncrementValue 
					end 	as IncrementValue
	from			work.ExtrapolateImportRatios a
	left join 		work.ImportRatioDiff b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) 
	order by		a.IO, a.Naics, a.Year;
quit;

proc sql;
	Create table	work.ImportRatioAnnualRatio as
	Select			a.IO, a.Naics, a.CensusPeriodID, a.Year, a.YearNo,(a.IncrementValue*(a.YearNo-1))+b.Import_Ratio as Import_Ratio
	from			work.ImportRatioWorking a
	inner join		work.ImportRatioWorking b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.CensusPeriodID=b.CensusPeriodID) and (b.YearNo=1)
	order by 		a.IO, a.Naics, a.Year;
quit;

/*Create final interpolated and extrapolated import ratio dataset.*/
Proc sql;
	Create table	work.Import_Ratios_Flat as
	Select			Distinct a.IO, a.Naics, a.Year,
					case when a.Import_ratio is null then b.Import_Ratio
						 else a.Import_Ratio 
					end as Import_Ratio
	from			work.ExtrapolateImportRatios a
	left join		work.ImportRatioAnnualRatio b
	on				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year=b.Year)
	order by 		a.IO, a.Naics, a.Year;
quit;

/*******************************************************************************************************
  We now want to calculate combined domestic/import prices. Take the previously calculated import     
  ratios and match them up with import deflators, where available. If no import deflator is available,
  then the import ratio will be zero. If the industry/commodity combination is intrasectoral, then set 
  the import ratio equal to 1. We set to 1 because we remove all domestic intrasectoral shipments, but
  not imported intrasectoral shipments.															   
  Only do this for materials. And we only do this for the PRO value, not anything else.               
 ********************************************************************************************************/

/* Merge the import ratio file with the import deflator and domestic deflator files.
   Merge the domestic prices, import prices, and import ratios together. */
Proc Sql;
	Create table	work.Import_Merge as 
	Select			a.IO, a.Naics, a.Year, a.Import_Ratio, b.Value as Imp_Defl, c.Value as Dom_Defl
	from 			work.Import_Ratios_Flat a
	left join		work.Import_Deflators_Flat b
	on				(a.IO=b.IO) and (a.Year=b.Year)
	left join		work.IO_Domestic_All c
	on				(a.IO=c.IO) and (a.Year=c.Year)        
	order by		a.IO, a.Naics, a.Year;
quit;

/*Modify work.Import_Merge
If there's an intrasectoral transaction, set the import ratio to 1, which assumes the domestic component goes away.
If the Imp_Defl is null, then set the import_ratio to equal zero. This will override intrasectoral cases if there's no import deflator.
If the Imp_Defl is null, then set the Imp_Defl to 100. This number doesn't matter since the import ratio has been set to 0. But we need a value
to prevent any errors from showing up in future aggregations.*/
Proc Sql;
	Create table	work.Import_Merge2 as 
	Select			IO, Naics, Year, 
					case when substr(IO,1,4)=substr(Naics,1,4) then 1  /* NOTE: FOR GROSS VALUE ADDED REMOVE LINE */
						 when Imp_Defl is null then 0
						 else Import_Ratio
					end as Import_Ratio,
					case when Imp_Defl is null then 100
						 else Imp_Defl
					end as Imp_Defl, Dom_Defl
	from			work.Import_Merge
	order by		IO, Naics, Year;
quit;

/*	Calculating average annual share of Import Ratio */
Proc Sql;
	Create table  	work.AverageAnnualShares_ImportRatio as 
    Select          a.IO, a.Naics, a.Year, (a.Import_Ratio+b.Import_Ratio)/2 as Share_ImportRatio
    from 	     	work.Import_Merge2 a 
	left join 		work.Import_Merge2 b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year-1=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

/*	Calculating logarithmic change in import and domestic deflators */
Proc Sql;
	Create table  	work.LogChg_ImpDefl as 
    Select          a.IO, a.Naics, a.Year, log(a.Imp_Defl)-log(b.Imp_Defl) as LogChg_ImpDefl
    from 	     	work.Import_Merge2 a
	left join 		work.Import_Merge2 b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year-1=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

proc sql;
	Create table  	work.LogChg_DomDefl as 
    Select          a.IO, a.Naics, a.Year, log(a.Dom_Defl)-log(b.Dom_Defl) as LogChg_DomDefl
    from 	     	work.Import_Merge2 a
	left join 		work.Import_Merge2 b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year-1=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

/*Multiply log change in Import by Import ratio, then mulitply log change in domestic price by (1-Import Ratio)*/
Proc Sql;
	Create table  	work.LogShare_ImpDefl as 
    Select          a.IO, a.Naics, a.Year, b.Share_ImportRatio*a.LogChg_ImpDefl as LogShare_ImpDefl
    from 	     	work.LogChg_ImpDefl a
	left join 		work.AverageAnnualShares_ImportRatio b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year=b.Year)
	order by		a.IO, a.Naics, a.Year;

	Create table  	work.LogShare_DomDefl as 
    Select          a.IO, a.Naics, a.Year, (1-b.Share_ImportRatio) * a.LogChg_DomDefl as LogShare_DomDefl
    from 	     	work.LogChg_DomDefl a
	left join 		work.AverageAnnualShares_ImportRatio b
    on 				(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year=b.Year)
	order by		a.IO, a.Naics, a.Year;
quit;

/*	Calculating exponent of sum of weighted product growth rates | Exp (Sum(LogarithmicChange*AverageAnnualShares))*/
Proc Sql;
	Create table  	work.ExpSum as 
    Select          a.IO, a.Naics, a.Year, exp(sum(a.LogShare_ImpDefl+b.LogShare_DomDefl)) as Value
    from 	     	work.LogShare_ImpDefl a
	inner join		work.LogShare_DomDefl b
    on	 			(a.IO=b.IO) and (a.Naics=b.Naics) and (a.Year=b.Year) 
	Group by		a.IO, a.Naics, a.Year;
quit;

%macro chain;
Proc sql;
Create table 	work.IO_Combined_M as
Select 			a.NAICS, a.IO, a.Year,
				case when a.year=1987 then 100
				%do i = 1988 %to &lastyr.;
					when a.Year=&i then
					%do b = &i %to 1988 %by -1;
						_&b..Value*
					%end;
					100
				%end;
				end as Defl
from 			work.ExpSum a
				%do c = 1988 %to &lastyr.;
					left join work.ExpSum _&c on (a.IO=_&c..IO) and (a.Naics=_&c..Naics) and _&c..year=&c
				%end;
order by 		NAICS, IO, Year;
quit;
%mend chain;
%chain;

/*#####################################################################################################
  #IO_Combined_M has the combined import/domestic prices for each industry/commodity combination for  #
  #materials. We now take the IO table, find the commodity share for each 4-digit consuming industry. #
  #Note on intrasectorals: If an intrasectoral shipment, we want to remove the domestic portion of the#
  #consuming industry.																				  #
  #####################################################################################################*/

/*We will interpolate the IO table for all variables. This will be used to find averages for both
materials and services.*/
Proc Sort data=work.IO_ALL2 out=work.IO_All3;
	by Naics IO Year Classification;
run;

Proc Transpose data=work.IO_All3 out=work.IO_All_Flat1 (rename=(_NAME_= Variable COL1=Value) drop=_LABEL_);
	by Naics IO Year Classification;
run;

Proc sql;
	Create table	work.IO_All_Flat as
	Select			Naics, IO, Year, Classification, Variable, Value
	from			work.IO_All_Flat1 
	order by		NAICS, IO, Year;
quit;		

/*We can split of materials and services now, since they are calculated slightly differently
from this point forward. NOTE: We only use PUR values for services*/
Proc Sql;
	Create table	work.IO_All_Flat_Mat as 
	Select			substr(NAICS,1,4) as Naics_4, Naics, IO, Variable, Classification, Year, Value 
	from 			work.IO_All_Flat 
	where			Variable in ('PRO', 'RET', 'TC', 'WHS') and Classification = 'M'          
	order by		Naics, IO, Year;
quit;

proc sql;
	Create table	work.IO_All_Flat_Srv as 
	Select			substr(NAICS,1,4) as Naics_4, Naics, IO, Variable, Classification, Year, Value
	from 			work.IO_All_Flat 
	where			Variable = 'PUR' and Classification = 'S'           
	order by		Naics, IO, Year;
quit;

/*Merge IO_All_Flat_Mat and Import_Ratios_flat.*/
Proc Sql;
	Create table	work.IO_All_Flat_Mat2 as 
	Select			a.Naics_4, a.Naics, a.IO, a.Year, a.Variable, a.Classification, a.Value, b.Import_Ratio
	from 			work.IO_All_Flat_Mat a
	left join		work.Import_Ratios_Flat b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Year=b.Year)   
	order by		a.Naics, a.IO, a.Year;
quit;

/* For SECTORAL price of materials, if the variable is PRO and it's an intrasectoral shipment and there's a 
   corresponding import deflator, then we remove the domestic share */
proc sql;
    Create table	work.IO_All_Flat_Mat3 as 
	Select			a.NAICS_4, a.Naics, a.IO, a.Year, a.Variable, a.Classification, a.Value, a.Import_Ratio, b.Value as Imp_Defl, 
					case when a.NAICS_4=substr(a.IO,1,4) and Variable="PRO" then 'True'	/*Create 'intra' to make logical expressions easier*/	
						 else 'False'
					end as Intra,
					case when b.Value is null then 'False'	/*Create variable to test if there's an import deflator*/
						 else 'True'
					end as HasImp   
	from 			work.IO_All_Flat_Mat2 a
	left join		work.Import_Deflators_Flat b
	on				(a.IO=b.IO) and (a.Year=b.Year)   
	order by		a.Naics, a.IO, a.Year;
quit;

proc sql;
	Create table	work.IO_All_Flat_Mat4 as 
	Select			NAICS_4, Naics, IO, Year, Variable, Classification, 
					case when Intra = 'True' and HasImp = 'True' then Value*Import_Ratio	
						 when Intra = 'True' and HasImp = 'False' then 0
						 else Value
					end as Value, Import_Ratio, Imp_Defl
	from 			work.IO_All_Flat_Mat3 
	order by		Naics, IO, Year;
quit;

proc sort data=work.IO_ALL_Flat_Mat4 out=work.IO_ALL_Flat_Mat4;
	by Naics_4 Naics IO Year;
run;

/*Calculate shares*/
Proc Sql;
	Create table	work.IO_All_Flat_Mat5 as 
	Select			Naics_4, Naics, IO, Year, Variable, Classification, Value, Import_Ratio, 
					sum(Value) as Total, value/sum(value) as Percent
	from 			work.IO_All_Flat_Mat4 
	group by		Naics_4, Year
	order by		Naics_4, Naics, IO, Year;
quit;

/*Interpolate the shares. */
/*Step:1 Create unique Naics - IO combinations with years from 1987-End Year (EY)*/
Proc Sql;
	Create table  	work.YearStructure2_87EY as 
    Select          Distinct a.Naics, substr(Naics,1,4) as Naics_4, a.IO, b.Year
    from 	     	work.IO_All_Flat_Mat5 a
	inner join		work.IO_Domestic_All b
	on				(a.IO=b.IO);
quit;

%macro interpolate_shares(dsn,var);
/*Step:2 Join Shares (every 5 years) to year structure*/
Proc Sql;
	Create table  	work.&dsn.Shares_5yrs as 
    Select          a.Naics_4, a.Naics, a.IO, a.Year, b.Variable, b.Percent
    from 	     	work.YearStructure2_87EY a
	left join		work.IO_All_Flat_Mat5 b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Year=b.Year)
	where			b.Variable is null or b.Variable = &var.
	order by		a.Naics_4, a.Naics, a.IO, a.Year;
quit;

/*Step:3 Add CensusPeriodID and CensusYear from the databse and hold 1997 shares constant back to 1987*/
libname SQL ODBC DSN=IPSTestDB  schema=sas;

/*Pull in the YearID map from IPS Database */
data work.Report_YearsCensusPeriod;
	set	sql.Report_YearsCensusPeriod;
	if CensusPeriodID > 10 and CensusPeriodID<13;
run;

/*Add CensusPeriodID and CensusYear from the database for interpolation*/
Proc Sql;
	Create table  	work.AddYearNo_CensusPeriod_&dsn. as 
    Select          Distinct a.Naics_4, a.Naics, a.IO, a.Year, b.CensusPeriodID, b.CensusYear as YearNo, a.Variable, a.Percent
    from 	     	work.&dsn.shares_5yrs a
	left join		work.Report_YearsCensusPeriod b
	on				(a.Year=b.Year)
	order by		a.Naics_4, a.Naics, a.IO, b.Year;
quit;

/*Extrapolate 1997 share back to 1987 and 2007 share forward through EY*/
Proc Sql;
	Create table  	work.ExtrapolateShares&dsn. as 
    Select          Distinct a.Naics_4, a.Naics, a.IO, a.Year, a.CensusPeriodID, a.YearNo, a.Variable, 
					case when a.Year<1997 then b.Percent
						 when a.Year>2007 then c.Percent
						 else a.Percent
					end as Percent
    from 	     	work.AddYearNo_CensusPeriod_&dsn. a
	left join		work.AddYearNo_CensusPeriod_&dsn. b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (b.Year=1997)
	left join		work.AddYearNo_CensusPeriod_&dsn. c
	on				(a.Naics=c.Naics) and (a.IO=C.IO) and (c.Year=2007)
	order by		a.Naics_4, a.Naics, a.IO, a.Year;
quit;

/*Interpolate benchmark shares*/
Proc sql;
	Create table  	work.&dsn.ShareDiff as 
    Select          a.Naics_4, a.Naics, a.IO, a.Variable, a.CensusPeriodID, (a.Percent-b.Percent)/5 as IncrementValue
    from 	     	work.ExtrapolateShares&dsn. a
	inner join		work.ExtrapolateShares&dsn. b
    on 				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.CensusPeriodID=b.CensusPeriodID) and (a.YearNo=6) and (b.YearNo=1)
	order by		a.Naics_4, a.Naics, a.IO, a.CensusPeriodID;

	Create table	work.&dsn.ShareWorking as
	Select			a.Naics_4, a.Naics, a.IO, a.Year, a.Variable, a.CensusPeriodID, a.YearNo, a.Percent, 
					case 	when b.IncrementValue is null then 0 
							else b.IncrementValue 
					end 	as IncrementValue
	from			work.ExtrapolateShares&dsn. a
	left join 		work.&dsn.ShareDiff b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.CensusPeriodID=b.CensusPeriodID) 
	order by		a.Naics_4, a.Naics, a.IO, a.Year;

	Create table	work.&dsn.ShareAnnualRatio as
	Select			a.Naics_4, a.Naics, a.IO, a.Variable, a.CensusPeriodID, a.Year, a.YearNo,(a.IncrementValue*(a.YearNo-1))+b.Percent as Percent
	from			work.&dsn.ShareWorking a
	inner join		work.&dsn.ShareWorking b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.CensusPeriodID=b.CensusPeriodID) and (b.YearNo=1)
	order by 		a.Naics_4, a.Naics, a.IO, a.Year;
quit;

/*Create final interpolated and extrapolated shares dataset.*/
Proc sql;
	Create table	work.&dsn.Share_Flat as
	Select			Distinct a.Naics_4, a.Naics, a.IO, &var. as Variable, a.Year,
					case when a.Percent is null then b.Percent
						 else a.Percent 
					end as Percent
	from			work.ExtrapolateShares&dsn. a
	left join		work.&dsn.ShareAnnualRatio b
	on				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Year=b.Year)
	order by 		a.Naics_4, a.Naics, a.IO, a.Year;
quit;
%mend interpolate_shares;

%interpolate_shares(PRO,'PRO');
%interpolate_shares(RET,'RET');
%interpolate_shares(TC,'TC');
%interpolate_shares(WHS,'WHS');

/* Merge Shares into 1 flatfile. */
Proc Sql;
	Create table 	work.Shares_Flat as
	Select 			Distinct Naics_4, Naics, IO, Variable, Year, Percent	from work.PROShare_Flat union all
	Select 			Distinct Naics_4, Naics, IO, Variable, Year, Percent 	from work.WHSShare_Flat union all
	Select 			Distinct Naics_4, Naics, IO, Variable, Year, Percent	from work.TCShare_Flat union all
	Select 			Distinct Naics_4, Naics, IO, Variable, Year, Percent 	from work.RETShare_Flat 
	order by		Naics_4, Naics, IO, Variable, Year;
quit;

/*	Calculating average annual share of IO_Naics_Revenue */
Proc Sql;
	Create table  	work.Shares_AverageAnnualShares as 
    Select          a.Naics_4, a.Naics, a.IO, a.Variable, a.Year, (a.Percent+b.Percent)/2 as Value
    from 	     	work.Shares_Flat a 
	left join 		work.Shares_Flat b
    on 				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Variable=b.Variable) and (a.Year-1=b.Year)
	order by		Naics_4, Naics, IO, Variable, Year;
quit;

/*We need to associate the margin commodities with the appropriate deflator*/
proc sql;
	Create table  	work.Shares_Flat2 as 
    Select          Naics_4, Naics, IO, Variable, Year, Value,
					case when Variable = 'PRO' then IO
					     when Variable = 'RET' then '4B000Z'
				   	     when Variable = 'WHS' then '42000Z'
						 else '48B00Z'
					end as Defl_Code
    from 	     	work.Shares_AverageAnnualShares
	order by		Naics_4, Naics, IO, Variable, Year;
quit;

/*Pull out the z deflators from the domestic price table*/
Proc Sql;
	Create table  	work.Defl_Z as 
    Select        	IO, Year, Value 
    from 	     	work.IO_Domestic_All 
	where			IO in ("48B00Z", "42000Z", "4B000Z");

	Create table  	work.Shares_Flat_Z as 
    Select          a.Naics_4, a.Naics, a.IO, a.Variable, a.Year, a.Defl_Code, a.Value as Share_Average, b.Value as Defl
    from 	     	work.Shares_Flat2 a 
	inner join 		work.Defl_Z b
    on 				(a.Defl_Code=b.IO) and (a.Year=b.Year)
	order by		a.Naics_4, a.Naics, a.IO, a.Variable, a.Year;
quit;

/*Now merge the non-z shares with the combined import/domestic deflators.*/
Proc sql;
	Create table  	work.Shares_Flat_Pro as 
    Select          a.Naics_4, a.Naics, a.IO, a.Variable, a.Year, a.Defl_Code, a.Value as Share_Average, b.Defl
    from 	     	work.Shares_Flat2 a 
	inner join 		work.IO_Combined_M b
    on 				(a.Naics=b.Naics) and (a.Defl_Code=b.IO) and (a.Year=b.Year)
	order by		a.Naics_4, a.Naics, a.IO, a.Variable, a.Year;
quit;

/*Combine Shares_Flat_Pro and Shares_Flat_Z*/
Proc Sql;
	Create table 	work.MatPrice as
	Select 			Naics_4, Naics, IO, Variable, Year, Share_Average, Defl		from work.Shares_Flat_Z  union all
	Select 			Naics_4, Naics, IO, Variable, Year, Share_Average, Defl		from work.Shares_Flat_Pro 
	order by		Naics_4, Naics, IO, Variable, Year;
quit;

/*	Calculating logarithmic change in deflators and multiply log change by average share */
Proc Sql;
	Create table  	work.LogChg_MatPriceDefl as 
    Select          a.Naics_4, a.Naics, a.IO, a.Year, a.Variable, a.Share_Average, log(a.Defl)-log(b.Defl) as LogChg_Defl
    from 	     	work.MatPrice a
	left join 		work.MatPrice b
    on 				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Variable=b.Variable) and (a.Year-1=b.Year)
	order by		a.Naics_4, a.Naics, a.IO, a.Variable, a.Year;

	Create table  	work.LogShare_MatPriceDefl as 
    Select          a.Naics_4, a.Naics, a.IO, a.Year, a.Variable, a.Share_Average, a.LogChg_Defl, a.Share_Average * b.LogChg_Defl as LogShare_Defl
    from 	     	work.LogChg_MatPriceDefl a
	left join 		work.LogChg_MatPriceDefl b
    on 				(a.Naics=b.Naics) and (a.IO=b.IO) and (a.Variable=b.Variable) and (a.Year=b.Year)
	order by		a.Naics_4, a.Naics, a.IO, a.Variable, a.Year;
quit;

/*	Calculating exponent of sum of weighted product growth rates | Exp (Sum(LogarithmicChange*AverageAnnualShares))*/
Proc Sql;
	Create table  	work.MatPrice3 as 
    Select          a.Naics_4, a.Year, exp(sum(a.LogShare_Defl)) as Value
    from 	     	work.LogShare_MatPriceDefl a
	inner join		work.LogShare_MatPriceDefl b
    on	 			(a.Naics_4=b.Naics_4) and (a.Naics=b.Naics) and (a.IO=b.IO) and (a.Variable=b.Variable) and (a.Year=b.Year)
	Group by		a.Naics_4, a.Year;
quit;

%macro chain2;
Proc sql;
Create table 	work.price_mat as
Select 			a.Naics_4 as NAICS, a.Year,
				case when a.year=1987 then 100
				%do i = 1988 %to &lastyr.;
					when a.Year=&i then
					%do b = &i %to 1988 %by -1;
						_&b..Value*
					%end;
					100
				%end;
				end as Price_Mat
from 			work.MatPrice3 a
				%do c = 1988 %to &lastyr.;
					left join work.MatPrice3 _&c on (a.Naics_4=_&c..Naics_4) and _&c..year=&c
				%end;
order by 		NAICS, Year;
quit;
%mend chain2;
%chain2;

/* Export to IP SAS library */
data IP.price_mat;
	set work.price_mat;
run;

/* Export to Excel for analysis */
proc export data=work.price_mat
			outfile="Q:\MFP\Manufacturing\IP\IP Output\Price_of_Materials.xlsx"
			dbms=xlsx replace;
			sheet="Price_Mat";
run;
