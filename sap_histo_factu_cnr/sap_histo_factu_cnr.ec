/*******************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_histo_factu_cnr
    
	Fecha : 18/01/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura Historico de Facturas para CNR
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

*****************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>
#include <math.h>

$include "sap_histo_factu_cnr.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];

FILE	*pFileFacturasUnx;

char	sArchFacturasUnx[100];
char	sSoloArchivoFacturas[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 			nombreBase[20];
time_t 			hora;
int				iFlagMigra=0;
$long			lNroCliente;
$long			lCorrFactuActu;
$ClsHisfac		regHisfac;
$ClsDetaHisfac	regDetalle;
$ClsDetaPlano	regDetaPlano;
long 			lFechaLectuActual;
char			*vSucursal[]={"0003", "0004", "0010", "0020", "0023", "0026", "0050", "0065", "0053", "0056", "0059", "0069"};
$char			sSucursal[5];
int				iCantAnios;
$long			iAnioPeriodo;
char			sFechaDesde[9];
$long			lFechaDesde;
char			sFechaHasta[9];
$long			lFechaHasta;
int				i;
int 			j;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);

	memset(sSucursal, '\0', sizeof(sSucursal));
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO CURSOR STABILITY;

/*
	$BEGIN WORK;
*/
	CreaPrepare1();
	
	CreaPrepare();

	$EXECUTE selFechaLimInf into :iAnioPeriodo;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
	
	memset(sSucursal, '\0', sizeof(sSucursal));
	
	for(i=0; i<12; i++){
		for(j=1; j<=6 ; j++){
			memset(sFechaDesde, '\0', sizeof(sFechaHasta));
			sprintf(sFechaDesde, "%d0101", iAnioPeriodo);
			sprintf(sFechaHasta, "%d1231", iAnioPeriodo);
			
			rdefmtdate(&lFechaDesde, "yyyymmdd", sFechaDesde); /*char a long*/
			rdefmtdate(&lFechaHasta, "yyyymmdd", sFechaHasta); /*char a long*/
						
			CreaPrepare();
			
			strcpy(sSucursal, vSucursal[i]);
	
			if(!AbreArchivos(sSucursal, iAnioPeriodo)){
				exit(1);	
			}
			
						
			/*$BEGIN WORK;*/
			
			if(glNroCliente > 0){
				$OPEN curCliente using :glNroCliente, :sSucursal;	
			}else{
				$OPEN curCliente using :sSucursal;
			}	
		
			printf("HISTO_CNR Procesando Sucursal %s Anio %ld......\n", sSucursal, iAnioPeriodo);
			
			while(LeoClientes(&lNroCliente, &lCorrFactuActu)){
	
				if(! ClienteYaMigrado(lNroCliente, &iFlagMigra)){
		
					$OPEN curHisfac using :lNroCliente, :lFechaDesde, :lFechaHasta;
		
					while(LeoHisfac(&regHisfac)){
						if(regHisfac.indica_refact[0]=='N'){
							$OPEN curCarfac using :lNroCliente, :regHisfac.lCorrFactura;	
						}else{
							$OPEN curDrefac using :lNroCliente, :regHisfac.corr_refacturacion;	
						}
		
						InicializaDetaPlano(&regDetaPlano);
		
						while(LeoDetalle(regHisfac, &regDetalle)){
							
							CargaDetaPlano(regDetalle, &regDetaPlano);
										
						}
						
						if(regHisfac.indica_refact[0]=='N'){
							$CLOSE curCarfac;
						}else{
							$CLOSE curDrefac;
						}
		
						/* Kw condonados */
						rdefmtdate(&lFechaLectuActual, "yyyymmdd", regHisfac.sFechaLectuActual); /*char a long*/
						if(lFechaLectuActual > 42400 ){  /* 01/02/2016 */
							CargarCondones(regHisfac, &regDetaPlano);
						}else{
							regDetaPlano.kwh_facturados = regHisfac.consumo_sum;
							regDetaPlano.kwh_condonados=0;
							regDetaPlano.kwh_totales = regHisfac.consumo_sum;					
						}
		
						CargaHislec(regHisfac, &regDetaPlano);
						
						if(regDetaPlano.tipo_medidor[0]=='R')
							CargaHislecReac(regHisfac, &regDetaPlano);
		
		
						GenerarPlano(pFileFacturasUnx, regHisfac, regDetaPlano);
					}
		
					$CLOSE curHisfac;
		          /*
					if(!RegistraCliente(lNroCliente, iFlagMigra)){
						$ROLLBACK WORK;
						exit(1);	
					}	
               */		
					cantProcesada++;
				}else{
					cantPreexistente++;	
				}
				
			}/* cursor clientes */
	
			iAnioPeriodo++;
					
			$CLOSE curCliente;
			/*$COMMIT WORK;*/
	
			CerrarArchivos();
			
			$CLOSE DATABASE;
			$DISCONNECT CURRENT;
	
			$DATABASE :nombreBase;	
			$SET LOCK MODE TO WAIT 600;
			$SET ISOLATION TO DIRTY READ;	
		}/* Cursor Anio */	
	}/* cursor sucursal */
				

	/* Registrar Control Plano */
/*   
	$BEGIN WORK;
	
	if(!RegistraArchivo()){
		$ROLLBACK WORK;
		exit(1);
	}
	
	$COMMIT WORK;
*/
	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */
/*
	FormateaArchivos();
*/

/*	
	if(! EnviarMail(sArchResumenDos, sArchControlDos)){
		printf("Error al enviar mail con lista de respaldo.\n");
		printf("El mismo se pueden extraer manualmente en..\n");
		printf("     [%s]\n", sArchResumenDos);
	}else{
		sprintf(sCommand, "rm -f %s", sArchResumenDos);
		iRcv=system(sCommand);			
	}
*/

	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Clientes Preexistentes :    %ld \n",cantPreexistente);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{

	if(argc < 4 || argc > 5){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	giEstadoCliente=atoi(argv[2]);
	
	strcpy(gsTipoGenera, argv[3]);
	
	if(argc==5){
		glNroCliente=atoi(argv[4]);
	}else{
		glNroCliente=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos(sSucur, iAnio)
$char	sSucur[5];
long	iAnio;
{
	
	memset(sArchFacturasUnx,'\0',sizeof(sArchFacturasUnx));
	memset(sSoloArchivoFacturas,'\0',sizeof(sSoloArchivoFacturas));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchFacturasUnx  , "%sT1CNR.unx", sPathSalida);
	strcpy( sSoloArchivoFacturas, "T1CNR.unx");

	pFileFacturasUnx=fopen( sArchFacturasUnx, "w" );
	if( !pFileFacturasUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchFacturasUnx );
		return 0;
	}
	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileFacturasUnx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
	
	memset(sCommand, '\0', sizeof(sCommand));

/*
	if(cantProcesada>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchInstalacionUnx, sArchInstalacionDos);
		iRcv=system(sCommand);
	}

	sprintf(sCommand, "rm -f %s", sArchInstalacionUnx);
	iRcv=system(sCommand);	
*/	
}

void CreaPrepare1(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));

	/************ FechaLimiteInferior **************/
	strcpy(sql, "SELECT YEAR(TODAY)-5 FROM dual ");
	
	$PREPARE selFechaLimInf FROM $sql;
		
	
}

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

	/********** Centros Operativos *********/
	strcpy(sql, "SELECT cod_centro_op ");
	strcat(sql, "FROM sucur_centro_op ");
	strcat(sql, "WHERE cod_sucur_sap IS NOT NULL ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
	
	$PREPARE selSucur FROM $sql;
	$DECLARE curSucur CURSOR for selSucur;

	/****** Cursor Clientes ******/
	strcpy(sql, "SELECT c.numero_cliente, c.corr_facturacion "); 
	strcat(sql, "FROM cliente c ");

	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si ");
	}
/*
strcat(sql, ", migra_activos m ");
*/
	if(glNroCliente > 0){
		strcat(sql, "WHERE c.numero_cliente = ? ");	
		strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	}else{
		strcat(sql, "WHERE c.tipo_sum NOT IN (5, 6) ");
	}
	if(giEstadoCliente==0){
		strcat(sql, "AND c.estado_cliente = 0 ");	
	}else if(giEstadoCliente==1){
		strcat(sql, "AND c.estado_cliente != 0 ");
	}
	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}

	strcat(sql, "AND c.sucursal = ? ");	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
/*
strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
*/
	$PREPARE selCliente FROM $sql;
	
	$DECLARE curCliente CURSOR FOR selCliente;

	/****** Cursor Hisfac *******/
	strcpy(sql, "SELECT h.numero_cliente, ");
	strcat(sql, "h.fecha_facturacion, ");
	strcat(sql, "h.corr_facturacion, ");
	strcat(sql, "h.centro_emisor || h.tipo_docto || '-' || LPAD(h.numero_factura, 8, '0'), ");
	strcat(sql, "CASE ");					/* TArifa*/
	strcat(sql, "	WHEN c.tarifa[2] = 'G' AND c.tipo_sum = 6 THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "TO_CHAR(h.fecha_vencimiento1, '%Y%m%d'), ");
	strcat(sql, "TO_CHAR(h.fecha_facturacion, '%Y%m%d'), ");
	strcat(sql, "NVL(TO_CHAR(h2.fecha_lectura, '%Y%m%d'), '0000'), ");
	strcat(sql, "TO_CHAR(h.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "h.consumo_sum, ");
	strcat(sql, "h.suma_impuestos, ");
	strcat(sql, "h.indica_refact, ");
	strcat(sql, "h.numero_factura ");
	strcat(sql, "FROM hisfac h, cliente c, OUTER sap_transforma t1, OUTER hisfac h2 ");
	strcat(sql, "WHERE h.numero_cliente = ? ");
	strcat(sql, "AND h.fecha_facturacion BETWEEN ? AND ? ");
	/*strcat(sql, "AND h.fecha_facturacion >= TODAY - 1825 ");*/
	strcat(sql, "AND c.numero_cliente = h.numero_cliente ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h.tarifa ");
	strcat(sql, "AND h2.numero_cliente = h.numero_cliente ");
	strcat(sql, "AND h2.corr_facturacion = h.corr_facturacion - 1 ");
	
	$PREPARE selHisfac FROM $sql;
	
	$DECLARE curHisfac CURSOR FOR selHisfac;

	/********** Fecha Lectura Hislec anterior **********/
	strcpy(sql, "SELECT TO_CHAR(MIN(fecha_lectura), '%Y%m%d') FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 7) ");
	
	$PREPARE selHislecAnterior FROM $sql;

	/********* Consumo Refacturado **********/
	strcpy(sql, "SELECT r.kwh, r.corr_refacturacion FROM refac r ");
	strcat(sql, "WHERE r.numero_cliente = ? ");
	strcat(sql, "AND r.nro_docto_afect = ? ");
	strcat(sql, "AND r.fecha_fact_afect = ? ");
	strcat(sql, "AND r.corr_refacturacion = (SELECT MAX(r2.corr_refacturacion) ");
	strcat(sql, "	FROM refac r2 ");
	strcat(sql, "	WHERE r2.numero_cliente = r.numero_cliente ");
	strcat(sql, "	AND r2.nro_docto_afect = r.nro_docto_afect ");
	strcat(sql, "	AND r2.fecha_fact_afect = r.fecha_fact_afect) ");
	
	$PREPARE selRefac FROM $sql;

	/********* Carfac ***********/
	strcpy(sql, "SELECT codigo_cargo, valor_cargo, tipo_cargo ");
	strcat(sql, "FROM carfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	
	$PREPARE selCarfac FROM $sql;
	
	$DECLARE curCarfac CURSOR FOR selCarfac;
	
	/********* Drefac ***********/
	strcpy(sql, "SELECT d.codigo_cargo, d.valor_cargo, c.tipo_cargo ");
	strcat(sql, "FROM drefac d, codca c ");
	strcat(sql, "WHERE d.numero_cliente = ? ");
	strcat(sql, "AND d.corr_refacturacion = ? ");
	strcat(sql, "AND c.codigo_cargo = d.codigo_cargo ");

	$PREPARE selDrefac FROM $sql;
	
	$DECLARE curDrefac CURSOR FOR selDrefac;

	/*********** HISLEC ***********/
	strcpy(sql, "SELECT h.lectura_facturac, h.lectura_terreno, h.consumo, h.numero_medidor, h.marca_medidor ");
	strcat(sql, "FROM hislec h ");
	strcat(sql, "WHERE h.numero_cliente = ? ");
	strcat(sql, "AND h.corr_facturacion = ? ");
	strcat(sql, "AND h.tipo_lectura NOT IN (5, 6, 7) ");

	$PREPARE selHislec FROM $sql;
	
	/*********** HISLEC REAC ***********/
	strcpy(sql, "SELECT lectu_factu_reac, lectu_terreno_reac, consumo_reac ");
	strcat(sql, "FROM hislec_reac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 7) ");
	
	$PREPARE selHislecReac FROM $sql;
	
	/*********** HISLEC REFAC***********/
	strcpy(sql, "SELECT h1.lectura_rectif, h1.consumo_rectif ");
	strcat(sql, "FROM hislec_refac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura) ");
   
	$PREPARE selHislecRefac FROM $sql;
		
	/*********** HISLEC REAC REFAC ***********/
	strcpy(sql, "SELECT h1.lectu_rectif_reac, h1.consu_rectif_reac ");
	strcat(sql, "FROM hislec_refac_reac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac_reac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura )" );
   
	$PREPARE selHislecReacRefac FROM $sql;	
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/******** Select Correlativo ****************/
	strcpy(sql, "SELECT correlativo +1 FROM sap_gen_archivos ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	/*$PREPARE selCorrelativo FROM $sql;*/

	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	/*$PREPARE updGenArchivos FROM $sql;*/
		
	/******** Insert gen_archivos ****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'INSTALACION', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT histo_cnr FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, histo_cnr ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "histo_cnr = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ Busca Instalacion 1 **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.estado = 'I' ");

	$PREPARE selFechaInstal1 FROM $sql;

	/************ Busca Instalacion 2 **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(MIN(m.fecha_ult_insta), '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");

	$PREPARE selFechaInstal2 FROM $sql;
	
	/******* Tipo de Medidor *******/
	strcpy(sql, "SELECT modelo_medidor, NVL(tipo_medidor, 'A') ");
	strcat(sql, "FROM medid ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND numero_medidor = ? ");
	strcat(sql, "AND marca_medidor = ? ");
	
	$PREPARE selTipoMedid FROM $sql;
	$DECLARE curTipoMedid CURSOR for selTipoMedid;

	/************* Consumo Condonado ****************/
	strcpy(sql, "SELECT consumo_condonado ");
	strcat(sql, "FROM det_val_tarifas_hist ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	strcat(sql, "AND corr_precio = 1 ");

	$PREPARE selKwCondonado	FROM $sql;

/*
SELECT monto_ajus_real,
kwh_ajustados,
kwh_ajustados_tope,
identif_agenda,
corr_refact_kwh,
tipo_concepto,
corr_pur2_aju 
FROM puree2_ajustes p 
WHERE p.numero_cliente = ?
AND p.corr_fact_monto= ?
AND p.corr_pur2_aju = (SELECT MAX(corr_pur2_aju)
	FROM puree2_ajustes pa
	WHERE pa.numero_cliente = p.numero_cliente 
	AND pa.corr_fact_monto = p.corr_fact_monto)
AND p.estado = 'P'
*/
}

void FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[9];
	
	memset(fmtFecha,'\0',sizeof(fmtFecha));
	
	$EXECUTE selFechaActualFmt INTO :fmtFecha;
	
	strcpy(Fecha, fmtFecha);
	
}

void RutaArchivos( ruta, clave )
$char ruta[100];
$char clave[7];
{

	$EXECUTE selRutaPlanos INTO :ruta using :clave;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
        exit(1);
    }
}
/*
long getCorrelativo(sTipoArchivo)
$char		sTipoArchivo[11];
{
$long iValor=0;

	$EXECUTE selCorrelativo INTO :iValor using :sTipoArchivo;
	
    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el correlativo del archivo tipo %s.\n", sTipoArchivo);
        exit(1);
    }	
    
    return iValor;
}
*/

short ClienteYaMigrado(nroCliente, iFlagMigra)
$long	nroCliente;
int		*iFlagMigra;
{
	$char	sMarca[2];
	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
		return 1;
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
	return 0;
}



void GeneraENDE(fp, regHisfac)
FILE *fp;
$ClsHisfac	regHisfac;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regHisfac.numero_cliente, regHisfac.lCorrFactura);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "HISTOCNR");
		strcpy(sNombreArchivo, sSoloArchivoFacturas);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenInstal using
				:gsTipoGenera,
				:lCantidad,
				:glNroCliente,
				:sNombreArchivo;
	}
	
	return 1;
}
*/
short RegistraCliente(nroCliente, iFlagMigra)
$long	nroCliente;
int		iFlagMigra;
{
/*
	if(iFlagMigra==1){
		$EXECUTE insClientesMigra using :nroCliente;
	}else{
		$EXECUTE updClientesMigra using :nroCliente;
	}
*/
	return 1;
}

short LeoClientes(lNroCliente, lCorrFactu)
$long	*lNroCliente;
$long	*lCorrFactu;
{
	$long	lNroClienteAux;
	$long	lCorrFactuAux;
	
	$FETCH curCliente into :lNroClienteAux, :lCorrFactuAux;
		
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			return 0;	
		}else{
			printf("Error al leer clientes.\n");
			exit(2);
		}	
	}
	
	*lNroCliente = lNroClienteAux;
	*lCorrFactu = lCorrFactuAux;
	
	return 1;
}

void InicializoHisfac(regHisfac)
ClsHisfac * regHisfac;
{
	long	numero_cliente;
	long	lFechaFacturacion;
	long	lCorrFactura;
	char	id_comprobante[14];
	char	tarifa[11];
	char	sFechaVencimiento1[9];
	char	sFechaFacturacion[9];
	char	sFechaLectuAnterior[9];
	char	sFechaLectuActual[9];
	double	consumo_sum;
	double	suma_impuestos;

	rsetnull(CLONGTYPE, (char *) &(regHisfac->numero_cliente));
	rsetnull(CLONGTYPE, (char *) &(regHisfac->lFechaFacturacion));
	rsetnull(CLONGTYPE, (char *) &(regHisfac->lCorrFactura));
	
	memset(regHisfac->id_comprobante, '\0', sizeof(regHisfac->id_comprobante));
	memset(regHisfac->tarifa, '\0', sizeof(regHisfac->tarifa));
	memset(regHisfac->sFechaVencimiento1, '\0', sizeof(regHisfac->sFechaVencimiento1));
	memset(regHisfac->sFechaFacturacion, '\0', sizeof(regHisfac->sFechaFacturacion));
	memset(regHisfac->sFechaLectuAnterior, '\0', sizeof(regHisfac->sFechaLectuAnterior));
	memset(regHisfac->sFechaLectuActual, '\0', sizeof(regHisfac->sFechaLectuActual));
	
	rsetnull(CDOUBLETYPE, (char *) &(regHisfac->consumo_sum));
	rsetnull(CDOUBLETYPE, (char *) &(regHisfac->suma_impuestos));
	rsetnull(CLONGTYPE, (char *) &(regHisfac->nDiasPeriodo));

	memset(regHisfac->indica_refact, '\0', sizeof(regHisfac->indica_refact));
	
	rsetnull(CLONGTYPE, (char *) &(regHisfac->corr_refacturacion));
	rsetnull(CLONGTYPE, (char *) &(regHisfac->lNroFactura));
}

short LeoHisfac(regHisfac)
$ClsHisfac * regHisfac;
{
	$long	correlaAnterior;
	$char	sFechaLecturaAnterior[9];
	long	lFechaLectuAnterior;
	long	lFechaLectuActual;
	long	lDiffDias;
	$long	corr_refacturacion;
	$double dKwh;
		
	memset(sFechaLecturaAnterior, '\0', sizeof(sFechaLecturaAnterior));
	
	InicializoHisfac(regHisfac);
	
	$FETCH curHisfac into
		:regHisfac->numero_cliente,
		:regHisfac->lFechaFacturacion,
		:regHisfac->lCorrFactura,
		:regHisfac->id_comprobante,
		:regHisfac->tarifa,
		:regHisfac->sFechaVencimiento1,
		:regHisfac->sFechaFacturacion,
		:regHisfac->sFechaLectuAnterior,
		:regHisfac->sFechaLectuActual,
		:regHisfac->consumo_sum,
		:regHisfac->suma_impuestos,
		:regHisfac->indica_refact,
		:regHisfac->lNroFactura;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de HISFAC !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }

	alltrim(regHisfac->tarifa, ' ');
	alltrim(regHisfac->sFechaLectuAnterior, ' ');

	if(strcmp(regHisfac->sFechaLectuAnterior, "0000")==0){
		/* Busco la fecha en Hislec */	
		correlaAnterior = regHisfac->lCorrFactura - 1;
		
		$EXECUTE selHislecAnterior into :sFechaLecturaAnterior using :regHisfac->numero_cliente, :correlaAnterior;
		
		if(SQLCODE != 0){
			printf("Error al buscar hislec anterior para cliente %ld y correlativo actual %ld\n", regHisfac->numero_cliente, regHisfac->lCorrFactura);
			exit(2);
		}
		strcpy(regHisfac->sFechaLectuAnterior, sFechaLecturaAnterior);
	}

	/* Obtengo los dias del período */
	
	
	rdefmtdate(&lFechaLectuAnterior, "yyyymmdd", regHisfac->sFechaLectuAnterior); /*char a long*/
	rdefmtdate(&lFechaLectuActual, "yyyymmdd", regHisfac->sFechaLectuActual); /*char a long*/
	
	lDiffDias = lFechaLectuActual - lFechaLectuAnterior;
	regHisfac->nDiasPeriodo = lDiffDias;

	/* Verifico refacturaciones */
	if(regHisfac->indica_refact[0]=='S'){
		$EXECUTE selRefac into :dKwh, :corr_refacturacion
				using :regHisfac->numero_cliente,
					  :regHisfac->lNroFactura,
					  :regHisfac->lFechaFacturacion;
		
		if(SQLCODE != 0){
			printf("Error\nNo se encontró refacturacion para cliente %ld factura %ld\n", regHisfac->numero_cliente, regHisfac->lNroFactura);
			exit(2);	
		}
		
		regHisfac->consumo_sum = dKwh;
		regHisfac->corr_refacturacion = corr_refacturacion;
	}
	
	return 1;	
}

void InicializaDetalle(regDetalle)
ClsDetaHisfac	*regDetalle;
{
	memset(regDetalle->codigo_cargo, '\0', sizeof(regDetalle->codigo_cargo));
	rsetnull(CDOUBLETYPE, (char *) &(regDetalle->valor_cargo));
	memset(regDetalle->tipo_cargo, '\0', sizeof(regDetalle->tipo_cargo));
}

short LeoDetalle(regHisfac, regDetalle)
ClsHisfac		regHisfac;
$ClsDetaHisfac	*regDetalle;
{
	
	InicializaDetalle(regDetalle);

	if(regHisfac.indica_refact[0]=='N'){
		$FETCH curCarfac into :regDetalle->codigo_cargo,
								:regDetalle->valor_cargo,
								:regDetalle->tipo_cargo;
	}else{
		$FETCH curDrefac into :regDetalle->codigo_cargo,
								:regDetalle->valor_cargo,
								:regDetalle->tipo_cargo;
	}	
	
	if(SQLCODE !=0){
		if(SQLCODE == 100){
			return 0;	
		}else{
			printf("Error al buscar detalle de la factura para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
			exit(2);
		}	
	}
	
	return 1;
}

void InicializaDetaPlano(regDetaPlano)
ClsDetaPlano *regDetaPlano;
{
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->cargo_fijo));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->cargo_variable));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->importe_neto));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->Res347));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->fonimvemen));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->subsidios));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->bonificacion));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->puree_m));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->puree_b));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->otros));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->lectu_terr_activa));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->lectu_factu_activa));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->consumo_activa));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->lectu_terr_reactiva));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->lectu_factu_reactiva));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->consumo_reactiva));

	rsetnull(CLONGTYPE, (char *) &(regDetaPlano->numero_medidor));
	
	memset(regDetaPlano->marca_medidor, '\0', sizeof(regDetaPlano->marca_medidor));
	memset(regDetaPlano->modelo_medidor, '\0', sizeof(regDetaPlano->modelo_medidor));
	memset(regDetaPlano->tipo_medidor, '\0', sizeof(regDetaPlano->tipo_medidor));

	rsetnull(CINTTYPE, (char *) &(regDetaPlano->porc_factor_potencia));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->kwh_facturados));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->kwh_condonados));
	rsetnull(CDOUBLETYPE, (char *) &(regDetaPlano->kwh_totales));
	
	regDetaPlano->cargo_fijo=0.00;
	regDetaPlano->cargo_variable=0.00;
	regDetaPlano->importe_neto=0.00;
	regDetaPlano->Res347=0.00;
	regDetaPlano->fonimvemen=0.00;
	regDetaPlano->subsidios=0.00;
	regDetaPlano->bonificacion=0.00;
	regDetaPlano->puree_m=0.00;
	regDetaPlano->puree_b=0.00;
	regDetaPlano->otros=0.00;

	regDetaPlano->lectu_terr_activa=0.00;
	regDetaPlano->lectu_factu_activa=0.00;
	regDetaPlano->consumo_activa=0.00;
	regDetaPlano->lectu_terr_reactiva=0.00;
	regDetaPlano->lectu_factu_reactiva=0.00;
	regDetaPlano->consumo_reactiva=0.00;	
	regDetaPlano->porc_factor_potencia=0.00;
	regDetaPlano->kwh_facturados=0.00;
	regDetaPlano->kwh_condonados=0.00;
	regDetaPlano->kwh_totales=0.00;
}

void CargaDetaPlano(regDetalle, regDetaPlano)
ClsDetaHisfac	regDetalle;
ClsDetaPlano	*regDetaPlano;
{
	
	int iCodigo;
	
	iCodigo=atoi(regDetalle.codigo_cargo);
	
	/*
	if(strcmp(regDetalle.codigo_cargo, "020")==0){
		regDetaPlano->cargo_fijo += regDetalle.valor_cargo;
	}
	if(strcmp(regDetalle.codigo_cargo, "030")==0){
		regDetaPlano->cargo_variable += regDetalle.valor_cargo;
	}	
	if(strcmp(regDetalle.codigo_cargo, "022")==0){
		regDetaPlano->Res347 += regDetalle.valor_cargo;
	}	
	if(strcmp(regDetalle.codigo_cargo, "618")==0 || strcmp(regDetalle.codigo_cargo, "619")==0){
		regDetaPlano->fonimvemen += regDetalle.valor_cargo;
	}	
	if(strcmp(regDetalle.codigo_cargo, "001")==0){
		regDetaPlano->subsidios += regDetalle.valor_cargo;
	}
	*/
	
	switch(iCodigo){
		case 10: /* Bajo Factor de Potencia*/
			if(regDetalle.valor_cargo >= 74 && regDetalle.valor_cargo <=84){
				regDetaPlano->porc_factor_potencia=10;
			}else if(regDetalle.valor_cargo > -1 && regDetalle.valor_cargo <74){
				regDetaPlano->porc_factor_potencia=20;
			}else{
				regDetaPlano->porc_factor_potencia=0;
			}
			break;
		case 20:
			regDetaPlano->cargo_fijo += regDetalle.valor_cargo;
			break;
		case 30:
			regDetaPlano->cargo_variable += regDetalle.valor_cargo;
			break;
		case 22:
			regDetaPlano->Res347 += regDetalle.valor_cargo;
			break;
			
		case 618:
		case 619:
			regDetaPlano->fonimvemen += regDetalle.valor_cargo;
			break;
			
		case 1:
			regDetaPlano->subsidios += regDetalle.valor_cargo;
			break;

		case 5:
			regDetaPlano->bonificacion += regDetalle.valor_cargo;
			break;
		case 604:
			regDetaPlano->puree_m += regDetalle.valor_cargo;
			break;			
		case 605:
			regDetaPlano->puree_b += regDetalle.valor_cargo;
			break;			
		default:
			if(regDetalle.tipo_cargo[0]!= 'I'){
				regDetaPlano->otros += regDetalle.valor_cargo;
			}
			break;			
	}
	
	if(regDetalle.tipo_cargo[0]!= 'I'){
		if(iCodigo!=1 && iCodigo!=5 && iCodigo!=604 && iCodigo!=605){
			regDetaPlano->importe_neto += regDetalle.valor_cargo;
		}
	}
}

void CargaHislec(regHisfac, regDetaPlano)
ClsHisfac		regHisfac;
$ClsDetaPlano	*regDetaPlano;
{
	$EXECUTE selHislec into	
		:regDetaPlano->lectu_terr_activa,
		:regDetaPlano->lectu_factu_activa,
		:regDetaPlano->consumo_activa,
		:regDetaPlano->numero_medidor,
		:regDetaPlano->marca_medidor
	using
		:regHisfac.numero_cliente,
		:regHisfac.lCorrFactura;
			
	if(SQLCODE != 0){
		if(SQLCODE==100){
			printf("No se encontro HISLEC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
		}else{
			printf("Error al buscar HISLEC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
		}
		exit(2);
	}
	
	if(regHisfac.indica_refact[0]=='S'){
		$EXECUTE selHislecRefac into
			:regDetaPlano->lectu_terr_activa,
			:regDetaPlano->consumo_activa
		using
			:regHisfac.numero_cliente,
			:regHisfac.lCorrFactura;
				
		if(SQLCODE != 0){
			if(SQLCODE==100){
				printf("No se encontro HISLEC_REFAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
			}else{
				printf("Error al buscar HISLEC_REFAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
				exit(2);			
			}	
		}else{
			regDetaPlano->lectu_factu_activa = regDetaPlano->lectu_terr_activa;
		}
	}

	/* Cargo datos del medidor */
	$OPEN curTipoMedid 	using :regHisfac.numero_cliente,
						      :regDetaPlano->numero_medidor,
							  :regDetaPlano->marca_medidor;
							  	
	$FETCH curTipoMedid into :regDetaPlano->modelo_medidor,
							 :regDetaPlano->tipo_medidor;

	$CLOSE curTipoMedid;
								  	
	if(SQLCODE != 0){
		printf("No se encontro Medid para cliente %ld Medidor %ld Marca %s\n", regHisfac.numero_cliente, regDetaPlano->numero_medidor, regDetaPlano->marca_medidor);
	}
}

void CargaHislecReac(regHisfac, regDetaPlano)
ClsHisfac		regHisfac;
ClsDetaPlano	*regDetaPlano;
{
	$EXECUTE selHislecReac into	
		:regDetaPlano->lectu_terr_reactiva,
		:regDetaPlano->lectu_factu_reactiva,
		:regDetaPlano->consumo_reactiva
	using
		:regHisfac.numero_cliente,
		:regHisfac.lCorrFactura;
			
	if(SQLCODE != 0){
		if(SQLCODE==100){
			printf("No se encontro HISLEC_REAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
			exit(2);
		}else{
			printf("Error al buscar HISLEC_REAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
			exit(2);			
		}	
	}
	
	if(regHisfac.indica_refact[0]=='S'){
		$EXECUTE selHislecReacRefac into
			:regDetaPlano->lectu_terr_reactiva,
			:regDetaPlano->consumo_reactiva
		using
			:regHisfac.numero_cliente,
			:regHisfac.lCorrFactura;
				
		if(SQLCODE != 0){
			if(SQLCODE==100){
				printf("No se encontro HISLEC_REFAC_REAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
			}else{
				printf("Error al buscar HISLEC_REFAC_REAC para cliente %ld correlativo %ld\n", regHisfac.numero_cliente, regHisfac.lCorrFactura);
				exit(2);			
			}	
		}else{
			regDetaPlano->lectu_factu_reactiva=regDetaPlano->lectu_terr_reactiva;
		}
		
	}

}

void GenerarPlano(pf, regHisfac, regDetaPlano)
FILE 			*pf;
ClsHisfac		regHisfac;
ClsDetaPlano	regDetaPlano;
{
	GeneraHISTOCNR(pf, regHisfac, regDetaPlano);
/*	
	GeneraENDE(pf, regHisfac);
*/	
}

void GeneraHISTOCNR(fp, regHisfac, regDetaPlano)
FILE 			*fp;
ClsHisfac		regHisfac;
ClsDetaPlano	regDetaPlano;
{

	char	sLinea[1000];	
	double	dAux;
	
	memset(sLinea, '\0', sizeof(sLinea));
/*	
	sprintf(sLinea, "T1%ld-%ld\tHISTOCNR\t", regHisfac.numero_cliente, regHisfac.lCorrFactura);
*/	
	/*EXBEL*/
	sprintf(sLinea, "%s\t", regHisfac.id_comprobante);
	
	/*PARTNER*/
	sprintf(sLinea, "%sT1%ld\t",sLinea, regHisfac.numero_cliente);
	
	/*TARIFTYP*/
	sprintf(sLinea, "%s%s\t", sLinea, regHisfac.tarifa);
	
	/*zz_fvenc*/
	sprintf(sLinea, "%s%s\t", sLinea, regHisfac.sFechaVencimiento1);
	
	/*ZWKENN (id para identificar ?)*/
	if(regDetaPlano.tipo_medidor[0]=='A'){
		strcat(sLinea, "1\t");
	}else{
		strcat(sLinea, "2\t");
	}
	
	/*EQUI-SERNR  (nro.de serie ?)*/
	sprintf(sLinea, "%s%018ld\t", sLinea, regDetaPlano.numero_medidor);
	
	/*BLDAT*/
	sprintf(sLinea, "%s%s\t", sLinea, regHisfac.sFechaFacturacion);
	
	/*AB*/
	sprintf(sLinea, "%s%s\t", sLinea, regHisfac.sFechaLectuAnterior);
	
	/*BIS*/
	sprintf(sLinea, "%s%s\t", sLinea, regHisfac.sFechaLectuActual);   
	
	/*ZEITANT*/
	if(regHisfac.nDiasPeriodo > 0){
		sprintf(sLinea, "%s%ld\t", sLinea, regHisfac.nDiasPeriodo);	
	}else{
		strcat(sLinea, "0\t");
	}
	
	/*zz_pbfpf (Porcentaje bajo factor potencia ???)*/
	sprintf(sLinea, "%s%ld\t", sLinea, regDetaPlano.porc_factor_potencia); /* 0 */
	
	/*zz_cntkf*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, fabs(regDetaPlano.kwh_facturados)); 
	
	/*zz_cntkc (kw x tis ???)*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, fabs(regDetaPlano.kwh_condonados));  /* 0 */
	
	/*I_ABRMENGE (Suma de los 2 anteriores ??)*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, fabs(regDetaPlano.kwh_totales)); 
	
	/*zz_conaj (consumo a 61 dias) */
	if(regHisfac.nDiasPeriodo > 0){
		dAux = regDetaPlano.kwh_totales;
		dAux= (dAux/regHisfac.nDiasPeriodo) * 61;
		sprintf(sLinea, "%s%.0lf\t", sLinea, dAux);	
	}else{
		strcat(sLinea, "0\t");	
	}
	
	/*zz_carfi*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.cargo_fijo));
	
	/*zz_carva*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.cargo_variable));
	
	/*zz_impnf (importe neto factura. sin impuestos ni subsidios ?)*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.importe_neto));
	
	/*zz_res*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.Res347));
	
	/*zz_fornim*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.fonimvemen));
	
	/*zz_subsi*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.subsidios));
	
	/*zz_bonif (bonificacion ?) */
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.bonificacion));
	
	/*zz_puree (puree 604)*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.puree_m));

	/*zz_puree (puree 605)*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.puree_b));
		
	/*zz_otcon (otros conceptos)*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regDetaPlano.otros));
	
	/*zz_impue*/
	sprintf(sLinea, "%s%.02lf\t", sLinea, fabs(regHisfac.suma_impuestos));
	
	/*zz_lectc*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.lectu_terr_activa);
	
	/*zz_lecfc*/
	if(!risnull(CDOUBLETYPE, (char *) &regDetaPlano.lectu_factu_activa)){
		sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.lectu_factu_activa);
	}else{
		strcat(sLinea, "0\t");	
	}
	
	/*zz_conle*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.consumo_activa);
	
	/*zz_lectr*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.lectu_terr_reactiva);
	
	/*zz_lecfr*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.lectu_factu_reactiva);
	
	/*zz_conrl*/
	sprintf(sLinea, "%s%.0lf\t", sLinea, regDetaPlano.consumo_reactiva);
	
	/* Lo que sigue parece que es para T23 */
	/*zz_ltpot*/
	strcat(sLinea, "\t");
	/*zz_lfapo*/
	strcat(sLinea, "\t");
	/*zz_clpot*/
	strcat(sLinea, "\t");
	/*zz_ltdpu*/
	strcat(sLinea, "\t");
	/*zz_lfdpu*/
	strcat(sLinea, "\t");
	/*zz_dempu*/
	strcat(sLinea, "\t");
	/*zz_ltdfdp*/
	strcat(sLinea, "\t");
	/*zz_lfdfdp*/
	strcat(sLinea, "\t");
	/*zz_dfdpu*/
	strcat(sLinea, "\t");
	/*zz_ltcpu*/
	strcat(sLinea, "\t");
	/*zz_lfcpu*/
	strcat(sLinea, "\t");
	/*zz_cpun*/
	strcat(sLinea, "\t");
	/*zz_ltcva*/
	strcat(sLinea, "\t");
	/*zz_lfcva*/
	strcat(sLinea, "\t");
	/*zz_cvall*/
	strcat(sLinea, "\t");
	/*zz_ltcre*/
	strcat(sLinea, "\t");
	/*zz_lfcre*/
	strcat(sLinea, "\t");
	/*zz_conre*/
	strcat(sLinea, "\t");
	/*zz_ippun*/
	strcat(sLinea, "\t");
	/*zz_ipfdp*/
	strcat(sLinea, "\t");
	/*zz_icpun*/
	strcat(sLinea, "\t");
	/*zz_icres*/
	strcat(sLinea, "\t");
	/*zz_icv*/
	strcat(sLinea, "\t");
	/*zz_icrea*/
	strcat(sLinea, "\t");
	/*zz_ip*/
	strcat(sLinea, "\t");
	/*zz_ice*/
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);

}

void CargarCondones(regHisfac, regDetaPlano)
$ClsHisfac		regHisfac;
$ClsDetaPlano	*regDetaPlano;
{
	double dFactuAux=0.00;
	
	$EXECUTE selKwCondonado into :regDetaPlano->kwh_condonados
		using :regHisfac.numero_cliente,
			  :regHisfac.lCorrFactura;
			  	
	if(SQLCODE!=0){
		regDetaPlano->kwh_facturados = regHisfac.consumo_sum;
		regDetaPlano->kwh_condonados=0;
		regDetaPlano->kwh_totales = regHisfac.consumo_sum;
		return;	
	}else{
		dFactuAux= regHisfac.consumo_sum - regDetaPlano->kwh_condonados;
		regDetaPlano->kwh_facturados = dFactuAux;
		regDetaPlano->kwh_totales = regHisfac.consumo_sum;
	}

}

short LeoSucursal(sSucur)
$char   *sSucur;
{
	$char	sAux[5];
	
	memset(sAux, '\0', sizeof(sAux));
	
	$FETCH curSucur into :sAux;
		
	if(SQLCODE!=0){
		return 0;	
	}
	
	strcpy(sSucur, sAux);
	
	return 1;
}


/****************************
		GENERALES
*****************************/

void command(cmd,buff_cmd)
char *cmd;
char *buff_cmd;
{
   FILE *pf;
   char *p_aux;
   pf =  popen(cmd, "r");
   if (pf == NULL)
       strcpy(buff_cmd, "E   Error en ejecucion del comando");
   else
       {
       strcpy(buff_cmd,"\n");
       while (fgets(buff_cmd + strlen(buff_cmd),512,pf))
           if (strlen(buff_cmd) > 5000)
              break;
       }
   p_aux = buff_cmd;
   *(p_aux + strlen(buff_cmd) + 1) = 0;
   pclose(pf);
}

/*
short EnviarMail( Adjunto1, Adjunto2)
char *Adjunto1;
char *Adjunto2;
{
    char 	*sClave[] = {SYN_CLAVE};
    char 	*sAdjunto[3]; 
    int		iRcv;
    
    sAdjunto[0] = Adjunto1;
    sAdjunto[1] = NULL;
    sAdjunto[2] = NULL;

	iRcv = synmail(sClave[0], sMensMail, NULL, sAdjunto);
	
	if(iRcv != SM_OK){
		return 0;
	}
	
    return 1;
}

void  ArmaMensajeMail(argv)
char	* argv[];
{
$char	FechaActual[11];

	
	memset(FechaActual,'\0', sizeof(FechaActual));
	$EXECUTE selFechaActual INTO :FechaActual;
	
	memset(sMensMail,'\0', sizeof(sMensMail));
	sprintf( sMensMail, "Fecha de Proceso: %s<br>", FechaActual );
	if(strcmp(argv[1],"M")==0){
		sprintf( sMensMail, "%sNovedades Monetarias<br>", sMensMail );		
	}else{
		sprintf( sMensMail, "%sNovedades No Monetarias<br>", sMensMail );		
	}
	if(strcmp(argv[2],"R")==0){
		sprintf( sMensMail, "%sRegeneracion<br>", sMensMail );
		sprintf(sMensMail,"%sOficina:%s<br>",sMensMail, argv[3]);
		sprintf(sMensMail,"%sF.Desde:%s|F.Hasta:%s<br>",sMensMail, argv[4], argv[5]);
	}else{
		sprintf( sMensMail, "%sGeneracion<br>", sMensMail );
	}		
	
}
*/


char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;
	int dPos=0;
	
	lLargo=strlen(sCadena);

	for(lPos=0; lPos<lLargo; lPos++){

		if(sCadena[lPos]!= cFind[0]){
			sNvaCadena[dPos]=sCadena[lPos];
			dPos++;
		}else{
			if(strcmp(cRemp, "")!=0){
				sNvaCadena[dPos]=cRemp[0];	
				dPos++;
			}
		}
	}
	
	sNvaCadena[dPos]='\0';

	return sNvaCadena;
}

