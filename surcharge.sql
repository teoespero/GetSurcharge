
SELECT 
	--MAST.cust_no,
	--MAST.cust_sequence,
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) as AccountNum,
	LOT.no_of_units,
	LOT.lot_no,
	LOT.lot_status,
	lot.misc_5 AS Subdivision,
	LOT.misc_14 AS Category,
	LOT.misc_16 AS Irrigation,
	RTRIM(LTRIM(LOT.street_number))+' '+RTRIM(LTRIM(LOT.street_name)) AS [Address],
	CONVERT(varchar(10),MIN(MAST.connect_date),101) AS First_Conn_Date
	INTO #BASEWATER1
	--INTO #BASESEWER
FROM ub_master MAST
INNER JOIN
	lot
	ON MAST.lot_no=LOT.lot_no
	AND replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) IN (
		SELECT 
			DISTINCT
			replicate('0', 6 - len(cust_no)) + cast (cust_no as varchar)+ '-'+replicate('0', 3 - len(cust_sequence)) + cast (cust_sequence as varchar)
		FROM ub_bill_detail BILLD
		WHERE
			--service_code IN ('SC30','SC31')
			service_code IN ('WC30','WC31')
	)
	--AND replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) ='014754-000'
	--AND RTRIM(LTRIM(LOT.street_number))+' '+RTRIM(LTRIM(LOT.street_name)) LIKE '%17500 Reynolds Street #111%'
GROUP BY
	MAST.cust_no,
	MAST.cust_sequence,
	LOT.no_of_units,
	LOT.lot_no,
	lot.misc_5,
	LOT.misc_14,
	LOT.misc_16,
	LOT.lot_status,
	RTRIM(LTRIM(LOT.street_number))+' '+RTRIM(LTRIM(LOT.street_name))
ORDER BY
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) ASC

SELECT 
	ACCOUNTNUM,
	SUM(NO_OF_UNITS) AS EDU,
	[ADDRESS] AS LOT_ADDRESS,
	lot_no AS LOTNO
	INTO #BASEWATER2
FROM #BASEWATER1
GROUP BY
	[AccountNum],
	[ADDRESS],
	lot_no 
ORDER BY
	[ADDRESS] ASC


SELECT 
	ACCOUNTNUM,
	B2.LOT_ADDRESS,
	B2.EDU,
	B2.LOTNO,
	(SELECT TOP 1 MIN(First_Conn_Date) FROM #BASEWATER1 WHERE [ADDRESS]=B2.LOT_ADDRESS AND lot_no=B2.LOTNO) AS CONNDATE
	INTO #BASEWATER3
FROM #BASEWATER2 B2
ORDER BY
	B2.LOT_ADDRESS ASC


SELECT 
	(SELECT TOP 1 Subdivision FROM #BASEWATER1 WHERE [ADDRESS]=B3.LOT_ADDRESS) AS SUBDIVISION,
	(SELECT TOP 1 Category FROM #BASEWATER1 WHERE [ADDRESS]=B3.LOT_ADDRESS) AS CATEGORY,
	ACCOUNTNUM,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE
	INTO #BASEWATER4
FROM #BASEWATER3 B3

SELECT 
	SUBDIVISION,
	CATEGORY,
	ACCOUNTNUM,
	LOT_ADDRESS,
	LOTNO,
	(
	CASE
		WHEN CATEGORY= 'Single Family' THEN 1
		ELSE EDU
	END
	) AS EDU,
	CONNDATE
	INTO #BASEWATER5
FROM #BASEWATER4

SELECT 
	SUBDIVISION,
	CATEGORY,
	ACCOUNTNUM,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	(
	CASE
		WHEN CAST(CONNDATE AS DATE) BETWEEN '7/1/2005' AND '8/12/2010' THEN CAST(2800.00*EDU AS money)
		WHEN CAST(CONNDATE AS DATE)  >= '8/13/2010' THEN CAST(5750.00*EDU AS money)
		--WHEN CAST(CONNDATE AS DATE) BETWEEN '7/1/2005' AND '8/12/2010' THEN CAST(1000.00*EDU AS money)
		--WHEN CAST(CONNDATE AS DATE)  >= '8/13/2010' THEN CAST(2150.00*EDU AS money)
	END
	) AS TOTALDUE
	INTO #BASEWATER6
FROM #BASEWATER5


SELECT 
	B6.SUBDIVISION,
	B6.CATEGORY,
	B6.ACCOUNTNUM,
	B6.LOT_ADDRESS,
	B6.LOTNO,
	B6.EDU,
	B6.CONNDATE,
	B6.TOTALDUE,
	--(
	--select 
	--	sum(amount)
	--from ub_bill_detail
	--where
	--	replicate('0', 6 - len(cust_no)) + cast (cust_no as varchar)+ '-'+replicate('0', 3 - len(cust_sequence)) + cast (cust_sequence as varchar)=B6.ACCOUNTNUM
	--	AND service_code in ('wc30','wc31')
	--	--and tran_type in ('billing','ADJUSTMENT')
	--	and code='flat'
	--	--and ltrim([description])='Cap S/Chg'
	--	and tran_date between '07/01/2005' and '6/30/2020'
	--) AS TOTALBILLED
	SUM(BILL.AMOUNT) AS TOTALBILLED
	INTO #BASEWATER7
FROM #BASEWATER6 B6
INNER JOIN
	ub_bill_detail BILL
	ON replicate('0', 6 - len(cust_no)) + cast (cust_no as varchar)+ '-'+replicate('0', 3 - len(cust_sequence)) + cast (cust_sequence as varchar)=B6.ACCOUNTNUM
	AND BILL.service_code IN ('WC30','WC31')
	--AND BILL.service_code IN ('SC30','SC31')
	AND BILL.code='FLAT'
	AND BILL.tran_date between '07/01/2005' and '6/30/2020'
GROUP BY
	B6.SUBDIVISION,
	B6.CATEGORY,
	B6.ACCOUNTNUM,
	B6.LOT_ADDRESS,
	B6.LOTNO,
	B6.EDU,
	B6.CONNDATE,
	B6.TOTALDUE
ORDER BY	
	B6.LOT_ADDRESS

SELECT 
	SUBDIVISION,
	CATEGORY,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	TOTALDUE,
	SUM(TOTALBILLED) AS TOTALBILLED
	--(SUM(TOTALBILLED)-TOTALBILLED) AS BALANCE
	INTO #BASEWATER8
FROM #BASEWATER7
GROUP BY
	SUBDIVISION,
	CATEGORY,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	TOTALDUE
ORDER BY
	LOT_ADDRESS ASC

SELECT 
	SUBDIVISION,
	CATEGORY,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	TOTALDUE,
	TOTALBILLED,
	(TOTALDUE-TOTALBILLED) AS BALANCE
	INTO #BASEWATER9
FROM #BASEWATER8
ORDER BY 
	LOT_ADDRESS ASC

SELECT 
	SUBDIVISION,
	CATEGORY,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	TOTALDUE,
	TOTALBILLED,
	BALANCE,
	(
		CASE	
			WHEN EDU = 0 THEN 0
			ELSE (BALANCE/(20*EDU)) 
			--ELSE (BALANCE/(5*EDU))
		END
	)AS MONTHSREMAINING
	--MONTHSREMAINING,
	--MONTHSREMAINING/12 AS YEARSREMAINING
	INTO #BASEWATER10
FROM #BASEWATER9

SELECT 
	SUBDIVISION,
	CATEGORY,
	LOT_ADDRESS,
	LOTNO,
	EDU,
	CONNDATE,
	TOTALDUE,
	TOTALBILLED,
	BALANCE,
	MONTHSREMAINING,
	MONTHSREMAINING/12 AS YEARSREMAINING
FROM #BASEWATER10




DROP TABLE #BASEWATER1
DROP TABLE #BASEWATER2
DROP TABLE #BASEWATER3
DROP TABLE #BASEWATER4
DROP TABLE #BASEWATER5
DROP TABLE #BASEWATER6
DROP TABLE #BASEWATER7
DROP TABLE #BASEWATER8
DROP TABLE #BASEWATER9
DROP TABLE #BASEWATER10


--select 
--	sum(amount)
--from ub_bill_detail
--where
--	cust_no=14754
--	and cust_sequence=0
--	and service_code in ('wc30','wc31')
--	and tran_type in ('billing')
--	and code='flat'
--	and ltrim([description])='Cap S/Chg'
--	and tran_date between '07/01/2005' and '06/30/2020'