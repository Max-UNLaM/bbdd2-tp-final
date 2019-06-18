CREATE DATABASE Z -- creo para ahi guardar los SP (por ahora)
USE Z 

ALTER PROC SP_CompareDB(@db_origen NVARCHAR(100), @db_destino NVARCHAR(100))
AS
BEGIN
	IF (exists(SELECT 1 FROM sys.databases WHERE name=@db_origen) and
		exists(SELECT 1 FROM sys.databases WHERE name=@db_destino))
		BEGIN
			DECLARE @query NVARCHAR(1000)
			--Obtengo las tablas del db_origen y guardo en la tabla temporal
			SET @query = 'SELECT TABLE_CATALOG, TABLE_NAME INTO ##TABLAS_BD_ORIGEN FROM '+@db_origen+'.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE =''BASE TABLE'';'
			EXEC (@query)
			--Obtengo las tablas del db_destino y guardo en la tabla temporal
			SET @query = 'SELECT TABLE_CATALOG, TABLE_NAME INTO ##TABLAS_BD_DESTINO FROM '+@db_destino+'.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE =''BASE TABLE'';'
			EXEC (@query)

		END
	ELSE
		BEGIN 
			if not exists(select 1 from sys.databases where name=@db_origen)
			RAISERROR(N'No existe la base de datos %s', 16, 1, @db_origen)
	
			if not exists(select 1 from sys.databases where name=@db_destino)
			RAISERROR(N'No existe la base de datos %s', 16, 1, @db_destino)
		END
END

EXEC SP_CompareDB 'origen', 'destino'


-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



