/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_move_out
    
	Fecha : 14/10/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura MOVE_OUT y su respectivo MOVE_IN
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_move_out.h";

/* Variables Globales */
$long	glNroCliente;
$char	gsTipoGenera[2];

FILE	*pFileBajas;
FILE	*pFileAltas;
FILE	*pFileAltasViejas;

char	sArchBajasUnx[100];
char	sArchBajasDos[100];
char	sSoloArchivoBajas[100];

char	sArchAltasUnx[100];
char	sArchAltasDos[100];
char	sSoloArchivoAltas[100];

char	sArchAltasViejasUnx[100];
char	sSoloArchivoAltasViejas[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];

long	cantProcesada;
long 	cantPreexistente;

/* Variables Globales Host */
$ClsBajas	regBajas;
$long	lFechaLimiteInferior;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;

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

	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
		
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

	if(glNroCliente > 0){
		$OPEN curBajas using :glNroCliente;
	}else{
		$OPEN curBajas;
	}

	while(LeoBajas(&regBajas)){

		if(! ClienteYaMigrado(regBajas.numero_cliente, &iFlagMigra)){
			
			if (!GenerarPlanoBajas(pFileBajas, regBajas)){
				exit(1);	
			}
/*
			if(regBajas.lFechaBaja > lFechaLimiteInferior){
				if (!GenerarPlanoAltas(pFileAltas, regBajas)){
					$ROLLBACK WORK;
					exit(1);	
				}
			}else{
				if (!GenerarPlanoAltas(pFileAltasViejas, regBajas)){
					$ROLLBACK WORK;
					exit(1);	
				}				
			}
*/
         
         $BEGIN WORK;
         					
			if(!RegistraCliente(regBajas.numero_cliente, iFlagMigra)){
				$ROLLBACK WORK;
				exit(1);	
			}
         
         $COMMIT WORK;
         			
			cantProcesada++;
		}else{
			cantPreexistente++;			
		}
	}
	
	$CLOSE curBajas;
			
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
/*
	FormateaArchivos();
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

	if(argc < 3 || argc > 4){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	strcpy(gsTipoGenera, argv[2]);
	
	if(argc==4){
		glNroCliente=atoi(argv[3]);
	}else{
		glNroCliente=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos()
{
	int iCorrBaja=0;
	int iCorrAlta=0;
		
	memset(sArchBajasUnx,'\0',sizeof(sArchBajasUnx));
	memset(sArchBajasDos,'\0',sizeof(sArchBajasDos));
	memset(sSoloArchivoBajas,'\0',sizeof(sSoloArchivoBajas));

	memset(sArchAltasUnx,'\0',sizeof(sArchAltasUnx));
	memset(sArchAltasDos,'\0',sizeof(sArchAltasDos));
	memset(sSoloArchivoAltas,'\0',sizeof(sSoloArchivoAltas));	

	memset(sArchAltasViejasUnx,'\0',sizeof(sArchAltasViejasUnx));
	memset(sSoloArchivoAltasViejas,'\0',sizeof(sSoloArchivoAltasViejas));	
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );
	
	iCorrBaja = getCorrelativo("MOVE_OUT");
	/*iCorrAlta = getCorrelativo("MOVE_IN");*/
	
	alltrim(sPathSalida,' ');

	sprintf( sArchBajasUnx  , "%sT1MOVEOUT.unx", sPathSalida);
	strcpy( sSoloArchivoBajas, "T1MOVEOUT.unx" );

	pFileBajas=fopen( sArchBajasUnx, "w" );
	if( !pFileBajas ){
		printf("ERROR al abrir archivo %s.\n", sArchBajasUnx );
		return 0;
	}

	sprintf( sArchAltasUnx  , "%sT1MOVEIN_Inac.unx", sPathSalida);
	strcpy( sSoloArchivoAltas, "T1MOVEIN_Inac.unx");

	pFileAltas=fopen( sArchAltasUnx, "w" );
	if( !pFileAltas ){
		printf("ERROR al abrir archivo %s.\n", sArchAltasUnx );
		return 0;
	}

	sprintf( sArchAltasViejasUnx  , "%sT1MOVEIN_Inac_viejos.unx", sPathSalida);
	strcpy( sSoloArchivoAltasViejas, "T1MOVEIN_Inac_viejos.unx");

	pFileAltasViejas=fopen( sArchAltasViejasUnx, "w" );
	if( !pFileAltasViejas ){
		printf("ERROR al abrir archivo %s.\n", sArchAltasViejasUnx );
		return 0;
	}
	
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileBajas);
	fclose(pFileAltas);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char    sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

    strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");
    
	if(cantProcesada>0){
	    sprintf(sCommand, "chmod 777 %s", sArchBajasUnx);
	    iRcv=system(sCommand);
	    
	    sprintf(sCommand, "cp %s %s", sArchBajasUnx, sPathCp);
	    iRcv=system(sCommand);

	    sprintf(sCommand, "chmod 777 %s", sArchAltasUnx);
	    iRcv=system(sCommand);
	    
	    sprintf(sCommand, "cp %s %s", sArchAltasUnx, sPathCp);
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
	
	/******** Cursor Bajas + sus Altas  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, c.tarifa), ");
	strcat(sql, "CASE ");		/* tarifa */
	strcat(sql, "	WHEN c.tarifa[2] = 'G' AND c.tipo_sum = 6 THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");	
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "CASE ");	/* Tipo Cliente */
	strcat(sql, "	WHEN c.tipo_cliente IN ('CO', 'OC') AND c.tarifa[2]='R' THEN 'R1' ");
	strcat(sql, "	WHEN c.tipo_cliente IN ('CO', 'OC') AND c.tarifa[2]='G' THEN 'C1' ");
	strcat(sql, "	ELSE t2.cod_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "c.sucursal, ");	/* Sucursal */
   
	strcat(sql, "NVL(TO_CHAR(e.fecha_terr_puser, '%Y%m%d'), 'NULO') fecha_alta, ");
   
	strcat(sql, "TO_CHAR(si.fecha_baja, '%Y%m%d') fecha_baja, ");
	strcat(sql, "DATE(si.fecha_baja), ");
	strcat(sql, "NVL(si.procedimiento, 'OTRO'), ");
	strcat(sql, "NVL(c.nro_beneficiario, '0'), ");
   
	strcat(sql, "NVL(TO_CHAR(e.fecha_traspaso, '%Y%m%d'), 'NULO') fecha_alta_sis ");
	
	strcat(sql, "FROM cliente c, sap_inactivos si, OUTER sap_transforma t1, OUTER estoc e, ");
	strcat(sql, "OUTER sap_transforma t2 ");

	strcat(sql, "WHERE c.estado_cliente != 0 ");
	if(glNroCliente > 0 ){
		strcat(sql, "AND c.numero_cliente = ? ");		
	}

	strcat(sql, "AND si.numero_cliente = c.numero_cliente ");

	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");
	strcat(sql, "AND e.numero_cliente = c.numero_cliente ");

	strcat(sql, "AND t2.clave = 'TIPCLI' ");
	strcat(sql, "AND t2.cod_mac = c.tipo_cliente ");
	
	$PREPARE selBajas FROM $sql;
	
	$DECLARE curBajas CURSOR WITH HOLD FOR selBajas;

	/******** Select Retiros Medidor *********/	
	strcpy(sql, "SELECT TO_CHAR(m2.fecha_modif, '%Y%m%d') ");
	strcat(sql, "FROM modif m2 ");
	strcat(sql, "WHERE m2.numero_cliente = ? ");
	strcat(sql, "AND m2.codigo_modif = 57 ");

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
	
	$PREPARE selCorrelativo FROM $sql;

	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	$PREPARE updGenArchivos FROM $sql;
		
	/******** Insert gen_archivos Bajas****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'MOVE_OUT', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	$PREPARE insGenBajas FROM $sql;

	/******** Insert gen_archivos Altas ****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'MOVE_IN', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	$PREPARE insGenAltas FROM $sql;
	
	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT move_out FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos Bajas **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, move_out ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigraB FROM $sql;
	
	/************ Update Clientes Migra Bajas **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "move_out = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigraB FROM $sql;

	/*********Insert Clientes extraidos Altas **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, move_in ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigraA FROM $sql;
	
	/************ Update Clientes Migra Altas **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "move_in = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigraA FROM $sql;

	/************ Busca Instalacion **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(MIN(m.fecha_ult_insta), '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");

	$PREPARE selFechaInstal FROM $sql;

	/************ FechaLimiteInferior **************/
	strcpy(sql, "SELECT TODAY-365 FROM dual ");
	
	$PREPARE selFechaLimInf FROM $sql;	
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

short LeoBajas(regBaja)
$ClsBajas *regBaja;
{
	$char sNroBeneficiario[17];
	InicializaBajas(regBaja);
	
	
	memset(sNroBeneficiario, '\0', sizeof(sNroBeneficiario));
	
	$FETCH curBajas into
		:regBaja->numero_cliente,
		:regBaja->tarifa,
		:regBaja->clase_tarifa,
		:regBaja->tipo_cliente,
		:regBaja->sucursal_sap,
		/*:regBaja->fecha_alta,*/
      :regBaja->fecha_baja,
		:regBaja->lFechaBaja,
		:regBaja->proced,
		:sNroBeneficiario;
		/*:regBaja->fecha_alta_sistema;*/
	
	
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de BAJAS !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regBaja->proced, ' ');
/*   
	alltrim(regBaja->fecha_alta, ' ');
	alltrim(regBaja->fecha_alta_sistema, ' ');
*/
	
	/* Busco la fecha de instalacion si NO vino de INCORPORACION */
	if(strcmp(regBaja->proced, "INCORPORACION")==1){
		$EXECUTE selRetiro into :regBaja->fecha_retiro using :regBaja->numero_cliente;
			
		if(SQLCODE != 0){
			if(SQLCODE == SQLNOTFOUND){
				strcpy(regBaja->fecha_retiro, "19950924");	
			}else{
				printf("Error al buscar fecha de RETIRO de medidor para cliente %ld.\nProcedimiento %s", regBaja->numero_cliente, regBaja->proced);
				exit(2);
			}
		}		
	}

	if(strcmp(sNroBeneficiario, "")==0){
		regBaja->nro_beneficiario=0;
	}else{
		regBaja->nro_beneficiario=atol(sNroBeneficiario);
	}

	/* Fecha de Alta de medidor */
/*   
	if(strcmp(regBaja->fecha_alta, "NULO")==0){
		if(regBaja->nro_beneficiario > 0){
			$EXECUTE selRetiro  into :regBaja->fecha_alta using :regBaja->nro_beneficiario;
				
			if(SQLCODE != 0){
				if(SQLCODE != SQLNOTFOUND){
					printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld.\n", regBaja->nro_beneficiario);
					exit(2);
				}else{
					strcpy(regBaja->fecha_alta, "19950924");
				}
			}
		}else{
			$EXECUTE selFechaInstal into :regBaja->fecha_alta using :regBaja->numero_cliente;
			
			if(SQLCODE != 0){
				strcpy(regBaja->fecha_alta, "19950924");
			}
		}			
	}
*/
	/* Fecha Alta Sistema */
/*   
	if(strcmp(regBaja->fecha_alta_sistema, "NULO")==0){
		if(regBaja->nro_beneficiario > 0){
			$EXECUTE selRetiro  into :regBaja->fecha_alta_sistema using :regBaja->nro_beneficiario;
				
			if(SQLCODE != 0){
				if(SQLCODE != SQLNOTFOUND){
					printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld.\n", regBaja->nro_beneficiario);
					exit(2);
				}else{
					strcpy(regBaja->fecha_alta_sistema, "19950924");
				}
			}
		}else{
			$EXECUTE selFechaInstal into :regBaja->fecha_alta_sistema using :regBaja->numero_cliente;
			
			if(SQLCODE != 0){
				strcpy(regBaja->fecha_alta_sistema, "19950924");
			}
		}		
	}
*/	
	return 1;	
}

void InicializaBajas(regBaja)
$ClsBajas	*regBaja;
{
	rsetnull(CLONGTYPE, (char *) &(regBaja->numero_cliente));
	memset(regBaja->tarifa, '\0', sizeof(regBaja->tarifa));
	memset(regBaja->tipo_cliente, '\0', sizeof(regBaja->tipo_cliente));
	memset(regBaja->sucursal_sap, '\0', sizeof(regBaja->sucursal_sap));
	memset(regBaja->fecha_alta, '\0', sizeof(regBaja->fecha_alta));
	memset(regBaja->fecha_baja, '\0', sizeof(regBaja->fecha_baja));	
	memset(regBaja->proced, '\0', sizeof(regBaja->proced));		
	memset(regBaja->fecha_retiro, '\0', sizeof(regBaja->fecha_retiro));		
	memset(regBaja->fecha_alta_sistema, '\0', sizeof(regBaja->fecha_alta_sistema));
	rsetnull(CLONGTYPE, (char *) &(regBaja->nro_beneficiario));

}

short ClienteYaMigrado(nroCliente, iFlagMigra)
$long	nroCliente;
int		*iFlagMigra;
{
	$char	sMarca[2];
	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
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


short GenerarPlanoBajas(fp, regBaja)
FILE 				*fp;
$ClsBajas		regBaja;
{

	/* EAUSD */	
	GeneraEAUSD(fp, regBaja);

	/* EAUSVD */	
	GeneraEAUSVD(fp, regBaja);
	
	/* ENDE */
	GeneraENDE(fp, regBaja);

	return 1;
}

void GeneraENDE(fp, regBaja)
FILE *fp;
$ClsBajas	regBaja;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regBaja.numero_cliente);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "MOVE_OUT");
		strcpy(sNombreArchivo, sSoloArchivoBajas);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenBajas using
				:gsTipoGenera,
				:lCantidad,
				:glNroCliente,
				:sNombreArchivo;
	}
	
	return 1;
}

short RegistraCliente(nroCliente, iFlagMigra)
$long	nroCliente;
int		iFlagMigra;
{
	if(iFlagMigra==1){
		$EXECUTE insClientesMigraB using :nroCliente;
	}else{
		$EXECUTE updClientesMigraB using :nroCliente;
	}

	return 1;
}

void GeneraEAUSD(fp, regBaja)
FILE 		*fp;
ClsBajas	regBaja;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld\tEAUSD\t", regBaja.numero_cliente);
	
	if(strcmp(regBaja.proced, "INCORPORACION")==0){
		strcat(sLinea, "\t");	
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regBaja.fecha_retiro);
	}
	sprintf(sLinea, "%s%s", sLinea, regBaja.fecha_baja);
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}

void GeneraEAUSVD(fp, regBaja)
FILE 			*fp;
ClsBajas	regBaja;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tEAUSVD\t", regBaja.numero_cliente);
	sprintf(sLinea, "%sT1%ld\t", sLinea, regBaja.numero_cliente);
	strcat(sLinea, "\t");
	sprintf(sLinea, "%sT1%ld", sLinea, regBaja.numero_cliente);
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

short GenerarPlanoAltas(fp, regBaja)
FILE 				*fp;
$ClsBajas		regBaja;
{

	/* EVERD */	
	GeneraEVERD(fp, regBaja);
	
	/* ENDE */
	GeneraENDE(fp, regBaja);

	return 1;	
}

void GeneraEVERD(fp, regBaja)
FILE 				*fp;
$ClsBajas		regBaja;
{
	char	sLinea[1000];	
	char	sFechaAlta2[9];
	long 	lFechaAlta;
		
	memset(sLinea, '\0', sizeof(sLinea));
	memset(sFechaAlta2, '\0', sizeof(sFechaAlta2));
/*
	rdefmtdate(&lFechaAlta, "yyyymmdd", regBaja.fecha_alta);
	if(lFechaAlta < lFechaLimiteInferior){
		strcpy(sFechaAlta2, "20151101");
	}else{
		strcpy(sFechaAlta2, regBaja.fecha_alta);
	}
	
	if(sFechaAlta2[0]== 'N'){
		strcpy(sFechaAlta2, "20151101");	
	}
	if(regBaja.fecha_alta_sistema[0]== 'N'){
		strcpy(regBaja.fecha_alta_sistema, "19950924");	
	}


   strcpy(regAlta.fecha_alta_sistema, regAlta.fecha_alta);
*/   
   /* LLAVE */		
	sprintf(sLinea, "T1%ld\tEVER\t", regBaja.numero_cliente);
   
	/* sprintf(sLinea, "%s%ld\t",sLinea, regBaja.numero_cliente); */
   
	sprintf(sLinea, "%s%ld\t", sLinea, regBaja.tipo_cliente);
   
	strcat(sLinea, "\t3\t");
	strcat(sLinea, "\t\t\t");
	sprintf(sLinea, "%s%ld\t", sLinea, regBaja.numero_cliente);
	strcat(sLinea, "T1\t");
	strcat(sLinea, "\t");
	/*
	sprintf(sLinea, "%s%s\t", sLinea, regBaja.tarifa);
	*/
	strcat(sLinea, "ZT1\t");
	
	strcat(sLinea, "\t");
	sprintf(sLinea, "%sT1%ld\t", sLinea, regBaja.numero_cliente);
	sprintf(sLinea, "%sT1%ld\t", sLinea, regBaja.numero_cliente);
	/*
	sprintf(sLinea, "%s%s\t", sLinea, regBaja.fecha_alta);
	*/
	sprintf(sLinea, "%s%s\t", sLinea, sFechaAlta2);
	
	strcat(sLinea, "\t");
	strcat(sLinea, "0001\t");
	
	sprintf(sLinea, "%s%s\t", sLinea, regBaja.fecha_alta_sistema);
	sprintf(sLinea, "%s%ld\t", sLinea, regBaja.numero_cliente);
	strcat(sLinea, "\t");
	sprintf(sLinea, "%s%s\t", sLinea, regBaja.sucursal_sap);
	strcat(sLinea, "\t");
	strcat(sLinea, "NO ACTIVO\t");
	strcat(sLinea, "\t");
	sprintf(sLinea, "%s%s", sLinea, regBaja.tipo_cliente);
	
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

