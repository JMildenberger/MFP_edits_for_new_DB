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
      length dataset $29;
      infile "R:\MFP DataSets\Manufacturing\MFP\SAS Inputs\MFP_Parameters.txt" dlm='09'x firstobs=2;
      input dataset firstyr lastyr baseperiod;
      call symput('last', trim(left(put(lastyr, 4.))));
run;
 %put &last;

/***************************************************************************************/
/*STEP 3*/
/***************************************************************************************/
proc iml;
/*importing capital flow chart for equipment for 1997 into sas iml matrix form - these are
total values of assets in a particular industry for the year of the capital flow table 
(in this case 1997)these are being imported to form the inital matrix for the RAS method used 
later*/
use capital.equipment;
read all var {ome15	ome16	ome17	ome18	ome19	ome20 	ome21	ome22	ome23
ome24	ome25	ome26	ome27	ome28	ome29	ome30	ome31	ome32	ome33	ome34	ome35
ome36	ome37	ome38	ome39	ome40	ome41	ome42	ome43	ome44	ome45	ome46	ome47
ome48	ome49	ome50	ome51	ome52	ome53	ome54	ome55	ome56	ome57	ome58	ome59
ome60	ome61	ome62	ome63	ome64	ome65	ome66	ome67} into equipment;

/*transposing capital flow chart - columns are assets types (27 columns)
rows are industries (53 rows)*/
tranequipment = t(equipment);

tranequipment[,15]=tranequipment[,15]+tranequipment[,26];/*adding asset 15 and asset 26 - autos
and light trucks, afterwards, light trucks (26) are set to zero - this is done to match the
aggregation preformed in the DMSP data*/
tranequipment[,26]=0;
/*retransposing transposted equipment to get new equipment matrix with combined 15 and 26*/
equipment = t(tranequipment);

/* generate special tools ratio, using 1997 value for special tools, and then applying to 
industry categories 61 and 62: motor vehicle manufacturing and parts stuff - Flow chart
categories - note: this is just for asset 9 - metalworking machinery*/

/*loading current capital flow year special tools value (1997) */
use sptools.cfsptyr;
read all var {sptlcfyr} into sptlcfyr;

/* columns are industries and rows are assets in equipment this step takes asset capital
equipment category 9 (metal working machinery) and adds this asset for industries 47 and 48, 
which are motor vehicle manufacturing and motor vehicle body, trailer and parts manufacturing
respectively  - corresponding to BEA industry codes 61 and 62*/
trkstotal = equipment[9,47] + equipment[9,48];

/*creating ratios of the corresponding asset values for each industry to the total value*/
prop61 = equipment[9,47]/trkstotal;
prop62 = 1 - prop61;

/*using ratios above to formulate new asset values for metal working machinery based on the 
special tools value for the Capital flow year (subtract out special tools) - note this is 
for one value because the capital flow chart is for 1997!! Note 2 - If we are using the real 
value for special tools and if the capital flow table is nominal, perhaps we should be using
the nominal value of special tools instead*/
equipment[9,47] = equipment[9,47] - (sptlcfyr[1,1]*prop61);
equipment[9,48]=equipment[9,48] - (sptlcfyr[1,1]*prop62);

/*importing capital structures flow data for 1997 into sas iml*/
use capital.structures;
read all var {oms15	oms16	oms17	oms18	oms19	oms20 	oms21	oms22	oms23
oms24	oms25	oms26	oms27	oms28	oms29	oms30	oms31	oms32	oms33	oms34	oms35
oms36	oms37	oms38	oms39	oms40	oms41	oms42	oms43	oms44	oms45	oms46	oms47
oms48	oms49	oms50	oms51	oms52	oms53	oms54	oms55	oms56	oms57	oms58	oms59
oms60	oms61	oms62	oms63	oms64	oms65	oms66	oms67} into structures;


create capital.equipimat from equipment;
append from equipment;
create capital.structimat from structures;
append from structures;

quit;

/*Removeing the 2008 nominal special tools value from asset 9 in industry 3361*/
proc iml;
use capital.ACES_2008_Equip_Original;
read all into aces;
use sptools.special_tools;
read all into sptools_value;

ACES[9,32]=ACES[9,32]-sptools_value[62,2];

create capital.aces_2008_equip from aces;
append from aces;
quit;

/*Removeing the 2012 nominal special tools value from asset 9 in industry 3361*/
proc iml;
use capital.ACES_2012_Equip_Original;
read all into aces;
use sptools.special_tools;
read all into sptools_value;

ACES[9,32]=ACES[9,32]-sptools_value[66,2];

create capital.aces_2012_equip from aces;
append from aces;
quit;


/*renaming columns to correspond to industry classifications on the flow chart*/
data capital.equipimat;
set capital.equipimat;
rename col1-col53=ame15-ame67;
run;
data capital.structimat;
set capital.structimat;
rename col1-col53=ams15-ams67;
run;
