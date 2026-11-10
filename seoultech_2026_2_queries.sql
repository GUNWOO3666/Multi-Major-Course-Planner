-- Change the selected IDs after checking the section list below.
USE multi_major_planner;
SET NAMES utf8mb4;
SELECT s.section_id,d.dept_name,c.course_id,c.title,s.section_no,s.offered_course_type,s.raw_schedule,s.schedule_status
FROM Section s JOIN Course c ON c.course_id=s.course_id JOIN Department d ON d.dept_id=s.dept_id
WHERE s.`year`=2026 AND s.semester=2 ORDER BY d.dept_id,c.course_id,s.section_no;

SET @selected_a=1;
SET @selected_b=48;
-- Demo selection: CS programming intro(2) 11001 and ICT signals and systems 21001.

-- Expected: one conflict, Tuesday periods 1 through 2.
SELECT a.section_id AS section_a,ca.title AS course_a,b.section_id AS section_b,cb.title AS course_b,
 a.day_of_week,GREATEST(a.start_period,b.start_period) AS overlap_start,
 LEAST(a.end_period,b.end_period) AS overlap_end
FROM ClassSchedule a
JOIN ClassSchedule b ON a.section_id<b.section_id AND a.day_of_week=b.day_of_week
 AND a.start_period<=b.end_period AND b.start_period<=a.end_period
JOIN Section sa ON sa.section_id=a.section_id
JOIN Section sb ON sb.section_id=b.section_id AND sa.`year`=sb.`year` AND sa.semester=sb.semester
JOIN Course ca ON ca.course_id=sa.course_id
JOIN Course cb ON cb.course_id=sb.course_id
WHERE a.section_id IN (@selected_a,@selected_b)
 AND b.section_id IN (@selected_a,@selected_b);
-- Pending sections must not be interpreted as conflict-free.
SELECT s.section_id,c.title,s.raw_schedule,'강의시간 확인 필요' AS warning
FROM Section s
JOIN Course c ON c.course_id=s.course_id WHERE s.section_id IN (@selected_a,@selected_b) AND s.schedule_status='NEEDS_REVIEW';


