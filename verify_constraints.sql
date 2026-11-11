-- Run ONLY after multi_major_planner.sql in a test database.
-- Each invalid statement must fail; run mysql with --force to continue.
USE multi_major_planner;
START TRANSACTION;
INSERT INTO Department VALUES (1,'중복 PK');
INSERT INTO Department (dept_name) VALUES ('컴퓨터공학과');
INSERT INTO CurriculumCourse VALUES (1,'109004',2026,'전선');
INSERT INTO CurriculumCourse VALUES (999,'109004',2026,'전선');
INSERT INTO CurriculumCourse VALUES (1,'209001',2026,'교양');
INSERT INTO Section (course_id,dept_id,`year`,semester,section_no,professor,capacity) VALUES ('109004',1,2026,2,'11001','테스트',30);
INSERT INTO Section (course_id,dept_id,`year`,semester,section_no,professor,capacity) VALUES ('MISSING',1,2026,2,'X','테스트',30);
INSERT INTO Section (course_id,dept_id,`year`,semester,section_no,professor,capacity) VALUES ('109004',1,2026,3,'X','테스트',30);
INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES (1,2,1,2,'다른 강의실');
INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES (999,1,1,2,'테스트');
INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES (1,8,1,2,'테스트');
INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES (1,1,5,2,'테스트');
INSERT INTO Course VALUES ('BAD','테스트',-1);
DELETE FROM Course WHERE course_id='109004';
ROLLBACK;
SELECT CONSTRAINT_TYPE,COUNT(*) AS total FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='multi_major_planner' GROUP BY CONSTRAINT_TYPE;
