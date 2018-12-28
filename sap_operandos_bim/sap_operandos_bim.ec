/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_operandos_bim
    
	Fecha : 23/05/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura OPERANDOS para operandos
      bimestrales.
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0=Activos; 1= No Activos; 2= Todos;		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		<Fecha Inicio Busqueda> <Opcional>: dd/mm/aaaa

********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_operandos_bim.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
$long glFechaDesde;

char	sArchQConsBimesUnx[100];
char	sSoloArchivoQConsBimes[100];
char	sArchFacDiasPCUnx[100];
char	sSoloArchivoFacDiasPC[100];

char	sArchQConsActivaUnx[100];
char	sSoloArchivoQConsActiva[100];
char	sArchQConsReactivaUnx[100];
char	sSoloArchivoQConsReactiva[100];

char	sArchCosPhiUnx[100];
char	sSoloArchivoCosPhi[100];

FILE  *fpQConsBimes;
FILE  *fpFacDiasPC;
FILE  *fpQConsActiva;
FILE  *fpQConsReactiva;
FILE  *fpCosPhi;

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
$int	iCorrelativos;

$dtime_t    gtInicioCorrida;
$char       sLstParametros[100];
$long       glFechaParametro;


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$long    lFechaRti;

char	*vSucursal[]={"0003", "0004", "0010", "0020", "0023", "0026", "0050", "0065", "0053", "0056", "0059", "0069"};
$char	sSucursal[5];
int		i;
$ClsCliente       regCliente;
$ClsFactura       regFactu;
$ClsAhorroHist    regAhorro;
$ClsFacts         regFact;
FILE              *fpUnx;

int         iFlagRefacturada;
$long       lFechaInicio;
$long       lFechaLecturaPrima;
$long       lFechaLectuAnterior;
long        lContador;
int         iIndice;

char        sFechaDesde[11];
char        sFechaHasta[11];
$long       lFechaDesde;
$long       lFechaHasta;

$long       cantConsu;
$long       cantLectuActi;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}

	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 120;
	$SET ISOLATION TO DIRTY READ;
	$SET ISOLATION TO CURSOR STABILITY;
	
	CreaPrepare();


	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
   
/*		
	$EXECUTE selCorrelativos into :iCorrelativos;
*/
   $EXECUTE selFechaRti INTO :lFechaRti;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha RTI\n");
      exit(2);
   }
/*   		
   rdefmtdate(&lFechaInicio, "yyyymmdd", "20141201");
   rdefmtdate(&lFechaHasta, "yyyymmdd", "20160131");
*/   
            
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(sSucursal, '\0', sizeof(sSucursal));
   
/*   
	for(i=0; i<12; i++){
		strcpy(sSucursal, vSucursal[i]);
*/
      strcpy(sSucursal, "");
      
      lContador=0;
      iIndice=1;
      
		if(!AbreArchivos(sSucursal, iIndice)){
			exit(1);	
		}
		
		$OPEN curClientes;
/*		
		printf("Procesando Sucursal %s......\n", sSucursal);
*/         
      while(LeoCliente(&regCliente)){
         cantConsu=0;
         cantLectuActi=0;
         if(!ClienteYaMigrado(regCliente.numero_cliente, &lFechaInicio, &iFlagMigra)){
            
            if(regCliente.corr_facturacion > 0){
               lFechaLecturaPrima=0;
               lFechaLectuAnterior=0;
               /*
               getPrimaLectura(regCliente.numero_cliente, &lFechaLecturaPrima);
               */
               /*
               $OPEN curFactura USING  :regCliente.numero_cliente, :lFechaInicio, :lFechaHasta;
               */
               if(glFechaParametro > 0)
                  lFechaInicio = glFechaParametro;
                  
               $OPEN curFactura USING  :regCliente.numero_cliente, :lFechaInicio;
               
               while(LeoFactura(&regFactu)){
                  if(regFactu.indica_refact[0]=='N'){
                     /* Hago el de consumos bimestrales */
                     TraspasoDatosFactu(1, regCliente, regFactu, &regFact);
                     fpUnx=fpQConsBimes;
                     GenerarPlanos(fpUnx, 1, regFact);
                     
                     /* Hago el de Dias del periodo bimestral */
                     TraspasoDatosFactu(2, regCliente, regFactu, &regFact);
                     fpUnx=fpFacDiasPC;
                     GenerarPlanos(fpUnx, 2, regFact);
                     
                     cantConsu++;
                     if(regFactu.fhasta >= lFechaLimiteInferior){
                        /* QCONBFPACT*/
                        TraspasoDatosFactu(3, regCliente, regFactu, &regFact);
                        GenerarPlanos(fpQConsActiva, 3, regFact);
                        cantLectuActi++;
                        if(regFactu.tipo_medidor[0]=='R'){
                           if(getConsuReactiva(&regFactu)){
                              /* QCONBFPREAC */
                              TraspasoDatosFactu(4, regCliente, regFactu, &regFact);
                              GenerarPlanos(fpQConsReactiva, 4, regFact);
                           }else{
                              printf("No se encontró consumo reactiva para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                           }
                        }
                     }
                     /*
                     if(regFactu.corr_facturacion == regCliente.corr_facturacion){
                        if(regFactu.tipo_medidor[0]=='R'){
                           // QCONTADOR 
                           if(getLeyenda(&regFactu, lFechaInicio)){
                              if(getIniVentanaAgenda(&regFactu)){
                                 TraspasoDatosFactu(5, regCliente, regFactu, &regFact);
                                 GenerarPlanos(fpCosPhi, 5, regFact);
                              }else{
                                 printf("No se encontró Inicio Ventana Agenda para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                              }
                           }else{
                              printf("No se encontró Leyenda CosPhi para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                           }
                        }
                     }
                     */  
                  }else{
                     
                     if(regFactu.fhasta >= lFechaLimiteInferior){
                        if(regFactu.tipo_medidor[0]=='R'){
                           if(!getConsuReactiva(&regFactu)){
                              printf("No se encontró consumo reactiva para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);                           
                           }
                        }
                     }
                     /* Actualizar el consumo_sum con los refac */
                     $OPEN curRefac USING :regCliente.numero_cliente, :regFactu.numero_factura, :regFactu.fecha_facturacion;
                     
                     while(LeoRefac(&regFactu)){
                        /* Reevalua el consumo_sum */
                     }
                     
                     $CLOSE curRefac;

                     /* Hago el de consumos bimestrales */
                     TraspasoDatosFactu(1, regCliente, regFactu, &regFact);
                     fpUnx=fpQConsBimes;
                     GenerarPlanos(fpUnx, 1, regFact);
                     
                     /* Hago el de Dias del periodo bimestral */
                     TraspasoDatosFactu(2, regCliente, regFactu, &regFact);
                     fpUnx=fpFacDiasPC;
                     GenerarPlanos(fpUnx, 2, regFact);
                     
                     cantConsu++;
                     if(regFactu.fhasta >= lFechaLimiteInferior){
                        /* QCONBFPACT*/
                        TraspasoDatosFactu(3, regCliente, regFactu, &regFact);
                        GenerarPlanos(fpQConsActiva, 3, regFact);
                        cantLectuActi++;
                        
                        if(regFactu.tipo_medidor[0]=='R'){
                           /* QCONBFPREAC */
                           TraspasoDatosFactu(4, regCliente, regFactu, &regFact);
                           GenerarPlanos(fpQConsReactiva, 4, regFact);
                        }
                     }
                     /*
                     if(regFactu.corr_facturacion == regCliente.corr_facturacion){
                        if(regFactu.tipo_medidor[0]=='R'){
                           // QCONTADOR
                           if(getLeyenda(&regFactu, lFechaInicio)){
                              if(getIniVentanaAgenda(&regFactu)){
                                 TraspasoDatosFactu(5, regCliente, regFactu, &regFact);
                                 GenerarPlanos(fpCosPhi, 5, regFact);
                              }else{
                                 printf("No se encontró Inicio Ventana Agenda para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                              }
                           }else{
                              printf("No se encontró Leyenda CosPhi para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                           }
                        }
                     }  
                     */
                  }
               }
               
               $CLOSE curFactura;
               
               
               $OPEN curAhorro USING :regCliente.numero_cliente;                
               
               while(LeoAhorro(&regAhorro)){
                  if(lFechaLectuAnterior==0 || (lFechaLectuAnterior!=0 && lFechaLectuAnterior != regAhorro.lFechaInicio)){
                     /* Hago el de consumos bimestrales */
                     TraspasoDatos(1, regCliente, lFechaLecturaPrima, regAhorro, &regFact);
                     fpUnx=fpQConsBimes;
                     GenerarPlanos(fpUnx, 1, regFact);
                     
                     /* Hago el de Dias del periodo bimestral */
                     TraspasoDatos(2, regCliente, lFechaLecturaPrima, regAhorro, &regFact);
                     fpUnx=fpFacDiasPC;
                     GenerarPlanos(fpUnx, 2, regFact);
                     lFechaLectuAnterior = regAhorro.lFechaInicio;
                     
                     cantConsu++;
                  }
               }
               
               $CLOSE curAhorro;
               
               lContador++;
               if(lContador >= 350000){
                  fclose(fpQConsBimes);
                  fclose(fpFacDiasPC);
                  
                  MueveArchivos();
                  
                  iIndice++;
                  lContador=0;
            		if(!AbreArchivos(sSucursal, iIndice)){
            			exit(1);	
            		}
               }
            }

            /*if(giTipoCorrida==0){*/            
               $BEGIN WORK;            
               if(!RegistraCliente(regCliente.numero_cliente, cantConsu, cantLectuActi, iFlagMigra)){
                  $ROLLBACK WORK;
                  exit(2);
               }
               $COMMIT WORK;
            /*}*/            
            cantProcesada++;
         }else{
            cantPreexistente++;
         } 
         
                 
      } /* Clientes */
   
      $CLOSE curClientes;

      CerrarArchivos();
/*      
   }  // Sucursales 
*/


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
   MueveArchivos();
/*   
   FormateaArchivos(sSucursal, iIndice);
*/   
   
   /*
	for(i=0; i<12; i++){
		strcpy(sSucursal, vSucursal[i]);

      FormateaArchivos(sSucursal, iIndice);
   }
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
	printf("Operandos Bimestrales\n");
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
char  sFechaPar[11];
   
   memset(sFechaPar, '\0', sizeof(sFechaPar));
   memset(sLstParametros, '\0', sizeof(sLstParametros));
   
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

   sprintf(sLstParametros, "%s %s %s %s", argv[1], argv[2], argv[3], argv[4]);
   
	if(argc ==6){
      strcpy(sFechaPar, argv[5]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
      sprintf(sLstParametros, " %s %s",sLstParametros , argv[5]);
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
		printf("	<Fecha Inicio> = dd/mm/aaaa (opcional).\n");
}

short AbreArchivos(sSucur, indice)
char  sSucur[5];
int   indice;
{
	
	memset(sArchQConsBimesUnx,'\0',sizeof(sArchQConsBimesUnx));
	memset(sSoloArchivoQConsBimes,'\0',sizeof(sSoloArchivoQConsBimes));

	memset(sArchFacDiasPCUnx,'\0',sizeof(sArchFacDiasPCUnx));
	memset(sSoloArchivoFacDiasPC,'\0',sizeof(sSoloArchivoFacDiasPC));

	memset(sArchQConsActivaUnx,'\0',sizeof(sArchQConsActivaUnx));
	memset(sSoloArchivoQConsActiva,'\0',sizeof(sSoloArchivoQConsActiva));

	memset(sArchQConsReactivaUnx,'\0',sizeof(sArchQConsReactivaUnx));
	memset(sSoloArchivoQConsReactiva,'\0',sizeof(sSoloArchivoQConsReactiva));

	memset(sArchCosPhiUnx,'\0',sizeof(sArchCosPhiUnx));
	memset(sSoloArchivoCosPhi,'\0',sizeof(sSoloArchivoCosPhi));

   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchQConsBimesUnx  , "%sT1FACTS_QCONSBIMES_%s_%d.unx", sPathSalida, sSucur, indice );
	sprintf( sSoloArchivoQConsBimes, "T1FACTS_QCONSBIMES_%s_%d.unx", sSucur, indice);

	fpQConsBimes=fopen( sArchQConsBimesUnx, "w" );
	if( !fpQConsBimes ){
		printf("ERROR al abrir archivo %s.\n", sArchQConsBimesUnx );
		return 0;
	}

	sprintf( sArchFacDiasPCUnx  , "%sT1FACTS_FACDIASPC_%s_%d.unx", sPathSalida, sSucur, indice );
	sprintf( sSoloArchivoFacDiasPC, "T1FACTS_FACDIASPC_%s_%d.unx", sSucur, indice);

	fpFacDiasPC=fopen( sArchFacDiasPCUnx, "w" );
	if( !fpFacDiasPC ){
		printf("ERROR al abrir archivo %s.\n", sArchFacDiasPCUnx );
		return 0;
	}
   
	sprintf( sArchQConsActivaUnx  , "%sT1FACTS_QCONBFPACT_%s_%d.unx", sPathSalida, sSucur, indice );
	sprintf( sSoloArchivoQConsActiva, "T1FACTS_QCONBFPACT_%s_%d.unx", sSucur, indice);

	fpQConsActiva=fopen( sArchQConsActivaUnx, "w" );
	if( !fpQConsActiva ){
		printf("ERROR al abrir archivo %s.\n", sArchQConsActivaUnx );
		return 0;
	}
   
	sprintf( sArchQConsReactivaUnx  , "%sT1FACTS_QCONBFPREAC_%s_%d.unx", sPathSalida, sSucur, indice );
	sprintf( sSoloArchivoQConsReactiva, "T1FACTS_QCONBFPREAC_%s_%d.unx", sSucur, indice);

	fpQConsReactiva=fopen( sArchQConsReactivaUnx, "w" );
	if( !fpQConsActiva ){
		printf("ERROR al abrir archivo %s.\n", sArchQConsReactivaUnx );
		return 0;
	}
/*   
	sprintf( sArchCosPhiUnx  , "%sT1FACTS_QCONTADOR_%s_%d.unx", sPathSalida, sSucur, indice );
	sprintf( sSoloArchivoCosPhi, "T1FACTS_QCONTADOR_%s_%d.unx", sSucur, indice);

	fpCosPhi=fopen( sArchCosPhiUnx, "w" );
	if( !fpCosPhi ){
		printf("ERROR al abrir archivo %s.\n", sArchCosPhiUnx );
		return 0;
	}
*/	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(fpQConsBimes);
   fclose(fpFacDiasPC);
   fclose(fpQConsActiva);
   fclose(fpQConsReactiva);
   /*fclose(fpCosPhi);*/

}

void  MueveArchivos()
{
char	sCommand[1000];
int	iRcv;
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

   /* El de consumos bimestrales */
	sprintf(sCommand, "chmod 755 %s", sArchQConsBimesUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchQConsBimesUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchQConsBimesUnx);
      iRcv=system(sCommand);
   }
   
   
   /* El de Dias del período */
	sprintf(sCommand, "chmod 755 %s", sArchFacDiasPCUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchFacDiasPCUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchFacDiasPCUnx);
      iRcv=system(sCommand);
   }

   /* Consumo Activa */
	sprintf(sCommand, "chmod 755 %s", sArchQConsActivaUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchQConsActivaUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchQConsActivaUnx);
      iRcv=system(sCommand);
   }
   
   /* Consumo Reactiva */
	sprintf(sCommand, "chmod 755 %s", sArchQConsReactivaUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchQConsReactivaUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchQConsReactivaUnx);
      iRcv=system(sCommand);
   }

   /* Coseno Phi */
/*   
	sprintf(sCommand, "chmod 755 %s", sArchCosPhiUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchCosPhiUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchCosPhiUnx);
      iRcv=system(sCommand);
   }
*/   
}

void FormateaArchivos(sSucur, indice)
char  sSucur[5];
int   indice;
{
char	sCommand[1000];
int	iRcv, i;
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

   for(i=1; i<= indice; i++){
   	sprintf( sArchQConsBimesUnx  , "%sT1FACTS_QCONSBIMES_%s_%d.unx", sPathSalida, sSucur, i );
      sprintf( sArchFacDiasPCUnx  , "%sT1FACTS_FACDIASPC_%s_%d.unx", sPathSalida, sSucur, i );
      
      /* El de consumos bimestrales */
   	sprintf(sCommand, "chmod 755 %s", sArchQConsBimesUnx);
   	iRcv=system(sCommand);
   	
   	sprintf(sCommand, "cp %s %s", sArchQConsBimesUnx, sPathCp);
   	iRcv=system(sCommand);		
   
      sprintf(sCommand, "rm %s", sArchQConsBimesUnx);
      iRcv=system(sCommand);
      
      
      /* El de Dias del período */
   	sprintf(sCommand, "chmod 755 %s", sArchFacDiasPCUnx);
   	iRcv=system(sCommand);
   	
   	sprintf(sCommand, "cp %s %s", sArchFacDiasPCUnx, sPathCp);
   	iRcv=system(sCommand);		
   
      sprintf(sCommand, "rm %s", sArchFacDiasPCUnx);
      iRcv=system(sCommand);
   
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

   /********* Fecha RTi **********/
	strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;

	/******** Cursor CLIENTES  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
   strcat(sql, "NVL(c.corr_facturacion, 0), ");
   strcat(sql, "TRIM(t2.acronimo_sap) tipo_tarifa "); 
   strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER sap_transforma t1, OUTER sap_transforma t2 ");

   if(giTipoCorrida==1) 	
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
	/*strcat(sql, "AND c.sucursal = ? ");*/
	strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND c.sector != 88 ");
   strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
   strcat(sql, "AND t1.clave = 'TIPCLI' ");
   strcat(sql, "AND t1.cod_mac = c.tipo_cliente ");
   strcat(sql, "AND t2.clave = 'TARIFTYP' ");
   strcat(sql, "AND t2.cod_mac = c.tarifa ");

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
		
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	

   if(giTipoCorrida == 1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /*********** Facturas ************/
   strcpy(sql, "SELECT DISTINCT h.numero_cliente, "); 
   strcat(sql, "h.corr_facturacion, ");
   strcat(sql, "l1.lectura_facturac - l2.lectura_facturac, "); 
   /*strcat(sql, "h.consumo_sum, ");*/ 
   strcat(sql, "h.tarifa, "); 
   strcat(sql, "h.indica_refact, ");
   strcat(sql, "l2.fecha_lectura + 1 fdesde, "); 
   strcat(sql, "l1.fecha_lectura fhasta, ");
   strcat(sql, "(l1.fecha_lectura - (l2.fecha_lectura + 1)) difdias, ");
   strcat(sql, "((l1.lectura_facturac - l2.lectura_facturac)/ (l1.fecha_lectura - (l2.fecha_lectura + 1))) * 61 cons_61, ");
   /*strcat(sql, "(h.consumo_sum / (l1.fecha_lectura - (l2.fecha_lectura + 1))) * 61 cons_61, ");*/
   strcat(sql, "h.fecha_facturacion, ");
   strcat(sql, "h.numero_factura, ");
   strcat(sql, "l1.tipo_lectura, ");
   strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
   strcat(sql, "'000T1'|| lpad(h.sector,2,0) || sc.cod_ul_sap porcion, ");
   strcat(sql, "TRIM(sc.cod_ul_sap || lpad(h.sector , 2, 0) ||  lpad(h.zona,5,0)) unidad_lectura, ");
   strcat(sql, "h.coseno_phi/100 ");
   strcat(sql, "FROM hisfac h, hislec l1, hislec l2, medid m, sucur_centro_op sc ");
   strcat(sql, "WHERE h.numero_cliente = ? ");
   
   /*
   strcat(sql, "AND h.fecha_lectura BETWEEN ? AND ? ");
   strcat(sql, "AND h.fecha_lectura >= ? ");
   */
   strcat(sql, "AND h.tipo_docto IN ('01', '07') ");
   strcat(sql, "AND l1.numero_cliente = h.numero_cliente ");
   strcat(sql, "AND l1.corr_facturacion = h.corr_facturacion ");
   strcat(sql, "AND l1.tipo_lectura IN (1,2,3,4,7) ");
   strcat(sql, "AND l2.numero_cliente = h.numero_cliente ");
   strcat(sql, "AND l2.corr_facturacion = (SELECT MAX(l3.corr_facturacion) FROM hislec l3 ");
   strcat(sql, "	WHERE l3.numero_cliente = h.numero_cliente ");
   strcat(sql, " 	AND l3.corr_facturacion < h.corr_facturacion ");
   strcat(sql, "  AND l3.tipo_lectura IN (1,2,3,4,7)) ");
   strcat(sql, "AND l2.fecha_lectura >= ? ");
   strcat(sql, "AND m.numero_medidor = l1.numero_medidor ");
   strcat(sql, "AND m.marca_medidor = l1.marca_medidor ");
   strcat(sql, "AND sc.cod_centro_op = h.sucursal ");
   
   strcat(sql, "ORDER BY h.corr_facturacion ASC ");
   
   $PREPARE selFactura FROM $sql;

   $DECLARE curFactura CURSOR WITH HOLD FOR selFactura;

   /************ Consumos Activa Refacturados ************/
   strcpy(sql, "SELECT kwh_refacturados, kvar_refac_reac "); 
   strcat(sql, "FROM refac ");
   strcat(sql, "WHERE numero_cliente = ? ");
   strcat(sql, "AND nro_docto_afect = ? ");
   strcat(sql, "AND fecha_fact_afect = ? ");

   $PREPARE selRefac FROM $sql;

   $DECLARE curRefac CURSOR WITH HOLD FOR selRefac;
   
   /********** Ahorro_Hist ************/
   strcpy(sql, "SELECT a1.numero_cliente, ");
   strcat(sql, "a1.corr_fact_act, ");
   strcat(sql, "a1.fecha_lectura_act_2 + 1, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act_2 + 1, '%Y%m%d'), ");
   strcat(sql, "a1.fecha_lectura_act, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act, '%Y%m%d'), ");
   strcat(sql, "a1.consumo_61dias_act, ");
   strcat(sql, "a1.dias_per_act ");
   strcat(sql, "FROM ahorro_hist a1 ");
   strcat(sql, "WHERE a1.numero_cliente = ? ");
   strcat(sql, "ORDER BY corr_fact_act ASC ");
   
   $PREPARE selAhorro FROM $sql;

   $DECLARE curAhorro CURSOR WITH HOLD FOR selAhorro;

   /************* Primera Lectura *****************/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.tipo_lectura IN (1,2,3,4,7) ");   
   
   $PREPARE selPrimaLectura FROM $sql;

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
	strcat(sql, "'FACTSBIM', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT facts_bim, fecha_val_tarifa FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, facts_bim, gconsbimes, facdiaspc, qconbfpact ");
	strcat(sql, ")VALUES(?, 'S', ?, ?, ?) ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "facts_bim = 'S', ");
	strcat(sql, "gconsbimes = ?, ");
	strcat(sql, "facdiaspc = ?, ");
	strcat(sql, "qconbfpact = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ FechaLimiteInferior **************/
	/* strcpy(sql, "SELECT TODAY-365 FROM dual ");

	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
*/		
	$PREPARE selFechaLimInf FROM "SELECT fecha_pivote FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
	/*********** Correlativos Hacia Atras ***********/		
	strcpy(sql, "SELECT t.valor FROM tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'CORR' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
	
	$PREPARE selCorrelativos FROM $sql;
	
   /*************** Fecha Vig.Tarifa****************/
	strcpy(sql, "SELECT MIN(fecha_lectura) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_lectura > ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 7, 8) ");
   
   $PREPARE selVigTarifa FROM $sql;
	
   /********* Registra Corrida **********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'OPEBIM', ?, CURRENT, ?)";

   /******** Fecha Inicio busqueda *******/
   $PREPARE selFechaDesde FROM "SELECT fecha_limi_inf FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
   /******* Consumo Reactiva *******/
   $PREPARE selConsuReac FROM "SELECT h1.cons_reac + h2.cons_reac 
      FROM hisfac_adic h1, hisfac_adic h2
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h2.numero_cliente = h1.numero_cliente
      AND h2.corr_facturacion = h1.corr_facturacion-1 ";

   /******* Lectura Reactiva *******/
   $PREPARE selLectuReac FROM "SELECT lectu_factu_reac 
      FROM hislec_reac
      WHERE numero_cliente = ?
      AND corr_facturacion = ?
      AND tipo_lectura IN (1,2,3,4) ";   
   
   /******* Lectura Reactiva Ajustada *******/
   $PREPARE selLectuReacRefac FROM "SELECT h1.lectu_rectif_reac
      FROM hislec_refac_reac h1
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h1.corr_refacturacion = ( SELECT MAX(h2.corr_refacturacion)
      	FROM hislec_refac_reac h2
      	WHERE h2.numero_cliente = h1.numero_cliente
      	AND h2.corr_facturacion = h1.corr_facturacion ) ";
   
   /******* Ini Ventana Agenda 1 *******/
   $PREPARE selIniVentana1 FROM "SELECT MIN(inicio_ventana)+1 FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND ? BETWEEN inicio_ventana AND fin_ventana ";
	
   /******* Ini Ventana Agenda 2 *******/	
   $PREPARE selIniVentana2 FROM "SELECT MAX(inicio_ventana)+1 FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND inicio_ventana <= ? ";
   
   /******* Leyenda CosPhi *******/
   $PREPARE selLeyenda FROM "SELECT evento, fecha_evento
      FROM rer_eventos_cabe
      WHERE numero_cliente = ? ";
   
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
short LeoCliente(regCli)
$ClsCliente *regCli;
{

   InicializaCliente(regCli);

	$FETCH curClientes INTO
      :regCli->numero_cliente,
      :regCli->corr_facturacion,
      :regCli->tarifa; 

  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

	return 1;	
}

void InicializaCliente(regCli)
$ClsCliente *regCli;
{
	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regCli->corr_facturacion));
   memset(regCli->tarifa, '\0', sizeof(regCli->tarifa));
}

void getPrimaLectura(lNroCliente, lFechaLectura)
$long lNroCliente;
$long *lFechaLectura;
{
   $long lFechaAux;
   
   $EXECUTE selPrimaLectura INTO :lFechaAux
      USING :lNroCliente;
      
   if(SQLCODE != 0){
      printf("No se pudo cargar primera lectura para cliente %ld.\n", lNroCliente);
      return;
   }

   *lFechaLectura = lFechaAux;
}

short LeoFactura(reg)
$ClsFactura *reg;
{

   InicializaFactura(reg);
   
   $FETCH curFactura INTO
      :reg->numero_cliente, 
      :reg->corr_facturacion, 
      :reg->consumo_sum, 
      :reg->tarifa,
      :reg->indica_refact,
      :reg->fdesde, 
      :reg->fhasta,
      :reg->difdias,
      :reg->cons_61,
      :reg->fecha_facturacion,
      :reg->numero_factura,
      :reg->tipo_lectura,
      :reg->tipo_medidor,
      :reg->porcion,
      :reg->ul,
      :reg->cosenoPhi;

   if(SQLCODE != 0){
      return 0;
   }

   return 1;
}

void InicializaFactura(reg)
$ClsFactura    *reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum)); 
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->indica_refact, '\0', sizeof(reg->indica_refact));
   rsetnull(CLONGTYPE, (char *) &(reg->fdesde)); 
   rsetnull(CLONGTYPE, (char *) &(reg->fhasta));
   rsetnull(CINTTYPE, (char *) &(reg->difdias));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cons_61));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->numero_factura));
   rsetnull(CINTTYPE, (char *) &(reg->tipo_lectura));
   memset(reg->tipo_medidor, '\0', sizeof(reg->tipo_medidor));
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum_reactiva));
   memset(reg->porcion, '\0', sizeof(reg->porcion));
   memset(reg->ul, '\0', sizeof(reg->ul));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cosenoPhi));
   memset(reg->leyendaPhi, '\0', sizeof(reg->leyendaPhi));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaEvento));
   memset(reg->sFechaEvento, '\0', sizeof(reg->sFechaEvento));
   
}


short LeoAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{
   InicializaAhorro(regAhorro);
   
   $FETCH curAhorro INTO
      :regAhorro->numero_cliente,
      :regAhorro->corr_fact_act,
      :regAhorro->lFechaInicio,
      :regAhorro->sFechaInicio,
      :regAhorro->lFechaFin,
      :regAhorro->sFechaFin,
      :regAhorro->consumo_61dias_act,
      :regAhorro->dias_per_act;

   if(SQLCODE != 0){
      return 0;
   }

   return 1;
}

void InicializaAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{

   rsetnull(CLONGTYPE, (char *) &(regAhorro->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regAhorro->corr_fact_act));
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaInicio));
   memset(regAhorro->sFechaInicio, '\0', sizeof(regAhorro->sFechaInicio)); 
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaFin));
   memset(regAhorro->sFechaFin, '\0', sizeof(regAhorro->sFechaFin));
   rsetnull(CDOUBLETYPE, (char *) &(regAhorro->consumo_61dias_act));
   rsetnull(CINTTYPE, (char *) &(regAhorro->dias_per_act));

}

short LeoRefac(reg)
$ClsFactura *reg;
{
   $double  kwhRefac=0.00;
   $double  kwhRefacReac=0.00;
   
   $FETCH curRefac INTO :kwhRefac, :kwhRefacReac;
   
   if(SQLCODE != 0){
      return 0;
   }

   if(!risnull(CDOUBLETYPE, (char *) &kwhRefac))
      reg->consumo_sum += kwhRefac;
   
   if(!risnull(CDOUBLETYPE, (char *) &kwhRefacReac))
      reg->consumo_sum_reactiva += kwhRefacReac;
   
   reg->cons_61 = (reg->consumo_sum / reg->difdias) * 61;
   
   return 1;
}

void  TraspasoDatos(iMarca, regClie, lFechaAlta, regAhorro, regFact)
int            iMarca;
ClsCliente     regClie;
long           lFechaAlta;
ClsAhorroHist  regAhorro;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);

   rfmtdate(lFechaAlta, "yyyymmdd", sAux);

   regFact->numero_cliente = regAhorro.numero_cliente;
   if(iMarca == 1){
      regFact->corr_facturacion = regAhorro.corr_fact_act;
   }else{
      regFact->corr_facturacion = regAhorro.corr_fact_act + 1;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   if(iMarca == 1){
      strcpy(regFact->operand, "QCONSBIMES");
   }else{
      strcpy(regFact->operand, "FADIASPC");
   }
   
   /* AB */
   strcpy(regFact->ab, regAhorro.sFechaInicio);
   
   /* BIS2 */
   strcpy(regFact->bis2, regAhorro.sFechaFin);
   
   /* LMENGE */
   if(iMarca == 1){
      sprintf(regFact->lmenge, "%.0lf", regAhorro.consumo_61dias_act);
   }else if(iMarca==2){
      sprintf(regFact->lmenge, "%ld", regAhorro.dias_per_act);
   }
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}


void  TraspasoDatosFactu(iMarca, regClie, regFactu, regFact)
int            iMarca;
ClsCliente     regClie;
ClsFactura  regFactu;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);


   regFact->numero_cliente = regFactu.numero_cliente;
   if(iMarca == 2){
      regFact->corr_facturacion = regFactu.corr_facturacion + 1;
   }else{
      regFact->corr_facturacion = regFactu.corr_facturacion;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   switch(iMarca){
      case 1:
         strcpy(regFact->operand, "QCONSBIMES");
         break;
      case 2:
         strcpy(regFact->operand, "FADIASPC");
         break;
      case 3:
         strcpy(regFact->operand, "QCONBFPACT");
         break;
      case 4:
         strcpy(regFact->operand, "QCONBFPREAC");
         break;
      case 5:
         strcpy(regFact->operand, "QCONTADOR");
         break;
   }
   
   /* AB */
   if(iMarca==5){
      strcpy(regFact->ab, regFactu.sFechaEvento);
   }else{
      rfmtdate(regFactu.fdesde, "yyyymmdd", regFact->ab);
   }
   
   /* BIS2 */
   if(iMarca==5){
      strcpy(regFact->bis2, "99991231");
   }else{
      rfmtdate(regFactu.fhasta, "yyyymmdd", regFact->bis2);
   }
   
      
   /* LMENGE */
   switch(iMarca){
      case 1:
         sprintf(regFact->lmenge, "%.0lf", regFactu.cons_61);
         break;
      case 2:
         sprintf(regFact->lmenge, "%ld", regFactu.difdias);
         break;
      case 3:
         if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
            strcpy(regFact->lmenge, "0");
         }else{
            sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum);
         }
         break;
      case 4:
         if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
            strcpy(regFact->lmenge, "0");
         }else{
            sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum_reactiva);
         }
         break;
      case 5:
         alltrim(regFactu.leyendaPhi, ' ');
         sprintf(regFact->lmenge, "%s", regFactu.leyendaPhi);
         break;
   }
   
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}



void InicializaOperandos(regFact)
ClsFacts *regFact;
{

   memset(regFact->anlage, '\0', sizeof(regFact->anlage));
   memset(regFact->bis1, '\0', sizeof(regFact->bis1));
   memset(regFact->auto_inser, '\0', sizeof(regFact->auto_inser));
   memset(regFact->operand, '\0', sizeof(regFact->operand));
   memset(regFact->ab, '\0', sizeof(regFact->ab));
   memset(regFact->bis2, '\0', sizeof(regFact->bis2));
   memset(regFact->lmenge, '\0', sizeof(regFact->lmenge));
   memset(regFact->tarifart, '\0', sizeof(regFact->tarifart));
   memset(regFact->kondigr, '\0', sizeof(regFact->kondigr));

}

short ClienteYaMigrado(nroCliente, lFechaInicio, iFlagMigra)
$long	nroCliente;
$long *lFechaInicio;
int		*iFlagMigra;
{
   $long lFecha;
	$char	sMarca[2];
/*	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}
*/	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca, :lFecha using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("Error al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
      if(gsTipoGenera[0]=='G'){	
		    /*return 1;*/
      }
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
   *lFechaInicio = lFecha;

	return 0;
}


void GenerarPlanos(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
   
   GeneraKey(fpSalida, iMarca, regFact);
   
   GeneraCuerpo(fpSalida, iMarca, regFact);
   
   GeneraPie(fpSalida, iMarca, regFact);
   
   GeneraENDE(fpSalida, iMarca, regFact);

}

void GeneraKey(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   char  sMarca[3];
   int   iRcv;
       
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));

   switch(iMarca){
      case 1:
      case 3:
      case 4:
      case 5:
         strcpy(sMarca, "QC");
         break;
      case 2:
         strcpy(sMarca, "FP");
         break;
   }

   /* llave */
   sprintf(sLinea, "T1%ld-%ld%s\tKEY\t", regFact.numero_cliente, regFact.corr_facturacion, sMarca);
   
   /* ANLAGE */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.anlage);

   /* BIS1 */
   sprintf(sLinea, "%s%s", sLinea, regFact.bis1);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KEY\n");
      exit(1);
   }	


}

void GeneraCuerpo(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
      case 1:
      case 3:
      case 4:
      case 5:
         sprintf(sLinea, "T1%ld-%ldQC\tF_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);
         break;
      case 2:
         sprintf(sLinea, "T1%ld-%ldFP\tF_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);
         break;
   }

   /* OPERAND */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.operand);

   /* AUTO_INSER */
   sprintf(sLinea, "%s%s", sLinea, regFact.auto_inser);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir Cuerpo\n");
      exit(1);
   }	

}

void GeneraPie(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
      case 1:
      case 3:
      case 4:
      case 5:
         sprintf(sLinea, "T1%ld-%ldQC\tV_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);
         break;
      case 2:
         sprintf(sLinea, "T1%ld-%ldFP\tV_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);
         break;
   }
   
   /* AB */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.ab);
   
   /* BIS2 */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.bis2);
   
   /* LMENGE */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.lmenge);
   
   /* TARIFART */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.tarifart);
   
   /* KONDIGR */
   sprintf(sLinea, "%s%s", sLinea, regFact.kondigr);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir Pie\n");
      exit(1);
   }	

}


void GeneraENDE(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   char  sMarca[3];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));
   
   switch(iMarca){
      case 1:
      case 3:
      case 4:
      case 5:
         strcpy(sMarca, "QC");
         break;
      case 2:
         strcpy(sMarca, "FP");
         break;
   }
	
   sprintf(sLinea, "T1%ld-%ld%s\t&ENDE", regFact.numero_cliente, regFact.corr_facturacion, sMarca);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fpSalida, sLinea);
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
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "FACTSBIM");
		strcpy(sNombreArchivo, sArchQConsBimesUnx);
      
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
short RegistraCliente(nroCliente, cantConsu, cantActi, iFlagMigra)
$long	nroCliente;
$long  cantConsu;
$long  cantActi;
int		iFlagMigra;
{
	
	if(iFlagMigra==1){
		$EXECUTE insClientesMigra using :nroCliente, :cantConsu, :cantConsu, :cantActi;
	}else{
		$EXECUTE updClientesMigra using :cantConsu, :cantConsu, :cantActi, :nroCliente;
	}

	return 1;
}

short getConsuReactiva(reg)
$ClsFactura *reg;
{

   $EXECUTE selConsuReac INTO :reg->consumo_sum_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;
      
   if(SQLCODE != 0){
      return 0;
   }
   return 1;
}

short getLectuReactiva(reg)
$ClsFactura *reg;
{

   $EXECUTE selLectuReac INTO :reg->lectura_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;

   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

short getLectuReactivaRefac(reg)
$ClsFactura *reg;
{

   $EXECUTE selLectuReacRefac INTO :reg->lectura_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;

   if(SQLCODE != 0){
      $EXECUTE selLectuReac INTO :reg->lectura_reactiva
         USING :reg->numero_cliente,
               :reg->corr_facturacion;
               
      if(SQLCODE != 0){
         return 0;
      }
   }

   return 1;
}

short getIniVentanaAgenda(reg)
$ClsFactura *reg;
{
   $long lFecha;
   
   rsetnull(CLONGTYPE, (char *) &(lFecha));
   
   $EXECUTE selIniVentana1 INTO :lFecha
      USING :reg->porcion,
            :reg->ul,
            :reg->fdesde;
            
   if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
      $EXECUTE selIniVentana2 INTO :lFecha
         USING :reg->porcion,
               :reg->ul,
               :reg->fdesde;
   
      if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
         return 0;
      }
   }            

   reg->fdesde = lFecha;
   
   return 1;
}

short getLeyenda(reg, lValTarifa)
$ClsFactura *reg;
$long       lValTarifa;
{

   $EXECUTE selLeyenda INTO :reg->leyendaPhi,
                            :reg->lFechaEvento;
                            
   if(SQLCODE != 0){
      return 0;
   }

   if(reg->lFechaEvento < lValTarifa)
      reg->lFechaEvento = lValTarifa;
      
   rfmtdate(reg->lFechaEvento, "yyyymmdd", reg->sFechaEvento); /* long to char */   

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

