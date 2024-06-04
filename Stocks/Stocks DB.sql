	
USE master
GO

DECLARE	@kill	VARCHAR(8000) = '';  
SELECT	@kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';'  
FROM sys.dm_exec_sessions
WHERE database_id  = db_id('Stocks')
--print @kill
EXEC(@kill)
GO

IF DB_ID('Stocks') IS NOT NULL
DROP DATABASE Stocks
GO

CREATE DATABASE Stocks
	ON	
	(NAME = Stocks_Data
	,FILENAME = 'D:\SQL\Stocks_Data.mdf'
	,SIZE = 10MB
	,FILEGROWTH = 10MB
	)
	LOG ON	
	(NAME = Stocks_Log
	,FILENAME = 'D:\SQL\Stocks_Log.ldf'
	,SIZE = 10MB
	,FILEGROWTH = 10MB
	)
GO

USE Stocks
GO

--By giving each table unique prefixes for its columns, a new DBA can quickly trace foreign references, and it will force some standardization
--of "aliases" in stored procedures


IF OBJECT_ID('Sources') IS NOT NULL
DROP TABLE Sources
GO

CREATE TABLE Sources
	(
	SR_PK					INT	IDENTITY(0, 1) CONSTRAINT SR_PK PRIMARY KEY CLUSTERED
	,SR_SR_FK				INT NULL CONSTRAINT SR_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK) --Can have a parent ID< but must be valid
	,SR_Changed_By			NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SR_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL	
	,SR_Name				NVARCHAR(255) NOT NULL
	,SR_Description			NVARCHAR(MAX)	NULL
	,SR_Stage_Table			SYSNAME	NULL
	,SR_Data_Directory		NVARCHAR(260) NULL
	,SR_Error_Directory		NVARCHAR(260) NULL
	,SR_Archive_Directory	NVARCHAR(260) NULL
	,SR_URL					NVARCHAR(MAX) NULL
	)
GO



--This will keep track of imported files.  It will contain info on if the file was altered, and if it is excluded from being reloaded as a default.
IF OBJECT_ID('Files') IS NOT NULL
DROP TABLE Files
GO

--This isn't all of the possible variations on file names/paths, I've treid to get the ones that are going to be referenced often as calculated oclumns, storage is cheap, processing is not, dev time is even more.
CREATE TABLE Files
	(
	F_PK				INT IDENTITY(0, 1) CONSTRAINT F_PK PRIMARY KEY CLUSTERED
	,F_SR_FK			INT CONSTRAINT F_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,F_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,F_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,F_FileName			NVARCHAR(255) NOT NULL CONSTRAINT F_Filename_Pattern CHECK (F_Filename LIKE '%\%.%')
	,F_Path				AS LEFT(F_Filename, LEN(F_Filename) - CHARINDEX('\', REVERSE(F_Filename)))	
	,F_Short_Name		AS RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1)
	,F_No_Ext			AS LEFT(RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1), LEN(RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1)) - CHARINDEX('.', REVERSE(RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1))))
	,F_To_First_Dot		AS LEFT(RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1), CHARINDEX('.', RIGHT(F_Filename, CHARINDEX('\', REVERSE(F_Filename))-1))-1)
	,F_Is_Altered		BIT NOT NULL DEFAULT 0 
	,F_Is_Locked		BIT NOT NULL DEFAULT 0
	)
GO

CREATE INDEX px_F_FileInfo ON Files (F_Filename, F_Changed_By, F_Changed_Date)
GO


--The various types of stocks, just a simple insert here as it's just 4 rows so far.
IF OBJECT_ID('Stock_Type') IS NOT NULL
DROP TABLE Stock_Type
GO

CREATE TABLE Stock_Type 
	(
	ST_PK				SMALLINT IDENTITY(0, 1) CONSTRAINT ST_PK PRIMARY KEY CLUSTERED
	,ST_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,ST_Changed_Date	DATETIME DEFAULT GETDATE() NOT NULL
	,ST_Name			NVARCHAR(255)	NOT NULL
	,ST_Description		NVARCHAR(MAX)	NULL
	)
GO


--List of the various exchanges.  The raw files have some recent trade data, however this isn't being updated currently, and will be left NULL
IF OBJECT_ID('Exchanges') IS NOT NULL
DROP TABLE Exchanges
GO

CREATE TABLE Exchanges
	(
	E_PK				SMALLINT IDENTITY(0, 1) CONSTRAINT E_PK PRIMARY KEY CLUSTERED
	,E_SR_FK			INT CONSTRAINT E_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,E_F_FK				INT CONSTRAINT E_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,E_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,E_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,E_Name				NVARCHAR(255)	NOT NULL
	,E_Description		NVARCHAR(MAX)	NULL
	,E_Country			NVARCHAR(255)	NULL
	,E_Currency			NVARCHAR(255)	NULL
	,E_Suffix			NVARCHAR(255)	NULL
	,E_Timezone			NVARCHAR(255)	NULL
	,E_IsIntraday		BIT				NULL
	,E_Last_Trade		DATETIME NULL
	,E_Advances			INT NULL
	,E_Declines			INT	NULL
	,E_Wiki_URL			NVARCHAR(MAX)	NULL
	)
GO


IF OBJECT_ID('Symbols') IS NOT NULL
DROP TABLE Symbols
GO

CREATE TABLE Symbols
	(
	S_PK				INT IDENTITY(0, 1) CONSTRAINT S_PK PRIMARY KEY CLUSTERED
	,S_SR_FK			INT CONSTRAINT S_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,S_ST_FK			SMALLINT CONSTRAINT S_ST_FK FOREIGN KEY REFERENCES Stock_Type(ST_PK)  
	,S_E_FK				SMALLINT CONSTRAINT S_E_FK FOREIGN KEY REFERENCES Exchanges(E_PK)
	,S_F_FK				INT CONSTRAINT S_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,S_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,S_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,S_Symbol			NVARCHAR(255)	NOT NULL	--Stocks currently have a max length of 5, and a min of 3, so I'd've used an NVARCHAR anyways, so why not make it bigger for future hardening?  Also, space is cheap.  Labor to fix to short of data types is expensive.
	,S_Name				NVARCHAR(255)	NULL
	,S_Description		NVARCHAR(MAX)	NULL
	)
GO

CREATE INDEX px_Symbol ON Symbols (S_Symbol, S_SR_FK, S_ST_FK, S_E_FK, S_F_FK)
GO

IF OBJECT_ID('Daily_Activity') IS NOT NULL
DROP TABLE Daily_Activity
GO

CREATE TABLE Daily_Activity
	(
	DA_PK				BIGINT IDENTITY(1, 1) CONSTRAINT DA_PK PRIMARY KEY NONCLUSTERED
	,DA_SR_FK			INT CONSTRAINT DA_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,DA_S_FK			INT CONSTRAINT DA_S_FK FOREIGN KEY REFERENCES Symbols(S_PK)
	,DA_F_FK			INT	CONSTRAINT DA_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,DA_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,DA_Changed_Date	DATETIME DEFAULT GETDATE() NOT NULL
	,DA_Date			DATE NOT NULL
	,DA_Open			DECIMAL(38, 8) NULL  --These data types exceed both max values and current max decimals, but once again, storage is cheap, labor to fix stuff later is not
	,DA_High			DECIMAL(38, 8) NULL  
	,DA_Low				DECIMAL(38, 8) NULL  
	,DA_Close			DECIMAL(38, 8) NULL  
	,DA_Volume			DECIMAL(38, 8) NULL  
	,DA_OpenInt			DECIMAL(38, 8) NULL  --This is in the source file, not sure what it does
	,DA_Is_Altered		BIT NOT NULL DEFAULT 0 
	,DA_Is_Locked		BIT NOT NULL DEFAULT 0
	)
GO

CREATE CLUSTERED INDEX cx_DA_FK ON Daily_Activity(DA_S_FK, DA_F_FK, DA_Date)
GO


--dataset from https://www.kaggle.com/datasets/borismarjanovic/price-volume-data-for-all-us-stocks-etfs

--SELECT * FROM Sources

IF OBJECT_ID('Stage_Kaggle_Stocks') IS NOT NULL
DROP TABLE Stage_Kaggle_Stocks
GO

CREATE TABLE Stage_Kaggle_Stocks
	(
	SKS_PK				INT IDENTITY(1, 1) NOT NULL
	,SKS_SR_FK			INT CONSTRAINT SKS_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SKS_F_FK			INT CONSTRAINT SKS_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SKS_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SKS_Changed_Date	DATETIME DEFAULT GETDATE() NOT NULL
	,SKS_Date			DATE NOT NULL
	,SKS_Open			DECIMAL(38, 8) NOT NULL  --These data types exceed both max values and current max decimals, but once again, storage is cheap, labor to fix stuff later is not
	,SKS_High			DECIMAL(38, 8) NOT NULL  
	,SKS_Low			DECIMAL(38, 8) NOT NULL  
	,SKS_Close			DECIMAL(38, 8) NOT NULL  
	,SKS_Volume			DECIMAL(38, 8) NOT NULL  
	,SKS_OpenInt		DECIMAL(38, 8) NULL  
	)
GO

--data from https://eoddata.com/

IF OBJECT_ID('Stage_EOD_Daily') IS NOT NULL
DROP TABLE Stage_EOD_Daily
GO

CREATE TABLE Stage_EOD_Daily
	(
	SED_PK				INT IDENTITY(1, 1) NOT NULL
	,SED_SR_FK			INT	CONSTRAINT SED_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SED_F_FK			INT CONSTRAINT SED_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SED_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SED_Changed_Date	DATETIME DEFAULT GETDATE() NOT NULL
	,SED_Symbol			VARCHAR(255)
	,SED_Date			DATE NOT NULL
	,SED_Open			DECIMAL(38, 8) NOT NULL  --These data types exceed both max values and current max decimals, but once again, storage is cheap, labor to fix stuff later is not
	,SED_High			DECIMAL(38, 8) NOT NULL  
	,SED_Low			DECIMAL(38, 8) NOT NULL  
	,SED_Close			DECIMAL(38, 8) NOT NULL  
	,SED_Volume			DECIMAL(38, 8) NOT NULL  
	,SED_OpenInt		DECIMAL(38, 8) NULL  --Roughly Half the files have this.
	)
GO



IF OBJECT_ID('Stage_EOD_Manual_Symbols') IS NOT NULL
DROP TABLE Stage_EOD_Manual_Symbols
GO

CREATE TABLE Stage_EOD_Manual_Symbols
	(
	SEMS_PK				INT	IDENTITY(1, 1) CONSTRAINT SEMS_PK PRIMARY KEY NONCLUSTERED
	,SEMS_SR_FK			INT CONSTRAINT SEMS_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SEMS_F_FK			INT CONSTRAINT SEMS_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SEMS_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SEMS_Changed_Date	DATETIME DEFAULT GETDATE() NOT NULL
--	,SEMS_FileName		NVARCHAR(260) NOT NULL
	,SEMS_Symbol			VARCHAR(255) NOT NULL
	,SEMS_Description	VARCHAR(255) NOT NULL
	)


IF OBJECT_ID('Stage_EOD_Exchanges') IS NOT NULL
DROP TABLE Stage_EOD_Exchanges
GO

CREATE TABLE Stage_EOD_Exchanges
	(
	SEE_PK					INT IDENTITY(1, 1) CONSTRAINT SEE_PK	PRIMARY KEY NONCLUSTERED
	,SEE_SR_FK				INT CONSTRAINT SEE_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SEE_F_FK				INT CONSTRAINT SEE_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SEE_Changed_By			NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SEE_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,Code					NVARCHAR(255) NULL
	,[Name]					NVARCHAR(255) NULL
	,LastTradeDateTime		DATETIME
	,Country				NVARCHAR(255) NULL
	,Currency				NVARCHAR(255) NULL
	,Advances				INT		NULL
	,Declines				SMALLINT	NULL
	,Suffix					NVARCHAR(255) NULL
	,Timezone				NVARCHAR(255) NULL
	,IsIntraday				BIT
	)

IF OBJECT_ID('Stage_Kaggle_Bitcoin') IS NOT NULL
DROP TABLE Stage_Kaggle_Bitcoin
GO

CREATE TABLE Stage_Kaggle_Bitcoin
	(
	SKB_PK					INT		IDENTITY(1, 1) CONSTRAINT SKB_PK PRIMARY KEY NONCLUSTERED
	,SKB_SR_FK				INT CONSTRAINT SKB_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SKB_F_FK				INT CONSTRAINT SKB_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SKB_Changed_By			NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SKB_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,SKB_Start				DATETIME
	,SKB_End				DATETIME
	,SKB_Open				DECIMAL(38, 8) 
	,SKB_High				DECIMAL(38, 8) 
	,SKB_Low				DECIMAL(38, 8) 
	,SKB_Close				DECIMAL(38, 8) 
	,SKB_Volume				DECIMAL(38, 8) 
	,SKB_Market_Cap			DECIMAL(38, 8) 
	)
GO


IF OBJECT_ID('Stage_EOD_Daily_Symbols') IS NOT NULL
DROP TABLE Stage_EOD_Daily_Symbols
GO

CREATE TABLE Stage_EOD_Daily_Symbols
	(
	SEDS_PK					INT		IDENTITY(1, 1) CONSTRAINT SEDS_PK PRIMARY KEY NONCLUSTERED
	,SEDS_SR_FK				INT CONSTRAINT SEDS_SR_FK FOREIGN KEY REFERENCES Sources(SR_PK)
	,SEDS_F_FK				INT CONSTRAINT SEDS_F_FK FOREIGN KEY REFERENCES Files(F_PK)
	,SEDS_Changed_By		NVARCHAR(255)	DEFAULT SUSER_SNAME() NOT NULL
	,SEDS_Changed_Date		DATETIME DEFAULT GETDATE() NOT NULL
	,Code					NVARCHAR(255)
	,[Name]					NVARCHAR(255)
	)

/*
SELECT	*
FROM	Sources
*/

