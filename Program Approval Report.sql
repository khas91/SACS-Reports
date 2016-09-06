/*
	Author: Stuart Pierson
	ORION Program: STDL01J3 Program Approval Report.
	
	Report produces a file with the following heading:

	Pgm Cd, Offcl TTL, Cip Cd, Awd Ty, Crd Hrs, Cntct Hrs, F/A Appr, SACS Appr, Eff Trm, End Trm,   

	One issue I'm noticing is that the sample report that I was given by Karen Stearns AA, AS, and AAS programs in it, but no others.
	I don't know how to get the ORION program to give those results. This data might have been messed with to isolate those results. I'll
	have to ask her.
*/

USE MIS

IF OBJECT_ID(N'dbo.fn_Program_Approval_Report') IS NOT NULL
	DROP FUNCTION dbo.fn_Program_Approval_Report;
GO

CREATE FUNCTION dbo.fn_Program_Approval_Report (@awd_ty VARCHAR(MAX))
RETURNS @programs TABLE
(
	PGM_CD VARCHAR(MAX)
	,[Offcl TTL] VARCHAR(MAX)
	,CIP_CD VARCHAR(MAX)
	,AWD_TY VARCHAR(MAX)
	,PGM_TTL_CRD_HRS VARCHAR(MAX)
	,PGM_TTL_MIN_CNTCT_HRS_REQD VARCHAR(MAX)
	,FIN_AID_APPRVD CHAR(1)
	,SACS_APPROVAL CHAR(1)
	,EFF_TRM CHAR(6)
	,END_TRM VARCHAR(5)
)
AS
BEGIN

	INSERT INTO @programs
		SELECT
			prog.PGM_CD 
			,CASE WHEN prog.PGM_OFFCL_TTL <> '' THEN prog.PGM_OFFCL_TTL ELSE prog.PGM_TRK_TTL END AS 'Offcl TTL'
			,prog.CIP_CD
			,prog.AWD_TY
			,prog.PGM_TTL_CRD_HRS
			,prog.PGM_TTL_MIN_CNTCT_HRS_REQD
			,prog.FIN_AID_APPRVD
			,CASE WHEN prog.SACS_APPROVAL <> '' THEN prog.SACS_APPROVAL ELSE 'N' END AS 'SACS_APPROVAL'
			,prog.EFF_TRM_D
			,prog.END_TRM
		FROM
			MIS.dbo.ST_PROGRAMS_A_136 prog
		WHERE
			prog.END_TRM = ''
			AND prog.EFF_TRM_D <> ''
			AND prog.AWD_TY = CASE WHEN @AWD_TY <> '' THEN @AWD_TY ELSE prog.AWD_TY END
			AND prog.AWD_TY NOT IN ('ND','NC','HS')
	RETURN;
END
GO

USE MIS


SELECT
	*
FROM
	dbo.fn_Program_Approval_Report('')