/*
Autor: Equipo Base De Datos
Fecha de Creaci�n: 27/05/2019
Funci�n: Modificar tabla de dos bases de datos para que la de destino coincidacon formato de tabla de origen
Task: Manual
*/




CREATE PROCEDURE SP_TABLE_COMPARE @table VARCHAR(80), @origin_database VARCHAR(80), @destination_database VARCHAR(80)
AS
BEGIN TRY
	-- Validar que existan ambas bases de datos
	IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE NAME = @origin_database)
		RAISERROR(N'No existe la base de datos %s', 16, 1, @origin_database)
	IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE NAME = @destination_database)
		RAISERROR(N'No existe la base de datos %s', 16, 1, @destination_database)
-- Traer todas las columnas de la tabla de origen
CREATE TABLE #columnasTablaOrigen (COLUMN_NAME VARCHAR(80))
(
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @origin_database + '.' + @table
);
-- Traer todas las columnas de tabla destino
CREATE TABLE #columnasTablaDestino (COLUMN_NAME VARCHAR(80))
(
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @destination_database + '.' + @table
);
-- Traer columnas que no existan en la de destino
CREATE TABLE #columnasHuerfanas (COLUMN_NAME VARCHAR(80))(
	SELECT * FROM #columnasTablaOrigen AS ori 
	LEFT JOIN #columnasTablaDestino AS dest ON ori.COLUMN_NAME = dest.COLUMN_NAME
		WHERE dest.COLUMN_NAME = NULL
);
	-- Crear el SP (o meter ac�) para recorrer, cursor mediante, estas columnas para realizar el alter correspondiente en la tabla destino
	RAISERROR('Not implemented', 16, 1)
GO

SELECT Columnas
FROM
(
    SELECT  c.name "Columnas"
    FROM Musica.sys.tables t
    INNER JOIN Musica.sys.all_columns c 
            ON t.object_id = c.object_id
    INNER JOIN Musica.sys.types ty 
            ON c.system_type_id = ty.system_type_id
    WHERE t.name = 'Cantante'
    EXCEPT
    SELECT  c.name
    FROM Musica2.sys.tables t
    INNER JOIN Musica2.sys.all_columns c 
            ON t.object_id = c.object_id
    INNER JOIN Musica2.sys.types ty 
            ON c.system_type_id = ty.system_type_id
    WHERE t.name = 'Cantante'
) as izquierda
UNION ALL
SELECT Columnas
FROM
(
    SELECT  c.name Columnas
    FROM Musica2.sys.tables t
    INNER JOIN Musica2.sys.all_columns c  
            ON t.object_id = c.object_id
    INNER JOIN Musica2.sys.types ty      
            ON c.system_type_id = ty.system_type_id
    WHERE t.name = 'Cantante'
    EXCEPT
    SELECT  c.name
    FROM Musica.sys.tables t
    INNER JOIN Musica.sys.all_columns c 
            ON t.object_id = c.object_id
    INNER JOIN Musica.sys.types ty 
            ON c.system_type_id = ty.system_type_id
    WHERE t.name = 'Cantante'
) as derecha;
END TRY
BEGIN CATCH
END CATCH
GO