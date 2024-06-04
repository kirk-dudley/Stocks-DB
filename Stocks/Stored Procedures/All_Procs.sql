
CREATE OR ALTER PROCEDURE Add_Source

	@Name				NVARCHAR(255)	
	,@ParentID			INT	= NULL
	,@Description		NVARCHAR(MAX) = NULL
	,@Stage_Table		SYSNAME = NULL
	,@Data_Directory	NVARCHAR(255) = NULL
	,@Error_Directory	NVARCHAR(255) = NULL
	,@Archive_Directory	NVARCHAR(255) = NULL
	,@URL				NVARCHAR(255) = NULL
	,@PK				INT = NULL

AS

BEGIN TRANSACTION Add_Source;

	--If explicit ID is set, sets identity_insert on, and inserts
	IF @PK IS NOT NULL
	BEGIN
		SET IDENTITY_INSERT Sources ON;
		INSERT INTO Sources
			(
			SR_PK
			,SR_SR_FK
			,SR_Name
			,SR_Description
			,SR_Stage_Table
			,SR_Data_Directory
			,SR_Error_Directory
			,SR_Archive_Directory
			,SR_URL
			)
		SELECT
			@PK
			,@ParentID
			,@Name
			,@Description
			,@Stage_Table
			,@Data_Directory
			,@Error_Directory
			,@Archive_Directory
			,@URL
			;
		SET IDENTITY_INSERT Sources OFF;
	END
	ELSE
	BEGIN		--if identity is not set, a normal insert
		INSERT INTO Sources
			(
			SR_SR_FK
			,SR_Name
			,SR_Description
			,SR_Stage_Table
			,SR_Data_Directory
			,SR_Error_Directory
			,SR_Archive_Directory
			,SR_URL
			)
		SELECT
			@ParentID
			,@Name
			,@Description
			,@Stage_Table
			,@Data_Directory
			,@Error_Directory
			,@Archive_Directory
			,@URL
	END
	;
COMMIT TRANSACTION Add_Source;
GO


--SELECT * FROM Stock_Type
--SELECT * FROM Exchanges
--SELECT * FROM Stage_EOD_Daily
--TRUNCATE TABLE Stage_EOD_Daily

--IF OBJECT_ID('Add_Stage_EOD_Daily') IS NOT NULL
--DROP PROCEDURE Add_Stage_EOD_Daily
--GO

--DROP PROCEDURE Add_Stage_EOD_Daily
CREATE OR ALTER PROCEDURE Add_Stage_EOD_Daily

AS

BEGIN TRANSACTION EOD_Daily;

--Cleans up symbols once, avoids future processing costs
	UPDATE	Stage_EOD_Daily
	SET		SED_Symbol = UPPER(LTRIM(RTRIM(SED_Symbol)))
	WHERE	SED_Symbol <> UPPER(LTRIM(RTRIM(SED_Symbol)))


--Checks for missing symbols
	INSERT INTO Symbols
		(
		S_Changed_By
		,S_Changed_Date
		,S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Symbol
		)
	SELECT	
		T1.SED_Changed_By
		,T1.SED_Changed_Date
		,T1.SED_SR_FK	
		,4
		,0
		,T1.SED_F_FK
		,T1.SED_Symbol
	FROM	Stage_EOD_Daily T1
			JOIN
			(
			SELECT	SED_Symbol
					,MIN(SED_PK) MIN_PK
			FROM	Stage_EOD_Daily
					JOIN
					Files
						ON	SED_F_FK = F_PK
					LEFT OUTER JOIN
					Symbols
						ON	SED_Symbol = S_Symbol
			WHERE	S_PK IS NULL
			GROUP BY SED_Symbol
			) D1
				ON	T1.SED_PK = D1.MIN_PK
	;


	--updates existing records with new info.  
	UPDATE	Daily_Activity
	SET		DA_Changed_By = SED_Changed_By
			,DA_Changed_Date = SED_Changed_Date
			,DA_Close = SED_Close
			,DA_F_FK = SED_F_FK
			,DA_High = SED_High
			,DA_Low = SED_Low
			,DA_Open = SED_Open
			,DA_OpenInt = SED_OpenInt
			,DA_Volume = SED_Volume
	FROM	Stage_EOD_Daily 
			JOIN
			Symbols
				ON	SED_Symbol = S_Symbol
			JOIN
			Daily_Activity
				ON	SED_SR_FK = DA_SR_FK
				AND	SED_Date = DA_Date
				AND	S_PK = DA_S_FK
			JOIN
			Files					--This is to check for "locked" files in previously loaded data, it DOES NOT join to stage. 
				ON	DA_F_FK = F_PK
	WHERE	F_Is_Locked = 0
	;

	--Inserts new records
	INSERT INTO Daily_Activity
		(
		DA_S_FK
		,DA_F_FK
		,DA_SR_FK
		,DA_Changed_By
		,DA_Changed_Date
		,DA_Date
		,DA_Open
		,DA_High
		,DA_Low
		,DA_Close
		,DA_Volume
		,DA_OpenInt
		)
	SELECT
		S_PK
		,SED_F_FK
		,SED_SR_FK
		,SED_Changed_By
		,SED_Changed_Date
		,SED_Date
		,SED_Open
		,SED_High
		,SED_Low
		,SED_Close
		,SED_Volume
		,SED_OpenInt
	FROM	Stage_EOD_Daily
			JOIN
			Symbols
				ON	SED_Symbol = S_Symbol
	AND		NOT EXISTS
					(
					SELECT	*
					FROM	Daily_Activity
					WHERE	DA_S_FK = S_PK
					AND		DA_Date = SED_Date
					AND		DA_SR_FK = SED_SR_FK
					)
	;

COMMIT TRANSACTION EOD_Daily;
GO
--SELECT * FROM Symbols

--Some symbols can be duplicated across exchanges.
--Both exchange and symbol need to be used
--Once data is in daily_sales with exchange joined, the symbols should be unique.

CREATE OR ALTER PROCEDURE Add_Stage_EOD_Daily_Symbols

AS

SET NOCOUNT ON

BEGIN TRANSACTION Daily_Symbols;

	--With string/path joins, it's better to put into a temp table
	SELECT	SEDS_PK
			,SEDS_SR_FK
			,SEDS_F_FK
			,SEDS_Changed_By
			,SEDS_Changed_Date
			,Code
			,Name
			,RIGHT(F_Path, CHARINDEX('\', REVERSE(F_Path))-1) AS SEDS_Exchange
			,E_PK
	INTO	#Daily_Symbols		
	FROM	Stage_EOD_Daily_Symbols
			JOIN
			Files
				ON	SEDS_F_FK = F_PK
			LEFT OUTER JOIN
			Exchanges
				ON	RIGHT(F_Path, CHARINDEX('\', REVERSE(F_Path))-1) = E_Name
	WHERE	(CHARINDEX('\', REVERSE(F_Path))-1) >= 1
	;
	--index for faster performance on subsequent reads
	CREATE INDEX px_Temp ON	#Daily_Symbols (Code) INCLUDE(Name, Seds_SR_FK, Seds_F_FK, E_PK)
	;

--Updates existing
	UPDATE	Symbols
	SET		S_Name = Name
			,S_Changed_Date = SEDS_Changed_Date
			,S_F_FK = SEDS_F_FK
			,S_SR_FK = SEDS_SR_FK
	FROM	#Daily_Symbols T1
			JOIN
			Symbols
				ON	Code = S_Symbol
				AND	T1.E_PK = S_E_FK
	WHERE	Name <> S_Name
	;

--Inserts new
	INSERT INTO Symbols
		(
		S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Changed_Date
		,S_Symbol
		,S_Name
		)
	select	SEDS_SR_FK
			,4
			,E_PK
			,SEDS_F_FK
			,SEDS_Changed_Date
			,Code
			,Name
	FROM	#Daily_Symbols T1
			LEFT OUTER JOIN
			Symbols
				ON	Code = S_Symbol
				AND	T1.E_PK = S_E_FK
	WHERE	S_PK IS NULL
	GROUP BY 
			SEDS_Changed_Date
			,SEDS_SR_FK
			,SEDS_F_FK
			,E_PK
			,Code
			,Name
	;

COMMIT TRANSACTION Daily_Symbols;
GO





--DROP PROCEDURE Add_Stage_EOD_Exchanges
CREATE OR ALTER PROCEDURE Add_Stage_EOD_Exchanges

AS

BEGIN TRANSACTION Add_EOD_Exchanges;

	--updates existing records with new info
	UPDATE	Exchanges
	SET		E_F_FK = F_PK
			,E_SR_FK = SEE_SR_FK
			,E_Changed_By = SEE_Changed_By
			,E_Changed_Date = SEE_Changed_Date
			,E_Description = LTRIM(RTRIM(Name))
			,E_Country = LTRIM(RTRIM(Country))
			,E_Currency = LTRIM(RTRIM(Currency))
			,E_Suffix = LTRIM(RTRIM(Suffix))
			,E_Timezone = LTRIM(RTRIM(Timezone))
			,E_IsIntraday = LTRIM(RTRIM(IsIntraday))
			,E_Last_Trade = LTRIM(RTRIM(LastTradeDateTime))
			,E_Advances = LTRIM(RTRIM(Advances))
			,E_Declines = LTRIM(RTRIM(Declines))
	FROM	Exchanges E1
			JOIN
			Stage_EOD_Exchanges
				ON	E1.E_Name = Code
			JOIN
			Files F1
				ON	SEE_F_FK = F_PK
	WHERE	NOT EXISTS 
					(
					SELECT  *
					FROM	Exchanges E2
							JOIN
							Files F2
								ON	E2.E_F_FK = F2.F_PK
					WHERE	F2.F_Is_Locked = 1
					AND		E2.E_Name = E1.E_Name
					)
	;

	--inserts new records
	INSERT INTO Exchanges
		(
		E_Changed_By
		,E_Changed_Date
		,E_SR_FK
		,E_F_FK
		,E_Name
		,E_Description
		,E_Country
		,E_Currency
		,E_Suffix
		,E_Timezone
		,E_IsIntraday
		,E_Last_Trade
		,E_Advances
		,E_Declines
		)	
	SELECT	
		SEE_Changed_By
		,SEE_Changed_Date
		,SEE_SR_FK
		,SEE_F_FK
		,LTRIM(RTRIM(Code))
		,LTRIM(RTRIM(Name))
		,LTRIM(RTRIM(Country))
		,LTRIM(RTRIM(Currency))
		,LTRIM(RTRIM(Suffix))
		,LTRIM(RTRIM(Timezone))
		,IsIntraday
		,LastTradeDateTime
		,Advances
		,Declines
	FROM	Stage_EOD_Exchanges
			JOIN
			Files
				ON	SEE_F_FK = F_PK
	WHERE	NOT EXISTS 
					(
					SELECT	* 
					FROM	Exchanges 
					WHERE	E_Name = Code
					)
	;

COMMIT TRANSACTION Add_EOD_Exchanges;
GO



/*
SELECT * FROM symbols
SELECT * FROM FILES
SELECT * FROM Stage_EOD_Manual_Symbols

DELETE FROM FILES WHERE F_PK > 0

*/

--IF OBJECT_ID('Add_Stage_EOD_Manual_Symbols') IS NOT NULL
--DROP PROCEDURE Add_Stage_EOD_Manual_Symbols
--GO

--DROP PROCEDURE Add_Stage_EOD_Manual_Symbols NULL
CREATE OR ALTER PROCEDURE Add_Stage_EOD_Manual_Symbols

--	@F_PK		INT			--value of F_PK in the Files table, referenced by SEMS_F_FK in Stage_EOD_Manual_Symbols

AS

SET NOCOUNT ON;

--checks that @F_PK is valid
--IF (SELECT COUNT(*) FROM Files WHERE F_PK = @F_PK) = 0
--	THROW 50000, 'The value assigned to @F_PK is not valid', 1;

BEGIN TRANSACTION Add_Symbols;

	--updates existing records with new info
	UPDATE	Symbols
	SET		S_Description = LTRIM(RTRIM(SEMS_Description)) --Make sure there's no excess whitespace
			,S_SR_FK = SEMS_SR_FK
			,S_E_FK = E_PK
			,S_F_FK = SEMS_F_FK
			,S_Changed_By = SEMS_Changed_By
			,S_Changed_Date = SEMS_Changed_Date
	FROM	Symbols S1
			JOIN
			Stage_EOD_Manual_Symbols
				ON	S_Symbol = SEMS_Symbol
			JOIN
			Files F1
				ON	SEMS_F_FK = F_PK
			JOIN
			Exchanges
				ON	F_No_Ext = E_Name
	WHERE	S_Description <> LTRIM(RTRIM(SEMS_Description))
	AND		NOT EXISTS (SELECT * FROM Symbols S2 JOIN Files F2 ON S2.S_F_FK = F2.F_PK WHERE S1.S_PK = S2.S_PK AND F2.F_Is_Locked = 1) --checks that the original record isn't flagged as locked
	;


	--inserts new records
	INSERT INTO Symbols
		(
		S_Changed_By
		,S_Changed_Date
		,S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Symbol
		,S_Name
		)	
	SELECT		
		SEMS_Changed_By
		,SEMS_Changed_Date
		,SEMS_SR_FK
		,4  --UNKOWN
		,E_PK
		,F_PK
		,RTRIM(LTRIM(SEMS_Symbol))
		,RTRIM(LTRIM(SEMS_Description))
	--select *
	FROM	Stage_EOD_Manual_Symbols
			JOIN
			Files
				ON	F_PK = SEMS_F_FK
			JOIN
			Exchanges
				ON	F_No_Ext = E_Name
	WHERE	NOT EXISTS 
					(
					SELECT	* 
					FROM	Symbols 
					WHERE	S_Symbol = RTRIM(LTRIM(SEMS_Symbol))
					)
	;

COMMIT TRANSACTION Add_Symbols;
GO


CREATE OR ALTER PROCEDURE Add_Stage_Kaggle_Bitcoin

AS

--Checks for a bitcoin symbol

BEGIN TRANSACTION Kaggle_Bitcoin;

	IF NOT EXISTS (SELECT * FROM Symbols WHERE S_Symbol = 'BTC')
	BEGIN
		INSERT INTO Symbols
			(
			S_SR_FK				
			,S_ST_FK
			,S_E_FK
			,S_F_FK
			,S_Changed_By
			,S_Changed_Date
			,S_Symbol
			,S_Name
			)
		SELECT DISTINCT 
			SKB_SR_FK
			,4
			,0
			,SKB_F_FK
			,SKB_Changed_By
			,SKB_Changed_Date
			,'BTC'
			,'BitCoin'
		FROM	Stage_Kaggle_Bitcoin
	END
	;
--Updates existing

	UPDATE	Daily_Activity
	SET		DA_Changed_By = SKB_Changed_By
			,DA_Changed_Date = SKB_Changed_Date
			,DA_Close = SKB_Close
			,DA_F_FK = SKB_F_FK
			,DA_High = SKB_High
			,DA_Low = SKB_Low
			,DA_Open = SKB_Open
			,DA_Volume = SKB_Volume
	FROM	Stage_Kaggle_Bitcoin
			JOIN
			Symbols
				ON	'BTC' = S_Symbol
			JOIN
			Daily_Activity
				ON	SKB_SR_FK = DA_SR_FK
				AND	SKB_End = DA_Date
				AND	S_PK = DA_S_FK
			JOIN
			Files					--This is to check for "locked" files in previously loaded data, it DOES NOT join to stage. 
				ON	DA_F_FK = F_PK
	WHERE	F_Is_Locked = 0
	;

		--Inserts new records
	INSERT INTO Daily_Activity
		(
		DA_S_FK
		,DA_F_FK
		,DA_SR_FK
		,DA_Changed_By
		,DA_Changed_Date
		,DA_Date
		,DA_Open
		,DA_High
		,DA_Low
		,DA_Close
		,DA_Volume
		)
	SELECT
		S_PK
		,SKB_F_FK
		,SKB_SR_FK
		,SKB_Changed_By
		,SKB_Changed_Date
		,SKB_End
		,SKB_Open
		,SKB_High
		,SKB_Low
		,SKB_Close
		,SKB_Volume
	FROM	Stage_Kaggle_Bitcoin
			JOIN
			Symbols
				ON	'BTC' = S_Symbol
	AND		NOT EXISTS
					(
					SELECT	*
					FROM	Daily_Activity
					WHERE	DA_S_FK = S_PK
					AND		DA_Date = SKB_End
					AND		DA_SR_FK = SKB_SR_FK
					)
	ORDER BY SKB_End
	;

COMMIT TRANSACTION Kaggle_Bitcoin;
GO


--DROP PROCEDURE Add_Stage_Kaggle_Stocks
CREATE OR ALTER PROCEDURE Add_Stage_Kaggle_Stocks

AS

SET NOCOUNT ON

BEGIN TRANSACTION Kaggle_Stocks;

--Updates Kaggle ETF source ids
--If this was a resued production enviroment, I probably would have broken out the SSIS package into 2.
--This is just to show a different method of taking care of source IDs.

	UPDATE	Stage_Kaggle_Stocks
	SET		SKS_SR_FK = 9
	--SELECT	*
	FROM	Stage_Kaggle_Stocks
			JOIN
			Files
				ON	SKS_F_FK = F_PK
	WHERE	F_Path LIKE '%\ETFs%'
	;

	--UPDATES FILES AS WELL.
	UPDATE	Files
	SET		F_SR_FK = 9
	WHERE	F_SR_FK = 10
	AND		F_Path LIKE '%\ETFs%'
	;
	--Checks for missing symbols

	INSERT INTO Symbols
		(
		S_Changed_By
		,S_Changed_Date
		,S_SR_FK
		,S_ST_FK
		,S_E_FK
		,S_F_FK
		,S_Symbol
		)

	SELECT	T1.SKS_Changed_By
			,T1.SKS_Changed_Date
			,T1.SKS_SR_FK	
			,4			--ST_FK
			,0			--E_FK
			,T1.SKS_F_FK
			,UPPER(LTRIM(RTRIM(F_To_First_Dot)))
	FROM	Stage_Kaggle_Stocks T1
			JOIN
			(
			SELECT	F_To_First_Dot 
					,MAX(SKS_PK) MAX_PK
			FROM	Stage_Kaggle_Stocks
					JOIN
					Files
						ON	SKS_F_FK = F_PK
					LEFT OUTER JOIN
					Symbols
						ON	F_To_First_Dot = S_Symbol
			WHERE	S_PK IS NULL
			GROUP BY F_To_First_Dot 
			) D1
				ON	T1.SKS_PK = MAX_PK
	;
	--Updates existing records to most current data, except for "locked" files
	UPDATE	Daily_Activity
	SET		DA_Changed_By = SKS_Changed_By
			,DA_Changed_Date = SKS_Changed_Date
			,DA_Close = SKS_Close
			,DA_F_FK = SKS_F_FK
			,DA_High = SKS_High
			,DA_Low = SKS_Low
			,DA_Open = SKS_Open
			,DA_OpenInt = SKS_OpenInt
			,DA_Volume = SKS_Volume
	FROM	Stage_Kaggle_Stocks
			JOIN
			Files F1
				ON	SKS_F_FK = F1.F_PK
			JOIN
			Symbols
				ON	F_To_First_Dot = S_Symbol
			JOIN
			Daily_Activity
				ON	SKS_SR_FK = DA_SR_FK
				AND	SKS_Date = DA_Date
				AND	S_PK = DA_S_FK
			JOIN
			Files F_Lock					--This is to check for "locked" files in previously loaded data, it DOES NOT join to stage. 
				ON	DA_F_FK = F_Lock.F_PK
	WHERE	F_Lock.F_Is_Locked = 0
	;


--insert snew records

	--Inserts new records
	INSERT INTO Daily_Activity
		(
		DA_S_FK
		,DA_F_FK
		,DA_SR_FK
		,DA_Changed_By
		,DA_Changed_Date
		,DA_Date
		,DA_Open
		,DA_High
		,DA_Low
		,DA_Close
		,DA_Volume
		,DA_OpenInt
		)
	SELECT
		S_PK
		,SKS_F_FK
		,SKS_SR_FK
		,SKS_Changed_By
		,SKS_Changed_Date
		,SKS_Date
		,SKS_Open
		,SKS_High
		,SKS_Low
		,SKS_Close
		,SKS_Volume
		,SKS_OpenInt
	FROM	Stage_Kaggle_Stocks
			JOIN
			Files
				ON	SKS_F_FK = F_PK
			JOIN
			Symbols
				ON	F_To_First_Dot = S_Symbol
	AND		NOT EXISTS
					(
					SELECT	*
					FROM	Daily_Activity
					WHERE	DA_S_FK = S_PK
					AND		DA_Date = SKS_Date
					AND		DA_SR_FK = SKS_SR_FK
					)
	;

COMMIT TRANSACTION Kaggle_Stocks;
GO


--Get_File_IDs 'C:\TEMP\BOB.TXT', 'Test Data'
--SELECT * FROM FILES JOIN SOURCES ON F_SR_FK = SR_PK

CREATE OR ALTER PROCEDURE Get_File_IDs

	@Filename		VARCHAR(260)
	,@SR_PK			INT

AS

SET NOCOUNT ON

--checks that @SR_PK is valid
IF (SELECT COUNT(*) FROM Sources WHERE SR_PK = @SR_PK) = 0
	THROW 50000, 'The value assigned to @SR_PK is not valid', 1;

--checks that @Filename is valid
IF ISNULL(@Filename, '') = ''
	THROW 50000, 'The value assigned to @Filename is not valid', 1;

BEGIN TRANSACTION IDS;

	--inserts values
	INSERT INTO Files
		(
		F_FileName
		,F_SR_FK
		)
	SELECT
		@Filename
		,@SR_PK
	;
--gets timestamp, fileid
	SELECT	F_PK
			,F_Changed_Date
	FROM	Files
	WHERE	F_PK = @@IDENTITY
	;

COMMIT TRANSACTION IDs;
GO