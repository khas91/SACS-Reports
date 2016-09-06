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

	Update 8/17/2016: Nearly complete, at least until I have to worry about gen-ed and prof hours. I've managed to adjust the filters to where everything showing up on the ORION output is displaying here,
	with the correct values for PGM Hrs, # PGM hrs via DE and % PGM Hrs via DE. # Gen Ed Hrs via DE and % Gen Ed Hrs via DE will doubtlessly depend on calculating which electives to apply to each program.
	Also, right now the script is compiling all the programs for which at least 12.5% of the program hours can be completed online. This is what the original ORION program does when 'D' is passed as the parameter
	for delivery method, but if 'T' (Traditional) is passed for Delivery Method instead, then it should pull in programs for which this is not the case. I'll probably accomplish this with an If-Else.

	Update 8/31/2016: Kelsey gave me some input. Apparently, she's not interested in separating out the traditional programs and the distance learning ones. Give the output with all programs and give the percentages and let
	the consumer decide which ones they're interested in. Also, about to set up logic to retreive all award types and programs if both are blank.

	The degree audit logic is Hopelessly, inconceivably complex. I need to set down what I've figured out about it and here seems to be just about as good a place as any.
	The MIS.dbo.ST_PROGRAMS_A_136 table is definitely the most over-used multi-use file in the database. It contains demographic information in rows where EFF_TRM_D is not
*/

USE MIS

IF OBJECT_ID('dbo.sp_Course_Delievery_Method') IS NOT NULL
	DROP PROCEDURE dbo.sp_Course_Delievery_Method
GO

CREATE PROCEDURE dbo.sp_Course_Delievery_Method
	@awd_type VARCHAR(MAX) = 'VC'
	,@pgm_cd VARCHAR(MAX) = ''
	,@min_term CHAR(5) = '20103'
	,@max_term CHAR(5) = '20153'
AS
BEGIN

IF OBJECT_ID('tempdb..#programs') IS NOT NULL
	DROP TABLE #programs
IF OBJECT_ID('tempdb..#programcourserequirements') IS NOT NULL
	DROP TABLE #programcourserequirements

	CREATE TABLE #programs
	(
		PGM_CD VARCHAR(MAX)
		,PGM_NAME VARCHAR(MAX)
		,AWD_TY VARCHAR(MAX)
		,HRS_REQD VARCHAR(MAX)
		,GE_HRS_REQD VARCHAR(MAX)
	)

	CREATE TABLE #programcourserequirements
	(
		PGM_CD VARCHAR(MAX)
		,CRS_ID VARCHAR(MAX)
		,HRS VARCHAR(MAX)
		,OfferedOnline VARCHAR(MAX)
	)

	IF (@pgm_cd <> '')
	BEGIN

		INSERT INTO #programs
			SELECT
				prog.PGM_CD
				,CASE WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL ELSE prog.PGM_TRK_TTL END
				,prog.AWD_TY
				,CASE
					WHEN prog.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD
					ELSE prog.PGM_TTL_CRD_HRS
				END
				,prog.PGM_TTL_GE_HRS_REQD
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
				,CASE WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL ELSE prog.PGM_TRK_TTL END
				,prog.AWD_TY
				,CASE
					WHEN prog.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD
					ELSE prog.PGM_TTL_CRD_HRS
				END
				,prog.PGM_TTL_GE_HRS_REQD
			FROM
				MIS.dbo.ST_PROGRAMS_A_136 prog
			WHERE
				prog.EFF_TRM_D <> ''
				AND prog.EFF_TRM_D <= @max_term
				AND prog.AWD_TY = @awd_type
				AND (prog.END_TRM = '' OR prog.END_TRM >= @max_term)

	END
	ELSE
	BEGIN

		INSERT INTO #programs
			SELECT
				prog.PGM_CD
				,CASE WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL ELSE prog.PGM_TRK_TTL END
				,prog.AWD_TY
				,CASE
					WHEN prog.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD
					ELSE prog.PGM_TTL_CRD_HRS
				END
				,prog.PGM_TTL_GE_HRS_REQD
			FROM
				MIS.dbo.ST_PROGRAMS_A_136 prog
			WHERE
				prog.EFF_TRM_D <> ''
				AND prog.EFF_TRM_D <= @max_term
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
		,p2.PGM_NAME
		,MIN(p2.HRS_REQD)
		,CASE
			WHEN SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) > MIN(p2.HRS_REQD) THEN MIN(p2.HRS_REQD)
			ELSE SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END)
		END
		,CASE
			WHEN CAST(MIN(p2.HRS_REQD) AS FLOAT) = 0.00 THEN 100
			WHEN (SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) / MIN(p2.HRS_REQD)) * 100 > 100 THEN 100
			ELSE (SUM(CASE WHEN p1.OfferedOnline = 'Y' THEN CAST(p1.HRS AS FLOAT) ELSE 0.0 END) / MIN(p2.HRS_REQD)) * 100
		END
	FROM
		#programcourserequirements p1
		INNER JOIN #programs p2 ON p2.PGM_CD = p1.PGM_CD
	GROUP BY
		p1.PGM_CD
		,p2.PGM_NAME
		,p2.AWD_TY
	ORDER BY
		p1.PGM_CD
	

END
GO

EXEC dbo.sp_Course_Delievery_Method @awd_type = '', @pgm_cd = '',@min_term = '20103', @max_term = '20153'

/***********************************************************
*                     Testing                              *
************************************************************/

SELECT
	prog.CODE
	,prog.DESCRIPTION
	,prog.ISN_ST_PROGRAMS_A
	,prog.PGM_AREA
	,prog.PGM_AREA_GROUP
	,prog.PGM_AREA_MIN_CRED_HRS
	,prog.PGM_AREA_MIN_CRS
FROM
	(SELECT
		code.CODE,code.DESCRIPTION
		,prog.ISN_ST_PROGRAMS_A
		,prog.PGM_AREA
		,prog.PGM_AREA_GROUP
		,prog.PGM_AREA_MIN_CRED_HRS
		,prog.PGM_AREA_MIN_CRS
		,ROW_NUMBER() OVER (PARTITION BY code.CODE ORDER BY EFF_TRM_A DESC) RN
	FROM
		MIS.dbo.ST_PROGRAMS_A_136 prog
		LEFT JOIN MIS.dbo.UTL_CODE_TABLE_120 code ON RIGHT(code.CODE, 3) = prog.PGM_AREA_TYPE
													AND LEFT(code.CODE, 3) = 'AS '
	WHERE
		 EFF_TRM_A <> ''
		 AND prog.PGM_CD = '2254'
		 AND code.STATUS = 'A'
		 AND code.TABLE_NAME = 'DA-AREATYP') PROG
WHERE 
	RN = 1
ORDER BY
	PGM_AREA

SELECT
	*
FROM
	MIS.dbo.UTL_CODE_TABLE_120 code
WHERE
	code.TABLE_NAME = 'DA-AREATYP'
	AND LEFT(code.CODE, 3) = 'BAS'
	AND STATUS = 'A'
ORDER BY
	code.ISN_UTL_CODE_TABLE


SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE
	prog.ISN_ST_PROGRAMS_A IN(
SELECT
	ISN_ST_PROGRAMS_A
FROM
	MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136
WHERE
	ISN_ST_PROGRAMS_A IN
	(
	SELECT
		prog.ISN_ST_PROGRAMS_A
	FROM
		MIS.dbo.ST_PROGRAMS_A_136 prog
	WHERE
		prog.PGM_CD = '1108'))

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE
	prog.PGM_CD = '2125'
	AND prog.EFF_TRM_A <> ''
	AND prog.PGM_AREA_TYPE = '06A'
	

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE
	prog.PGM_CD = '2125'
	AND prog.EFF_TRM_G <> ''
	AND prog.PGM_AREA = 6
ORDER BY
	EFF_TRM_G ASC

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 gro
WHERE
	gro.ISN_ST_PROGRAMS_A = '1441613'


SELECT
	DISTINCT groupcrs.PGM_AREA_GROUP_CRS
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 progroup ON progroup.PGM_CD = prog.PGM_CD
												AND progroup.EFF_TRM_G <> ''
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 groupcrs ON groupcrs.ISN_ST_PROGRAMS_A = progroup.ISN_ST_PROGRAMS_A
WHERE
	prog.PGM_CD = '2127'
	AND prog.EFF_TRM_A <> ''
	AND LEFT(prog.PGM_AREA_TYPE, 2) IN ('01','02','03','04','05')
ORDER BY
	groupcrs.PGM_AREA_GROUP_CRS

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
WHERE
	prog.PGM_CD = '2258'
	AND prog.EFF_TRM_G <> ''
	AND prog.PGM_AREA = 5
ORDER BY
	EFF_TRM_G DESC

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 prog
WHERE
	prog.ISN_ST_PROGRAMS_A = '1354286'

SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_AND_OR_136 prog
WHERE
	prog.ISN_ST_PROGRAMS_A = '14'
ORDER BY
	ISN_ST_PROGRAMS_A