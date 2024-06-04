
select	format(count(*), 'n0')
from	Daily_Activity



SELECT	ISNULL(S_Name, S_Symbol) Company
		,MIN(DA_Date) fdate
		,MAX(DA_Date) ldate
		,MIN(DA_Low) [low]
		,MAX(DA_High) [high]
		,SUM(DA_Volume) volume
FROM	Daily_Activity
		JOIN
		Symbols
			ON	DA_S_FK = S_PK
GROUP BY ISNULL(S_Name, S_Symbol) 


SELECT	E_Name
		,SR_Name
		,S_Name
		,DA_Date
		,DA_Open
		,DA_Close
		,DA_High
		,DA_Low
		,DA_Volume
FROM	Daily_Activity
		JOIN
		Symbols
			ON	DA_S_FK = S_PK
		join
		Sources
			ON	DA_SR_FK = SR_PK
		JOIN
		Exchanges
			ON	S_E_FK = E_PK
WHERE	S_Name = 'Tesla Inc'
ORDER BY DA_Date


SELECT	*
FROM	Symbols
		JOIN
		Stage_EOD_Manual_Symbols
			ON	S_Symbol = SEMS_Symbol
		JOIN



UPDATE	Symbols
SET		S_SR_FK = SEMS_SR_FK
FROM	Symbols
		JOIN
		Stage_EOD_Manual_Symbols
			ON	S_Symbol = SEMS_Symbol
WHERE	S_SR_FK IS NULL



SELECT	*
FROM	Symbols
WHERE	S_SR_FK IS NULL
