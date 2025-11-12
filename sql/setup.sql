CREATE TABLE employees (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(50),
    department VARCHAR2(50)
);

INSERT INTO employees VALUES (1, 'Alice', 'HR');
INSERT INTO employees VALUES (2, 'Bob', 'IT');
INSERT INTO employees VALUES (3, 'Carol', 'Finance');
COMMIT;
