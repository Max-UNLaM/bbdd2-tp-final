USE TEST;
IF OBJECT_ID('dbo.SP_VALIDAR_NORMAS_CODIFICACION') IS NOT NULL
				DROP procedure SP_VALIDAR_NORMAS_CODIFICACION
GO
-- SP CON FUNCIONES 
CREATE PROCEDURE SP_VALIDAR_NORMAS_CODIFICACION @bdOrigen varchar(50)
AS
BEGIN TRY
set nocount on
		IF OBJECT_ID('dbo.PRIMARY_KEY', 'U') IS NOT NULL
				DROP TABLE PRIMARY_KEY; 
		IF OBJECT_ID('dbo.UNIQUES', 'U') IS NOT NULL
				DROP TABLE UNIQUES; 
		IF OBJECT_ID('dbo.CHECKS', 'U') IS NOT NULL
				DROP TABLE CHECKS; 
		IF OBJECT_ID('dbo.FOREIGN_KEY', 'U') IS NOT NULL
				DROP TABLE FOREIGN_KEY; 
		IF OBJECT_ID('dbo.STORED_PROCEDURES', 'U') IS NOT NULL
				DROP TABLE STORED_PROCEDURES; 
		IF OBJECT_ID('dbo.VISTAS', 'U') IS NOT NULL
				DROP TABLE VISTAS; 
	IF (LEFT(@bdOrigen, 3)  <> 'DB_')
		print N'La base de datos ' + @bdOrigen + ' no cumple con las normas de convención de nombres (DB_NombreBaseDeDatos)';
	
	-- Declaro variables que van a usar los cursores
	
	DECLARE @query NVARCHAR(1000);
	DECLARE @tabla as varchar(100)
	DECLARE @columna as varchar(100)
	DECLARE @restriccion as varchar(100)
	DECLARE @tablaPK as varchar(100)
	DECLARE @proceso as varchar(100)
	DECLARE @vista as varchar(100)
	

	-- Obtiene las tablas de la BD Origen que previamente guardó en la tabla temporal TABLAS_BD_ORIGEN y las recorre con un cursor
	DECLARE C_TABLAS CURSOR 
	FOR 
	SELECT TABLE_NAME
	FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_CATALOG= @bdOrigen

	OPEN C_TABLAS
	FETCH NEXT FROM C_TABLAS INTO @tabla

	WHILE @@fetch_status = 0
	BEGIN
		-- Elimino tablas temporales si ya existen
		

		-- Valida la PK y su restriccion (constraint)
		SET @query = N'SELECT t2.column_name, t1.constraint_name INTO PRIMARY_KEY from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1 join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME where T1.TABLE_NAME=''' + @tabla + ''' and T1.CONSTRAINT_TYPE = ''PRIMARY KEY'' ;';
		EXEC (@query)	
		
		SET @columna = (SELECT column_name FROM PRIMARY_KEY)
		SET @restriccion = (SELECT constraint_name FROM PRIMARY_KEY)
		
		IF ( @columna  <> @tabla + 'ID')
			print N'La clave primaria "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (<NombreTabla>ID).';
		IF ( @restriccion  <> 'PK_' + @tabla )
			print N'La restriccion "' + @restriccion + '" de la PK "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (PK_<NombreTabla>).';
		

		-------------------------------------------------------------------------------
		---------------------  VALIDACION DE LAS UNIQUE CONSTRAINT --------------------
		-------------------------------------------------------------------------------
		
		SET @query = N'select t2.column_name, t1.constraint_name into UNIQUES from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1 join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME where T1.TABLE_NAME=''' + @tabla + ''' AND T1.CONSTRAINT_TYPE = ''UNIQUE'' ;';
		EXEC (@query);

		-- Declara un cursor para recorrer todas las posibles UQ constraints
		DECLARE C_UNIQUE CURSOR 
		FOR 
		SELECT column_name, constraint_name FROM UNIQUES

		OPEN C_UNIQUE
		FETCH NEXT FROM C_UNIQUE INTO @columna, @restriccion

		WHILE @@fetch_status = 0
		BEGIN

			IF ( @restriccion  <> 'UQ_' + @columna )
				print N'La restriccion "' + @restriccion + '" del campo "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (UQ_<NombreCampo>).';
			
			FETCH NEXT FROM C_UNIQUE INTO @columna, @restriccion
		END

		CLOSE C_UNIQUE
		DEALLOCATE C_UNIQUE


		-------------------------------------------------------------------------------
		---------------------  VALIDACION DE LAS CHECK CONSTRAINT ---------------------
		-------------------------------------------------------------------------------
		
		SET @query = N'select t2.column_name, t1.constraint_name into CHECKS from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1 join ' + @bdOrigen + '.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME where T1.TABLE_NAME=''' + @tabla + ''' AND T1.CONSTRAINT_TYPE = ''CHECK'' ;';
		EXEC (@query);

		-- Declara un cursor para recorrer todas las posibles CK constraints
		DECLARE C_CHECKS CURSOR 
		FOR 
		SELECT column_name, constraint_name FROM CHECKS

		OPEN C_CHECKS
		FETCH NEXT FROM C_CHECKS INTO @columna, @restriccion

		WHILE @@fetch_status = 0
		BEGIN
			-- Valida la constraint
			IF ( @restriccion  <> 'CK_' + @columna )
				print N'La restriccion "' + @restriccion + '" del campo "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (CK_<NombreCampo>).';
		
			FETCH NEXT FROM C_CHECKS INTO @columna, @restriccion
		END

		CLOSE C_CHECKS
		DEALLOCATE C_CHECKS


		-------------------------------------------------------------------------------
		-----------------------  VALIDACION DE LAS FOREIGN KEYS -----------------------
		-------------------------------------------------------------------------------
		
		SET @query = N'SELECT fk.name restriccion, t2.name tablaPK, c.name columna into FOREIGN_KEY
					FROM ' + @bdOrigen + '.sys.foreign_keys fk
					join ' + @bdOrigen + '.sys.foreign_key_columns fkc on fkc.constraint_object_id = fk.object_id
					join ' + @bdOrigen + '.sys.tables as t on fkc.parent_object_id = t.object_id
					join ' + @bdOrigen + '.sys.columns as c on fkc.parent_object_id = c.object_id and fkc.parent_column_id = c.column_id
					join ' + @bdOrigen + '.sys.tables as t2 on t2.object_id = fkc.referenced_object_id
					WHERE t.name = ''' + @tabla + ''';';
		EXEC (@query);

		-- Declara un cursor para recorrer todas las posibles FK
		DECLARE C_FOREIGN_KEY CURSOR 
		FOR 
		SELECT restriccion, tablaPK, columna FROM FOREIGN_KEY

		OPEN C_FOREIGN_KEY
		FETCH NEXT FROM C_FOREIGN_KEY INTO @restriccion, @tablaPK, @columna

		WHILE @@fetch_status = 0
		BEGIN
			-- Valida el nombre del campo
			IF ( @columna  <> @tablaPK+ 'ID' )
				print N'La clave foranea "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (FK_<NombreTabla1>_<NombreTabla2>).';
			
			-- Valida el nombre de la constraint
			IF ( @restriccion  <> 'FK_' + @tabla + '_' + @tablaPK )
				print N'La restriccion "' + @restriccion + '" del campo "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (FK_<NombreTabla1>_<NombreTabla2>).';
			
			FETCH NEXT FROM C_FOREIGN_KEY INTO  @restriccion, @tablaPK, @columna
		END

		CLOSE C_FOREIGN_KEY
		DEALLOCATE C_FOREIGN_KEY
		
						
		FETCH NEXT FROM C_TABLAS INTO @tabla
	END	

	CLOSE C_TABLAS
	DEALLOCATE C_TABLAS


	-------------------------------------------------------------------------------
	---------------------  VALIDACION DE LOS STORED PROCEDURE ---------------------
	-------------------------------------------------------------------------------
		
	SET @query = N'SELECT specific_name into STORED_PROCEDURES FROM ' + @bdOrigen + '.information_schema.routines where routine_type = ''PROCEDURE'';';
	EXEC (@query);

	-- Declara un cursor para recorrer todas los posibles SP
	DECLARE C_STORED_PROCEDURES CURSOR 
	FOR 
	SELECT specific_name FROM STORED_PROCEDURES

	OPEN C_STORED_PROCEDURES
	FETCH NEXT FROM C_STORED_PROCEDURES INTO @proceso

	WHILE @@fetch_status = 0
	BEGIN
		-- Valida el nombre del sp
		IF ( LEFT(@proceso, 3)  <> 'SP_' )
			print N'El procedimiento almacenado "' + @proceso + '" no cumple con las normas de convención de nombres (sp_<NombreStoredProcedure>).';
			
		FETCH NEXT FROM C_STORED_PROCEDURES INTO @proceso
	END

	CLOSE C_STORED_PROCEDURES
	DEALLOCATE C_STORED_PROCEDURES
		

	-------------------------------------------------------------------------------
	------------------------  VALIDACION DE LAS VISTAS  ---------------------------
	-------------------------------------------------------------------------------
		
	SET @query = N'SELECT name into VISTAS FROM ' + @bdOrigen + '.sys.views;';
	EXEC (@query);

	-- Declara un cursor para recorrer todas las posibles vistas
	DECLARE C_VISTAS CURSOR 
	FOR 
	SELECT name FROM VISTAS

	OPEN C_VISTAS
	FETCH NEXT FROM C_VISTAS INTO @vista

	WHILE @@fetch_status = 0
	BEGIN
		-- Valida el nombre de la vista
		IF ( LEFT(@vista, 2)  <> 'V_' )
			print N'La vista "' + @vista + '" no cumple con las normas de convención de nombres (v_<NombreView>).';
			
		FETCH NEXT FROM C_VISTAS INTO @vista
	END

	CLOSE C_VISTAS
	DEALLOCATE C_VISTAS
		

END TRY
BEGIN CATCH
	-- Print del error
	PRINT 'Error: ' + ERROR_MESSAGE()
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_TABLAS')) > -1
		BEGIN
			CLOSE C_TABLAS
		END
		DEALLOCATE C_TABLAS
	END
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_UNIQUE')) > -1
		BEGIN
			CLOSE C_UNIQUE
		END
		DEALLOCATE C_UNIQUE
	END
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_CHECKS')) > -1
		BEGIN
			CLOSE C_CHECKS
		END
		DEALLOCATE C_CHECKS
	END
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_FOREIGN_KEY')) > -1
		BEGIN
			CLOSE C_FOREIGN_KEY
		END
		DEALLOCATE C_FOREIGN_KEY
	END
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_STORED_PROCEDURES')) > -1
		BEGIN
			CLOSE C_STORED_PROCEDURES
		END
		DEALLOCATE C_STORED_PROCEDURES
	END
	BEGIN
		IF (SELECT CURSOR_STATUS('global','C_VISTAS')) > -1
		BEGIN
			CLOSE C_VISTAS
		END
		DEALLOCATE C_VISTAS
	END
END CATCH
GO

--EXEC SP_VALIDAR_NORMAS_CODIFICACION 'DB_Base2'
