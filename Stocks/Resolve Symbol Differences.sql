
SELECT	DISTINCT		
		E_Name
		,S_Symbol
		,F_To_First_Dot
		,F_FileName
FROM	Stage_Kaggle_Stocks
		JOIN
		Files
			ON	SKS_F_FK = F_PK
		JOIN
		Symbols
			ON	F_To_First_Dot = S_Symbol
		JOIN
		Exchanges
			ON	S_E_FK = E_PK
order by 1, 2, 3, 4



SELECT	S_Symbol
		,S_Name
		,E_Name
		,E_Description
FROM	Symbols
		JOIN
		Exchanges
			ON	S_E_FK = E_PK
WHERE	S_Symbol IN	
	(
	select	S_Symbol
			--,count(*)
	from	Symbols
	group by S_Symbol
	having	count(*) > 1
	) 
ORDER BY 1, 2, 3, 4


SELECT * FROM Exchanges



SELECT	SR1.SR_Name
		,SR2.SR_Name
		,E1.E_Name
		,E2.E_Name
		,S1.S_Symbol
		,S2.S_Symbol
		,F1.F_FileName
		,F2.F_FileName
FROM	Symbols S1
		JOIN
		Symbols S2
			ON	S1.S_Symbol = S2.S_Symbol
		JOIN
		Sources SR1
			ON	SR1.SR_PK = SR1.SR_PK
		JOIN
		Sources SR2
			ON	SR2.SR_PK = SR2.SR_PK
		JOIN
		Exchanges E1
			ON	S1.S_E_FK = E1.E_PK
		JOIN
		Exchanges E2
			ON	S2.S_E_FK = E2.E_PK
		JOIN
		Files F1
			ON	S1.S_F_FK = F1.F_PK
		JOIN
		Files F2
			ON	S2.S_F_FK = F2.F_PK
WHERE	S1.S_E_FK = 0   --UNKNOWN
AND		S2.S_E_FK > 0   --DEFINED
ORDER BY 1, 2, 3, 4


