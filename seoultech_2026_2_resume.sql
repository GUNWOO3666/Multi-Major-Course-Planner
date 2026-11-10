-- Run in the SAME Workbench connection after error 1175. Do not rerun the whole import.
USE multi_major_planner;
SET @planner_previous_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;
CALL load_seoultech_2026_2();
SET SESSION sql_safe_updates = @planner_previous_safe_updates;

DROP PROCEDURE load_seoultech_2026_2;
DROP PROCEDURE guard_original_demo;
DROP TEMPORARY TABLE expected_Department;
DROP TEMPORARY TABLE expected_Course;
DROP TEMPORARY TABLE expected_CurriculumCourse;
DROP TEMPORARY TABLE expected_Section;
DROP TEMPORARY TABLE expected_ClassSchedule;

-- Verification: 2 departments, 46 courses, 0 unverified curricula, 67 sections, 79 meetings.
SELECT 'Department' AS table_name,COUNT(*) AS row_count FROM Department
UNION ALL SELECT 'Course',COUNT(*) FROM Course
UNION ALL SELECT 'CurriculumCourse',COUNT(*) FROM CurriculumCourse
UNION ALL SELECT 'Section',COUNT(*) FROM Section
UNION ALL SELECT 'ClassSchedule',COUNT(*) FROM ClassSchedule;
SELECT d.dept_name,COUNT(*) AS sections FROM Section s JOIN Department d ON d.dept_id=s.dept_id GROUP BY d.dept_id,d.dept_name;
SELECT c.course_id,c.title,s.section_no,s.raw_schedule,s.raw_classrooms,s.schedule_status
FROM Section s JOIN Course c ON c.course_id=s.course_id WHERE s.schedule_status='NEEDS_REVIEW';
-- All normal sections must have a meeting: expected 0 rows.
SELECT s.section_id FROM Section s LEFT JOIN ClassSchedule cs ON cs.section_id=s.section_id
WHERE s.schedule_status='CONFIRMED' GROUP BY s.section_id HAVING COUNT(cs.schedule_id)=0;
-- Offered-course list independent of CurriculumCourse (not yet certified).
SELECT d.dept_name,c.course_id,c.title,c.credits,s.section_id,s.section_no,s.offered_course_type,
 s.professor,cs.day_of_week,cs.start_period,cs.end_period,cs.classroom,s.raw_classrooms,s.schedule_status
FROM Section s JOIN Department d ON d.dept_id=s.dept_id JOIN Course c ON c.course_id=s.course_id
LEFT JOIN ClassSchedule cs ON cs.section_id=s.section_id
WHERE s.`year`=2026 AND s.semester=2 ORDER BY d.dept_id,s.section_id,cs.day_of_week;

