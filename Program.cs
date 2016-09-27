using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PLR
{
    public class Program
    {
        static void Main(string[] args)
        {
            //Parameters
            String minTerm = "20141";
            String maxTerm = "20172";
            String programCode = "";
            String campusCenter = "";
            String awardType = "";
            bool runForHighSchool = true;
 
            //derived parameters
            int minTermYear = int.Parse(minTerm.Substring(0, 4));
            int minTermTerm = int.Parse("" + minTerm[4]);
            int maxTermYear = int.Parse(maxTerm.Substring(0, 4));
            int maxTermTerm = int.Parse("" + maxTerm[4]);

            //datastores
            Dictionary<String, AcademicProgram> programDictionary = new Dictionary<string, AcademicProgram>();
            Dictionary<String, Course> globalCourseDictionary = new Dictionary<string, Course>();
            Dictionary<Tuple<String, String>, List<String>> classesByCampusCenterAndTerm = new Dictionary<Tuple<string, string>, List<string>>();
            List<String> campusCenters = new List<String>();
            Dictionary<Tuple<String,String>,List<String>> AAElectivesByCampusAndTerm = new Dictionary<Tuple<string,string>,List<string>>();
            List<AcademicProgram> programs = new List<AcademicProgram>();
            Dictionary<Tuple<String, String, String>, float> TotalProgramHoursForProgramByCampusCenter = new Dictionary<Tuple<string, string, string>, float>();
            Dictionary<Tuple<String, String, String>, float> TotalGeneralEducationHoursForProgramByCampusCenter = new Dictionary<Tuple<string, string, string>, float>();
            Dictionary<Tuple<String, String, String>, float> TotalCoreAndProfessionalForProgramByCampusCenter = new Dictionary<Tuple<string, string, string>, float>();
            Dictionary<Tuple<String, String, String>, List<String>> SatisfiedCoursesForProgramByCatalogYearAndCampusCenter = new Dictionary<Tuple<string, string, string>, List<string>>();
            Dictionary<Tuple<String, String, String>, List<String>> AACoursesByAACatalogAndCampus = new Dictionary<Tuple<string, string, string>, List<string>>();

            String[] highschoolCodes = new String[]{"D1427",
                                                    "C1411",
                                                    "A1618",
                                                    "D1401",
                                                    "C1634",
                                                    "C1414",
                                                    "A1103",
                                                    "B1403",
                                                    "A1104",
                                                    "A1105",
                                                    "D1103",
                                                    "B1408",
                                                    "A1110",
                                                    "A1111",
                                                    "A1112",
                                                    "Z7000",
                                                    "A1303",
                                                    "A1116",
                                                    "A1301",
                                                    "A1117",
                                                    "Z7004",
                                                    "A1118",
                                                    "B1613",
                                                    "A1119",
                                                    "A1114",
                                                    "Z7015",
                                                    "Z7002",
                                                    "B1410",
                                                    "F1410",
                                                    "A1106",
                                                    "A1122",
                                                    "B1414"};
            
            SqlConnection conn = new SqlConnection("Server=vulcan;database=MIS;Trusted_Connection=yes");

            try
            {
                conn.Open();
            }
            catch (Exception)
            {
                
                throw;
            }

 
            SqlCommand comm = new SqlCommand("SELECT DISTINCT                                                                                                                         "
                                            + "    prog.PGM_CD                                                                                                                        "
                                            + "    ,prog.AWD_TY                                                                                                                       "    
                                            + "    ,prog.EFF_TRM_D                                                                                                                    "
                                            + "    ,prog.END_TRM                                                                                                                      "
                                            + "    ,proggroup.PGM_AREA                                                                                                                "
                                            + "    ,progarea.PGM_AREA_TYPE                                                                                                            "
                                            + "    ,proggroup.PGM_AREA_GROUP                                                                                                          "
                                            + "    ,proggroup.PGM_AREA_OPTN_CD                                                                                                        "
                                            + "    ,proggroup.PGM_AREA_OPTN_OPER                                                                                                      "
                                            + "    ,groupcourse.PGM_AREA_GROUP_CRS                                                                                                    "
                                            + "    ,CASE WHEN prog.AWD_TY = 'VC' THEN prog.PGM_TTL_MIN_CNTCT_HRS_REQD ELSE prog.PGM_TTL_CRD_HRS END AS HRS                            "
                                            + "    ,prog.PGM_TTL_GE_HRS_REQD                                                                                                          "   
                                            + "FROM                                                                                                                                   "
                                            + "    MIS.dbo.ST_PROGRAMS_A_136 prog                                                                                                     "
                                            + "    INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 progarea ON progarea.PGM_CD = prog.PGM_CD                                                     "
                                            + "	                                              AND progarea.EFF_TRM_A = prog.EFF_TRM_D                                                 "
                                            + "    INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 proggroup ON proggroup.PGM_CD = prog.PGM_CD                                                   "
                                            + "	                                              AND proggroup.EFF_TRM_G = prog.EFF_TRM_D                                                "
                                            + "	                                              AND proggroup.PGM_AREA = progarea.PGM_AREA                                              "
                                            + "    INNER JOIN MIS.dbo.ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136 groupcourse ON groupcourse.ISN_ST_PROGRAMS_A = proggroup.ISN_ST_PROGRAMS_A "
                                            + "WHERE                                                                                                                                  "
                                            + "    prog.EFF_TRM_D <> ''                                                                                                               "
                                            + "    AND prog.EFF_TRM_D <= '" + maxTerm + "'                                                                                            "
                                            + "    AND (prog.END_TRM = '' OR prog.END_TRM >= '" + minTerm + "')                                                                       "
                                            + "    AND prog.AWD_TY NOT IN ('ND','NC','HS')                                                                                            "
                                           // + programCode == "" ? " " : ("   AND prog.PGM_CD = '" + programCode + "' ") /* causes SQL exception when uncommented. Don't know why */
                                            + "ORDER BY                                                                                                                               "
                                            + "    prog.PGM_CD                                                                                                                        "
                                            + "    ,prog.EFF_TRM_D                                                                                                                    "
                                            + "    ,proggroup.PGM_AREA                                                                                                                 "
                                            + "    ,proggroup.PGM_AREA_GROUP", conn);
            SqlDataReader reader = comm.ExecuteReader();

            while (reader.Read())
            {
                String curProgramCode = reader["PGM_CD"].ToString();
                String effectiveTerm = reader["EFF_TRM_D"].ToString();
                String endTerm = reader["END_TRM"].ToString();
                String courseID = reader["PGM_AREA_GROUP_CRS"].ToString().Trim();
                int areaNum = int.Parse(reader["PGM_AREA"].ToString());
                int groupNum = int.Parse(reader["PGM_AREA_GROUP"].ToString());

                AcademicProgram prog;

                if (!programDictionary.ContainsKey(curProgramCode))
                {
                    prog = new AcademicProgram();
                    prog.progCode = curProgramCode;
                    prog.awardType = reader["AWD_TY"].ToString();
                    prog.catalogChanges = new List<AcademicProgram.CatalogChange>();
                    prog.catalogDictionary = new Dictionary<string, AcademicProgram.CatalogChange>();
                    programs.Add(prog);
                    programDictionary.Add(curProgramCode, prog);
                }
                else
                {
                    prog = programDictionary[curProgramCode];
                }

                AcademicProgram.CatalogChange catalog;

                if (!prog.catalogDictionary.ContainsKey(effectiveTerm))
                {
                    catalog = new AcademicProgram.CatalogChange();
                    catalog.effectiveTerm = effectiveTerm;
                    catalog.endTerm = endTerm;
                    catalog.totalProgramHours = (int)float.Parse(reader["HRS"].ToString());
                    catalog.totalGeneralEducationHours = (int)float.Parse(reader["PGM_TTL_GE_HRS_REQD"].ToString());
                    catalog.totalCoreAndProfessionalHours = catalog.totalProgramHours - catalog.totalGeneralEducationHours;
                    catalog.effectiveTermYear = int.Parse(catalog.effectiveTerm.Substring(0, 4));
                    catalog.effectiveTermTerm = int.Parse("" + catalog.effectiveTerm[4]);
                    catalog.endTermYear = catalog.endTerm != "" ? int.Parse(catalog.endTerm.Substring(0, 4)) : 9999;
                    catalog.endTermTerm = catalog.endTerm != "" ? int.Parse("" + catalog.endTerm[4]) : 9;
                    catalog.areaDictionary = new Dictionary<int, AcademicProgram.CatalogChange.Area>();
                    catalog.flatCourseArray = new List<string>();
                    prog.catalogChanges.Add(catalog);
                    prog.catalogDictionary.Add(effectiveTerm, catalog);
                    catalog.areas = new List<AcademicProgram.CatalogChange.Area>();
                }
                else
                {
                    catalog = prog.catalogDictionary[effectiveTerm];
                }

                AcademicProgram.CatalogChange.Area area;

                if (!catalog.areaDictionary.ContainsKey(areaNum))
                {
                    area = new AcademicProgram.CatalogChange.Area();
                    area.areaNum = areaNum;
                    area.areaType = reader["PGM_AREA_TYPE"].ToString();
                    area.groupDictionary = new Dictionary<int, AcademicProgram.CatalogChange.Area.Group>();
                    area.groups = new List<AcademicProgram.CatalogChange.Area.Group>();
                    catalog.areas.Add(area);
                    catalog.areaDictionary.Add(area.areaNum, area);
                }
                else
                {
                    area = catalog.areaDictionary[areaNum];
                }

                AcademicProgram.CatalogChange.Area.Group group;

                if (!area.groupDictionary.ContainsKey(groupNum))
                {
                    
                    group = new AcademicProgram.CatalogChange.Area.Group();
                    group.groupNum = groupNum;
                    group.optCode = reader["PGM_AREA_OPTN_CD"].ToString();
                    group.operatorCode = reader["PGM_AREA_OPTN_OPER"].ToString();
                    group.courseDictionary = new Dictionary<string, Course>();
                    group.courses = new List<Course>();
                    area.groups.Add(group);
                    area.groupDictionary.Add(groupNum, group);
                }
                else
                {
                    group = area.groupDictionary[groupNum];
                }

                Course course;

                if (!globalCourseDictionary.ContainsKey(courseID))
                {
                    course = new Course();
                    course.courseID = courseID;
                    globalCourseDictionary.Add(courseID, course);
                }
                else
                {
                    course = globalCourseDictionary[courseID];
                }

                group.courseDictionary.Add(courseID, course);
                group.courses.Add(course);
                catalog.flatCourseArray.Add(courseID);
 
            }

            reader.Close();

            comm = new SqlCommand("SELECT DISTINCT"
	                           + "     class.campCntr              "
                               + " FROM                            "
	                           + "     MIS.dbo.ST_CLASS_A_151 class", conn);

            reader = comm.ExecuteReader();

            while (reader.Read())
            {
                String campCntr = reader["campCntr"].ToString();

                if (runForHighSchool)
                {
                    if (!highschoolCodes.Contains(campCntr))
                    {
                        continue;
                    }
                }
                else
                {
                    if (highschoolCodes.Contains(campCntr))
                    {
                        continue;
                    }
                }

                if (campCntr.Substring(1, 4) == "7300")
                {
                    continue;
                }
                campusCenters.Add(campCntr);

            }

            reader.Close();

            comm = new SqlCommand("SELECT DISTINCT                                                                                                                      "
	                              + "     class.crsID                                                                                                                   "
	                              + "     ,class.campCntr                                                                                                               "
	                              + "     ,class.efftrm                                                                                                                 "
	                              + "     ,CASE                                                                                                                         "
		                          + "         WHEN course.CRED_TY IN ('01','02','03','14','15') THEN class.EVAL_CRED_HRS                                                "
		                          + "         ELSE class.CNTCT_HRS                                                                                                      "
	                              + "     END AS HRS                                                                                                                    "
	                              + "     ,course.USED_FOR_AA_ELECTIVE                                                                                                  " 
                                  + " FROM                                                                                                                              "
	                              + "     MIS.dbo.ST_CLASS_A_151 class                                                                                                  "
	                              + "     INNER JOIN MIS.dbo.ST_COURSE_A_150 course ON course.CRS_ID = class.crsID                                                      "
	                              + "     INNER JOIN MIS.[dbo].[ST_PROGRAMS_A_PGM_AREA_GROUP_CRS_136] groupcourse ON groupcourse.[PGM_AREA_GROUP_CRS] =  course.CRS_ID  "
	                              + "     INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 proggroup ON proggroup.ISN_ST_PROGRAMS_A = groupcourse.ISN_ST_PROGRAMS_A                 "
                                  + " WHERE                                                                                                                             "
	                              + "     class.efftrm <= '" + maxTerm + "'                                                                                             "
	                              + "     AND class.efftrm >= '" + minTerm + "'", conn);
            comm.CommandTimeout = 240;
            reader = comm.ExecuteReader();

            while (reader.Read())
            {
                String curCampusCenter = reader["campCntr"].ToString();
                String term = reader["efftrm"].ToString();
                String courseID = reader["crsID"].ToString().Trim();
                Tuple<String, String> key = new Tuple<string, string>(curCampusCenter, term);
                float hours = float.Parse(reader["HRS"].ToString());
                bool AAElective = reader["USED_FOR_AA_ELECTIVE"].ToString() == "Y";

                if (!globalCourseDictionary.ContainsKey(courseID))
                {
                    continue;
                }

                List<String> courses;

                if (classesByCampusCenterAndTerm.ContainsKey(key))
                {
                    courses = classesByCampusCenterAndTerm[key];
                }
                else
                {
                    courses = new List<string>();
                    classesByCampusCenterAndTerm.Add(key, courses);
                }
                if (AAElective)
                {
                    if (!AAElectivesByCampusAndTerm.ContainsKey(key))
                    {
                        AAElectivesByCampusAndTerm.Add(key, new List<string>());
                    }
                    if (!AAElectivesByCampusAndTerm[key].Contains(courseID))
                    {
                        AAElectivesByCampusAndTerm[key].Add(courseID);
                    }
                }

                courses.Add(courseID);

                Course course = globalCourseDictionary[courseID];

                course.hours = hours;
            }

            reader.Close();
            conn.Close();
  
            foreach (AcademicProgram curProgram in programs)
            {
                foreach (AcademicProgram.CatalogChange catalog in curProgram.catalogChanges)
                {
                    foreach (String camp in campusCenters)
                    {
                        float totalProgramHours = 0;
                        float totalGenEdHours = 0;
                        float totalCoreAndProfessionalHours = 0;
                        
                        int curYear = catalog.effectiveTermYear;
                        int curTerm = catalog.effectiveTermTerm;

                        List<String> satisfiedCourses = new List<string>();
                        List<String> AACoursesForProgram = new List<string>();

                        Tuple<String, String, String> key = new Tuple<string, string, string>(curProgram.progCode, catalog.effectiveTerm, camp);
                        SatisfiedCoursesForProgramByCatalogYearAndCampusCenter.Add(key, new List<String>());

                        while ((curYear < maxTermYear || (curYear == maxTermYear && curTerm <= maxTermTerm))
                            && (curYear < catalog.endTermYear || (curYear == catalog.endTermYear && curTerm <= catalog.endTermTerm)))
                        {

                            Tuple<String, String> yearkey = new Tuple<string, string>(camp, curYear.ToString() + curTerm.ToString());
                            List<String> coursesAtCampusCenterForTerm;

                            if (classesByCampusCenterAndTerm.ContainsKey(yearkey))
                            {
                                coursesAtCampusCenterForTerm = classesByCampusCenterAndTerm[yearkey];
                            }
                            else
                            {
                                curYear = curTerm == 3 ? curYear + 1 : curYear;
                                curTerm = curTerm == 3 ? 1 : curTerm + 1;
                                continue;
                            }

                            foreach (String course in catalog.flatCourseArray)
                            {
                                if (coursesAtCampusCenterForTerm.Contains(course) && !satisfiedCourses.Contains(course))
                                {
                                    satisfiedCourses.Add(course);
                                    SatisfiedCoursesForProgramByCatalogYearAndCampusCenter[key].Add(course);
                                }
                            }

                            if (curProgram.progCode == "1108" && AAElectivesByCampusAndTerm.ContainsKey(yearkey))
                            {
                                foreach (String course in AAElectivesByCampusAndTerm[yearkey])
                                {
                                    if (!AACoursesForProgram.Contains(course))
                                    {
                                        AACoursesForProgram.Add(course);
                                        totalProgramHours += globalCourseDictionary[course].hours;
                                        totalCoreAndProfessionalHours += globalCourseDictionary[course].hours;
                                    }
                                }
                            }
                                                                                   
                            curYear = curTerm == 3 ? curYear + 1 : curYear;
                            curTerm = curTerm == 3 ? 1 : curTerm + 1;
                        }

                        if (curProgram.progCode == "1108")
                        {
                            AACoursesByAACatalogAndCampus.Add(key, AACoursesForProgram);
                        }

                        if (satisfiedCourses.Count == 0)
                        {
                            TotalProgramHoursForProgramByCampusCenter.Add(key, totalProgramHours);
                            TotalGeneralEducationHoursForProgramByCampusCenter.Add(key, totalGenEdHours);
                            TotalCoreAndProfessionalForProgramByCampusCenter.Add(key, totalCoreAndProfessionalHours);
                            continue;
                        }

                        foreach (AcademicProgram.CatalogChange.Area area in catalog.areas)
                        {
                            bool genEdArea = false;

                            switch (area.areaType.Substring(0, 2))
                            {
                                case "01":
                                case "02":
                                case "03":
                                case "04":
                                case "05":
                                    if (curProgram.awardType != "VC")
                                    {
                                        genEdArea = true;
                                    }

                                    break;
                                default:
                                    if (curProgram.awardType == "AA")
                                    {
                                        genEdArea = true;
                                    }
                                    break;
                            }

                            List<float> groupHours = new List<float>();
                            List<char> operands = new List<char>();
                            List<float> andGroups = new List<float>();

                            foreach (AcademicProgram.CatalogChange.Area.Group group in area.groups)
                            {
                                float groupHoursTotal = 0;

                                List<Course> coursesInGroup = new List<Course>();

                                foreach (String course in group.courseDictionary.Keys)
                                {
                                    if (satisfiedCourses.Contains(course))
                                    {
                                        coursesInGroup.Add(group.courseDictionary[course]);
                                    }
                                }

                                switch (group.optCode)
                                {
                                    case "14":
                                    case "00":
                                        foreach (Course course in coursesInGroup)
                                        {
                                            groupHoursTotal += course.hours;
                                        }
                                        break;
                                    case "11":

                                        float hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 2);
                                        groupHoursTotal += hoursForGroup;
                                        
                                        break;
                                    case "21":
                                    case "31":
                                    case "41":
                                    case "61":
                                    case "71":
                                    case "81":
                                    case "82":
                                    case "83":
                                    case "84":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 1);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "22":
                                    case "32":
                                    case "42":
                                    case "62":
                                    case "72":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 2);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "23":
                                    case "33":
                                    case "43":
                                    case "63":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 3);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "24":
                                    case "34":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 4);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "25":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 5);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "26":
                                    case "87":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 6);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "27":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 7);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "28":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 8);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    case "29":

                                        hoursForGroup = Course.findAndSumFirstNCourses(coursesInGroup, 9);
                                        groupHoursTotal += hoursForGroup;

                                        break;
                                    default:
                                        break;
                                }

                                groupHours.Add(groupHoursTotal);
                                operands.Add(group.operatorCode.Length == 0 ? ' ' : group.operatorCode[0]);
                            }

                            for (int i = 0; i < operands.Count; i++)
                            {
                                float andGroupTotal = groupHours[0];
                                int j = i;

                                while (j < operands.Count && operands[j] == 'A')
                                {
                                    andGroupTotal += groupHours[j];
                                    j++;
                                }

                                andGroups.Add(andGroupTotal);
                            }

                            totalProgramHours += andGroups.Max();

                            if (genEdArea)
                            {
                                totalGenEdHours += andGroups.Max();
                            }
                            else
                            {
                                totalCoreAndProfessionalHours += andGroups.Max();
                            }
                        }

                        TotalProgramHoursForProgramByCampusCenter.Add(key, totalProgramHours);
                        TotalGeneralEducationHoursForProgramByCampusCenter.Add(key, totalGenEdHours);
                        TotalCoreAndProfessionalForProgramByCampusCenter.Add(key, totalCoreAndProfessionalHours);
                    }  
                }
            }

            using (System.IO.StreamWriter file = new System.IO.StreamWriter("output.csv"))
            {
                file.WriteLine("PGM CD, AWD TYPE, CATALOG YEAR, CAMP CNTR, TRM FROM, TRM TO, AREA, GROUP, CRS ID USED, CRS HRS, TOT PGM HRS, TOT GEN-ED HRS, TOT PROF HRS");

                foreach (AcademicProgram curProgram in programs)
                {
                    foreach (AcademicProgram.CatalogChange catalog in curProgram.catalogChanges)
                    {
                        foreach (String camp in campusCenters)
                        {
                            Tuple<String, String, String> key = new Tuple<string, string, string>(curProgram.progCode, catalog.effectiveTerm, camp);

                            if (SatisfiedCoursesForProgramByCatalogYearAndCampusCenter[key].Count > 0)
                            {
                                foreach (String course in SatisfiedCoursesForProgramByCatalogYearAndCampusCenter[key])
                                {
                                    int areaNum = 0;
                                    int groupNum = 0;

                                    foreach (AcademicProgram.CatalogChange.Area area in catalog.areas)
                                    {
                                        foreach (AcademicProgram.CatalogChange.Area.Group group in area.groups)
                                        {
                                            if (group.courseDictionary.Keys.Contains(course))
                                            {
                                                areaNum = area.areaNum;
                                                groupNum = group.groupNum;
                                            }
                                        }
                                    }
                                                                        
                                    file.WriteLine(curProgram.progCode + "," + curProgram.awardType + "," + catalog.effectiveTerm + "," + camp + "," + minTerm + "," + maxTerm + "," +
                                        areaNum.ToString() + "," + groupNum.ToString() + "," + course + "," + globalCourseDictionary[course].hours.ToString() + "," +
                                        (TotalProgramHoursForProgramByCampusCenter[key] > catalog.totalProgramHours ? catalog.totalProgramHours.ToString() : 
                                        TotalProgramHoursForProgramByCampusCenter[key].ToString() )
                                        + "," + (TotalGeneralEducationHoursForProgramByCampusCenter[key] > catalog.totalGeneralEducationHours ? catalog.totalGeneralEducationHours.ToString()
                                        : TotalGeneralEducationHoursForProgramByCampusCenter[key].ToString()) + ","
                                        + (TotalCoreAndProfessionalForProgramByCampusCenter[key] > catalog.totalCoreAndProfessionalHours ? catalog.totalCoreAndProfessionalHours.ToString()
                                        : TotalCoreAndProfessionalForProgramByCampusCenter[key].ToString()));
                                }
                                if (curProgram.progCode == "1108")
                                {
                                    foreach (String course in AACoursesByAACatalogAndCampus[key])
                                    {
                                        int curYear = minTermYear;
                                        int curTerm = minTermTerm;

                                        if (!SatisfiedCoursesForProgramByCatalogYearAndCampusCenter[key].Contains(course))
                                        {
                                          file.WriteLine(curProgram.progCode + "," + curProgram.awardType + "," + catalog.effectiveTerm + "," + camp + "," + minTerm + "," + maxTerm + ",ELEC,,"
                                            + course + "," + globalCourseDictionary[course].hours.ToString() + "," + (TotalProgramHoursForProgramByCampusCenter[key] > catalog.totalProgramHours 
                                            ? catalog.totalProgramHours.ToString() : TotalProgramHoursForProgramByCampusCenter[key].ToString()) + "," + (TotalGeneralEducationHoursForProgramByCampusCenter[key] 
                                            > catalog.totalGeneralEducationHours ? catalog.totalGeneralEducationHours.ToString(): TotalGeneralEducationHoursForProgramByCampusCenter[key].ToString()) 
                                            + "," + (TotalCoreAndProfessionalForProgramByCampusCenter[key] > catalog.totalCoreAndProfessionalHours ? catalog.totalCoreAndProfessionalHours.ToString()
                                            : TotalCoreAndProfessionalForProgramByCampusCenter[key].ToString()));  
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                file.Close();
            }
        }


    }
    public class AcademicProgram
    {
        public String progCode;
        public String progName;
        public String awardType;
        public List<CatalogChange> catalogChanges;
        public Dictionary<String, CatalogChange> catalogDictionary;

        public class CatalogChange
        {
            public String effectiveTerm;
            public String endTerm;
            public bool financialAidApproved;
            public int effectiveTermYear;
            public int effectiveTermTerm;
            public int endTermYear;
            public int endTermTerm;
            public List<Area> areas;
            public List<String> flatCourseArray;
            public Dictionary<int, Area> areaDictionary;
            public int totalProgramHours;
            public int totalGeneralEducationHours;
            public int totalCoreAndProfessionalHours;

            public class Area
            {
                public int areaNum;
                public String areaType;
                public List<Group> groups;
                public Dictionary<int, Group> groupDictionary;
                    
                public class Group
                {
                    public int groupNum;
                    public String optCode;
                    public String operatorCode;
                    public List<Course> courses;
                    public Dictionary<String, Course> courseDictionary;
                        
                }
            }
        }
    }

    public class Course
    {
        public String courseID;
        public float hours;

        public static float findAndSumFirstNCourses(List<Course> courses, int n)
        {
            float[] courseHours = new float[courses.Count];

            for (int i = 0; i < courseHours.Length; i++)
            {
                courseHours[i] = courses[i].hours;
            }

            return courseHours.OrderByDescending(x => x).Take(n).Sum();
        }
    }
}
