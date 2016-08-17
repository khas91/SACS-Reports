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


DECLARE @awd_type VARCHAR(MAX) = 'VC'
DECLARE @pgm_cd VARCHAR(MAX) = ''
DECLARE @min_term CHAR(5) = '20103'
DECLARE @max_term CHAR(5) = '20153'


IF OBJECT_ID('tempdb..#programs') IS NOT NULL
	DROP TABLE #programs
IF OBJECT_ID('tempdb..#programcourserequirements') IS NOT NULL
	DROP TABLE #programcourserequirements

CREATE TABLE #programs
(
	PGM_CD CHAR(4)
	,AWD_TY VARCHAR(MAX)
	,HRS_REQD VARCHAR(MAX)
)


CREATE TABLE #programcourserequirements
(
	PGM_CD CHAR(4)
	,CRS_ID VARCHAR(MAX)
	,HRS VARCHAR(MAX)
	,OfferedOnline VARCHAR(MAX)
)

IF (@pgm_cd <> '')
BEGIN

	INSERT INTO #programs
		SELECT
			prog.PGM_CD
			,prog.AWD_TY
			,prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.PGM_CD = @pgm_cd
			AND prog.EFF_TRM_D <> ''
			AND prog.EFF_TRM_D <= @max_term
			AND prog.AWD_TY = @awd_type
			AND (prog.END_TRM = '' OR prog.END_TRM >= @max_term)
END
ELSE IF (@awd_type <> '')
BEGIN
	
	INSERT INTO #programs
		SELECT
			prog.PGM_CD
			,prog.AWD_TY
			,prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.EFF_TRM_D <= @max_term
			AND prog.AWD_TY = @awd_type
			AND (prog.END_TRM = '' OR prog.END_TRM >= @max_term)

END

INSERT INTO #programcourserequirements
	SELECT
		p.PGM_CD
		,prog.CRS_ID_X
		,MAX((course.MIN_CNTCT_HRS + course.MAX_CNTCT_HRS) / 2.0) AS 'HRS'
		,'' AS 'OfferedOnline'
	FROM
		#programs p
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD_X = p.PGM_CD
		INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON prog.CRS_ID_X = course.CRS_ID
	WHERE
		prog.CRS_ID_X <> ''
	GROUP BY
		p.PGM_CD
		,prog.CRS_ID_X

UPDATE #programcourserequirements
	SET OfferedOnline = (
		SELECT
			CASE
				WHEN SUM(CASE WHEN class.NON_FF_PERC <= 100 AND class.NON_FF_PERC >= 50 THEN 1 ELSE 0 END) > 0 THEN 'Y'
				ELSE 'N'
			END
		FROM
			#programcourserequirements p
			INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsId = p.CRS_ID
		WHERE
			class.effTrm <= @max_term
			AND class.effTrm >= @min_term
			AND class.CLS_STAT <> 'C'
			AND class.crsId = procourse.CRS_ID
		GROUP BY
			p.CRS_ID
	)
	FROM
		#programcourserequirements procourse

SELECT
	@min_term
	,@max_term
	,p1.PGM_CD
	,p2.AWD_TY
	,''
	,MIN(p2.HRS_REQD)
	,CASE
		WHEN SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) > MIN(p2.HRS_REQD) THEN MIN(p2.HRS_REQD)
		ELSE SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END)
	END
	,(SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) / MIN(p2.HRS_REQD)) * 100
FROM
	#programcourserequirements p1
	INNER JOIN #programs p2 ON p2.PGM_CD = p1.PGM_CD
GROUP BY
	p1.PGM_CD
	,p2.AWD_TY
HAVING
	SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) / AVG(CAST(p2.HRS_REQD AS FLOAT)) >= .125
