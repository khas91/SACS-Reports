/*
	Author: Stuart Pierson
	ORION program: STSL97J4 SACS Course Delivery Method Report.

	Program produces output files with the following headers.

	File 05:
	Begin Term, End Term, Award Type, POS Code, POS Title, PGM Hrs (reqd for degree), # PGM hrs via DE, % PGM Hrs via DE, # Gen Ed Hrs via DE, % Gen Ed Hrs via DE, # Prof Hrs via DE, % Prof Hrs via DE, FA Apprvd,

	File 04:
	PGM CD, AWD TYPE, PGM TITLE, TRM FROM, TRM TO, CRS ID, HB/DL, 

	File 06:
	PGM CD, AWD TYPE, TRM FROM, TRM TO, AREA, GROUP, CRS ID USED, CRS HRS, TOT PGM HRS, TOT GEN-ED HRS, TOT PROF HRS,     

	The output values for the columns in file 05 requires the compilation of highly confusing and calculations. I am not getting the correct numbers. I'm not really even sure about the basis for inclusion into the list.
	Promising, however, is program 5793 "Paramedic" for which I've arrived at twice the value of # PGM hrs via DE displayed on the report. The fact that it's an integer multiple means I ought to be close.
*/


IF OBJECT_ID ('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp
IF OBJECT_ID ('tempdb..#programs') IS NOT NULL
	DROP TABLE #programs

DECLARE @min_term CHAR(5) = '20103'
DECLARE @max_term CHAR(5) = '20153'
DECLARE @awd_type VARCHAR(6) = 'VC'
DECLARE @pgm VARCHAR(4) = ''

CREATE TABLE #programs
(
	PGM_CD VARCHAR(MAX)
	,AWD_TY VARCHAR(MAX)
)

IF (@awd_type = '')
BEGIN
	INSERT INTO #programs
		SELECT
			prog.PGM_CD
			,prog.AWD_TY
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.PGM_CD = @pgm
			AND prog.END_TRM = ''
END
ELSE IF (@awd_type <> '')
BEGIN
	INSERT INTO #programs
		SELECT
			prog.PGM_CD
			,prog.AWD_TY
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.AWD_TY = @awd_type
			AND prog.END_TRM = ''
END

SELECT
	class.crsId
	,SUM(CASE WHEN class.NON_FF_PERC = 100 THEN 1 ELSE 0 END) AS 'NumOnlineAvailable'
	,AVG(class.CNTCT_HRS) AS 'HRS'
INTO
	#temp
FROM
	MIS.dbo.ST_CLASS_A_151 class
	INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON class.crsId = course.CRS_ID
WHERE
	class.effTrm > @min_term
	AND class.effTrm < @max_term
GROUP BY
	class.crsId


SELECT
	@min_term
	,@max_term
	,p.AWD_TY
	,p.PGM_CD
	,CASE WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL ELSE prog.PGM_TRK_TTL END
	,AVG(prog.PGM_TTL_MIN_CNTCT_HRS_REQD)
	,CASE WHEN SUM(CASE WHEN t.NumOnlineAvailable > 0 THEN t.HRS ELSE 0 END) > AVG(prog.PGM_TTL_MIN_CNTCT_HRS_REQD) THEN AVG(prog.PGM_TTL_MIN_CNTCT_HRS_REQD) ELSE SUM(CASE WHEN t.NumOnlineAvailable > 0 THEN t.HRS ELSE 0 END) END
FROM
	#programs p
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = p.PGM_CD
											AND prog.EFF_TRM_D <> ''
											AND prog.END_TRM = ''
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 progreq ON progreq.PGM_CD_X = p.PGM_CD
	INNER JOIN #temp t ON t.crsId = progreq.CRS_ID_X
GROUP BY
	p.PGM_CD
	,p.AWD_TY
	,prog.PGM_OFFCL_TTL
	,prog.PGM_TRK_TTL
