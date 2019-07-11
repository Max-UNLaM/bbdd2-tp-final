
USE master
go
IF (exists(SELECT 1 FROM sys.databases WHERE name='ZETA'))
	DROP DATABASE ZETA
GO
CREATE DATABASE ZETA
GO
USE ZETA
GO
----------------------------------------------------------------
-- 1ro PASO  creo sp para las normas de codigicacion -----------
----------------------------------------------------------------
CREATE PROCEDURE SP_VALIDAR_NORMAS_CODIFICACION @bdOrigen varchar(50)
AS
	set nocount on
	print N' ';
	print N'-- NORMAS DE CONVENCION --';
	BEGIN TRY
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
		SELECT table_name FROM ##TABLAS_BD_ORIGEN

		OPEN C_TABLAS
		FETCH NEXT FROM C_TABLAS INTO @tabla

		WHILE @@fetch_status = 0
		BEGIN
		
			-- Lista de tablas temporales que uso
			-- PRIMARY_KEY
			-- UNIQUES
			-- CHECKS
			-- FOREIGN_KEY
			-- STORED_PROCEDURES
			-- VISTAS

			-- Valida la PK y su restriccion (constraint)
			SET @query = N'SELECT t2.column_name, t1.constraint_name INTO ##PRIMARY_KEY
						   from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1
						   join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME
						   where T1.TABLE_NAME=''' + @tabla + ''' and T1.CONSTRAINT_TYPE = ''PRIMARY KEY'' ;';
			EXEC (@query)	
		
			SET @columna = (SELECT column_name FROM ##PRIMARY_KEY)
			SET @restriccion = (SELECT constraint_name FROM ##PRIMARY_KEY)
		
			IF ( @columna  <> @tabla + 'ID')
				print N'La clave primaria "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (<NombreTabla>ID).';
			IF ( @restriccion  <> 'PK_' + @tabla )
				print N'La restriccion "' + @restriccion + '" de la PK "' + @columna + '" de la tabla "' + @tabla + '" no cumple con las normas de convención de nombres (PK_<NombreTabla>).';
		

			-------------------------------------------------------------------------------
			---------------------  VALIDACION DE LAS UNIQUE CONSTRAINT --------------------
			-------------------------------------------------------------------------------
			SET @query = N'select t2.column_name, t1.constraint_name into ##UNIQUES
						   from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1
						   join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME
						   where T1.TABLE_NAME=''' + @tabla + ''' AND T1.CONSTRAINT_TYPE = ''UNIQUE'' ;';
			EXEC (@query);

			-- Declara un cursor para recorrer todas las posibles UQ constraints
			DECLARE C_UNIQUE CURSOR 
			FOR 
			SELECT column_name, constraint_name FROM ##UNIQUES

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
		
			SET @query = N'select t2.column_name, t1.constraint_name into ##CHECKS
						   from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1
						   join ' + @bdOrigen + '.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME 
						   where T1.TABLE_NAME=''' + @tabla + ''' AND T1.CONSTRAINT_TYPE = ''CHECK'' ;';
			EXEC (@query);

			-- Declara un cursor para recorrer todas las posibles CK constraints
			DECLARE C_CHECKS CURSOR 
			FOR 
			SELECT column_name, constraint_name FROM ##CHECKS

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
		
			SET @query = N'SELECT fk.name restriccion, t2.name tablaPK, c.name columna into ##FOREIGN_KEY
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
			SELECT restriccion, tablaPK, columna FROM ##FOREIGN_KEY

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
			
			--Elimino manualmente las tablas temporales
			DROP TABLE ##PRIMARY_KEY
			DROP TABLE ##UNIQUES
			DROP TABLE ##CHECKS
			DROP TABLE ##FOREIGN_KEY
						
			FETCH NEXT FROM C_TABLAS INTO @tabla
		END	

		CLOSE C_TABLAS
		DEALLOCATE C_TABLAS


		-------------------------------------------------------------------------------
		---------------------  VALIDACION DE LOS STORED PROCEDURE ---------------------
		-------------------------------------------------------------------------------
		
		SET @query = N'SELECT specific_name into ##STORED_PROCEDURES
					   FROM ' + @bdOrigen + '.information_schema.routines
					   where routine_type = ''PROCEDURE'';';
		EXEC (@query);

		-- Declara un cursor para recorrer todas los posibles SP
		DECLARE C_STORED_PROCEDURES CURSOR 
		FOR 
		SELECT specific_name FROM ##STORED_PROCEDURES

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
		
		SET @query = N'SELECT name into ##VISTAS FROM ' + @bdOrigen + '.sys.views;';
		EXEC (@query);

		-- Declara un cursor para recorrer todas las posibles vistas
		DECLARE C_VISTAS CURSOR 
		FOR 
		SELECT name FROM ##VISTAS

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

----------------------------------------------------------------
-- 2ro PASO  creo sp para eliminar restricciones ---------------
----------------------------------------------------------------
CREATE PROCEDURE SP_ELIMINAR_RESTRICCIONES @bd varchar(50), @tabla varchar(50), @columna varchar(50)
AS
	BEGIN TRY
		-- Nombre de la tabla temporal
			-- RESTRICCIONES;
		set nocount on
		print N' ';
		print N'-- ELIMINAR RESTRECCIONES PARA REALIZAR LOS CAMBIOS si existen --';
		DECLARE @query NVARCHAR(1000);
		-- Guarda las restricciones en la tabla temporal RESTRICCIONES para luego recorrerla y eliminarlas
		SET @query = N'SELECT d.name restriccion INTO ##RESTRICCIONES
					   FROM [' + @bd + '].sys.default_constraints d
					   INNER JOIN [' + @bd + '].sys.columns c ON d.parent_column_id = c.column_id
					   WHERE d.parent_object_id = OBJECT_ID(N''[' + @bd + '].dbo.' + @tabla +''', N''U'') AND c.name = ''' + @columna + ''';';

		EXEC (@query)
	
		IF EXISTS(SELECT * FROM ##RESTRICCIONES)
		BEGIN
			-- Declara el cursor para recorrer las restricciones	
			DECLARE @restriccion as varchar(200)

			DECLARE C_RESTRICCIONES CURSOR 
			FOR SELECT restriccion FROM ##RESTRICCIONES

			OPEN C_RESTRICCIONES
			FETCH NEXT FROM C_RESTRICCIONES INTO @restriccion

			SET @query = ''

			WHILE @@fetch_status = 0
			BEGIN
				-- Elimina las restricciones una por una
				SET @query = 'ALTER TABLE [' + @bd + '].dbo.' + @tabla + ' DROP CONSTRAINT  ' + @restriccion + ';';
							
				print @query;
				-- EXEC (@query);
							
				FETCH NEXT FROM C_RESTRICCIONES INTO @restriccion
			END
			CLOSE C_RESTRICCIONES
			DEALLOCATE C_RESTRICCIONES
		END
		DROP TABLE ##RESTRICCIONES
	END TRY
	BEGIN CATCH
		-- Print del error y cierra el cursor si quedó abierto
		PRINT 'Error: ' + ERROR_MESSAGE()

		IF (SELECT CURSOR_STATUS('global','C_RESTRICCIONES')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_RESTRICCIONES')) > -1
			BEGIN
				CLOSE C_RESTRICCIONES
			END
			DEALLOCATE C_RESTRICCIONES
		END
	END CATCH
GO

----------------------------------------------------------------
-- 3ro PASO creo sp para agregar tablas en el DB destino -------
----------------------------------------------------------------
CREATE PROCEDURE SP_AGREGAR_TABLA @tabla varchar(50), @bdOrigen varchar(50), @bdDestino varchar(50)
AS
	BEGIN TRY
		-- Nombres de las tablas temporales
			-- CAMPOS_ORIGEN; 
			-- PRIMARY_KEY_ORIGEN; 
			-- UNIQUE_ORIGEN; 
		set nocount on
		print N' ';
		print N'-- POSIBLES CAMBIOS A REALIZAR EN LA BASE DE DATOS INDICADAS si existen --';
		DECLARE @query NVARCHAR(1000);
		--  guardo en la tabla temporal CAMPOS_ORIGEN todos los campos que tiene la tabla origen
		SET @query = N'select column_name, column_default, is_nullable, data_type, character_maximum_length into ##CAMPOS_ORIGEN
					   from ' + @bdOrigen + '.INFORMATION_SCHEMA.COLUMNS
					   where TABLE_NAME=''' + @tabla + ''';';
		EXEC (@query);
					
		SET @query = N'select t2.column_name, t1.constraint_name into ##PRIMARY_KEY_ORIGEN
					   from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1 
					   join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME
					   where T1.TABLE_NAME=''' + @tabla + ''' and T1.CONSTRAINT_TYPE = ''PRIMARY KEY'' ;';
		EXEC (@query);

		SET @query = N'select t2.column_name, t1.constraint_name into ##UNIQUE_ORIGEN
					   from ' + @bdOrigen + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS T1
					   join ' + @bdOrigen + '.INFORMATION_SCHEMA.KEY_COLUMN_USAGE T2 ON T2.CONSTRAINT_NAME = T1.CONSTRAINT_NAME
					   where T1.TABLE_NAME=''' + @tabla + ''' AND T1.CONSTRAINT_TYPE = ''UNIQUE'' ;';
		EXEC (@query);

		-- Declaro variables que van a usar los cursores
		DECLARE @columna as varchar(50)
		DECLARE @valor_defecto as varchar(50)
		DECLARE @permite_null as varchar(50)
		DECLARE @tipo as varchar(50)
		DECLARE @tamanio as varchar(50)
		DECLARE @restriccion  as varchar(100)

		------------------------------------------------------------------
		------- CREATE TABLE PARA AGREGAR LA TABLA A LA BD DESTINO -------
		------------------------------------------------------------------
			
		IF EXISTS(SELECT 1 FROM ##CAMPOS_ORIGEN) --> comprobamos si hay tablas para agregar en destino
		BEGIN
			-- CREATE TABLE EN TABLA DESTINO
			DECLARE C_CAMPOS_ORIGEN CURSOR 
			FOR SELECT column_name, column_default, is_nullable, data_type, character_maximum_length FROM ##CAMPOS_ORIGEN
		
			OPEN C_CAMPOS_ORIGEN
			FETCH NEXT FROM C_CAMPOS_ORIGEN INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

			SET @query = 'CREATE TABLE [' + @bdDestino + '].dbo.' + @tabla + ' (';

			WHILE @@fetch_status = 0
			BEGIN

				SET @query += ' ' + @columna + ' ' + @tipo;

				IF (@tamanio IS NOT NULL AND @tamanio != '')
					SET @query += '(' + @tamanio +  ')';
					
				IF (@permite_null = 'NO')
					SET @query += ' NOT NULL';

				IF (@valor_defecto IS NOT NULL)
					SET @query += ' DEFAULT ' + @valor_defecto +  ' ';

				SET @query += ',';
					
				FETCH NEXT FROM C_CAMPOS_ORIGEN INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio
					
			END
			CLOSE C_CAMPOS_ORIGEN
			DEALLOCATE C_CAMPOS_ORIGEN

			------- Este bloque es para remover la última coma "," que se agrego 8 lineas mas arriba cuando se agrega el ultimo atributo.
			SET @query = 
					CASE @query WHEN null THEN null 
					ELSE (
						CASE LEN(@query) WHEN 0 THEN @query 
						ELSE LEFT(@query, LEN(@query) - 1) 
						END 
					) END
			------- Fin del bloque para remover la coma "," -------------------------------------------
				
			-- Cierra el Create table
			SET @query += ' );'
					
			-- Ejecuta primero el Create table, luego se le agregarán las keys
			print @query;
			-- EXEC (@query);

		END

		------------------------------------------------------------------
		-------- ALTER TABLE PARA AGREGAR LA PRIMARY KEY -----------------
		------------------------------------------------------------------
		IF EXISTS(SELECT 1 FROM ##PRIMARY_KEY_ORIGEN)
		BEGIN

			DECLARE C_PRIMARY_KEY_ORIGEN CURSOR 
			FOR SELECT column_name, constraint_name FROM ##PRIMARY_KEY_ORIGEN
		
			OPEN C_PRIMARY_KEY_ORIGEN
			FETCH NEXT FROM C_PRIMARY_KEY_ORIGEN INTO @columna, @restriccion

			SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ADD CONSTRAINT PK_' + @tabla + ' PRIMARY KEY (';

			WHILE @@fetch_status = 0
			BEGIN

				SET @query += ' ' + @columna + ', '; -- Se agrega la coma por si es una PK compuesta
					
				FETCH NEXT FROM C_PRIMARY_KEY_ORIGEN INTO @columna, @restriccion
					
			END
			CLOSE C_PRIMARY_KEY_ORIGEN
			DEALLOCATE C_PRIMARY_KEY_ORIGEN

			------- Este bloque es para remover la última coma "," que se agrego 8 lineas mas ariba ----
			SET @query = 
					CASE @query WHEN null THEN null 
					ELSE (
						CASE LEN(@query) WHEN 0 THEN @query 
						ELSE LEFT(@query, LEN(@query) - 1) 
						END 
					) END
			------- Fin del bloque para remover la coma "," -------------------------------------------

			SET @query += ');'

			-- Ejecuta el Alter table para agregar las keys			
			print @query;
			-- EXEC (@query);
		END
			
		-------------------------------------------------------------------
		--------------- ALTER TABLE PARA AGREGAR LAS UNIQUE ---------------
		-------------------------------------------------------------------

		IF EXISTS(SELECT 1 FROM ##UNIQUE_ORIGEN)
		BEGIN

			DECLARE C_UNIQUE_ORIGEN CURSOR 
			FOR SELECT column_name, constraint_name FROM ##UNIQUE_ORIGEN
		
			OPEN C_UNIQUE_ORIGEN
			FETCH NEXT FROM C_UNIQUE_ORIGEN INTO @columna, @restriccion

			WHILE @@fetch_status = 0
			BEGIN

				SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ADD CONSTRAINT UQ_' + @tabla + ' UNIQUE (' + @columna + ');'; 
				
				-- Ejecuta el Alter table para agregar la restricción UNIQUE	
				print @query;
				-- EXEC (@query);
					
				FETCH NEXT FROM C_UNIQUE_ORIGEN INTO @columna, @restriccion
					
			END
			CLOSE C_UNIQUE_ORIGEN
			DEALLOCATE C_UNIQUE_ORIGEN

		END
		-- Elimino las tablas temporales manualmente porque sino en la otra iteracion se chocan
		DROP TABLE ##CAMPOS_ORIGEN
		DROP TABLE ##PRIMARY_KEY_ORIGEN 
		DROP TABLE ##UNIQUE_ORIGEN
	END TRY
	BEGIN CATCH
		-- Print del error y cierra los cursores si quedaron abiertos
		PRINT 'Error: ' + ERROR_MESSAGE()

		IF (SELECT CURSOR_STATUS('global','C_CAMPOS_ORIGEN')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_CAMPOS_ORIGEN')) > -1
			BEGIN
				CLOSE C_CAMPOS_ORIGEN
			END
			DEALLOCATE C_CAMPOS_ORIGEN
		END
		IF (SELECT CURSOR_STATUS('global','C_PRIMARY_KEY_ORIGEN')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_PRIMARY_KEY_ORIGEN')) > -1
			BEGIN
				CLOSE C_PRIMARY_KEY_ORIGEN
			END
			DEALLOCATE C_PRIMARY_KEY_ORIGEN
		END
		IF (SELECT CURSOR_STATUS('global','C_UNIQUE_ORIGEN')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_UNIQUE_ORIGEN')) > -1
			BEGIN
				CLOSE C_UNIQUE_ORIGEN
			END
			DEALLOCATE C_UNIQUE_ORIGEN
		END
	END CATCH
GO

----------------------------------------------------------------
-- 4ro PASO creo sp para comparar tablas -----------------------
----------------------------------------------------------------
CREATE PROCEDURE SP_COMPARAR_TABLA @tabla varchar(50), @bdOrigen varchar(50), @bdDestino varchar(50)
AS
	BEGIN TRY
		-- nombres de las tablas temporales.
			-- ORIG; 
			-- DEST; 
			-- DIFERENCIAS; 
			-- CAMBIOS_ORIG; 
			-- CAMBIOS_DEST; 
		set nocount on
		print N' ';
		print N'-- POSIBLES CAMBIOS A REALIZAR EN LA TABLAS INDICADAS si existen --';
		-- Guarda los datos de la tabla de cada BD, en las tablas temporales ORIG y DEST
		DECLARE @query NVARCHAR(1000);
		SET @query = N'select table_catalog, table_name, column_name, column_default, is_nullable, data_type, character_maximum_length into ##ORIG
					   from ' + @bdOrigen + '.information_schema.columns
					   where table_name = ''' + @tabla + ''';';
		EXEC (@query)

		SET @query = N'select table_catalog, table_name, column_name, column_default, is_nullable, data_type, character_maximum_length into ##DEST
					   from ' + @bdDestino + '.information_schema.columns
					   where table_name = ''' + @tabla + ''';';
		EXEC (@query)

		-- Guarda en la tabla temporal CAMBIOS_ORIG los campos que no existen en la Tabla DEST
		SELECT * INTO ##CAMBIOS_ORIG FROM ##ORIG where column_name not in (SELECT column_name FROM ##DEST)

		-- Guarda en la tabla temporal CAMBIOS_DEST las columnas que existen en la tabla DEST pero no en la ORIG
		SELECT * INTO ##CAMBIOS_DEST FROM ##DEST where column_name not in (SELECT column_name FROM ##ORIG)

		-- Guarda en la tabla temporal DIFERENCIAS las columnas que existen en la ORIG y en la DEST pero tienen alguna diferencia
		SELECT O.table_catalog, O.table_name, O.column_name, O.column_default, O.is_nullable, O.data_type, O.character_maximum_length INTO ##DIFERENCIAS FROM ##ORIG O LEFT JOIN ##DEST D ON D.column_name = O.column_name where
				D.is_nullable <> O.is_nullable OR
				D.data_type <> O.data_type OR
				D.column_default <> O.column_default OR
				D.character_maximum_length <> O.character_maximum_length OR
				-- Estas comparaciones con IS NULL e IS NOT NULL se agregan porque al comparar si un valor es diferente a NULL, devuelve UNKNOWN lo que se traduce a FALSE en lugar de TRUE, por más que sean diferentes
				-- Supuestamente deberia solucionarse con un SET ANSI_NULLS OFF pero como no me sirvió, tuve que manejarlo asi.
				(D.column_default IS NULL AND O.column_default IS NOT NULL) OR
				(D.column_default IS NOT NULL AND O.column_default IS  NULL) OR
				(D.character_maximum_length IS NULL AND O.character_maximum_length IS NOT NULL) OR
				(D.character_maximum_length IS NOT NULL AND O.character_maximum_length IS  NULL)


		-- Declaro variables que van a usar los cursores
		DECLARE @columna as varchar(50)
		DECLARE @valor_defecto as varchar(50)
		DECLARE @permite_null as varchar(50)
		DECLARE @tipo as varchar(50)
		DECLARE @tamanio as varchar(50)

		---------------------------------------------------------------
		------- ALTER TABLE PARA LOS CAMBIOS DE LAS DIFERENCIAS -------
		---------------------------------------------------------------
		IF EXISTS(SELECT * FROM ##DIFERENCIAS)
		BEGIN
			-- Si existen diferencias, las carga en un cursor y recorre para hacer el Alter Table ALTER COLUMN para cada una
			DECLARE C_CAMBIOS_DIFERENCIAS CURSOR 
			FOR 
			SELECT column_name, column_default, is_nullable, data_type, character_maximum_length FROM ##DIFERENCIAS
		
			OPEN C_CAMBIOS_DIFERENCIAS
			FETCH NEXT FROM C_CAMBIOS_DIFERENCIAS INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

			SET @query = ''

			WHILE @@fetch_status = 0
			BEGIN
				-- IMPORTANTE: Antes del alter column hay que eliminar las restricciones de esta campo !! Sino no deja eliminar o alterar el campo
				-- EXEC SP_ELIMINAR_RESTRICCIONES @bdDestino, @tabla, @columna --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

				SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ALTER COLUMN ' + @columna + ' ' + @tipo;

				IF (@tamanio IS NOT NULL AND @tamanio != '')
					SET @query += ' (' + @tamanio +  ') ';
					
				IF (@permite_null = 'NO')
					SET @query += ' NOT NULL ';
					
				print @query;
				-- EXEC (@query);
					
				-- Si tiene valor por defecto, se agrega acá, luego del alter column. Ya que es una restricción y estas se agregan como CONSTRAINT
				IF (@valor_defecto IS NOT NULL AND @valor_defecto != '')
				BEGIN
					SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ADD CONSTRAINT DF_' + @columna + ' DEFAULT ' + REPLACE(REPLACE(@valor_defecto,'(',''), ')','') + ' FOR ' + @columna ; -- Quito los parentesis adicionales para que no rompa
				
					print @query;
					-- EXEC (@query);
				END;
				FETCH NEXT FROM C_CAMBIOS_DIFERENCIAS INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

			END
			CLOSE C_CAMBIOS_DIFERENCIAS
			DEALLOCATE C_CAMBIOS_DIFERENCIAS

		END

		----------------------------------------------------------------------------------------
		------- ALTER TABLE PARA AGREGAR EL CAMPO FALTANTE A LA TABLA DESTINO ------------------
		----------------------------------------------------------------------------------------
		IF EXISTS(SELECT * FROM ##CAMBIOS_ORIG)
		BEGIN
			-- Si existen columnas en la BD Origen, las carga en un cursor y recorre para hacer el Alter Table ADD COLUMN para cada una
			DECLARE C_CAMBIOS_ORIG CURSOR 
			FOR 
			SELECT column_name, column_default, is_nullable, data_type, character_maximum_length FROM ##CAMBIOS_ORIG
				
			OPEN C_CAMBIOS_ORIG
			FETCH NEXT FROM C_CAMBIOS_ORIG INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

			SET @query = ''

			WHILE @@fetch_status = 0
			BEGIN

				SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ADD ' + @columna + ' ' + @tipo;

				IF (@tamanio IS NOT NULL AND @tamanio != '')
					SET @query += ' (' + @tamanio +  ') ';
					
				IF (@permite_null = 'NO')
					SET @query += ' NOT NULL ';

				SET @query += ';';
					
				print @query;
				-- EXEC (@query);
					
				-- Si tiene valor por defecto, se agrega acá, luego del alter column. Ya que es una restricción y estas se agregan como CONSTRAINT
				IF (@valor_defecto IS NOT NULL AND @valor_defecto != '')
				BEGIN
					SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ADD CONSTRAINT DF_' + @columna + ' DEFAULT ' + REPLACE(REPLACE(@valor_defecto,'(',''), ')','') + ' FOR ' + @columna ; -- Quito los parentesis adicionales para que no rompa
				
					print @query;
					-- EXEC (@query);
				END

				FETCH NEXT FROM C_CAMBIOS_ORIG INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

			END
			CLOSE C_CAMBIOS_ORIG
			DEALLOCATE C_CAMBIOS_ORIG

		END

		----------------------------------------------------------------------------------------------------------
		------- ALTER TABLE PARA ELIMINAR LOS CAMPOS SOBRANTES DE LA TABLA DESTINO -------------------------------
		----------------------------------------------------------------------------------------------------------
		IF EXISTS(SELECT 1 FROM ##CAMBIOS_DEST)
		BEGIN
			-- Si existen columnas solo en la BD Destino, las carga en un cursor y recorre para hacer el Alter Table DROP COLUMN para cada una
			DECLARE C_CAMBIOS_DEST CURSOR 
			FOR 
			SELECT column_name FROM ##CAMBIOS_DEST
		
			OPEN C_CAMBIOS_DEST
			FETCH NEXT FROM C_CAMBIOS_DEST INTO @columna

			SET @query = ''

			WHILE @@fetch_status = 0
			BEGIN
				-- IMPORTANTE: Antes del alter column hay que eliminar las restricciones de esta columna !! Sino no deja eliminar o alterar la columna
				EXEC SP_ELIMINAR_RESTRICCIONES @bdDestino, @tabla, @columna

				SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' DROP COLUMN ' + @columna;
					
				print @query;
				-- EXEC (@query);
					
				FETCH NEXT FROM C_CAMBIOS_DEST INTO @columna

			END
			CLOSE C_CAMBIOS_DEST
			DEALLOCATE C_CAMBIOS_DEST

		END
		DROP TABLE ##ORIG
		DROP TABLE ##DEST
		DROP TABLE ##DIFERENCIAS
		DROP TABLE ##CAMBIOS_ORIG
		DROP TABLE ##CAMBIOS_DEST
	END TRY
	BEGIN CATCH
		-- Print del error y cierra los cursores si quedaron abiertos
		PRINT 'Error: ' + ERROR_MESSAGE()

		IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_DIFERENCIAS')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_DIFERENCIAS')) > -1
			BEGIN
				CLOSE C_CAMBIOS_DIFERENCIAS
			END
			DEALLOCATE C_CAMBIOS_DIFERENCIAS
		END
		IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_ORIG')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_ORIG')) > -1
			BEGIN
				CLOSE C_CAMBIOS_ORIG
			END
			DEALLOCATE C_CAMBIOS_ORIG
		END
		IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_DEST')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_CAMBIOS_DEST')) > -1
			BEGIN
				CLOSE C_CAMBIOS_DEST
			END
			DEALLOCATE C_CAMBIOS_DEST
		END
	END CATCH
GO

----------------------------------------------------------------
-- 5ro PASO creo sp para comparar las DB -----------------------
----------------------------------------------------------------
CREATE PROCEDURE SP_COMPARAR_BASES @bdOrigen varchar(50), @bdDestino varchar(50)
AS
	set nocount on
	BEGIN TRY
		IF EXISTS(SELECT * FROM SYS.DATABASES WHERE NAME = @bdOrigen)
		BEGIN
			IF EXISTS(SELECT * FROM SYS.DATABASES WHERE NAME = @bdDestino)
			BEGIN
				-- Nombres de las tamblas temporales
					-- TABLAS_BD_ORIGEN; 
					-- TABLAS_BD_DESTINO; 
					-- TABLAS_SOLO_BD_ORIGEN; 
					-- TABLAS_SOLO_BD_DESTINO; 
					-- TABLAS_AMBAS_BD;
			 
				DECLARE @query NVARCHAR(1000);

				-- Obtiene las tablas de la BD Origen y las guarda en la tabla temporal TABLAS_BD_ORIGEN
				SET @query = N'SELECT table_catalog, table_name INTO ##TABLAS_BD_ORIGEN FROM ' + @bdOrigen + '.information_schema.TABLES WHERE TABLE_TYPE=''BASE TABLE'';';
				EXEC (@query)

				-- Obtiene las tablas de la BD Destino y las guarda en la tabla temporal TABLAS_BD_DESTINO
				SET @query = N'SELECT table_catalog, table_name INTO ##TABLAS_BD_DESTINO FROM ' + @bdDestino + '.information_schema.TABLES WHERE TABLE_TYPE=''BASE TABLE'';';
				EXEC (@query)

				-- Guarda en la tabla temporal TABLAS_SOLO_BD_ORIGEN las tablas que existen en la BD origen pero no en la BD destino
				SELECT * INTO ##TABLAS_SOLO_BD_ORIGEN FROM ##TABLAS_BD_ORIGEN where table_name not in (SELECT table_name FROM ##TABLAS_BD_DESTINO)

				-- Guarda en la tabla temporal TABLAS_SOLO_BD_DESTINO las tablas que existen en la BD destino pero no en la BD origen
				SELECT * INTO ##TABLAS_SOLO_BD_DESTINO FROM ##TABLAS_BD_DESTINO where table_name not in (SELECT table_name FROM ##TABLAS_BD_ORIGEN)
		
				-- Guarda en la tabla temporal TABLAS_AMBAS_BD las tablas que existen en la BD origen y en la BD destino pero quizas tienen alguna diferencia
				SELECT * INTO ##TABLAS_AMBAS_BD FROM ##TABLAS_BD_ORIGEN where table_name in (SELECT table_name FROM ##TABLAS_BD_DESTINO)

				-- Declaro variables que van a usar los tres cursores
				DECLARE @tabla as varchar(50)
		
				-------------------------------------------------------------------------------------------------------
				------- EJECUTA EL SP PARA AGREGAR EN LA BD DESTINO LAS TABLAS QUE EXISTEN SOLO EN LA BD ORIGEN -------
				-------------------------------------------------------------------------------------------------------
				IF EXISTS(SELECT * FROM ##TABLAS_SOLO_BD_ORIGEN)
				BEGIN
				
					-- Si existen tablas solo en la BD origen, las carga en un cursor y recorre para insertarlas en la de BD Destino
					DECLARE C_TABLAS_SOLO_BD_ORIGEN CURSOR 
					FOR 
					SELECT table_name FROM ##TABLAS_SOLO_BD_ORIGEN

					OPEN C_TABLAS_SOLO_BD_ORIGEN
					FETCH NEXT FROM C_TABLAS_SOLO_BD_ORIGEN INTO @tabla

					WHILE @@fetch_status = 0
					BEGIN
						-- Inserta cada tabla en la BD Destino con el SP_AGREGAR_TABLA
						EXEC SP_AGREGAR_TABLA @tabla, @bdOrigen, @bdDestino;
							
						FETCH NEXT FROM C_TABLAS_SOLO_BD_ORIGEN INTO @tabla
					END

					CLOSE C_TABLAS_SOLO_BD_ORIGEN
					DEALLOCATE C_TABLAS_SOLO_BD_ORIGEN

				END

				---------------------------------------------------------------------------------------------------------
				------- EJECUTA EL SP PARA ELIMINAR EN LA BD DESTINO LAS TABLAS QUE SOLO EXISTEN EN LA BD DESTINO -------
				---------------------------------------------------------------------------------------------------------

				IF EXISTS(SELECT * FROM ##TABLAS_SOLO_BD_DESTINO)
				BEGIN
				
					-- Si existen tablas solo en la BD Destino, las carga en un cursor y recorre para borrarlas
					DECLARE C_TABLAS_SOLO_BD_DESTINO CURSOR 
					FOR 
					SELECT table_name FROM ##TABLAS_SOLO_BD_DESTINO
				
					OPEN C_TABLAS_SOLO_BD_DESTINO
					FETCH NEXT FROM C_TABLAS_SOLO_BD_DESTINO INTO @tabla

					WHILE @@fetch_status = 0
					BEGIN
						-- Usamos una sentencia porque no vale la pena crear un SP solo para un Drop Table
						SET @query = N'DROP TABLE ' + @bdDestino + '.dbo.' + @tabla; 
						print @query;
						-- EXEC (@query)
							
						FETCH NEXT FROM C_TABLAS_SOLO_BD_DESTINO INTO @tabla
					END

					CLOSE C_TABLAS_SOLO_BD_DESTINO
					DEALLOCATE C_TABLAS_SOLO_BD_DESTINO
				
				END

				------------------------------------------------------------------------------------------------------------------
				------- EJECUTA EL SP PARA LOS CAMBIOS DE LAS TABLAS QUE EXISTEN EN AMBAS BD PERO PUEDEN TENER DIFERENCIAS -------
				------------------------------------------------------------------------------------------------------------------
				IF EXISTS(SELECT * FROM ##TABLAS_AMBAS_BD)
				BEGIN
					-- Si existen tablas en comun, las carga en un cursor y lo recorre comparandolas
					DECLARE C_TABLAS_AMBAS_BD CURSOR 
					FOR 
					SELECT table_name FROM ##TABLAS_AMBAS_BD

					OPEN C_TABLAS_AMBAS_BD
					FETCH NEXT FROM C_TABLAS_AMBAS_BD INTO @tabla

					WHILE @@fetch_status = 0
					BEGIN
						-- Compara cada tabla con el SP_AGREGAR_TABLA
						EXEC SP_COMPARAR_TABLA @tabla, @bdOrigen, @bdDestino;
							
						FETCH NEXT FROM C_TABLAS_AMBAS_BD INTO @tabla
					END

					CLOSE C_TABLAS_AMBAS_BD
					DEALLOCATE C_TABLAS_AMBAS_BD

				END

				-----------------------------------------------------------------------------------------------------------
				------- EJECUTA EL SP PARA VALIDAR LAS NORMAS DE CODIFICACION EN LA PRIMER BASE DE DATOS (BDOrigen) -------
				-----------------------------------------------------------------------------------------------------------
				EXEC SP_VALIDAR_NORMAS_CODIFICACION @bdOrigen 


			END
			ELSE RAISERROR(N'No existe la BD: %s', 16, 1, @bdDestino)
		END 
		ELSE RAISERROR(N'No existe la BD: %s', 16, 1, @bdOrigen)
		
	END TRY
	BEGIN CATCH
		-- Print del error
		PRINT 'Error: ' + ERROR_MESSAGE()
		-- Cierra los cursores por si alguno quedó abierto
		IF (SELECT CURSOR_STATUS('global','C_TABLAS_AMBAS_BD')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_TABLAS_AMBAS_BD')) > -1
			BEGIN
				CLOSE C_TABLAS_AMBAS_BD
			END
			DEALLOCATE C_TABLAS_AMBAS_BD
		END
		IF (SELECT CURSOR_STATUS('global','C_TABLAS_SOLO_BD_ORIGEN')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_TABLAS_SOLO_BD_ORIGEN')) > -1
			BEGIN
				CLOSE C_TABLAS_SOLO_BD_ORIGEN
			END
			DEALLOCATE C_TABLAS_SOLO_BD_ORIGEN
		END
		IF (SELECT CURSOR_STATUS('global','C_TABLAS_SOLO_BD_DESTINO')) >= -1
		BEGIN
			IF (SELECT CURSOR_STATUS('global','C_TABLAS_SOLO_BD_DESTINO')) > -1
			BEGIN
				CLOSE C_TABLAS_SOLO_BD_DESTINO
			END
			DEALLOCATE C_TABLAS_SOLO_BD_DESTINO
		END
	END CATCH
GO


--> EXEC SP_COMPARAR_BASES 'DB_Origen', 'DB_Destino';

