
---------------------------------------------------------------------
-- 3ro PASO creo sp para comparar los campos de la tabla en curso ---
---------------------------------------------------------------------
-- para este paso ya se supone que existen el bdOrigen y bdDestino con tablas similares (tabla con el mismo nombre)
ALTER PROCEDURE SP_COMPARAR_TABLA @tabla varchar(50), @bdOrigen varchar(50), @bdDestino varchar(50)
AS
BEGIN TRY
	-- nombres de las tablas temporales globales.
		-- ORIG; 
		-- DEST; 
		-- DIFERENCIAS; 
		-- CAMBIOS_ORIG; 
		-- CAMBIOS_DEST; 
	set nocount on
	-- Guarda los datos de la tabla de cada BD, en las tablas temporales ORIG y DEST
	DECLARE @query NVARCHAR(1000);
	SET @query = N'select table_catalog, table_name, column_name, column_default, is_nullable, data_type, character_maximum_length into ##ORIG from ' + @bdOrigen + '.information_schema.columns where table_name = ''' + @tabla + ''';';
	EXEC (@query)

	SET @query = N'select table_catalog, table_name, column_name, column_default, is_nullable, data_type, character_maximum_length into ##DEST from ' + @bdDestino + '.information_schema.columns where table_name = ''' + @tabla + ''';';
	EXEC (@query)

	-- Guarda en la tabla temporal CAMBIOS_ORIG las columnas que existen en la tabla ORIG pero no en la DEST
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
			-- IMPORTANTE: Antes del alter column hay que eliminar las restricciones de esta columna !! Sino no deja eliminar o alterar la columna
			-- EXEC SP_ELIMINAR_RESTRICCIONES @bdDestino, @tabla, @columna --|||||||||||| falta eliminar restricciones ||||||||||||||||||||||||

			SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' ALTER COLUMN ' + @columna + ' ' + @tipo;

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
			END;
			FETCH NEXT FROM C_CAMBIOS_DIFERENCIAS INTO @columna, @valor_defecto, @permite_null, @tipo, @tamanio

		END
		CLOSE C_CAMBIOS_DIFERENCIAS
		DEALLOCATE C_CAMBIOS_DIFERENCIAS

	END

	----------------------------------------------------------------------------------------
	------- ALTER TABLE PARA AGREGAR LOS CAMBIOS DE CAMBIOS_ORIG EN LA TABLA DESTINO -------
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
	------- ALTER TABLE PARA ELIMINAR LO QUE SOBRE EN LA TABLA DESTINO (El contenido de CAMBIOS_DEST ) -------
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

			SET @query = 'ALTER TABLE [' + @bdDestino + '].dbo.' + @tabla + ' DROP COLUMN ' + @columna + ';';
					
			print @query;
			-- EXEC (@query);
					
			FETCH NEXT FROM C_CAMBIOS_DEST INTO @columna

		END
		CLOSE C_CAMBIOS_DEST
		DEALLOCATE C_CAMBIOS_DEST

	END
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

exec SP_COMPARAR_TABLA 'tabla','DB_Origen','DB_Destino'