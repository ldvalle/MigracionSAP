/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_instalchange
    
	Fecha : 27/01/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura INSTALCHANGE
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0=Activos; 1= No Activos; 2= Todos;		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

*******************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_instalchange.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileInstalacionUnx;

char	sArchInstalacionUnx[100];
char	sSoloArchivoInstalacion[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long	cantActivos;
long	cantInactivos;
long 	cantPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$ClsInstalacion	regInstal;
$long	lFechaLimiteInferior;
$int	iCorrelativos;
$char sFechaRti[9];
$long lFechaRti;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fpIntalacion;
int		iFlagMigra=0;
$long	lNroCliente;
$long	lCorrFacturacion;
$long	lCorrFactuAux;
char	sTarifaAnterior[20];
char	sFechaFactuAnterior[9];
char  sFechaUltiFactura[9];
$char  sFechaUltCambio[9];
char	sTarifaActual[20];
char	sTarifaFactura[20];
char  sCodUlAnterior[9];

char	sTarifaAux[20];
char  sCodUlAux[9];

long	lFecha;
int		iNx;
int		iFlagCambio;
int      iSec;
$long    lFechaValTarifa;
$long    lFechaAltaReal;
$long    lFechaPivote;
int      iCantOcurr;
int      iTeniaPendiente;

$ClsCliente    regCliente;
$ClsFacturas   regFacturas;
$ClsFacturas   regAux;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;
   $SET ISOLATION TO CURSOR STABILITY;

	CreaPrepare();

   memset(sFechaRti, '\0', sizeof(sFechaRti));
   
   $EXECUTE selFechaRti into :sFechaRti, :lFechaRti;

	/*$EXECUTE selFechaLimInf into :lFechaLimiteInferior;*/
		
	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantActivos=0;
	cantInactivos=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

	if(giEstadoCliente == 0){
		if(glNroCliente > 0){
			$OPEN curClienteActivo using :glNroCliente;	
		}else{
			$OPEN curClienteActivo;
		}	
	}else{
		if(glNroCliente > 0){
			$OPEN curClienteInactivo using :glNroCliente;	
		}else{
			$OPEN curClienteInactivo;
		}		
	}

	fpIntalacion=pFileInstalacionUnx;

	while(LeoCliente(&regCliente)){
		if(! ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra, &lFechaValTarifa, &lFechaPivote, &lFechaAltaReal)){
         /*$OPEN curFacturas using :regCliente.numero_cliente, :lFechaRti;*/
			/*$OPEN curFacturas using :regCliente.numero_cliente, :lFechaValTarifa;*/
         $OPEN curFacturas using :regCliente.numero_cliente, :lFechaPivote;

         memset(sFechaFactuAnterior, '\0', sizeof(sFechaFactuAnterior));
         memset(sTarifaAnterior, '\0', sizeof(sTarifaAnterior));
         memset(sCodUlAnterior, '\0', sizeof(sCodUlAnterior));
         memset(sFechaUltiFactura, '\0', sizeof(sFechaUltiFactura));			
         memset(sTarifaAux, '\0', sizeof(sTarifaAux));
         memset(sCodUlAux, '\0', sizeof(sCodUlAux));
         
			iNx=0;
         iSec=1;
         iCantOcurr=0;
			iFlagCambio=0;
         iTeniaPendiente=0;
         
         while (LeoFacturas(&regFacturas)){
            strcpy(sFechaUltiFactura, regFacturas.sFechaFacturacion);
            /*CopiaAux(regFacturas, &regAux);*/
            
            if(iNx==0){ /* primera vuelta*/
               strcpy(sTarifaAnterior, regFacturas.tarifa);
               strcpy(sCodUlAnterior, regFacturas.cod_ul);
					strcpy(sFechaFactuAnterior, regFacturas.sFechaFacturacion);
					alltrim(sTarifaAnterior, ' ');
               
            }else{
            
               if(strcmp(sTarifaAnterior, regFacturas.tarifa)!=0 || strcmp(sCodUlAnterior, regFacturas.cod_ul)!=0){
               
                  /* Tengo que informar la novedad */
                  strcpy(sTarifaAux, sTarifaAnterior);
                  strcpy(sCodUlAux, sCodUlAnterior);
                  
                  strcpy(sTarifaAnterior, regFacturas.tarifa);
                  strcpy(sCodUlAnterior, regFacturas.cod_ul);
                  strcpy(sFechaFactuAnterior, regFacturas.sFechaFacturacion);
                  
                  if(iTeniaPendiente==0){
                     /* Armo la novedad y espero la siguiente para cerrarla e informar */
                     strcpy(regAux.tarifa, regFacturas.tarifa);
                     strcpy(regAux.cod_ul, regFacturas.cod_ul);
                     strcpy(regAux.sFechaFacturacion, regFacturas.sFechaFacturacion);
                     iTeniaPendiente=1;
                  }else if(iTeniaPendiente==1){
                     /* Informo la novedad pendiente y preparo la novedad actual */
                     strcpy(regAux.sFechaHasta, regFacturas.sFechaFacturacion);
                     GenerarPlano(regAux.sFechaFacturacion, regCliente, regAux, iSec);
                     iSec++;
                     /* Armo la novedad y espero la siguiente para cerrarla e informar */
                     strcpy(regAux.tarifa, regFacturas.tarifa);
                     strcpy(regAux.cod_ul, regFacturas.cod_ul);
                     strcpy(regAux.sFechaFacturacion, regFacturas.sFechaFacturacion);
                     iTeniaPendiente=1;
                     
                  }

                  iFlagCambio=1;
               }
            }
            
            iNx++;
         }
         
         $CLOSE curFacturas;
         
         if(iFlagCambio == 1){
            if(iTeniaPendiente == 1){
               /* Ver si los estados del cliente son iguales a la ultima factura*/
               if(strcmp(sTarifaAnterior, regCliente.tarifa)!=0 || strcmp(sCodUlAnterior, regCliente.cod_ul)!=0){
                  /* cierro la pendiente */
                  strcpy(regAux.sFechaHasta, sFechaUltiFactura);
                  GenerarPlano(regAux.sFechaFacturacion, regCliente, regAux, iSec);
                  iSec++;
                  /* lo igualo al estado actual del cliente */
                  strcpy(regAux.tarifa, regCliente.tarifa);
                  strcpy(regAux.cod_ul, regCliente.cod_ul);
                  strcpy(regAux.sFechaFacturacion, sFechaUltiFactura);
                  strcpy(regAux.sFechaHasta, "99991231");
                  GenerarPlano(regAux.sFechaFacturacion, regCliente, regAux, iSec);
               }else{
                  /* cierro la pendiente */
                  strcpy(regAux.sFechaHasta, "99991231");
                  GenerarPlano(regAux.sFechaFacturacion, regCliente, regAux, iSec);
               }
            }
         }

/*			
         $BEGIN WORK;
			if(iFlagCambio==1){
				if(!RegistraCliente(lNroCliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);	
				}
			}
         $COMMIT WORK;
*/         
			cantProcesada++;         
         
		}else{
			cantPreexistente++;			
		}
	}
	
	
	if(giEstadoCliente == 0){
		$CLOSE curClienteActivo;
	}else{
		$CLOSE curClienteInactivo;
	}
			
	CerrarArchivos();

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

	FormateaArchivos();

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
	printf("INSTALL CHANGE.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Clientes Activos :          %ld \n",cantActivos);
	printf("Clientes No Activos :       %ld \n",cantInactivos);
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

	if(argc < 5 || argc > 6){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0){
		MensajeParametros();
		return 0;	
	}
	
	giEstadoCliente=atoi(argv[2]);
	
	strcpy(gsTipoGenera, argv[3]);
	
   giTipoCorrida=atoi(argv[4]);
   
	if(argc==6){
		glNroCliente=atoi(argv[5]);
	}else{
		glNroCliente=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos, 2=Ambos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0=Normal, 1=Reducida\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos()
{
	
	memset(sArchInstalacionUnx,'\0',sizeof(sArchInstalacionUnx));
	memset(sSoloArchivoInstalacion,'\0',sizeof(sSoloArchivoInstalacion));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	if(giEstadoCliente==0){
		sprintf( sArchInstalacionUnx  , "%sT1INSTCHA_Activos.unx", sPathSalida);
		strcpy( sSoloArchivoInstalacion, "T1INSTACHA_Activos.unx");
	}else{
		sprintf( sArchInstalacionUnx  , "%sT1INSTCHA_Inactivos.unx", sPathSalida);
		strcpy( sSoloArchivoInstalacion, "T1INSTACHA_Inactivos.unx");
	}
	
	pFileInstalacionUnx=fopen( sArchInstalacionUnx, "w" );
	if( !pFileInstalacionUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchInstalacionUnx );
		return 0;
	}
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileInstalacionUnx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
	
	if(giEstadoCliente==0){
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/", sPathCopia);
	}else{
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchInstalacionUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchInstalacionUnx, sPathCp);
	iRcv=system(sCommand);
	
	
/*
	if(cantActivos>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchInstalacionUnx, sArchInstalacionDos);
		iRcv=system(sCommand);
	}

	sprintf(sCommand, "rm -f %s", sArchInstalacionUnx);
	iRcv=system(sCommand);	
	
	if(cantInactivos>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchInstalInactivoUnx, sArchInstalInactivoDos);
		iRcv=system(sCommand);
	}
	
	sprintf(sCommand, "rm -f %s", sArchInstalInactivoUnx);
	iRcv=system(sCommand);	
*/
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

   /********* Fecha RTi **********/
	strcpy(sql, "SELECT TO_CHAR(fecha_modificacion, '%Y%m%d'), fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;


	/****** Cursor Clientes Activos ******/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "c.corr_facturacion, ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(t2.cod_sap, '000'), "); 
	strcat(sql, "s.cod_ul_sap || ");
	strcat(sql, "LPAD(CASE WHEN c.sector>60 AND c.sector < 81 THEN c.sector ELSE c.sector END, 2, 0) || "); 
	strcat(sql, "LPAD(c.zona,5,0) "); 
	strcat(sql, "FROM cliente c, sap_transforma t1, OUTER sap_transforma t2, sucur_centro_op s ");

   if(giTipoCorrida == 1)
      strcat(sql, ", migra_activos m ");

	if(glNroCliente > 0){
		strcat(sql, "WHERE c.numero_cliente = ?	");
	}else{
		strcat(sql, "WHERE c.estado_cliente = 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
	}

	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");
	strcat(sql, "AND t2.clave = 'BU_TYPE' "); 
	strcat(sql, "AND t2.cod_mac = c.actividad_economic "); 
	strcat(sql, "AND s.cod_centro_op = c.sucursal ");
	strcat(sql, "AND s.fecha_activacion <= TODAY ");
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) ");
   
  	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
   
   if(giTipoCorrida == 1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	$PREPARE selClienteActivo FROM $sql;
	
	$DECLARE curClienteActivo CURSOR WITH HOLD FOR selClienteActivo;

	/****** Cursor Clientes NO Activos ******/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "c.corr_facturacion, ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");   
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(t2.cod_sap, '000'), "); 
	strcat(sql, "s.cod_ul_sap || ");
	strcat(sql, "LPAD(CASE WHEN c.sector>60 AND c.sector < 81 THEN c.sector ELSE c.sector END, 2, 0) || "); 
	strcat(sql, "LPAD(c.zona,5,0) "); 
	strcat(sql, "FROM cliente c, sap_transforma t1, OUTER sap_transforma t2, sucur_centro_op s ");
   
strcat(sql, ", sap_inactivos si ");

	if(glNroCliente > 0){
		strcat(sql, "WHERE c.numero_cliente = ?	");
	}else{
		strcat(sql, "WHERE c.estado_cliente != 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
	}

	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");
	strcat(sql, "AND t2.clave = 'BU_TYPE' "); 
	strcat(sql, "AND t2.cod_mac = c.actividad_economic "); 
	strcat(sql, "AND s.cod_centro_op = c.sucursal ");
	strcat(sql, "AND s.fecha_activacion <= TODAY ");
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) ");
   
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");

strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
   
	$PREPARE selClienteInactivo FROM $sql;
	
	$DECLARE curClienteInactivo CURSOR WITH HOLD FOR selClienteInactivo;
		
	/******** Cursor Facturas **********/
	strcpy(sql, "SELECT h.corr_facturacion, ");
	strcat(sql, "h.fecha_facturacion, ");
	strcat(sql, "TO_CHAR(h.fecha_facturacion - 1 UNITS DAY, '%Y%m%d'), ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "s.cod_ul_sap || ");
	strcat(sql, "LPAD(CASE WHEN h.sector>60 AND h.sector < 81 THEN h.sector ELSE h.sector END, 2, 0) || "); 
	strcat(sql, "LPAD(h.zona,5,0) "); 
	strcat(sql, "FROM cliente c, hisfac h, sap_transforma t1, sucur_centro_op s ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.fecha_lectura >= ? ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h.tarifa ");
	strcat(sql, "AND s.cod_centro_op = h.sucursal ");
	strcat(sql, "AND s.fecha_activacion <= TODAY ");
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) ");
   strcat(sql, "ORDER BY h.corr_facturacion ASC ");   
   
	$PREPARE selFacturas FROM $sql;
	
	$DECLARE curFacturas CURSOR WITH HOLD FOR selFacturas;	

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
	strcat(sql, "'MODIF', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT modif, fecha_val_tarifa, fecha_alta_real, fecha_pivote FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, modif ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "modif = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;


	/************ FechaLimiteInferior **************/
	/*strcpy(sql, "SELECT TODAY-365 FROM dual ");*/

	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
		
	$PREPARE selFechaLimInf FROM $sql;

	/*********** Correlativos Hacia Atras ***********/		
	strcpy(sql, "SELECT t.valor FROM tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'CORR' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
	
	$PREPARE selCorrelativos FROM $sql;

	/*********** fecha vigencia tarifa ***********/		
	strcpy(sql, "SELECT fecha_val_tarifa, ");
	strcat(sql, "TO_CHAR(fecha_val_tarifa, '%Y%m%d') ");
	strcat(sql, "FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selFechaVigTar FROM $sql;

   /********* Ultima fecha Modif tarifa **********/
   strcpy(sql, "SELECT TO_CHAR(MAX(fecha_modif), '%Y%m%d') FROM modif ");
   strcat(sql, "WHERE numero_cliente = ? ");
   strcat(sql, "AND codigo_modif IN (16, 21) ");

   $PREPARE selUltModif FROM $sql;

   /********* Ultima fecha Modif ruta lectura **********/
   strcpy(sql, "SELECT TO_CHAR(MAX(fecha_modif), '%Y%m%d') FROM modif ");
   strcat(sql, "WHERE numero_cliente = ? ");
   strcat(sql, "AND codigo_modif = 2 ");

   $PREPARE selUltModifUl FROM $sql;

   /************ Tension Actual *************/
	strcpy(sql, "SELECT NVL(s.cod_sap, '00') ");
	strcat(sql, "FROM tecni t, sap_transforma s ");
	strcat(sql, "WHERE t.numero_cliente = ? ");
   strcat(sql, "AND s.clave = 'SPEBENE' ");
	strcat(sql, "AND s.cod_mac = t.codigo_voltaje ");
   
   $PREPARE selVoltaActual FROM $sql;
   
   /************ Electro Actual Actual *************/
	strcpy(sql, "SELECT NVL(s.cod_sap, '00') ");
	strcat(sql, "FROM clientes_vip t, sap_transforma s ");
	strcat(sql, "WHERE t.numero_cliente = ? ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");   
	strcat(sql, "AND s.clave = 'NODISCONCT' ");
	strcat(sql, "AND s.cod_mac = t.motivo ");
   
   $PREPARE selElectroActual FROM $sql;
   	
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

short ClienteYaMigrado(nroCliente, iFlagMigra, lFecha, lPivote, lFechaReal)
$long	nroCliente;
int		*iFlagMigra;
$long    *lFecha;
$long    *lPivote;
$long    *lFechaReal;
{
	$char	sMarca[2];
   $long lFechaVig;
	$long lFechaAlta;
   $long lFechaPivote;
   
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado INTO :sMarca, :lFechaVig, :lFechaAlta, :lFechaPivote using :nroCliente;
		
	if(SQLCODE != 0){
 		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}

   *lFecha = lFechaVig;
   *lFechaReal = lFechaAlta;
   *lPivote = lFechaPivote;

	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
      
   	if(gsTipoGenera[0]=='R'){
   		return 0;	
   	}
		return 1;
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
   
	return 0;
}
                   

short GenerarPlano(sFechaDesde, regCliente, regFactura, iSec)
char        sFechaDesde[9];
ClsCliente  regCliente;
ClsFacturas regFactura;
int         iSec;
{

	/* KEY */	
	GeneraKEY(regCliente, regFactura, iSec);

	/* DATA */	
	GeneraDATA(sFechaDesde, regCliente, regFactura, iSec);	
	
	/* ENDE */
	GeneraENDE(regCliente, iSec);
	
	return 1;
}

void GeneraENDE(regCliente, iSec)
$ClsCliente       regCliente;
int               iSec;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%d\t&ENDE", regCliente.numero_cliente, iSec);

	strcat(sLinea, "\n");
	
	fprintf(pFileInstalacionUnx, sLinea);	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "MODIF");
		strcpy(sNombreArchivo, sSoloArchivoInstalacion);
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

	if(iFlagMigra==1){
		$EXECUTE insClientesMigra using :nroCliente;
	}else{
		$EXECUTE updClientesMigra using :nroCliente;
	}

	return 1;
}

void GeneraKEY(regCliente, regFacturas, iSec)
ClsCliente     regCliente;
ClsFacturas    regFacturas;
int      iSec;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
	sprintf(sLinea, "T1%ld-%d\tKEY\t", regCliente.numero_cliente, iSec);
   /* ANLAGE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
   /* BIS Fecha Hasta */
   sprintf(sLinea, "%s%s", sLinea, regFacturas.sFechaHasta);
	
	strcat(sLinea, "\n");
	
	fprintf(pFileInstalacionUnx, sLinea);	
	
}

void GeneraDATA(sFechaDesde, regCliente, regFactura, iSec)
char        sFechaDesde[9];
ClsCliente  regCliente;
ClsFacturas regFactura;
int         iSec;
{
	char	sLinea[1000];	
   long  lFechaRti;
   long  lFechaFactura;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
   /* LLAVE */
	sprintf(sLinea, "T1%ld-%d\tDATA\t", regCliente.numero_cliente, iSec);
   /* VSTELLE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
   /* SPEBENE */
   if(strcmp(regCliente.codigo_voltaje, "00")!=0){
      sprintf(sLinea, "%s%s\t", sLinea, regCliente.codigo_voltaje);
   }else{
      strcat(sLinea, "\t");
   }
   /* ANLART */
   strcat(sLinea, "0007\t");
   
   /* NODISCONCT */
   if(strcmp(regCliente.catego_electro, "00")!=0){
      sprintf(sLinea, "%s%s\t", sLinea, regCliente.catego_electro);
   }else{
      strcat(sLinea, "\t");
   }
   
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, sFechaDesde);
   
   /* TARIFTYP */
   lFechaRti = atol(sFechaRti);
   lFechaFactura = atol(regFactura.sFechaFacturacion);
   sprintf(sLinea, "%s%s\t", sLinea, regFactura.tarifa);
/*   
   if(lFechaFactura > lFechaRti){
	  sprintf(sLinea, "%s%s\t", sLinea, regFactura.tarifa);
   }else{
      strcat(sLinea, "DUMMY\t");
   }
*/   
   /* BRANCHE */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.ramo);
   /* AKLASSE */
	strcat(sLinea, "EDE\t");
   /* ABLEINH */
	sprintf(sLinea, "%s%s\t", sLinea, regFactura.cod_ul);
   /* BEGRU */
   strcat(sLinea, "T1\t");
   /* ETIMEZONE */
   strcat(sLinea, "UTC-3");

	strcat(sLinea, "\n");
	
	fprintf(pFileInstalacionUnx, sLinea);
}


short LeoCliente(reg)
$ClsCliente *reg;
{

   InicializaCliente(reg);
	
	if(giEstadoCliente == 0){
		$FETCH curClienteActivo INTO :reg->numero_cliente,
         :reg->corr_facturacion,
         :reg->tarifa,
         :reg->ramo,
         :reg->cod_ul;
       
	}else{
		$FETCH curClienteInactivo  INTO :reg->numero_cliente,
         :reg->corr_facturacion,
         :reg->tarifa,
         :reg->ramo,
         :reg->cod_ul;
	}
	
	if(SQLCODE !=0){
		if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al recorrer Clientes.\n");
		}	
		
	}

   strcpy(reg->codigo_voltaje, getVoltaActual(reg->numero_cliente));
   strcpy(reg->catego_electro, getElectroActual(reg->numero_cliente));
   
   alltrim(reg->tarifa, ' ');
   alltrim(reg->ramo, ' ');
   alltrim(reg->cod_ul, ' ');
   alltrim(reg->codigo_voltaje, ' ');
   alltrim(reg->catego_electro, ' ');
	
	return 1;
}

void InicializaCliente(reg)
ClsCliente *reg;
{

	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->corr_facturacion));
	memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->ramo, '\0', sizeof(reg->ramo));
   memset(reg->cod_ul, '\0', sizeof(reg->cod_ul));
   memset(reg->codigo_voltaje, '\0', sizeof(reg->codigo_voltaje));
   memset(reg->catego_electro, '\0', sizeof(reg->catego_electro));

}


short getFechaVigTarifa(lNroCliente, reg)
$long lNroCliente;
$ClsInstalacion *reg;
{
	$EXECUTE selFechaVigTar into :reg->lFechaFacturacion, :reg->sFechaFacturacion
			using :lNroCliente;
				
	if(SQLCODE!=0){
		return 0;	
	}
	
	return 1;
}

void CopiaAux(regOri, regDest)
ClsFacturas regOri;
ClsFacturas *regDest;
{

   regDest->corr_facturacion = regOri.corr_facturacion;
   regDest->lFechaFacturacion = regOri.lFechaFacturacion;
   strcpy(regDest->sFechaFacturacion, regOri.sFechaFacturacion);
   strcpy(regDest->tarifa, regOri.tarifa);
   strcpy(regDest->cod_ul, regOri.cod_ul);

}

char *getVoltaActual(lNroCliente)
$long lNroCliente;
{
   $char sValor[3];
   
   memset(sValor, '\0', sizeof(sValor));
   
   $EXECUTE selVoltaActual INTO :sValor USING :lNroCliente;
   
   if(SQLCODE != 0){
      strcpy(sValor, "00");
   }
   
   alltrim(sValor, ' ');
   
   return sValor; 
}

char *getElectroActual(lNroCliente)
$long lNroCliente;
{
   $char sValor[7];
   
   memset(sValor, '\0', sizeof(sValor));
   
   $EXECUTE selElectroActual INTO :sValor USING :lNroCliente;
   
   if(SQLCODE != 0){
      strcpy(sValor, "00");
   }
   
   alltrim(sValor, ' ');
   
   return sValor; 
}

short LeoFacturas(reg)
$ClsFacturas *reg;
{

   InicializaFacturas(reg);
   
   $FETCH curFacturas INTO :reg->corr_facturacion,
      :reg->lFechaFacturacion,
      :reg->sFechaFacturacion,
      :reg->tarifa,
      :reg->cod_ul;
   
   if(SQLCODE !=0 ){
      return 0;
   }   
   
   alltrim(reg->sFechaFacturacion, ' ');
   alltrim(reg->tarifa, ' ');
   alltrim(reg->cod_ul, ' ');
   
   return 1;
}

void InicializaFacturas(reg)
ClsFacturas *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaFacturacion));
	memset(reg->sFechaFacturacion, '\0', sizeof(reg->sFechaFacturacion));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->cod_ul, '\0', sizeof(reg->cod_ul));
   memset(reg->sFechaHasta, '\0', sizeof(reg->sFechaHasta));
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

