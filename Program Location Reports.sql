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

	Update 9/6/2016 - learned a lot recently: The output so far differs from the of the ORION program, but we're going to go with mine. It matches the logic used in the degree audit program.
	The following is how to find the course options for a given program:
	SELECT
		PGM_AREA_GROUP_CRS
	FROM
		MIS.dbo.ST_PROGRAMS_A_136 prog
		INNER JOIN MIS.[dbo].[ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136] courses ON courses.[ISN_ST_PROGRAMS_A] = prog.[ISN_ST_PROGRAMS_A]
	WHERE
		prog.EFF_TRM_G <> ''
		AND prog.PGM_CD = <Program_code>

	One final area of contention: I've found out that the TOT PGM HRS, TOT GEN-ED HRS and TOT PROF HRS columns don't come from the data but are instead running totals over program and campus center
	which contain the cumulative sum of hours for the courses offered at that campus center. TOT GEN-ED HRS gets incremented if, for the area type the course is being used for is between 01 and 05
	, TOT PROF HRS is for area types 06+ and TOT PGM HRS is the sum of both. We have to have a discussion about this with Kelsey to see if it's actually needed.

	Update 9/8/2016: We convinced Kelsey that we don't need a cumulative total. The last three column will be just the total for a program/campus center combination. Last thing I need to do is
	to add campus center as a parameter.
*/

USE MIS

IF OBJECT_ID('dbo.sp_Program_Location_Report') IS NOT NULL
	DROP PROCEDURE dbo.sp_Program_Location_Report
GO

CREATE PROCEDURE dbo.sp_Program_Location_Report
	@pgm_cd CHAR(4) = ''
	,@awd_type VARCHAR(4) = 'BAS'
	,@min_term CHAR(5) = '20163'
	,@max_term CHAR(5) = '20163'
AS
BEGIN


	CREATE TABLE #programs
	(
		PGM_CD CHAR(5)
		,AWD_TY VARCHAR(6)
	)

	CREATE TABLE #electives
	(
		CRS_ID VARCHAR(MAX)
		,AWD_TYPE VARCHAR(6)
		,EFF_TRM CHAR(5)
		,END_TRM CHAR(5)
	)

	IF (@pgm_cd <> '')
	BEGIN

	INSERT INTO #programs
		SELECT DISTINCT
			prog.PGM_CD
			,prog.AWD_TY
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.PGM_CD = @pgm_cd
			AND prog.EFF_TRM_D <= @max_term
			AND (prog.END_TRM = '' OR prog.END_TRM >= @min_term)
			AND prog.PGM_CD NOT IN ('S000','T003','S001','5000')

	END
	ELSE IF (@awd_type <> '')
	BEGIN

	INSERT INTO #programs
		SELECT DISTINCT
			prog.PGM_CD
			,prog.AWD_TY
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.AWD_TY = @awd_type
			AND prog.EFF_TRM_D <> ''
			AND prog.EFF_TRM_D <= @max_term
			AND (prog.END_TRM = '' OR prog.END_TRM >= @min_term)
			AND prog.PGM_CD NOT IN ('S000','T003','S001','5000')
	END
	ELSE
	BEGIN

	INSERT INTO #programs
		SELECT DISTINCT
			prog.PGM_CD
			,prog.AWD_TY
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.EFF_TRM_D <= @max_term
			AND (prog.END_TRM = '' OR prog.END_TRM >= @min_term)
			AND prog.AWD_TY NOT IN ('NC','ND','HS')
			AND prog.PGM_CD NOT IN ('S000','T003','S001','5000')

	END


	INSERT INTO #electives
		SELECT
			course.CRS_ID
			,'AA'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AA_ELECTIVE = 'Y'
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))

	INSERT INTO #electives
		SELECT 
			course.CRS_ID
			,'AS'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AS_ELECTIVE = 'Y'
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))

	INSERT INTO #electives
		SELECT 
			course.CRS_ID
			,'AAS'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_AAS_ELECTIVE = 'Y'
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))

	INSERT INTO #electives
		SELECT 
			course.CRS_ID
			,'BAS'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('A', 'D', 'E', 'G')
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))

	INSERT INTO #electives
		SELECT
			course.CRS_ID
			,'BS'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('B', 'D', 'F', 'G')
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))


	INSERT INTO #electives
		SELECT
			course.CRS_ID
			,'BSN'
			,course.EFF_TRM
			,course.END_TRM
		FROM
			MIS.dbo.ST_COURSE_A_150 course
		WHERE
			course.USED_FOR_BAS_ELECTIVE IN ('C', 'E', 'F', 'G')
			AND course.EFF_TRM >= @max_term
			AND (course.END_TRM = '' OR course.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))

	SELECT
		DISTINCT p1.PGM_CD
		,courses.[PGM_AREA_GROUP_CRS]
		,prog.PGM_AREA
		,prog.PGM_AREA_GROUP
		,progarea.PGM_AREA_TYPE
		,prog.EFF_TRM_G
		,progarea.EFF_TRM_A
	INTO
		#programcourserequirements
	FROM
		#programs p1
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON p1.PGM_CD = prog.PGM_CD
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 progarea ON progarea.PGM_CD = prog.PGM_CD
													AND progarea.EFF_TRM_A <> ''
													AND progarea.EFF_TRM_A <= @min_term
													AND prog.EFF_TRM_A = progarea.EFF_TRM_G
		INNER JOIN MIS.[dbo].[ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136] courses ON courses.[ISN_ST_PROGRAMS_A] = prog.[ISN_ST_PROGRAMS_A]
	WHERE
		prog.EFF_TRM_G <> ''
		AND prog.EFF_TRM_G <= @max_term
		AND (prog.END_TRM = '' OR prog.END_TRM >= CAST((CAST(LEFT(@min_term, 4) AS INT) + 5) AS VARCHAR(MAX)) + RIGHT(@min_term, 1))
		AND LEFT(courses.PGM_AREA_GROUP_CRS, 1) <> '+'
		

	SELECT
		 SRC.PGM_CD
		,SRC.AWD_TY
		,SRC.campCntr
		,SRC.min_term
		,SRC.max_term
		,SRC.PGM_AREA
		,SRC.PGM_AREA_GROUP
		,SRC.[PGM_AREA_GROUP_CRS]
		,SRC.EFF_TRM_A
		,SRC.EFF_TRM_G
		,SRC.HRS
		,SRC.PGM_AREA_TYPE
	INTO
		#temp
	FROM (
		SELECT
			ROW_NUMBER() OVER (PARTITION BY p.PGM_CD, procourse.PGM_AREA, procourse.PGM_AREA_GROUP, procourse.PGM_AREA_GROUP_CRS ORDER BY procourse.EFF_TRM_A DESC) AS RN
			,ROW_NUMBER() OVER (PARTITION BY p.PGM_CD, procourse.PGM_AREA_GROUP_CRS ORDER BY procourse.EFF_TRM_A DESC) AS RN2
			,p.PGM_CD
			,p.AWD_TY
			,class.campCntr
			,@min_term AS 'min_term'
			,@max_term AS 'max_term'
			,CAST(procourse.PGM_AREA AS VARCHAR(4)) AS PGM_AREA
			,CAST(procourse.PGM_AREA_GROUP AS VARCHAR(4)) AS PGM_AREA_GROUP
			,procourse.[PGM_AREA_GROUP_CRS]
			,procourse.EFF_TRM_A
			,procourse.EFF_TRM_G
			,CASE
				WHEN p.AWD_TY IN ('VC','ATC','ATD') THEN class.CNTCT_HRS
				ELSE class.EVAL_CRED_HRS
			END AS 'HRS'
			,procourse.PGM_AREA_TYPE
		FROM
			#programs p
			INNER JOIN #programcourserequirements procourse ON procourse.PGM_CD = p.PGM_CD
			INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsID = procourse.PGM_AREA_GROUP_CRS
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = p.PGM_CD
													AND prog.EFF_TRM_D <> ''
													AND prog.END_TRM = ''
		WHERE
			class.efftrm >= @max_term
			AND class.efftrm <= @min_term
			AND procourse.EFF_TRM_A = procourse.EFF_TRM_G
		) SRC
	WHERE
		RN = 1 
		AND RN2 = 1


	INSERT INTO #temp
		SELECT
			p.PGM_CD                  AS PGM_CD
			,p.AWD_TY				  AS AWD_TY
			,class.campCntr			  AS campCntr
			,@min_term				  AS min_term
			,@max_term				  AS max_term
			,'ELEC'             	  AS PGM_AREA
			,''                       AS PGM_AREA_GROUP
			,e.CRS_ID				  AS [PGM_AREA_GROUP_CRS]
			,''						  AS EFF_TRM_A
			,''						  AS EFF_TRM_G
			,class.EVAL_CRED_HRS      AS HRS
			,''                       AS PGM_AREA_TYPE
		FROM
			#programs p
			INNER JOIN #electives e ON e.AWD_TYPE = p.AWD_TY
			INNER JOIN MIS.dbo.ST_CLASS_A_151 class ON class.crsId = e.CRS_ID
		WHERE
			class.effTrm >= @min_term
			AND class.effTrm <= @max_term	

	
	SELECT
		PGM_CD
		,AWD_TY
		,campCntr
		,min_term
		,max_term
		,PGM_AREA
		,PGM_AREA_GROUP
		,PGM_AREA_GROUP_CRS
		,HRS
		,SUM(HRS) OVER (PARTITION BY PGM_CD, campCntr) AS [Total Program Hours]
		,SUM
			(CASE
				WHEN AWD_TY IN ('VC','ATD','ATC') THEN 0
				ELSE 
					CASE
						WHEN LEFT(PGM_AREA_TYPE, 2) < '06' THEN HRS
						ELSE 0
					END
			END) OVER (PARTITION BY PGM_CD, campCntr) AS [Total General Education Hours]
		,SUM
			(CASE
				WHEN AWD_TY IN ('VC','ATD','ATC') THEN HRS
				ELSE 
					CASE
						WHEN LEFT(PGM_AREA_TYPE, 2) >= '06' OR PGM_AREA = 'ELEC' THEN HRS
						ELSE 0
					END
			END) OVER (PARTITION BY PGM_CD, campCntr) AS [Total Core and Professional Hours]
	INTO
		#finalreport
	FROM
		#temp
	ORDER BY 
		PGM_CD

	SELECT
		*
	FROM
		#finalreport

END
GO


/************************************************************
*   Testing
************************************************************/

EXEC dbo.sp_Program_Location_Report

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


SELECT
	*
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 grou ON grou.ISN_ST_PROGRAMS_A = prog.ISN_ST_PROGRAMS_A
WHERE
	prog.EFF_TRM_G <> ''
	AND prog.PGM_CD = '5604'
	AND grou.PGM_AREA_GROUP_CRS = 'ACR0001'
/**/	
SELECT
	DISTINCT TABLE_NAME
FROM
	MIS.dbo.UTL_CODE_TABLE_120

SELECT
	*
FROM
	MIS.dbo.UTL_CODE_TABLE_120 code
WHERE
	code.TABLE_NAME = 'DA-AREATYP'
	AND LEFT(code.CODE, 3) = 'AS '
	AND code.STATUS = 'A'
ORDER BY
	code.ISN_UTL_CODE_TABLE
*/
