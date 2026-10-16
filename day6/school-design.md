# School Database Design Document

## Table Descriptions

1. **`students`**: Stores individual student profiles, including their unique identifier, full name, and a unique email address.
2. **`courses`**: Stores available classes offered by the school, including a unique course title and a unique course code (e.g., MATH101).
3. **`enrolments`**: A junction (join) table that connects students to courses. It handles the many-to-many relationship and stores the specific `grade` attribute earned by a student in that course.

---

## Relationships & Join Table

- **Students to Courses (Many-to-Many):** One student can enroll in multiple courses, and one course can have multiple students.
- **Why a Join Table is Needed:** Relational databases cannot store direct multi-valued lists inside a single column. The `enrolments` table resolves this by mapping `student_id` and `course_id` pairs.
- **Composite Primary Key & Constraints:** By setting `PRIMARY KEY (student_id, course_id)`, the database enforces a strict rule: the exact same student cannot enroll in the exact same course twice, while foreign keys with `ON DELETE CASCADE` ensure data integrity if a student or course is removed.

---

## Recommended Index

- **Index:** `CREATE INDEX idx_enrolments_course ON enrolments(course_id);`
- **Reason:** This index dramatically speeds up lookup operations when querying which students are enrolled in a specific course or when aggregating student counts per course via `GROUP BY`.

---

## SQL vs. NoSQL Evaluation

For a school management system handling student records, grades, and course registrations, **SQL (Relational Database)** is the optimal choice. School data is strictly structured, highly relational (students link directly to courses and grades), and requires absolute transactional integrity (ACID compliance) so grades and enrolments are never orphaned or duplicated. NoSQL would be unnecessarily loose for managing rigid academic records and constraints like unique emails and strict enrolment keys.
