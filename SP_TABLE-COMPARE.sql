/*
Autor: Equipo Base De Datos
Fecha de Creación: 27/05/2019
Función: Modificar tabla de dos bases de datos para que la de destino coincidacon formato de tabla de origen
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
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @origin_database
END TRY
BEGIN CATCH
END CATCH
GO