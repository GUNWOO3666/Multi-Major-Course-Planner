-- Multi-Major Course Planner | MySQL 8.0.16+ | UTF-8
-- Fresh installation only: existing tables cause an error; no data is dropped.
CREATE DATABASE IF NOT EXISTS multi_major_planner CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE multi_major_planner;
SET NAMES utf8mb4;

CREATE TABLE Department (
 dept_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 dept_name VARCHAR(100) NOT NULL,
 CONSTRAINT uq_department_name UNIQUE (dept_name),
 CONSTRAINT ck_department_name CHECK (CHAR_LENGTH(TRIM(dept_name)) > 0)
) ENGINE=InnoDB;

CREATE TABLE Course (
 course_id VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
 title VARCHAR(150) NOT NULL,
 credits DECIMAL(3,1) NOT NULL,
 CONSTRAINT ck_course_id CHECK (CHAR_LENGTH(TRIM(course_id)) > 0),
 CONSTRAINT ck_course_title CHECK (CHAR_LENGTH(TRIM(title)) > 0),
 CONSTRAINT ck_course_credits CHECK (credits > 0 AND credits <= 30)
) ENGINE=InnoDB;

CREATE TABLE CurriculumCourse (
 dept_id INT UNSIGNED NOT NULL,
 course_id VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 curriculum_year SMALLINT NOT NULL,
 course_type VARCHAR(2) COLLATE utf8mb4_bin NOT NULL COMMENT '전필 또는 전선',
 recommended_year TINYINT NOT NULL,
 recommended_semester TINYINT NOT NULL,
 PRIMARY KEY (dept_id, course_id, curriculum_year),
 CONSTRAINT fk_curriculum_department FOREIGN KEY (dept_id) REFERENCES Department(dept_id),
 CONSTRAINT fk_curriculum_course FOREIGN KEY (course_id) REFERENCES Course(course_id),
 CONSTRAINT ck_curriculum_year CHECK (curriculum_year BETWEEN 1900 AND 2199),
 CONSTRAINT ck_curriculum_type CHECK (course_type IN ('전필','전선')),
 CONSTRAINT ck_recommended_year CHECK (recommended_year BETWEEN 1 AND 6),
 CONSTRAINT ck_recommended_semester CHECK (recommended_semester IN (1,2))
) ENGINE=InnoDB;

CREATE TABLE Section (
 section_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 course_id VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 dept_id INT UNSIGNED NOT NULL COMMENT '개설 학과; 교육과정 인정 학과와 다를 수 있음',
 `year` SMALLINT NOT NULL,
 semester TINYINT NOT NULL,
 section_no VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 professor VARCHAR(100) NOT NULL,
 capacity SMALLINT NOT NULL,
 CONSTRAINT uq_section UNIQUE (`year`, semester, course_id, section_no),
 CONSTRAINT fk_section_course FOREIGN KEY (course_id) REFERENCES Course(course_id),
 CONSTRAINT fk_section_department FOREIGN KEY (dept_id) REFERENCES Department(dept_id),
 CONSTRAINT ck_section_year CHECK (`year` BETWEEN 1900 AND 2199),
 CONSTRAINT ck_section_semester CHECK (semester IN (1,2)),
 CONSTRAINT ck_section_no CHECK (CHAR_LENGTH(TRIM(section_no)) > 0),
 CONSTRAINT ck_section_professor CHECK (CHAR_LENGTH(TRIM(professor)) > 0),
 CONSTRAINT ck_section_capacity CHECK (capacity > 0),
 INDEX ix_section_department_term (dept_id, `year`, semester)
) ENGINE=InnoDB;

CREATE TABLE ClassSchedule (
 schedule_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 section_id INT UNSIGNED NOT NULL,
 day_of_week TINYINT NOT NULL COMMENT '1=월,2=화,3=수,4=목,5=금,6=토,7=일',
 start_period TINYINT NOT NULL,
 end_period TINYINT NOT NULL COMMENT '종료 교시 포함',
 classroom VARCHAR(100) NOT NULL,
 CONSTRAINT uq_schedule UNIQUE (section_id, day_of_week, start_period, end_period),
 CONSTRAINT fk_schedule_section FOREIGN KEY (section_id) REFERENCES Section(section_id),
 CONSTRAINT ck_schedule_day CHECK (day_of_week BETWEEN 1 AND 7),
 CONSTRAINT ck_schedule_period CHECK (start_period BETWEEN 1 AND 15 AND end_period BETWEEN 1 AND 15 AND start_period <= end_period),
 CONSTRAINT ck_schedule_room CHECK (CHAR_LENGTH(TRIM(classroom)) > 0)
) ENGINE=InnoDB;

-- Fictional demonstration data, NOT the university's actual 2026 timetable.
START TRANSACTION;
INSERT INTO Department (dept_id,dept_name) VALUES (1,'컴퓨터공학과'),(2,'스마트ICT융합공학과');
INSERT INTO Course VALUES ('109004','데이터베이스',3),('109005','운영체제',3),('209001','사물인터넷',3),('009001','프로그래밍기초',3);
INSERT INTO CurriculumCourse VALUES
 (1,'109004',2025,'전선',3,2),(1,'109004',2026,'전필',3,2),
 (2,'109004',2026,'전선',3,2),(1,'109005',2026,'전필',3,2),
 (2,'209001',2026,'전필',3,2),(1,'009001',2026,'전필',1,1),(2,'009001',2026,'전선',1,1);
INSERT INTO Section (section_id,course_id,dept_id,`year`,semester,section_no,professor,capacity) VALUES
 (1,'109004',1,2026,2,'11001','김교수',40),
 (2,'109004',1,2026,2,'11002','이교수',40),
 (3,'109005',1,2026,2,'11001','박교수',35),
 (4,'209001',2,2026,2,'21001','최교수',30),
 (5,'009001',2,2026,2,'21002','정교수',40);
INSERT INTO ClassSchedule (section_id,day_of_week,start_period,end_period,classroom) VALUES
 (1,2,1,2,'공학관101'),(1,4,3,3,'공학관101'),
 (2,1,4,5,'공학관102'),(2,3,4,4,'공학관102'),
 (3,2,2,3,'공학관201'),(3,4,4,4,'공학관201'),
 (4,2,2,2,'ICT관301'),(4,5,1,2,'ICT관301'),
 (5,1,1,2,'ICT관302'),(5,3,1,1,'ICT관302');
COMMIT;

-- Expected counts: 2 / 4 / 7 / 5 / 10.
SELECT 'Department' AS table_name, COUNT(*) AS row_count FROM Department
UNION ALL SELECT 'Course', COUNT(*) FROM Course
UNION ALL SELECT 'CurriculumCourse', COUNT(*) FROM CurriculumCourse
UNION ALL SELECT 'Section', COUNT(*) FROM Section
UNION ALL SELECT 'ClassSchedule', COUNT(*) FROM ClassSchedule;

-- Recognition by selected departments and curriculum year; one row per meeting.
-- A shared course intentionally appears once per recognizing department.
SET @curriculum_year = 2026;
SELECT d.dept_name AS curriculum_department, cc.course_type, c.course_id,c.title,c.credits,
 od.dept_name AS offering_department,s.section_id,s.section_no,s.professor,
 cs.day_of_week,cs.start_period,cs.end_period,cs.classroom
FROM CurriculumCourse cc
JOIN Department d ON d.dept_id=cc.dept_id
JOIN Course c ON c.course_id=cc.course_id
JOIN Section s ON s.course_id=c.course_id
JOIN Department od ON od.dept_id=s.dept_id
JOIN ClassSchedule cs ON cs.section_id=s.section_id
WHERE cc.dept_id IN (1,2) AND cc.curriculum_year=@curriculum_year
 AND s.`year`=2026 AND s.semester=2
ORDER BY d.dept_id,c.course_id,s.section_no,cs.day_of_week;

-- ER minimum participation audit: expected zero rows.
-- PK/FK/CHECK alone cannot enforce at least one meeting per section.
SELECT s.section_id FROM Section s LEFT JOIN ClassSchedule cs ON cs.section_id=s.section_id
GROUP BY s.section_id HAVING COUNT(cs.schedule_id)=0;

-- Selected sections 1 and 4: expected one conflict, Tuesday period 2.
SELECT a.section_id AS section_a,b.section_id AS section_b,a.day_of_week,
 GREATEST(a.start_period,b.start_period) AS overlap_start,
 LEAST(a.end_period,b.end_period) AS overlap_end
FROM ClassSchedule a JOIN ClassSchedule b ON a.section_id < b.section_id
 AND a.day_of_week=b.day_of_week AND a.start_period<=b.end_period AND b.start_period<=a.end_period
JOIN Section sa ON sa.section_id=a.section_id
JOIN Section sb ON sb.section_id=b.section_id AND sa.`year`=sb.`year` AND sa.semester=sb.semester
WHERE a.section_id IN (1,4) AND b.section_id IN (1,4);
