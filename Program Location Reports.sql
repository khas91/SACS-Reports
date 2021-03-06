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

	Update 9/8/2016: We convinced Kelsey that we don't need a cumulative total. The last three columns will be just the total for a program/campus center combination. Last thing I need to do is
	to add campus center as a parameter.

	Update 9/9/2016: You'll notice if you're following this on source control that the code looks vastly different. The only major functional change is that I've added another parameter.
	Now you can use @highschool to specify whether you want only high school results (value of 'H'), no high school results ('O') or both (leave the parameter blank).
	There's really no way of knowing whether a campus center in ORION is a high school or not, so I've created the #highschools temp table, into which I've inserted all high schools.
	It's hard coded, but the list I'm using comes straight from Kelsey. This paremeter is not present in the original ORION program. It is an enhancement.

	The non-functional changes should make it all simpler and, hopefully, more correct. Getting the correct values for PGM_AREA and PGM_AREA_GROUP without having duplicates in the results
	was not possible without this refactor.

	Update 9/14/2016: I've decided to not have this be a stored procedure. This was necessary in order to generate the difference report, and it wasn't really serving a purpose anyway.
	I've given the output to Kelsey, and she's satisfied. One more thing, though: I need a difference report for the other sites report.
*/

IF OBJECT_ID('tempdb..#electives') IS NOT NULL
	DROP TABLE #electives
IF OBJECT_ID('tempdb..#highschools') IS NOT NULL
	DROP TABLE #highschools
IF OBJECT_ID('tempdb..#programs') IS NOT NULL
	DROP TABLE #programs
IF OBJECT_ID('tempdb..#catalogchanges') IS NOT NULL
	DROP TABLE #catalogchanges
IF OBJECT_ID('tempdb..#distinctcoursesforprograms') IS NOT NULL
	DROP TABLE #distinctcoursesforprograms
IF OBJECT_ID('tempdb..#coursegroupareadictionary') IS NOT NULL
	DROP TABLE #coursegroupareadictionary
IF OBJECT_ID('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp
IF OBJECT_ID('tempdb..#interimreport') IS NOT NULL
	DROP TABLE #interimreport
IF OBJECT_ID('tempdb..#finalreport') IS NOT NULL
	DROP TABLE #finalreport
IF OBJECT_ID('tempdb..#highschoolreport') IS NOT NULL
	DROP TABLE #highschoolreport
IF OBJECT_ID('tempdb..#othersitesreport') IS NOT NULL
	DROP TABLE #othersitesreport
IF OBJECT_ID('tempdb..#highschoolinterimreport') IS NOT NULL
	DROP TABLE #highschoolinterimreport
IF OBJECT_ID('tempdb..#othersitesinterimreport') IS NOT NULL
	DROP TABLE #othersitesinterimreport
IF OBJECT_ID('tempdb..#highschoolfinalreport') IS NOT NULL
	DROP TABLE #highschoolfinalreport
IF OBJECT_ID('tempdb..#highschooldiffreport') IS NOT NULL
	DROP TABLE #highschooldiffreport


DECLARE @pgm_cd CHAR(4) = ''
DECLARE @awd_type VARCHAR(4) = ''
DECLARE @min_term CHAR(5) = '20141'
DECLARE @max_term CHAR(5) = '20172'
DECLARE @campcntr VARCHAR(10) = ''
DECLARE @highschool CHAR(1) = ''

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

CREATE TABLE #highschools
(
	campCntr VARCHAR(MAX)
)

INSERT INTO #highschools VALUES
('D1427')
,('C1411')
,('A1618')
,('D1401')
,('C1634')
,('C1414')
,('A1103')
,('B1403')
,('A1104')
,('A1105')
,('D1103')
,('B1408')
,('A1110')
,('A1111')
,('A1112')
,('Z7000')
,('A1303')
,('A1116')
,('A1301')
,('A1117')
,('Z7004')
,('A1118')
,('B1613')
,('A1119')
,('A1114')
,('Z7015')
,('Z7002')
,('B1410')
,('F1410')
,('A1106')
,('A1122')
,('B1414')


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
/*
--I've convinced myself that all the courses marked as electives for AS, AAS, BAS, BS, or BSN are also
--in the degree audit for the individual programs, hence adding them here would result in duplicates.
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
*/
SELECT
	DISTINCT 
	prog.PGM_CD
	,EFF_TRM_D
	,CASE 
		WHEN END_TRM = '' THEN END_TRM
		ELSE CAST(CAST(LEFT(END_TRM, 4) AS INT) + 5 AS VARCHAR(MAX)) + RIGHT(END_TRM, 1) 
	END AS END_TRM
INTO
	#catalogchanges
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
	INNER JOIN #programs p ON p.PGM_CD = prog.PGM_CD
WHERE
	EFF_TRM_D <> ''
	AND EFF_TRM_D <= @max_term
	AND (END_TRM = '' OR CAST(CAST(LEFT(END_TRM, 4) AS INT) + 5 AS VARCHAR(MAX)) + RIGHT(END_TRM, 1) >= @min_term)
		
SELECT
	DISTINCT 
		prog.PGM_CD
		,p.AWD_TY
		,PGM_AREA_GROUP_CRS AS CRS_ID
		,c.EFF_TRM_D
		,c.END_TRM
INTO
	#distinctcoursesforprograms
FROM
	MIS.dbo.ST_PROGRAMS_A_136 prog
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 procourse ON procourse.ISN_ST_PROGRAMS_A = prog.ISN_ST_PROGRAMS_A
	INNER JOIN #programs p ON p.PGM_CD = prog.PGM_CD
	INNER JOIN #catalogchanges c ON c.PGM_CD = prog.PGM_CD
								AND prog.EFF_TRM_G = c.EFF_TRM_D
WHERE
	prog.EFF_TRM_G <> ''
	AND LEFT(procourse.PGM_AREA_GROUP_CRS, 1) <> '+'
	AND RIGHT(procourse.PGM_AREA_GROUP_CRS, 1) <> '*'
	AND prog.EFF_TRM_G <= @min_term

SELECT
	*
INTO
	#coursegroupareadictionary
FROM
	(
	SELECT
		ROW_NUMBER() OVER (PARTITION BY dist.PGM_CD, dist.CRS_ID ORDER BY dist.EFF_TRM_D DESC) RN
		,dist.PGM_CD
		,dist.CRS_ID
		,progarea.PGM_AREA
		,progarea.PGM_AREA_TYPE
		,proggroup.PGM_AREA_GROUP
		,dist.EFF_TRM_D
	FROM
		#distinctcoursesforprograms dist
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 progarea ON progarea.PGM_CD = dist.PGM_CD
												AND progarea.EFF_TRM_A = dist.EFF_TRM_D
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 proggroup ON proggroup.PGM_CD = dist.PGM_CD
													AND proggroup.EFF_TRM_G = dist.EFF_TRM_D
													AND proggroup.PGM_AREA = progarea.PGM_AREA
		INNER JOIN MIS.[dbo].[ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136] groupcourse ON groupcourse.ISN_ST_PROGRAMS_A = proggroup.ISN_ST_PROGRAMS_A
																				AND groupcourse.PGM_AREA_GROUP_CRS = dist.CRS_ID) SRC
WHERE
	RN = 1

SELECT
	DISTINCT
		d.PGM_CD
		,d.AWD_TY
		,class.campCntr
		,class.crsId
		,CASE
			WHEN d.AWD_TY = 'VC' THEN class.CNTCT_HRS
			ELSE class.EVAL_CRED_HRS
		END AS HRS
INTO
	#temp		
FROM
	MIS.dbo.ST_CLASS_A_151 class
	INNER JOIN #distinctcoursesforprograms d ON d.CRS_ID = class.crsId
WHERE 
	class.effTrm >= @min_term
	AND class.effTrm <= @max_term
	AND class.effTrm >= d.EFF_TRM_D
	AND (class.effTrm <= d.END_TRM OR d.END_TRM = '')

SELECT DISTINCT
	p.PGM_CD
	,p.AWD_TY
	,class.campCntr
	,@min_term AS min_term
	,@max_term AS max_term
	,'ELEC' AS PGM_AREA
	,CAST('' AS VARCHAR(MAX)) AS PGM_AREA_GROUP
	,CAST('' AS VARCHAR(MAX)) AS PGM_AREA_TYPE
	,class.crsId
	,MAX(class.EVAL_CRED_HRS) AS HRS
INTO
	#interimreport
FROM
	MIS.dbo.ST_CLASS_A_151 class
	INNER JOIN #electives e ON e.CRS_ID = class.crsId
	INNER JOIN #programs p ON p.AWD_TY = e.AWD_TYPE
WHERE 
	class.effTrm >= e.EFF_TRM
	AND class.effTrm <= CAST(CAST(LEFT(e.END_TRM, 4) AS INT) + 5 AS VARCHAR(MAX)) + RIGHT(e.END_TRM, 1)
	AND class.effTrm >= @min_term
	AND class.effTrm <= @max_term
GROUP BY
	p.PGM_CD
	,p.AWD_TY
	,class.campCntr
	,class.crsId

INSERT INTO #interimreport
	SELECT DISTINCT
		t.PGM_CD
		,t.AWD_TY
		,t.campCntr
		,@min_term AS min_term
		,@max_term AS max_term
		,dict.PGM_AREA
		,dict.PGM_AREA_GROUP
		,dict.PGM_AREA_TYPE
		,t.crsId
		,t.HRS
	FROM
		#temp t
		INNER JOIN #coursegroupareadictionary dict ON dict.PGM_CD = t.PGM_CD
													AND t.crsId = dict.CRS_ID

DELETE course
	FROM
		#interimreport course
	WHERE
		course.PGM_AREA = 'ELEC'
		AND EXISTS (SELECT
							* 
					FROM 
						#interimreport i 
					WHERE 
						i.crsId = course.crsId 
						AND i.PGM_CD = course.PGM_CD 
						AND i.campCntr = course.campCntr
						AND i.PGM_AREA <> 'ELEC')

IF (@highschool = 'H')
BEGIN

	SELECT 
		i.*	
	INTO
		#othersitesinterimreport
	FROM 
		#interimreport i
		LEFT JOIN #highschools h ON i.campCntr = h.campCntr
	WHERE
		h.campCntr IS NULL

	SELECT 
		i.*
	INTO
		#highschoolinterimreport
	FROM 
		#interimreport i
		LEFT JOIN #highschools h ON i.campCntr = h.campCntr
	WHERE
		h.campCntr IS NOT NULL

	SELECT
		i.*
		,SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Program Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN 0
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA <> 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) IN ('01', '02', '03', '04', '05') THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total General Education Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA = 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Professional Core Hours]
	INTO
		#highschoolreport
	FROM
		#highschoolinterimreport i

	SELECT
		i.*
		,SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Program Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN 0
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA <> 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) IN ('01', '02', '03', '04', '05') THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total General Education Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA = 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Professional Core Hours]
	INTO
		#othersitesreport
	FROM
		#othersitesinterimreport i

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_CRD_HRS
		FROM
			#highschoolreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY <> 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_CRD_HRS

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		FROM
			#highschoolreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY = 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_MIN_CNTCT_HRS_REQD

	UPDATE f
		SET f.[Total General Education Hours] = prog.PGM_TTL_GE_HRS_REQD
		FROM
			#highschoolreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total General Education Hours] > prog.PGM_TTL_GE_HRS_REQD

	UPDATE f
		SET f.[Total Professional Core Hours] = prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD
		FROM
			#highschoolreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total Professional Core Hours] > prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD

	SELECT
		f.PGM_CD
		,f.AWD_TY
		,f.campCntr
		,f.min_term
		,f.max_term
		,f.PGM_AREA
		,f.PGM_AREA_GROUP
		,f.crsId
		,f.HRS
		,f.[Total Program Hours]
		,f.[Total General Education Hours]
		,f.[Total Professional Core Hours]
	FROM
		#highschoolreport f

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_CRD_HRS
		FROM
			#othersitesreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY <> 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_CRD_HRS

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		FROM
			#othersitesreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY = 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_MIN_CNTCT_HRS_REQD

	UPDATE f
		SET f.[Total General Education Hours] = prog.PGM_TTL_GE_HRS_REQD
		FROM
			#othersitesreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total General Education Hours] > prog.PGM_TTL_GE_HRS_REQD

	UPDATE f
		SET f.[Total Professional Core Hours] = prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD
		FROM
			#othersitesreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total Professional Core Hours] > prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD

	SELECT
		h.campCntr
		,h.AWD_TY
		,h.PGM_CD
		,CASE
			WHEN h.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD
			ELSE prog.PGM_TTL_CRD_HRS
		END AS [Total PGM Hrs (required for degree)]
		,h.[Total Program Hours]
		,CAST(0.0 AS FLOAT) AS [Percent of PGM Hrs]
		,prog.PGM_TTL_GE_HRS_REQD
		,h.[Total General Education Hours]
		,CAST(0.0 AS FLOAT) AS [Percent of Gen Ed Hrs at Site]
		,CASE
			WHEN h.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD
			ELSE prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD
		END AS [Total Professional Core Hours Required]
		,h.[Total Professional Core Hours]
		,CAST(0.0 AS FLOAT) AS [Percent of Professional Core Hours at Site]
		,ISNULL(prev.[Current_ # of PGM hrs at site],0) AS [Current_ # of PGM hrs at site]
		,ISNULL(prev.[Current_% of PGM Hrs],0) AS [Current_% of PGM Hrs]
		,ISNULL(prev.[Current_# of Gen Ed Hrs at site],0) AS [Current_# of Gen Ed Hrs at site]
		,ISNULL(prev.[Current_% of Gen Ed Hrs at site],0) AS [Current_% of Gen Ed Hrs at site]
		,ISNULL(prev.[Current_# of Prof Hrs at site],0) AS [Current_# of Prof Hrs at site]
		,ISNULL(prev.[Current_% of Prof Hrs at site],0) AS [Current_% of Prof Hrs at site]
	INTO
		#highschooldiffreport
	FROM
		#highschoolreport h
		INNER JOIN #othersitesreport o ON o.PGM_CD = h.PGM_CD
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON h.PGM_CD = prog.PGM_CD
		LEFT JOIN Adhoc.[dbo].[ProgramsByHighSchoolLocation] prev ON prev.[Center #] = h.campCntr
																	AND prev.[POS Code] = h.PGM_CD
	WHERE
		prog.EFF_TRM_D <> ''
		AND prog.END_TRM = ''
	GROUP BY
		h.campCntr
		,h.AWD_TY
		,h.PGM_CD
		,prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		,prog.PGM_TTL_CRD_HRS
		,h.[Total Program Hours]
		,prog.PGM_TTL_GE_HRS_REQD
		,h.[Total General Education Hours]
		,h.[Total Professional Core Hours]
		,prev.[Current_ # of PGM hrs at site]
		,prev.[Current_% of PGM Hrs]
		,prev.[Current_# of Gen Ed Hrs at site]
		,prev.[Current_% of Gen Ed Hrs at site]
		,prev.[Current_# of Prof Hrs at site]
		,prev.[Current_% of Prof Hrs at site]

	UPDATE h
		SET h.[Percent of PGM Hrs] = ROUND(CAST(h.[Total Program Hours] AS FLOAT) / CAST(h.[Total PGM Hrs (required for degree)] AS FLOAT) * 100.0, 2)
			,h.[Percent of Gen Ed Hrs at Site] = CASE
				WHEN h.PGM_TTL_GE_HRS_REQD = 0 THEN 100.0
				ELSE ROUND(CAST(h.[Total General Education Hours] AS FLOAT) / CAST(h.PGM_TTL_GE_HRS_REQD AS FLOAT) * 100.0, 2)
			END
			,h.[Percent of Professional Core Hours at Site] =  CASE 
				WHEN h.[Total Professional Core Hours Required] = 0 THEN 100.0
				ELSE ROUND(CAST(h.[Total Professional Core Hours] AS FLOAT) / CAST(h.[Total Professional Core Hours Required] AS FLOAT) * 100.0, 2)
			END
		FROM #highschooldiffreport h

	SELECT 
		h.campCntr AS [Center#]
		,loc.LOCATION_NAME AS [Center Name]
		,h.PGM_CD AS [POS Code]
		,CASE
			WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL
			ELSE prog.PGM_TRK_TTL
		END AS [POS Title]
		,h.[Total PGM Hrs (required for degree)] AS [PGM Hrs (required for degree)]
		,h.[Total Program Hours] AS [Current # of PGM hours at site]
		,h.[Percent of PGM Hrs] AS [Percentage of PGM hours at site]
		,h.[Total General Education Hours] AS [Current # of Gen Ed hours at site]
		,h.[Percent of Gen Ed Hrs at Site] AS [Percentage of Gen Ed hours at site]
		,h.[Total Professional Core Hours] AS [Current # of Prof hours at site]
		,h.[Percent of Professional Core Hours at Site] AS [Percentage of Prof hours at site]
		,CASE
			WHEN h.[Current_% of PGM Hrs] > h.[Percent of PGM Hrs] THEN 'Lower'
			WHEN h.[Current_% of PGM Hrs] < h.[Percent of PGM Hrs] THEN 'Higher'
			ELSE 'No Change' 
		END AS [Higher or Lower]
		,h.[Current_ # of PGM hrs at site] AS [Previous # of PGM hours at site (last reported)]
		,h.[Current_% of PGM Hrs] AS [Previous Percentage of PGM hours]
		,h.[Current_# of Gen Ed Hrs at site] AS [Previous # of Gen Ed hours at site]
		,h.[Current_% of Gen Ed Hrs at site] AS [Previous Percentage of Gen Ed hours at site]
		,h.[Current_# of Prof Hrs at site] AS [Previous # of Prof hours at site]
		,h.[Current_% of Prof Hrs at site] AS [Previous Percentage of Prof hours at site]
	FROM
		#highschooldiffreport h
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = h.PGM_CD
		INNER JOIN MIS.dbo.FAC199_LOCATION_A_199 loc ON loc.SITE_LOCAL_NUM + loc.LOCATION_NUM = h.campCntr
	WHERE
		prog.EFF_TRM_D <> ''
		AND prog.END_TRM = ''
				
END
ELSE
	BEGIN

	SELECT
		i.*
		,SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Program Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN 0
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA <> 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) IN ('01', '02', '03', '04', '05') THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total General Education Hours]
		,SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				WHEN i.AWD_TY = 'AA' AND i.PGM_AREA = 'ELEC' THEN i.HRS
				WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' THEN i.HRS
				ELSE 0
			END) OVER (PARTITION BY i.PGM_CD, i.campCntr) AS [Total Professional Core Hours]
	INTO
		#finalreport
	FROM
		#interimreport i

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_CRD_HRS
		FROM
			#finalreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY <> 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_CRD_HRS

	UPDATE f
		SET f.[Total Program Hours] = prog.PGM_TTL_MIN_CNTCT_HRS_REQD
		FROM
			#finalreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.AWD_TY = 'VC'
			AND f.[Total Program Hours] > prog.PGM_TTL_MIN_CNTCT_HRS_REQD

	UPDATE f
		SET f.[Total General Education Hours] = prog.PGM_TTL_GE_HRS_REQD
		FROM
			#finalreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total General Education Hours] > prog.PGM_TTL_GE_HRS_REQD

	UPDATE f
		SET f.[Total Professional Core Hours] = prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD
		FROM
			#finalreport f
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.PGM_CD = f.PGM_CD
		WHERE
			prog.EFF_TRM_D <> ''
			AND prog.END_TRM = ''
			AND f.[Total Professional Core Hours] > prog.PGM_TTL_CRD_HRS - prog.PGM_TTL_GE_HRS_REQD
	
	SELECT
		f.PGM_CD
		,f.AWD_TY
		,f.campCntr
		,f.min_term
		,f.max_term
		,f.PGM_AREA
		,f.PGM_AREA_GROUP
		,f.crsId
		,f.HRS
		,f.[Total Program Hours]
		,f.[Total General Education Hours]
		,f.[Total Professional Core Hours]
	FROM
		#finalreport f
	ORDER BY
		f.PGM_CD
		,f.campCntr

	--SELECT
	--	f.campCntr AS [Center#]
	--	,f.PGM_CD AS [POS Code]
	--	,f.[Total Program Hours] AS [Current # of PGM hours at site]
	--	,CAST(0 AS FLOAT) AS [Percentage of PGM hours at site]
	--	,f.[Total General Education Hours] AS [Current # of Gen Ed hours at site]
	--	,CAST(0 AS FLOAT) AS [Percentage of Gen Ed hours at site]
	--	,f.[Total Professional Core Hours] AS [Current # of Prof hours at site]
	--	,CAST(0 AS FLOAT) AS [Percentage of Prof hours at site]
	--FROM
	--	#finalreport f

	SELECT *
  FROM [Adhoc].[dbo].[ProgramsByNonHSCenters]
		
END