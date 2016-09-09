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
*/

USE MIS

IF OBJECT_ID('dbo.sp_Program_Location_Report') IS NOT NULL
	DROP PROCEDURE dbo.sp_Program_Location_Report
GO

CREATE PROCEDURE dbo.sp_Program_Location_Report
	@pgm_cd CHAR(4) = ''
	,@awd_type VARCHAR(4) = ''
	,@min_term CHAR(5) = '20141'
	,@max_term CHAR(5) = '20172'
	,@campcntr VARCHAR(10) = ''
	,@highschool CHAR(1) = 'H'
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
		SRC.PGM_CD
		,SRC.PGM_AREA_GROUP_CRS AS CRS_ID
		,SRC.PGM_AREA
		,SRC.PGM_AREA_GROUP
		,SRC.PGM_AREA_TYPE
	INTO
		#coursegroupareadictionary
	FROM
		(SELECT
			ROW_NUMBER() OVER (PARTITION BY prog.PGM_CD, groupcourse.PGM_AREA_GROUP_CRS ORDER BY EFF_TRM_G DESC) RN
			,prog.PGM_CD
			,groupcourse.PGM_AREA_GROUP_CRS
			,prog.PGM_AREA
			,prog.PGM_AREA_GROUP
			,prog.PGM_AREA_TYPE
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
			INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 groupcourse ON groupcourse.ISN_ST_PROGRAMS_A = prog.ISN_ST_PROGRAMS_A
			INNER JOIN #distinctcoursesforprograms dist ON dist.CRS_ID = groupcourse.PGM_AREA_GROUP_CRS
														AND dist.PGM_CD = prog.PGM_CD
		WHERE
			prog.EFF_TRM_G <> ''
			AND prog.EFF_TRM_G <= @min_term) SRC
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
		,'' AS PGM_AREA_GROUP
		,'' AS PGM_AREA_TYPE
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

	IF (@highschool <> '')
	BEGIN
		IF (@highschool = 'H')
		BEGIN
			DELETE i 
				FROM #interimreport i
				LEFT JOIN #highschools h ON i.campCntr = h.campCntr
			WHERE
				h.campCntr IS NULL
		END
		IF (@highschool = 'O')
		BEGIN
			DELETE i 
				FROM #interimreport i
				LEFT JOIN #highschools h ON i.campCntr = h.campCntr
			WHERE
				h.campCntr IS NOT NULL
		END
	END
	
	
	/*Please forgive me*/		
	SELECT
		i.*
		,CASE WHEN SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) > MAX(prog.PGM_TTL_CRD_HRS) AND i.AWD_TY <> 'VC'
			  THEN MAX(prog.PGM_TTL_CRD_HRS) 
			  WHEN SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) > MAX(prog.PGM_TTL_MIN_CNTCT_HRS_REQD)
			  THEN MAX(prog.PGM_TTL_CRD_HRS) 
			  ELSE SUM(i.HRS) OVER (PARTITION BY i.PGM_CD, i.campCntr) END AS [Total Program Hours]
		,CASE WHEN (SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN 0
				ELSE CASE
						WHEN LEFT(i.PGM_AREA_TYPE, 2) < '06' AND i.AWD_TY IN ('BAS','BSN','BS','AAS','AS') THEN i.HRS
						WHEN i.AWD_TY = 'AA' AND i.PGM_AREA <> 'ELEC' THEN i.HRS
						ELSE 0
					END
				END) OVER (PARTITION BY i.PGM_CD, i.campCntr)) > MAX(prog.[PGM_TTL_GE_HRS_REQD]) THEN MAX(prog.[PGM_TTL_GE_HRS_REQD]) 
				ELSE SUM(CASE
					WHEN i.AWD_TY = 'VC' THEN 0
					ELSE CASE
							WHEN LEFT(i.PGM_AREA_TYPE, 2) < '06' AND i.AWD_TY IN ('BAS','BSN','BS','AAS','AS') THEN i.HRS
							WHEN i.AWD_TY = 'AA' AND i.PGM_AREA <> 'ELEC' THEN i.HRS
							ELSE 0
						END
					END) OVER (PARTITION BY i.PGM_CD, i.campCntr) END AS [Total General Education Hours]
		,CASE WHEN (SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				ELSE CASE
						WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' AND i.AWD_TY IN ('BAS','BSN','BS','AAS','AS') THEN i.HRS
						WHEN i.PGM_AREA = 'ELEC' AND i.AWD_TY = 'AA' THEN i.HRS
						ELSE 0
					END
				END) OVER (PARTITION BY i.PGM_CD, i.campCntr)) > MAX(prog.PGM_TTL_CRD_HRS) - MAX(prog.PGM_TTL_GE_HRS_REQD) AND i.AWD_TY <> 'VC' THEN MAX(prog.PGM_TTL_CRD_HRS)
			WHEN (SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				ELSE CASE
						WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' AND i.AWD_TY IN ('BAS','BSN','BS','AAS','AS') THEN i.HRS
						WHEN i.PGM_AREA = 'ELEC' AND i.AWD_TY = 'AA' THEN i.HRS
						ELSE 0
					END
				END) OVER (PARTITION BY i.PGM_CD, i.campCntr)) > MAX(prog.PGM_TTL_MIN_CNTCT_HRS_REQD) THEN MAX(prog.PGM_TTL_MIN_CNTCT_HRS_REQD) 
			ELSE SUM(CASE
				WHEN i.AWD_TY = 'VC' THEN i.HRS
				ELSE CASE
						WHEN LEFT(i.PGM_AREA_TYPE, 2) >= '06' AND i.AWD_TY IN ('BAS','BSN','BS','AAS','AS') THEN i.HRS
						WHEN i.PGM_AREA = 'ELEC' AND i.AWD_TY = 'AA' THEN i.HRS
						ELSE 0
					END
				END) OVER (PARTITION BY i.PGM_CD, i.campCntr) END AS [Total Professional Core Hours]
	INTO
		#finalreport
	FROM 
		#interimreport i
		INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON i.PGM_CD = prog.PGM_CD
	WHERE
		prog.EFF_TRM_D <> ''
		AND prog.EFF_TRM_D <= @max_term
	GROUP BY
		 i.PGM_CD
		,i.AWD_TY
		,i.campCntr
		,i.min_term
		,i.max_term
		,i.PGM_AREA
		,i.PGM_AREA_GROUP
		,i.PGM_AREA_TYPE
		,i.crsId
		,i.HRS

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
		PGM_CD,
		campCntr
		,crsId

END
GO

/************************************************************
*   Testing
************************************************************/

EXEC dbo.sp_Program_Location_Report
