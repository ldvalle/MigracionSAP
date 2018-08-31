/*******************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_lecturas
    
	Fecha : 19/01/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura Historico de Lecturas
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0 = Activos;  1 = No Activos 
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

*****************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_lecturas.h";

/* Variables Globales */
$int	giEstadoCliente;
$long	glNroCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileLecturasUnx;

char	sArchLecturasUnx[100];
char	sSoloArchivoLecturas[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];

long	lCorrelativo;
long	lIndiceArchivo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$ClsLecturas	regLecturas;
$ClsFPLectu		regFPLectu;
$long	lFechaLimiteInferior;
$int	iCorrelativos;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$long	lNroCliente=0;
$long	lCorrFactu=0;
$long   lCorrFactuActu=0;
char	sFechaFacturacion[9];
ClsLecturas	regLectuAux;
char	*vSucursal[]={"0003", "0004", "0010", "0020", "0023", "0026", "0050", "0065", "0053", "0056", "0059", "0069"};
$char	sSucursal[5];
int		i;
$long lFechaValTarifa;
$long lFechaMoveIn;
$long lFechaPivote;
int      iVuelta;
long  lFechaAux;

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
	
	CreaPrepare1();

	/*$EXECUTE selFechaLimInf into :lFechaLimiteInferior;*/
		
	/*$EXECUTE selCorrelativos into :iCorrelativos;*/
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

	
	memset(sSucursal, '\0', sizeof(sSucursal));
	/* i=0 para iniciar desde el ppio */
   
   
	for(i=0; i<12; i++){
   
		CreaPrepare();
		
		strcpy(sSucursal, vSucursal[i]);

		if(!AbreArchivos(sSucursal)){
			exit(1);	
		}
		
		if(glNroCliente > 0){
			$OPEN curClientes using :glNroCliente, :sSucursal;
		}else{
			$OPEN curClientes using :sSucursal;
		}
		
		printf("Procesando Sucursal %s......\n", sSucursal);
			
		while(LeoClientes(&lNroCliente, &lCorrFactu)){
			/*$BEGIN WORK;*/
			if(lCorrFactu > 0){
				/*if(! ClienteYaMigrado(lNroCliente, &iFlagMigra, &lFechaValTarifa, &lFechaMoveIn)){*/
            if(! ClienteYaMigrado(lNroCliente, &iFlagMigra, &lFechaPivote, &lFechaMoveIn)){
               iVuelta=1;
					lIndiceArchivo=1;
					/*lCorrFactu=getCorrFactu(lNroCliente);*/
               /*
					lCorrFactu=lCorrFactu - iCorrelativos;
					if(lCorrFactu <= 0){
						lCorrFactu=1;
					}else{
						if(getTramoFactu(lNroCliente, lCorrFactu)==2)
							lCorrFactu=lCorrFactu-1;
					}
	            */
               /*
					if(ExisteFactura(lNroCliente, lCorrFactu)){
               */										
						/* Proceso Lecturas Activas */
                  /*$OPEN curLectuActi using :lNroCliente, :lFechaValTarifa;*/			
						/*$OPEN curLectuActi using :lNroCliente, :lFechaLimiteInferior, :lCorrFactu;*/
                  /*$OPEN curLectuActi using :lNroCliente, :lFechaValTarifa, :lCorrFactu;*/
                  /*$OPEN curLectuActi using :lNroCliente, :lFechaPivote, :lCorrFactu;*/
                  $OPEN curLectuActi using :lNroCliente, :lFechaPivote;
                  
												
						while(LeoLecturasActivas(lNroCliente, &regLecturas)){
                     if(iVuelta==1){
            				rdefmtdate(&lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); /*char a long*/
            				lFechaAux=lFechaAux+1;
            				rfmtdate(lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); /* long to char */
                     }
                     
				         if((iVuelta ==1 && regLecturas.tipo_lectura != 8) || (iVuelta > 1)){
    							if (!GenerarPlano("A", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
    								/*$ROLLBACK WORK;*/
    								exit(1);	
    							}
    							
    							if(regLecturas.tipo_medidor[0]=='R'){
    								/* Si el medidor es de Reactiva, busco la lectura Reactiva */
    								DuplicaRegistro(regLecturas, &regLectuAux);
    								
    								if(getUltimoConsumoReactiva(1, lNroCliente, regLecturas.corr_facturacion, &regLecturas)){
                              if(iVuelta==1){
                     				rdefmtdate(&lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); /*char a long*/
                     				lFechaAux=lFechaAux+1;
                     				rfmtdate(lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); /* long to char */
                              }
                           
    									if (!GenerarPlano("R", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
    										/*$ROLLBACK WORK;*/
    										exit(1);	
    									}					
    								}else{
    									if (!GenerarPlano("R", pFileLecturasUnx, regLectuAux, lFechaMoveIn)){
    										/*$ROLLBACK WORK;*/
    										exit(1);	
    									}
    								}
    							}
                        GeneraENDE(pFileLecturasUnx, regLecturas);
                     }
                     
                     iVuelta++;
						}/* Cursor Lecturas Activas */
						
						$CLOSE curLectuActi;
						
						/* Proceso FP_Lectu  */
               
						if(getFPLectu(lNroCliente, &regFPLectu)){
							/* Informo Tramo sin facturar */ 
							CargoLectuFP("A", regFPLectu, &regLecturas);
							regLecturas.corr_facturacion++;
							if (!GenerarPlano("A", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
								exit(1);	
							}
							if(regFPLectu.tipo_medidor[0]=='R'){
								CargoLectuFP("R", regFPLectu, &regLecturas);	
								if (!GenerarPlano("R", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
									exit(1);	
								}						
							}
                     GeneraENDE(pFileLecturasUnx, regLecturas);
						}else{
							/* Invento tramo con ultimo consumo */
/*                    
							memset(sFechaFacturacion, '\0', sizeof(sFechaFacturacion));
							
							$EXECUTE selCorrFactuActu into :lCorrFactuActu using :lNroCliente;
								
						    if ( SQLCODE != 0 ){
						    	printf("Error al buscar Correlativo Actual para cliente %ld\nProceso Abortado.\n", lNroCliente);
								exit(1);	
						    }
						    
							if(getUltimoConsumoActiva(lNroCliente, lCorrFactuActu, &regLecturas)){
								regLecturas.corr_facturacion++;
								strcpy(sFechaFacturacion, regLecturas.fecha_lectura);
								
								if (!GenerarPlano("A", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
									exit(1);	
								}					
							}
							if(regLecturas.tipo_medidor[0]=='R'){
								DuplicaRegistro(regLecturas, &regLectuAux);
								if(getUltimoConsumoReactiva(2, lNroCliente, lCorrFactuActu, &regLecturas)){
									regLecturas.corr_facturacion++;
									strcpy(regLecturas.fecha_lectura, sFechaFacturacion);
									if (!GenerarPlano("R", pFileLecturasUnx, regLecturas, lFechaMoveIn)){
										exit(1);	
									}
								}else{
									regLectuAux.corr_facturacion++;
									strcpy(regLectuAux.fecha_lectura, sFechaFacturacion);
									if (!GenerarPlano("R", pFileLecturasUnx, regLectuAux, lFechaMoveIn)){
										exit(1);	
									}							
								}
							}
*/                     
						}
		
						/*
						GeneraENDE(pFileLecturasUnx, regLecturas);
						*/
/*                  
                  $BEGIN WORK;
                  
						if(!RegistraCliente(lNroCliente, iFlagMigra)){
							$ROLLBACK WORK;
							exit(1);	
						}
                  
                  $COMMIT WORK;
*/                  			
						cantProcesada++;
               /*                  
					} 
               */
               
				}else{
					cantPreexistente++;
				}/* Cliente Migrado*/
			}
			/*$COMMIT WORK;*/	
		}/* Cursor Clientes */
		$CLOSE curClientes;
		
		CerrarArchivos();
		
		FormateaArchivos();
		
	}/* cursor sucursal */

	/* Registrar Control Plano */
/*	
	$BEGIN WORK;
	
	CreaPrepare2();
	
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
	printf("LECTURAS.\n");
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

	if(argc < 5 || argc > 6){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

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
		printf("	<Estado Cliente> 0 = Activo,  1 = No Activo.\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0 = Normal,  1 = Reducida.\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos(sSucur)
char	sSucur[5];
{
	
	memset(sArchLecturasUnx,'\0',sizeof(sArchLecturasUnx));
	memset(sSoloArchivoLecturas,'\0',sizeof(sSoloArchivoLecturas));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

/*
	sprintf( sArchLecturasUnx  , "%sLecturas_T1_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativo );
	sprintf( sSoloArchivoLecturas, "Lecturas_T1_%s_%d.txt", FechaGeneracion, lCorrelativo );
*/
	sprintf( sArchLecturasUnx  , "%sT1MTREAD_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchivoLecturas, "T1MTREAD_%s.unx", sSucur );
	
	pFileLecturasUnx=fopen( sArchLecturasUnx, "w" );
	if( !pFileLecturasUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchLecturasUnx );
		return 0;
	}
	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileLecturasUnx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char 	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	sprintf(sCommand, "chmod 755 %s", sArchLecturasUnx);
	iRcv=system(sCommand);
	
	if(giEstadoCliente==0){
		/*sprintf(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/Lecturas/", sPathCopia);
	}else{
		/*sprintf(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}
	
	sprintf(sCommand, "cp %s %s", sArchLecturasUnx, sPathCp);
	iRcv=system(sCommand);

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
	
}

void CreaPrepare2(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));	

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
	strcat(sql, "'LECTURAS', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenLectu FROM $sql;*/	
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
/*	
	strcpy(sql, "SELECT cod_centro_op ");
	strcat(sql, "FROM sucur_centro_op ");
	strcat(sql, "WHERE cod_sucur_sap IS NOT NULL ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
	
	$PREPARE selSucur FROM $sql;
	$DECLARE curSucur CURSOR for selSucur;
*/
	/******** Cursor CLIENTES  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, NVL(c.corr_facturacion -1, 0) FROM cliente c ");

   if(giTipoCorrida == 1)	
      strcat(sql, ", migra_activos ma ");
	
	if(giEstadoCliente==0){
		strcat(sql, "WHERE c.estado_cliente = 0 ");
	}else{
		strcat(sql, ", sap_inactivos si ");
		strcat(sql, "WHERE c.estado_cliente != 0 ");
	}
	
	if(glNroCliente > 0 ){
		strcat(sql, "AND c.numero_cliente = ? ");
	}
	strcat(sql, "AND c.sucursal = ? ");
	strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND c.sector != 88 ");

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
		
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	

   if(giTipoCorrida==1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;
	
	/******** Sel Tramo Factura  ************/	
	strcpy(sql, "SELECT h.tipo_lectura FROM hislec h ");
	strcat(sql, "WHERE h.numero_cliente = ? ");
	strcat(sql, "AND h.corr_facturacion = ? ");
	strcat(sql, "AND h.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h.fecha_lectura = (SELECT MAX(h2.fecha_lectura) FROM hislec h2 ");
	strcat(sql, "	WHERE h2.numero_cliente = h.numero_cliente ");
	strcat(sql, "	AND h2.corr_facturacion = h.corr_facturacion ");
	strcat(sql, "	AND h2.tipo_lectura NOT IN (5, 6, 7)) ");
	
	$PREPARE selTramo FROM $sql;

	/******** Sel Tramo Factura  Ver.2 ************/	
	strcpy(sql, "SELECT c.corr_facturacion, h.tipo_lectura ");
	strcat(sql, "FROM cliente c, hislec h ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.corr_facturacion = c.corr_facturacion - 1 ");
	strcat(sql, "AND h.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h.fecha_lectura = (SELECT MAX(h2.fecha_lectura) FROM hislec h2 ");
	strcat(sql, "	WHERE h2.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND h2.corr_facturacion = c.corr_facturacion - 1 ");
	strcat(sql, "	AND h2.tipo_lectura NOT IN (5, 6, 7)) ");
	
	$PREPARE selTramoV2 FROM $sql;
	
	/******** Sel CorrFacturacion  ****************/
	strcpy(sql, "SELECT MAX(corr_facturacion) FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_facturacion <= TODAY - 365 ");

	$PREPARE selCorrFactu FROM $sql;
	
	/******** Sel CorrFacturacion  Cliente****************/
   /*strcpy(sql, "SELECT corr_facturacion -1 FROM cliente ");*/
	strcpy(sql, "SELECT corr_facturacion FROM cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selCorrFactuActu FROM $sql;
	
	/******** Cursor Lecturas Activas ****************/
	strcpy(sql, "SELECT h1.numero_cliente, ");
	strcat(sql, "h1.corr_facturacion, ");
	strcat(sql, "TO_CHAR(h1.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "h1.tipo_lectura, ");
	strcat(sql, "t1.cod_sap, ");
	strcat(sql, "h1.lectura_facturac, ");
	strcat(sql, "h1.consumo, ");
	strcat(sql, "h2.indica_refact, ");
	strcat(sql, "h1.numero_medidor, ");
	strcat(sql, "h1.marca_medidor, ");
	strcat(sql, "med.mod_codigo, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
	strcat(sql, "TO_CHAR(a.fecha_generacion, '%Y%m%d') ");
	strcat(sql, "FROM hislec h1, hisfac h2, medidor med, modelo m, sap_transforma t1, agenda a ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
   strcat(sql, "AND h1.fecha_lectura >= ? ");
/*   
	strcat(sql, "AND h1.corr_facturacion <= ? ");
*/   
	strcat(sql, "AND h1.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.corr_facturacion = h1.corr_facturacion "); 
	strcat(sql, "AND med.med_numero = h1.numero_medidor ");
	strcat(sql, "AND med.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND med.cli_tarifa = 'T1' ");
	strcat(sql, "AND m.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND m.mod_codigo = med.mod_codigo ");
	strcat(sql, "AND t1.clave = 'TIPOLECTU' ");
	strcat(sql, "AND t1.cod_mac = h1.tipo_lectura ");
	strcat(sql, "AND a.sucursal = h2.sucursal ");
	strcat(sql, "AND a.sector = h2.sector ");
	strcat(sql, "AND a.fecha_emision_real = h2.fecha_facturacion ");

	strcat(sql, "ORDER BY 2 ASC ");
	
	$PREPARE selLectuActi FROM $sql;
	
	$DECLARE curLectuActi CURSOR FOR selLectuActi;


	/************* Lectura/Consumo Activa *************/
	strcpy(sql, "SELECT h1.numero_cliente, ");
	strcat(sql, "h1.corr_facturacion, ");
	strcat(sql, "TO_CHAR(h2.fecha_facturacion, '%Y%m%d'), ");
	strcat(sql, "h1.tipo_lectura, ");
	strcat(sql, "t1.cod_sap, ");
	strcat(sql, "h1.lectura_facturac, ");
	strcat(sql, "h1.consumo, ");
	strcat(sql, "h2.indica_refact, ");
	strcat(sql, "h1.numero_medidor, ");
	strcat(sql, "h1.marca_medidor, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
   strcat(sql, "TO_CHAR(a.fecha_generacion, '%Y%m%d') ");
/*	
	strcat(sql, "FROM hislec h1, hisfac h2, medidor med, modelo m, sap_transforma t1 ");
*/
	strcat(sql, "FROM hislec h1, hisfac h2, medid m, sap_transforma t1, agenda a ");
	
	strcat(sql, "WHERE h1.numero_cliente = ? ");
   
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.corr_facturacion = h1.corr_facturacion "); 
	strcat(sql, "AND m.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = h1.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = h1.marca_medidor ");
/*	
	strcat(sql, "AND med.med_numero = h1.numero_medidor ");
	strcat(sql, "AND med.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND med.cli_tarifa = 'T1' ");
	strcat(sql, "AND m.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND m.mod_codigo = med.mod_codigo ");
*/	
	strcat(sql, "AND t1.clave = 'TIPOLECTU' ");
	strcat(sql, "AND t1.cod_mac = h1.tipo_lectura ");
	strcat(sql, "AND a.sucursal = h2.sucursal ");
	strcat(sql, "AND a.sector = h2.sector ");
	strcat(sql, "AND a.fecha_emision_real = h2.fecha_facturacion ");
	
	$PREPARE selConsuActi FROM $sql;	
	$DECLARE curConsuActi cursor for selConsuActi;
	
	/*********** Lecturas Reactivas ***********/
	strcpy(sql, "SELECT h1.numero_cliente, ");
	strcat(sql, "h1.corr_facturacion, ");
	strcat(sql, "TO_CHAR(h1.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "h1.tipo_lectura, ");
	strcat(sql, "t1.cod_sap, ");
	strcat(sql, "h1.lectu_factu_reac, ");
	strcat(sql, "h1.consumo_reac, ");
	strcat(sql, "h2.indica_refact, ");
	strcat(sql, "h1.numero_medidor, ");
	strcat(sql, "h1.marca_medidor, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
   strcat(sql, "TO_CHAR(a.fecha_generacion, '%Y%m%d') ");
	/*
	strcat(sql, "FROM hislec_reac h1, hisfac h2, medidor med, modelo m, sap_transforma t1 ");
	*/
	strcat(sql, "FROM hislec_reac h1, hisfac h2, medid m, sap_transforma t1, agenda a ");
	
	strcat(sql, "WHERE h1.numero_cliente = ? ");
  
	strcat(sql, "AND h1.corr_facturacion = ? ");
   
	strcat(sql, "AND h1.tipo_lectura NOT IN (5, 6, 7) ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.corr_facturacion = h1.corr_facturacion "); 
	strcat(sql, "AND m.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = h1.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = h1.marca_medidor ");	
/*	
	strcat(sql, "AND med.med_numero = h1.numero_medidor ");
	strcat(sql, "AND med.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND med.cli_tarifa = 'T1' ");
	strcat(sql, "AND m.mar_codigo = h1.marca_medidor ");
	strcat(sql, "AND m.mod_codigo = med.mod_codigo ");
*/
	
	strcat(sql, "AND t1.clave = 'TIPOLECTU' ");
	strcat(sql, "AND t1.cod_mac = h1.tipo_lectura ");
	strcat(sql, "AND a.sucursal = h2.sucursal ");
	strcat(sql, "AND a.sector = h2.sector ");
	strcat(sql, "AND a.fecha_emision_real = h2.fecha_facturacion ");
		
	$PREPARE selLectuReac FROM $sql;
	$DECLARE curLectuReac cursor for selLectuReac;
	
	/******** Sel Hislec Rectificado *********/
	strcpy(sql, "SELECT h1.lectura_rectif, h1.consumo_rectif ");
	strcat(sql, "FROM hislec_refac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura) ");
   
	$PREPARE selHislecRefac FROM $sql;

	/******** Sel Hislec Reac Rectificado *********/
	strcpy(sql, "SELECT h1.lectu_rectif_reac, h1.consu_rectif_reac ");
	strcat(sql, "FROM hislec_refac_reac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac_reac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura )" );
   
	$PREPARE selHislecReacRefac FROM $sql;	
	
	/******** Sel FP_LECTU *********/	
	strcpy(sql, "SELECT l.numero_cliente, ");
	strcat(sql, "l.corr_facturacion + 2, ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN l.ind_verificacion = 'S' THEN TO_CHAR(l.fecha_lectura_ver, '%Y%m%d') ");
   strcat(sql, "	ELSE TO_CHAR(l.fecha_lectura, '%Y%m%d') ");
	strcat(sql, "END fecha_lectura, ");
	strcat(sql, "l.tipo_lectura, ");
	strcat(sql, "t1.cod_sap, ");
	strcat(sql, "CASE ");
	strcat(sql, "   WHEN l.tipo_lectura = 1 THEN l.lectura_prop ");
	strcat(sql, "   WHEN l.tipo_lectura = 2 THEN l.lectura_actual ");
	strcat(sql, "   WHEN l.tipo_lectura = 3 THEN l.lectura_verif ");
	strcat(sql, "   WHEN l.tipo_lectura = 4 THEN l.lectura_a_fact ");
	strcat(sql, "   WHEN l.tipo_lectura IS NULL AND l.lectura_actual IS NOT NULL THEN l.lectura_actual ");
	strcat(sql, "END lectura_activa, ");
	strcat(sql, "CASE ");
	strcat(sql, "   WHEN l.tipo_lectura_reac = 1 THEN l.lectura_prop_reac ");
	strcat(sql, "   WHEN l.tipo_lectura_reac = 2 THEN l.lectu_actual_reac ");
	strcat(sql, "   WHEN l.tipo_lectura_reac = 3 THEN l.lectura_verif_reac ");
	strcat(sql, "   WHEN l.tipo_lectura_reac = 4 THEN l.lectu_a_fact_reac ");
	strcat(sql, "   WHEN l.tipo_lectura_reac IS NULL AND l.lectu_actual_reac IS NOT NULL THEN l.lectu_actual_reac ");
	strcat(sql, "END lectura_reactiva, ");
	strcat(sql, "l.cons_activa_p2, ");
	strcat(sql, "l.cons_reac_p2, ");
	strcat(sql, "l.numero_medidor, ");
	strcat(sql, "l.marca_medidor, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A') ");
	/*
	strcat(sql, "FROM fp_lectu l, sap_transforma t1, medidor med, modelo m ");
	*/
	strcat(sql, "FROM fp_lectu l, sap_transforma t1, medid m ");
	strcat(sql, "WHERE l.numero_cliente = ? ");
	strcat(sql, "AND (( ? = l.corr_facturacion) OR ( ? = l.corr_fact_ant)) ");
	strcat(sql, "AND t1.clave = 'TIPOLECTU' ");
	strcat(sql, "AND t1.cod_mac = l.tipo_lectura ");
	strcat(sql, "AND m.numero_cliente = l.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = l.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = l.marca_medidor ");
	
/*	
	strcat(sql, "AND med.med_numero = l.numero_medidor ");
	strcat(sql, "AND med.mar_codigo = l.marca_medidor ");
	strcat(sql, "AND med.cli_tarifa = 'T1' ");
	strcat(sql, "AND m.mar_codigo = l.marca_medidor ");
	strcat(sql, "AND m.mod_codigo = med.mod_codigo ");
*/
	
	$PREPARE selFPLectu FROM $sql;
	
	$DECLARE curFPLectu CURSOR FOR selFPLectu;
	
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

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT lecturas, fecha_pivote, fecha_move_in FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, lecturas ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "lecturas = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ Existe Factura *************/
	strcpy(sql, "SELECT COUNT(*) FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	
	$PREPARE selFactura FROM $sql;
	
	
		
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

short getTramoFactu(lNroCliente, lCorrFactu)
$long	lNroCliente;
$long	lCorrFactu;
{
	$int iTipoLectu=0;
	short salida=0;
	
	$EXECUTE selTramo into :iTipoLectu using :lNroCliente, :lCorrFactu;
		
    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo error al tratar de determinar tramo factura para cliente %ld correlativo %ld.\n", lNroCliente, lCorrFactu);
        exit(1);
    }
    
    switch(iTipoLectu){
    	case 8:
    		salida=1;
    		break;
    	default:
    		salida=2;
    		break;
    }
    
    return salida;
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

short LeoClientes(lNroCliente, lCorrFactura)
$long *lNroCliente;
$long *lCorrFactura;
{
	$long lNroClienteLocal;
	$long lCorrLocal;
	
	$FETCH curClientes into
		:lNroClienteLocal,
		:lCorrLocal;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }
	
	*lNroCliente = lNroClienteLocal;
	*lCorrFactura = lCorrLocal;
	
	return 1;
}

long getCorrFactu(lNroCliente)
$long  lNroCliente;
{
	$long lCorrFactu=0;
	
	$EXECUTE selCorrFactu into :lCorrFactu using :lNroCliente;
		
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al buscar Correlativo de Facturación para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }
    			
	return lCorrFactu;
}

short LeoLecturasActivas(lNroCliente, regLectu)
$long		lNroCliente;
$ClsLecturas *regLectu;
{
	$double dLectuRectif=0.0;
	$double dConsuRectif=0.0;
	
	InicializaLecturas(regLectu);

	$FETCH curLectuActi into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->fecha_lectura,
		:regLectu->tipo_lectura,
		:regLectu->tipo_lectu_sap,
		:regLectu->lectura_facturac,
		:regLectu->consumo,
		:regLectu->indica_refact,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->modelo_medidor,
		:regLectu->tipo_medidor,
      :regLectu->fecha_generacion;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor Lecturas Activas para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }

	alltrim(regLectu->tipo_lectu_sap, ' ');
	
	if(regLectu->indica_refact[0]=='S'){
		/* Buscar la actualizada */

		$EXECUTE selHislecRefac into :dLectuRectif, :dConsuRectif using :lNroCliente, 
																		:regLectu->corr_facturacion,
																		:regLectu->tipo_lectura;

	    if ( SQLCODE != 0 ){
	    	if(SQLCODE != 100){
				printf("Error al leer Cursor Lecturas Activas Rectificadas para cliente %ld\nProceso Abortado.\n", lNroCliente);
				exit(1);	
			}
	    }else{
	    	regLectu->lectura_facturac = dLectuRectif;
	    	regLectu->consumo = dConsuRectif;
	    }
	}
	
	return 1;	
}

void InicializaLecturas(regLectu)
$ClsLecturas	*regLectu;
{
	rsetnull(CLONGTYPE, (char *) &(regLectu->numero_cliente));
	rsetnull(CLONGTYPE, (char *) &(regLectu->corr_facturacion));
	memset(regLectu->fecha_lectura, '\0', sizeof(regLectu->fecha_lectura));
	rsetnull(CINTTYPE, (char *) &(regLectu->tipo_lectura));
	memset(regLectu->tipo_lectu_sap, '\0', sizeof(regLectu->tipo_lectu_sap));
	rsetnull(CDOUBLETYPE, (char *) &(regLectu->lectura_facturac));
	rsetnull(CDOUBLETYPE, (char *) &(regLectu->consumo));
	memset(regLectu->indica_refact, '\0', sizeof(regLectu->indica_refact));
	
	rsetnull(CLONGTYPE, (char *) &(regLectu->numero_medidor));
	memset(regLectu->marca_medidor, '\0', sizeof(regLectu->marca_medidor));
	memset(regLectu->modelo_medidor, '\0', sizeof(regLectu->modelo_medidor));
	memset(regLectu->tipo_medidor, '\0', sizeof(regLectu->tipo_medidor));
	memset(regLectu->fecha_generacion, '\0', sizeof(regLectu->fecha_generacion));
}

short ClienteYaMigrado(nroCliente, iFlagMigra, lPivote, lMoveIn)
$long	nroCliente;
int		*iFlagMigra;
$long    *lPivote;
$long    *lMoveIn;
{
	$char	sMarca[2];
	$long   lFechaPivote;
   $long   lFechaMoveIn;
   
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado INTO :sMarca, :lFechaPivote, :lFechaMoveIn 
         USING :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
   *lPivote=lFechaPivote;
   *lMoveIn=lFechaMoveIn;
   
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
      
   	if(gsTipoGenera[0]!='R'){
   		return 1;	
   	}
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
	return 0;
}


short GenerarPlano(sTabla, fp, regLectu, lFechaMv)
char				sTabla[2];
FILE 				*fp;
$ClsLecturas		regLectu;
long           lFechaMv;
{

	/* IEABLU */	
	GeneraIEABLU(sTabla, fp, regLectu, lFechaMv);	
	
	return 1;
}

void GeneraENDE(fp, regLectu)
FILE *fp;
$ClsLecturas	regLectu;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regLectu.numero_cliente, regLectu.corr_facturacion);

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
		strcpy(sTipoArchivo, "LECTURAS");
		strcpy(sNombreArchivo, sSoloArchivoLecturas);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenLectu using
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


void GeneraIEABLU(sTabla, fp, regLectu, lFechaMv)
char			sTabla[2];
FILE 			*fp;
ClsLecturas		regLectu;
long        lFechaMv;
{
	char	   sLinea[1000];	
	int		iNumerador;
   long     lFechaLectura;
	long     lFechaAux;
   
	memset(sLinea, '\0', sizeof(sLinea));

   rdefmtdate(&lFechaLectura, "yyyymmdd", regLectu.fecha_lectura); /*char a long*/
   
   if(lFechaLectura == lFechaMv){
      lFechaAux=lFechaLectura+1;
      rfmtdate(lFechaAux, "yyyymmdd", regLectu.fecha_lectura); /* long to char */   
   }

	/**** Real Bimestral ****/	
	if(regLectu.tipo_lectura!=8 && regLectu.tipo_lectura!=0){

		sprintf(sLinea, "T1%ld-%ld\tIEABLU\t", regLectu.numero_cliente, regLectu.corr_facturacion);
      /* EQUNR */
		sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
		
		/* ZWNUMMER */
		if(regLectu.tipo_medidor[0]=='A'){
			iNumerador=1; /* Activa Real*/
		}else{
			if(sTabla[0]=='A'){
				iNumerador=1; /* Activa Real*/
			}else{
            /* Reactiva Real */
				/*iNumerador=2;*/ 
            iNumerador=3;
			}			
		}
		sprintf(sLinea, "%s%d\t", sLinea, iNumerador);

      /* ABLESGR */
      /* Condicional a la fecha de MOVE_IN */
      if(lFechaLectura == lFechaMv){
         strcat(sLinea, "06\t"); /* Motivo */
      }else{
         strcat(sLinea, "01\t"); /* Motivo */
      }
	   /* ZWSTAND */
		sprintf(sLinea, "%s%.0f\t", sLinea, regLectu.lectura_facturac);
      /* ISTABLART */
		sprintf(sLinea, "%s%s\t", sLinea, regLectu.tipo_lectu_sap);
      /* ADAT */
      sprintf(sLinea, "%s%s\t", sLinea, regLectu.fecha_lectura);
	
      /* ATIM */
		strcat(sLinea, "0000\t");
      
      /* ADATTATS */
      sprintf(sLinea, "%s%s\t", sLinea, regLectu.fecha_lectura);
      
      /* AKTIV */
		strcat(sLinea, "1\t");
      /* ADATSOLL */
      if(lFechaLectura != lFechaMv){
		    sprintf(sLinea, "%s%s", sLinea, regLectu.fecha_generacion);
      }
			
		strcat(sLinea, "\n");

		fprintf(fp, sLinea);
/*
		memset(sLinea, '\0', sizeof(sLinea));
	
		sprintf(sLinea, "T1%ld-%ld\t&ENDE", regLectu.numero_cliente, lIndiceArchivo);
	
		strcat(sLinea, "\n");
		
		fprintf(fp, sLinea);
*/	
		lIndiceArchivo++;
		
	}

   
	/****** Ficticia Tramo 1 o 2 *****/
   memset(sLinea, '\0', sizeof(sLinea));
   
	sprintf(sLinea, "T1%ld-%ld\tIEABLU\t", regLectu.numero_cliente, regLectu.corr_facturacion);
   /* EQUNR */
	sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
	
	/* ZWNUMMER */
	if(regLectu.tipo_medidor[0]=='A'){
		iNumerador=2; /* Activa Ficticia*/
	}else{
		if(sTabla[0]=='A'){
         /* Activa Ficticia*/
			/*iNumerador=3;*/ 
         iNumerador=2;
		}else{
			iNumerador=4; /* Reactiva Ficticia */
		}			
	}
	sprintf(sLinea, "%s%d\t", sLinea, iNumerador);
	
   /* ABLESGR */
   /* Condicional a la fecha de MOVE_IN */
   if(lFechaLectura == lFechaMv){
      strcat(sLinea, "06\t"); /* Motivo */
   }else{
      strcat(sLinea, "01\t"); /* Motivo */
   }
	
	/* ZWSTAND */
	sprintf(sLinea, "%s%.0f\t", sLinea, regLectu.consumo);
   
   /* ISTABLART */
/*   
	sprintf(sLinea, "%s%s\t", sLinea, regLectu.tipo_lectu_sap);
*/
   strcat(sLinea, "E4\t");
   	
   /* ADAT */
	sprintf(sLinea, "%s%s\t", sLinea, regLectu.fecha_lectura);
   /* ATIM */
	strcat(sLinea, "0000\t");
   /* ADATTATS */
   sprintf(sLinea, "%s%s\t", sLinea, regLectu.fecha_lectura);
   /* AKTIV */
	strcat(sLinea, "1\t");
   /* ADATSOLL */
   if(lFechaLectura != lFechaMv){
	  /*sprintf(sLinea, "%s%s", sLinea, regLectu.fecha_lectura);*/
     sprintf(sLinea, "%s%s", sLinea, regLectu.fecha_generacion);
   }

	strcat(sLinea, "\n");

	fprintf(fp, sLinea);
/*
  	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regLectu.numero_cliente, regLectu.corr_facturacion);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
*/
	lIndiceArchivo++;

}

short getFPLectu(lNroCliente, regFPLectu)
$long			lNroCliente;
$ClsFPLectu		*regFPLectu;
{
	$long  iCorrFacturacion;
	$long  iTipoLectu;
	$long  iCorrAux;
	
	$EXECUTE selTramoV2 into :iCorrFacturacion, :iTipoLectu using :lNroCliente;
		
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al verificar si existe tramo no facturado para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }
    		
    if(iTipoLectu!=8){
    	return 0;
    }
    
    /* Recupero FP_Lectu*/
    InicializoFPLectu(regFPLectu);
    
    iCorrAux=iCorrFacturacion-1;

    $OPEN curFPLectu 	using
		:lNroCliente,
		:iCorrAux,
		:iCorrAux;
    
	$FETCH curFPLectu into
		:regFPLectu->numero_cliente,
		:regFPLectu->corr_facturacion,
		:regFPLectu->fecha_lectura,
		:regFPLectu->tipo_lectura,
		:regFPLectu->tipo_lectu_sap,
		:regFPLectu->lectura_activa,
		:regFPLectu->lectura_reactiva,
		:regFPLectu->consumo_activa,
		:regFPLectu->consumo_reactiva,
		:regFPLectu->numero_medidor,
		:regFPLectu->marca_medidor,
		:regFPLectu->modelo_medidor,
		:regFPLectu->tipo_medidor;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
    		$CLOSE curFPLectu;
			return 0;
		}else{
			printf("Error al leer FP_LECTU para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }
    
    $CLOSE curFPLectu;
    
    alltrim(regFPLectu->tipo_lectu_sap, ' ');
    
	return 1;
}

void InicializoFPLectu(regFPLectu)
$ClsFPLectu	*regFPLectu;
{
	
	rsetnull(CLONGTYPE, (char *) &(regFPLectu->numero_cliente));
	rsetnull(CLONGTYPE, (char *) &(regFPLectu->corr_facturacion));
	memset(regFPLectu->fecha_lectura, '\0', sizeof(regFPLectu->fecha_lectura));
	rsetnull(CINTTYPE, (char *) &(regFPLectu->tipo_lectura));
	memset(regFPLectu->tipo_lectu_sap, '\0', sizeof(regFPLectu->tipo_lectu_sap));
	rsetnull(CDOUBLETYPE, (char *) &(regFPLectu->lectura_activa));
	rsetnull(CDOUBLETYPE, (char *) &(regFPLectu->lectura_reactiva));
	rsetnull(CDOUBLETYPE, (char *) &(regFPLectu->consumo_activa));
	rsetnull(CDOUBLETYPE, (char *) &(regFPLectu->consumo_reactiva));
	rsetnull(CLONGTYPE, (char *) &(regFPLectu->numero_medidor));
	memset(regFPLectu->marca_medidor, '\0', sizeof(regFPLectu->marca_medidor));
	memset(regFPLectu->modelo_medidor, '\0', sizeof(regFPLectu->modelo_medidor));
	memset(regFPLectu->tipo_medidor, '\0', sizeof(regFPLectu->tipo_medidor));    
    
}

void CargoLectuFP(sTipo, regFPLectu, regLectu)
char			sTipo[2];
$ClsFPLectu		regFPLectu;
$ClsLecturas	*regLectu;
{
	InicializaLecturas(regLectu);
	
	regLectu->numero_cliente = regFPLectu.numero_cliente;
	regLectu->corr_facturacion = regFPLectu.corr_facturacion;
	strcpy(regLectu->fecha_lectura, regFPLectu.fecha_lectura);
	regLectu->tipo_lectura = regFPLectu.tipo_lectura;
	strcpy(regLectu->tipo_lectu_sap, regFPLectu.tipo_lectu_sap);
	
	if(sTipo[0]=='A'){
		regLectu->lectura_facturac = regFPLectu.lectura_activa;
		regLectu->consumo = regFPLectu.consumo_activa;
	}else{
		regLectu->lectura_facturac = regFPLectu.lectura_reactiva;
		regLectu->consumo = regFPLectu.consumo_reactiva;		
	}
	
	strcpy(regLectu->indica_refact, "N");
	regLectu->numero_medidor = regFPLectu.numero_medidor;
	strcpy(regLectu->marca_medidor, regFPLectu.marca_medidor);
	strcpy(regLectu->modelo_medidor, regFPLectu.modelo_medidor);
	strcpy(regLectu->tipo_medidor, regFPLectu.tipo_medidor);
	
	alltrim(regLectu->tipo_lectu_sap, ' ');
	
}

short getUltimoConsumoActiva(lNroCliente, lCorrFactu, regLectu)
$long 			lNroCliente;
$long			lCorrFactu;
$ClsLecturas	*regLectu;
{
	$double		dLectuRectif=0.00;
	$double		dConsuRectif=0.00;
	
	InicializaLecturas(regLectu);
	
	$OPEN curConsuActi using :lNroCliente, :lCorrFactu;
	
	$FETCH curConsuActi into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->fecha_lectura,
		:regLectu->tipo_lectura,
		:regLectu->tipo_lectu_sap,
		:regLectu->lectura_facturac,
		:regLectu->consumo,
		:regLectu->indica_refact,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->modelo_medidor,
		:regLectu->tipo_medidor,
      :regLectu->fecha_generacion;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
    		$CLOSE curConsuActi;
			return 0;
		}else{
			printf("Error al leer Ultimo Consumo Activo para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }		
	
	$CLOSE curConsuActi;
	
	if(regLectu->indica_refact[0]=='S'){
		$EXECUTE selHislecRefac	into :dLectuRectif, :dConsuRectif 
			using :lNroCliente, :lCorrFactu, :regLectu->tipo_lectura;
				
	    if ( SQLCODE != 0 ){
	    	if(SQLCODE == 100){
				return 0;
			}else{
				printf("Error al leer Ultimo Consumo Activo Rectificado para cliente %ld\nProceso Abortado.\n", lNroCliente);
				exit(1);	
			}
	    }
	    regLectu->lectura_facturac = dLectuRectif;
	    regLectu->consumo = dConsuRectif;
	}
	
	regLectu->tipo_lectura=0;
	alltrim(regLectu->tipo_lectu_sap, ' ');
	
	return 1;
}

short getUltimoConsumoReactiva(iEtapa, lNroCliente, lCorrFactu, regLectu)
int				iEtapa;
$long 			lNroCliente;
$long			lCorrFactu;
$ClsLecturas	*regLectu;
{
	$double		dLectuRectif=0.00;
	$double		dConsuRectif=0.00;
	
	InicializaLecturas(regLectu);
	
	$OPEN curLectuReac using :lNroCliente, :lCorrFactu;
	
	$FETCH curLectuReac into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->fecha_lectura,
		:regLectu->tipo_lectura,
		:regLectu->tipo_lectu_sap,
		:regLectu->lectura_facturac,
		:regLectu->consumo,
		:regLectu->indica_refact,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->modelo_medidor,
		:regLectu->tipo_medidor,
      :regLectu->fecha_generacion;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
    		$CLOSE curLectuReac;
			return 0;
		}else{
			printf("Error al leer Ultimo Consumo Reactivo para cliente %ld\nProceso Abortado.\n", lNroCliente);
			exit(1);	
		}
    }		

	$CLOSE curLectuReac;
	
	if(regLectu->indica_refact[0]=='S'){
		$EXECUTE selHislecReacRefac	into :dLectuRectif, :dConsuRectif 
			using :lNroCliente, :lCorrFactu, :regLectu->tipo_lectura;
				
	    if ( SQLCODE != 0 ){
	    	if(SQLCODE == 100){
				return 0;
			}else{
				printf("Error al leer Ultimo Consumo Reactivo Rectificado para cliente %ld\nProceso Abortado.\n", lNroCliente);
				exit(1);	
			}
	    }
	    regLectu->lectura_facturac = dLectuRectif;
	    regLectu->consumo = dConsuRectif;
	}
	
	if(iEtapa==2)
		regLectu->tipo_lectura=0;
		
		
	alltrim(regLectu->tipo_lectu_sap, ' ');
	
	return 1;
}

void DuplicaRegistro(regLecturas, regLectuAux)
ClsLecturas	regLecturas;
ClsLecturas *regLectuAux;
{

		regLectuAux->numero_cliente = regLecturas.numero_cliente;
		regLectuAux->corr_facturacion = regLecturas.corr_facturacion;
		strcpy(regLectuAux->fecha_lectura , regLecturas.fecha_lectura);
		regLectuAux->tipo_lectura = regLecturas.tipo_lectura;
		strcpy(regLectuAux->tipo_lectu_sap , regLecturas.tipo_lectu_sap);
		regLectuAux->lectura_facturac = 0;
		regLectuAux->consumo = 0;
		strcpy(regLectuAux->indica_refact, "N");
		regLectuAux->numero_medidor = regLecturas.numero_medidor;
		strcpy(regLectuAux->marca_medidor, regLecturas.marca_medidor);
		strcpy(regLectuAux->modelo_medidor, regLecturas.modelo_medidor);
		strcpy(regLectuAux->tipo_medidor, regLecturas.tipo_medidor);
		
		alltrim(regLectuAux->tipo_lectu_sap, ' ');

}

short ExisteFactura(lNroCliente, lCorrFactu)
$long	lNroCliente;
$long	lCorrFactu;
{
	$long lCant=0;
	
	$EXECUTE selFactura into :lCant using :lNroCliente, :lCorrFactu;
		
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			printf("No existe factura para cliente %ld correlativo %ld\n", lNroCliente, lCorrFactu);	
		}else{
			printf("Error al buscar factura para cliente %ld correlativo %ld\n", lNroCliente, lCorrFactu);	
		}
		return 0;
	}
	
	if(lCant <= 0)
		return 0;
		
	return 1;
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

