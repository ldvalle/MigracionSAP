/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_operandos
    
	Fecha : 25/01/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura OPERANDOS
		
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

$include "sap_operandos.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileOperandosUnx;

char	sArchOperandosUnx[100];
char	sSoloArchivoOperandos[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantVipProcesada;
long	cantVipActivos;
long	cantVipInactivos;
long 	cantVipPreexistente;

long	cantTisProcesada;
long	cantTisActivos;
long	cantTisInactivos;
long 	cantTisPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$long	lCorrFactuIni;
$ClsOperando	regOperandos;

$ClsOperando	regOpeAux;
int				iNx;
$long			lFechaAlta;
$long			lFechaIniAnterior;
$long			lFechaHastaAnterior;
$long			lClienteAnterior;
long			lDifDias;
char			sFechaAlta[9];
$long       lFechaIniAux;
$long       lFechaFinAux;
$long       lFechaValTarifa;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;

	CreaPrepare();

	/*$EXECUTE selFechaLimInf into :lFechaLimiteInferior;*/
		
	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantVipProcesada=0;
	cantVipActivos=0;
	cantVipInactivos=0;
	cantVipPreexistente=0;

	cantTisProcesada=0;
	cantTisActivos=0;
	cantTisInactivos=0;
	cantTisPreexistente=0;

	/*********************************************
				ELECTRO DEPENDENCIA
	**********************************************/
	if(glNroCliente > 0){
		$OPEN curElectro using :glNroCliente;
	}else{
		$OPEN curElectro;
	}

	lClienteAnterior=0;
	
		
	while(LeoElectroDependencia(&regOperandos)){
  
		if(lClienteAnterior != regOperandos.numero_cliente){
			/* Primera ocurrencia del cliente */
         lClienteAnterior = regOperandos.numero_cliente;
			iNx=1;
         
			if(! ClienteYaMigrado("VIP", regOperandos.numero_cliente, &lFechaValTarifa, &iFlagMigra)){
            rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
            
            if(getFechaIni(regOperandos, &lFechaIniAux)){
               rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
               regOperandos.lFechaInicio=lFechaIniAux;
               
               if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
                  if(getFechaFin(regOperandos, &lFechaFinAux)){
                     rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                     regOperandos.lFechaFin=lFechaFinAux;
                     /* registro desactivado */
                     GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                     iNx++;                  
                  }
               }else{
               
                  /* registro activo */
                  GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                  cantVipProcesada++;
                  iNx++;
               }
            }
			}else{
				cantVipPreexistente++;
			}
		}else{
			/* Mismo Cliente fila anterior*/
          if(getFechaIni(regOperandos, &lFechaIniAux)){
             rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
             regOperandos.lFechaInicio=lFechaIniAux;
             
             if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
                if(getFechaFin(regOperandos, &lFechaFinAux)){
                   rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                   regOperandos.lFechaFin=lFechaFinAux;
                   /* registro desactivado */
                   GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                   iNx++;                  
                }
             }else{
                /* registro activo */
                GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                cantVipProcesada++;
                iNx++;
             }
          }
		}
   }

	$CLOSE curElectro;
	
	/*********************************************
				   TARIFA SOCIAL
	**********************************************/
	if(glNroCliente > 0){
		$OPEN curTis using :glNroCliente;
	}else{
		$OPEN curTis;
	}

	lClienteAnterior=0;
	
   while(LeoTis(&regOperandos)){
		if(lClienteAnterior != regOperandos.numero_cliente){
			/* Primera ocurrencia del cliente */
         lClienteAnterior = regOperandos.numero_cliente;
			iNx=1;
         
			if(! ClienteYaMigrado("TIS", regOperandos.numero_cliente, &lFechaValTarifa, &iFlagMigra)){
            rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
            
            if(getFechaIni(regOperandos, &lFechaIniAux)){
               rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
               regOperandos.lFechaInicio=lFechaIniAux;
               
               if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
                  if(getFechaFin(regOperandos, &lFechaFinAux)){
                     rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                     regOperandos.lFechaFin=lFechaFinAux;
                     /* registro desactivado */
                     GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                     iNx++;                  
                  }
               }else{
                  /* registro activo */
                  GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                  iNx++;
                  cantTisProcesada++;
               }
            }
			}else{
				cantTisPreexistente++;
			}
		}else{
			/* Mismo Cliente fila anterior*/
          if(getFechaIni(regOperandos, &lFechaIniAux)){
             rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
             regOperandos.lFechaInicio=lFechaIniAux;
             
             if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
                if(getFechaFin(regOperandos, &lFechaFinAux)){
                   rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                   regOperandos.lFechaFin=lFechaFinAux;
                   /* registro desactivado */
                   GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                   iNx++;                  
                }
             }else{
                /* registro activo */
                GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                iNx++;
                cantTisProcesada++;
             }
          }
		}
   }
   

	$CLOSE curTIS;
			
	CerrarArchivos();

	/* Registrar Control Plano */
/*   
	if(!RegistraArchivo()){
		$ROLLBACK WORK;
		exit(1);
	}
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
	printf("OPERANDOS.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes VIP Procesados :       %ld \n",cantVipProcesada);
	printf("Clientes VIP Preexistentes :    %ld \n",cantVipPreexistente);
	printf("Clientes TIS Procesados :       %ld \n",cantTisProcesada);
	printf("Clientes TIS Preexistentes :    %ld \n",cantTisPreexistente);	
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
	
	memset(sArchOperandosUnx,'\0',sizeof(sArchOperandosUnx));
	memset(sSoloArchivoOperandos,'\0',sizeof(sSoloArchivoOperandos));

	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');
   
	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
   
	/*lCorrelativo = getCorrelativo("OPERANDOS");*/
	
	

	if(giEstadoCliente==0){
		sprintf( sArchOperandosUnx  , "%sT1FACTS_Activo.unx", sPathSalida );
		strcpy( sSoloArchivoOperandos, "T1FACTS_Activo.unx");
	}else{
		sprintf( sArchOperandosUnx  , "%sT1FACTS_Inactivo.unx", sPathSalida );
		strcpy( sSoloArchivoOperandos, "T1FACTS_Inactivo.unx");
	}
	
	pFileOperandosUnx=fopen( sArchOperandosUnx, "w" );
	if( !pFileOperandosUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchOperandosUnx );
		return 0;
	}

	return 1;	
}

void CerrarArchivos(void)
{
    
	fclose(pFileOperandosUnx);
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

	sprintf(sCommand, "chmod 755 %s", sArchOperandosUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchOperandosUnx, sPathCp);
	iRcv=system(sCommand);
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


	
	/******** ELECTRO DEPENDIENTES *********/
	strcpy(sql, "SELECT v.numero_cliente, ");
	strcat(sql, "v.fecha_activacion, ");
	strcat(sql, "TO_CHAR(v.fecha_activacion, '%Y%m%d'), ");
	strcat(sql, "NVL(v.fecha_desactivac, 0), ");
	strcat(sql, "NVL(TO_CHAR(v.fecha_desactivac, '%Y%m%d'), '99991231'), ");
	strcat(sql, "v.motivo, ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "NVL(c.nro_beneficiario, 0) ");
	strcat(sql, "FROM cliente c, clientes_vip v, tabla tb1 ");

   if(giTipoCorrida==1)	
      strcat(sql, ", migra_activos m ");	

	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si ");
	}		
	
	if(glNroCliente > 0 ){
		strcat(sql, "WHERE c.numero_cliente = ? ");
		strcat(sql, "AND c.tipo_sum != 5 ");	
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}		
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
/*		
		strcat(sql, "AND si.fecha_baja >= TODAY - 365 ");
*/		
	}
	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
   
	strcat(sql, "AND v.numero_cliente = c.numero_cliente ");
   
	strcat(sql, "AND tb1.nomtabla = 'SDCLIV' ");
	strcat(sql, "AND tb1.codigo = v.motivo ");
   strcat(sql, "AND tb1.valor_alf[4] = 'S' ");
	strcat(sql, "AND tb1.sucursal = '0000' ");
	strcat(sql, "AND tb1.fecha_activacion <= TODAY "); 
	strcat(sql, "AND ( tb1.fecha_desactivac >= TODAY OR tb1.fecha_desactivac IS NULL ) ");    
   
	/*strcat(sql, "AND v.fecha_activacion >= ? ");*/

   if(giTipoCorrida==1)	
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
	
	strcat(sql, "ORDER BY v.numero_cliente, v.fecha_activacion ASC ");

	$PREPARE selElectro FROM $sql;
	
	$DECLARE curElectro CURSOR FOR selElectro;


   /******** Temporal TIS ******/
/*   
	strcpy(sql, "SELECT DISTINCT numero_cliente "); 
	strcat(sql, "FROM tarifa_social ");
	strcat(sql, "INTO TEMP tempo1 WITH NO LOG; ");

	$PREPARE insTempoTis FROM $sql;
*/   
	/****** Cursor Tarifa Social  *******/
	
	strcpy(sql, "SELECT v.numero_cliente, ");
	strcat(sql, "v.fecha_inicio, ");
	strcat(sql, "TO_CHAR(v.fecha_inicio, '%Y%m%d'), ");
	strcat(sql, "NVL(v.fecha_desactivac, 0), ");
	strcat(sql, "NVL(TO_CHAR(v.fecha_desactivac, '%Y%m%d'), '99991231'), ");
	strcat(sql, "v.motivo, ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "NVL(c.nro_beneficiario, 0) ");
	strcat(sql, "FROM cliente c, tarifa_social v ");

   if(giTipoCorrida == 1)
      strcat(sql, ", migra_activos m ");	

	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si ");
	}		
	
	if(glNroCliente > 0 ){
		strcat(sql, "WHERE c.numero_cliente = ? ");
		strcat(sql, "AND c.tipo_sum != 5 ");	
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}		
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND v.numero_cliente = c.numero_cliente ");

/*   
	strcat(sql, "AND v.fecha_inicio >= ? ");
*/
   
   if(giTipoCorrida == 1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	strcat(sql, "ORDER BY v.numero_cliente, v.fecha_inicio ");
	
	$PREPARE selTarsoc FROM $sql;
	
	$DECLARE curTis CURSOR FOR selTarsoc;
		
	/******** Buscamos el Alta en ESTOC *********/
	strcpy(sql, "SELECT TO_CHAR(fecha_terr_puser, '%Y%m%d') ");
	strcat(sql, "FROM estoc ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selEstoc FROM $sql;
	
	/******** Select Retiros Medidor *********/	
	strcpy(sql, "SELECT TO_CHAR(MAX(m2.fecha_modif), '%Y%m%d') ");
	strcat(sql, "FROM modif m2 ");
	strcat(sql, "WHERE m2.numero_cliente = ? ");
	strcat(sql, "AND m2.codigo_modif = 58 ");

	$PREPARE selRetiro FROM $sql;		
	
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
	strcat(sql, "'OPERANDOS', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado VIP **********/
	strcpy(sql, "SELECT operando_vip FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/********* Select Cliente ya migrado TIS **********/
	strcpy(sql, "SELECT operando_tis FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado2 FROM $sql;
	
	/*********Insert Clientes extraidos VIP **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, operando_vip ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra VIP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_vip = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/*********Insert Clientes extraidos TIS **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, operando_tis ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra2 FROM $sql;
	
	/************ Update Clientes Migra TIS **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_tis = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra2 FROM $sql;

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
	
	/******** Fecha Primera Factura a Migrar *********/
/*
	strcpy(sql, "SELECT TO_CHAR(MIN(h.fecha_facturacion), '%Y%m%d') ");
	strcat(sql, "FROM hisfac h, cliente c ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND fecha_facturacion >= ? ");
	strcat(sql, "AND h.corr_facturacion >= c.corr_facturacion - ? ");
	------------------------------------------------------------------------
	strcpy(sql, "SELECT TO_CHAR(fecha_facturacion, '%Y%m%d') FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
*/
	
	strcpy(sql, "SELECT TO_CHAR(MAX(h2.fecha_lectura), '%Y%m%d') ");
	strcat(sql, "FROM hisfac h1, hislec h2 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.fecha_lectura < h1.fecha_facturacion ");
	strcat(sql, "AND h2.tipo_lectura IN (1, 2, 3, 4, 8) ");
	
	$PREPARE selFechaFactura FROM $sql;

	/******* Medid 1 *********/
	strcpy(sql, "SELECT NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924')");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.estado = 'I' ");
	
	$PREPARE selMedid1 FROM $sql;
	
	/******* Medid 1 *********/
	strcpy(sql, "SELECT NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924')");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.fecha_ult_insta = (SELECT MAX(m2.fecha_ult_insta) FROM medid m2 ");
	strcat(sql, "   WHERE m2.numero_cliente = m.numero_cliente) ");	
	
	$PREPARE selMedid2 FROM $sql;
   
	/********** Fecha Alta Instalacion ************/
	strcpy(sql, "SELECT fecha_val_tarifa, TO_CHAR(fecha_val_tarifa, '%Y%m%d') FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selFechaInstal FROM $sql;

   /*********** Incio Periodo ************/
	strcpy(sql, "SELECT MIN(fecha_lectura) "); 
	strcat(sql, "FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_facturacion >= ? "); 
  	strcat(sql, "AND fecha_facturacion <= ? ");
   
   $PREPARE selFechaIni FROM $sql;
   
   /*********** Fin Periodo ************/   
	strcpy(sql, "SELECT MAX(fecha_lectura) "); 
	strcat(sql, "FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_facturacion >= ? ");  
  	strcat(sql, "AND fecha_facturacion <= ? ");

   $PREPARE selFechaFin FROM $sql;   	
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
short LeoElectroDependencia(regOpe)
$ClsOperando *regOpe;
{
   $long lFechaAux;
   
	InicializaOperando(regOpe);

	$FETCH curElectro into
		:regOpe->numero_cliente,
		:regOpe->lFechaInicio,
		:regOpe->sFechaInicio,
		:regOpe->lFechaFin,
		:regOpe->sFechaFin,
		:regOpe->sMotivoVip,
		:regOpe->corr_facturacion,
		:regOpe->nro_beneficiario;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de ELECTRODEPENDIENTES !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	strcpy(regOpe->sOperando, "FLAGVIP");
	
   if(regOpe->lFechaFin == 0){
      rdefmtdate(&lFechaAux, "yyyymmdd", "99991231");
      regOpe->lFechaFin = lFechaAux;
   }
   
   
	alltrim(regOpe->sMotivoVip, ' ');
	alltrim(regOpe->sOperando, ' ');
	
	return 1;	
}

short LeoTis(regOpe)
$ClsOperando *regOpe;
{
   $long lFechaAux;
   
	InicializaOperando(regOpe);

	$FETCH curTis into
		:regOpe->numero_cliente,
		:regOpe->lFechaInicio,
		:regOpe->sFechaInicio,
		:regOpe->lFechaFin,
		:regOpe->sFechaFin,
		:regOpe->sMotivoVip,
		:regOpe->corr_facturacion,
		:regOpe->nro_beneficiario;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de TIS !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	strcpy(regOpe->sOperando, "FLAGTIS");
   if(regOpe->lFechaFin == 0){
      rdefmtdate(&lFechaAux, "yyyymmdd", "99991231");
      regOpe->lFechaFin = lFechaAux;
   }


	
	alltrim(regOpe->sMotivoVip, ' ');
	alltrim(regOpe->sOperando, ' ');
	
	return 1;	
}


void InicializaOperando(regOpe)
$ClsOperando	*regOpe;
{
	
	rsetnull(CLONGTYPE, (char *) &(regOpe->numero_cliente));
	memset(regOpe->fecha_vig_tarifa, '\0', sizeof(regOpe->fecha_vig_tarifa));
	memset(regOpe->sOperando, '\0', sizeof(regOpe->sOperando));
	memset(regOpe->sFechaInicio, '\0', sizeof(regOpe->sFechaInicio));
	rsetnull(CLONGTYPE, (char *) &(regOpe->lFechaInicio));
	memset(regOpe->sFechaFin, '\0', sizeof(regOpe->sFechaFin));
	rsetnull(CLONGTYPE, (char *) &(regOpe->lFechaFin));
	memset(regOpe->sMotivoVip, '\0', sizeof(regOpe->sMotivoVip));
	rsetnull(CLONGTYPE, (char *) &(regOpe->corr_facturacion));
	rsetnull(CLONGTYPE, (char *) &(regOpe->nro_beneficiario));

}

short ClienteYaMigrado(sOpe, nroCliente, lFechaTarifa, iFlagMigra)
char	sOpe[4];
$long	nroCliente;
$long *lFechaTarifa;
int		*iFlagMigra;
{
	$char	sMarca[2];
   $long lFecha;
	
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	if(strcmp(sOpe, "VIP")==0){
		$EXECUTE selClienteMigrado into :sMarca, :lFecha using :nroCliente;
	}else{
		$EXECUTE selClienteMigrado2 into :sMarca, :lFecha using :nroCliente;
	}
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
   	if(gsTipoGenera[0]=='G'){
   		return 1;	
   	}
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}

   *lFechaTarifa = lFecha;
   
	return 0;
}

short CargaAltaCliente(regIns)
$ClsOperando *regIns;
{
	$long lFechaAlta;
	$char sFechaAlta[9];
	$long iCorrFactuInicio;
	
	memset(sFechaAlta, '\0', sizeof(sFechaAlta));


   $EXECUTE selFechaInstal INTO :lFechaAlta, :sFechaAlta
      USING :regIns->numero_cliente;
      
   if(SQLCODE !=0){
		printf("Error al buscar fecha de Alta para cliente %ld.\n", regIns->numero_cliente);
		exit(2);
   }
   
   strcpy(regIns->fecha_vig_tarifa, sFechaAlta);
   
/*
	if(regIns->corr_facturacion > 0){
		
		iCorrFactuInicio = regIns->corr_facturacion - iCorrelativos;
		
		if(iCorrFactuInicio <= 0){
			iCorrFactuInicio=1;	
		}
		
		strcpy(sFechaAlta, getFechaFactura(regIns->numero_cliente, iCorrFactuInicio));
	
		strcpy(regIns->fecha_vig_tarifa, sFechaAlta);
	
	}else{

		$EXECUTE selMedid1 into :regIns->fecha_vig_tarifa using :regIns->numero_cliente;
			
		if(SQLCODE !=0){
			$EXECUTE selMedid2 into :regIns->fecha_vig_tarifa using :regIns->numero_cliente;
			
			if(SQLCODE !=0){
				printf("Error al buscar fecha de Alta para cliente %ld.\n", regIns->numero_cliente);
				exit(2);
			}
		}
	}
*/   
	
	return 1;	
}


char *getFechaFactura(lNroCliente, lCorrFactuInicio)
$long	lNroCliente;
$long   lCorrFactuInicio;
{
	$char	sFechaFactura[9];
	
	memset(sFechaFactura, '\0', sizeof(sFechaFactura));
	
	/* Reemplazo la fecha lectura por la fecha de primera factura a migrar */
	$EXECUTE selFechaFactura into :sFechaFactura using :lNroCliente, :lCorrFactuInicio;
		
	if(SQLCODE != 0){
		printf("No se encontró factura historica para cliente %ld\n", lNroCliente);
		return sFechaFactura;
	}
		
	return sFechaFactura;
}

short GenerarPlano(sTipo, fp, regOpe, iNx)
char				sTipo[2];
FILE 				*fp;
$ClsOperando		regOpe;
long				iNx;
{
	/* KEY */	
	GeneraKEY(sTipo, fp, regOpe, iNx);

	/* F_FLAG */	
	GeneraFFlag(sTipo, fp, regOpe, iNx);

	/* V_FLAG */	
	GeneraVFlag(sTipo, fp, regOpe, iNx);
		
	/* ENDE */
	GeneraENDE(fp, regOpe, iNx);
	
	return 1;
}

void GeneraENDE(fp, regOpe, iNx)
FILE *fp;
$ClsOperando	regOpe;
long			iNx;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regOpe.numero_cliente, iNx);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantVipProcesada > 0 || cantTisProcesada > 0){
		strcpy(sTipoArchivo, "OPERANDOS");
		strcpy(sNombreArchivo, sSoloArchivoOperandos);
		lCantidad=cantVipProcesada + cantTisProcesada;
				
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
short RegistraCliente(sOpe, nroCliente, iFlagMigra)
char	sOpe[4];
$long	nroCliente;
int		iFlagMigra;
{

	if(strcmp(sOpe, "VIP")){
		if(iFlagMigra==1){
			$EXECUTE insClientesMigra using :nroCliente;
		}else{
			$EXECUTE updClientesMigra using :nroCliente;
		}
	}else{
		if(iFlagMigra==1){
			$EXECUTE insClientesMigra2 using :nroCliente;
		}else{
			$EXECUTE updClientesMigra2 using :nroCliente;
		}
	}

	return 1;
}

void GeneraKEY(sTipo, fp, regOpe, iNx)
char		sTipo[2];
FILE 		*fp;
ClsOperando	regOpe;
long		iNx;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%ld\tKEY\t", regOpe.numero_cliente, iNx);
	/* ANLAGE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regOpe.numero_cliente);
   /* BIS */	
	sprintf(sLinea, "%s%s", sLinea, regOpe.fecha_vig_tarifa);
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraFFlag(sTipo, fp, regOpe, iNx)
char			sTipo[2];
FILE 			*fp;
ClsOperando 	regOpe;
long			iNx;
{

	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\tF_FLAG\t", regOpe.numero_cliente, iNx);
	
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sOperando);
	
	if(sTipo[0]=='R'){
		strcat(sLinea, "X");	
	}

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);

}

void GeneraVFlag(sTipo, fp, regOpe, iNx)
char			sTipo[2];
FILE 			*fp;
ClsOperando 	regOpe;
long			iNx;
{

	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\tV_FLAG\t", regOpe.numero_cliente, iNx);
	
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sFechaInicio);
   /* BIS */
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sFechaFin);
	
	if(sTipo[0]=='R'){
		strcat(sLinea, "X");	
	}

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);

}

void CopiarData(regOpe, regOpeAux)
ClsOperando	regOpe;
ClsOperando	*regOpeAux;
{
	
	regOpeAux->numero_cliente = regOpe.numero_cliente;
	strcpy(regOpeAux->fecha_vig_tarifa, regOpe.fecha_vig_tarifa);
	strcpy(regOpeAux->sOperando, regOpe.sOperando);
	rfmtdate(regOpeAux->lFechaInicio, "yyyymmdd", regOpeAux->sFechaInicio);
	rfmtdate(regOpeAux->lFechaFin, "yyyymmdd", regOpeAux->sFechaFin);
	strcpy(regOpeAux->sMotivoVip, regOpe.sMotivoVip);
	regOpeAux->corr_facturacion=regOpe.corr_facturacion;
	regOpeAux->nro_beneficiario=regOpe.nro_beneficiario;
	
}

short getFechaIni(reg, lFecha)
$ClsOperando   reg;
$long          *lFecha;
{

   $long lFechaAux;
   
   $EXECUTE selFechaIni INTO :lFechaAux
      USING :reg.numero_cliente,
            :reg.lFechaInicio,
            :reg.lFechaFin;

   if(SQLCODE !=0 ){
      return 0;
   }
   
   *lFecha = lFechaAux;

   return 1;
}

short getFechaFin(reg, lFecha)
$ClsOperando   reg;
$long          *lFecha;
{

   $long lFechaAux;
   
   $EXECUTE selFechaFin INTO :lFechaAux
      USING :reg.numero_cliente,
            :reg.lFechaInicio,
            :reg.lFechaFin;

   if(SQLCODE !=0 ){
      return 0;
   }
   
   *lFecha = lFechaAux;

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

