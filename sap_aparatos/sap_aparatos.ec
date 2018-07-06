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

$include "sap_aparatos.h";

/* Variables Globales */
$char	gsTipoGenera[2];

FILE	*pFileMedidorUnx;
FILE    *pFileMedidorExtUnx;
FILE    *pFileLog;

char	sArchMedidorUnx[100];
char	sArchMedidorExt[100];
char	sSoloArchivoMedidor[100];

char	sArchLog[100];
char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;
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
int		iFlagMigra=0;
int 	iFlagEmpla=0;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
	$BEGIN WORK;

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantPreexistente=0;
	iContaLog=0;
	
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

	$OPEN curMedidores;

	fp=pFileMedidorUnx;

	while(LeoMedidores(&regMedidor)){
		iFlagEmpla=CargaEmplazamiento(&regMedidor);
		
		if(iFlagEmpla==0){
			$ROLLBACK WORK;
			exit(1);				
		}else if(iFlagEmpla==1){
			if (!GenerarPlano(fp, regMedidor)){
				$ROLLBACK WORK;
				exit(1);	
			}

			if (!GenerarPlanoExt(pFileMedidorExtUnx, regMedidor)){
				$ROLLBACK WORK;
				exit(1);	
			}
						
			cantProcesada++;
		}
	}
	
	$CLOSE curMedidores;
			
	CerrarArchivos();

	/* Registrar Control Plano */
	if(!RegistraArchivo()){
		$ROLLBACK WORK;
		exit(1);
	}
	
	$COMMIT WORK;

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
	printf("APARATOS\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Medidores Procesados :       %ld \n",cantProcesada);
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
	
	memset(sArchMedidorUnx,'\0',sizeof(sArchMedidorUnx));
	memset(sArchMedidorExt,'\0',sizeof(sArchMedidorExt));
	memset(sSoloArchivoMedidor,'\0',sizeof(sSoloArchivoMedidor));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );
	
	lCorrelativo = getCorrelativo("APARATO");
	
	alltrim(sPathSalida,' ');

	sprintf( sArchMedidorUnx  , "%sT1DEVICE.unx", sPathSalida );
	sprintf( sArchMedidorExt  , "%sT1ZModifEquipos.unx", sPathSalida);
	strcpy( sSoloArchivoMedidor, "T1DEVICE.unx");

	pFileMedidorUnx=fopen( sArchMedidorUnx, "w" );
	if( !pFileMedidorUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedidorUnx );
		return 0;
	}

	pFileMedidorExtUnx=fopen( sArchMedidorExt, "w" );
	if( !pFileMedidorExtUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedidorExt );
		return 0;
	}
		
	sprintf( sArchLog  , "%sAparato_T1_%s_%d.log", sPathSalida, FechaGeneracion, lCorrelativo );
	pFileLog=fopen( sArchLog, "w" );
	if( !pFileLog ){
		printf("ERROR al abrir archivo %s.\n", sArchLog );
		return 0;
	}	
	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileMedidorUnx);
	fclose(pFileMedidorExtUnx);
	fclose(pFileLog);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
	
	strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");

	sprintf(sCommand, "chmod 755 %s", sArchMedidorUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "chmod 755 %s", sArchMedidorExt);
	iRcv=system(sCommand);
			
	sprintf(sCommand, "cp %s %s", sArchMedidorUnx, sPathCp);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchMedidorExt, sPathCp);
	iRcv=system(sCommand);
	

sArchMedidorExt
/*
	if(cantProcesada>0){
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

	/******** Cursor Principal  SFC *************/
	strcpy(sql, "SELECT me.med_numero, "); 
	strcat(sql, "me.mar_codigo, "); 
	strcat(sql, "me.mod_codigo, "); 
	strcat(sql, "me.med_estado, ");
	strcat(sql, "me.med_ubic, ");
	strcat(sql, "me.med_codubic, ");
	strcat(sql, "me.numero_cliente, ");
	strcat(sql, "mo.tipo_medidor ");
	strcat(sql, "from medidor me, modelo mo ");
	strcat(sql, "WHERE me.med_tarifa = 'T1' "); 
	strcat(sql, "AND me.mar_codigo NOT IN ('000', 'AGE') "); 
	strcat(sql, "AND me.med_anio != 2019 "); 
	strcat(sql, "AND mo.mar_codigo = me.mar_codigo "); 
	strcat(sql, "AND mo.mod_codigo = me.mod_codigo "); 

	$PREPARE selMedidores FROM $sql;
	
	$DECLARE curMedidores CURSOR FOR selMedidores;	
	
	/******** Cursor Principal  ****************/	
	strcpy(sql, "SELECT me.mar_codigo, ");
	strcat(sql, "me.mod_codigo, ");
	strcat(sql, "me.med_numero, ");
	strcat(sql, "me.med_ubic, ");
	strcat(sql, "me.med_codubic, ");
	strcat(sql, "me.numero_cliente, ");
	strcat(sql, "NVL(me.med_anio, 1900), ");
	strcat(sql, "f.fab_nombre[1,30], ");
	strcat(sql, "mo.mat_codigo, ");
	strcat(sql, "NVL(mo.tipo_medidor, 'A'), ");
	strcat(sql, "me.med_precinto1, ");
	strcat(sql, "me.med_precinto2, ");
	strcat(sql, "me.cla_codigo, ");
	strcat(sql, "fc.fun_fase ");
	strcat(sql, "FROM medidor me, ");
	strcat(sql, "	medidores@medidor_test:marca ma, ");
	strcat(sql, "	medidores@medidor_test:fabricante f, ");
	strcat(sql, " modelo mo, config c, funcionamiento fc ");
	strcat(sql, "WHERE me.med_tarifa = 'T1' ");
	strcat(sql, "AND me.med_estado != 'Z' ");
	strcat(sql, "AND me.mar_codigo NOT IN ('000', 'AGE') ");
	strcat(sql, "AND me.med_anio != 2019 ");
	strcat(sql, "AND ma.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND f.fab_codigo = ma.fab_codigo ");
	strcat(sql, "AND mo.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND mo.mod_codigo = me.mod_codigo ");

	strcat(sql, "AND c.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND c.mod_codigo = me.mod_codigo ");
	strcat(sql, "AND fc.fun_codigo = c.fun_codigo ");

strcat(sql, "UNION ");

	strcat(sql, "SELECT me.mar_codigo, ");
	strcat(sql, "me.mod_codigo, ");
	strcat(sql, "me.med_numero, ");
	strcat(sql, "me.med_ubic, ");
	strcat(sql, "me.med_codubic, ");
	strcat(sql, "me.numero_cliente, ");
	strcat(sql, "NVL(me.med_anio, 1900), ");
	strcat(sql, "f.fab_nombre[1,30], ");
	strcat(sql, "mo.mat_codigo, ");
	strcat(sql, "NVL(mo.tipo_medidor, 'A'), ");
	strcat(sql, "me.med_precinto1, ");
	strcat(sql, "me.med_precinto2, ");
	strcat(sql, "me.cla_codigo, ");
	strcat(sql, "fc.fun_fase ");
	strcat(sql, "FROM medidor me, ");
	strcat(sql, "	medidores@medidor_test:marca ma, ");
	strcat(sql, "	medidores@medidor_test:fabricante f, ");
	strcat(sql, " modelo mo, config c, funcionamiento fc, ");
	strcat(sql, " medid mi ");
	strcat(sql, "WHERE me.med_tarifa = 'T1' ");
	strcat(sql, "AND me.med_estado = 'Z' ");
	strcat(sql, "AND me.mar_codigo NOT IN ('000', 'AGE') ");
	strcat(sql, "AND me.med_anio != 2019 ");
	strcat(sql, "AND ma.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND f.fab_codigo = ma.fab_codigo ");
	strcat(sql, "AND mo.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND mo.mod_codigo = me.mod_codigo ");

	strcat(sql, "AND c.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND c.mod_codigo = me.mod_codigo ");
	strcat(sql, "AND fc.fun_codigo = c.fun_codigo ");

	strcat(sql, "AND mi.numero_medidor = me.med_numero ");
	strcat(sql, "AND mi.marca_medidor = me.mar_codigo ");
	strcat(sql, "AND mi.modelo_medidor = me.mod_codigo ");
	strcat(sql, "AND (mi.fecha_ult_insta IS NOT NULL OR mi.fecha_ult_insta >= TODAY - 365) ");


	$PREPARE selMedidores FROM $sql;
	
	$DECLARE curMedidores CURSOR FOR selMedidores;	

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

short LeoMedidores(regMed)
$ClsMedidor *regMed;
{
	InicializaMedidor(regMed);

	$FETCH curMedidores into
		:regMed->marca,
		:regMed->modelo,
		:regMed->numero,
		:regMed->med_ubic,
		:regMed->med_codubic,
		:regMed->numero_cliente,
		:regMed->med_anio,
		:regMed->fabricante,
		:regMed->mat_codigo,
		:regMed->tipo_medidor,
		:regMed->med_precinto1,
		:regMed->med_precinto2,
		:regMed->med_clase,
		:regMed->med_fase;			

	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Medidores !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regMed->fabricante, ' ');
	alltrim(regMed->mat_codigo, ' ');
	alltrim(regMed->med_precinto1, ' ');
	alltrim(regMed->med_precinto2, ' ');
	alltrim(regMed->med_clase, ' ');
	alltrim(regMed->med_fase, ' ');
	
	return 1;	
}

void InicializaMedidor(regMed)
$ClsMedidor	*regMed;
{
	memset(regMed->marca, '\0', sizeof(regMed->marca));
	memset(regMed->modelo, '\0', sizeof(regMed->modelo));
	
	rsetnull(CLONGTYPE, (char *) &(regMed->numero));
	
	memset(regMed->med_ubic, '\0', sizeof(regMed->med_ubic));
	memset(regMed->med_codubic, '\0', sizeof(regMed->med_codubic));
	
	rsetnull(CLONGTYPE, (char *) &(regMed->numero_cliente));
	rsetnull(CINTTYPE, (char *) &(regMed->med_anio));
	
	memset(regMed->fabricante, '\0', sizeof(regMed->fabricante));
	memset(regMed->mat_codigo, '\0', sizeof(regMed->mat_codigo));
	memset(regMed->emplazamiento, '\0', sizeof(regMed->emplazamiento));
	memset(regMed->gp_numeradores, '\0', sizeof(regMed->gp_numeradores));
	memset(regMed->tipo_medidor, '\0', sizeof(regMed->tipo_medidor));

	memset(regMed->med_precinto1, '\0', sizeof(regMed->med_precinto1));
	memset(regMed->med_precinto2, '\0', sizeof(regMed->med_precinto2));
	memset(regMed->med_clase, '\0', sizeof(regMed->med_clase));
	memset(regMed->med_fase, '\0', sizeof(regMed->med_fase));
	
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
					sprintf(sMensaje, "%s Medidor %ld %s %s\n", sMensaje, regMed->numero, regMed->marca, regMed->modelo);
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

short GenerarPlano(fp, regMed)
FILE 				*fp;
$ClsMedidor			regMed;
{

	/* V_EQUI */	
	GeneraVEQUI(fp, regMed);

	/* EGERS */
	GeneraEGERS(fp, regMed);
	
	/* EGERH */	
	GeneraEGERH(fp, regMed);	
	
	/* ENDE */
	GeneraENDE(fp, regMed);
	
	return 1;
}

void GeneraENDE(fp, regMed)
FILE *fp;
$ClsMedidor	regMed;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld%s%s\t&ENDE", regMed.numero, regMed.marca, regMed.modelo);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "APARATO");
		strcpy(sNombreArchivo, sSoloArchivoMedidor);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenAparato using
				:gsTipoGenera,
				:lCantidad,
				:sNombreArchivo;
	}
	
	return 1;
}


void GeneraVEQUI(fp, regMed)
FILE 		*fp;
ClsMedidor	regMed;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

	if(regMed.med_anio==0)
		regMed.med_anio=1900;
		
	sprintf(sLinea, "T1%ld%s%s\tEQUI\t", regMed.numero, regMed.marca, regMed.modelo);
	
	strcat(sLinea, "99991231\t");
	strcat(sLinea,"\t");
	strcat(sLinea,"I\t");
	strcat(sLinea,"1000\t");
/*	
	sprintf(sLinea, "%s%s\t", sLinea, regMed.fabricante);
*/
	sprintf(sLinea, "%s%s\t", sLinea, regMed.marca);
	
	strcat(sLinea, "\t");
	if(regMed.med_anio==0){
		regMed.med_anio=1900;
	}
	sprintf(sLinea, "%s%d\t", sLinea, regMed.med_anio);
	strcat(sLinea, "\t");
	strcat(sLinea, "\t");
	sprintf(sLinea, "%s%d0101\t", sLinea, regMed.med_anio);
	
	sprintf(sLinea, "%s%s\t", sLinea, regMed.emplazamiento);
	strcat(sLinea, "\t");
	
	/*
	sprintf(sLinea, "%s%s\t", sLinea, regMed.emplazamiento);
	*/
	strcat(sLinea, "\t");
	
	
	strcat(sLinea, "\t\t\t\t");
	sprintf(sLinea, "%s%s_%s\t", sLinea, regMed.marca, regMed.modelo);
	sprintf(sLinea, "%s%ld\t", sLinea, regMed.numero);
	strcat(sLinea, "01");
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}

void GeneraEGERS(fp, regMed)
FILE 			*fp;
ClsMedidor		regMed;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld%s%s\tEGERS\t01", regMed.numero, regMed.marca, regMed.modelo);	
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

void GeneraEGERH(fp, regMed)
FILE 			*fp;
ClsMedidor		regMed;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));

	if(regMed.med_anio==0)
		regMed.med_anio=1900;

	sprintf(sLinea, "T1%ld%s%s\tEGERH\t", regMed.numero, regMed.marca, regMed.modelo);	
	strcat(sLinea, "99991231\t");
	sprintf(sLinea, "%s%d0101\t", sLinea, regMed.med_anio);
	
	/* ultimo campo a definir GRUPO DE NUMERADORES*/
	if(regMed.tipo_medidor[0]=='R'){
		strcat(sLinea, "T1_REAC");
	}else{
		strcat(sLinea, "T1_SIMP");
	}
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}


short GenerarPlanoExt(fp, regMed)
FILE 				*fp;
$ClsMedidor			regMed;
{

	/* EQUI */	
	GeneraEQUI(fp, regMed);

	/* ENDE */
/*
	GeneraENDE(fp, regMed);
*/
	
	return 1;
}

void GeneraEQUI(fp, regMed)
FILE 		*fp;
ClsMedidor	regMed;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

		
	sprintf(sLinea, "T1%ld%s%s\tEQUI\t", regMed.numero, regMed.marca, regMed.modelo);
	
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
	
	fprintf(fp, sLinea);	
	
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


