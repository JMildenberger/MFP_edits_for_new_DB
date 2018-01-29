/* Program: MFP IP Macros
   Last updated: May 19, 2017 */

libname IP "Q:\MFP\SAS Libraries\Manufacturing\IP";

/*Creates a macro variables from textfile*/
data _null_;
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('first', trim(left(put(firstyr, 4.))));
      call symput('last', trim(left(put(lastyr, 4.))));
run;

/*Macro variables for second and second-to-last years*/
%let second = &first + 1;
%let secondtolast = &last - 1;

/* Import MFP Price Files from Excel */
libname MFP XLSX 'R:\MFP DataSets\Manufacturing\IP\SAS Inputs\MFP IP Price Files.xlsx';

data work.Price_Fuels; /* To be read-in from SAS library in the future */
	set MFP.Price_Fuels;
run;

data work.Price_Mat;  /* Read-in from SAS library */
	set IP.Price_Mat;
run;

data work.Price_Srv; /* Read-in from SAS library */
	set IP.Price_Srv;
run;


/* Transpose Datasets for IP Macro Calculations */

/*Cost of Electricity*/
proc sort data=IP.CostofElectricity;
by naics;
run;

proc transpose data=IP.CostofElectricity out=work.CostofElectricity prefix=CostOfElectricity;
by naics;
id year;
run;

/*Quantity of Electricity*/
proc sort data=IP.Quanofelectricity;
by naics;
run;

proc transpose data=IP.Quanofelectricity out=work.Quanofelectricity prefix=QuanOfElectricity;
by naics;
id year;
run;

/*Cost of Fuels*/
proc sort data=IP.CostofFuels;
by naics;
run;

proc transpose data=IP.CostofFuels out=work.CostofFuels prefix=CostOfFuels;
by naics;
id year;
run;

/*Cost of Supplies*/
proc sort data=IP.CostofSupplies;
by naics;
run;

proc transpose data=IP.CostofSupplies out=work.CostofSupplies prefix=CostOfSupplies;
by naics;
id year;
run;

/*Cost of Services*/
proc sort data=IP.Cost_Srv;
by naics;
run;

proc transpose data=IP.Cost_Srv out=work.CostofServices prefix=CostOfServices;
by naics;
id year;
run;

/*Price of Fuels*/
proc sort data=work.Price_Fuels;
by naics;
run;

proc transpose data=work.Price_Fuels out=work.PriceofFuels prefix=PriceOfFuels;
by naics;
id year;
run;

/*Price of Materials*/
proc sort data=work.Price_Mat;
by naics;
run;

proc transpose data=work.Price_Mat out=work.PriceofSupplies prefix=PriceOfSupplies;
by naics;
id year;
run;

/*Price of Services*/
proc sort data=work.Price_Srv;
by naics;
run;

proc transpose data=work.Price_Srv out=work.PriceofServices prefix=PriceOfServices;
by naics;
id year;
run;

/*Price of Electricity (Index): Divide Cost of Electrity by Quantity of Electricity*/
%MACRO PRICEOFELECTRICTY(first, last);
	data work.priceofelectricity (keep = NAICS PriceOfElectricity:);
		merge work.costofelectricity work.quanofelectricity;
				FirstPriceOfElectricity&first = (CostOfElectricity&first / QuanOfElectricity&first);
		%do i = &first %to &last;
				PriceOfElectricity&i = ((CostOfElectricity&i / QuanOfElectricity&i) / FirstPriceOfElectricity&first) * 100;
		%end;
	run;
%MEND PRICEOFELECTRICTY;
%PRICEOFELECTRICTY(first=&first, last=&last);

/*Merge of CostFiles*/
data work.costmerge (Drop=_Name_);
	merge work.costoffuels work.costofsupplies work.costofelectricity work.costofservices;
run;

/*Cost of Fuels Value Shares*/
%MACRO CFSHARES;
data work.cfshares(Keep=NAICS y:);
	set work.costmerge;
	%do i = &first %to &last;
	y&i=costoffuels&i/(costoffuels&i+costofsupplies&i+costofelectricity&i+costofservices&i);
	%end;
run;
%MEND CFSHARES;
%CFSHARES;

/*Cost of Supplies Value Shares*/
%MACRO CSUPPSHARES;
data work.csuppshares(Keep=NAICS y:);
	set work.costmerge;
	%do i = &first %to &last;
	y&i=costofsupplies&i/(costoffuels&i+costofsupplies&i+costofelectricity&i+costofservices&i);
	%end;
run;
%MEND CSUPPSHARES;
%CSUPPSHARES;

/*Cost of Electricity Value Shares*/
%MACRO CESHARES;
data work.ceshares(Keep=NAICS y:);
	set work.costmerge;
	%do i = &first %to &last;
	y&i=costofelectricity&i/(costoffuels&i+costofsupplies&i+costofelectricity&i+costofservices&i);
	%end;
run;
%MEND CESHARES;
%CESHARES;

/*Cost of Services Value Shares*/
%MACRO CSERVSHARES;
data work.cservshares(Keep=NAICS y:);
	set work.costmerge;
	%do i = &first %to &last;
	y&i=costofservices&i/(costoffuels&i+costofsupplies&i+costofelectricity&i+costofservices&i);
	%end;
run;
%MEND CSERVSHARES;
%CSERVSHARES;

/*CostOfFuels Index*/
%MACRO COSTOFFUELSINDEX (first, last);
data work.costoffuelsindex (keep=NAICS costoffuelsi:);
	set work.costoffuels;
	%do i = &first %to &last;
    costoffuelsi&i= (costoffuels&i / costoffuels&first) * 100;
	%end;
run;
%MEND COSTOFFUELSINDEX;
%COSTOFFUELSINDEX(first=&first, last=&last);

/*CostOfSupplies Index*/
%MACRO COSTOFSUPPLIESINDEX (first, last);
data work.costofsuppliesindex (keep=NAICS costofsuppliesi:);
	set work.costofsupplies;
	%do i = &first %to &last;
    costofsuppliesi&i= (costofsupplies&i / costofsupplies&first) * 100;
	%end;
run;
%MEND COSTOFSUPPLIESINDEX;
%COSTOFSUPPLIESINDEX(first=&first, last=&last);

/*CostOfElectricity Index*/
%MACRO COSTOFELECTRICITYINDEX (first, last);
data work.costofelectricityindex (keep=NAICS costofelectricityi:);
	set work.costofelectricity;
	%do i = &first %to &last;
    costofelectricityi&i= (costofelectricity&i / costofelectricity&first) * 100;
	%end;
run;
%MEND COSTOFELECTRICITYINDEX;
%COSTOFELECTRICITYINDEX(first=&first, last=&last);

/*CostOfServices Index*/
%MACRO COSTOFSERVICESINDEX (first, last);
data work.costofservicesindex (keep=NAICS costofservicesi:);
	set work.costofservices;
	%do i = &first %to &last;
    costofservicesi&i= (costofservices&i / costofservices&first) * 100;
	%end;
run;
%MEND COSTOFSERVICESINDEX;
%COSTOFSERVICESINDEX(first=&first, last=&last);

/*CostOfFuelsquan*/
%MACRO cfquan;
data work.costoffuelsquan(Keep=NAICS y:);
	merge work.costoffuelsindex work.priceoffuels;
	%do i = &first %to &last;
	y&i=(costoffuelsi&i/priceoffuels&i)*100;
	%end;
run; 
%MEND cfquan;
%cfquan;

/*CostOfSuppliesquan*/
%MACRO csquan;
data work.costofsuppliesquan(Keep=NAICS y:);
	merge work.costofsuppliesindex work.priceofsupplies;
	%do i = &first %to &last;
	y&i=(costofsuppliesi&i/priceofsupplies&i)*100;
	%end;
run; 
%MEND csquan;
%csquan;

/*CostOfElectricityquan*/
%MACRO cequan;
data work.costofelectricityquan(Keep=NAICS y:);
	merge work.costofelectricityindex work.priceofelectricity;
	%do i = &first %to &last;
	y&i=(costofelectricityi&i/priceofelectricity&i)*100;
	%end;
run; 
%MEND cequan;
%cequan;

/*CostOfServicesquan*/
%MACRO cservquan;
data work.costofservicesquan(Keep=NAICS y:);
	merge work.costofservicesindex work.priceofservices;
	%do i = &first %to &last;
	y&i=(costofservicesi&i/priceofservices&i)*100;
	%end;
run; 
%MEND cservquan;
%cservquan;

/*FuelsLnDiff*/
%MACRO fuelslndiff (first, second, secondtolast, last);
data work.fuelslndiff;
	set work.costoffuelsquan;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		fuelslndiff&year2 = log(y&year2) - log(y&year);
		keep NAICS fuelslndiff&year2;
		%end;
	%end;
run;
%MEND fuelslndiff;
%fuelslndiff(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*SuppliesLnDiff*/
%MACRO supplieslndiff (first, second, secondtolast, last);
data work.supplieslndiff;
	set work.costofsuppliesquan;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		supplndiff&year2 = log(y&year2) -  log(y&year);
		keep NAICS supplndiff&year2;
		%end;
	%end;
run;
%MEND supplieslndiff;
%supplieslndiff(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*ElectricityLnDiff*/
%MACRO electricitylndiff (first, second, secondtolast, last);
data work.electricitylndiff;
	set work.costofelectricityquan;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		eleclndiff&year2 = log(y&year2) - log(y&year);
		keep NAICS eleclndiff&year2;
		%end;
	%end;
run;
%MEND electricitylndiff;
%electricitylndiff(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*ServicesLnDiff*/
%MACRO serviceslndiff (first, second, secondtolast, last);
data work.serviceslndiff;
	set work.costofservicesquan;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		servlndiff&year2 = log(y&year2) - log(y&year);
		keep NAICS servlndiff&year2;
		%end;
	%end;
run;
%MEND serviceslndiff;
%serviceslndiff(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*FuelsAvgValShares*/
%MACRO fuelsavgvalshares (first, second, secondtolast, last);
data work.fuelsavgvalshares;
	set work.cfshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		fuelsavgvalshare&year2 = (y&year + y&year2)/ 2;
		keep NAICS fuelsavgvalshare&year2;
		%end;
	%end;
run;
%MEND fuelsavgvalshares;
%fuelsavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*SuppliesAvgValShares*/
%MACRO suppliesavgvalshares (first, second, secondtolast, last);
data work.suppliesavgvalshares;
	set work.csuppshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		suppavgvalshare&year2 = (y&year + y&year2)/ 2;
		keep NAICS suppavgvalshare&year2;
		%end;
	%end;
run;
%MEND suppliesavgvalshares;
%suppliesavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*ElectricityAvgValShares*/
%MACRO electricityavgvalshares (first, second, secondtolast, last);
data work.electricityavgvalshares;
	set work.ceshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		elecavgvalshare&year2 = (y&year + y&year2)/ 2;
		keep NAICS elecavgvalshare&year2;
		%end;
	%end;
run;
%MEND electricityavgvalshares;
%electricityavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*ServicesAvgValShares*/
%MACRO servicesavgvalshares (first, second, secondtolast, last);
data work.servicesavgvalshares;
	set work.cservshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		servavgvalshare&year2 = (y&year + y&year2)/ 2;
		keep NAICS servavgvalshare&year2;
		%end;
	%end;
run;
%MEND servicesavgvalshares;
%servicesavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

/*WeightedIP (LnDiff are multiplied by share weights and then EXP is taken)*/
%MACRO weightedIP (first, last);
data work.weightedIP (keep=NAICS y:);
	merge work.fuelslndiff work.supplieslndiff work.electricitylndiff work.serviceslndiff
		  work.fuelsavgvalshares work.suppliesavgvalshares work.electricityavgvalshares work.servicesavgvalshares;
	by NAICS;
	%do i = &first %to &last;
    y&i= exp( (fuelslndiff&i * fuelsavgvalshare&i) + (supplndiff&i * suppavgvalshare&i) + 
			(eleclndiff&i * elecavgvalshare&i) +(servlndiff&i * servavgvalshare&i) );
	%end;
	y&first=100;
run;
%MEND weightedIP;
%weightedIP(first=&first, last=&last);

/*IPIND*/
%MACRO INTPRCH (first, second, secondtolast, last);
data IP.INTPRCH (keep= NAICS y:);
	set work.weightedIP;
	%do year2 = &second %to &last;
			%do year = &first %to &secondtolast;
				if &year2 = &year + 1 then
				y&year2 = y&year2 * y&year;
			%end;
	%end;
run;
%MEND INTPRCH;
%INTPRCH(first=&first, second=&second, secondtolast=&secondtolast,last=&last);


/*IP COMP*********************************************************************************/ 
/*All Comp files are assuming numbers from Census in thousands - convert them to millions*/
%MACRO IPComp (first, last);
data IP.IPComp (keep=NAICS y:);
	merge work.costoffuels work.costofsupplies work.costofelectricity work.costofservices;
	%do i = &first %to &last;
    y&i= (CostOfFuels&i + CostOfSupplies&i + CostOfElectricity&i + CostOfServices&i) / 1000;
	%end;
run;
%MEND IPComp;
%IPComp(first=&first, last=&last);
 
/*Fuels Comp*/
%MACRO FUELSComp (first, last);
data IP.FUELSComp (keep=NAICS y:);
	set work.costoffuels;
	%do i = &first %to &last;
    y&i= CostOfFuels&i / 1000;
	%end;
run;
%MEND FUELSComp;
%FUELSComp(first=&first, last=&last);

/*Supplies Comp*/
%MACRO SUPPLIESComp (first, last);
data IP.MatComp (keep=NAICS y:);
	set work.costofsupplies;
	%do i = &first %to &last;
    y&i= CostOfSupplies&i / 1000;
	%end;
run;
%MEND SUPPLIESComp;
%SUPPLIESComp(first=&first, last=&last);

/*Electricity Comp*/
%MACRO ELECTRICITYComp (first, last);
data IP.ElectComp (keep=NAICS y:);
	set work.costofelectricity;
	%do i = &first %to &last;
    y&i= CostOfElectricity&i / 1000;
	%end;
run;
%MEND ELECTRICITYComp;
%ELECTRICITYComp(first=&first, last=&last);

/*Services Comp*/
%MACRO SERVICESComp (first, last);
data IP.SrvComp (keep=NAICS y:);
	set work.costofservices;
	%do i = &first %to &last;
    y&i= CostOfServices&i / 1000;
	%end;
run;
%MEND SERVICESComp;
%SERVICESComp(first=&first, last=&last);

/*Fuels and Electricity Comp*/
%MACRO ENERGYComp (first, last);
data IP.energycomp (keep=NAICS y:);
	merge work.costoffuels work.costofelectricity;
	%do i = &first %to &last;
    y&i= (CostOfFuels&i + CostOfElectricity&i ) / 1000;
	%end;
run;
%MEND ENERGYComp;
%ENERGYComp(first=&first, last=&last);

/*Materials and Services Comp*/
%MACRO MATSRVComp (first, last);
data IP.matsrvcomp (keep=NAICS y:);
	merge work.costofsupplies work.costofservices;
	%do i = &first %to &last;
    y&i= (CostOfSupplies&i + CostOfServices&i ) / 1000;
	%end;
run;
%MEND MATSRVComp;
%MATSRVComp(first=&first, last=&last);

/*Materials and Fuels Deflator*/
%MACRO FUELSSUPPcosts (first, last);
data work.fuelssuppcosts (keep=NAICS costs:);
	merge work.costoffuels work.costofsupplies;
	%do i = &first %to &last;
    costs&i= CostOfFuels&i + CostOfSupplies&i;
	%end;
run;
%MEND FUELSSUPPcosts;
%FUELSSUPPcosts(first=&first, last=&last);

%MACRO FUELSquan (first, last);
data work.fuelsquan (keep=NAICS fuelsquan:);
	merge work.costoffuels work.priceoffuels;
	%do i = &first %to &last;
    fuelsquan&i= (CostOfFuels&i / PriceOfFuels&i) * 100;
	%end;
run;
%MEND FUELSquan;
%FUELSquan(first=&first, last=&last);

%MACRO SUPPLIESquan (first, last);
data work.suppliesquan (keep=NAICS suppliesquan:);
	merge work.costofsupplies work.priceofsupplies;
	%do i = &first %to &last;
    suppliesquan&i= (CostOfSupplies&i / PriceOfSupplies&i) * 100;
	%end;
run;
%MEND SUPPLIESquan;
%SUPPLIESquan(first=&first, last=&last);

%MACRO FUELSSUPPquans (first, last);
data work.fuelssuppquans (keep=NAICS quans:);
	merge work.fuelsquan work.suppliesquan;
	%do i = &first %to &last;
    quans&i= fuelsquan&i + suppliesquan&i;
	%end;
run;
%MEND FUELSSUPPquans;
%FUELSSUPPquans(first=&first, last=&last);

%MACRO KMSDFI (first, last);
data IP.kmsdfi (keep=NAICS y:);
	merge work.fuelssuppcosts work.fuelssuppquans;
	%do i = &first %to &last;
    y&i= (costs&i / quans&i ) * 100;
	%end;
run;
%MEND KMSDFI;
%KMSDFI(first=&first, last=&last);
/*End of Materials and Fuels Deflator*/


/*INDEXING**********************************************************************************/

/*Index of Fuels*/
data IP.fuels;
	set work.costoffuelsquan;
run;

/*Index of Supplies*/
data IP.materials;
	set work.costofsuppliesquan;
run;

/*Index of Electricity*/
data IP.elect;
	set work.costofelectricityquan;
run;

/*Index of Services*/
data IP.services;
	set work.costofservicesquan;
run;

/*Index of Energy*/
%MACRO FENERGYSHARES;
data work.fenergyshares(Keep=NAICS fenergy:);
	set work.costmerge;
	%do i = &first %to &last;
	fenergy&i=costoffuels&i/(costoffuels&i+costofelectricity&i);
	%end;
run;
%MEND FENERGYSHARES;
%FENERGYSHARES;

%MACRO EENERGYSHARES;
data work.eenergyshares(Keep=NAICS eenergy:);
	set work.costmerge;
	%do i = &first %to &last;
	eenergy&i=costofelectricity&i/(costoffuels&i+costofelectricity&i);
	%end;
run;
%MEND EENERGYSHARES;
%EENERGYSHARES;

%MACRO fenergyavgvalshares (first, second, secondtolast, last);
data work.fenergyavgvalshares;
	set work.fenergyshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		fenergyavgvalshare&year2 = (fenergy&year + fenergy&year2)/ 2;
		keep NAICS fenergyavgvalshare&year2;
		%end;
	%end;
run;
%MEND fenergyavgvalshares;
%fenergyavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

%MACRO eenergyavgvalshares (first, second, secondtolast, last);
data work.eenergyavgvalshares;
	set work.eenergyshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		eenergyavgvalshare&year2 = (eenergy&year + eenergy&year2)/ 2;
		keep NAICS eenergyavgvalshare&year2;
		%end;
	%end;
run;
%MEND eenergyavgvalshares;
%eenergyavgvalshares(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

%MACRO weightedenergy (first, last);
data work.weightedenergy (keep=NAICS y:);
	merge work.fuelslndiff work.electricitylndiff
		  work.fenergyavgvalshares work.eenergyavgvalshares;
	by NAICS;
	%do i = &first %to &last;
    y&i= exp( (fuelslndiff&i * fenergyavgvalshare&i)+ (eleclndiff&i * eenergyavgvalshare&i) );
	%end;
	y&first=100;
run;
%MEND weightedenergy;
%weightedenergy(first=&first, last=&last);

%MACRO ENERGY (first, second, secondtolast, last);
data IP.ENERGY (keep= NAICS y:);
	set work.weightedenergy;
	%do year2 = &second %to &last;
			%do year = &first %to &secondtolast;
				if &year2 = &year + 1 then
				y&year2 = y&year2 * y&year;
			%end;
	%end;
run;
%MEND ENERGY;
%ENERGY(first=&first, second=&second, secondtolast=&secondtolast,last=&last);
/*End Index of Energy*/

/*Index of Materials and Services*/
%MACRO MMatSrvSHARES;
data work.mmatsrvshares(Keep=NAICS mmatsrv:);
	set work.costmerge;
	%do i = &first %to &last;
	mmatsrv&i=costofsupplies&i/(costofsupplies&i+costofservices&i);
	%end;
run;
%MEND MMatSrvSHARES;
%MMatSrvSHARES;

%MACRO SMatSrvSHARES;
data work.smatsrvshares(Keep=NAICS smatsrv:);
	set work.costmerge;
	%do i = &first %to &last;
	smatsrv&i=costofservices&i/(costofsupplies&i+costofservices&i);
	%end;
run;
%MEND SMatSrvSHARES;
%SMatSrvSHARES;

%MACRO MMatSrvAVGVALSHARES (first, second, secondtolast, last);
data work.mmatsrvavgvalshares;
	set work.mmatsrvshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		mmatsrvavgvalshare&year2 = (mmatsrv&year + mmatsrv&year2)/ 2;
		keep NAICS mmatsrvavgvalshare&year2;
		%end;
	%end;
run;
%MEND MMatSrvAVGVALSHARES;
%MMatSrvAVGVALSHARES(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

%MACRO SMatSrvAVGVALSHARES (first, second, secondtolast, last);
data work.smatsrvavgvalshares;
	set work.smatsrvshares;	
	%do year2 = &second %to &last;
		%do year = &first %to &secondtolast;
		if &year2 = &year + 1 then
		smatsrvavgvalshare&year2 = (smatsrv&year + smatsrv&year2)/ 2;
		keep NAICS smatsrvavgvalshare&year2;
		%end;
	%end;
run;
%MEND SMatSrvAVGVALSHARES;
%SMatSrvAVGVALSHARES(first=&first, second=&second, secondtolast=&secondtolast, last=&last);

%MACRO weightedmatsrv(first, last);
data work.weightedmatsrv(keep=NAICS y:);
	merge work.supplieslndiff work.serviceslndiff
		  work.mmatsrvavgvalshares work.smatsrvavgvalshares;
	by NAICS;
	%do i = &first %to &last;
    y&i= exp( (supplndiff&i * mmatsrvavgvalshare&i)+ (servlndiff&i * smatsrvavgvalshare&i) );
	%end;
	y&first=100;
run;
%MEND weightedmatsrv;
%weightedmatsrv(first=&first, last=&last);

%MACRO MATSRV (first, second, secondtolast, last);
data IP.MATSRV (keep= NAICS y:);
	set work.weightedmatsrv;
	%do year2 = &second %to &last;
			%do year = &first %to &secondtolast;
				if &year2 = &year + 1 then
				y&year2 = y&year2 * y&year;
			%end;
	%end;
run;
%MEND MATSRV;
%MATSRV(first=&first, second=&second, secondtolast=&secondtolast,last=&last);
/*End Index of Materials and Services*/

/*AGGREGATION OF IP******************************************************************************/
%MACRO ELECquan (first, last);
data work.elecquan (keep=NAICS elecquan:);
	merge work.costofelectricity work.priceofelectricity;
	%do i = &first %to &last;
    elecquan&i= (CostOfElectricity&i / PriceOfElectricity&i) * 100;
	%end;
run;
%MEND ELECquan;
%ELECquan(first=&first, last=&last);

%MACRO SERVquan (first, last);
data work.servquan (keep=NAICS servquan:);
	merge work.costofservices work.priceofservices;
	%do i = &first %to &last;
    servquan&i= (CostOfServices&i / PriceOfServices&i) * 100;
	%end;
run;
%MEND SERVquan;
%SERVquan(first=&first, last=&last);

%MACRO AGGquan (first, last);
data work.AGGquan (keep=NAICS AGGquan:);
	merge work.fuelsquan work.suppliesquan work.elecquan work.servquan;
	%do i = &first %to &last;
    aggquan&i= (fuelsquan&i + suppliesquan&i + elecquan&i + servquan&i) / 1000;
	%end;
run;
%MEND AGGquan;
%AGGquan(first=&first, last=&last);

%MACRO DIRAGGIP (first, last);
data IP.diraggip (keep=NAICS y:);
	set work.aggquan;
	%do i = &first %to &last;
    y&i= (aggquan&i / aggquan&first) * 100;
	%end;
run;
%MEND DIRAGGIP;
%DIRAGGIP(first=&first, last=&last);
/*End Direct Aggregation of IP*/
