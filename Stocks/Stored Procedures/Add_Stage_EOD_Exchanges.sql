


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



