/*Clear the Log*/
dm wpgm 'clear log' wpgm;

/*SAS statements generated by macro execution and resolving macro variables are written to sas log*/
options symbolgen mprint source;

/*Creates libraries for capital, IP, and MFP datasets*/
libname IPIn "Q:\MFP\SAS Libraries\Manufacturing\IP";
libname CapIn "Q:\MFP\SAS Libraries\Manufacturing\Capital\comp";
libname CapIn2 "Q:\MFP\SAS Libraries\Manufacturing\Capital\kstock4d";
libname CapAir "Q:\MFP\SAS Libraries\NAICS 481\MFP";
libname CapRail "Q:\MFP\SAS Libraries\NAICS 482111\MFP";
libname MFPSAS "Q:\MFP\SAS Libraries\Manufacturing\MFP";
/*Creates macro variable for excel output location*/
%let outxlsx=J:\SAS Testing\MFP Re-write\Output Data;

/*Copies entire IP library*/ 
proc copy in=IPin out=work;
run;

/*Copies capital compensation dataset*/
proc copy in=CapIn out=work;
	select CapComp;
run;

/*Copies capital index and DirAggCap*/
proc copy in=CapIn2 out=work;
	select Capital DirAggCap;
run;

/*Copies airline variables to append to final flatfile*/
proc copy in=capair out=work;
	select airline_ips_variables;
run;

/*Copies railroad variables to append to final flatfile*/
proc copy in=caprail out=work;
	select railroad_ips_variable;
run;

/*Transposes IP and Capital datasets from wide format to long format*/
%macro transpose (dataset,dataseriesid,dataseries);
proc transpose data=work.&dataset out=transpose1;
by NAICS;
quit;

data &dataset._t (drop=NAICS _NAME_ COL1);
	set transpose1;
	industry=compress(put(NAICS,10.)," ");
	year=input(compress(_NAME_,,"F"),8.);
	value=COL1;
	dataseriesid=&dataseriesid;
	dataarrayid="00";
	dataseries=&dataseries;
run;
%mend transpose;

%transpose (capcomp,"C02","CapComp");
%transpose (capital,"C01","Capital");
%transpose (diraggcap,"","");
%transpose (diraggip,"",""); 
%transpose (elect,"Y01","Elect"); 
%transpose (electcomp,"Y02","ElectComp"); 
%transpose (energy,"E01","Energy"); 
%transpose (energycomp,"E02","EnergyComp"); 
%transpose (fuels,"F01","Fuels"); 
%transpose (fuelscomp,"F02","FuelsComp"); 
%transpose (intprch,"P01","IntPrch"); 
%transpose (ipcomp,"P02","IPComp"); 
%transpose (kmsdfi,"",""); 
%transpose (matcomp,"R02","MatComp"); 
%transpose (materials,"R01","Materials"); 
%transpose (matsrv,"S01","MatSrv"); 
%transpose (matsrvcomp,"S02","MatSrvComp"); 
%transpose (services,"V01","Services"); 
%transpose (srvcomp,"V02","SrvComp"); 

/*Imports a textfile containing the UpdateID and Lastyr and creates macro variables*/
data _null_;
      length updateid 3 firstyr 4 lastyr 4 baseperiod 3;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input updateid firstyr lastyr baseperiod;
      call symput('updateid', trim(left(put(updateid, 3.))));
      call symput('lastyr', trim(left(put(lastyr, 4.))));
run;

/*Connects to IPS2 database*/
LIBNAME SQL ODBC DSN=IPS2DB schema=sas;

/*Create macro variables for first and last year of data*/
data _null_;
	set sql.update (where=(updateid=&updateid));
	call symput('updatestatusid', updatestatusid);
run;

%let dataset = %sysfunc(ifc(&updatestatusid=Loading,sql.reportbuilder_preliminary,sql.reportbuilder_current));

/*Filters IPS view*/
data work.IPSData;
	set 	&dataset;
	where	dataseriesid in("L01","L20","L02","T01","T30","T05","W01","W20","W00","L00","U10") AND 
			SectorID="31,32,33" AND 
			DigitID="4-Digit" AND 
			ProductivityDB=1 AND                     
			year le &lastyr;
run;

/*Create macro variable for base year*/
data _null_;
	set ipsdata;
	call symput('baseyear', trim(left(put(baseyear, 4.))));
run;

/*Rebase IPS data to 1987*/
%macro rebase(dataout, datain, dataseriesid, base); 
proc sql;
	create table	&dataout as
	select			a.industry, a.year, a.dataseriesid, a.dataseries, a.dataarrayid, a.value/b.value*100 as value
	from			&datain a
	inner join		&datain b
	on				a.industry=b.industry AND a.dataseriesid=b.dataseriesid
	where			a.dataseriesid=&dataseriesid AND b.dataseriesid=&dataseriesid AND b.year=&base;
quit;
%mend rebase;

%rebase(aeh, ipsdata, "L01", 1987);
%rebase(out, ipsdata, "T01", 1987);
%rebase(imprdef, ipsdata, "T05", 1987);

/*Create macro to calculate component weights and productivity*/
%macro wtprody(dataout, datain1, datain2, dataseriesidout, dataseriesidin1, dataseriesidin2, dataseriesout, multiplier);
proc sql;
	create table	&dataout as
	select			a.industry, a.year, &dataseriesidout as dataseriesid, &dataseriesout as dataseries, 
					"00" as dataarrayid, a.value/b.value*&multiplier as value
	from			&datain1 a
	inner join		&datain2 b
	on				a.industry=b.industry AND a.year=b.year
	where			a.dataseriesid = &dataseriesidin1 AND b.dataseriesid = &dataseriesidin2;
quit;
%mend wtprody;

/*Uses wtprody macro to calculate component weights. For easy reference: T30=ValProd, L02=LComp*/
%wtprody(capwt, capcomp_t, ipsdata, "C03", "C02", "T30", "CapWt", 1);
%wtprody(labwt, ipsdata, ipsdata, "L03", "L02", "T30", "LabWt", 1);
%wtprody(ipwt, ipcomp_t, ipsdata, "P03", "P02", "T30", "IPWt", 1);
%wtprody(energywt, energycomp_t, ipsdata, "E03", "E02", "T30", "EnergyWt", 1);
%wtprody(Electwt, electcomp_t, ipsdata, "Y03", "Y02", "T30", "ElectWt", 1);
%wtprody(Fuelswt, fuelscomp_t, ipsdata, "F03", "F02", "T30", "FuelsWt", 1);
%wtprody(Matsrvwt, matsrvcomp_t, ipsdata, "S03", "S02", "T30", "MatSrvWt", 1);
%wtprody(Matwt, matcomp_t, ipsdata, "R03", "R02", "T30", "MatWt", 1);
%wtprody(Srvwt, srvcomp_t, ipsdata, "V03", "V02", "T30", "SrvWt", 1);
%wtprody(energyipwt, energycomp_t, ipcomp_t, "E04", "E02", "P02", "EnergyIPWt", 1);
%wtprody(Electipwt, electcomp_t, ipcomp_t, "Y04", "Y02", "P02", "ElectIPWt", 1);
%wtprody(Fuelsipwt, fuelscomp_t, ipcomp_t, "F04", "F02", "P02", "FuelsIPWt", 1);
%wtprody(Matsrvipwt, matsrvcomp_t, ipcomp_t, "S04", "S02", "P02", "MatSrvIPWt", 1);
%wtprody(Matipwt, matcomp_t, ipcomp_t, "R04", "R02", "P02", "MatIPWt", 1);
%wtprody(Srvipwt, srvcomp_t, ipcomp_t, "V04", "V02", "P02", "SrvIPWt", 1);

/*Multiplies average annual weights and logarithmic change*/
%macro avgwtln (dataout, datain1, datain2);
proc sql;
	create table	&dataout as
	select			a.industry, a.year, ((a.value+b.value)/2)*(log(d.value)-log(c.value)) as value
	from			&datain1 a
	left join		&datain1 b
	on				a.industry=b.industry AND (a.year-1=b.year)
	left join		&datain2 c
	on				a.industry=c.industry AND (a.year-1=c.year)
	left join		&datain2 d
	on				a.industry=d.industry AND (a.year=d.year);
quit;
%mend avgwtln;

%avgwtln (ipavgwtln, ipwt, intprch_t);
%avgwtln (capavgwtln, capwt, capital_t);
%avgwtln (labavgwtln, labwt, aeh);

/*Calculates exponent of sum of weighted growth rates*/
proc sql;
	create table	expsum as
	select			a.industry, a.year, exp(a.value+b.value+c.value) as value
	from			ipavgwtln a
	inner join		capavgwtln b
	on				a.industry=b.industry AND a.year=b.year
	inner join		labavgwtln c
	on				a.industry=c.industry AND a.year=c.year;
quit;

/*Calculates CombInput (M01) via chain linking*/
%macro chain(dataout, datain, dataseriesid, dataseries);
data &dataout (drop=oldvalue);
  set &datain (rename=(value=oldvalue));
  by industry;
  if first.industry then value=100;
  else value=value*oldvalue ;
  retain value;
  dataseriesid=&dataseriesid;
  dataseries=&dataseries;
  dataarrayid="00";
run;
%mend chain;

%chain(combinput, expsum, "M01", "CombInput");

/*Calculates component deflators*/
%macro def(dataout, dataseriesidout, dataseriesout, datain1, datain2, dataseriesidin1, dataseriesidin2);
proc sql;
	create table	&dataout as
	select			a.industry, a.year, &dataseriesidout as dataseriesid, &dataseriesout as dataseries, 
					((a.value/b.value)/(c.value/d.value))*100 as value
	from			&datain1 a
	inner join		&datain1 b
	on				a.industry=b.industry AND b.year=&baseyear
	inner join		&datain2 c
	on				a.industry=c.industry AND a.year=c.year
	inner join		&datain2 d
	on				a.industry=d.industry AND d.year=&baseyear
	where			a.dataseriesid=&dataseriesidin1 AND b.dataseriesid=&dataseriesidin1 AND 
					c.dataseriesid=&dataseriesidin2 AND d.dataseriesid=&dataseriesidin2;
quit;
%mend def;

%def (capdef, "C05", "CapDef", capcomp_t, capital_t, "C02", "C01");
%def (electdef, "Y05", "ElectDef", electcomp_t, elect_t, "Y02", "Y01");
%def (energydef, "E05", "EnergyDef", energycomp_t, energy_t, "E02", "E01");
%def (fuelsdef, "F05", "FuelsDef", fuelscomp_t, fuels_t, "F02", "F01");
%def (ipdef, "P05", "IPDef", ipcomp_t, intprch_t, "P02", "P01");
%def (labdef, "L05", "LabDef", ipsdata, aeh, "L02", "L01");
%def (matdef, "R05", "MatDef", matcomp_t, materials_t, "R02", "R01");
%def (matsrvdef, "S05", "MatSrvDef", matsrvcomp_t, matsrv_t, "S02", "S01");
%def (srvdef, "V05", "SrvDef", srvcomp_t, services_t, "V02", "V01");
%def (totdef, "M05", "TotDef", ipsdata, combinput, "T30", "M01"); 

/*Use wtprody macro to calculate component productivity*/
%wtprody(capprdy, out, capital_t, "C00", "T01", "C01", "CapPrdy", 100);
%wtprody(electprdy, out, elect_t, "Y00", "T01", "Y01", "ElectPrdy", 100);
%wtprody(energyprdy, out, energy_t, "E00", "T01", "E01", "EnergyPrdy", 100);
%wtprody(fuelsprdy, out, fuels_t, "F00", "T01", "F01", "FuelsPrdy", 100);
%wtprody(ipprdy, out, intprch_t, "P00", "T01", "P01", "IPPrdy", 100);
%wtprody(matprdy, out, materials_t, "R00", "T01", "R01", "MatPrdy", 100);
%wtprody(matsrvprdy, out, matsrv_t, "S00", "T01", "S01", "MatSrvPrdy", 100);
%wtprody(mfprdy, out, combinput, "M00", "T01", "M01", "MFPrdy", 100);
%wtprody(srvprdy, out, services_t, "V00", "T01", "V01", "SrvPrdy", 100);

/*Uses wtprody macro to calculate CapLabRt, IPLabRt, CapTQEffect, CapLabRtDA, IPTQEffect, and IPLabRtDA*/
%wtprody(caplabrt, capital_t, aeh, "C06", "C01", "L01", "CapLabRt", 100);
%wtprody(iplabrt, intprch_t, aeh, "P06", "P01", "L01", "IPLabRt", 100);
%wtprody(CapTQEffect, capital_t, diraggcap_t, "", "C01", "", "CapTQEffect", 100);
%wtprody(CapLabRtDA, diraggcap_t, aeh, "", "", "L01", "CapLabRtDA", 100);
%wtprody(IPTQEffect, intprch_t, diraggip_t, "", "P01", "", "IPTQEffect", 100);
%wtprody(IPLabRtDA, diraggip_t, aeh, "", "", "L01", "IPLabRtDA", 100);


/*Create macro to calculate CapUC and IPUC*/
%macro uc(dataout, dataseriesidout, dataseriesout, datain1, datain2, 
			dataseriesidin1, dataseriesidin2);
proc sql;
	create table	&dataout as
	select			a.industry, a.year, &dataseriesidout as dataseriesid, &dataseriesout as dataseries, 
					(((a.value/b.value)*100)/c.value)*100 as value, "00" as dataarrayid
	from			&datain1 a
	inner join		&datain1 b
	on				a.industry=b.industry
	inner join		&datain2 c
	on				a.industry=c.industry AND a.year=c.year
	where			a.dataseriesid=&dataseriesidin1 AND b.dataseriesid=&dataseriesidin1 AND 
					c.dataseriesid=&dataseriesidin2 AND b.year=1987;
quit;
%mend uc;

%uc(capuc, "C10", "CapUC", capcomp_t, out, "C02", "T01");
%uc(ipuc, "P10", "IPUC", ipcomp_t, out, "P02", "T01");

/*Create macro to calculate CapLabCntr and IPLabCntr*/
/*For capital, expcaplabcntr=exp{AvgCapWt*(LnDiffCap-LnDiffAEH)}*/
/*For ip, expiplabcntr=exp{AvgIPWt*(LnDiffIntPrch-LnDiffAEH)}*/
%macro explabcntr (dataout, datain1, datain2, datain3);
proc sql;
	create table	&dataout as
	select			a.industry, a.year, 
					exp(((a.value+b.value)/2)*((log(d.value)-log(c.value))-(log(f.value)-log(e.value)))) as value
	from			&datain1 a
	left join		&datain1 b
	on				a.industry=b.industry AND (a.year-1=b.year)
	left join		&datain2 c
	on				a.industry=c.industry AND (a.year-1=c.year)
	left join		&datain2 d
	on				a.industry=d.industry AND a.year=d.year
	left join		&datain3 e
	on				a.industry=e.industry AND (a.year-1=e.year)
	left join		&datain3 f
	on				a.industry=f.industry AND a.year=f.year;
quit;
%mend explabcntr;

%explabcntr (expcaplabctr, capwt, capital_t, aeh);
%explabcntr (expiplabctr, ipwt, intprch_t, aeh);

%chain(caplabcntr, expcaplabctr, "C07", "CapLabCntr");
%chain(iplabcntr, expiplabctr, "P07", "IPLabCntr");

/*rebase to current IPS base year*/
%rebase(aeh_final, aeh, "L01", &baseyear);
%rebase(capital_final, capital_t, "C01", &baseyear);
%rebase(caplabcntr_final, caplabcntr, "C07", &baseyear);
%rebase(caplabrt_final, caplabrt, "C06", &baseyear);
%rebase(capprdy_final, capprdy, "C00", &baseyear);
%rebase(capuc_final, capuc, "C10", &baseyear);
%rebase(combinput_final, combinput, "M01", &baseyear);
%rebase(elect_final, elect_t, "Y01", &baseyear);
%rebase(electprdy_final, electprdy, "Y00", &baseyear);
%rebase(energy_final, energy_t, "E01", &baseyear);
%rebase(energyprdy_final, energyprdy, "E00", &baseyear);
%rebase(fuels_final, fuels_t, "F01", &baseyear);
%rebase(fuelsprdy_final, fuelsprdy, "F00", &baseyear);
%rebase(imprdef_final, imprdef, "T05", &baseyear);
%rebase(intprch_final, intprch_t, "P01", &baseyear);
%rebase(iplabcntr_final, iplabcntr, "P07", &baseyear);
%rebase(iplabrt_final, iplabrt, "P06", &baseyear);
%rebase(ipprdy_final, ipprdy, "P00", &baseyear);
%rebase(ipuc_final, ipuc, "P10", &baseyear);
%rebase(materials_final, materials_t, "R01", &baseyear);
%rebase(matprdy_final, matprdy, "R00", &baseyear);
%rebase(matsrv_final, matsrv_t, "S01", &baseyear);
%rebase(matsrvprdy_final, matsrvprdy, "S00", &baseyear);
%rebase(mfprdy_final, mfprdy, "M00", &baseyear);
%rebase(out_final, out, "T01", &baseyear);
%rebase(services_final, services_t, "V01", &baseyear);
%rebase(srvprdy_final, srvprdy, "V00", &baseyear);
%rebase(CapTQEffect_final, CapTQEffect, "", &baseyear);
%rebase(caplabrtda_final, caplabrtda, "", &baseyear);
%rebase(iptqeffect_final, iptqeffect, "", &baseyear);
%rebase(iplabrtda_final, iplabrtda, "", &baseyear);

/*Calculates TotComp*/
proc sql;
	create table	TotComp as
	select			a.industry, a.year, "M02" as dataseriesid, "TotComp" as dataseries, 
					(a.value+b.value+c.value) as value, "00" as dataarrayid
	from			ipsdata a
	inner join		capcomp_t b
	on				a.industry=b.industry AND a.year=b.year
	inner join		ipcomp_t c
	on				a.industry=c.industry AND a.year=c.year
	where			a.dataseriesid="L02";
quit;

/*Calculates LCompIdx*/
proc sql;
	create table	lcompidx as
	select			a.industry, a.year, "U11" as dataseriesid, "LCompIdx" as dataseries, "00" as dataarrayid,
					(a.value/b.value)*100 as value
	from			ipsdata a
	inner join		ipsdata b
	on				a.industry=b.industry
	where			a.dataseriesid="L02" AND b.dataseriesid="L02" AND b.year=&baseyear;
quit;

/*Contains instances where ValProd does not equal TotComp.  If data_integrity contains zero observations, then 
ValProd equals TotComp for all industry/year combinations*/
proc sql;
	create table	data_integrity as
	select			a.industry, a.year, a.value as totcomp, b.value as valprod, a.value-b.value as difference
	from			totcomp a
	inner join		ipsdata b
	on				a.industry=b.industry AND a.year=b.year
	where			b.dataseriesid="T30" AND calculated difference > .000001;
quit;

/*Combine published variables into one flatfile*/
data published_variables (keep=industry year value dataseriesid dataseries dataarrayid);
set	aeh_final capital_final	caplabcntr_final caplabrt_final	capprdy_final capuc_final combinput_final elect_final
	electprdy_final	energy_final energyprdy_final fuels_final fuelsprdy_final imprdef_final	intprch_final
	iplabcntr_final	iplabrt_final ipprdy_final ipuc_final materials_final matprdy_final	matsrv_final
	matsrvprdy_final mfprdy_final out_final services_final srvprdy_final capcomp_t capdef capwt	electcomp_t
	electdef electipwt electwt energycomp_t energydef energyipwt energywt fuelscomp_t fuelsdef fuelsipwt
	fuelswt ipcomp_t ipdef ipwt labdef labwt ipsdata (where=(dataseriesid="L02")) matcomp_t matdef	matipwt
	matsrvcomp_t matsrvdef matsrvipwt matsrvwt matwt srvcomp_t srvdef srvipwt srvwt totdef 
	ipsdata (where=(dataseriesid="T30")) totcomp ipsdata (where=(dataseriesid="L20")) lcompidx 
	ipsdata (where=(dataseriesid="W01")) ipsdata (where=(dataseriesid="W20")) ipsdata (where=(dataseriesid="W00"))
	ipsdata (where=(dataseriesid="L00")) ipsdata (where=(dataseriesid="U10"));
run;

/*Combine unpublished variables into one flatfile*/
data unpublished_variables (keep=industry year value dataseriesid dataseries dataarrayid);
set	captqeffect_final caplabrtda_final iptqeffect_final iplabrtda_final;
run;

/*Create industryid to industry concordance*/
data industryidconcordance;
	set ipsdata (where=(dataseriesid="T01" AND year=1987));
	keep industryid industry;
run;

/*Create yearid to year concordance*/
data yearidconcordance;
	set ipsdata (where=(dataseriesid="T01" AND industry="3111"));
	keep year yearid;
run;

/*Merge industryid and yearid with published_variables data set*/
proc sql;
	create table	publishedMFPflatfile as
	select			a.industry as IndustryCodeID, a.year, a.value, a.dataseriesid, a.dataseries as DataseriesCodeID, 
					a.dataarrayid, b.industryid, c.yearid
	from			published_variables a
	inner join		industryidconcordance b
	on				a.industry=b.industry
	inner join		yearidconcordance c
	on				a.year=c.year
	order by		a.dataseries, a.industry, a.year;
quit;

/**/
data airline_ips_variables (drop=x);
	set airline_ips_variables (rename=(industrycodeid=x));
	industrycodeid=compress(put(x,10.)," ");
run;

data railroad_ips_variable (drop=x);
	set railroad_ips_variable (rename=(industrycodeid=x));
	industrycodeid=compress(put(x,10.)," ");
run;

/*Stack airline and railroad MFP datasets onto manufacturing MFP dataset*/
data mfpsas.publishedMFPflatfile;
	set publishedMFPflatfile airline_ips_variables railroad_ips_variable;
run;

/*Merge industryid and yearid with unpublished_variables data set*/
proc sql;
	create table	mfpsas.unpublishedMFPflatfile as
	select			a.industry as IndustryCodeID, a.year, a.value, a.dataseriesid, a.dataseries as DataseriesCodeID, 
					a.dataarrayid, b.industryid, c.yearid
	from			unpublished_variables a
	inner join		industryidconcordance b
	on				a.industry=b.industry
	inner join		yearidconcordance c
	on				a.year=c.year
	order by		a.dataseries, a.industry, a.year;
quit;

data mfpsas.publishedmfpflatfile;
set mfpsas.publishedmfpflatfile;
Value_Round=round(value,0.001);
if DataSeriesCodeID="CapWt" and value_round=0.000 then Value=0.001;
drop value_round;
run;

data mfpsas.unpublishedMFPflatfile;
set mfpsas.unpublishedMFPflatfile;
Value_Round=round(value,0.001);
if DataSeriesCodeID="CapWt" and value_round=0.000 then Value=0.001;
drop value_round;
run;

/*Output flatfile in excel*/
proc export data=mfpsas.publishedMFPflatfile
			outfile="&outxlsx.\mfp&lastyr.PublishedMFPflatfile"
			dbms=xlsx
			replace;
run;

/*Output flatfile in excel*/
proc export data=mfpsas.unpublishedMFPflatfile
			outfile="&outxlsx.\mfp&lastyr.UnpublishedMFPflatfile"
			dbms=xlsx
			replace;
run;
