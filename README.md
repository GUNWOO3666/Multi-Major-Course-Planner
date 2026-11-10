# Multi-Major Course Planner 실행 안내

## 실행
1. MySQL Workbench에서 로컬 MySQL 연결을 엽니다.
2. File → Open SQL Script에서 multi_major_planner.sql을 엽니다.
3. 선택 영역 없이 번개 아이콘(전체 실행)을 누릅니다.
4. Schemas를 새로고침하고 multi_major_planner → Tables의 5개 테이블을 확인합니다.

MySQL 8.0.16 이상이 필요합니다. CHECK가 실제 적용되는 버전 기준입니다.
기존 동명 테이블이 없는 DB에서 최초 1회 실행하세요. DROP/초기화 명령은 없습니다.
동명 테이블이 이미 있으면 중단하고 기존 구조를 확인하세요. 오류 무시/계속 실행은 사용하지 마세요.
DDL은 자동 커밋되므로 도중 실패한 테이블 생성은 자동으로 되돌아가지 않습니다.
명령행 실행은 mysql -u root -p --default-character-set=utf8mb4 접속 후
SOURCE C:/Users/gunwo/Documents/ChatGPT/db 프로젝트/multi_major_planner.sql;

## 설계
- Department: 학과. Course: 학교 과목코드 VARCHAR PK(선행 0 보존).
- CurriculumCourse: (dept_id, course_id, curriculum_year) 복합 PK. 학과·연도별 전필/전선 관리.
- Section: 별도 section_id PK. (year, semester, course_id, section_no) UNIQUE.
  서로 다른 과목은 같은 강좌번호를 사용할 수 있습니다.
- ClassSchedule: 요일·연속 교시 구간 하나당 한 행. 화 1~2, 목 3은 두 행입니다.
- 개설 학과와 교육과정 인정 학과는 별개입니다. 공유 교과목의 학점은 학과별 JOIN 결과를 단순 합산하면 중복될 수 있습니다.
- 학기는 정규 1/2학기, 요일은 월=1~일=7, 교시는 1~15, 종료 교시 포함으로 정했습니다.
  학교의 실제 교시 체계가 다르면 CHECK 범위를 조정하세요. 계절학기는 현재 범위 밖입니다.
- 추천 학년 1~6, 학점 0 초과~30, 정원 양수. 이 범위는 프로젝트 가정입니다.
- FK는 기본 RESTRICT 동작: 참조 중인 부모 삭제·키 변경을 차단합니다.
- 동일 시간 행은 UNIQUE로 차단합니다. 서로 다른 구간의 부분 겹침, 강의실/교수 중복은 자동 차단하지 않습니다.
- ER의 Section당 최소 1개 ClassSchedule은 PK/FK/UNIQUE/CHECK만으로 보장되지 않습니다.
  분반과 시간을 같은 트랜잭션으로 저장하고, 포함된 최소 참여 점검 조회 결과가 0행인지 확인하세요.
- 교육과정 연도와 개설 연도는 독립입니다. JOIN 예제의 @curriculum_year를 학생 적용 교육과정 연도로 바꾸세요.

## 샘플 및 검증 결과
실제 학교의 2026-2 강좌 데이터가 아닌 가상 데이터입니다.
컴퓨터공학과와 스마트ICT융합공학과의 예시를 포함합니다.
MySQL Community Server 8.0.46의 격리된 임시 DB에서 실제 실행했습니다.
사용자 기존 MySQL DB에는 접속하거나 변경하지 않았습니다.
- 5개 테이블 생성 및 INSERT 성공, 실행 오류 0건.
- 행 수: Department 2 / Course 4 / CurriculumCourse 7 / Section 5 / ClassSchedule 10.
- PK 5개, UNIQUE 3개, FK 5개, CHECK 16개 확인.
- 통합 JOIN 16행, 수업 없는 분반 0행.
- 선택 section_id 1·4의 충돌 1건: 화요일 2교시.
- verify_constraints.sql의 14개 위반 시도 모두 예상 오류로 거절됨.
  PK·UNIQUE 중복, 잘못된 FK, 전필/전선 외 값, 잘못된 학기/요일/교시/학점, 참조 중 부모 삭제를 검사했습니다.

validation-results.txt: 정상 조회 결과.
constraint-results.txt: 제약조건 개수.
constraint-errors.txt: 14개 예상 오류 기록.
verify_constraints.sql은 테스트 DB 전용이며 의도적으로 오류가 납니다.
재검증 시 mysql 클라이언트의 --force 옵션으로 실행해야 마지막 ROLLBACK까지 진행합니다.
