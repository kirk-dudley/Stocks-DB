
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

