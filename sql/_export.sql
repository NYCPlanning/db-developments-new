-- EXPORT DevDB
DROP TABLE IF EXISTS EXPORT_devdb;
SELECT * 
INTO EXPORT_devdb
FROM FINAL_devdb
WHERE (Date_Complete::date <=  :'CAPTURE_DATE'
	OR (Date_Complete IS NULL  
		AND Date_Permittd::date <=  :'CAPTURE_DATE')
	OR (Date_Complete IS NULL 
		AND Date_Permittd IS NULL 
		AND Date_Filed::date <=  :'CAPTURE_DATE'));

-- EXPORT HousingDB
DROP TABLE IF EXISTS EXPORT_housing;
SELECT * INTO EXPORT_housing
FROM EXPORT_devdb
WHERE resid_flag = 'Residential';

-- Switch to 10 char fieldnames
DROP TABLE IF EXISTS SHP_devdb;
SELECT
	Job_Number as "Job_Number",
	Job_Type as "Job_Type",
	Resid_Flag as "ResidFlag",
	Nonres_Flag as "NonresFlag",
	Job_Inactive as "Job_Inactv",
	Job_Status as "Job_Status",
	Complete_Year as "CompltYear",
	Complete_Qrtr as "CompltQrtr",
	Permit_Year as "PermitYear",
	Permit_Qrtr as "PermitQrtr",
	ClassA_Init as "ClassAInit",
	ClassA_Prop as "ClassAProp",
	ClassA_Net as "ClassANet",
	ClassA_HNYAff::NUMERIC as "ClassA_HNY",
	Hotel_Init as "HotelInit",
	Hotel_Prop as "HotelProp",
	OtherB_Init as "OtherBInit",
	OtherB_Prop as "OtherBProp",
	units_co as "Units_CO",
	Boro as "Boro",
	BIN as "BIN",
	BBL as "BBL",
	Address_Numbr as "AddressNum",
	Address_St as "AddressSt",
	Address as "Address",
	Occ_Initial as "Occ_Init",
	Occ_Proposed as "Occ_Prop",
	Bldg_Class as "Bldg_Class",
	Job_Desc as "Job_Desc",
	Desc_Other as "Desc_Other",
	Date_Filed as "DateFiled",
	Date_StatusD as "DateStatsD",
	Date_StatusP as "DateStatsP",
	Date_Permittd as "DatePermit",
	Date_StatusR as "DateStatsR",
	Date_StatusX as "DateStatsX",
	Date_LastUpdt as "DateLstUpd",
	Date_Complete as "DateComplt",
	ZoningDist1 as "ZoningDst1",
	ZoningDist2 as "ZoningDst2",
	ZoningDist3 as "ZoningDst3",
	SpecialDist1 as "SpeclDst1",
	SpecialDist2 as "SpeclDst2",
	Landmark as "Landmark",
	ZSF_Init as "ZSF_Init",
	ZSF_Prop as "ZSF_Prop",
	ZoningUG_init as "ZoningUG_init",
	ZoningUG_prop as "ZoningUG_prop",
	Stories_Init as "FloorsInit",
	Stories_Prop as "FloorsProp",
	Height_Init as "HeightInit",
	Height_Prop as "HeightProp",
	ConstructnSF as "CnstrctnSF",
	Enlargement as "Enlargemnt",
	EnlargementSF as "EnlrgSF",
	CostEstimate as "CostEst",
	LoftBoardCert as "LoftBoard",
	eDesignation as "eDesigntn",
	CurbCut as "CurbCut",
	TractHomes as "TractHomes",
	Ownership as "Ownership",
	owner_name as "OwnrName",
	Owner_Address as "OwnrAddr",
	Owner_ZipCode as "OwnrZip",
	Owner_Phone as "OwnrPhone",
	PLUTO_UnitRes as "PL_UnitRes",
	PLUTO_BldgSF as "PL_BldgSF",
	PLUTO_ComSF as "PL_ComSF",
	PLUTO_OffcSF as "PL_OffcSF",
	PLUTO_RetlSF as "PL_RetlSF",
	PLUTO_ResSF as "PL_ResSF",
	PLUTO_YrBuilt as "PL_YrBuilt",
	PLUTO_YrAlt1 as "PL_YrAlt1",
	PLUTO_YrAlt2 as "PL_YrAlt2",
	PLUTO_Histdst as "PL_Histdst",
	PLUTO_Landmk as "PL_Landmk",
	PLUTO_BldgCls as "PL_BldgCls",
	PLUTO_LandUse as "PL_LandUse",
	PLUTO_Owner as "PL_Owner",
	PLUTO_OwnType as "PL_OwnType",
	PLUTO_Condo as "PL_Condo",
	PLUTO_Bldgs as "PL_Bldgs",
	PLUTO_Floors as "PL_Floors",
	PLUTO_Version as "PL_Version",
	CenBlock2010 as "CenBlock10",
	CenTract2010 as "CenTract10",
	BCTCB2010 as "BCTCB2010",
	BCT2010 as "BCT2010",
	NTA2010 as "NTA2010",
	NTAName2010 as "NTAName10",
	CenBlock2020 as "CenBlock20",
	CenTract2020 as "CenTract20",
	BCTCB2020 as "BCTCB2020",
	BCT2020 as "BCT2020",
	NTA2020 as "NTA2020",
	NTAName2020 as "NTAName20",
	CDTA2020 as "CDTA2020",
	ComunityDist as "CommntyDst",
	CouncilDist as "CouncilDst",
	SchoolSubDist as "SchSubDist",
	SchoolCommnty as "SchCommnty",
	SchoolElmntry as "SchElmntry",
	SchoolMiddle as "SchMiddle",
	FireCompany as "FireCmpany",
	FireBattalion as "FireBattln",
	FireDivision as "FireDivsn",
	PolicePrecnct as "PolicePcnt",
	-- DEPDrainArea as "DEPDrainAr",
	-- DEPPumpStatn as "DEPPumpStn",
	PLUTO_FIRM07 as "PL_FIRM07",
	PLUTO_PFIRM15 as "PL_PFIRM15",
	Latitude as "Latitude",
	Longitude as "Longitude",
	DataSource as "DataSource",
	GeomSource as "GeomSource",
	DCPEditFields as "DCPEdited",
	HNY_ID as "HNY_ID",
	HNY_JobRelate as "HNY_Relate",
	Version as "Version",
	ST_SetSRID(ST_MakePoint(longitude,latitude), 4326) as geom
INTO SHP_devdb
FROM EXPORT_devdb;


DROP TABLE IF EXISTS SHP_housing;
SELECT * INTO SHP_housing
FROM SHP_devdb
WHERE "ResidFlag" = 'Residential';

