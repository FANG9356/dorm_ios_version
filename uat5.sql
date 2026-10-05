UPDATE admins SET email = 'uat_admin@test.com' WHERE username = 'uat_admin'; INSERT INTO admins (username, email, role, dorm_code) VALUES ('uat_super', 'uat_admin@test.com', 'superadmin', '1');
