CREATE TABLE sap_regiextra (
estructura  char(50),
fecha_corrida	datetime year to second,
modo_corrida   char(1),
numero_cliente integer,
cant_registros decimal(10,0),
nombre_archivo varchar(100)
);

GRANT select ON sap_regiextra  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_regiextra  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_regiextra  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_regiextra  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

CREATE TABLE sap_gen_archivos (
sistema				char(10) not null,
tipo_archivo		char(20) not null,
correlativo			integer  not null);

GRANT select ON sap_gen_archivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_gen_archivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_gen_archivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_gen_archivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


-- Esta tabla podrá tener mas campos en funcion
-- de mas objetos que tengan como referencia unica
-- al cliente.

CREATE TABLE sap_regi_cliente(
numero_cliente	integer not null,
fecha_val_tarifa	date,
fecha_alta_real   date,
interloc_comercial	char(1),
cuenta_contrato		char(1),
obj_conexion		char(1),
pto_suministro		char(1),
instalacion			char(1),
ubica_apa			char(1),
montaje				char(1),
desmontaje			char(1),
move_in				char(1),
move_out			char(1),
lecturas			char(1),
facturas			char(1),
histo_cnr			char(1),
modif				char(1),
operando_vip		char(1),
operando_tis		char(1),
depgar            char(1),
billdoc           char(1),
facts_bim         char(1),
fica              char(1),
fecha_move_in		date
);

CREATE UNIQUE INDEX inx01sap_regi_cliente ON sap_regi_cliente (numero_cliente);

GRANT select ON sap_regi_cliente  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_regi_cliente  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_regi_cliente  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_regi_cliente  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

CREATE TABLE sap_transforma (
clave	char(20) not null,
cod_mac	char(10) not null,
cod_sap char(10),
descripcion char(60),
valor_entero	integer,
acronimo_sap	char(20)
);

CREATE UNIQUE INDEX inx01sap_trafo ON sap_transforma (clave, cod_mac);

GRANT select ON sap_transforma  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_transforma  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_transforma  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_transforma  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

CREATE TABLE mg_corpor_t23 (
numero_cliente	integer not null,
cod_repart		char(3),
cod_corporativo	char(8),
cod_corpo_padre char(8)
);

CREATE INDEX inx01_mg_corpor ON mg_corpor_t23(numero_cliente);

GRANT select ON mg_corpor_t23  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON mg_corpor_t23  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON mg_corpor_t23  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON mg_corpor_t23  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

ALTER TABLE sucur_centro_op ADD(cod_ul_sap char(1));


CREATE TABLE sap_inactivos (
numero_cliente	integer not null,
fecha_baja		datetime year to second not null,
saldo			decimal(12,2),
elegido			char(1),
procedimiento  char(20)
);

CREATE INDEX inx01inactivos ON sap_inactivos(numero_cliente);
CREATE INDEX inx02inactivos ON sap_inactivos(fecha_baja);

GRANT select ON sap_inactivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_inactivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_inactivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_inactivos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

CREATE TABLE corpoT1migrado(
	numero_cliente	integer not null
);

CREATE INDEX inx_corpoT1migra ON corpoT1migrado (numero_cliente);

GRANT select ON corpoT1migrado  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON corpoT1migrado  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON corpoT1migrado  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON corpoT1migrado  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


CREATE TABLE sap_cambio_medid 
(numero_cliente integer);

CREATE INDEX inx_camedid01 ON sap_cambio_medid (numero_cliente);

GRANT select ON sap_cambio_medid  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_cambio_medid  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_cambio_medid  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_cambio_medid  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


CREATE TABLE migra_activos 
(numero_cliente integer);

CREATE INDEX inx_migrad01 ON migra_activos (numero_cliente);

GRANT select ON migra_activos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON migra_activos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON migra_activos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON migra_activos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

------------

CREATE TABLE sap_trafo_cargos (
cod_cargo_mac		char(3) NOT NULL,
descripcion_mac	varchar(30),
clase_pos_doc		char(10),
contrapartida		char(10),
cte_de_calculo	char(10),
tipo_precio			char(10),
tarifa					char(10),
deriv_contable	char(10),
tipo_cargo_tarifa    char(1));

CREATE INDEX inx_trafo_cargos01 ON sap_trafo_cargos (cod_cargo_mac);

GRANT select ON sap_trafo_cargos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_trafo_cargos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_trafo_cargos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_trafo_cargos  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


CREATE TABLE sap_calcu_inter (
   numero_cliente    integer NOT NULL,
   corr_facturacion  integer,
   inter_calculado   float
);

CREATE INDEX inx_calcuinter01 ON sap_calcu_inter (numero_cliente);

GRANT select ON sap_calcu_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_calcu_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_calcu_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_calcu_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

------------

CREATE TABLE sapsfc_continge(
id_sfc   char(20),
numero_cliente integer);

CREATE INDEX inx_continge01 ON sapsfc_continge (numero_cliente);

GRANT select ON sapsfc_continge  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sapsfc_continge  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sapsfc_continge  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sapsfc_continge  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

------------

CREATE TABLE sap_sfc_inter(
numero_cliente integer,
asset    char(20),
account  char(20),
pod      char(20));

CREATE INDEX inx_inter01 ON sap_sfc_inter (numero_cliente);

GRANT select ON sapsfc_continge  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_sfc_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_sfc_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_sfc_inter  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


-----------------------------

CREATE TABLE sap_portion (
portion	char(8),
diff_date	int);

CREATE INDEX inx_portion01 ON sap_portion (portion);

GRANT select ON sap_portion  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT insert ON sap_portion  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT delete ON sap_portion  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;

GRANT update ON sap_portion  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf;


BEGIN WORK;

ALTER TABLE hisfac_cont_temp ADD(
cliente_nuevo smallint,
saldo_res31_2016 decimal(12,2),
subtarifa_ebp	smallint,
categoria_tarif char(3),
valor_res_pleno decimal(12,2));

INSERT INTO tabla
(sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)VALUES(
'0000', 'PATH', 'SAPISU', 'Extracciones Migracion', '/home/ldvalle/noti_out/', TODAY);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor, fecha_activacion
)VALUES('0000', 'SAPFAC', 'HISTO', 'Dias hacia atras migra facturas', 365, today);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor, fecha_activacion
)VALUES('0000', 'SAPFAC', 'CORR', 'Correlativos hacia atras migra facturas', 9, today);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, fecha_activacion, fecha_modificacion
)VALUES( '0000', 'SAPFAC', 'RTI-1', 'Fecha RTI', TODAY, '2017-02-01');

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)VALUES(
'SAPISU', 'PARTNER', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)VALUES(
'SFDC', 'CUENTA', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)VALUES(
'SAPISU', 'INSTAL', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'OBJCONEX', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'PUNTOSUM', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'UBICAPA', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'PORTION', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'UNLECTU', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'APARATO', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'SECUENLEC', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'CTACONTRA_ACTIVA', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'CTACONTRA_NOACTIVA', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'CTACONTRA_FICTICIA', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'MONTAJE', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'DESMONTAJE', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'MOVE_IN', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'MOVE_OUT', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'LECTURAS', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'FACTURAS', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'MODIF', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'OPERANDOS', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'HISTOCNR', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'DEPGAR', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'BILLDOC', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'FACTSBIM', 0);

INSERT INTO sap_gen_archivos (
sistema, tipo_archivo, correlativo
)values(
'SAPISU', 'FICA', 0);

---------

update sucur_centro_op set
cod_ul_sap = 'G'
where cod_centro_op= '0003';

update sucur_centro_op set
cod_ul_sap = 'R'
where cod_centro_op= '0004';

update sucur_centro_op set
cod_ul_sap = 'A'
where cod_centro_op= '0010';

update sucur_centro_op set
cod_ul_sap = 'Q'
where cod_centro_op= '0020';

update sucur_centro_op set
cod_ul_sap = 'F'
where cod_centro_op= '0023';

update sucur_centro_op set
cod_ul_sap = 'B'
where cod_centro_op= '0026';

update sucur_centro_op set
cod_ul_sap = 'L'
where cod_centro_op= '0050';

update sucur_centro_op set
cod_ul_sap = 'M'
where cod_centro_op= '0053';

update sucur_centro_op set
cod_ul_sap = 'D'
where cod_centro_op= '0056';

update sucur_centro_op set
cod_ul_sap = 'S'
where cod_centro_op= '0059';

update sucur_centro_op set
cod_ul_sap = 'C'
where cod_centro_op= '0065';

update sucur_centro_op set
cod_ul_sap = 'N'
where cod_centro_op= '0069';

COMMIT WORK;


/* Carga de NO Activos Nuevos

INSERT INTO sap_inactivos (numero_cliente, fecha_baja, saldo, elegido, procedimiento)
select c.numero_cliente, m.fecha_modif,
c.valor_anticipo - (c.saldo_actual + c.saldo_int_acum +
c.saldo_imp_no_suj_i + c.saldo_imp_suj_int),
'S',
m.proced
from cliente c, modif m
where c.estado_cliente != 0
and m.numero_cliente = c.numero_cliente
and m.codigo_modif in (56, 58)
and m.fecha_modif >= today - 365;

*/

/*
CREATE TABLE sucur_centro_op (
cod_sucur            integer not null,
cod_centro_op        char(4) not null,
fecha_activacion     date    not null,
fecha_desactivac     date,
cod_sucur_sap        char(4),
cod_ul_sap           char(1),
nro_relacion         smallint
)
*/

/*
INSERT INTO sap_cambio_medid (numero_cliente)
SELECT distinct c.numero_cliente
FROM cliente c, hislec h
WHERE c.estado_cliente = 0
AND h.numero_cliente = c.numero_cliente
AND h.fecha_lectura >= TODAY - 365
AND h.tipo_lectura = 5
*/ 