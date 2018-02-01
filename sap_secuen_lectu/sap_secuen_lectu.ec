/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_secuen_lectu
    
	Fecha : 29/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura SECUENCIA DE LECTURA
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_secuen_lectu.h";

/* Variables Globales */
$char	gsTipoGenera[2];

char	sArchSecuenLectuUnx[100];
char	sArchSecuenLectuDos[100];
char	sSoloArchivoSecuenLectu[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;
FILE	*pFileSecuenLectuUnx;
long	cantProcesada;
long 	cantPreexistente;

/* Variables Globales Host */
$ClsSecuLectu	regSecuen;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fp;
int		iFlagMigra=0;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
	/*$BEGIN WORK;*/

	EXEC SQL SELECT c.sucursal,
		c.sector, 
		c.zona, 
		c.correlativo_ruta,
		c.numero_cliente, 
		s.cod_ul_sap || 
		lpad(case when c.sector>60 and c.sector < 81 then c.sector else c.sector end, 2, 0) || 
		lpad(c.zona,5,0) unidad_lectura,
		'T1' || m.numero_medidor || m.marca_medidor || m.modelo_medidor aparato
		FROM cliente c, sucur_centro_op s, medid m, migra_activos ma 
		WHERE c.estado_cliente = 0 
		AND c.tipo_sum != 5 
		AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm
			WHERE cm.numero_cliente = c.numero_cliente
			AND cm.fecha_activacion < TODAY
			AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY))
		AND c.sector BETWEEN 41 AND 82
		AND s.cod_centro_op = c.sucursal
		AND m.numero_cliente = c.numero_cliente 
		AND m.estado = 'I'
      AND ma.numero_cliente = c.numero_cliente 

		INTO TEMP tempo1 WITH NO log;

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
/*
	$EXECUTE insTemporal;
*/
	$OPEN curSecuen;

	fp=pFileSecuenLectuUnx;

	while(LeoSecuencia(&regSecuen)){
		if (!GenerarPlano(fp, regSecuen)){
			/*$ROLLBACK WORK;*/
			exit(1);	
		}
		cantProcesada++;
	}
	
	$CLOSE curSecuen;
			
	CerrarArchivos();

	/* Registrar Control Plano */
/*   
	if(!RegistraArchivo()){
		$ROLLBACK WORK;
		exit(1);
	}
*/	
	/*$COMMIT WORK;*/

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

	if(argc != 3){
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
	
	memset(sArchSecuenLectuUnx,'\0',sizeof(sArchSecuenLectuUnx));
	memset(sArchSecuenLectuDos,'\0',sizeof(sArchSecuenLectuDos));
	memset(sSoloArchivoSecuenLectu,'\0',sizeof(sSoloArchivoSecuenLectu));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );
	
	lCorrelativo = getCorrelativo("SECUENLEC");
	
	alltrim(sPathSalida,' ');

	sprintf( sArchSecuenLectuUnx  , "%sSecuenLectu_T1_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativo );
	sprintf( sArchSecuenLectuDos  , "%sSecuenLectu_T1_%s_%d.txt", sPathSalida, FechaGeneracion, lCorrelativo );
	sprintf( sSoloArchivoSecuenLectu, "SecuenLectu_T1_%s_%d.txt", FechaGeneracion, lCorrelativo );

	pFileSecuenLectuUnx=fopen( sArchSecuenLectuUnx, "w" );
	if( !pFileSecuenLectuUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchSecuenLectuUnx );
		return 0;
	}
	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileSecuenLectuUnx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
   memset(sPathCp, '\0', sizeof(sPathCp));

   strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");
   
	sprintf(sCommand, "chmod 755 %s", sArchSecuenLectuUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchSecuenLectuUnx, sPathCp);
	iRcv=system(sCommand);		

	sprintf(sCommand, "rm -f %s", sArchSecuenLectuUnx);
	iRcv=system(sCommand);	
   
/*
	if(cantProcesada>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchSecuenLectuUnx, sArchSecuenLectuDos);
		iRcv=system(sCommand);
	}

	sprintf(sCommand, "rm -f %s", sArchSecuenLectuUnx);
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

	/******** carga temporal ***********/
/*
	strcpy(sql, "SELECT c.sucursal, ");
	strcat(sql, "c.sector, ");
	strcat(sql, "c.zona, ");
	strcat(sql, "c.correlativo_ruta, ");
	strcat(sql, "c.numero_cliente, ");
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "lpad(case when c.sector>60 and c.sector < 81 then c.sector-20 else c.sector end, 2, 0)|| "); 
	strcat(sql, "lpad(c.zona,5,0) unidad_lectura, ");
	strcat(sql, "'T1' || m.numero_medidor || m.marca_medidor || m.modelo_medidor aparato ");
	strcat(sql, "FROM cliente c, sucur_centro_op s, medid m ");
	strcat(sql, "WHERE c.estado_cliente = 0 ");
	strcat(sql, "AND c.sector BETWEEN 41 AND 82 ");
	strcat(sql, "AND s.cod_centro_op = c.sucursal ");
	strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND m.estado = 'I' ");
	strcat(sql, "INTO TEMP tempo1 WITH NO log; ");
	
	$PREPARE insTemporal FROM $sql;
*/
	/******** Cursor Principal  ****************/	
	strcpy(sql, "SELECT sucursal, ");
	strcat(sql, "sector, ");
	strcat(sql, "zona, ");
	strcat(sql, "correlativo_ruta, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "unidad_lectura, "); 
	strcat(sql, "aparato ");
	strcat(sql, "FROM tempo1 ");
	strcat(sql, "ORDER BY 1,2,3,4 ");
	
	$PREPARE selSecuen FROM $sql;
	
	$DECLARE curSecuen CURSOR FOR selSecuen;	

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
	strcat(sql, "'SECUENLEC', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, -1, ?) ");
	
	$PREPARE insGenSecuen FROM $sql;
	
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

short LeoSecuencia(regSecu)
$ClsSecuLectu *regSecu;
{
	InicializaSecuencia(regSecu);

	$FETCH curSecuen into
		:regSecu->sucursal,
		:regSecu->sector,
		:regSecu->zona,
		:regSecu->correlativo_ruta,
		:regSecu->numero_cliente,
		:regSecu->unidad_lectura,
		:regSecu->aparato;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de SECUENCIA !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regSecu->unidad_lectura, ' ');
	alltrim(regSecu->aparato, ' ');
	
	return 1;	
}

void InicializaSecuencia(regSecu)
$ClsSecuLectu	*regSecu;
{

	memset(regSecu->sucursal, '\0', sizeof(regSecu->sucursal));
	rsetnull(CINTTYPE, (char *) &(regSecu->sector));
	rsetnull(CINTTYPE, (char *) &(regSecu->zona));
	rsetnull(CLONGTYPE, (char *) &(regSecu->correlativo_ruta));
	rsetnull(CLONGTYPE, (char *) &(regSecu->numero_cliente));
	memset(regSecu->unidad_lectura, '\0', sizeof(regSecu->unidad_lectura));
	memset(regSecu->aparato, '\0', sizeof(regSecu->aparato));
	
}



short GenerarPlano(fp, regSecu)
FILE 				*fp;
$ClsSecuLectu		regSecu;
{

	/* EMG_SR_ABLEINH */	
	GeneraMRU(fp, regSecu);

	/* EMG_SR_EQUNR */	
	GeneraEQUNR(fp, regSecu);	
	
	/* ENDE */
	GeneraENDE(fp, regSecu);
	
	return 1;
}

void GeneraENDE(fp, regSecu)
FILE *fp;
$ClsSecuLectu	regSecu;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regSecu.numero_cliente);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "SECUENLEC");
		strcpy(sNombreArchivo, sSoloArchivoSecuenLectu);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenSecuen using
				:gsTipoGenera,
				:lCantidad,
				:sNombreArchivo;
	}
	
	return 1;
}

void GeneraMRU(fp, regSecu)
FILE 		*fp;
ClsSecuLectu	regSecu;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld\tMRU\t", regSecu.numero_cliente);
	sprintf(sLinea, "%s%s", sLinea, regSecu.unidad_lectura);
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}

void GeneraEQUNR(fp, regSecu)
FILE 			*fp;
ClsSecuLectu	regSecu;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tEQUNR\t", regSecu.numero_cliente);
	sprintf(sLinea, "%s%s", sLinea, regSecu.aparato);

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


