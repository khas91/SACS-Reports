/*
	Author: Stuart Pierson
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

	Note 8/12/2016 - Problems: Logic for "Area" and "Group" unknown. Are these values related to the course or the program? Amy is contacting IT for more information.
	Total Program Hours and Total Professor Hours seem relatively self-explanatory but they appear to be encoded in an inconsistent manner in ORION.
	All other columns seem fine. Still need to figure out how hours for electives are added to this. Here's my preliminary sense of it: Add a row for each BAS, AA, AS and AAS 
	program for each course which could be used as an elective for any of those programs. This is probably correct, but I'll need to obtain sample output to check it once
	it's implemented.

	Also, once 06 is finished, the others should be relatively easy to derive from the existing information. 01, 02 and 03 are summary reports or error reports and thus do not
	need to be implemented here.
*/


IF OBJECT_ID ('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp
IF OBJECT_ID ('tempdb..#electives') IS NOT NULL
	DROP TABLE #electives
IF OBJECT_ID ('tempdb..#coursesforcampuscenter') IS NOT NULL
	DROP TABLE #coursesforcampuscenter
IF OBJECT_ID ('tempdb..#distinctcoursesforcamuscenter') IS NOT NULL
	DROP TABLE #distinctcoursesforcamuscenter
IF OBJECT_ID ('tempdb..#finalreport') IS NOT NULL
	DROP TABLE #finalreport


DECLARE @pgm_cd CHAR(4) = ''
DECLARE @awd_type VARCHAR(4) = 'BAS'
DECLARE @min_term CHAR(5) = '20103'
DECLARE @max_term CHAR(5) = '20153'

CREATE TABLE #temp
(
	PGM_CD CHAR(4)
	,AWD_TY VARCHAR(6)
)

CREATE TABLE #electives
(
	CRS_ID VARCHAR(MAX)
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

IF (@awd_type = 'AA')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AA_ELECTIVE = 'Y'
			AND END_TRM = ''
END
ELSE IF (@awd_type = 'AS')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AS_ELECTIVE = 'Y'
			AND END_TRM = ''
END
ELSE IF (@awd_type = 'AAS')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AAS_ELECTIVE = 'Y'
			AND END_TRM = ''
END
ELSE IF (@awd_type = 'BAS')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('A', 'D', 'E', 'G')
			AND END_TRM = ''
END
ELSE IF (@awd_type = 'BS')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('B', 'D', 'F', 'G')
			AND END_TRM = ''
END
ELSE IF (@awd_type = 'BSN')
BEGIN
	INSERT INTO #electives
		SELECT DISTINCT
			course.CRS_ID
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('C', 'E', 'F', 'G')
			AND END_TRM = ''
END


SELECT
	t.PGM_CD
	,t.AWD_TY
	,class.campCntr
	,prog.CRS_ID_X AS 'CRS ID USED'
INTO
	#coursesforcampuscenter
FROM
	#temp t
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON t.PGM_CD = prog.PGM_CD_X
	INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsId = prog.CRS_ID_X
											AND class.effTrm >= @min_term
											AND class.effTrm <= @max_term
											AND class.CLS_STAT <> 'C'
											AND (class.FF_PERC = '100' OR (class.NON_FF_PERC >= '0' AND class.NON_FF_PERC <= '49'))
	INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON (course.CRS_ID = class.crsId
											AND course.EFF_TRM >= class.effTrm
											AND course.END_TRM <= class.effTrm)
WHERE 
	LEFT(LTRIM(prog.CRS_ID_X), 1) <> '+'
--	prog.AUDIT_AVAIL_FLG = 'Y' /* This is the original NATURAL code, but when I include it I get no results */
GROUP BY
	t.PGM_CD
	,t.AWD_TY
	,class.campCntr
	,prog.CRS_ID_X
	,class.effTrm

INSERT INTO #coursesforcampuscenter
	SELECT 
		t.PGM_CD
		,t.AWD_TY
		,class.campCntr
		,prog.CRS_ID_X AS 'CRS ID USED'
	FROM
		#temp t
		INNER JOIN #electives e ON 1=1
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON t.PGM_CD = prog.PGM_CD_X
		INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON course.CRS_ID = e.CRS_ID
												AND course.EFF_TRM >= @min_term
												AND course.END_TRM <= @max_term
		INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsId = e.CRS_ID
												AND class.effTrm <= course.END_TRM
												AND class.effTrm >= course.EFF_TRM
												AND class.CLS_STAT <> 'C'
												AND (class.FF_PERC = '100' OR (class.NON_FF_PERC >= '0' AND class.NON_FF_PERC <= '49'))
	WHERE 
		LEFT(LTRIM(prog.CRS_ID_X), 1) <> '+'
	GROUP BY
		t.PGM_CD
		,t.AWD_TY
		,class.campCntr
		,prog.CRS_ID_X
		,class.effTrm

DROP TABLE #electives;
DROP TABLE #temp;

SELECT
	DISTINCT *
INTO 
	#distinctcoursesforcamuscenter
FROM
	#coursesforcampuscenter

DROP TABLE #coursesforcampuscenter;

SELECT DISTINCT
	x.PGM_CD
	,x.AWD_TY
	,x.campCntr
	,@min_term AS 'TRM FROM'
	,@max_term AS 'TRM TO'
	,'' AS 'AREA'
	,'' AS 'GROUP'
	,x.[CRS ID USED]
	,'' AS 'CRS HRS'
	,'' AS 'TOT PGM HRS'
	,'' AS 'TOT GEN-ED HRS'
	,'' AS 'TOT PROF HRS'
INTO
	#finalreport
FROM
	#distinctcoursesforcamuscenter x
	INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON x.[CRS ID USED] = class.crsId
											AND class.campCntr = x.campCntr
											AND class.effTrm >= @min_term
											AND class.effTrm <= @max_term
			
DROP TABLE #distinctcoursesforcamuscenter

SELECT
	*
FROM
	#finalreport

/************************************************************
*   Testing
************************************************************/

/*
SELECT
	*
FROM
	MIS.dbo.ST_CLASS_A_151 class
WHERE
	class.crsId = 'MAP2302'
	AND class.effTrm >= '20103'
	AND class.effTrm <= '20153'
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
