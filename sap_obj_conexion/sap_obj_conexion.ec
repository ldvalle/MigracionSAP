/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_partner
    
	Fecha : 07/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructuras OBJETO CONEXION, PUNTO SUMINISTRO y
				UBICACION DE APARATOS.
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Archivos a Generar>: 0=Todos; 1=Objeto Conexion; 2=Punto Suministro; 3=Ubicacion Aparatos
		
		<Estado Cliente>: 0 = Activo; 1 = No Activo; 2 = Todos
					
		<Tipo Generacion>: G = Generacion; R = Regeneracion
					   
		<Nro Cliente>: Opcional. Si se carga el valor, se extrae SOLO para el cliente en cuestion

*********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_obj_conexion.h";

/* Variables Globales */
$int	giArchivosGen;
$int	giEstadoCliente;
$long	glNroCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileConexActivoUnx;
FILE	*pFileConexNoActivoUnx;
FILE	*pFilePtoSumActivoUnx;
FILE	*pFilePtoSumNoActivoUnx;
FILE	*pFileUbicApaActivoUnx;
FILE	*pFileUbicApaNoActivoUnx;

char	sArchConexActivoUnx[100];
char	sArchConexNoActivoUnx[100];
char	sArchPtoSumActivoUnx[100];
char	sArchPtoSumNoActivoUnx[100];
char	sArchUbicApaActivoUnx[100];
char	sArchUbicApaNoActivoUnx[100];

char	sArchConexActivoDos[100];
char	sArchConexNoActivoDos[100];
char	sArchPtoSumActivoDos[100];
char	sArchPtoSumNoActivoDos[100];
char	sArchUbicApaActivoDos[100];
char	sArchUbicApaNoActivoDos[100];

char	sSoloArchivoConexActivo[100];
char	sSoloArchivoConexNoActivo[100];
char	sSoloArchivoPtoSumActivo[100];
char	sSoloArchivoPtoSumNoActivo[100];
char	sSoloArchivoUbicApaActivo[100];
char	sSoloArchivoUbicApaNoActivo[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativoConex;
long	lCorrelativoPtoSum;
long	lCorrelativoUbicApa;

long	cantProcesadaConexActivo;
long	cantProcesadaConexNoActivo;
long	cantProcesadaPtoSumActivo;
long	cantProcesadaPtoSumNoActivo;
long	cantProcesadaUbicApaActivo;
long	cantProcesadaUbicApaNoActivo;

long 	cantPreexistenteConex;
long 	cantPreexistentePtoSum;
long 	cantPreexistenteUbicApa;


/* Variables Globales Host */
$ClsCliente	regCliente;

char	sMensMail[1024];	/*jhuck ME089 */

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fpConex;
FILE	*fpPunto;
FILE    *fpUbic;

$ClsCliente	  regCliente;
int		iFlagMigra;

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

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesadaConexActivo=0;
	cantProcesadaConexNoActivo=0;
	cantProcesadaPtoSumActivo=0;
	cantProcesadaPtoSumNoActivo=0;
	cantProcesadaUbicApaActivo=0;
	cantProcesadaUbicApaNoActivo=0;

	cantPreexistenteConex=0;
	cantPreexistentePtoSum=0;
	cantPreexistenteUbicApa=0;
	
	if(glNroCliente > 0 ){
    	$OPEN curClientes using :glNroCliente;
    }else{
		$OPEN curClientes;
	}

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
	while(LeoClientes(&regCliente)){
		
		if(giArchivosGen==0 || giArchivosGen==1){

			/* Hago el de Objeto de Conexion */
			
			if(regCliente.estado_cliente[0]=='0'){
				fpConex=pFileConexActivoUnx;
			}else{
				fpConex=pFileConexNoActivoUnx;
			}
			iFlagMigra=0;
			if(! ClienteYaMigrado("OBJCONEX", regCliente.numero_cliente, &iFlagMigra)){

				if (!GenerarPlanoObjConex(fpConex, regCliente)){
					printf("Falló generacion OBJ para cliente %ld\n", regCliente.numero_cliente);
					exit(1);	
				}

				if(regCliente.estado_cliente[0]=='0'){
					cantProcesadaConexActivo++;
				}else{
					cantProcesadaConexNoActivo++;			
				}
/*
				if(gsTipoGenera[0]!='R'){
               $BEGIN WORK;
					if(!RegistraCliente("OBJCONEX", regCliente.numero_cliente, iFlagMigra)){
						$ROLLBACK WORK;
						exit(1);					
					}
               $COMMIT WORK;
				}
*/            
				
			}else{
				cantPreexistenteConex++;
			}
			
		}

		if(giArchivosGen==0 || giArchivosGen==2){

			/* Hago el de punto Suministro */
			if(regCliente.estado_cliente[0]=='0'){
				fpPunto=pFilePtoSumActivoUnx;
			}else{
				fpPunto=pFilePtoSumNoActivoUnx;
			}
			iFlagMigra=0;
			if(! ClienteYaMigrado("PUNTOSUM", regCliente.numero_cliente, &iFlagMigra)){

				if (!GenerarPlanoPtoSumin(fpPunto, regCliente)){
					printf("Falló generacion PUNTO SUM para cliente %ld\n", regCliente.numero_cliente);
					exit(1);	
				}

				if(regCliente.estado_cliente[0]=='0'){
					cantProcesadaPtoSumActivo++;
				}else{
					cantProcesadaPtoSumNoActivo++;			
				}
/*            
            $BEGIN WORK;
				if(!RegistraCliente("PUNTOSUM", regCliente.numero_cliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);					
				}
            $COMMIT WORK;
*/            				
			}else{
				cantPreexistentePtoSum++;
			}						
		}
		
		if(giArchivosGen==0 || giArchivosGen==3){

			/* Hago el de Ubicacion Aparatos */
			if(regCliente.estado_cliente[0]=='0'){
				fpUbic=pFileUbicApaActivoUnx;
			}else{
				fpUbic=pFileUbicApaNoActivoUnx;
			}
			iFlagMigra=0;
			if(! ClienteYaMigrado("UBICAPA", regCliente.numero_cliente, &iFlagMigra)){

				if (!GenerarPlanoUbicApa(fpUbic, regCliente)){
					printf("Falló generacion UBICA APA para cliente %ld\n", regCliente.numero_cliente);
					exit(1);	
				}

				if(regCliente.estado_cliente[0]=='0'){
					cantProcesadaUbicApaActivo++;
				}else{
					cantProcesadaUbicApaNoActivo++;			
				}
/*
            $BEGIN WORK;
				if(!RegistraCliente("UBICAPA", regCliente.numero_cliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);					
				}
            $COMMIT WORK;
*/            				
			}else{
				cantPreexistenteUbicApa++;
			}						
		}		
			
	}/* Fin While */

	$CLOSE curClientes;
	
	CerrarArchivos();
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
	printf("OBJETO DE CONEXION.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Objeto Conexión Activos :         %ld \n",cantProcesadaConexActivo);
	printf("Clientes Objeto Conexión No Activos :      %ld \n",cantProcesadaConexNoActivo);
	printf("Clientes Objeto Conexión Preexistentes:    %ld \n",cantPreexistenteConex);
	printf("Clientes Punto Suministro Activos :        %ld \n",cantProcesadaPtoSumActivo);
	printf("Clientes Punto Suministro No Activos :     %ld \n",cantProcesadaPtoSumNoActivo);
	printf("Clientes Punto Suministro Preexistentes:   %ld \n",cantPreexistentePtoSum);	
	printf("Clientes Ubicación Aparatos Activos :      %ld \n",cantProcesadaUbicApaActivo);
	printf("Clientes Ubicación Aparatos No Activos :   %ld \n",cantProcesadaUbicApaNoActivo);
	printf("Clientes Ubicación Aparatos Preexistentes: %ld \n",cantPreexistenteUbicApa);	
	
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

	if(argc > 7 || argc < 6){
		MensajeParametros();
		return 0;
	}
	
	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0 && strcmp(argv[2], "3")!=0){
		MensajeParametros();
		return 0;	
	}

	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));
	
	giArchivosGen=atoi(argv[2]);
	giEstadoCliente=atoi(argv[3]);
	strcpy(gsTipoGenera, argv[4]);
	giTipoCorrida=atoi(argv[5]);
   
	if(argc == 7){	
		glNroCliente=atol(argv[6]);
	}else{
		glNroCliente=-1;	
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("    <Base> = synergia.\n");
		printf("    <Archivos Generados> 0=Todos; 1=Obj.Conex; 2=Pto.Suministro; 3=Ubic.Aparatos.\n");
		printf("    <Estado Cliente> = 0 Activo - 1 No Activo 2 - Todos.\n");
		printf("    <Tipo Generación> G = Generación, R = Regeneración.\n");
		printf("    <Nro.Cliente> Opcional.\n");
}

short AbreArchivos()
{
	
	memset(sArchConexActivoUnx,'\0',sizeof(sArchConexActivoUnx));
	memset(sArchConexNoActivoUnx,'\0',sizeof(sArchConexNoActivoUnx));
	memset(sArchPtoSumActivoUnx,'\0',sizeof(sArchPtoSumActivoUnx));
	memset(sArchPtoSumNoActivoUnx,'\0',sizeof(sArchPtoSumNoActivoUnx));
	memset(sArchUbicApaActivoUnx,'\0',sizeof(sArchUbicApaActivoUnx));
	memset(sArchUbicApaNoActivoUnx,'\0',sizeof(sArchUbicApaNoActivoUnx));

	memset(sArchConexActivoDos,'\0',sizeof(sArchConexActivoDos));
	memset(sArchConexNoActivoDos,'\0',sizeof(sArchConexNoActivoDos));
	memset(sArchPtoSumActivoDos,'\0',sizeof(sArchPtoSumActivoDos));
	memset(sArchPtoSumNoActivoDos,'\0',sizeof(sArchPtoSumNoActivoDos));
	memset(sArchUbicApaActivoDos,'\0',sizeof(sArchUbicApaActivoDos));
	memset(sArchUbicApaNoActivoDos,'\0',sizeof(sArchUbicApaNoActivoDos));

	memset(sSoloArchivoConexActivo,'\0',sizeof(sSoloArchivoConexActivo));
	memset(sSoloArchivoConexNoActivo,'\0',sizeof(sSoloArchivoConexNoActivo));
	memset(sSoloArchivoPtoSumActivo,'\0',sizeof(sSoloArchivoPtoSumActivo));
	memset(sSoloArchivoPtoSumNoActivo,'\0',sizeof(sSoloArchivoPtoSumNoActivo));
	memset(sSoloArchivoUbicApaActivo,'\0',sizeof(sSoloArchivoUbicApaActivo));
	memset(sSoloArchivoUbicApaNoActivo,'\0',sizeof(sSoloArchivoUbicApaNoActivo));
		
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
   alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
   alltrim(sPathCopia,' ');
   
/*	
	lCorrelativoConex = getCorrelativo("OBJCONEX");
	lCorrelativoPtoSum = getCorrelativo("PUNTOSUM");
	lCorrelativoUbicApa = getCorrelativo("UBICAPA");
*/	
	
	
	switch(giArchivosGen){
		case 0:	/* Objeto Conexion, Punto Suministro y Ubicacion Aparatos */
			sprintf( sArchConexActivoUnx  , "%sT1CONNOBJ_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoConexActivo, "T1CONNOBJ_Activo.unx");
			sprintf( sArchConexNoActivoUnx  , "%sT1CONNOBJ_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoConexNoActivo, "T1CONNOBJ_Inactivo.unx");
			
			sprintf( sArchPtoSumActivoUnx  , "%sT1PREMISE_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoPtoSumActivo, "T1PREMISE_Activo.unx");
			sprintf( sArchPtoSumNoActivoUnx  , "%sT1PREMISE_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoPtoSumNoActivo, "T1PREMISE_Inactivo.unx");

			sprintf( sArchUbicApaActivoUnx  , "%sT1DEVLOC_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoUbicApaActivo, "T1DEVLOC_Activo.unx");
			sprintf( sArchUbicApaNoActivoUnx  , "%sT1DEVLOC_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoUbicApaNoActivo, "T1DEVLOC_Inactivo.unx");

			pFileConexActivoUnx=fopen( sArchConexActivoUnx, "w" );
			if( !pFileConexActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchConexActivoUnx );
				return 0;
			}			
			
			pFileConexNoActivoUnx=fopen( sArchConexNoActivoUnx, "w" );
			if( !pFileConexNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchConexNoActivoUnx );
				return 0;
			}			
			
			pFilePtoSumActivoUnx=fopen( sArchPtoSumActivoUnx, "w" );
			if( !pFilePtoSumActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPtoSumActivoUnx );
				return 0;
			}			
			
			pFilePtoSumNoActivoUnx=fopen( sArchPtoSumNoActivoUnx, "w" );
			if( !pFilePtoSumNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPtoSumNoActivoUnx );
				return 0;
			}
			
			pFileUbicApaActivoUnx=fopen( sArchUbicApaActivoUnx, "w" );
			if( !pFileUbicApaActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchUbicApaActivoUnx );
				return 0;
			}			
			
			pFileUbicApaNoActivoUnx=fopen( sArchUbicApaNoActivoUnx, "w" );
			if( !pFileUbicApaNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchUbicApaNoActivoUnx );
				return 0;
			}			
			
			break;
											
		case 1: /* Solo Objeto Conexion */
			sprintf( sArchConexActivoUnx  , "%sT1CONNOBJ_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoConexActivo, "T1CONNOBJ_Activo.unx");
			sprintf( sArchConexNoActivoUnx  , "%sT1CONNOBJ_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoConexNoActivo, "T1CONNOBJ_Inactivo.unx");

			pFileConexActivoUnx=fopen( sArchConexActivoUnx, "w" );
			if( !pFileConexActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchConexActivoUnx );
				return 0;
			}			
			
			pFileConexNoActivoUnx=fopen( sArchConexNoActivoUnx, "w" );
			if( !pFileConexNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchConexNoActivoUnx );
				return 0;
			}
			break;
						
		case 2:	/* Solo Punto Suministro */
			sprintf( sArchPtoSumActivoUnx  , "%sT1PREMISE_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoPtoSumActivo, "T1PREMISE_Activo.unx");
			sprintf( sArchPtoSumNoActivoUnx  , "%sT1PREMISE_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoPtoSumNoActivo, "T1PREMISE_Inactivo.unx");
						
			pFilePtoSumActivoUnx=fopen( sArchPtoSumActivoUnx, "w" );
			if( !pFilePtoSumActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPtoSumActivoUnx );
				return 0;
			}			
			
			pFilePtoSumNoActivoUnx=fopen( sArchPtoSumNoActivoUnx, "w" );
			if( !pFilePtoSumNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPtoSumNoActivoUnx );
				return 0;
			}			
			break;
			
		case 3: /* Solo Ubicacion de Aparatos */
			sprintf( sArchUbicApaActivoUnx  , "%sT1DEVLOC_Activo.unx", sPathSalida);
			strcpy( sSoloArchivoUbicApaActivo, "T1DEVLOC_Activo.unx");
			sprintf( sArchUbicApaNoActivoUnx  , "%sT1DEVLOC_Inactivo.unx", sPathSalida);
			strcpy( sSoloArchivoUbicApaNoActivo, "T1DEVLOC_Inactivo.unx");
			
			pFileUbicApaActivoUnx=fopen( sArchUbicApaActivoUnx, "w" );
			if( !pFileUbicApaActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchUbicApaActivoUnx );
				return 0;
			}			
			
			pFileUbicApaNoActivoUnx=fopen( sArchUbicApaNoActivoUnx, "w" );
			if( !pFileUbicApaNoActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchUbicApaNoActivoUnx );
				return 0;
			}			
			
			break;						
	}
	
	return 1;	
}

void CerrarArchivos(void)
{
	switch(giArchivosGen){
		case 0:	/* Objeto Conexion y Punto Suministro */
			fclose(pFileConexActivoUnx);
			fclose(pFileConexNoActivoUnx);
			fclose(pFilePtoSumActivoUnx);
			fclose(pFilePtoSumNoActivoUnx);
			fclose(pFileUbicApaActivoUnx);
			fclose(pFileUbicApaNoActivoUnx);			
			break;
		case 1:
			fclose(pFileConexActivoUnx);
			fclose(pFileConexNoActivoUnx);
			break;
		case 2:
			fclose(pFilePtoSumActivoUnx);
			fclose(pFilePtoSumNoActivoUnx);
			break;
		case 3:
			fclose(pFileUbicApaActivoUnx);
			fclose(pFileUbicApaNoActivoUnx);
			break;			
	}	
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
	

	if(cantProcesadaConexActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchConexActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchConexActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}

	if(cantProcesadaConexNoActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchConexNoActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchConexNoActivoUnx, sPathCp);
		iRcv=system(sCommand);
      		
	}

	if(cantProcesadaPtoSumActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchPtoSumActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchPtoSumActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}

	if(cantProcesadaPtoSumNoActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchPtoSumNoActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchPtoSumNoActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}

	if(cantProcesadaUbicApaActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchUbicApaActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchUbicApaActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}

	if(cantProcesadaUbicApaNoActivo>0){
		sprintf(sCommand, "chmod 775 %s", sArchUbicApaNoActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchUbicApaNoActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}

/*
	sprintf(sCommand, "rm -f %s", sArchConexActivoUnx);
	iRcv=system(sCommand);	
	sprintf(sCommand, "rm -f %s", sArchConexNoActivoUnx);
	iRcv=system(sCommand);		
	sprintf(sCommand, "rm -f %s", sArchPtoSumActivoUnx);
	iRcv=system(sCommand);	
	sprintf(sCommand, "rm -f %s", sArchPtoSumNoActivoUnx);
	iRcv=system(sCommand);	
	sprintf(sCommand, "rm -f %s", sArchUbicApaActivoUnx);
	iRcv=system(sCommand);	
	sprintf(sCommand, "rm -f %s", sArchUbicApaNoActivoUnx);
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
	
	/******** Cursor Clientes  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "UPPER(c.nombre[1,40]), ");
	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "c.actividad_economic, ");

	strcat(sql, "DECODE (c.tipo_sum,'6', ' ', c.cod_calle), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', UPPER(TRIM(p.dp_nom_calle)), UPPER(TRIM(c.nom_calle))), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', TRIM(p.dp_nro_dir), TRIM(c.nro_dir)), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', TRIM(p.dp_piso_dir), TRIM(c.piso_dir)), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', TRIM(p.dp_depto_dir), TRIM(c.depto_dir)), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', UPPER(TRIM(p.dp_nom_entre)), UPPER(TRIM(c.nom_entre))), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', UPPER(TRIM(p.dp_nom_entre1)), UPPER(TRIM(c.nom_entre1))), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', sp2.cod_sap, sp1.cod_sap) provincia, ");
	strcat(sql, "DECODE (c.tipo_sum,'6', ' ', sp.cod_sap) partido, ");
	strcat(sql, "DECODE (c.tipo_sum,'6', UPPER(TRIM(p.dp_nom_partido)), UPPER(TRIM(c.nom_partido))), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', ' ', c.comuna), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', UPPER(TRIM(p.dp_nom_localidad)), UPPER(TRIM(c.nom_comuna))), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', p.dp_cod_postal, c.cod_postal), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', ' ', TRIM(c.obs_dir[1,40])), ");
	strcat(sql, "DECODE (c.tipo_sum,'6', p.dp_telefono, c.telefono), ");

	strcat(sql, "c.rut, ");
	strcat(sql, "c.tip_doc, ");
	strcat(sql, "TRUNC(c.nro_doc,0), ");
	strcat(sql, "c.tipo_fpago, ");
	strcat(sql, "c.minist_repart, ");
	strcat(sql, "c.estado_cliente, ");
	strcat(sql, "c.tipo_sum, ");
	strcat(sql, "co.cod_sap, "); /* Sucursal SAP */
	strcat(sql, "c.info_adic_lectura, ");
	strcat(sql, "c.obs_dir[1,40] ");
	strcat(sql, "FROM cliente c, sap_transforma co, sap_transforma sp, sap_transforma sp1, OUTER (postal p, sap_transforma sp2 ) ");

   if(giTipoCorrida==1)
      strcat(sql, ", migra_activos ma ");
	
if(giEstadoCliente!=0){
	strcat(sql, ", sap_inactivos si ");
}

	if(glNroCliente > 0){
		strcat(sql, "WHERE c.numero_cliente = ? ");	
		strcat(sql, "AND c.tipo_sum != 5 ");
	}else{
		strcat(sql, "WHERE c.tipo_sum != 5 ");
	}
	if(giEstadoCliente==0){
		strcat(sql, "AND c.estado_cliente = 0 ");	
	}else if(giEstadoCliente==1){
		strcat(sql, "AND c.estado_cliente != 0 ");
	}
	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}

	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
		
	strcat(sql, "AND co.clave = 'CENTROEMPLA' ");
	strcat(sql, "AND co.cod_mac = c.sucursal ");
	strcat(sql, "AND p.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND sp.clave = 'CONDADO' ");
	strcat(sql, "AND sp.cod_mac = c.partido ");
	strcat(sql, "AND sp1.clave = 'REGION' ");
	strcat(sql, "AND sp1.cod_mac = c.provincia ");
	strcat(sql, "AND sp2.clave = 'REGION' ");
	strcat(sql, "AND sp2.cod_mac = p.dp_provincia ");

   if(giTipoCorrida==1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD for selClientes;		
	
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/********* Select Cliente OBJETO CONEXION ya migrado **********/
	strcpy(sql, "SELECT obj_conexion FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");	
	
	$PREPARE selClienteObjConexMigrado FROM $sql;
	
	/********* Select Cliente PUNTO SUMINISTRO ya migrado **********/
	strcpy(sql, "SELECT pto_suministro FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClientePtoSumMigrado FROM $sql;	
	
	/********* Select Cliente Ubic.Aparatos ya migrado **********/
	strcpy(sql, "SELECT ubica_apa FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteUbicApaMigrado FROM $sql;		

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
	strcat(sql, "?, ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenArchivo FROM $sql;*/

	/*********Insert Clientes extraidos OBJ CONEXION **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, obj_conexion ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClteMigraConex FROM $sql;

	/************ Update Clientes extraidos OBJ CONEXION **********/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "obj_conexion = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClteMigraConex FROM $sql;
	
	/*********Insert Clientes extraidos PUNTO SUMINISTRO **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, pto_suministro ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insCltePtosSum FROM $sql;

	/************ Update Clientes extraidos PUNTO SUMINISTRO **********/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "pto_suministro = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updCltePtosSum FROM $sql;
	
	
	/*********Insert Clientes extraidos UBIC.APARATOS **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, ubica_apa ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClteUbicApa FROM $sql;

	/************ Update Clientes extraidos UBIC.APARATOS **********/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "ubica_apa = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClteUbicApa FROM $sql;	
	
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
short LeoClientes(regCli)
$ClsCliente *regCli;
{
	InicializaCliente(regCli);
	
	$FETCH curClientes into
		:regCli->numero_cliente,
		:regCli->nombre,
		:regCli->tipo_cliente,
		:regCli->actividad_economic,
		:regCli->cod_calle,
		:regCli->nom_calle,
		:regCli->nro_dir,
		:regCli->piso_dir,
		:regCli->depto_dir,
		:regCli->nom_entre,
		:regCli->nom_entre1,
		:regCli->provincia,
		:regCli->partido,
		:regCli->nom_partido,
		:regCli->comuna,
		:regCli->nom_comuna,
		:regCli->cod_postal,
		:regCli->obs_dir,
		:regCli->telefono,
		:regCli->rut,
		:regCli->tip_doc,
		:regCli->nro_doc,
		:regCli->tipo_fpago,
		:regCli->minist_repart,
		:regCli->estado_cliente,
		:regCli->tipo_sum,
		:regCli->sucursal,
		:regCli->info_adic_lectura,
		:regCli->descrip_info_adic;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Clientes !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
    
    
/****/
	if(strcmp(regCli->provincia, "00")==0){
		if(regCli->cod_postal > 1499 || regCli->cod_postal < 1000 || risnull(CINTTYPE, (char *) &(regCli->cod_postal))){
			regCli->cod_postal = 1076;
		}
	}else{
		if(regCli->cod_postal <= 1499 || risnull(CINTTYPE, (char *) &(regCli->cod_postal))){
			regCli->cod_postal = 1876;
		}
	}
/***/    
    
	if(risnull(CFLOATTYPE,(char *) &(regCli->nro_doc))){
		regCli->nro_doc=0;	
	}
	alltrim(regCli->telefono, ' ');
		
	alltrim(regCli->nombre, ' ');
	alltrim(regCli->obs_dir, ' ');
	alltrim(regCli->info_adic_lectura, ' ');
	
	/* Reemp Comillas */

	strcpy(regCli->nombre, strReplace(regCli->nombre, "'", " "));
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "'", " "));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "'", " "));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "'", " "));
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "'", " "));
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "'", " "));
	strcpy(regCli->info_adic_lectura, strReplace(regCli->info_adic_lectura, "'", " "));

	return 1;	
}

void InicializaCliente(regCli)
$ClsCliente	*regCli;
{

	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
	memset(regCli->nombre, '\0', sizeof(regCli->nombre));
	memset(regCli->tipo_cliente, '\0', sizeof(regCli->tipo_cliente));
	memset(regCli->actividad_economic, '\0', sizeof(regCli->actividad_economic));
	memset(regCli->cod_calle, '\0', sizeof(regCli->cod_calle));
	memset(regCli->nom_calle, '\0', sizeof(regCli->nom_calle));
	memset(regCli->nro_dir, '\0', sizeof(regCli->nro_dir));
	memset(regCli->piso_dir, '\0', sizeof(regCli->piso_dir));
	memset(regCli->depto_dir, '\0', sizeof(regCli->depto_dir));
	memset(regCli->nom_entre, '\0', sizeof(regCli->nom_entre));
	memset(regCli->nom_entre1, '\0', sizeof(regCli->nom_entre1));
	memset(regCli->provincia, '\0', sizeof(regCli->provincia));
	memset(regCli->partido, '\0', sizeof(regCli->partido));
	memset(regCli->nom_partido, '\0', sizeof(regCli->nom_partido));
	memset(regCli->comuna, '\0', sizeof(regCli->comuna));
	memset(regCli->nom_comuna, '\0', sizeof(regCli->nom_comuna));
	rsetnull(CINTTYPE, (char *) &(regCli->cod_postal));
	memset(regCli->obs_dir, '\0', sizeof(regCli->obs_dir));
	memset(regCli->telefono, '\0', sizeof(regCli->telefono));
	memset(regCli->rut, '\0', sizeof(regCli->rut));
	memset(regCli->tip_doc, '\0', sizeof(regCli->tip_doc));
	rsetnull(CFLOATTYPE, (char *) &(regCli->nro_doc));
	memset(regCli->tipo_fpago, '\0', sizeof(regCli->tipo_fpago));
	rsetnull(CLONGTYPE, (char *) &(regCli->minist_repart));
	memset(regCli->tipo_sum, '\0', sizeof(regCli->tipo_sum));
	memset(regCli->sucursal, '\0', sizeof(regCli->sucursal));
	memset(regCli->info_adic_lectura, '\0', sizeof(regCli->info_adic_lectura));
	memset(regCli->descrip_info_adic, '\0', sizeof(regCli->descrip_info_adic));
	
}


short GenerarPlanoObjConex(fp, regCliente)
FILE 			*fp;
$ClsCliente		regCliente;
{

	/* CO_EHA */	
	GeneraCO_EHA(fp, regCliente);
	
	/* CO_ADR */
	GeneraCO_ADR(fp, regCliente);
	
	/* ENDE */
	GeneraENDE(fp, regCliente);
	
	return 1;
}

short GenerarPlanoPtoSumin(fp, regCliente)
FILE 			*fp;
$ClsCliente		regCliente;
{
	
	/* EVBSD */
	GeneraEVBSD(fp, regCliente);
	
	/* ENDE */
	GeneraENDE(fp, regCliente);
	
	return 1;
}

short GenerarPlanoUbicApa(fp, regCliente)
FILE 			*fp;
$ClsCliente		regCliente;
{
	
	/* EVBSD */
	GeneraEGPLD(fp, regCliente);
	
	/* ENDE */
	GeneraENDE(fp, regCliente);
	
	return 1;
}

void GeneraENDE(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regCliente.numero_cliente);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}


short ClienteYaMigrado(sTipoObjeto, nroCliente, iFlagMigra)
char	sTipoObjeto[11];
$long	nroCliente;
int		*iFlagMigra;
{
	$char	sMarca[2];
	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}

	memset(sMarca, '\0', sizeof(sMarca));
		
	if(strcmp(sTipoObjeto, "OBJCONEX")==0){
		$EXECUTE selClienteObjConexMigrado into :sMarca using :nroCliente;
	}else if(strcmp(sTipoObjeto, "PUNTOSUM")==0){
		$EXECUTE selClientePtoSumMigrado into :sMarca using :nroCliente;
	}else{
		$EXECUTE selClienteUbicApaMigrado into :sMarca using :nroCliente;
	}

	if(SQLCODE != 0){
		if(SQLCODE == SQLNOTFOUND){
			*iFlagMigra=1;  /* Indica que se debe hacer un insert */
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

short RegistraCliente(sObjeto, nroCliente, iFlagMigra)
char	sObjeto[11];
$long	nroCliente;
int		iFlagMigra;
{

	if(strcmp(sObjeto, "OBJCONEX")==0){
		if(iFlagMigra==1){
			$EXECUTE insClteMigraConex using :nroCliente;
		}else{
			$EXECUTE updClteMigraConex using :nroCliente;
		}
	}else if(strcmp(sObjeto, "PUNTOSUM")==0){
		if(iFlagMigra==1){
			$EXECUTE insCltePtosSum using :nroCliente;
		}else{
			$EXECUTE updCltePtosSum using :nroCliente;
		}
	}else{
		if(iFlagMigra==1){
			$EXECUTE insClteUbicApa using :nroCliente;
		}else{
			$EXECUTE updClteUbicApa using :nroCliente;
		}		
	}

	return 1;
}

/*
short RegistraArchivo(void)
{
	$int iEstado=giEstadoCliente;
	$long	lNroCliente=glNroCliente;
	$long	lCantClientes;
	$char	sTipoArchivo[50];
	$char	sNombreArchivo[100];
	
	// Objeto Conexion	
	if(cantProcesadaConexActivo>0 || cantProcesadaConexNoActivo>0){
		strcpy(sTipoArchivo, "OBJCONEX");
		alltrim(sTipoArchivo, ' ');
		$EXECUTE updGenArchivos using :sTipoArchivo;

	}
	
	if(cantProcesadaConexActivo>0 ){
		strcpy(sTipoArchivo, "OBJCONEX_ACTIVO");
		
		strcpy(sNombreArchivo, sSoloArchivoConexActivo);
		lCantClientes=cantProcesadaConexActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;		
	}

	if(cantProcesadaConexNoActivo>0 ){
		strcpy(sTipoArchivo, "OBJCONEX_NO_ACTIVO");
		strcpy(sNombreArchivo, sSoloArchivoConexNoActivo);
		lCantClientes=cantProcesadaConexNoActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;	
	}
	
	// Punto Suministro
	if(cantProcesadaPtoSumActivo>0 || cantProcesadaPtoSumNoActivo>0){
		strcpy(sTipoArchivo, "PUNTOSUM");
		alltrim(sTipoArchivo, ' ');
		$EXECUTE updGenArchivos using :sTipoArchivo;

	}
	
	if(cantProcesadaPtoSumActivo>0 ){
		strcpy(sTipoArchivo, "PUNTOSUM_ACTIVO");
		strcpy(sNombreArchivo, sSoloArchivoPtoSumActivo);
		lCantClientes=cantProcesadaPtoSumActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;
					
	}

	if(cantProcesadaPtoSumNoActivo>0 ){
		strcpy(sTipoArchivo, "PUNTOSUM_NO_ACTIVO");
		strcpy(sNombreArchivo, sSoloArchivoPtoSumNoActivo);
		lCantClientes=cantProcesadaPtoSumNoActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;
	}	
		
	// Ubicacion Aparatos
	if(cantProcesadaUbicApaActivo>0 || cantProcesadaUbicApaNoActivo>0){
		strcpy(sTipoArchivo, "UBICAPA");
		alltrim(sTipoArchivo, ' ');
		$EXECUTE updGenArchivos using :sTipoArchivo;

	}
	
	if(cantProcesadaUbicApaActivo>0 ){
		strcpy(sTipoArchivo, "UBICAPA_ACTIVO");
		strcpy(sNombreArchivo, sSoloArchivoUbicApaActivo);
		lCantClientes=cantProcesadaUbicApaActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;
					
	}

	if(cantProcesadaUbicApaNoActivo>0 ){
		strcpy(sTipoArchivo, "UBICAPA_NO_ACTIVO");
		strcpy(sNombreArchivo, sSoloArchivoUbicApaNoActivo);
		lCantClientes=cantProcesadaUbicApaNoActivo;
		
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantClientes,	
				:lNroCliente,
				:sNombreArchivo;
	}	
	
	return 1;
}
*/
int getTipoPersona(sTipoCliente)
char	sTipoCliente[3];
{
	int iTipo=0;
	
	if(strcmp(sTipoCliente, "PR")==0 || strcmp(sTipoCliente, "PR")==0){
		iTipo=1;	
	}else{
		iTipo=2;
	}	
	
	return iTipo;
}

void GeneraCO_EHA(fp, regCliente)
FILE 		*fp;
ClsCliente	regCliente;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   /* LLAVE + SPRAS + BEGRU */
	sprintf(sLinea, "T1%ld\tCO_EHA\tS\tT1\t", regCliente.numero_cliente);
   /* SWERK */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.sucursal);
   /* COUNC  */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.partido);
	/*
	sprintf(sLinea, "%sARG", sLinea);
	*/
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}

void GeneraCO_ADR(fp, regCliente)
FILE 		*fp;
ClsCliente	regCliente;
{
	char	sLinea[10000];
   char  sAux[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sAux, '\0', sizeof(sAux));
	
	alltrim(regCliente.nom_partido, ' ');
	alltrim(regCliente.nom_comuna, ' ');
	alltrim(regCliente.nom_calle, ' ');
	alltrim(regCliente.nro_dir, ' ');
	alltrim(regCliente.nom_entre, ' ');
	alltrim(regCliente.nom_entre1, ' ');
   alltrim(regCliente.piso_dir, ' ');
   alltrim(regCliente.depto_dir, ' ');
   
   if(strcmp(regCliente.piso_dir, "") != 0){
      sprintf(sAux, "Piso: %s", regCliente.piso_dir);
   }
   if(strcmp(regCliente.depto_dir, "") != 0){
      sprintf(sAux, "%s Depto: %s", sAux, regCliente.depto_dir);
   }
   alltrim(sAux, ' ');
	
   /* LLAVE + DATE_FROM + DATE_TO */
	sprintf(sLinea, "T1%ld\tCO_ADR\t00010101\t99991231\t", regCliente.numero_cliente);

   /* NAME_CO */
   if(strcmp(sAux, "") != 0){
      sprintf(sLinea, "%s%s\t", sLinea, sAux);
   }else{
      strcat(sLinea, "\t");
   }

   /* CITY1 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_partido);
   /* CITY2 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_comuna);
   /* POST_CODE1 */
	sprintf(sLinea, "%s%d\t", sLinea, regCliente.cod_postal);
   /* STREET */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_calle);
   /* HOUSE_NUM1 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nro_dir);
   /* STR_SUPPL1 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_entre);
   /* STR_SUPPL2 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_entre1);
   /* COUNTRY */
	strcat(sLinea, "AR\t");
   /* REGION */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.provincia);
   /* TIME_ZONE */
	strcat(sLinea, "UTC-3");

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

void GeneraEVBSD(fp, regCliente)
FILE 		*fp;
ClsCliente	regCliente;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	alltrim(regCliente.piso_dir, ' ');
	alltrim(regCliente.depto_dir, ' ');
	
   /* llave */
	sprintf(sLinea, "T1%ld\tEVBSD\t", regCliente.numero_cliente);
   /* HAUS */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
   /* VBSTART + BEGRU */
   strcat(sLinea, "0007\tT1\t");
   /* FLOOR */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.piso_dir);
   /* ROOMNUMBER */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.depto_dir);
   /* LAGETEXT */
	sprintf(sLinea, "%s%s", sLinea, regCliente.info_adic_lectura);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraEGPLD(fp, regCliente)
FILE 		*fp;
ClsCliente	regCliente;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	alltrim(regCliente.info_adic_lectura, ' ');
	alltrim(regCliente.descrip_info_adic, ' ');
	
	sprintf(sLinea, "T1%ld\tEGPLD\t", regCliente.numero_cliente);
	sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);		/* llave conect */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);		/* llave premise */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.sucursal);
	strcat(sLinea, "\t");
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.info_adic_lectura);
	strcat(sLinea, "T1\t");
	sprintf(sLinea, "%s%s", sLinea, regCliente.descrip_info_adic);
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
		
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


static char *strReplace(sCadena, cFind, cRemp)
char *sCadena;
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;

	memset(sNvaCadena, '\0', sizeof(sNvaCadena));
	
	lLargo=strlen(sCadena);

    if (lLargo == 0)
    	return sCadena;

	for(lPos=0; lPos<lLargo; lPos++){

       if (sCadena[lPos] != cFind[0]) {
       	sNvaCadena[lPos]=sCadena[lPos];
       }else{
	       if(strcmp(cRemp, "")!=0){
	       		sNvaCadena[lPos]=cRemp[0];  
	       }else {
	            sNvaCadena[lPos]=' ';   
	       }
       }
	}

	return sNvaCadena;
}

