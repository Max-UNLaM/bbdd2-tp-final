create database Z

alter proc SP_Compare @db_origen sysname, @db_destino sysname
as
	if exists(select 1 from sys.databases where name=@db_origen and name=@db_destino)
	begin
		/*Enpiezo a comparar las tablas*/
		print 'ok!!!'
	end

	else
	begin 
		if not exists(select 1 from sys.databases where name=@db_origen)
		RAISERROR(N'No existe la base de datos %s', 16, 1, @db_origen)
	
		if not exists(select 1 from sys.databases where name=@db_destino)
		RAISERROR(N'No existe la base de datos %s', 16, 1, @db_destino)
	end



exec SP_Compare 'origen', 'destino'
