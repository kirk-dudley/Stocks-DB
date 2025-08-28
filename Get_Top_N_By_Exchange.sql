--Get_Top_N_By_Exchange 'NASDAQ', 37, 'M', 6, 2
CREATE   PROCEDURE Get_Top_N_By_Exchange 

	@Exchange		NVARCHAR(255)
	,@N				INT
	,@DateType		NVARCHAR(255)
	,@Interval		INT
	,@Min_Price		DECIMAL(38, 8) = 0

AS

DECLARE	@E_PK			INT
		,@DateStart		DATE
		,@DateEnd		DATE
		,@SQL			NVARCHAR(255)

SET	@Interval = ABS(@Interval) * -1 --Makes sure interval is a negative.  

--SELECT @Interval

--That exchange name or id is valid
BEGIN TRY
	SELECT	@E_PK = E_PK
	FROM	Exchanges
	WHERE	E_Name = @Exchange
	OR		CONVERT(NVARCHAR, E_PK) = @Exchange

	IF @E_PK IS NULL
		THROW 50000, 'Invalid Exhange Name or PK', 1;
END TRY
BEGIN CATCH
    SELECT	ERROR_NUMBER() AS ErrorNumber,
			ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

--Gets the most recent exchange date
SELECT @DateEnd = MAX(Stock_Date) FROM vw_Dates WHERE E_FK = @E_PK
--SELECT @DateEnd


--Gets the start date.  Dateadd won't accept @variable as the date type, for some inexplicable reason, and doesn't like the datepart to be a quoted string or variable, 
--So the whole thing needs to be a string with just @DateStart out rather than passing the inputs as variables.
BEGIN TRY
	SET	@SQL = N'SELECT @DateStart = DATEADD(' + CONVERT(NVARCHAR(255), @Datetype) + ', ' + CONVERT(NVARCHAR(255), @Interval) + ', ''' + CONVERT(NVARCHAR(255), @DateEnd) + ''')'
--	SELECT @SQL
	EXEC sys.SP_EXECUTESQL @SQL, N'@DateStart DATETIME OUT', @DateStart OUT
END TRY
BEGIN CATCH
    SELECT	ERROR_NUMBER() AS ErrorNumber,
			ERROR_MESSAGE() AS ErrorMessage;
END CATCH;


--Setting start date to a valid date

BEGIN TRY
	--SELECT	@DateEnd AS End_Date
	--		,@DateStart AS Ref_Date
	--		,MAX(DA_Date) AS StartDate
	--FROM	vw_Dates_Sub
	--WHERE	S_E_FK = @E_PK
	--AND		DA_Date <= @DateStart

	SELECT	@DateStart = MAX(DA_Date) 
	FROM	vw_Dates_Sub
	WHERE	S_E_FK = @E_PK
	AND		DA_Date <= @DateStart

END TRY
BEGIN CATCH
    SELECT	ERROR_NUMBER() AS ErrorNumber,
			ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

--Gets 2 days of data per exchange into table variable, keeps from having to constantly reference large underlying tables,
--Runs the comparisons
BEGIN TRY
	DECLARE	@Data	TABLE
		(
		Symbol		NVARCHAR(255)
		,[Name]		NVARCHAR(255)
		,[Date]		DATE
		,[Open]		DECIMAL(38, 8)
		,[High]		DECIMAL(38, 8)
		,[Low]		DECIMAL(38, 8)
		,[Close]	DECIMAL(38, 8)
		,Volume		DECIMAL(38, 8)
		,OpenInt	DECIMAL(38, 8)
		)

	INSERT INTO @Data

	SELECT	
		S_Symbol
		,ISNULL(S_Name, S_Symbol) Name
		,DA_Date
		,DA_Open
		,DA_High
		,DA_Low
		,DA_Close
		,DA_Volume
		,DA_OpenInt
	FROM	Daily_Activity
			JOIN
			Symbols
				ON	DA_S_FK = S_PK
	WHERE	S_E_FK = @E_PK
	AND		(	DA_Date = @DateStart
			OR	DA_Date = @DateEnd
			)

	SELECT	TOP (@N) 
			D2.Symbol
			,D2.[Name]
			,D1.[Date] [Historic Date]
			,D2.[Date] [Most Recent Date]
			,D1.[Open] [Historic Open]
			,D2.[Open] [Current Open]
			,D1.[High] [Historic High]
			,D2.[High] [Current High]
			,D1.[Low] [Historic Low]
			,D2.[Low] [Current Low]
			,D1.[Close] [Historic Close]
			,D2.[Close] [Current Close]
			,D1.[Volume] [Historic Volume]
			,D2.[Volume] [Current Volume]
			,(D2.[Close] - D1.[Close]) / D1.[Close] [Percent Growth]
			,(D2.[Close] - D1.[Close]) [Absolute Growth]
	FROM	@Data D1
			JOIN
			@Data D2
				ON	D1.Symbol = D2.Symbol
				AND	D1.[Date] < D2.[Date]
	WHERE	D1.[Open] >= @Min_Price	
	OR		D2.[Open] >= @Min_Price	
	OR		D1.[High] >= @Min_Price	
	OR		D2.[High] >= @Min_Price	
	OR		D1.[Low] >= @Min_Price	
	OR		D2.[Low] >= @Min_Price	
	OR		D1.[Close] >= @Min_Price	
	OR		D2.[Close] >= @Min_Price	
	ORDER BY (D2.[Close] - D1.[Close]) / D1.[Close] DESC
END TRY
BEGIN CATCH
    SELECT	ERROR_NUMBER() AS ErrorNumber,
			ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
