CREATE DATABASE IF NOT EXISTS minicloud;
USE minicloud;
CREATE TABLE IF NOT EXISTS services (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);
INSERT INTO services (name, description) VALUES
    ('web', 'Nginx web frontend'),
    ('application', 'Flask application backend')
ON DUPLICATE KEY UPDATE description = VALUES(description);
