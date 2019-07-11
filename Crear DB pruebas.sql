
USE master
GO
-----------------------------------------------------------
CREATE DATABASE DB_Origen;
GO

USE DB_Origen;
GO

CREATE TABLE tabla1 (
id int PRIMARY KEY, 
nombre varchar(50),
mail varchar(200) DEFAULT 'mail',
fecha datetime,
flag int DEFAULT 1 
);
GO
CREATE TABLE tabla2 (
id2 int PRIMARY KEY, 
nombre2 varchar(100),
mail2 varchar(200),
fecha2 datetime
);
GO

CREATE VIEW vista1 AS
SELECT mail
FROM tabla1
GO

-----------------------------------------------------------
CREATE DATABASE DB_Destino;
GO

USE DB_Destino;
GO

CREATE TABLE tabla1 (
id int PRIMARY KEY, 
nombre varchar(100),
mail varchar(200) UNIQUE,
dni int UNIQUE,
flag char,
CHECK (dni BETWEEN 1 and 999999)
);
GO
CREATE TABLE tabla3 (
id3 int PRIMARY KEY, 
idTabla1 int, 
nombre3 varchar(100),
mail3 varchar(200),
fecha3 datetime,
FOREIGN KEY (idTabla1) REFERENCES tabla1(id)
);

-- DROP DATABASE DB_Origen
-- DROP DATABASE DB_Destino

