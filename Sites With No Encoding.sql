/*
	Author: Stuart Pierson
	ORION Program: FCR155J1 Sites with no encoding report.

	This program produces an output file with the following header:
	Center Code,Site Name,Term(s),Classes Encoded,  

	where "Classes Encoded" is always 0. 

*/

USE MIS

IF OBJECT_ID(N'dbo.fn_Sites_With_No_Encoding') IS NOT NULL
	DROP FUNCTION dbo.fn_Sites_WIth_No_Encoding;
GO

CREATE FUNCTION dbo.fn_Sites_With_No_Encoding(@min_term CHAR(5), @max_term CHAR(5))
RETURNS @sites TABLE
(
	centercode VARCHAR(MAX)
	,sitename VARCHAR(MAX)
	,terms VARCHAR(MAX)
	,classesencoded INT
)
AS
BEGIN
	;WITH campuscenters as (SELECT
		cntr.CampusCode + cntr.LocationNumber AS 'Center Code'
		,cntr.LocationName
	FROM
		MIS.dbo.vwCampusCenter cntr)

	INSERT INTO @sites
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

		RETURN
END
GO

/************************************************************
*   Testing
************************************************************/

SELECT
	*
FROM
	MIS.dbo.fn_Sites_With_No_Encoding('20112','20162')
ORDER BY
	centercode