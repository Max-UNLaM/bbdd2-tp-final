/*
Autor: Equipo Base De Datos
Fecha de Creaci�n: 27/05/2019
Funci�n: Copia la tabla de la base de datos de origen a la de destino
Task: Manual
*/


CREATE PROCEDURE SP_TABLE_COPY @table VARCHAR(80), @origin_database VARCHAR(80), @destination_database VARCHAR(80)
AS
BEGIN TRY
	IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE NAME = @origin_database)
		RAISERROR(N'No existe la base de datos %s', 16, 1, @origin_database)
END TRY
BEGIN CATCH
END CATCH
GO