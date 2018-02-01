/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_aparatos
    
	Fecha : 28/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura APARATOS (medidores)
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_devinforecord.h";

/* Variables Globales */
$char	gsTipoGenera[2];

FILE  *pFileMedInstalUnx;
FILE  *pFileMedNoInstalUnx;
FILE  *pFileMedExtInstalUnx;
FILE  *pFileMedExtNoInstalUnx;

FILE  *pFileLog;

char	sArchMedInstalUnx[100];
char	sSoloArchivoMedInstalUnx[100];
char	sArchMedNoInstalUnx[100];
char	sSoloArchivoMedNoInstalUnx[100];

char	sArchMedExtInstal[100];
char	sArchMedExtNoInstal[100];

char  sArchivoLog[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantInstalados;
long 	cantNoInstalados;
long	iContaLog;

/* Variables Globales Host */
$ClsMedidor	regMedidor;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fp;
int	iFlagMigra=0;
int 	iFlagEmpla=0;
long  lContador;
int   iIndice;

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
   
	/*$BEGIN WORK;*/

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantInstalados=0;
	cantNoInstalados=0;
	iContaLog=0;
	
   memset(FechaGeneracion, '\0', sizeof(FechaGeneracion));
      
   FechaGeneracionFormateada(FechaGeneracion);
   
	/*********************************************
				AREA CURSORes PPALes
	**********************************************/

   /* Hago el de instalados */
	$OPEN curInstal;

	fp=pFileMedInstalUnx;
   lContador=0;
   iIndice=1;

   if(!AbreArchivosInst(iIndice)){
      exit(1);
   }   
	while(LeoMedidores(1, &regMedidor)){
      GenerarPlanoMed(pFileMedInstalUnx, regMedidor);
      
      iFlagEmpla=CargaEmplazamiento(&regMedidor);
     
      if(iFlagEmpla != 0 ){
		 GenerarPlanoExt(pFileMedExtInstalUnx, regMedidor);
      }
					
		cantInstalados++;
      lContador++;
      if(lContador >= 900000){
         fclose(pFileMedInstalUnx);
         fclose(pFileMedExtInstalUnx);
         iIndice++;
         lContador=0;
         
         if(!AbreArchivosInst(iIndice)){
            exit(1);
         }   
      }
	}
   	
	$CLOSE curInstal;
			
   fclose(pFileMedInstalUnx);
   fclose(pFileMedExtInstalUnx);

   /* Hago el de NO instalados */
   
   $OPEN curNoInstal;
   
   fp=pFileMedNoInstalUnx;
   
	while(LeoMedidores(2, &regMedidor)){
   
      if(DentroRango(regMedidor)){
         
         GenerarPlanoMed(fp, regMedidor);

         iFlagEmpla=CargaEmplazamiento(&regMedidor);
        
         if(iFlagEmpla != 0 ) 
   		 GenerarPlanoExt(pFileMedExtNoInstalUnx, regMedidor);
   					
   		cantNoInstalados++;
      }
	}
   
   $CLOSE curNoInstal;

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

	FormateaArchivos(iIndice);

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
	printf("APARATOS\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Medidores Instalados Procesados :    %ld \n",cantInstalados);
   printf("Medidores No Instalados Procesados : %ld \n",cantNoInstalados);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	if(iContaLog>0){
		printf("Existen registros en el archivo de log.\nFavor de revisar.\n");	
	}
	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{

	if(argc != 3 ){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	strcpy(gsTipoGenera, argv[2]);
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
}

short AbreArchivos()
{
   
   memset(sArchMedNoInstalUnx, '\0', sizeof(sArchMedNoInstalUnx));
   memset(sArchMedExtNoInstal, '\0', sizeof(sArchMedExtNoInstal));
   memset(sArchivoLog, '\0', sizeof(sArchivoLog));
	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );

	/*lCorrelativo = getCorrelativo("APARATO");*/
	
	alltrim(sPathSalida,' ');


   /* De los medidores no instalados */
	sprintf( sArchMedNoInstalUnx  , "%sT1DEVINFORECORD_noinstal.unx", sPathSalida );
   
	pFileMedNoInstalUnx=fopen( sArchMedNoInstalUnx, "w" );
	if( !pFileMedNoInstalUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedNoInstalUnx );
		return 0;
	}
   
   /* De la extension no instalados */
	sprintf( sArchMedExtNoInstal  , "%sT1ZModifEquipos_noinstal.unx", sPathSalida);

	pFileMedExtNoInstalUnx=fopen( sArchMedExtNoInstal, "w" );
	if( !pFileMedExtNoInstalUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedExtNoInstal );
		return 0;
	}
   
   /* de Log */
	sprintf( sArchivoLog  , "%sT1ZModifEquipos.log", sPathSalida);

	pFileLog=fopen( sArchivoLog, "w" );
	if( !pFileLog ){
		printf("ERROR al abrir archivo %s.\n", sArchivoLog );
		return 0;
	}
   
   
	return 1;	
}

short AbreArchivosInst(indice)
int      indice;
{
   memset(sArchMedInstalUnx, '\0', sizeof(sArchMedInstalUnx));
   memset(sSoloArchivoMedInstalUnx, '\0', sizeof(sSoloArchivoMedInstalUnx));
   memset(sArchMedExtInstal, '\0', sizeof(sArchMedExtInstal));

   /* De los medidores instalados */
	sprintf( sArchMedInstalUnx  , "%sT1DEVINFORECORD_instal_%d.unx", sPathSalida, indice );
   sprintf( sSoloArchivoMedInstalUnx  , "T1DEVINFORECORD_instal_%d.unx", indice);
   
	pFileMedInstalUnx=fopen( sArchMedInstalUnx, "w" );
	if( !pFileMedInstalUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedInstalUnx );
		return 0;
	}

   /* De la extension instalados */
	sprintf( sArchMedExtInstal  , "%sT1ZModifEquipos_instal_%d.unx", sPathSalida, indice);

	pFileMedExtInstalUnx=fopen( sArchMedExtInstal, "w" );
	if( !pFileMedExtInstalUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedExtInstal );
		return 0;
	}

   return 1;
}

void CerrarArchivos(void)
{
   
   fclose(pFileMedNoInstalUnx);
   fclose(pFileMedExtNoInstalUnx);
 
}

void FormateaArchivos(indice)
int   indice;
{
char	sCommand[1000];
int	iRcv, i;
char	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
	
	strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");

   /* Los Instalados */
   for(i=1; i <= indice; i++){
      sprintf( sArchMedInstalUnx  , "%sT1DEVINFORECORD_instal_%d.unx", sPathSalida, i);
      sprintf( sArchMedExtInstal  , "%sT1ZModifEquipos_instal_%d.unx", sPathSalida, i);
      
   	sprintf(sCommand, "chmod 755 %s", sArchMedInstalUnx);
   	iRcv=system(sCommand);
   
   	sprintf(sCommand, "cp %s %s", sArchMedInstalUnx, sPathCp);
   	iRcv=system(sCommand);
   
      /***********/
   	sprintf(sCommand, "chmod 755 %s", sArchMedExtInstal);
   	iRcv=system(sCommand);
   
   	sprintf(sCommand, "cp %s %s", sArchMedExtInstal, sPathCp);
   	iRcv=system(sCommand);

   }
   
   /* Los No Instalados */
   /***********/
	sprintf(sCommand, "chmod 755 %s", sArchMedNoInstalUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "cp %s %s", sArchMedNoInstalUnx, sPathCp);
	iRcv=system(sCommand);
   
   /***********/
	sprintf(sCommand, "chmod 755 %s", sArchMedExtNoInstal);
	iRcv=system(sCommand);

	sprintf(sCommand, "cp %s %s", sArchMedExtNoInstal, sPathCp);
	iRcv=system(sCommand);


/*
	if(cantInstalados>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchMedidorUnx, sArchMedidorDos);
		iRcv=system(sCommand);
	}

	sprintf(sCommand, "rm -f %s", sArchMedidorUnx);
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

   /************ Cursor Instalados ************/
   strcpy(sql, "SELECT mi.numero_medidor, ");
   strcat(sql, "mi.marca_medidor, ");
   strcat(sql, "mi.modelo_medidor, ");
   strcat(sql, "mi.numero_cliente, ");
   strcat(sql, "NVL(mi.tipo_medidor, 'A'), ");
   strcat(sql, "mi.enteros, ");
   strcat(sql, "mi.decimales, ");
   strcat(sql, "md.med_anio, ");
   strcat(sql, "md.med_factor, ");
   
   strcat(sql, "md.med_precinto1, ");
   strcat(sql, "md.med_precinto2, ");
   strcat(sql, "md.cla_codigo, ");
   strcat(sql, "fc.fun_fase, ");

	strcat(sql, "md.med_ubic, ");
	strcat(sql, "md.med_codubic, ");
/*   
   strcat(sql, "f.fab_nombre[1,30] ");
*/   
   strcat(sql, "f.fab_codigo ");
   strcat(sql, "FROM medid mi, medidor md, config c, funcionamiento fc ");
   
   strcat(sql, ", medidores@medidor_test:marca ma ");
   strcat(sql, ", medidores@medidor_test:fabricante f ");

strcat(sql, ", migra_activos mac ");
   
   strcat(sql, "WHERE mi.estado = 'I' ");
/*
   strcat(sql, "AND mi.numero_medidor = 37124714 ");
   strcat(sql, "AND mi.marca_medidor = 'AMP' ");
   strcat(sql, "AND mi.modelo_medidor = '03' ");
*/   
   strcat(sql, "AND md.med_numero = mi.numero_medidor ");
   strcat(sql, "AND md.mar_codigo = mi.marca_medidor ");
   strcat(sql, "AND md.mod_codigo = mi.modelo_medidor ");

	strcat(sql, "AND c.mar_codigo = md.mar_codigo ");
	strcat(sql, "AND c.mod_codigo = md.mod_codigo ");
	strcat(sql, "AND fc.fun_codigo = c.fun_codigo ");
   
	strcat(sql, "AND ma.mar_codigo = md.mar_codigo ");
	strcat(sql, "AND f.fab_codigo = ma.fab_codigo ");
   
strcat(sql, "AND mac.numero_cliente = mi.numero_cliente ");

   $PREPARE selMedInstal FROM $sql;
   
   $DECLARE curInstal CURSOR WITH HOLD FOR selMedInstal;
   	
   /************ Cursor NO instalados ***********/
   strcpy(sql, "SELECT mi.numero_medidor, ");
   strcat(sql, "mi.marca_medidor, ");
   strcat(sql, "mi.modelo_medidor, ");
   strcat(sql, "NVL(mi.numero_cliente, 0), ");
   strcat(sql, "mi.tipo_medidor, ");
   strcat(sql, "mi.enteros, ");
   strcat(sql, "mi.decimales, ");
   strcat(sql, "md.med_anio, ");
   strcat(sql, "md.med_factor, ");
   strcat(sql, "md.med_precinto1, ");
   strcat(sql, "md.med_precinto2, ");
   strcat(sql, "md.cla_codigo, ");
   strcat(sql, "fc.fun_fase, ");
	strcat(sql, "md.med_ubic, ");
	strcat(sql, "md.med_codubic, ");
   strcat(sql, "f.fab_nombre[1,30] ");
   
   strcat(sql, "FROM medid mi, medidor md, config c, funcionamiento fc ");

   strcat(sql, ", medidores@medidor_test:marca ma ");
   strcat(sql, ", medidores@medidor_test:fabricante f ");

   strcat(sql, "WHERE (mi.estado !='I' OR mi.estado IS NULL) ");
   strcat(sql, "AND md.med_numero = mi.numero_medidor ");
   strcat(sql, "AND md.mar_codigo = mi.marca_medidor ");
   strcat(sql, "AND md.mod_codigo = mi.modelo_medidor ");
   /*strcat(sql, "AND md.med_estado != 'Z' ");*/
   strcat(sql, "AND md.mar_codigo NOT IN ('000', 'AGE') ");
   strcat(sql, "AND md.med_anio != 2019 "); 

	strcat(sql, "AND c.mar_codigo = md.mar_codigo ");
	strcat(sql, "AND c.mod_codigo = md.mod_codigo ");
	strcat(sql, "AND fc.fun_codigo = c.fun_codigo ");

	strcat(sql, "AND ma.mar_codigo = md.mar_codigo ");
	strcat(sql, "AND f.fab_codigo = ma.fab_codigo ");

   $PREPARE selMedNoInstal FROM $sql;
   
   $DECLARE curNoInstal CURSOR FOR selMedNoInstal;
   
	/********* Buscar Movimientos ***********/
	strcpy(sql, "SELECT COUNT(*) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND numero_medidor = ? ");
	strcat(sql, "AND marca_medidor = ? ");
	strcat(sql, "AND fecha_lectura >= TODAY - 365 ");
   
   $PREPARE selMovimientos FROM $sql;   
   
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/******** Emplazamiento Cliente  *********/	
	strcpy(sql, "SELECT sc.cod_sap ");
	strcat(sql, "FROM cliente c, sap_transforma sc ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND sc.clave = 'CENTROEMPLA' ");
	strcat(sql, "AND sc.cod_mac = c.sucursal ");

	$PREPARE selEmplaClie FROM $sql;

	/******** Emplazamiento Bodega  *********/	
	strcpy(sql, "SELECT sc.cod_sap ");
	strcat(sql, "FROM  sap_transforma sc ");
	strcat(sql, "WHERE sc.clave = 'CENTROEMPLA' ");
	strcat(sql, "AND sc.cod_mac = ? ");
	
	$PREPARE selCentroEmpla FROM $sql;
	
	/******** Emplazamiento Bodega  *********/	
	strcpy(sql, "SELECT sc.cod_sap ");
	strcat(sql, "FROM  sap_transforma sc ");
	strcat(sql, "WHERE sc.clave = 'CTROCONTRAT23' ");
	strcat(sql, "AND sc.cod_mac = ? ");
		
	$PREPARE selCentroEmplaT23 FROM $sql;


	/******** Select Correlativo ****************/
	strcpy(sql, "SELECT correlativo +1 FROM sap_gen_archivos ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	$PREPARE selCorrelativo FROM $sql;

	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	$PREPARE updGenArchivos FROM $sql;
		
	/******** Insert gen_archivos ****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'APARATO', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, -1, ?) ");
	
	$PREPARE insGenAparato FROM $sql;
	
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

short LeoMedidores(iTipo, regMed)
int         iTipo;
$ClsMedidor *regMed;
{
	InicializaMedidor(regMed);

   if(iTipo==1){
      $FETCH curInstal INTO
         :regMed->numero_medidor,
         :regMed->marca_medidor,
         :regMed->modelo_medidor,
         :regMed->numero_cliente,
         :regMed->tipo_medidor,
         :regMed->enteros,
         :regMed->decimales,
         :regMed->med_anio,
         :regMed->med_factor,
         :regMed->med_precinto1,
         :regMed->med_precinto2,
         :regMed->med_clase,
         :regMed->med_fase,
         :regMed->med_ubic,
         :regMed->med_codubic,
         :regMed->cod_fabricante;
         /*:regMed->fabricante;*/
   }else{
      $FETCH curNoInstal INTO
         :regMed->numero_medidor,
         :regMed->marca_medidor,
         :regMed->modelo_medidor,
         :regMed->numero_cliente,
         :regMed->tipo_medidor,
         :regMed->enteros,
         :regMed->decimales,
         :regMed->med_anio,
         :regMed->med_factor,
         :regMed->med_precinto1,
         :regMed->med_precinto2,
         :regMed->med_clase,
         :regMed->med_fase,
         :regMed->med_ubic,
         :regMed->med_codubic,
         :regMed->fabricante;
   }
	
   if ( SQLCODE != 0 ){
      if(SQLCODE == 100){
      	return 0;
      }else{
      	printf("Error al leer Cursor de Medidores !!!\nProceso Abortado.\n");
      	exit(1);	
      }
   }			

	alltrim(regMed->med_precinto1, ' ');
	alltrim(regMed->med_precinto2, ' ');
	alltrim(regMed->med_clase, ' ');
	alltrim(regMed->med_fase, ' ');
	alltrim(regMed->med_ubic, ' ');
	alltrim(regMed->med_codubic, ' ');
   alltrim(regMed->fabricante, ' ');
	
	return 1;	
}

void InicializaMedidor(regMed)
$ClsMedidor	*regMed;
{

   rsetnull(CLONGTYPE, (char *) &(regMed->numero_medidor));
   memset(regMed->marca_medidor, '\0', sizeof(regMed->marca_medidor));
   memset(regMed->modelo_medidor, '\0', sizeof(regMed->modelo_medidor));
   rsetnull(CLONGTYPE, (char *) &(regMed->numero_cliente));
   memset(regMed->tipo_medidor, '\0', sizeof(regMed->tipo_medidor));
   rsetnull(CINTTYPE, (char *) &(regMed->enteros));
   rsetnull(CINTTYPE, (char *) &(regMed->decimales));
   rsetnull(CINTTYPE, (char *) &(regMed->med_anio));
   rsetnull(CFLOATTYPE, (char *) &(regMed->med_factor));
	memset(regMed->med_precinto1, '\0', sizeof(regMed->med_precinto1));
	memset(regMed->med_precinto2, '\0', sizeof(regMed->med_precinto2));
	memset(regMed->med_clase, '\0', sizeof(regMed->med_clase));
	memset(regMed->med_fase, '\0', sizeof(regMed->med_fase));
	memset(regMed->med_ubic, '\0', sizeof(regMed->med_ubic));
	memset(regMed->med_codubic, '\0', sizeof(regMed->med_codubic));
   memset(regMed->fabricante, '\0', sizeof(regMed->fabricante));
	
}


void GenerarPlanoMed(fp, regMed)
FILE 				*fp;
$ClsMedidor			regMed;
{

	/* DVMINT */	
	GeneraDVMINT(fp, regMed);

	/* DVMDEV */
	GeneraDVMDEV(fp, regMed);

	/* DVMDFL */
	GeneraDVMDFL(fp, regMed);

	
	/* DVMREG */	
	GeneraDVMREG(fp, "A", 1, regMed);
   
   GeneraDVMREG(fp, "A", 2, regMed);
   
   if(regMed.tipo_medidor[0]=='R'){
   
   	GeneraDVMREG(fp, "R", 3, regMed);
      
      GeneraDVMREG(fp, "R", 4, regMed);
   }

	/* DVMRFL */	
	GeneraDVMRFL(fp, "A", 1, regMed);
   
   GeneraDVMRFL(fp, "A", 2, regMed);
   
   if(regMed.tipo_medidor[0]=='R'){
   
   	GeneraDVMRFL(fp, "R", 3, regMed);
      
      GeneraDVMRFL(fp, "R", 4, regMed);
   }

	
   /* DVMABL */
   GeneraDVMABL(fp, "A", 1, regMed);
   
   GeneraDVMABL(fp, "A", 2, regMed);

   
   if(regMed.tipo_medidor[0]=='R'){
   
   	GeneraDVMABL(fp, "R", 3, regMed);
      
      GeneraDVMABL(fp, "R", 4, regMed);
   }
   
	/* ENDE */
	GeneraENDE(fp, regMed);
}

void GeneraENDE(fp, regMed)
FILE *fp;
$ClsMedidor	regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld%s%s\t&ENDE", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantInstalados > 0){
		strcpy(sTipoArchivo, "APARATO");
		strcpy(sNombreArchivo, sSoloArchivoMedInstalUnx);
		lCantidad=cantInstalados;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenAparato using
				:gsTipoGenera,
				:lCantidad,
				:sNombreArchivo;
	}
	
	return 1;
}


void GeneraDVMINT(fp, regMed)
FILE 		*fp;
ClsMedidor	regMed;
{
	char	sLinea[1000];	
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

	if(regMed.med_anio==0)
		regMed.med_anio=1900;
		
	sprintf(sLinea, "T1%ld%s%s\tDVMINT\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

   /* KEYDATE */
   /*sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);*/
   sprintf(sLinea, "%s%ld0101\t", sLinea, regMed.med_anio);
   
   /* SPARTE */
   strcat(sLinea, "01\t");
   
   /* MATNR */
   sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* GERAET */
   sprintf(sLinea, "%s%ld", sLinea, regMed.numero_medidor);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir DVMINT\n");
      exit(1);
   }	
   	
	
}

void GeneraDVMDEV(fp, regMed)
FILE 			*fp;
ClsMedidor		regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tDVMDEV\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* SPARTE */
   strcat(sLinea, "01\t");
   
   /* BIS */
   strcat(sLinea, "99991231\t");
   
   /* AB */
   sprintf(sLinea, "%s%ld0101\t", sLinea, regMed.med_anio);
   
   /* GERAET */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.numero_medidor);
   
   /* ZWGRUPPE */
   if(regMed.tipo_medidor[0]=='R'){
      strcat(sLinea, "LECDER02\t");
   }else{
      strcat(sLinea, "LECDER01\t");
   }
   
   /* MATNR */
   sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* EGGER_INFO */
   strcat(sLinea, "\t");
   
   /* BEGRU */
   strcat(sLinea, "T1\t");
   
   /* Z_HERST*/
   /*sprintf(sLinea, "%s%s", sLinea, regMed.fabricante);*/
   sprintf(sLinea, "%s%s", sLinea, regMed.marca_medidor);   	
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);

   if(iRcv < 0){
      printf("Error al escribir DVMDEV\n");
      exit(1);
   }	

}

void GeneraDVMDFL(fp, regMed)
FILE 			*fp;
ClsMedidor		regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tDVMDFL\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

   /* BIS */
   strcat(sLinea, "99991231\t");
   
   /* AB */
   sprintf(sLinea, "%s%ld0101\t", sLinea, regMed.med_anio);
   
   /* GERAET */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.numero_medidor);
   
   /* MATNR */
   sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* ZWGRUPPE */
   strcat(sLinea,"X\t");
   
   /* EGERR_INFO */
   strcat(sLinea,"X\t");
   
   /* BEGRU */
   strcat(sLinea,"X\t");
   
   /* Z_HERST */
   strcat(sLinea,"X");

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   
   if(iRcv < 0){
      printf("Error al escribir DVMDFL\n");
      exit(1);
   }	
   
}



void GeneraDVMREG(fp, cTipoMed, iTipoReg, regMed)
FILE 			*fp;
char        cTipoMed[2];
int         iTipoReg;
ClsMedidor		regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tDVMREG\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

   /* GERAET */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.numero_medidor);
   
   /* MATNR */
   sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* ZWNUMMER */
   sprintf(sLinea, "%s00%d\t", sLinea, iTipoReg);
   
   /* BIS */
   strcat(sLinea, "99991231\t");
   
   /* AB */
   sprintf(sLinea, "%s%ld0101\t", sLinea, regMed.med_anio);
   
   /* ZWNABR */
   if(cTipoMed[0]=='A'){
      if(iTipoReg==1){
         strcat(sLinea, "X\t");
      }else{
         strcat(sLinea, "\t");
      }
   }else{
      if(iTipoReg==3){
         strcat(sLinea, "X\t");
      }else{
         strcat(sLinea, "\t");
      }
   } 
     
   /* ZWKENN vacio*/
   strcat(sLinea, "\t");
   
   /* STANZVOR */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.enteros);
   
   /* STANZNAC */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.decimales);
   
   /* ZWFAKT */
   sprintf(sLinea, "%s%.02f\t", sLinea, regMed.med_factor);
   
   /* MEINS */
   strcat(sLinea, "kWh\t");
   
   /* BLIWIRK vacio */
   strcat(sLinea, "\t");
   
   /* ZWTYP vacio */
   	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir DVMREG\n");
      exit(1);
   }	

}


void GeneraDVMRFL(fp, cTipoMed, iTipoReg, regMed)
FILE 			*fp;
char        cTipoMed[2];
int         iTipoReg;
ClsMedidor		regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tDVMRFL\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

   /* BIS */
   strcat(sLinea, "99991231\t");
   
   /* AB */
   sprintf(sLinea, "%s%ld0101\t", sLinea, regMed.med_anio);
   
   /* GERAET */
   sprintf(sLinea, "%s%ld\t", sLinea, regMed.numero_medidor);

   /* MATNR */
   sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca_medidor, regMed.modelo_medidor);
   
   /* ZWNUMMER */
   sprintf(sLinea, "%s00%d\t", sLinea, iTipoReg);
   
   /* ZWKENN Vacio */
   strcat(sLinea, "\t");
   
   /* STANZVOR */
   strcat(sLinea, "X\t");
   
   /* STANZNAC */
   strcat(sLinea, "X\t");
   
   /* ZWFAKT */
   strcat(sLinea, "X\t");
   
   /* MEINS */
   strcat(sLinea, "X\t");
   
   /* BLIWIRK Vacio*/
   strcat(sLinea, "\t");
   
   /* ZWTYP Vacio */

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir DVMRFL\n");
      exit(1);
   }	
   
}


void GeneraDVMABL(fp, cTipoMed, iTipoReg, regMed)
FILE 			*fp;
char        cTipoMed[2];
int         iTipoReg;
ClsMedidor		regMed;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tDVMABL\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);

   /* ZWNUMMER */
   sprintf(sLinea, "%s00%d\t", sLinea, iTipoReg);
   
   /* ZWSTAND */
   strcat(sLinea, "0\t");
   
   /* ADAT */
   sprintf(sLinea, "%s%ld0101", sLinea, regMed.med_anio);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir DVMABL\n");
      exit(1);
   }	
   
}


void GenerarPlanoExt(fp, regMed)
FILE 				*fp;
$ClsMedidor			regMed;
{

	/* EQUI */	
	GeneraEQUI(fp, regMed);

}

void GeneraEQUI(fp, regMed)
FILE 		*fp;
ClsMedidor	regMed;
{
	char	sLinea[1000];	
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

		
	sprintf(sLinea, "T1%ld%s%s\tEQUI\t", regMed.numero_medidor, regMed.marca_medidor, regMed.modelo_medidor);
	
	if(strcmp(regMed.med_precinto1, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regMed.med_precinto1);
	}
	if(strcmp(regMed.med_precinto2, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regMed.med_precinto2);
	}

	strcat(sLinea,"\t"); /* precinto 3*/
	strcat(sLinea,"\t"); /* precinto 4*/
	strcat(sLinea,"\t"); /* precinto 5*/
	
	if(strcmp(regMed.med_clase, "")==0){
		strcat(sLinea, "\t");	
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regMed.med_clase);
	}

	if(strcmp(regMed.med_fase, "")!=0){
		if(regMed.med_fase[0]=='M'){
			strcat(sLinea, "Monofásico");
		}else{
			strcat(sLinea, "Trifásico");
		}
	}

	sprintf(sLinea, "\t%s", regMed.emplazamiento);
				
	strcat(sLinea, "\n");
	
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir EQUI\n");
      exit(1);
   }	
	
}


short DentroRango(regMed)
$ClsMedidor  regMed;
{
   $int  iCant;
   
   if(regMed.numero_cliente <= 0)
      return 0;
      
   iCant=0;
   
   $EXECUTE selMovimientos INTO :iCant
      USING :regMed.numero_cliente,
            :regMed.numero_medidor,
            :regMed.marca_medidor;
             
   if(SQLCODE != 0 )
      return 0;
                   
   if(iCant <= 0)
      return 0;

   return 1;
}

short CargaEmplazamiento(regMed)
$ClsMedidor *regMed;
{
	$char	sCodigo[11];
	$int	iCodigo;
	char	sMensaje[1000];
	
	memset(sCodigo, '\0', sizeof(sCodigo));
	memset(sMensaje, '\0', sizeof(sMensaje));
	
	switch(regMed->med_ubic[0]){
		case 'C':	/* En el cliente*/
			$EXECUTE selEmplaClie into :sCodigo using :regMed->numero_cliente;
				
			if(SQLCODE != 0){
				if(SQLCODE == SQLNOTFOUND){
					sprintf(sMensaje, "No se encontró emplazamiento para Medidor de Cliente %ld ", regMed->numero_cliente);
					sprintf(sMensaje, "%s Medidor %ld %s %s\n", sMensaje, regMed->numero_medidor, regMed->marca_medidor, regMed->modelo_medidor);
					strcpy(sCodigo, "XXXX");
					fprintf(pFileLog, sMensaje);
					return 2;
				}else{
					sprintf(sMensaje, "ERROR al buscar emplazamiento de Medidor para Cliente %ld\n", regMed->numero_cliente);
					fprintf(pFileLog, sMensaje);
					return 0;
				}
				iContaLog++;
			}
			alltrim(sCodigo, ' ');
			strcpy(regMed->emplazamiento, sCodigo);
			
			break;
			
		case 'D':  /* Bodega o Laboratorio*/
		case 'L':
			strcpy(regMed->emplazamiento, "0080");
			break;
			
		case 'O':  /* Contratista */
			sprintf(sCodigo, "0%c%c%c", regMed->med_codubic[3], regMed->med_codubic[4], regMed->med_codubic[5]);
			alltrim(sCodigo, ' ');
			
			if(strcmp(sCodigo, "0T23")!= 0){
				if(strcmp(sCodigo, "0030")==0 || strcmp(sCodigo, "0040")==0 || strcmp(sCodigo, "0060")==0){
					strcpy(regMed->emplazamiento, sCodigo);
				}else{
					strcpy(regMed->emplazamiento, getEmplazaSAP(sCodigo));
				}
			}else{
				memset(sCodigo, '\0', sizeof(sCodigo));
				sprintf(sCodigo, "%c%c%c", regMed->med_codubic[0], regMed->med_codubic[1], regMed->med_codubic[2]);
				strcpy(regMed->emplazamiento, getEmplazaT23(sCodigo));
			}
						
			break;
			
		case 'S':	/* En Sucursal */
			iCodigo=atoi(regMed->med_codubic);
			switch(iCodigo){
				case 500: /* Confirmar que hacemos con este */
					strcpy(regMed->emplazamiento, "0080");		
					break;
					
				case 501: /* Capital */
					strcpy(regMed->emplazamiento, "0030");
					break;
					
				case 502: /* Roca */
					strcpy(regMed->emplazamiento, "0060");
					break;
					
				case 503: /* Ribera */
					strcpy(regMed->emplazamiento, "0040");
					break;
			}
			
			break;
		case 'F':	/* En Fabrica */
			strcpy(regMed->emplazamiento, "0080");
			break;
	}

	
	return 1;
}

static char *getEmplazaSAP(sCodigo)
char	*sCodigo;
{
	$char sCodMac[5];
	$char sCodSap[5];
	char  sMensaje[1000];
	
	memset(sCodMac, '\0', sizeof(sCodMac));
	memset(sCodSap, '\0', sizeof(sCodSap));
	memset(sMensaje, '\0', sizeof(sMensaje));

	strcpy(sCodMac, sCodigo);
	
	$EXECUTE selCentroEmpla into :sCodSap using :sCodMac;
	
	if(SQLCODE != 0){
		sprintf(sMensaje, "Error al buscar centro emplazamiento SAP para codigo %s\n", sCodMac);
		fprintf(pFileLog, sMensaje);
		strcpy(sCodSap, "0000");
		iContaLog++;
	}
	
	return sCodSap;
}

static char *getEmplazaT23(sCodigo)
char	*sCodigo;
{
	$char sCodMac[5];
	$char sCodSap[5];
	char  sMensaje[1000];
	
	memset(sCodMac, '\0', sizeof(sCodMac));
	memset(sCodSap, '\0', sizeof(sCodSap));
	memset(sMensaje, '\0', sizeof(sMensaje));

	strcpy(sCodMac, sCodigo);
	
	$EXECUTE selCentroEmplaT23 into :sCodSap using :sCodMac;
	
	if(SQLCODE != 0){
		sprintf(sMensaje, "Error al buscar centro emplazamiento SAP para contratista T23 %s\n", sCodMac);
		fprintf(pFileLog, sMensaje);
		strcpy(sCodSap, "0000");
		iContaLog++;
	}
	
	return sCodSap;
	
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


