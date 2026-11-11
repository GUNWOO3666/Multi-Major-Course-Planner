-- SeoulTech 2026-2: screenshot transcription, 67 sections. MySQL 8.0.16+.
-- Run once AFTER the original demo script. Replaces ONLY an exact original demo dataset.
-- If any original data differs, the guard raises an error BEFORE replacement.
-- In Workbench enable: Query > Stop Script Execution On Errors.
-- NOT a curriculum-year certification: offered year != curriculum year.
USE multi_major_planner;
SET NAMES utf8mb4;
CREATE TEMPORARY TABLE expected_Department LIKE Department;
CREATE TEMPORARY TABLE expected_Course LIKE Course;
CREATE TEMPORARY TABLE expected_CurriculumCourse LIKE CurriculumCourse;
CREATE TEMPORARY TABLE expected_Section LIKE Section;
CREATE TEMPORARY TABLE expected_ClassSchedule LIKE ClassSchedule;
INSERT INTO expected_Department (dept_id,dept_name) VALUES (1,'컴퓨터공학과'),(2,'스마트ICT융합공학과');
INSERT INTO expected_Course VALUES ('109004','데이터베이스',3),('109005','운영체제',3),('209001','사물인터넷',3),('009001','프로그래밍기초',3);
INSERT INTO expected_CurriculumCourse VALUES
 (1,'109004',2025,'전선'),(1,'109004',2026,'전필'),
 (2,'109004',2026,'전선'),(1,'109005',2026,'전필'),
 (2,'209001',2026,'전필'),(1,'009001',2026,'전필'),(2,'009001',2026,'전선');
INSERT INTO expected_Section (section_id,course_id,dept_id,`year`,semester,section_no,professor,capacity) VALUES
 (1,'109004',1,2026,2,'11001','김교수',40),
 (2,'109004',1,2026,2,'11002','이교수',40),
 (3,'109005',1,2026,2,'11001','박교수',35),
 (4,'209001',2,2026,2,'21001','최교수',30),
 (5,'009001',2,2026,2,'21002','정교수',40);
INSERT INTO expected_ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES
 (1,2,1,2,'공학관101'),(1,4,3,3,'공학관101'),
 (2,1,4,5,'공학관102'),(2,3,4,4,'공학관102'),
 (3,2,2,3,'공학관201'),(3,4,4,4,'공학관201'),
 (4,2,2,2,'ICT관301'),(4,5,1,2,'ICT관301'),
 (5,1,1,2,'ICT관302'),(5,3,1,1,'ICT관302');
DELIMITER $$
CREATE PROCEDURE guard_original_demo()
BEGIN
 IF (SELECT COUNT(*) FROM Department) <> (SELECT COUNT(*) FROM expected_Department) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Department: row count differs from original demo.';
 END IF;
 IF EXISTS (SELECT 1 FROM expected_Department e WHERE NOT EXISTS (SELECT 1 FROM Department a WHERE a.`dept_id` <=> e.`dept_id` AND a.`dept_name` <=> e.`dept_name`)) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Department: not the exact original demo. Stop; preserve existing data.';
 END IF;
 IF (SELECT COUNT(*) FROM Course) <> (SELECT COUNT(*) FROM expected_Course) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course: row count differs from original demo.';
 END IF;
 IF EXISTS (SELECT 1 FROM expected_Course e WHERE NOT EXISTS (SELECT 1 FROM Course a WHERE a.`course_id` <=> e.`course_id` AND a.`title` <=> e.`title` AND a.`credits` <=> e.`credits`)) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Course: not the exact original demo. Stop; preserve existing data.';
 END IF;
 IF (SELECT COUNT(*) FROM CurriculumCourse) <> (SELECT COUNT(*) FROM expected_CurriculumCourse) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CurriculumCourse: row count differs from original demo.';
 END IF;
 IF EXISTS (SELECT 1 FROM expected_CurriculumCourse e WHERE NOT EXISTS (SELECT 1 FROM CurriculumCourse a WHERE a.`dept_id` <=> e.`dept_id` AND a.`course_id` <=> e.`course_id` AND a.`curriculum_year` <=> e.`curriculum_year` AND a.`course_type` <=> e.`course_type`)) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CurriculumCourse: not the exact original demo. Stop; preserve existing data.';
 END IF;
 IF (SELECT COUNT(*) FROM Section) <> (SELECT COUNT(*) FROM expected_Section) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section: row count differs from original demo.';
 END IF;
 IF EXISTS (SELECT 1 FROM expected_Section e WHERE NOT EXISTS (SELECT 1 FROM Section a WHERE a.`section_id` <=> e.`section_id` AND a.`course_id` <=> e.`course_id` AND a.`dept_id` <=> e.`dept_id` AND a.`year` <=> e.`year` AND a.`semester` <=> e.`semester` AND a.`section_no` <=> e.`section_no` AND a.`professor` <=> e.`professor` AND a.`capacity` <=> e.`capacity`)) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Section: not the exact original demo. Stop; preserve existing data.';
 END IF;
 IF (SELECT COUNT(*) FROM ClassSchedule) <> (SELECT COUNT(*) FROM expected_ClassSchedule) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ClassSchedule: row count differs from original demo.';
 END IF;
 IF EXISTS (SELECT 1 FROM expected_ClassSchedule e WHERE NOT EXISTS (SELECT 1 FROM ClassSchedule a WHERE a.`schedule_id` <=> e.`schedule_id` AND a.`section_id` <=> e.`section_id` AND a.`day_of_week` <=> e.`day_of_week` AND a.`start_period` <=> e.`start_period` AND a.`end_period` <=> e.`end_period` AND a.`classroom` <=> e.`classroom`)) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ClassSchedule: not the exact original demo. Stop; preserve existing data.';
 END IF;
END$$
DELIMITER ;
CALL guard_original_demo();
-- Allow genuinely unknown values instead of fabricating capacity or room assignments.
ALTER TABLE Section MODIFY capacity SMALLINT NULL,
 ADD offered_course_type VARCHAR(2) COLLATE utf8mb4_bin NULL,
 ADD raw_schedule VARCHAR(100) NULL,
 ADD raw_classrooms VARCHAR(300) NULL,
 ADD reported_count SMALLINT NULL COMMENT 'Number shown in screenshot; not verified as capacity',
 ADD schedule_status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED',
 ADD CONSTRAINT ck_offered_type CHECK (offered_course_type IS NULL OR offered_course_type IN ('전필','전선')),
 ADD CONSTRAINT ck_schedule_status CHECK (schedule_status IN ('CONFIRMED','NEEDS_REVIEW')),
 ADD CONSTRAINT ck_reported_count CHECK (reported_count IS NULL OR reported_count >= 0);
ALTER TABLE ClassSchedule MODIFY classroom VARCHAR(100) NULL;
-- No CurriculumCourse rows are inferred: curriculum year not provided.
DELIMITER $$
CREATE PROCEDURE load_seoultech_2026_2()
BEGIN
 DECLARE previous_safe_updates INT DEFAULT 1;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET SESSION sql_safe_updates = previous_safe_updates; RESIGNAL; END;
 SET previous_safe_updates = @@SESSION.sql_safe_updates;
 SET SESSION sql_safe_updates = 0;
 START TRANSACTION;
 CALL guard_original_demo();
 DELETE FROM ClassSchedule;
 DELETE FROM Section;
 DELETE FROM CurriculumCourse;
 DELETE FROM Course;
 DELETE FROM Department;
 INSERT INTO Department (dept_id,dept_name) VALUES (1,'컴퓨터공학과'),(2,'스마트ICT융합공학과');
 INSERT INTO Course (course_id,title,credits) VALUES
 ('109004','프로그래밍입문(2)',3),
 ('109029','컴퓨터그래픽스',3),
 ('109038','모바일프로그래밍',3),
 ('109073','선형대수학',3),
 ('109075','오픈소스소프트웨어',3),
 ('109078','기계학습',3),
 ('109086','블록체인',3),
 ('109114','캡스톤디자인(2)',3),
 ('109130','소프트웨어공학',3),
 ('109180','알고리즘',3),
 ('109261','웹프로그래밍',3),
 ('109270','컴파일러구조',3),
 ('109285','컴퓨터보안',3),
 ('109343','컴퓨터시스템구조',3),
 ('109417','Introduction to Programming 2',3),
 ('109481','고급웹프로그래밍',3),
 ('109482','유닉스프로그래밍',3),
 ('109502','코업(2)',6),
 ('109503','코업프로젝트(2)',12),
 ('109504','게임프로그래밍',3),
 ('109507','데이터마이닝',3),
 ('109512','사이버보안',3),
 ('109829','Linear Algebra',3),
 ('109833','Open Source Software',3),
 ('109834','Database',3),
 ('109840','빅데이터처리',3),
 ('109844','인공지능개론',3),
 ('101083','프로그래밍입문',3),
 ('161007','공학수학(2)',3),
 ('187006','회로이론(2)',3),
 ('187007','전자기학(2)',3),
 ('187008','신호및시스템',3),
 ('187010','기초전기전자실험(2)',3),
 ('187017','프로그래밍방법론',3),
 ('187018','컴퓨터구조',3),
 ('187019','디지털통신',3),
 ('187020','전자회로(2)',3),
 ('187021','디지털집적회로',3),
 ('187022','전력전자',3),
 ('187034','VR/AR',3),
 ('187038','코업(4)',6),
 ('187039','코업프로젝트(4)',12),
 ('187040','캡스톤디자인(2)',3),
 ('187042','딥러닝기초',3),
 ('187043','시스템프로그래밍',3),
 ('187045','디지털시스템설계',3);
 INSERT INTO Section (section_id,course_id,dept_id,`year`,semester,section_no,professor,capacity,offered_course_type,raw_schedule,raw_classrooms,reported_count,schedule_status) VALUES
 (1,'109004',1,2026,2,'11001','강동완',NULL,'전필','화(1~4)','아름관-405',54,'CONFIRMED'),
 (2,'109004',1,2026,2,'11003','이한수',NULL,'전필','금(6~9)','미래관-313',38,'CONFIRMED'),
 (3,'109004',1,2026,2,'11002','박래혁',NULL,'전필','월(1~4)','미래관-313',39,'CONFIRMED'),
 (4,'109029',1,2026,2,'31001','강동완',NULL,'전선','화(6~8)','Techno Cube(테크노 큐브)-403',90,'CONFIRMED'),
 (5,'109038',1,2026,2,'31002','이한수',NULL,'전선','월(1~4)','미래관-320',25,'CONFIRMED'),
 (6,'109038',1,2026,2,'31001','이한수',NULL,'전선','수(1~4)','미래관-313',40,'CONFIRMED'),
 (7,'109073',1,2026,2,'11001','손일수',NULL,'전선','수(6~8)','미래관-109',90,'CONFIRMED'),
 (8,'109075',1,2026,2,'21001','최성록',NULL,'전선','목(1~4)','미래관-319 미래관-320 미래관-B104',75,'CONFIRMED'),
 (9,'109078',1,2026,2,'31001','한지형',NULL,'전선','수(6~8)','미래관-B104',75,'CONFIRMED'),
 (10,'109086',1,2026,2,'41001','이창훈',NULL,'전선','화(2~4)','미래관-107',38,'CONFIRMED'),
 (11,'109114',1,2026,2,'41002','손일수',NULL,'전필','금(2~4)','미래관-313',12,'CONFIRMED'),
 (12,'109114',1,2026,2,'41008','최현수',NULL,'전필','금(6~8)','미래관-320',12,'CONFIRMED'),
 (13,'109114',1,2026,2,'41007','손기욱',NULL,'전필','금(2~4)','미래관-109',12,'CONFIRMED'),
 (14,'109114',1,2026,2,'41006','최성록',NULL,'전필','금(2~4)','미래관-107',11,'CONFIRMED'),
 (15,'109114',1,2026,2,'41005','김진대',NULL,'전필','금(2~4)','미래관-323',12,'CONFIRMED'),
 (16,'109114',1,2026,2,'41004','강동완',NULL,'전필','금(2~4)','미래관-320',12,'CONFIRMED'),
 (17,'109114',1,2026,2,'41003','한지형',NULL,'전필','금(2~4)','미래관-319',12,'CONFIRMED'),
 (18,'109114',1,2026,2,'41001','신용현',NULL,'전필','금(6~8)','미래관-310',12,'CONFIRMED'),
 (19,'109114',1,2026,2,'41009','전은흡',NULL,'전필','금(2~4)','미래관-208',12,'CONFIRMED'),
 (20,'109114',1,2026,2,'41010','김성곤',NULL,'전필','금(2~4)','미래관-201',12,'CONFIRMED'),
 (21,'109130',1,2026,2,'31001','김진대',NULL,'전선','화(2~4)','미래관-109',80,'CONFIRMED'),
 (22,'109180',1,2026,2,'21001','이창훈',NULL,'전선','화(6~9)','미래관-109 미래관-310 미래관-313',95,'CONFIRMED'),
 (23,'109261',1,2026,2,'21001','이길흥',NULL,'전선','화(1~4)','미래관-320',40,'CONFIRMED'),
 (24,'109270',1,2026,2,'41001','김진대',NULL,'전선','수(6~8)','미래관-310',38,'CONFIRMED'),
 (25,'109285',1,2026,2,'31001','박종혁',NULL,'전선','월(2~4)','미래관-109',40,'CONFIRMED'),
 (26,'109343',1,2026,2,'31001','박래혁',NULL,'전선','월(6~8)','미래관-109',98,'CONFIRMED'),
 (27,'109417',1,2026,2,'11001','아비르',NULL,'전필','금(1~4)','미래관-310',40,'CONFIRMED'),
 (28,'109481',1,2026,2,'31001','아비르',NULL,'전선','금(6~9)','미래관-319',38,'CONFIRMED'),
 (29,'109482',1,2026,2,'21001','신용현',NULL,'전선','월(1~4)','미래관-310',28,'CONFIRMED'),
 (30,'109482',1,2026,2,'21002','신용현',NULL,'전선','월(6~9)','미래관-310',25,'CONFIRMED'),
 (31,'109502',1,2026,2,'41001','한지형',NULL,'전선','토(1)','미래관-323',10,'NEEDS_REVIEW'),
 (32,'109503',1,2026,2,'41001','한지형',NULL,'전선','토(2)','미래관-323',10,'NEEDS_REVIEW'),
 (33,'109504',1,2026,2,'31001','전은흡',NULL,'전선','목(6~9)','미래관-310',40,'CONFIRMED'),
 (34,'109507',1,2026,2,'41001','전은흡',NULL,'전선','화(6~8)','미래관-201',41,'CONFIRMED'),
 (35,'109512',1,2026,2,'41001','손기욱',NULL,'전선','월(5~7)','미래관-201',38,'CONFIRMED'),
 (36,'109829',1,2026,2,'11001','손일수',NULL,'전선','목(1~3)','미래관-109',95,'CONFIRMED'),
 (37,'109833',1,2026,2,'21001','최성록',NULL,'전선','목(6~9)','미래관-109 미래관-319 미래관-320',80,'CONFIRMED'),
 (38,'109834',1,2026,2,'21001','김성곤',NULL,'전선','목(6~8)','미래관-208',100,'CONFIRMED'),
 (39,'109840',1,2026,2,'41001','김성곤',NULL,'전선','목(2~4)','미래관-202',40,'CONFIRMED'),
 (40,'109844',1,2026,2,'21001','최현수',NULL,'전선','월(6~8)','Techno Cube(테크노 큐브)-403',103,'CONFIRMED'),
 (41,'101083',2,2026,2,'11002','정현민',NULL,'전선','수(5~6),목(2)','창학관-317 창학관-317',26,'CONFIRMED'),
 (42,'101083',2,2026,2,'11001','정현민',NULL,'전선','수(4),목(5~6)','창학관-317 창학관-317',23,'CONFIRMED'),
 (43,'161007',2,2026,2,'21004','이계민',NULL,'전필','화(3),목(1~2)','창학관-324 창학관-324',70,'CONFIRMED'),
 (44,'187006',2,2026,2,'21001','이원영',NULL,'전필','수(5),금(2~3)','창학관-115 창학관-115',25,'CONFIRMED'),
 (45,'187006',2,2026,2,'21002','이원영',NULL,'전필','수(6),금(5~6)','창학관-115 창학관-115',25,'CONFIRMED'),
 (46,'187007',2,2026,2,'21001','최의민',NULL,'전필','수(6),금(5~6)','창학관-113 창학관-113',27,'CONFIRMED'),
 (47,'187007',2,2026,2,'21002','최의민',NULL,'전필','수(5),금(2~3)','창학관-113 창학관-113',27,'CONFIRMED'),
 (48,'187008',2,2026,2,'21001','박구만',NULL,'전선','화(1~2),목(3)','창학관-326 창학관-326',45,'CONFIRMED'),
 (49,'187010',2,2026,2,'21001','최현덕',NULL,'전필','월(5~10)','창학관-317',20,'CONFIRMED'),
 (50,'187010',2,2026,2,'21002','최현덕',NULL,'전필','화(5~10)','창학관-317',20,'CONFIRMED'),
 (51,'187017',2,2026,2,'21001','김화정',NULL,'전선','월(2~3),수(2)','창학관-323 창학관-323',30,'CONFIRMED'),
 (52,'187018',2,2026,2,'31001','김화정',NULL,'전선','화(3),수(5~6)','창학관-123 창학관-123',75,'CONFIRMED'),
 (53,'187019',2,2026,2,'31001','김동호',NULL,'전선','화(7),목(5~6)','창학관-325 창학관-325',50,'CONFIRMED'),
 (54,'187020',2,2026,2,'31001','김성권',NULL,'전선','월(8~10)','창학관-115',35,'CONFIRMED'),
 (55,'187021',2,2026,2,'31001','이원영',NULL,'전선','화(5~6),수(7)','창학관-115 창학관-115',30,'CONFIRMED'),
 (56,'187022',2,2026,2,'31001','최의민',NULL,'전선','수(8),목(7~8)','창학관-113 창학관-113',30,'CONFIRMED'),
 (57,'187034',2,2026,2,'41001','정현민',NULL,'전선','수(8~9),목(9)','창학관-325 창학관-325',25,'CONFIRMED'),
 (58,'187038',2,2026,2,'41001','최의민',NULL,'전선','일(0)',NULL,10,'NEEDS_REVIEW'),
 (59,'187039',2,2026,2,'41001','최의민',NULL,'전선','일(1)',NULL,10,'NEEDS_REVIEW'),
 (60,'187040',2,2026,2,'41003','김성권',NULL,'전선','금(7~12)','창학관-318',16,'CONFIRMED'),
 (61,'187040',2,2026,2,'41004','정현민',NULL,'전선','금(7~12)','창학관-342',16,'CONFIRMED'),
 (62,'187040',2,2026,2,'41002','이계민',NULL,'전선','금(7~12)','창학관-341',6,'CONFIRMED'),
 (63,'187040',2,2026,2,'41005','김화정',NULL,'전선','금(7~12)','창학관-320',10,'CONFIRMED'),
 (64,'187040',2,2026,2,'41001','최현덕',NULL,'전선','금(7~12)','창학관-313',13,'CONFIRMED'),
 (65,'187042',2,2026,2,'31001','이계민',NULL,'전선','화(1~2),목(3)','창학관-323 창학관-323',52,'CONFIRMED'),
 (66,'187043',2,2026,2,'31001','김화정',NULL,'전선','월(5~7)','창학관-323',30,'CONFIRMED'),
 (67,'187045',2,2026,2,'21001','정현민',NULL,'전선','수(7),목(7~8)','창학관-317 창학관-317',35,'CONFIRMED');
 INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES
 ('1','2','1','4','아름관-405'),
 ('2','5','6','9','미래관-313'),
 ('3','1','1','4','미래관-313'),
 ('4','2','6','8','Techno Cube(테크노 큐브)-403'),
 ('5','1','1','4','미래관-320'),
 ('6','3','1','4','미래관-313'),
 ('7','3','6','8','미래관-109'),
 ('8','4','1','4',NULL),
 ('9','3','6','8','미래관-B104'),
 ('10','2','2','4','미래관-107'),
 ('11','5','2','4','미래관-313'),
 ('12','5','6','8','미래관-320'),
 ('13','5','2','4','미래관-109'),
 ('14','5','2','4','미래관-107'),
 ('15','5','2','4','미래관-323'),
 ('16','5','2','4','미래관-320'),
 ('17','5','2','4','미래관-319'),
 ('18','5','6','8','미래관-310'),
 ('19','5','2','4','미래관-208'),
 ('20','5','2','4','미래관-201'),
 ('21','2','2','4','미래관-109'),
 ('22','2','6','9',NULL),
 ('23','2','1','4','미래관-320'),
 ('24','3','6','8','미래관-310'),
 ('25','1','2','4','미래관-109'),
 ('26','1','6','8','미래관-109'),
 ('27','5','1','4','미래관-310'),
 ('28','5','6','9','미래관-319'),
 ('29','1','1','4','미래관-310'),
 ('30','1','6','9','미래관-310'),
 ('33','4','6','9','미래관-310'),
 ('34','2','6','8','미래관-201'),
 ('35','1','5','7','미래관-201'),
 ('36','4','1','3','미래관-109'),
 ('37','4','6','9',NULL),
 ('38','4','6','8','미래관-208'),
 ('39','4','2','4','미래관-202'),
 ('40','1','6','8','Techno Cube(테크노 큐브)-403'),
 ('41','3','5','6','창학관-317'),
 ('41','4','2','2','창학관-317'),
 ('42','3','4','4','창학관-317'),
 ('42','4','5','6','창학관-317'),
 ('43','2','3','3','창학관-324'),
 ('43','4','1','2','창학관-324'),
 ('44','3','5','5','창학관-115'),
 ('44','5','2','3','창학관-115'),
 ('45','3','6','6','창학관-115'),
 ('45','5','5','6','창학관-115'),
 ('46','3','6','6','창학관-113'),
 ('46','5','5','6','창학관-113'),
 ('47','3','5','5','창학관-113'),
 ('47','5','2','3','창학관-113'),
 ('48','2','1','2','창학관-326'),
 ('48','4','3','3','창학관-326'),
 ('49','1','5','10','창학관-317'),
 ('50','2','5','10','창학관-317'),
 ('51','1','2','3','창학관-323'),
 ('51','3','2','2','창학관-323'),
 ('52','2','3','3','창학관-123'),
 ('52','3','5','6','창학관-123'),
 ('53','2','7','7','창학관-325'),
 ('53','4','5','6','창학관-325'),
 ('54','1','8','10','창학관-115'),
 ('55','2','5','6','창학관-115'),
 ('55','3','7','7','창학관-115'),
 ('56','3','8','8','창학관-113'),
 ('56','4','7','8','창학관-113'),
 ('57','3','8','9','창학관-325'),
 ('57','4','9','9','창학관-325'),
 ('60','5','7','12','창학관-318'),
 ('61','5','7','12','창학관-342'),
 ('62','5','7','12','창학관-341'),
 ('63','5','7','12','창학관-320'),
 ('64','5','7','12','창학관-313'),
 ('65','2','1','2','창학관-323'),
 ('65','4','3','3','창학관-323'),
 ('66','1','5','7','창학관-323'),
 ('67','3','7','7','창학관-317'),
 ('67','4','7','8','창학관-317');
 COMMIT;
 SET SESSION sql_safe_updates = previous_safe_updates;
END$$
DELIMITER ;
CALL load_seoultech_2026_2();
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

