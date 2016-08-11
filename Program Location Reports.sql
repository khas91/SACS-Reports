/*
	ORION Program: STSL97U5
	The purpose of this program is to collect information regarding the relationship between campus centers and programs of study.
	The original ORION program generated several reports. They had the following headers:

	For the file ending in 06:
	PGM CD, AWD TYPE, CAMP CNTR, TRM FROM, TRM TO, AREA, GROUP, CRS ID USED, CRS HRS, TOT PGM HRS, TOT GEN-ED HRS, TOT PROF HRS

	For the file ending in 05:
	Begin Term, End Term, State, City, Cntr #, Cntr Name, Awd Type, POS Code, POS Title, PGM Hrs (reqd for degree), # PGM hrs at site, % PGM Hrs, # Gen Ed Hrs at site, % Gen Ed Hrs at site, # Prof Hrs at site, % Prof Hrs at site, FA Apprvd,             

	For the file ending in 04:
	PGM CD, AWD TYPE, PGM TITLE, TRM FROM, TRM TO, CRS ID, CAMPUS, EFF TRM

	When I figure out the logic, I will convert this script into a stored procedure which will produce all the aforementioned reports as tables.
*/


IF OBJECT_ID ('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp

DECLARE @pgm_cd CHAR(4) = ''
DECLARE @awd_type VARCHAR(4) = 'VC'
DECLARE @min_term CHAR(5) = '20103'
DECLARE @max_term CHAR(5) = '20153'

CREATE TABLE #temp
(
	PGM_CD CHAR(4)
	,AWD_TY VARCHAR(6)
)

IF (@pgm_cd = '')
BEGIN
	INSERT INTO #temp
	SELECT
		prog.PGM_CD
		,prog.AWD_TY
	FROM
		MIS.dbo.ST_PROGRAMS_A_136 prog
	WHERE
		prog.EFF_TRM_D <> ''
		AND prog.PGM_STATUS = 'A'
		AND prog.END_TRM = ''
		AND prog.AWD_TY = @awd_type
END
ELSE
BEGIN
	INSERT INTO #temp
	SELECT TOP 1
		@pgm_cd AS 'PGM_CD'
		,prog.AWD_TY
	FROM
		MIS.dbo.ST_PROGRAMS_A_136 prog
	WHERE
		prog.PGM_CD = @pgm_cd
		AND prog.EFF_TRM_D <> ''
		AND prog.PGM_STATUS = 'A'
		AND prog.END_TRM = ''
	ORDER BY
		prog.EFF_TRM_D DESC
END


SELECT
	t.PGM_CD
	,t.AWD_TY
	,class.campCntr
	,@min_term
	,@max_term
	,''
	,''
	,prog.CRS_ID_X
	,MAX(class.CNTCT_HRS)
	,MAX(prog.PGM_TTL_MIN_CNTCT_HRS_REQD)
	,MAX(prog.PGM_TTL_GE_HRS_REQD)
FROM
	#temp t
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON t.PGM_CD = prog.PGM_CD_X
	INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsId = prog.CRS_ID_X
											AND class.effTrm >= @min_term
											AND class.effTrm <= @max_term
	INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON course.CRS_ID = class.crsId
											AND course.EFF_TRM >= class.effTrm
											AND course.END_TRM <= class.effTrm
--WHERE
--	prog.AUDIT_AVAIL_FLG = 'Y' /* This is the NATURAL code, but when I include it I get no results */
GROUP BY
	t.PGM_CD
	,t.AWD_TY
	,class.campCntr
	,prog.CRS_ID_X
	,class.effTrm
ORDER BY
	t.PGM_CD

/************************************************************
*   Testing
************************************************************/

/*
SELECT
	*
FROM
	MIS.dbo.ST_CLASS_A_151 class
WHERE
	class.crsId = 'CJK0096'
	AND class.effTrm >= '20103'
	AND class.effTrm <= '20153'
	AND class.campCntr = 'B0200'
GROUP BY
	class.crsId

SELECT
	*
FROM
	MIS.dbo.ST_COURSE_A_150 course
WHERE
	course.CRS_ID = 'CJK0096'

SELECT
	PGM_TTL_MIN_CNTCT_HRS_REQD
	,*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE 
	prog.PGM_CD = '5776'



SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136
WHERE
	ISN_ST_PROGRAMS_A IN (SELECT
	ISN_ST_PROGRAMS_A
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE
	prog.PGM_CD = '5100'
)
ORDER BY
	ISN_ST_PROGRAMS_A

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_AND_OR_136 courseandor ON prog.ISN_ST_PROGRAMS_A = courseandor.ISN_ST_PROGRAMS_A
WHERE
	prog.PGM_CD_X = '5679'
	AND prog.CRS_ID_X = 'PMT0106'
	AND prog.EFF_TRM_G = '20151'
	
*/
