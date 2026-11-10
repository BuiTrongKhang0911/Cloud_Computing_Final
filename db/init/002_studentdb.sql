CREATE DATABASE IF NOT EXISTS studentdb;
USE studentdb;

CREATE TABLE IF NOT EXISTS students (
    id INT PRIMARY KEY AUTO_INCREMENT,
    student_id VARCHAR(10) NOT NULL UNIQUE,
    fullname VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    major VARCHAR(50) NOT NULL
);

INSERT INTO students (student_id, fullname, dob, major) VALUES
    ('SV001', 'Nguyen Minh Anh', '2004-03-15', 'Cloud Computing'),
    ('SV002', 'Tran Gia Bao', '2003-11-02', 'Computer Science'),
    ('SV003', 'Le Phuong Linh', '2004-07-21', 'Information Systems')
ON DUPLICATE KEY UPDATE
    fullname = VALUES(fullname),
    dob = VALUES(dob),
    major = VALUES(major);

GRANT SELECT, INSERT, UPDATE, DELETE ON studentdb.* TO 'minicloud_user'@'%';
