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
		<Tipo Corrida>:    0=Normal, 1=Reducida
		<Fecha Inicio Busqueda> <Opcional>: dd/mm/aaaa

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
int   giTipoArchivos;
$long glFechaDesde;

FILE	*pFileOperandosUnx;
FILE	*pFileFlagTap;
FILE	*pFileQPTap;
FILE	*pFileFactorTap;
FILE	*pFileFlagEbp;
FILE  *pFileFlagFP;
FILE  *pFileFlagFP_SB;


char	sArchOperandosUnx[100];
char	sSoloArchivoOperandos[100];
char  sArchFlagTap[100];
char  sArchQPTap[100];
char  sArchFactorTap[100];
char  sArchFlagEbp[100];
char  sArchFlagFP[100];
char  sArchFlagFP_SB[100];

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

long  cantTasa;
long  cantEBP;
long  cantFP;
long  cantFP_SB;

char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;

$dtime_t    gtInicioCorrida;
$char       sLstParametros[100];
$long       glFechaParametro;
$long       lFechaPivote;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=2;
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
	
	$SET LOCK MODE TO WAIT 120;
	$SET ISOLATION TO DIRTY READ;
   /*$SET ISOLATION TO CURSOR STABILITY;*/

	CreaPrepare();

	$EXECUTE selFechaDesde INTO :lFechaLimiteInferior, :lFechaPivote;
		
	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
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

   cantTasa=0;
   cantEBP=0;
   
   switch(giTipoArchivos){
      case 0:
         GenerarElectro();
         GenerarTIS();
         fclose(pFileOperandosUnx);
         
         GenerarTasa();
         fclose(pFileFlagTap);
         fclose(pFileQPTap);
         fclose(pFileFactorTap);
         
         GenerarEBP();
         fclose(pFileFlagEbp);

         GenerarFP();
         fclose(pFileFlagFP);
         fclose(pFileFlagFP_SB);

         break;
      case 1:
         GenerarElectro();
         GenerarTIS();
         fclose(pFileOperandosUnx);
         break;
      case 2:
         GenerarTasa();
         fclose(pFileFlagTap);
         fclose(pFileQPTap);
         fclose(pFileFactorTap);
         break;
      case 3:
         GenerarEBP();
         fclose(pFileFlagEbp);
         break;
      case 4:
         GenerarFP();
         fclose(pFileFlagFP);
         fclose(pFileFlagFP_SB);
         break;
         
   }
			

   /* Registro la corrida */
   $BEGIN WORK;
   
   $EXECUTE insRegiCorrida USING :gtInicioCorrida,
                                 :sLstParametros;
   
   $COMMIT WORK;


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
   
   printf("Clientes Tasa :                 %ld \n",cantTasa);
   printf("Clientes EBP :                  %ld \n",cantEBP);
   printf("Clientes FP  :                  %ld \n",cantFP);
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
char  sFechaPar[11];
   
   memset(sFechaPar, '\0', sizeof(sFechaPar));
   memset(sLstParametros, '\0', sizeof(sLstParametros));

   
	if(argc < 6 || argc > 7){
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
   
   giTipoArchivos=atoi(argv[5]);
	
   glNroCliente=-1;

   sprintf(sLstParametros, "%s %s %s %s %s", argv[1], argv[2], argv[3], argv[4], argv[5]);
   
	if(argc ==7){
      strcpy(sFechaPar, argv[6]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
      sprintf(sLstParametros, " %s %s",sLstParametros , argv[6]);
	}else{
		glFechaParametro=-1;
	}
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos, 2=Ambos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0=Normal, 1=Reducida\n");
      printf(" <Archivos > 0=Todos, 1=Electro y TIS, 2=Tasas, 3=EBP, 4=FP\n");
		printf("	<Fecha Desde> <Opcional> dd/mm/aaaa\n");
}

short AbreArchivos()
{
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);
	
	memset(sArchOperandosUnx,'\0',sizeof(sArchOperandosUnx));
   memset(sArchFlagTap,'\0',sizeof(sArchFlagTap));
   memset(sArchQPTap,'\0',sizeof(sArchQPTap));
   memset(sArchFactorTap,'\0',sizeof(sArchFactorTap));
   memset(sArchFlagEbp,'\0',sizeof(sArchFlagEbp));
   memset(sArchFlagFP,'\0',sizeof(sArchFlagFP));
   memset(sArchFlagFP_SB,'\0',sizeof(sArchFlagFP_SB));

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');
   
	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
   
   switch(giTipoArchivos){
      case 0:
      	sprintf( sArchOperandosUnx  , "%sT1FACTS_VIPTIS.unx", sPathSalida );
      	pFileOperandosUnx=fopen( sArchOperandosUnx, "w" );
      	if( !pFileOperandosUnx ){
      		printf("ERROR al abrir archivo %s.\n", sArchOperandosUnx );
      		return 0;
      	}

      	sprintf( sArchFlagTap  , "%sT1FACTS_FLAGTAP.unx", sPathSalida );
      	pFileFlagTap=fopen( sArchFlagTap, "w" );
      	if( !pFileFlagTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagTap );
      		return 0;
      	}

      	sprintf( sArchQPTap  , "%sT1FACTS_QPTAP.unx", sPathSalida );
      	pFileQPTap=fopen( sArchQPTap, "w" );
      	if( !pFileQPTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchQPTap );
      		return 0;
      	}

      	sprintf( sArchFactorTap  , "%sT1FACTS_FACTOR_TAP.unx", sPathSalida );
      	pFileFactorTap=fopen( sArchFactorTap, "w" );
      	if( !pFileFactorTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchFactorTap );
      		return 0;
      	}

      	sprintf( sArchFlagEbp  , "%sT1FACTS_FLAGEBP.unx", sPathSalida );
      	pFileFlagEbp=fopen( sArchFlagEbp, "w" );
      	if( !pFileFlagEbp ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagEbp );
      		return 0;
      	}

      	sprintf( sArchFlagFP  , "%sT1FACTS_QCONTADOR_.unx", sPathSalida );
      	pFileFlagFP=fopen( sArchFlagFP, "w" );
      	if( !pFileFlagFP ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagFP );
      		return 0;
      	}

      	sprintf( sArchFlagFP_SB  , "%sT1FACTS_STANDBY_.unx", sPathSalida );
      	pFileFlagFP_SB=fopen( sArchFlagFP_SB, "w" );
      	if( !pFileFlagFP_SB ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagFP_SB );
      		return 0;
      	}
         
         break;
      case 1:
      	sprintf( sArchOperandosUnx  , "%sT1FACTS_VIPTIS.unx", sPathSalida );
      	pFileOperandosUnx=fopen( sArchOperandosUnx, "w" );
      	if( !pFileOperandosUnx ){
      		printf("ERROR al abrir archivo %s.\n", sArchOperandosUnx );
      		return 0;
      	}
         break;
               
      case 2:
         sprintf( sArchFlagTap  , "%sT1FACTS_FLAGTAP.unx", sPathSalida );
      	pFileFlagTap=fopen( sArchFlagTap, "w" );
      	if( !pFileFlagTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagTap );
      		return 0;
      	}

      	sprintf( sArchQPTap  , "%sT1FACTS_QPTAP.unx", sPathSalida );
      	pFileQPTap=fopen( sArchQPTap, "w" );
      	if( !pFileQPTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchQPTap );
      		return 0;
      	}

      	sprintf( sArchFactorTap  , "%sT1FACTS_FACTOR_TAP.unx", sPathSalida );
      	pFileFactorTap=fopen( sArchFactorTap, "w" );
      	if( !pFileFactorTap ){
      		printf("ERROR al abrir archivo %s.\n", sArchFactorTap );
      		return 0;
      	}
         break;
               
      case 3:
      	sprintf( sArchFlagEbp  , "%sT1FACTS_FLAGEBP.unx", sPathSalida );
      	pFileFlagEbp=fopen( sArchFlagEbp, "w" );
      	if( !pFileFlagEbp ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagEbp );
      		return 0;
      	}
         
         break;
         
      case 4:
      	sprintf( sArchFlagFP  , "%sT1FACTS_QCONTADOR_.unx", sPathSalida );
      	pFileFlagFP=fopen( sArchFlagFP, "w" );
      	if( !pFileFlagFP ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagFP );
      		return 0;
      	}

      	sprintf( sArchFlagFP_SB  , "%sT1FACTS_STANDBY_.unx", sPathSalida );
      	pFileFlagFP_SB=fopen( sArchFlagFP_SB, "w" );
      	if( !pFileFlagFP_SB ){
      		printf("ERROR al abrir archivo %s.\n", sArchFlagFP_SB );
      		return 0;
      	}
      
         break;      
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
       sprintf(sPathCp, "%sActivos/Operandos/", sPathCopia);
	}else{
	    /*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
       sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

   switch(giTipoArchivos){
      case 0:
      	sprintf(sCommand, "chmod 755 %s", sArchOperandosUnx);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchOperandosUnx, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchOperandosUnx);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFlagTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagTap);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchQPTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchQPTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchQPTap);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFactorTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFactorTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFactorTap);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFlagEbp);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagEbp, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagEbp);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFlagFP);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagFP, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagFP);
            iRcv=system(sCommand);
         }

         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFlagFP_SB);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagFP_SB, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagFP_SB);
            iRcv=system(sCommand);
         }
         
         break;
                  
      case 1:
      	sprintf(sCommand, "chmod 755 %s", sArchOperandosUnx);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchOperandosUnx, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchOperandosUnx);
            iRcv=system(sCommand);
         }
         break;      
      case 2:
      	sprintf(sCommand, "chmod 755 %s", sArchFlagTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagTap);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchQPTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchQPTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchQPTap);
            iRcv=system(sCommand);
         }
         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFactorTap);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFactorTap, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFactorTap);
            iRcv=system(sCommand);
         }
         break;      
      case 3:
      	sprintf(sCommand, "chmod 755 %s", sArchFlagEbp);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagEbp, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagEbp);
            iRcv=system(sCommand);
         }
         break;
      case 4:
      	sprintf(sCommand, "chmod 755 %s", sArchFlagFP);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagFP, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagFP);
            iRcv=system(sCommand);
         }

         /* ------------ */
      	sprintf(sCommand, "chmod 755 %s", sArchFlagFP_SB);
      	iRcv=system(sCommand);
      	
      	sprintf(sCommand, "cp %s %s", sArchFlagFP_SB, sPathCp);
      	iRcv=system(sCommand);
         
         if(iRcv == 0){
            sprintf(sCommand, "rm -f %s", sArchFlagFP_SB);
            iRcv=system(sCommand);
         }
      
   }
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

   /***** Existe Cliente *****/	
   $PREPARE selExiste FROM "SELECT COUNT(*) FROM sap_regi_cliente
      WHERE numero_cliente = ?";
   
	/******** ELECTRO DEPENDIENTES *********/
	strcpy(sql, "SELECT v.numero_cliente, ");
	strcat(sql, "v.fecha_activacion + 1, ");
	strcat(sql, "TO_CHAR(v.fecha_activacion + 1, '%Y%m%d'), ");
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
	

	if(giEstadoCliente==0){
		strcat(sql, "WHERE c.estado_cliente = 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
	}else{
		strcat(sql, "WHERE c.estado_cliente != 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
      strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}		

	strcat(sql, "AND v.fecha_activacion > ? ");
   
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
	
	$DECLARE curElectro CURSOR WITH HOLD FOR selElectro;


   /******** Temporal TIS ******/
/*   
	strcpy(sql, "SELECT DISTINCT numero_cliente "); 
	strcat(sql, "FROM tarifa_social ");
	strcat(sql, "INTO TEMP tempo1 WITH NO LOG; ");

	$PREPARE insTempoTis FROM $sql;
*/   
	/****** Cursor Tarifa Social  *******/
	
	strcpy(sql, "SELECT v.numero_cliente, ");
	strcat(sql, "v.fecha_inicio + 1, ");
	strcat(sql, "TO_CHAR(v.fecha_inicio + 1, '%Y%m%d'), ");
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
	
	if(giEstadoCliente==0){
		strcat(sql, "WHERE c.estado_cliente = 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
	}else{
		strcat(sql, "WHERE c.estado_cliente != 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
      strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}		

	strcat(sql, "AND v.fecha_inicio > ? ");
   
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND v.numero_cliente = c.numero_cliente ");
   
   
   if(giTipoCorrida == 1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	strcat(sql, "ORDER BY v.numero_cliente, v.fecha_inicio ");
	
	$PREPARE selTarsoc FROM $sql;
	
	$DECLARE curTis CURSOR WITH HOLD FOR selTarsoc;
		
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
	strcpy(sql, "SELECT operando_vip, fecha_val_tarifa FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/********* Select Cliente ya migrado TIS **********/
	strcpy(sql, "SELECT operando_tis, fecha_val_tarifa FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado2 FROM $sql;
	
	/*********Insert Clientes extraidos VIP **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, flag_vip, operando_vip ");
	strcat(sql, ")VALUES(?, ?, 'S') ");
	
	$PREPARE insFlagVip FROM $sql;
	
	/************ Update Clientes Migra VIP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_vip = 'S', ");
   strcat(sql, "flag_vip = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagVip FROM $sql;

	/*********Insert Clientes extraidos TIS **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, flag_tis, operando_tis ");
	strcat(sql, ")VALUES(?, ?, 'S') ");
	
	$PREPARE insFlagTis FROM $sql;
	
	/************ Update Clientes Migra TIS **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_tis = 'S', ");
   strcat(sql, "flag_tis = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagTis FROM $sql;

	/*********Insert Flag Tasa **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, flag_tap");
	strcat(sql, ")VALUES(?, ?) ");
	
	$PREPARE insFlagTasa FROM $sql;
	
	/************ Update Flag Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "flag_tap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagTasa FROM $sql;

	/*********Insert Factor Tasa **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, factor_tap");
	strcat(sql, ")VALUES(?, ?) ");
	
	$PREPARE insFactorTasa FROM $sql;
	
	/************ Update Factor Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "factor_tap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFactorTasa FROM $sql;

	/*********Insert Precio Tasa **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, qptap");
	strcat(sql, ")VALUES(?, ?) ");
	
	$PREPARE insQTasa FROM $sql;
	
	/************ Update Precio Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "qptap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updQTasa FROM $sql;

	/*********Insert EBP **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, flag_ebp");
	strcat(sql, ")VALUES(?, ?) ");
	
	$PREPARE insEbp FROM $sql;
	
	/************ Update EBP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "flag_ebp = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updEbp FROM $sql;

	/*********Insert FP **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, qcontador");
	strcat(sql, ")VALUES(?, ?) ");
	
	$PREPARE insFp FROM $sql;
	
	/************ Update FP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "qcontador = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFp FROM $sql;

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
   
   /********* Registra Corrida **********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'DEPGAR', ?, CURRENT, ?)";

   /******** Fecha Inicio busqueda *******/
   $PREPARE selFechaDesde FROM "SELECT fecha_limi_inf, fecha_pivote FROM sap_regi_cliente
      WHERE numero_cliente = 0";
         
   /******** Cursor Cliente Tasa *******/
   strcpy(sql, "SELECT t.numero_cliente, "); 
   strcat(sql, "t.codigo_tasa, "); 
   strcat(sql, "t.partido, "); 
   strcat(sql, "t.partida_municipal, "); 
   strcat(sql, "t.no_contribuyente ");
   strcat(sql, "FROM cliente_tasa t, cliente c ");
   if(giTipoCorrida==1)	
      strcat(sql, ", migra_activos m ");	
   
   /*strcat(sql, "WHERE (t.fecha_anulacion IS NULL OR t.fecha_anulacion > ?) ");*/
   
   strcat(sql, "WHERE c.numero_cliente = t.numero_cliente ");
   strcat(sql, "AND c.estado_cliente = 0 ");
   if(giTipoCorrida==1)	
      strcat(sql, "AND m.numero_cliente = t.numero_cliente ");	
   
   $PREPARE selCliTasa FROM $sql;   
   $DECLARE curCliTasa CURSOR WITH HOLD FOR selCliTasa;

   /******** Cursor Exencion Tasa *******/
   $PREPARE selTasaVig FROM "SELECT numero_cliente, 
      fecha_activacion + 1,
      TO_CHAR(fecha_activacion + 1, '%Y%m%d'),
      NVL(TO_CHAR(fecha_desactivac, '%Y%m%d'), '99991231'),
      cant_valor_tasa
      FROM tasas_vigencia
      WHERE numero_cliente = ?
      AND fecha_activacion >= ?
      ORDER BY fecha_activacion ASC ";

   $DECLARE curTasaVig CURSOR FOR selTasaVig;
   
   /****** Precio Unitario de la tasa *****/
   $PREPARE selPrecioTasa FROM "SELECT h.numero_cliente, 
      h.corr_facturacion corr,
      h.fecha_facturacion ffac, 
      p.fecha, 
      p.valor,
      c.codigo_valor,
      t.cod_sap
      FROM hisfac h, carfac c2, condic_impositivas c, preca p, OUTER sap_transforma t
      WHERE h.numero_cliente = ?
      AND h.fecha_facturacion > ?
      AND c2.numero_cliente= h.numero_cliente
      AND c2.corr_facturacion = h.corr_facturacion
      AND c2.codigo_cargo = c.codigo_impuesto
      AND c2.codigo_cargo IN ('580','886','887')
      AND c.cod_municipio = h.partido
      AND c.clase_servicio = h.clase_servicio
      AND p.codigo_valor = c.codigo_valor      
      AND p.fecha = (SELECT MAX(p2.fecha) FROM preca p2
      	WHERE p2.codigo_valor = p.codigo_valor
        AND p2.fecha < h.fecha_facturacion)
      AND t.clave = 'QPTAP'
      AND t.cod_mac = c.codigo_valor
      ORDER BY 2 ASC ";
  
   $DECLARE curPrecioTasa CURSOR FOR selPrecioTasa;  
   
   /********** Cursor EBP **********/
   strcpy(sql, "SELECT e.numero_cliente, "); 
   strcat(sql, "e.fecha_inicio + 1, ");
   strcat(sql, "TO_CHAR(e.fecha_inicio + 1, '%Y%m%d'), ");
   strcat(sql, "NVL(TO_CHAR(e.fecha_desactivac, '%Y%m%d'), '99991231') ");
   strcat(sql, "FROM entid_bien_publico e, cliente c ");
   if(giTipoCorrida==1)	
      strcat(sql, ", migra_activos m ");	
   
   strcat(sql, "WHERE c.numero_cliente = e.numero_cliente ");
   strcat(sql, "AND c.estado_cliente = 0 ");
   strcat(sql, "AND e.fecha_inicio > ? ");
   if(giTipoCorrida==1)	
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");	
   
   strcat(sql, "ORDER BY e.numero_cliente, e.fecha_inicio ASC ");   
                  	
   $PREPARE selEBP FROM $sql;   
   $DECLARE curEBP CURSOR WITH HOLD FOR selEBP;
   
   /********** Cursor FP **********/
   strcpy(sql, "SELECT r.numero_cliente, t2.cod_sap, r.evento, r.fecha_evento, ");
   strcat(sql, "TRIM(t1.acronimo_sap) tipo_tarifa "); 
   strcat(sql, "FROM rer_eventos_cabe r, cliente c, medid me, sap_transforma t1, OUTER sap_transforma t2 ");
   if(giTipoCorrida==1)	
      strcat(sql, ", migra_activos m ");	
   
   if(glFechaParametro==-1){
      strcat(sql, "WHERE c.numero_cliente = r.numero_cliente ");
   }else{
      strcat(sql, "WHERE r.fecha_evento >= ? ");
      strcat(sql, "AND c.numero_cliente = r.numero_cliente ");
   }
   strcat(sql, "AND c.estado_cliente = 0 ");
   strcat(sql, "AND c.tipo_sum != 5 ");
   strcat(sql, "AND me.numero_cliente = r.numero_cliente ");
   strcat(sql, "AND me.estado = 'I' ");
   strcat(sql, "AND me.tipo_medidor = 'R' ");   
   strcat(sql, "AND t1.clave = 'TARIFTYP' ");
   strcat(sql, "AND t1.cod_mac = c.tarifa ");
   strcat(sql, "AND t2.clave = 'BFP' ");
   strcat(sql, "AND t2.cod_mac = r.evento ");
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");

   if(giTipoCorrida==1)	
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");	

   $PREPARE selFP FROM $sql;   
   $DECLARE curFP CURSOR WITH HOLD FOR selFP;

   /****** Cursor Eventos ******/
   $PREPARE selFPEve FROM "SELECT r.numero_cliente, 
      r.corr_evento, 
      t.cod_sap, 
      r.fecha_evento_desde + 1, 
      r.fecha_evento_hasta
      FROM rer_eventos_deta r, sap_transforma t
      WHERE r.numero_cliente = ?
      AND r.evento != 'SB'
      AND r.fecha_evento_desde > ?
      AND r.fecha_evento_desde != r.fecha_evento_hasta
      AND t.clave = 'BFP'
      AND t.cod_mac = r.evento
      ORDER BY r.corr_evento ";
   
   $DECLARE curFpEve CURSOR WITH HOLD FOR selFPEve;

   /****** Cursor Eventos SB ******/
   $PREPARE selFPEveSB FROM "SELECT r.numero_cliente, 
      r.corr_evento, 
      r.evento, 
      r.fecha_evento_desde + 1, 
      r.fecha_evento_hasta
      FROM rer_eventos_deta r
      WHERE r.numero_cliente = ?
      AND r.evento = 'SB'
      AND r.fecha_evento_desde > ?
      AND r.fecha_evento_desde != r.fecha_evento_hasta
      ORDER BY r.corr_evento ";
   
   $DECLARE curFpEveSB CURSOR WITH HOLD FOR selFPEveSB;
                     
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
   rsetnull(CLONGTYPE, (char *) &(regOpe->dValor));
   memset(regOpe->sTarifa, '\0', sizeof(regOpe->sTarifa));

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
/*      
   	if(gsTipoGenera[0]=='G'){
   		return 1;	
   	}
*/      
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}

   *iFlagMigra=2;
   
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

   if(iNx==1){
   	/* KEY */	
   	GeneraKEY(sTipo, fp, regOpe, iNx);
   	/* F_FLAG */	
   	GeneraFFlag(sTipo, fp, regOpe, iNx);
   }
   
	/* V_FLAG */	
	GeneraVFlag(sTipo, fp, regOpe, iNx);
		
	/* ENDE */  
  	/*GeneraENDE(fp, regOpe, iNx);*/
	
	return 1;
}

void GeneraENDE(fp, regOpe, iNx)
FILE *fp;
$ClsOperando	regOpe;
long			iNx;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regOpe.numero_cliente, iNx);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
}

void GeneraENDE2(fp, lNroCliente, iNx)
FILE *fp;
long  lNroCliente;
long			iNx;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
   if(iNx==3){
      sprintf(sLinea, "T1%ld\t&ENDE", lNroCliente);
   }else{
      sprintf(sLinea, "T1%ld-%ld\t&ENDE", lNroCliente, iNx);
   }

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
   	
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
short RegistraCliente(sOpe, nroCliente, cantidad, iFlagMigra)
char	*sOpe;
$long	nroCliente;
$long cantidad;
int		iFlagMigra;
{

   /*alltrim(sOpe, ' ');*/
   iFlagMigra=2;
   
	if(strcmp(sOpe, "VIP")==0){
		if(iFlagMigra==1){
			$EXECUTE insFlagVip using :nroCliente, :cantidad;
		}else{
			$EXECUTE updFlagVip using :cantidad, :nroCliente;
		}
   }
   
	if(strcmp(sOpe, "TIS")==0){
		if(iFlagMigra==1){
			$EXECUTE insFlagTis using :nroCliente, :cantidad;
		}else{
			$EXECUTE updFlagTis using :cantidad, :nroCliente;
		}
	}

   if(strcmp(sOpe, "TASAFF")==0){
		if(iFlagMigra==1){
			$EXECUTE insFlagTasa using :nroCliente, :cantidad;
         /*$EXECUTE insFactorTasa using :nroCliente, :cantidad;*/
         $EXECUTE updFactorTasa using :cantidad, :nroCliente;
		}else{
			$EXECUTE updFlagTasa using :cantidad, :nroCliente;
         $EXECUTE updFactorTasa using :cantidad, :nroCliente;
		}
   }

   if(strcmp(sOpe, "QTASA")==0){
		if(iFlagMigra==1){
			$EXECUTE insQTasa using :nroCliente, :cantidad;
		}else{
			$EXECUTE updQTasa using :cantidad, :nroCliente;
		}
   }

   if(strcmp(sOpe, "EBP")==0){
		if(iFlagMigra==1){
			$EXECUTE insEbp using :nroCliente, :cantidad;
		}else{
			$EXECUTE updEbp using :cantidad, :nroCliente;
		}
   }

   if(strcmp(sOpe, "FP")==0){
		if(iFlagMigra==1){
			$EXECUTE insFp using :nroCliente, :cantidad;
		}else{
			$EXECUTE updFp using :cantidad, :nroCliente;
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
	int  iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

   alltrim(regOpe.sOperando, ' ');

   if(strcmp(regOpe.sOperando, "FLAGVIP")==0){
      iNx=1;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tKEY\t", regOpe.numero_cliente, iNx);
      
   }else if(strcmp(regOpe.sOperando, "FLAGTIS")==0){
      iNx=2;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tKEY\t", regOpe.numero_cliente, iNx);
      
   }else{
      iNx=3;
      /* Llave */
   	sprintf(sLinea, "T1%ld\tKEY\t", regOpe.numero_cliente);
      
   }
   
	/* ANLAGE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regOpe.numero_cliente);
   /* BIS */	
	sprintf(sLinea, "%s%s", sLinea, regOpe.fecha_vig_tarifa);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KEY\n");
      exit(1);
   }	
   	
}

void GeneraFFlag(sTipo, fp, regOpe, iNx)
char			sTipo[2];
FILE 			*fp;
ClsOperando 	regOpe;
long			iNx;
{

	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

   alltrim(regOpe.sOperando, ' ');

   if(strcmp(regOpe.sOperando, "FLAGVIP")==0){
      iNx=1;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tF_FLAG\t", regOpe.numero_cliente, iNx);
   }else if(strcmp(regOpe.sOperando, "FLAGTIS")==0){
      iNx=2;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tF_FLAG\t", regOpe.numero_cliente, iNx);
   }else{
      iNx=3;
      /* Llave */
   	sprintf(sLinea, "T1%ld\tF_FLAG\t", regOpe.numero_cliente);
   }
	
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sOperando);
	
	if(sTipo[0]=='R'){
		strcat(sLinea, "X");	
	}

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir F_FLAG\n");
      exit(1);
   }	

}

void GeneraVFlag(sTipo, fp, regOpe, iNx)
char			sTipo[2];
FILE 			*fp;
ClsOperando 	regOpe;
long			iNx;
{

	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

   alltrim(regOpe.sOperando, ' ');

   if(strcmp(regOpe.sOperando, "FLAGVIP")==0){
      iNx=1;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tV_FLAG\t", regOpe.numero_cliente, iNx);
   }else if(strcmp(regOpe.sOperando, "FLAGTIS")==0){
      iNx=2;
      /* Llave */
   	sprintf(sLinea, "T1%ld-%ld\tV_FLAG\t", regOpe.numero_cliente, iNx);
   }else{
      iNx=3;
      /* Llave */
   	sprintf(sLinea, "T1%ld\tV_FLAG\t", regOpe.numero_cliente);
   }
	
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sFechaInicio);
   /* BIS */
	sprintf(sLinea, "%s%s\t", sLinea, regOpe.sFechaFin);
	
	if(sTipo[0]=='R'){
		strcat(sLinea, "X");	
	}

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir V_FLAG\n");
      exit(1);
   }	

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

void GenerarElectro()
{
$ClsOperando	 regOperandos;
$ClsOperando	 regOpeAux;
int				 iNx;
$long			    lClienteAnterior;
$long           lFechaValTarifa;
$int            iFlagMigra;
$long           CantCliVip;


   if(glFechaParametro > 0){
      $OPEN curElectro USING :glFechaParametro;
   }else{
      $OPEN curElectro USING :lFechaLimiteInferior;
   }

	lClienteAnterior=0;
		
	while(LeoElectroDependencia(&regOperandos)){
  
		if(lClienteAnterior != regOperandos.numero_cliente){
      
			/* Primera ocurrencia del cliente */
         if(lClienteAnterior > 0){
            GeneraENDE2(pFileOperandosUnx, lClienteAnterior, 1);
            /*if(giTipoCorrida == 0){*/
               $BEGIN WORK;
               if(!RegistraCliente("VIP", lClienteAnterior, CantCliVip, iFlagMigra)){
                  $ROLLBACK WORK;
                  printf("No se registro cliente %ld\n", lClienteAnterior);
               }else{
                  $COMMIT WORK;
               }
               
            /*}*/
         }
         lClienteAnterior = regOperandos.numero_cliente;
			iNx=1;
         CantCliVip=1;
         
			if(! ClienteYaMigrado("VIP", regOperandos.numero_cliente, &lFechaValTarifa, &iFlagMigra)){
            iFlagMigra=2;
            
            rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
/*            
            if(getFechaIni(regOperandos, &lFechaIniAux)){
               rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
               regOperandos.lFechaInicio=lFechaIniAux;
*/               
               if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
               
/*               
                  if(getFechaFin(regOperandos, &lFechaFinAux)){
                     rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                     regOperandos.lFechaFin=lFechaFinAux;
*/                     
                     /* registro desactivado */
                     GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                     iNx++;                  
                  /*}*/
               }else{
               
                  /* registro activo */
                  GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                  cantVipProcesada++;
                  iNx++;
                  CantCliVip++;
               }
            /*}*/
			}else{
				cantVipPreexistente++;
			}
		}else{
      
         rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
			/* Mismo Cliente fila anterior*/
/*         
          if(getFechaIni(regOperandos, &lFechaIniAux)){
             rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
             regOperandos.lFechaInicio=lFechaIniAux;
*/             
             if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
             
/*             
                if(getFechaFin(regOperandos, &lFechaFinAux)){
                   rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                   regOperandos.lFechaFin=lFechaFinAux;
*/                   
                   /* registro desactivado */
                   GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                   iNx++;
                   CantCliVip++;                  
                /*}*/
             }else{
             
                /* registro activo */
                GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                cantVipProcesada++;
                iNx++;
                CantCliVip++;
             }
          }
		/*}*/
   }
   /*GeneraENDE2(pFileOperandosUnx, lClienteAnterior, iNx);*/
   GeneraENDE2(pFileOperandosUnx, lClienteAnterior, 1);
   
	$CLOSE curElectro;
}

void GenerarTIS()
{
$ClsOperando	 regOperandos;
$ClsOperando	 regOpeAux;
int				 iNx;
$long			    lClienteAnterior;
$long           lFechaValTarifa;
$int            iFlagMigra;
$long           CantCliTis;

   if(glFechaParametro > 0){
      $OPEN curTis USING :glFechaParametro;
   }else{
      $OPEN curTis USING :lFechaLimiteInferior;
   }
	
	lClienteAnterior=0;
	
   while(LeoTis(&regOperandos)){
		if(lClienteAnterior != regOperandos.numero_cliente){
         
			/* Primera ocurrencia del cliente */
         if(lClienteAnterior > 0){
            GeneraENDE2(pFileOperandosUnx, lClienteAnterior, 2);
             /*if(giTipoCorrida ==0 ){*/
               $BEGIN WORK;
               if(!RegistraCliente("TIS", lClienteAnterior, CantCliTis, iFlagMigra)){
                  $ROLLBACK WORK;
                  printf("No se registro TIS para cliente %ld\n", lClienteAnterior);            
               }else{
                  $COMMIT WORK;
               }
            /*}*/
         }
         
         lClienteAnterior = regOperandos.numero_cliente;
			iNx=1;
         CantCliTis=1;
         
			if(! ClienteYaMigrado("TIS", regOperandos.numero_cliente, &lFechaValTarifa, &iFlagMigra)){
            iFlagMigra=2;
            rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
/*            
            if(getFechaIni(regOperandos, &lFechaIniAux)){
               rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
               regOperandos.lFechaInicio=lFechaIniAux;
*/               
               if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
/*               
                  if(getFechaFin(regOperandos, &lFechaFinAux)){
                     rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                     regOperandos.lFechaFin=lFechaFinAux;
*/                     
                     /* registro desactivado */
                     GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                     iNx++;
                     CantCliTis++;                  
                  /*}*/
               }else{
                  /* registro activo */
                  GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                  iNx++;
                  CantCliTis++;
                  cantTisProcesada++;
               }
            /*}*/
			}else{
				cantTisPreexistente++;
			}
		}else{
			/* Mismo Cliente fila anterior*/
         rfmtdate(lFechaValTarifa, "yyyymmdd", regOperandos.fecha_vig_tarifa);
          /*
          if(getFechaIni(regOperandos, &lFechaIniAux)){
             rfmtdate(lFechaIniAux, "yyyymmdd", regOperandos.sFechaInicio);
             regOperandos.lFechaInicio=lFechaIniAux;
          */   
             if(strcmp(regOperandos.sFechaFin, "99991231")!=0){
/*               
                if(getFechaFin(regOperandos, &lFechaFinAux)){
                   rfmtdate(lFechaFinAux, "yyyymmdd", regOperandos.sFechaFin);
                   regOperandos.lFechaFin=lFechaFinAux;
*/                   
                   /* registro desactivado */
                   GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                   iNx++;
                   CantCliTis++;                  
                /*}*/
             }else{
                /* registro activo */
                GenerarPlano("R", pFileOperandosUnx, regOperandos, iNx);
                iNx++;
                cantTisProcesada++;
                CantCliTis++;
             }
          }
		/*}*/
   }

   /*GeneraENDE2(pFileOperandosUnx, lClienteAnterior, iNx);*/
   GeneraENDE2(pFileOperandosUnx, lClienteAnterior, 2);
	$CLOSE curTIS;


}

void GenerarTasa()
{
$ClsOperando   regOpe;
$ClsTasa       regTasa;
$ClsTasaVig    regVig;
$ClsTasaPrecio regPrecio;
int            iVuelta;
$long          lFechaDesde;
$long          lFechaHasta;
$double        dMonto;
int            iNx;
$long          cantOpTasa;
int            iFlagMigra;

   /*$OPEN curCliTasa USING :lFechaPivote;*/
   $OPEN curCliTasa;
   
   while(LeoTasa(&regTasa)){
      
      iFlagMigra=getExiste(regTasa.numero_cliente);
      
      iVuelta=0;
      if(glFechaParametro==-1){
         $OPEN curTasaVig USING :regTasa.numero_cliente, :lFechaPivote;
      }else{
         $OPEN curTasaVig USING :regTasa.numero_cliente, :glFechaParametro;
      }
      iNx=1;
      cantOpTasa=1;      
      while(LeoTasaVig(&regVig)){
         lFechaDesde = regVig.lFechaActivacion;
         InicializaOperando(&regOpe);
         TraspasoTasa(regVig, lFechaDesde, &regOpe);
      
         /* Flag Cliente */
         PrintTasaCliente(regOpe, iNx);
                     
         /* Factor */
         InicializaOperando(&regOpe);
         TraspasoTasaFactor(regVig, lFechaDesde, &regOpe);
         PrintTasaFactor(regOpe, iNx);

         iNx++;
      }
      if(iNx > 1){
         GeneraENDE2(pFileFlagTap, regTasa.numero_cliente, 3); /* Flag Cliente */
         GeneraENDE2(pFileFactorTap, regTasa.numero_cliente, 3); /* FlagFactor */

      }      
      $CLOSE curTasaVig;

      /*if(giTipoCorrida==0){*/
         cantOpTasa = iNx-1;
         $BEGIN WORK;
         if(!RegistraCliente("TASAFF", regTasa.numero_cliente, cantOpTasa, iFlagMigra)){
            printf("No registre TASAFF cliente %ld\n", regTasa.numero_cliente);
            $ROLLBACK WORK;
         }else{
            $COMMIT WORK;
         }
      /*}*/
      
      /* Precio */
      iVuelta=0;
      if(glFechaParametro==-1){
         $OPEN curPrecioTasa USING :regTasa.numero_cliente, :lFechaPivote;
      }else{
         $OPEN curPrecioTasa USING :regTasa.numero_cliente, :glFechaParametro;
      }

      iNx=0;
      cantOpTasa=1;
      while(LeoTasaPrecio(&regPrecio)){
         if(iVuelta==0){
            /*lFechaDesde = regPrecio.fecha;*/
            lFechaDesde = regPrecio.fecha_facturacion + 1;
            dMonto = regPrecio.valor;
            iVuelta=1;         
         }else{
            TraspasoTasaPrecio(regPrecio, lFechaDesde, dMonto, &regOpe);
            PrintTasaPrecio(regOpe, iNx);
            /*lFechaDesde = regPrecio.fecha;*/
            lFechaDesde = regPrecio.fecha_facturacion + 1;
            dMonto = regPrecio.valor;
         }
         iNx++;
      }
      if(iNx > 1){
         GeneraENDE2(pFileQPTap, regTasa.numero_cliente, 3); /* Flag Precio */
      }
      $CLOSE curPrecioTasa;

      /*if(giTipoCorrida==0){*/
         cantOpTasa = iNx-1;
         $BEGIN WORK;
         if(!RegistraCliente("QTASA", regTasa.numero_cliente, cantOpTasa, iFlagMigra)){
            printf("No registre QTASA cliente %ld\n", regTasa.numero_cliente);
            $ROLLBACK WORK;
         }else{
            $COMMIT WORK;
         }
      /*}*/

            
      cantTasa++;
   }

   $CLOSE curCliTasa;
}

void PrintTasaCliente(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   
   if(strcmp(reg.sFechaFin, "99991231")==0){
      strcpy(sMarca, "R");
   }else{
      strcpy(sMarca, "N");
   }
   
   if(inx==1){
      GeneraKEY(sMarca, pFileFlagTap, reg, inx);
      GeneraFFlag(sMarca, pFileFlagTap, reg, inx);
   }
   GeneraVFlag(sMarca, pFileFlagTap, reg, inx);
   /*GeneraENDE(pFileFlagTap, reg, inx);*/

}

void PrintTasaFactor(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   strcpy(sMarca, "X");
   
   if(inx==1){
      GeneraKEY(sMarca, pFileFactorTap, reg, inx);
      GeneraFFact(pFileFactorTap, reg, inx);
   }
   GeneraVFact(pFileFactorTap, reg, inx);
   /*GeneraENDE(pFileFactorTap, reg, inx);*/

}

void GeneraFFact(fp, reg, inx)
FILE        *fp;
ClsOperando reg;
int         inx;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tF_FACT\t", reg.numero_cliente);
	
	sprintf(sLinea, "%s%s\t", sLinea, reg.sOperando);
   
   sprintf(sLinea, "%s%.02f\t", sLinea, reg.dValor);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir F_FACT\n");
      exit(1);
   }	

}

void GeneraVFact( fp, reg, inx)
FILE 			*fp;
ClsOperando 	reg;
int			inx;
{

	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tV_FACT\t", reg.numero_cliente);
	
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaInicio);
   /* BIS */
	sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaFin);
	
   sprintf(sLinea, "%s%.02f\t", sLinea, reg.dValor);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir V_FACT\n");
      exit(1);
   }	

}

short LeoTasa(reg)
$ClsTasa *reg;
{

   InicializaTasa(reg);

   $FETCH curCliTasa INTO
            :reg->numero_cliente,
            :reg->codigo_tasa, 
            :reg->partido, 
            :reg->partida_municipal, 
            :reg->no_contribuyente;
   
   if(SQLCODE != 0)
      return 0;      

   return 1;
}

void InicializaTasa(reg)
$ClsTasa *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
	memset(reg->codigo_tasa, '\0', sizeof(reg->codigo_tasa));
	memset(reg->partido, '\0', sizeof(reg->partido));
	memset(reg->partida_municipal, '\0', sizeof(reg->partida_municipal));
   memset(reg->no_contribuyente, '\0', sizeof(reg->no_contribuyente));
}

short LeoTasaVig(reg)
$ClsTasaVig *reg;
{
   InicializaTasaVig(reg);

   $FETCH curTasaVig INTO
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->sFechaDesactivac,
      :reg->cant_valor_tasa;

   if(SQLCODE != 0)
      return 0;      
   
   return 1;
}


void InicializaTasaVig(reg)
$ClsTasaVig *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaActivacion));
	memset(reg->sFechaActivacion, '\0', sizeof(reg->sFechaActivacion));
	memset(reg->sFechaDesactivac, '\0', sizeof(reg->sFechaDesactivac));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cant_valor_tasa));
}

void TraspasoTasa(regVig, lFecha, regOpe)
ClsTasaVig  regVig;
long        lFecha;
ClsOperando *regOpe;
{
   regOpe->numero_cliente = regVig.numero_cliente;
   rfmtdate(lFecha, "yyyymmdd", regOpe->sFechaInicio);
   strcpy(regOpe->sFechaFin, regVig.sFechaDesactivac);
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "FLAGTAP");
}

void TraspasoTasaFactor(regVig, lFecha, regOpe)
ClsTasaVig  regVig;
long        lFecha;
ClsOperando *regOpe;
{
   regOpe->numero_cliente = regVig.numero_cliente;
   rfmtdate(lFecha, "yyyymmdd", regOpe->sFechaInicio);
   strcpy(regOpe->sFechaFin, regVig.sFechaDesactivac);
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "FACTOR_TAP");
   regOpe->dValor = regVig.cant_valor_tasa;
}

short LeoTasaPrecio(reg)
$ClsTasaPrecio *reg;
{

   InicializaTasaPrecio(reg);
   
   $FETCH curPrecioTasa INTO
      :reg->numero_cliente,
      :reg->corr_facturacion,
      :reg->fecha_facturacion, 
      :reg->fecha, 
      :reg->valor,
      :reg->codigo_tasa,
      :reg->codigo_sap;

   if(SQLCODE != 0)
      return 0;      
      
   return 1;   
}

void InicializaTasaPrecio(reg)
$ClsTasaPrecio *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha));
   rsetnull(CDOUBLETYPE, (char *) &(reg->valor));
   memset(reg->codigo_tasa, '\0', sizeof(reg->codigo_tasa));
   memset(reg->codigo_sap, '\0', sizeof(reg->codigo_sap));
}

void TraspasoTasaPrecio(regPrecio, lFechaDesde, dMonto, regOpe)
ClsTasaPrecio  regPrecio;
long           lFechaDesde;
double         dMonto;
ClsOperando    *regOpe;
{
   long  lFechaHasta;
   char  sFechaHasta[9];
   
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));
   
   /*lFechaHasta = regPrecio.fecha -1;*/
   lFechaHasta = regPrecio.fecha_facturacion;
   
   regOpe->numero_cliente = regPrecio.numero_cliente;
   rfmtdate(lFechaDesde, "yyyymmdd", regOpe->sFechaInicio);
   rfmtdate(lFechaHasta, "yyyymmdd", regOpe->sFechaFin);
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "QPTAP");
   regOpe->dValor = dMonto;
   strcpy(regOpe->sValor, regPrecio.codigo_sap);

}

void PrintTasaPrecio(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   strcpy(sMarca, "X");
   
   if(inx==1){
      GeneraKEY(sMarca, pFileQPTap, reg, inx);
      GeneraFQpri(pFileQPTap, reg, inx);
   }
   GeneraVQpri(pFileQPTap, reg, inx);
   /*GeneraENDE(pFileQPTap, reg, inx);*/

}

void GeneraFQpri(fp, reg, inx)
FILE        *fp;
ClsOperando reg;
int         inx;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tF_QPRI\t", reg.numero_cliente);
	
   /* OPERAND */
	sprintf(sLinea, "%s%s\t", sLinea, reg.sOperando);
   
   /* AUTO INSERT */
   strcat(sLinea, "X");

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir F_QPRI\n");
      exit(1);
   }	

}

void GeneraVQpri( fp, reg, inx)
FILE 			*fp;
ClsOperando 	reg;
int			inx;
{

	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
   alltrim(reg.sValor,' ');
   
	sprintf(sLinea, "T1%ld\tV_QPRI\t", reg.numero_cliente);
	
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaInicio);
   /* BIS */
	sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaFin);
	
   /* PREIS */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sValor);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir V_QPRI\n");
      exit(1);
   }	

}

void GenerarEBP(){
$ClsOperando   regOpe;
$ClsEBP        regEbp;
int            iNx;
int            iFlagMigra;
$long			    lClienteAnterior;
int            iTieneColita;

   if(glFechaParametro==-1){
      $OPEN curEBP USING :lFechaPivote;
   }else{
      $OPEN curEBP USING :glFechaParametro;
   }
   
   
   iNx=1;
   lClienteAnterior=0;
   iTieneColita=0;
   while(LeoEBP(&regEbp)){
      iTieneColita=0;
      if(regEbp.numero_cliente != lClienteAnterior ){
         iNx=1;
         InicializaOperando(&regOpe);
         TraspasoEBP(regEbp, &regOpe);
         PrintEBP(regOpe, iNx);
         lClienteAnterior=regEbp.numero_cliente;      
         
         iFlagMigra=getExiste(lClienteAnterior);
         $BEGIN WORK;
         if(!RegistraCliente("EBP", lClienteAnterior, 1, iFlagMigra)){
            $ROLLBACK WORK;
            printf("No se registro EBP para cliente %ld\n", lClienteAnterior);
         }else{
            $COMMIT WORK;
         }
         GeneraENDE2(pFileFlagEbp, lClienteAnterior, 3);
         iNx++;
         cantEBP++;
      }else{
         InicializaOperando(&regOpe);
         TraspasoEBP(regEbp, &regOpe);
         PrintEBP(regOpe, iNx);
         lClienteAnterior=regEbp.numero_cliente;      
         iNx++;
         iTieneColita=1;
      }
   }
   
   if(iTieneColita==1)
      GeneraENDE2(pFileFlagEbp, lClienteAnterior, 3);
   
   $CLOSE curEBP;

}

short LeoEBP(reg)
$ClsEBP  *reg;
{

   InicializaEBP(reg);
   
   $FETCH curEBP INTO 
      :reg->numero_cliente, 
      :reg->lFechaInicio,
      :reg->sFechaInicio,
      :reg->sFechaFin;

   if(SQLCODE != 0)
      return 0;
      
   return 1;
}

void InicializaEBP(reg)
$ClsEBP  *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaInicio));
	memset(reg->sFechaInicio, '\0', sizeof(reg->sFechaInicio));
	memset(reg->sFechaFin, '\0', sizeof(reg->sFechaFin));
}

void TraspasoEBP(regEbp, regOpe)
$ClsEBP        regEbp;
$ClsOperando   *regOpe;
{

   regOpe->numero_cliente = regEbp.numero_cliente;
   strcpy(regOpe->sFechaInicio, regEbp.sFechaInicio);
   strcpy(regOpe->sFechaFin, regEbp.sFechaFin);
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "FLAGEBP");

}

void  PrintEBP(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   
   if(strcmp(reg.sFechaFin, "99991231")==0){
      strcpy(sMarca, "R");
   }else{
      strcpy(sMarca, "N");
   }
   
   if(inx==1){
      GeneraKEY(sMarca, pFileFlagEbp, reg, inx);
      GeneraFFlag(sMarca, pFileFlagEbp, reg, inx);
   }
   GeneraVFlag(sMarca, pFileFlagEbp, reg, inx);
   /*GeneraENDE(pFileFlagEbp, reg, inx);*/

}

void GenerarFP(){
$ClsOperando   regOpe;
$ClsFP         regFp;
int            iNx;
int            iNx2;
int            iFlagMigra;
$char          sFechaPivoteEvento[11];
$long          lFechaPivoteEvento;
$ClsFPDeta     regFpDeta;
int            iTiene;
int            iTieneSB;

   memset(sFechaPivoteEvento, '\0', sizeof(sFechaPivoteEvento));
   strcpy(sFechaPivoteEvento, "01/12/2014");
   rdefmtdate(&lFechaPivoteEvento, "dd/mm/yyyy", sFechaPivoteEvento); /*char to long*/

   if(glFechaParametro==-1){
      $OPEN curFP;
   }else{
      $OPEN curFP USING :glFechaParametro;
   }
   
   /*iNx=1;*/
   cantFP=0;
   while(LeoFP(&regFp)){
   
      iNx=1;
      iNx2=1;
      iTiene=0;
      iTieneSB=0;
      if(regFp.lFechaEvento > lFechaPivoteEvento){
         /* El Detalle */
         if(glFechaParametro==-1){
            $OPEN curFpEve USING :regFp.numero_cliente, :lFechaPivoteEvento;
         }else{
            $OPEN curFpEve USING :regFp.numero_cliente, :glFechaParametro;
         }            
         
         while(LeoFPDeta(&regFpDeta)){
         
            strcpy(regFpDeta.sTarifa, regFp.sTarifa);
            
            InicializaOperando(&regOpe);
            TraspasoFPDeta(regFpDeta, &regOpe);
            PrintFP(regOpe, iNx);
            iNx++;
            iTiene=1;
         }         
         
         $CLOSE curFpEve;
         
         /* El Detalle del SB */
         if(glFechaParametro==-1){
            $OPEN curFpEveSB USING :regFp.numero_cliente, :lFechaPivoteEvento;
         }else{
            $OPEN curFpEveSB USING :regFp.numero_cliente, :glFechaParametro;
         }            
         
         while(LeoFPDetaSB(&regFpDeta)){
         
            strcpy(regFpDeta.sTarifa, regFp.sTarifa);
            
            InicializaOperando(&regOpe);
            TraspasoFPDeta_SB(regFpDeta, &regOpe);
            PrintFP_SB(regOpe, iNx2);
            iNx2++;
            iTieneSB=1;
         }         
         
         $CLOSE curFpEveSB;
         
      }else{
         InicializaOperando(&regOpe);
         /* Solo la Cabecera */
         if(strcmp(regFp.sEventoMac, "SB")){
            TraspasoFP(regFp, &regOpe);
            PrintFP(regOpe, iNx);
            iTiene=1;
         }else{
            /* Solo la cabecera del SB */
            TraspasoFP_SB(regFp, &regOpe);
            PrintFP_SB(regOpe, iNx2);
            iTieneSB=1;
         }         
      }
      
      if(iTiene==1){
         cantFP++;
         iFlagMigra=getExiste(regFp.numero_cliente);
         
         $BEGIN WORK;
         if(!RegistraCliente("FP", regFp.numero_cliente, 1, iFlagMigra)){
            printf("No registro FP para cliente %ld\n", regFp.numero_cliente);
            $ROLLBACK WORK;
         }else{
            $COMMIT WORK;
         }
      }
      
      if(iTiene==1){
         GeneraENDE2(pFileFlagFP, regFp.numero_cliente, 3);
      }
      
      if(iTieneSB==1){
         GeneraENDE2(pFileFlagFP_SB, regFp.numero_cliente, 3);
      }
   }
   
   $CLOSE curFP;

}

short LeoFP(reg)
$ClsFP  *reg;
{

   InicializaFP(reg);
   
   $FETCH curFP INTO 
      :reg->numero_cliente, 
      :reg->evento,
      :reg->sEventoMac,
      :reg->lFechaEvento,
      :reg->sTarifa;

   if(SQLCODE != 0)
      return 0;
   
   if(reg->lFechaEvento < lFechaLimiteInferior)
      reg->lFechaEvento = lFechaLimiteInferior;
         
   alltrim(reg->evento, ' ');
   alltrim(reg->sEventoMac, ' ');
   
   return 1;
}

void InicializaFP(reg)
$ClsFP  *reg;
{
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->evento, '\0', sizeof(reg->evento));
   memset(reg->sEventoMac, '\0', sizeof(reg->sEventoMac));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaEvento));
   memset(reg->sTarifa, '\0', sizeof(reg->sTarifa));
}


void TraspasoFP(regFp, regOpe)
$ClsFP        regFp;
$ClsOperando   *regOpe;
{

   alltrim(regFp.evento, ' ');
   
   regOpe->numero_cliente = regFp.numero_cliente;
   rfmtdate(regFp.lFechaEvento, "yyyymmdd", regOpe->sFechaInicio); /* long to char */
   strcpy(regOpe->sFechaFin, "99991231");
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "QCONTADOR");

   strcpy(regOpe->sValor, regFp.evento);
   strcpy(regOpe->sTarifa, regFp.sTarifa);
   
}

void TraspasoFPDeta(regFpDeta, regOpe)
$ClsFPDeta     regFpDeta;
$ClsOperando   *regOpe;
{

   alltrim(regFpDeta.evento, ' ');
   
   regOpe->numero_cliente = regFpDeta.numero_cliente;
   rfmtdate(regFpDeta.lFechaDesdeEvento, "yyyymmdd", regOpe->sFechaInicio); /* long to char */
   if(!risnull(CLONGTYPE, (char *) &regFpDeta.lFechaHastaEvento)){
      rfmtdate(regFpDeta.lFechaHastaEvento, "yyyymmdd", regOpe->sFechaFin); /* long to char */
   }else{
      strcpy(regOpe->sFechaFin, "99991231");
   }

   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "QCONTADOR");

   strcpy(regOpe->sValor, regFpDeta.evento);
   strcpy(regOpe->sTarifa, regFpDeta.sTarifa);

}

void  PrintFP(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   
   strcpy(sMarca, "R");
   
   if(inx == 1){
      GeneraKEY(sMarca, pFileFlagFP, reg, inx);
      GeneraFQUAN(pFileFlagFP, reg, inx);
   }
   GeneraVQUAN(pFileFlagFP, reg, inx);
   /*GeneraENDE(pFileFlagFP, reg, inx);*/

}

short LeoFPDeta(reg)
$ClsFPDeta  *reg;
{

   InicializaFPDeta(reg);

   $FETCH curFpEve INTO :reg->numero_cliente,
      :reg->corr_evento, 
      :reg->evento,
      :reg->lFechaDesdeEvento,
      :reg->lFechaHastaEvento;

   if(SQLCODE != 0)
      return 0;
         
   return 1;
}

void InicializaFPDeta(reg)
$ClsFPDeta  *reg;
{

	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->evento, '\0', sizeof(reg->evento));
   rsetnull(CINTTYPE, (char *) &(reg->corr_evento));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaDesdeEvento));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaHastaEvento));
   memset(reg->sTarifa, '\0', sizeof(reg->sTarifa));

} 


void  GeneraFQUAN(fp, reg, inx)
FILE        *fp;
ClsOperando reg;
int         inx;
{
	char	sLinea[1000];
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   sprintf(sLinea, "T1%ld\tF_QUAN\t", reg.numero_cliente);
   
   /* OPERAND */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sOperando);

   /* AUTO_INSER */
   strcat(sLinea, "X");

   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir FQUAN\n");
      exit(1);
   }	
}

void  GeneraVQUAN(fp, reg, inx)
FILE        *fp;
ClsOperando reg;
int         inx;
{
	char	sLinea[1000];
   int   iRcv;

   sprintf(sLinea, "T1%ld\tV_QUAN\t", reg.numero_cliente);

   /* AB */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaInicio);
   
   /* BIS2 */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sFechaFin);
   
   /* LMENGE */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sValor);
   
   /* TARIFART */
   sprintf(sLinea, "%s%s\t", sLinea, reg.sTarifa);
   
   /* KONDIGR */
   strcat(sLinea, "ENERGIA");

   strcat(sLinea, "\n");
   
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir VQUAN\n");
      exit(1);
   }	
}

int   getExiste(lNroCliente)
$long lNroCliente;
{
   $int iRcv=0;

   $EXECUTE selExiste INTO :iRcv USING :lNroCliente;
   
   if(iRcv==0){
      iRcv=1;
   }else{
      iRcv=2;
   }
   
   return iRcv;
}


short LeoFPDetaSB(reg)
$ClsFPDeta  *reg;
{

   InicializaFPDeta(reg);

   $FETCH curFpEveSB INTO :reg->numero_cliente,
      :reg->corr_evento, 
      :reg->evento,
      :reg->lFechaDesdeEvento,
      :reg->lFechaHastaEvento;

   if(SQLCODE != 0)
      return 0;
         
   return 1;
}

void TraspasoFP_SB(regFp, regOpe)
$ClsFP        regFp;
$ClsOperando   *regOpe;
{

   alltrim(regFp.evento, ' ');
   
   regOpe->numero_cliente = regFp.numero_cliente;
   rfmtdate(regFp.lFechaEvento, "yyyymmdd", regOpe->sFechaInicio); /* long to char */
   strcpy(regOpe->sFechaFin, "99991231");
   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "FLAGSTBY");

   strcpy(regOpe->sValor, regFp.evento);
   strcpy(regOpe->sTarifa, regFp.sTarifa);
   
}

void TraspasoFPDeta_SB(regFpDeta, regOpe)
$ClsFPDeta     regFpDeta;
$ClsOperando   *regOpe;
{

   alltrim(regFpDeta.evento, ' ');
   
   regOpe->numero_cliente = regFpDeta.numero_cliente;
   rfmtdate(regFpDeta.lFechaDesdeEvento, "yyyymmdd", regOpe->sFechaInicio); /* long to char */
   if(!risnull(CLONGTYPE, (char *) &regFpDeta.lFechaHastaEvento)){
      rfmtdate(regFpDeta.lFechaHastaEvento, "yyyymmdd", regOpe->sFechaFin); /* long to char */
   }else{
      strcpy(regOpe->sFechaFin, "99991231");
   }

   strcpy(regOpe->fecha_vig_tarifa, "20141201");
   strcpy(regOpe->sOperando, "FLAGSTBY");

   strcpy(regOpe->sValor, regFpDeta.evento);
   strcpy(regOpe->sTarifa, regFpDeta.sTarifa);

}

void  PrintFP_SB(reg, inx)
ClsOperando reg;
int         inx;
{
   char  sMarca[2];
   
   strcpy(sMarca, "R");
   
   if(inx == 1){
      GeneraKEY(sMarca, pFileFlagFP_SB, reg, inx);
      GeneraFFlag(sMarca, pFileFlagFP_SB, reg, inx);
   }
   GeneraVFlag(sMarca, pFileFlagFP_SB, reg, inx);
   /*GeneraENDE(pFileFlagFP_SB, reg, inx);*/

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

