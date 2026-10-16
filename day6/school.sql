-- Drop tables in reverse order of dependencies if they already exist
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

-- Create tables
CREATE TABLE students (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);

CREATE TABLE courses (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  code  TEXT NOT NULL UNIQUE
);

CREATE TABLE enrolments (
  student_id INTEGER NOT NULL,
  course_id  INTEGER NOT NULL,
  grade      TEXT,
  PRIMARY KEY (student_id, course_id),
  FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY (course_id)  REFERENCES courses(id)  ON DELETE CASCADE
);

-- Insert sample data
INSERT INTO students (name, email) VALUES ('Alice Smith', 'alice@school.edu');
INSERT INTO students (name, email) VALUES ('Bob Jones', 'bob@school.edu');
INSERT INTO students (name, email) VALUES ('Charlie Brown', 'charlie@school.edu');

INSERT INTO courses (title, code) VALUES ('Mathematics', 'MATH101');
INSERT INTO courses (title, code) VALUES ('Computer Science', 'CS101');
INSERT INTO courses (title, code) VALUES ('Physics', 'PHYS101');

INSERT INTO enrolments (student_id, course_id, grade) VALUES (1, 1, 'A');
INSERT INTO enrolments (student_id, course_id, grade) VALUES (1, 2, 'B');
INSERT INTO enrolments (student_id, course_id, grade) VALUES (2, 1, 'B+');
INSERT INTO enrolments (student_id, course_id, grade) VALUES (2, 2, 'A');
INSERT INTO enrolments (student_id, course_id, grade) VALUES (2, 3, 'C');

-- Query 1: All courses for one student
SELECT courses.title, courses.code, enrolments.grade
FROM courses
JOIN enrolments ON enrolments.course_id = courses.id
JOIN students   ON students.id = enrolments.student_id
WHERE students.name = 'Alice Smith';

-- Query 2: All students on one course
SELECT students.name, students.email, enrolments.grade
FROM students
JOIN enrolments ON enrolments.student_id = students.id
JOIN courses    ON courses.id = enrolments.course_id
WHERE courses.title = 'Mathematics';

-- Query 3: Number of students per course
SELECT courses.title, COUNT(enrolments.student_id) AS student_count
FROM courses
LEFT JOIN enrolments ON enrolments.course_id = courses.id
GROUP BY courses.id;

-- Query 4: Students who have no enrolments
SELECT students.name, students.email
FROM students
LEFT JOIN enrolments ON enrolments.student_id = students.id
WHERE enrolments.course_id IS NULL;

-- Query 5: Update one enrolment's grade
UPDATE enrolments
SET grade = 'A+'
WHERE student_id = 1 AND course_id = 1;