/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_portion
    
	Fecha : 20/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura PORTION y Unidad Lectura
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Archivos a Generar>: 0 = Todos; 1 = Porcion; 2 = Unidad Lectura
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_portion.h";

/* Variables Globales */
$int	giArchivosGen;
$int	giEstadoCliente;
$long	glNroCliente;
$char	gsTipoGenera[2];

FILE	*pFilePortionActivoUnx;
FILE	*pFilePortionNoActivoUnx;

FILE	*pFileULActivoUnx;
FILE	*pFileULNoActivoUnx;

char	sArchPortionActivoUnx[100];

char	sArchULActivoUnx[100];

char	sArchPortionActivoDos[100];

char	sArchULActivoDos[100];

char	sSoloArchivoPortionActivo[100];
char	sSoloArchivoULActivo[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativoPortion;
long	lCorrelativoUL;

long	cantProcesadaPortionActivo;
long	cantProcesadaPortionNoActivo;

long	cantProcesadaULActivo;
long	cantProcesadaULNoActivo;

long 	cantPreexistenteUL;
long 	cantPreexistenteUL;

/* Variables Globales Host */
$ClsPortion	regPortion;
$ClsUnLectu regUnLectu;
$long       lFechaPivote;
char        sFechaPivote[11];

$long       lFechaPivote2;
char        sFechaPivote2[11];

char	sMensMail[1024];	/*jhuck ME089 */

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fpPortion;
FILE	*fpUL;


	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
	/* $BEGIN WORK;*/

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesadaPortionActivo=0;
	cantProcesadaPortionNoActivo=0;
	cantProcesadaULActivo=0;
	cantProcesadaULNoActivo=0;


	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   /*$EXECUTE selFechaRti into :lFechaPivote;*/

   /*$EXECUTE selAnoRetro into :lFechaPivote;*/
/*   
   strcpy(sFechaPivote, "20141201");
   rdefmtdate(&lFechaPivote, "yyyymmdd", sFechaPivote); //char a long
*/   
   $EXECUTE selPivote INTO :lFechaPivote;
   
/*   
   strcpy(sFechaPivote2, "20171001");
   rdefmtdate(&lFechaPivote2, "yyyymmdd", sFechaPivote2); //char a long
*/   
   
   $EXECUTE selPivote2 INTO :lFechaPivote2;
      
	if(giArchivosGen==0 || giArchivosGen==1){

		/* Hago el PORTION */
		$OPEN curPorcion USING :lFechaPivote;
		
		fpPortion=pFilePortionActivoUnx;

		while(LeoPortion(&regPortion)){
         
         if(!getFactuAnterior(&regPortion)){
				$ROLLBACK WORK;
				exit(1);	
         }
      
			if (!GenerarPlanoPortion(fpPortion, regPortion)){
				$ROLLBACK WORK;
				exit(1);	
			}

			cantProcesadaPortionActivo++;
		}
		$CLOSE curPorcion;
	}
	
	if(giArchivosGen==0 || giArchivosGen==2){

		/* Hago la Unidad de Lectura */
		$OPEN curUnLectu USING :lFechaPivote;
		
		fpUL=pFileULActivoUnx;
	
		while(LeoUnLectu(&regUnLectu)){
         if(!getDifFechas(&regUnLectu)){
				/*$ROLLBACK WORK;*/
				exit(1);	
         }
      
			if (!GenerarPlanoUL(fpUL, regUnLectu)){
				/*$ROLLBACK WORK;*/
				exit(1);	
			}
			cantProcesadaULActivo++;
		}
		$CLOSE curUnLectu;
	}
			
	CerrarArchivos();

	/* Registrar Control Plano */
/*
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
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Registros Porcion :        %ld \n", cantProcesadaPortionActivo);
	printf("Registros Un.de Lectura :  %ld \n", cantProcesadaULActivo);
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

	if(argc != 4){
		MensajeParametros();
		return 0;
	}
	
	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0){
		MensajeParametros();
		return 0;	
	}

	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	giArchivosGen=atoi(argv[2]);	
	strcpy(gsTipoGenera, argv[3]);
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Archivos Generados> 0=Todos; 1=Porcion; 2=Unidad Lectura\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
}

short AbreArchivos()
{
	
	memset(sArchPortionActivoUnx,'\0',sizeof(sArchPortionActivoUnx));
	/*memset(sArchPortionNoActivoUnx,'\0',sizeof(sArchPortionNoActivoUnx));*/
	memset(sArchULActivoUnx,'\0',sizeof(sArchULActivoUnx));
	/*memset(sArchULNoActivoUnx,'\0',sizeof(sArchULNoActivoUnx));*/

	memset(sArchPortionActivoDos,'\0',sizeof(sArchPortionActivoDos));
	/*memset(sArchPortionNoActivoDos,'\0',sizeof(sArchPortionNoActivoDos));*/
	memset(sArchULActivoDos,'\0',sizeof(sArchULActivoDos));
	/*memset(sArchULNoActivoDos,'\0',sizeof(sArchULNoActivoDos));*/

	memset(sSoloArchivoPortionActivo,'\0',sizeof(sSoloArchivoPortionActivo));
	/*memset(sSoloArchivoPortionNoActivo,'\0',sizeof(sSoloArchivoPortionNoActivo));*/
	memset(sSoloArchivoULActivo,'\0',sizeof(sSoloArchivoULActivo));
	/*memset(sSoloArchivoULNoActivo,'\0',sizeof(sSoloArchivoULNoActivo));*/
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
	
	switch(giArchivosGen){
		case 0:	/* PORTION y UL */
			sprintf( sArchPortionActivoUnx  , "%sT1PORC.unx", sPathSalida );
			strcpy( sSoloArchivoPortionActivo, "T1PORC.unx");
			
			sprintf( sArchULActivoUnx  , "%sT1ULECT.unx", sPathSalida);
			strcpy( sSoloArchivoULActivo, "T1ULECT.unx");

			pFilePortionActivoUnx=fopen( sArchPortionActivoUnx, "w" );
			if( !pFilePortionActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPortionActivoUnx );
				return 0;
			}			

			pFileULActivoUnx=fopen( sArchULActivoUnx, "w" );
			if( !pFileULActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchULActivoUnx );
				return 0;
			}			

			break;
											
		case 1: /* Solo PORTION */
			sprintf( sArchPortionActivoUnx  , "%sT1PORC.unx", sPathSalida );
			strcpy( sSoloArchivoPortionActivo, "T1PORC.unx");
			
			pFilePortionActivoUnx=fopen( sArchPortionActivoUnx, "w" );
			if( !pFilePortionActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchPortionActivoUnx );
				return 0;
			}			

			break;
						
		case 2:	/* Solo UL */
			sprintf( sArchULActivoUnx  , "%sT1ULECT.unx", sPathSalida);
			strcpy( sSoloArchivoULActivo, "T1ULECT.unx");
						
			pFileULActivoUnx=fopen( sArchULActivoUnx, "w" );
			if( !pFileULActivoUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchULActivoUnx );
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
			fclose(pFilePortionActivoUnx);
			fclose(pFileULActivoUnx);
			break;
		case 1:
			fclose(pFilePortionActivoUnx);
			break;
		case 2:
			fclose(pFileULActivoUnx);
			break;
	}	
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
   sprintf(sPathCp, "%sActivos/", sPathCopia);
   

	if(cantProcesadaPortionActivo>0){
		sprintf(sCommand, "chmod 755 %s", sArchPortionActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchPortionActivoUnx, sPathCp);
		iRcv=system(sCommand);
      
	}
	
	if(cantProcesadaULActivo>0){
		sprintf(sCommand, "chmod 755 %s", sArchULActivoUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchULActivoUnx, sPathCp);
		iRcv=system(sCommand);
      		
	}
	
/*
	if(cantProcesadaPortionActivo>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchPortionActivoUnx, sArchPortionActivoDos);
		iRcv=system(sCommand);
	}

	if(cantProcesadaULActivo>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchULActivoUnx, sArchULActivoDos);
		iRcv=system(sCommand);
	}

	sprintf(sCommand, "rm -f %s", sArchPortionActivoUnx);
	iRcv=system(sCommand);	

	sprintf(sCommand, "rm -f %s", sArchULActivoUnx);
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

   /******** Fecha Pivote  ****************/
   strcpy(sql, "SELECT TODAY - 420 FROM dual ");
   
   $PREPARE selPivote FROM $sql;

   /******** Fecha Pivote 2  ****************/
   strcpy(sql, "SELECT TODAY - 70 FROM dual ");
   
   $PREPARE selPivote2 FROM $sql;
	
	/******** Cursor Porcion  ****************/	
	strcpy(sql, "SELECT TO_CHAR(MAX(a1.fecha_generacion), '%d.%m.%Y'), ");
	strcat(sql, "MAX(TO_CHAR(a1.fecha_emision_real, '%d.%m.%Y')), ");

	strcat(sql, "'000T1'||  ");
	strcat(sql, "	lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end,2,0) || sc.cod_ul_sap,  ");
	strcat(sql, "'T1' || '-' || (case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end) || '-' || sc.cod_centro_op,  ");
	
	strcat(sql, "TO_CHAR(MAX(a1.fecha_generacion + s.valor_entero), '%d.%m.%Y'), ");
	strcat(sql, "a1.sucursal, ");
	strcat(sql, "a1.sector, ");
	strcat(sql, "a1.zona ");   
	strcat(sql, "FROM agenda a1, sap_transforma s, sucur_centro_op sc ");
	/*strcat(sql, "WHERE a1.sector BETWEEN 41 AND 82 ");*/
   strcat(sql, "WHERE a1.sector <= 82 ");

   strcat(sql, "AND a1.identif_agenda IN ( SELECT d2.identif_agenda ");
   strcat(sql, "	FROM det_agenda d2 ");
   strcat(sql, "	WHERE d2.sucursal = a1.sucursal ");
   strcat(sql, "	AND d2.sector = a1.sector ");
   strcat(sql, "	AND d2.fecha_generacion = (SELECT MAX(d3.fecha_generacion) FROM det_agenda d3 ");
   strcat(sql, "		WHERE d3.sucursal = d2.sucursal ");
   strcat(sql, "	 	AND d3.sector = d2.sector ");
   strcat(sql, "	  AND d3.zona = d2.zona ");
   strcat(sql, "	  AND d3.fecha_generacion >= ?)) ");
   
/*   
	strcat(sql, "AND a1.fecha_emision_real = ( select max(a2.fecha_emision_real)  ");
	strcat(sql, "	FROM agenda a2  ");
   strcat(sql, " 	WHERE a2.sucursal = a1.sucursal ");
	strcat(sql, " 	AND a2.sector = a1.sector ");
   strcat(sql, "  AND a2.fecha_emision_real >= ? ) ");
*/   
	strcat(sql, "AND s.clave = 'PORTION_NDIAS' ");
	strcat(sql, "AND sc.cod_centro_op = a1.sucursal ");   
	strcat(sql, "GROUP BY 3,4,6,7,8 ");
	strcat(sql, "ORDER BY 3,4 ");
	
	$PREPARE selPorcion FROM $sql;
	
	$DECLARE curPorcion CURSOR FOR selPorcion;	
	
	/******** Cursor Unidad de Lectura ********/
	strcpy(sql, "SELECT ");
	strcat(sql, "'000T1'|| ");
	strcat(sql, "   lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end,2,0) || sc.cod_ul_sap porcion, ");
	strcat(sql, " TRIM(sc.cod_ul_sap || ");	
	strcat(sql, "      lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end, 2, 0)|| ");
	strcat(sql, "      lpad(d.zona,5,0)) unidad_lectura, ");
	strcat(sql, "'T1' || '-' || a1.sucursal || '-' || case when a1.sector>60 and a1.sector<81 then a1.sector else a1.sector end || ");
	strcat(sql, "	'-' || lpad(d.zona,5,0) desc_ul, ");
	strcat(sql, "NVL(s.indice_social, 0), ");
	strcat(sql, "NVL(r.ctr_registro, 95), ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN ac.radio IS NOT NULL THEN 'S' ");
	strcat(sql, " 	ELSE 'N' ");
	strcat(sql, "END, ");
	strcat(sql, "a1.sucursal, "); 
	strcat(sql, "a1.sector, ");
	strcat(sql, "a1.zona, "); 
	strcat(sql, "TO_CHAR(MAX(a3.fecha_generacion), '%Y%m%d') ");
	strcat(sql, "FROM agenda a1, sucur_centro_op sc, det_agenda d, susec s, OUTER reparto_facturas r, agenda a3, OUTER area_crisis ac ");
	/*strcat(sql, "WHERE a1.sector BETWEEN 41 AND 82 ");*/
   strcat(sql, "WHERE a1.sector <= 82 ");

   strcat(sql, "AND a1.identif_agenda IN ( SELECT d2.identif_agenda ");
   strcat(sql, "	FROM det_agenda d2 ");
   strcat(sql, "	WHERE d2.sucursal = a1.sucursal ");
   strcat(sql, "	AND d2.sector = a1.sector ");
   strcat(sql, "	AND d2.fecha_generacion = (SELECT MAX(d3.fecha_generacion) FROM det_agenda d3 ");
   strcat(sql, "		WHERE d3.sucursal = d2.sucursal ");
   strcat(sql, "	 	AND d3.sector = d2.sector ");
   strcat(sql, "	  AND d3.zona = d2.zona ");
   strcat(sql, "	  AND d3.fecha_generacion >= ?)) ");
   
/*   
	strcat(sql, "AND a1.fecha_emision_real = ( select max(a2.fecha_emision_real) ");
	strcat(sql, "	FROM agenda a2 ");
	strcat(sql, "  	WHERE a2.sucursal = a1.sucursal ");
	strcat(sql, "  	AND a2.sector = a1.sector ");
   strcat(sql, "     AND a2.fecha_emision_real >= ? ) ");
*/   
   
	strcat(sql, "AND sc.cod_centro_op = a1.sucursal ");
	strcat(sql, "AND sc.fecha_activacion <= TODAY ");
	strcat(sql, "AND (sc.fecha_desactivac IS NULL OR sc.fecha_desactivac > TODAY) ");
	strcat(sql, "AND d.identif_agenda = a1.identif_agenda ");
	strcat(sql, "AND s.sucursal = a1.sucursal ");
	strcat(sql, "AND s.sector = a1.sector ");
	strcat(sql, "AND s.zona = d.zona ");
	strcat(sql, "AND r.sucursal = a1.sucursal ");
	strcat(sql, "AND r.plan = a1.sector ");
	strcat(sql, "AND r.radio = d.zona ");
	strcat(sql, "AND ac.sucursal = a1.sucursal ");
	strcat(sql, "AND ac.plan = a1.sector ");
	strcat(sql, "AND ac.radio = d.zona ");	
	strcat(sql, "AND a3.sucursal= a1.sucursal ");
	strcat(sql, "AND a3.sector = a1.sector ");
	strcat(sql, "AND a3.zona = a1.zona ");
	/*strcat(sql, "AND a3.estado = 1 ");*/
	strcat(sql, "AND a3.tipo_agenda = 'L' ");
	strcat(sql, "GROUP BY 1,2,3,4,5,6,7,8,9 ");
	strcat(sql, "ORDER BY 1,2 ");
	
	$PREPARE selUnLectu FROM $sql;
	
	$DECLARE curUnLectu CURSOR FOR selUnLectu;	
	
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
	strcat(sql, "?, ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");	
	
	/*$PREPARE insGenArchivo FROM $sql;*/

   /********* Fecha RTi **********/
	strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;

   /********** Fecha Factura anterior ************/
	strcpy(sql, "SELECT MAX(fecha_emision_real) "); 
	strcat(sql, "FROM agenda ");
	strcat(sql, "WHERE sucursal = ? ");
	strcat(sql, "AND sector = ? ");
	strcat(sql, "AND zona = ? ");
	strcat(sql, "AND fecha_emision_real < ? ");

	strcpy(sql, "SELECT a1.fecha_emision_real, a1.fecha_generacion ");
	strcat(sql, "FROM agenda a1 ");
	strcat(sql, "WHERE a1.sucursal = ? ");
	strcat(sql, "AND a1.sector = ? ");
	strcat(sql, "AND a1.zona = ? "); 
	strcat(sql, "AND a1.fecha_emision_real = (SELECT MAX(a2.fecha_emision_real) ");
	strcat(sql, "	FROM agenda a2 ");
	strcat(sql, "	WHERE a2.sucursal = a1.sucursal ");
	strcat(sql, "	AND a2.sector = a1.sector ");
	strcat(sql, "	AND a2.zona = a1.zona ");
	strcat(sql, "   AND a2.fecha_emision_real < ?) ");
   
   $PREPARE selFacturaAnter FROM $sql;
   
   /*********** Año Atras ***********/
	strcpy(sql, "SELECT TODAY-574 FROM dual ");
      
   $PREPARE selAnoRetro FROM $sql;
   
   /*********** REcupero Fecha Generacion para Portion *************/
	strcpy(sql, "SELECT MAX(a1.fecha_generacion) ");
	strcat(sql, "FROM agenda a1 ");
	strcat(sql, "WHERE a1.sucursal = ? ");
	strcat(sql, "AND a1.sector = ? ");
	strcat(sql, "AND a1.zona = ? ");
	strcat(sql, "AND a1.fecha_emision_real = ( select max(a2.fecha_emision_real) ");  
	strcat(sql, "	FROM agenda a2 ");  
	strcat(sql, " 	WHERE a2.sucursal = a1.sucursal "); 
	strcat(sql, " 	AND a2.sector = a1.sector "); 
	strcat(sql, "  AND a2.fecha_emision_real >= ? ) ");
   
   $PREPARE selMinGen FROM $sql;
  
     		
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
short LeoPortion(regPor)
$ClsPortion *regPor;
{
	InicializaPortion(regPor);
	
	$FETCH curPorcion into
		:regPor->fecha_generacion,
		:regPor->fecha_emision,
		:regPor->cod_porcion,
		:regPor->desc_porcion,
		:regPor->fecha_genera_ampliada,
      :regPor->sucursal,
      :regPor->sector,
      :regPor->zona;
			
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Portion !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regPor->desc_porcion, ' ');
	
	return 1;	
}

void InicializaPortion(regPor)
$ClsPortion	*regPor;
{
	memset(regPor->cod_porcion, '\0', sizeof(regPor->cod_porcion));
	memset(regPor->desc_porcion, '\0', sizeof(regPor->desc_porcion));
	memset(regPor->fecha_generacion, '\0', sizeof(regPor->fecha_generacion));
	memset(regPor->fecha_emision, '\0', sizeof(regPor->fecha_emision));
	memset(regPor->fecha_genera_ampliada, '\0', sizeof(regPor->fecha_genera_ampliada));
   memset(regPor->sucursal, '\0', sizeof(regPor->sucursal));
   rsetnull(CINTTYPE, (char *) &(regPor->sector));
   rsetnull(CINTTYPE, (char *) &(regPor->zona));
   
   memset(regPor->termerst, '\0', sizeof(regPor->termerst));
   memset(regPor->abrdats, '\0', sizeof(regPor->abrdats));
}

short LeoUnLectu(regUl)
$ClsUnLectu  *regUl;
{
	InicializaUnLectu(regUl);
	
	$FETCH curUnLectu into
		:regUl->cod_porcion,
		:regUl->cod_ul,
		:regUl->desc_ul,
		:regUl->indice_social,
		:regUl->cod_contratista,
		:regUl->area_crisis,
      :regUl->sucursal,
      :regUl->sector,
      :regUl->zona,
		:regUl->fecha_lectura;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Unidad Lectura !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regUl->desc_ul, ' ');
	
	return 1;	
	
}

void InicializaUnLectu(regUl)
$ClsUnLectu	*regUl;
{
	memset(regUl->cod_porcion, '\0', sizeof(regUl->cod_porcion));
	memset(regUl->cod_ul, '\0', sizeof(regUl->cod_ul));
	memset(regUl->desc_ul, '\0', sizeof(regUl->desc_ul));
	rsetnull(CINTTYPE, (char *) &(regUl->indice_social));
	rsetnull(CINTTYPE, (char *) &(regUl->cod_contratista));
	memset(regUl->area_crisis, '\0', sizeof(regUl->area_crisis));
	memset(regUl->fecha_lectura, '\0', sizeof(regUl->fecha_lectura));
   
   memset(regUl->sucursal, '\0', sizeof(regUl->sucursal));
	rsetnull(CINTTYPE, (char *) &(regUl->sector));
	rsetnull(CINTTYPE, (char *) &(regUl->zona));
	rsetnull(CINTTYPE, (char *) &(regUl->eper_abl));   
   
}

short GenerarPlanoPortion(fp, regPor)
FILE 			*fp;
$ClsPortion		regPor;
{

	/* TE_420 */	
	GeneraTE420(fp, regPor);
	
	/* ENDE */
/*   
	GeneraENDEpor(fp, regPor);
*/	
	return 1;
}

short GenerarPlanoUL(fp, regUl)
FILE 			*fp;
$ClsUnLectu		regUl;
{
	
	/* TE_422 */
	GeneraTE422(fp, regUl);

	/* TE_425 */
	/*GeneraTE425(fp, regUl);*/
		
	/* ENDE */
	/*GeneraENDEul(fp, regUl);*/
	
	return 1;
}


void GeneraENDEpor(fp, regPor)
FILE *fp;
$ClsPortion	regPor;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "%s\t&ENDE", regPor.cod_porcion);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraENDEul(fp, regUl)
FILE *fp;
$ClsUnLectu	regUl;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "%s\t&ENDE", regUl.cod_ul);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$long	lNroCliente;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	lNroCliente=-1;
	
	// Portion	
	if(cantProcesadaPortionActivo > 0){
		strcpy(sTipoArchivo, "PORTION");
		strcpy(sNombreArchivo, sSoloArchivoPortionActivo);
		lCantidad=cantProcesadaPortionActivo;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantidad,
				:lNroCliente,
				:sNombreArchivo;
	}

	// Unidad Lectura
	if(cantProcesadaULActivo > 0){
		strcpy(sTipoArchivo, "UNLECTU");
		strcpy(sNombreArchivo, sSoloArchivoULActivo);
		lCantidad=cantProcesadaULActivo;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;

		$EXECUTE insGenArchivo using
				:sTipoArchivo,
				:gsTipoGenera,
				:lCantidad,
				:lNroCliente,
				:sNombreArchivo;
	}
	
	return 1;
}
*/
void GeneraTE420(fp, regPor)
FILE 		*fp;
ClsPortion	regPor;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));
	alltrim(regPor.desc_porcion, ' ');

/*	
	sprintf(sLinea, "%s\tTE420\t", regPor.cod_porcion);
	sprintf(sLinea, "%s%s\t", sLinea, regPor.cod_porcion);
	sprintf(sLinea, "%s%s\t", sLinea, regPor.desc_porcion);
	sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_genera_ampliada);
	sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_generacion);
	strcat(sLinea, "1\t");
	sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_genera_ampliada);
	sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_emision);
	strcat(sLinea, "\t\t\t");
	strcat(sLinea, "AR\t");
	strcat(sLinea, "\t");
	strcat(sLinea, "0\t0\t0\t");
	strcat(sLinea, "\t");
	strcat(sLinea, "T1\t");
	strcat(sLinea, "01\t");
	strcat(sLinea, "\t");
	strcat(sLinea, "0001\t");
	strcat(sLinea, "X\t");
	strcat(sLinea, "AR\t");
	strcat(sLinea, "01");
*/

   /* TERMSCHL */
   sprintf(sLinea, "%s\t", regPor.cod_porcion);
   
   /* TERMTEXT */
   sprintf(sLinea, "%s%s\t", sLinea, regPor.desc_porcion);
   
   /* PARASATZ */
   strcat(sLinea, "0001\t");
   
   /* BEGRU */
   strcat(sLinea, "T1\t");
   
   /* TERMERST */
   /*sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_generacion);*/
   sprintf(sLinea, "%s%s\t", sLinea, regPor.termerst);
   
   /* DATUMDF */
   /*sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_emision);*/
   sprintf(sLinea, "%s%s\t", sLinea, regPor.termerst);
   
   /* ZUORDAT */
   /*sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_generacion);*/
   sprintf(sLinea, "%s%s\t", sLinea, regPor.termerst);
   
   /* ABRDATS */
   /*sprintf(sLinea, "%s%s\t", sLinea, regPor.fecha_generacion);*/
   sprintf(sLinea, "%s%s\t", sLinea, regPor.abrdats);
   
   /* PERIODEW */
   strcat(sLinea, "1\t");
   
   /* IDENT */
   strcat(sLinea, "AR\t");
   
   /* SAPKAL */
   strcat(sLinea, "2\t");
   
   /* WORK_DAY */
   strcat(sLinea, "X\t");
   
   /* PTOLERFROM */
   strcat(sLinea, "0\t");
   
   /* PTOLERTO */
   strcat(sLinea, "0\t");
   
   /* EXTRAPOLWASTE (vacio) */
   strcat(sLinea, "\t");
   
   /* ABSZYK */
	strcat(sLinea, "00");
   
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}

void GeneraTE422(fp, regUl)
FILE 		*fp;
ClsUnLectu	regUl;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	alltrim(regUl.desc_ul, ' ');
/*	
	sprintf(sLinea, "%s\tTE422\t", regUl.cod_ul);
	sprintf(sLinea, "%s%s\t", sLinea, regUl.cod_ul);
	sprintf(sLinea, "%s%s\t", sLinea, regUl.desc_ul);
	sprintf(sLinea, "%s%s\t", sLinea, regUl.cod_porcion);
	
	strcat(sLinea, "1\tAR\t2\tT1\t3\t1\tX\t");
	strcat(sLinea, "\t\t\t");
	strcat(sLinea, "1\tX\t");
	strcat(sLinea, "\t\t\t\t\t\t");
	strcat(sLinea, "IS_U_METER_READING_ORDER\t\tIS_U_METER_READING_DOWNLOAD\t\t\t");
	
	sprintf(sLinea, "%s%d\t", sLinea, regUl.indice_social);
	sprintf(sLinea, "%s%s\t", sLinea, regUl.area_crisis);
	sprintf(sLinea, "%s%ld\t", sLinea, regUl.cod_contratista);	

	strcat(sLinea, "\t\t");
*/

   /* TERMSCHL */
   sprintf(sLinea, "%s\t",  regUl.cod_ul);
      
   /* TERMTEXT */
   sprintf(sLinea, "%s%s\t", sLinea, regUl.desc_ul);
   
   /* PORTION */
   sprintf(sLinea, "%s%s\t", sLinea, regUl.cod_porcion);
   
   /* AZVORABL */
   strcat(sLinea, "1\t");
   
   /* IDENT */
   strcat(sLinea, "AR\t");
   
   /* BEGRU */
   strcat(sLinea, "T1\t");
   
   /* SAPKAL */
   strcat(sLinea, "2\t");
   
   /* EPER_ABL */
   /*strcat(sLinea, "0\t");*/
   sprintf(sLinea, "%s%d\t", sLinea, regUl.eper_abl);
   
   /* DOWNL_ABL */
   strcat(sLinea, "2\t");
   
   /* DOW_KAL */
   strcat(sLinea, "X\t");
   
   /* AUF_ABL */
   strcat(sLinea, "2\t");
   
   /* AUF_KAL */
   strcat(sLinea, "X\t");
   
   /* FORMULAR */
   strcat(sLinea, "IS_U_METER_READING_ORDER\t");
   
   /* DOWN_FORM */
   strcat(sLinea, "IS_U_METER_READING_DOWNLOAD\t");

   /* DOWN_FORM */
   strcat(sLinea, "04");
      	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

void GeneraTE425(fp, regUl)
FILE 		*fp;
ClsUnLectu	regUl;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	alltrim(regUl.desc_ul, ' ');
	
	sprintf(sLinea, "%s\tTE425\t", regUl.cod_ul);
	sprintf(sLinea, "%s%s\t", sLinea, regUl.fecha_lectura);
	strcat(sLinea, "'LECTURA REAL'");
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

short getFactuAnterior(reg)
$ClsPortion *reg;
{
   $long lFecha;
   long  lFechaAux;
   $long lFechaAux1;
   $long lFechaAux2;
   long lFDesde;
   
   $EXECUTE selFacturaAnter INTO :lFechaAux1, :lFechaAux2 USING :reg->sucursal,
                                                            :reg->sector,
                                                            :reg->zona,
                                                            :lFechaPivote;
                                                            
                                                            /*:lFechaPivote2;*/

   if(SQLCODE != 0){
      printf("No se encontro facturacion anterior para Suc.%s Sector %ld Zona %ld POR\n", reg->sucursal, reg->sector, reg->zona);
      return 0;
   }
   /*
   lFechaAux1 = lFecha - 1;
   lFechaAux2 = lFecha - 3;
   */
  
   
/*
   if(!risnull(CLONGTYPE, (char *)&lFecha) && lFecha > 0){
      lFecha=lFecha-420; // Le resto 14 meses 
      lFDesde = lFecha-100;
      lFechaAux1 = RestarDiasHabiles(lFecha, 1, lFDesde);
      lFechaAux2 = RestarDiasHabiles(lFechaAux1, 3, lFDesde); 
   }else{
   
      rdefmtdate(&lFechaAux, "dd.mm.yyyy", reg->fecha_generacion);
      lFechaAux=lFechaAux-420; // Le resto 14 meses 
      lFDesde = lFechaAux-100;
      lFechaAux1 = RestarDiasHabiles(lFechaAux, 1, lFDesde);
      lFechaAux2 = RestarDiasHabiles(lFechaAux1, 3, lFDesde); 
   }
*/   
   rfmtdate(lFechaAux1, "dd.mm.yyyy", reg->termerst); /* long to char */
   rfmtdate(lFechaAux2, "dd.mm.yyyy", reg->abrdats);  /* long to char */

   return 1;
}

short getDifFechas(reg)
$ClsUnLectu *reg;  
{
   $long lFecha;
   $long lFechaAux;
   $long  lFechaAux1;
   $long  lFechaAux2;
   long  lFDesde;
   int   iDiffer;
   
   $EXECUTE selFacturaAnter INTO :lFechaAux1, :lFechaAux2 USING :reg->sucursal,
                                                :reg->sector,
                                                :reg->zona,
                                                :lFechaPivote;

   if(SQLCODE != 0){
      printf("No se encontro facturacion anterior para Suc.%s Sector %ld Zona %ld UL\n", reg->sucursal, reg->sector, reg->zona);
      return 0;
   }                                                            

   /*
   lFechaAux1 = lFecha - 1;
   lFechaAux2 = lFecha - 3;
   */
   
   /*
   if(!risnull(CLONGTYPE, (char *)&lFecha) && lFecha > 0){
      lFecha=lFecha-420; // Le resto 14 meses 
      lFDesde = lFecha-100;
      lFechaAux1 = RestarDiasHabiles(lFecha, 1, lFDesde);
      lFechaAux2 = RestarDiasHabiles(lFechaAux1, 3, lFDesde); 
   }else{
      $EXECUTE selMinGen INTO :lFechaAux USING  :reg->sucursal,
                                                :reg->sector,
                                                :reg->zona,
                                                :lFechaPivote2;
   
      if(SQLCODE != 0){
         printf("No se encontro Agenda para para Suc.%s Sector %ld Zona %ld F.Pivote %ld UL\n", reg->sucursal, reg->sector, reg->zona, lFechaPivote);
         return 0;
      }
      lFechaAux=lFechaAux-420; // Le resto 14 meses 
      lFDesde = lFechaAux-100;
                                                                  
      lFechaAux1 = RestarDiasHabiles(lFechaAux, 1, lFDesde);
      lFechaAux2 = RestarDiasHabiles(lFechaAux1, 3, lFDesde); 
   }
   */
   
   iDiffer = lFechaAux1 - lFechaAux2;
   
   reg->eper_abl = iDiffer;

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

