
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


