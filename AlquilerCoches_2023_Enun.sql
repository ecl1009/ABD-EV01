drop table precio_combustible cascade constraints;
drop table modelos            cascade constraints;
drop table vehiculos 	      cascade constraints;
drop table clientes 	      cascade constraints;
drop table facturas	      cascade constraints;
drop table lineas_factura     cascade constraints;
drop table reservas			 cascade constraints;

drop sequence seq_modelos;
drop sequence seq_num_fact;
drop sequence seq_reservas;

create table clientes(
	NIF	varchar(9) primary key,
	nombre	varchar(20) not null,
	ape1	varchar(20) not null,
	ape2	varchar(20) not null,
	direccion varchar(40) 
);

create table precio_combustible(
	tipo_combustible	varchar(10) primary key,
	precio_por_litro	numeric(4,2) not null
);

create sequence seq_modelos;

create table modelos(
	id_modelo 		integer primary key,
	nombre			varchar(30) not null,
	precio_cada_dia 	numeric(6,2) not null check (precio_cada_dia>=0),
	capacidad_deposito	integer not null check (capacidad_deposito>0),
	tipo_combustible	varchar(10) not null references precio_combustible);


create table vehiculos(
	matricula	varchar(8)  primary key,
	id_modelo	integer  not null references modelos,
	color		varchar(10)
);

create sequence seq_reservas;
create table reservas(
	idReserva	integer primary key,
	cliente  	varchar(9) references clientes,
	matricula	varchar(8) references vehiculos,
	fecha_ini	date not null,
	fecha_fin	date,
	check (fecha_fin >= fecha_ini)
);

create sequence seq_num_fact;
create table facturas(
	nroFactura	integer primary key,
	importe		numeric( 8, 2),
	cliente		varchar(9) not null references clientes
);

create table lineas_factura(
	nroFactura	integer references facturas,
	concepto	char(40),
	importe		numeric( 7, 2),
	primary key ( nroFactura, concepto)
);
	

create or replace procedure alquilar(arg_NIF_cliente varchar,
  arg_matricula varchar, arg_fecha_ini date, arg_fecha_fin date) is
begin
  null;
end;
/

create or replace
procedure reset_seq( p_seq_name varchar )
--From https://stackoverflow.com/questions/51470/how-do-i-reset-a-sequence-in-oracle
is
    l_val number;
begin
    --Averiguo cual es el siguiente valor y lo guardo en l_val
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --Utilizo ese valor en negativo para poner la secuencia cero, pimero cambiando el incremento de la secuencia
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
   --segundo pidiendo el siguiente valor
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    --restauro el incremento de la secuencia a 1
    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/

create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_modelos' );
  reset_seq( 'seq_num_fact' );
  reset_seq( 'seq_reservas' );
        
  
    delete from lineas_factura;
    delete from facturas;
    delete from reservas;
    delete from vehiculos;
    delete from modelos;
    delete from precio_combustible;
    delete from clientes;
   
		
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras', 'C/Perezoso n1');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez', 'C/Barriocanal n1');
    
    insert into precio_combustible values ('Gasolina', 1.5);
    insert into precio_combustible values ('Gasoil',   1.4);
    
    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasolina', 15, 50, 'Gasolina');
    insert into vehiculos values ( '1234-ABC', seq_modelos.currval, 'VERDE');

    insert into modelos values ( seq_modelos.nextval, 'Renault Clio Gasoil', 16,   50, 'Gasoil');
    insert into vehiculos values ( '1111-ABC', seq_modelos.currval, 'VERDE');
    insert into vehiculos values ( '2222-ABC', seq_modelos.currval, 'GRIS');
	
    commit;
end;
/
exec inicializa_test;

create or replace procedure test_alquila_coches is
begin
	 
  --caso 1 nro dias negativo
  begin
    inicializa_test;
    alquilar('12345678A', '1234-ABC', current_date, current_date-1);
    dbms_output.put_line('MAL: Caso nro dias negativo no levanta excepcion');
  exception
    when others then
      if sqlcode=-20003 then
        dbms_output.put_line('OK: Caso nro dias negativo correcto');
      else
        dbms_output.put_line('MAL: Caso nro dias negativo levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 2 vehiculo inexistente
  begin
    inicializa_test;
    alquilar('87654321Z', '9999-ZZZ', date '2013-3-20', date '2013-3-22');
    dbms_output.put_line('MAL: Caso vehiculo inexistente no levanta excepcion');
  exception
    when others then
      if sqlcode=-20002 then
        dbms_output.put_line('OK: Caso vehiculo inexistente correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo inexistente levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 3 cliente inexistente
  begin
    inicializa_test;
    alquilar('87654321Z', '1234-ABC', date '2013-3-20', date '2013-3-22');
    dbms_output.put_line('MAL: Caso cliente inexistente no levanta excepcion');
  exception
    when others then
      if sqlcode=-20001 then
        dbms_output.put_line('OK: Caso cliente inexistente correcto');
      else
        dbms_output.put_line('MAL: Caso cliente inexistente levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end;
  
  --caso 4 Todo correcto pero NO especifico la fecha final 
  declare
                
    resultadoPrevisto varchar(200) := 
      '1234-ABC11/03/1313512345678A4 dias de alquiler, vehiculo modelo 1   60#'||
      '1234-ABC11/03/1313512345678ADeposito lleno de 50 litros de Gasolina 75';
                
    resultadoReal varchar(200)  := '';
    fila varchar(200);
  begin  
    inicializa_test;
    alquilar('12345678A', '1234-ABC', date '2013-3-11', null);
    
    SELECT listAgg(matricula||fecha_ini||fecha_fin||facturas.importe||cliente
								||concepto||lineas_factura.importe, '#')
            within group (order by nroFactura, concepto)
    into resultadoReal
    FROM facturas join lineas_factura using(NroFactura)
                  join reservas using(cliente);
								
    dbms_output.put_line('Caso Todo correcto pero NO especifico la fecha final:');
   if resultadoReal=resultadoPrevisto then
      dbms_output.put_line('--OK SI Coinciden la reserva, la factura y las linea de factura');
    else
      dbms_output.put_line('--MAL NO Coinciden la reserva, la factura o las linea de factura');
      dbms_output.put_line('resultadoPrevisto='||resultadoPrevisto);
      dbms_output.put_line('resultadoReal    ='||resultadoReal);
    end if;
    
  exception   
    when others then
       dbms_output.put_line('--MAL: Caso Todo correcto pero NO especifico la fecha final devuelve '||sqlerrm);
  end;
  
  --caso 5 Intentar alquilar un coche ya alquilado
  
  --5.1 la fecha ini del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-10 al 12
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-1, date '2013-3-11'+1);
    --Fecha ini de la reserva el 11 
	alquilar('12345678A', '1234-ABC', date '2013-3-11', date '2013-3-13');
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_ini no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado solape de fecha_ini correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_ini levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
   --5.2 la fecha fin del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-10 al 12
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-1, date '2013-3-11'+1);
    --Fecha fin de la reserva el 11 
	alquilar('12345678A', '1234-ABC', date '2013-3-7', date '2013-3-11');
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_fin no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado solape de fecha_fin correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado solape de fecha_fin levanta excepcion '||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
  --5.3 la el intervalo del alquiler esta dentro de una reserva
  begin
    inicializa_test;    
	--Reservo del 2013-3-9 al 13
	insert into reservas values
	 (seq_reservas.NEXTVAL, '11111111B', '1234-ABC', date '2013-3-11'-2, date '2013-3-11'+2);
    -- reserva del 4 al 19
	alquilar('12345678A', '1234-ABC', date '2013-3-11'-7, date '2013-3-12'+7);
	
    dbms_output.put_line('MAL: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva no levanta excepcion');
	
  exception
    when others then
      if sqlcode=-20004 then
        dbms_output.put_line('OK: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva correcto');
      else
        dbms_output.put_line('MAL: Caso vehiculo ocupado intervalo del alquiler esta dentro de una reserva levanta excepcion '
        ||sqlcode||' '||sqlerrm);
      end if;
  end; 
  
   --caso 6 Todo correcto pero SI especifico la fecha final 
  declare
                                      
    resultadoPrevisto varchar(400) := '12222-ABC11/03/1313/03/1310212345678A2 dias de alquiler, vehiculo modelo 2   32#'||
                                    '12222-ABC11/03/1313/03/1310212345678ADeposito lleno de 50 litros de Gasoil   70';
                                      
    resultadoReal varchar(400)  := '';    
    fila varchar(200);
  begin
    inicializa_test;
    alquilar('12345678A', '2222-ABC', date '2013-3-11', date '2013-3-13');
    
    SELECT listAgg(nroFactura||matricula||fecha_ini||fecha_fin||facturas.importe||cliente
								||concepto||lineas_factura.importe, '#')
            within group (order by nroFactura, concepto)
    into resultadoReal
    FROM facturas join lineas_factura using(NroFactura)
                  join reservas using(cliente);
    
    
    dbms_output.put_line('Caso Todo correcto pero SI especifico la fecha final');
    
    if resultadoReal=resultadoPrevisto then
      dbms_output.put_line('--OK SI Coinciden la reserva, la factura y las linea de factura');
    else
      dbms_output.put_line('--MAL NO Coinciden la reserva, la factura o las linea de factura');
      dbms_output.put_line('resultadoPrevisto='||resultadoPrevisto);
      dbms_output.put_line('resultadoReal    ='||resultadoReal);
    end if;
    
  exception   
    when others then
       dbms_output.put_line('--MAL: Caso Todo correcto pero SI especifico la fecha final devuelve '||sqlerrm);
  end;
 
end;
/

set serveroutput on
exec test_alquila_coches;
