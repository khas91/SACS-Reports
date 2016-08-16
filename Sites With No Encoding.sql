DECLARE @min_term CHAR(5) = '20112'
DECLARE @max_term CHAR(5) = '20162'

;WITH campuscenters as (SELECT
	cntr.CampusCode + cntr.LocationNumber AS 'Center Code'
	,cntr.LocationName
FROM
	MIS.dbo.vwCampusCenter cntr)
SELECT
	center.[Center Code]
	,center.LocationName AS 'Site Name'
	,@min_term + '-' + @max_term AS 'Term(s)'
	,SUM(CASE WHEN class.ISN_ST_CLASS_A IS NOT NULL THEN 1 ELSE 0 END) AS 'Classes Encoded'
FROM
	campuscenters center
	LEFT JOIN MIS.dbo.ST_CLASS_A_151 class ON center.[Center Code] = class.campCntr
											AND class.effTrm >= @min_term
											AND class.effTrm <= @max_term
GROUP BY
	center.[Center Code], center.LocationName
HAVING
	SUM(CASE WHEN class.ISN_ST_CLASS_A IS NOT NULL THEN 1 ELSE 0 END) = 0
ORDER BY
	center.[Center Code]