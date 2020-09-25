/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_depgar
    
	Fecha : 28/04/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura SECURITY (Depositos en Garantia)
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0=Activos; 1= No Activos; 2= Todos;		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_depgar.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
$char sPathCopia[100];

FILE	*pFileDataUnx;

char	sArchDataUnx[100];
char	sSoloArchivoData[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreMigrada;


char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;
$dtime_t    gtInicioCorrida;
$long       glFechaParametro;


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 		nombreBase[20];
time_t 		hora;
int			iFlagMigra=0;
$ClsCliente		regCliente;
$ClsFormaPago	regFP;
$ClsPostal		regPos;
int			iNx;
$long			lFechaMoveIn;

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
	
	/*$BEGIN WORK;*/

	CreaPrepare();

	
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada = 0;
	cantPreMigrada = 0;

   $OPEN curClientes;
	
	while(LeoCliente(&regCliente, &regFP, &regPOs)){
		if(! ClienteYaMigrado(regDepgar.numero_cliente, &iFlagMigra)){
         GenerarPlano(pFileDataUnx, regDepgar);
         cantProcesada++;

		}else{
			cantPreMigrada++;
		}
						
	}

	$CLOSE curDepgar;
			
	CerrarArchivos();

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
	printf("DEPOSITOS EN GARANTIA.\n");
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

	if(argc != 5){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));

	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 ){
		MensajeParametros();
		return 0;	
	}
	
	giEstadoCliente=atoi(argv[2]);
	
	strcpy(gsTipoGenera, argv[3]);
	
   giTipoCorrida=atoi(argv[4]);

   glNroCliente=-1;
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0=Normal, 1=Reducida\n");
}

short AbreArchivos()
{
	
	memset(sArchDataUnx,'\0',sizeof(sArchDataUnx));
	memset(sSoloArchivoData,'\0',sizeof(sSoloArchivoData));

	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');
   
	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
   
	/*lCorrelativo = getCorrelativo("DEPGAR");*/
	
	if(giEstadoCliente==0){
		sprintf( sArchDataUnx  , "%sT1SUPPLIES_Activo.unx", sPathSalida );
		strcpy( sSoloArchivoData, "T1SUPPLIES_Activo.unx");
	}else{
		sprintf( sArchDataUnx  , "%sT1SUPPLIES_Inactivo.unx", sPathSalida );
		strcpy( sSoloArchivoData, "T1SUPPLIES_Inactivo.unx");
	}
	
	pFileDataUnx=fopen( sArchDataUnx, "w" );
	if( !pFileDataUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchDataUnx );
		return 0;
	}

	return 1;	
}

void CerrarArchivos(void)
{
    
	fclose(pFileDataUnx);
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

	sprintf(sCommand, "chmod 755 %s", sArchDataUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDataUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchDataUnx);
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
	
	/******** Clientes  *********/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.nombre IS NOT NULL AND c.nombre != ' ' THEN UPPER(c.nombre[1,40]) ");
	strcat(sql, " 	ELSE 'SIN NOMBRE' ");
	strcat(sql, "END, ");
	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, '0000') actividad_economica, "); 

	strcat(sql, "c.cod_calle, ");
	strcat(sql, "UPPER(c.nom_calle), ");
	strcat(sql, "c.nro_dir, ");
	strcat(sql, "c.piso_dir, ");
	strcat(sql, "c.depto_dir, ");
	strcat(sql, "UPPER(c.nom_entre), ");
	strcat(sql, "UPPER(c.nom_entre1), ");
	strcat(sql, "t2.cod_sap provincia, ");
	strcat(sql, "c.partido, ");
	strcat(sql, "UPPER(c.nom_partido), ");
	strcat(sql, "c.comuna, ");
	strcat(sql, "c.nom_comuna, ");
	strcat(sql, "c.cod_postal, ");
	strcat(sql, "c.obs_dir[1,40], ");
	strcat(sql, "c.telefono, ");

	strcat(sql, "c.rut, ");
	strcat(sql, "t3.cod_sap tipo_documento, ");
	strcat(sql, "TRUNC(c.nro_doc,0), ");
	strcat(sql, "c.tipo_fpago, ");
	strcat(sql, "c.minist_repart, ");
	strcat(sql, "c.estado_cliente, ");
	strcat(sql, "c.tipo_reparto, ");
	strcat(sql, "LPAD(f.fp_banco, 4, '0'), ");
	strcat(sql, "f.fp_tipocuenta, ");
	strcat(sql, "f.fp_nrocuenta, ");
	strcat(sql, "f.fp_sucursal, ");
	strcat(sql, "f.fecha_activacion, ");
	strcat(sql, "f.fecha_desactivac, ");
	strcat(sql, "f.fp_cbu, ");
	
	strcat(sql, "UPPER(p.dp_nom_calle), ");
	strcat(sql, "p.dp_nro_dir, ");
	strcat(sql, "p.dp_piso_dir, ");
	strcat(sql, "p.dp_depto_dir, ");
	strcat(sql, "UPPER(p.dp_nom_entre), ");
	strcat(sql, "UPPER(p.dp_nom_entre1), ");
	strcat(sql, "t4.cod_sap pcia_postal, ");
	strcat(sql, "UPPER(p.dp_nom_partido), ");
	strcat(sql, "p.dp_cod_postal, ");
	strcat(sql, "p.dp_telefono ");
	
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3, ");
	strcat(sql, "OUTER forma_pago f, OUTER (postal p, sap_transforma t4) ");
   
   if(giEstadoCliente != 0){
      strcat(sql, ", sap_inactivos si ");
   }
      
   if(giTipoCorrida == 1)
      strcat(sql, ", migra_activos ma ");	
	
	if(glNroCliente > 0){
		strcat(sql, "WHERE c.numero_cliente = ? ");	
		strcat(sql, "AND c.tipo_sum != 5 ");	
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else if(giEstadoCliente == 1){
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.tipo_sum != 5 ");
		}
	}

	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");

	strcat(sql, "AND t1.clave = 'BU_TYPE' ");
	strcat(sql, "AND t1.cod_mac = c.actividad_economic ");
	strcat(sql, "AND t2.clave = 'REGION' ");
	strcat(sql, "AND t2.cod_mac = c.provincia ");
	strcat(sql, "AND t3.clave = 'ID_TYPE' ");
	strcat(sql, "AND t3.cod_mac = c.tip_doc ");
	strcat(sql, "AND t4.clave = 'REGION' ");
	strcat(sql, "AND t4.cod_mac = p.dp_provincia ");
	strcat(sql, "AND f.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND f.fecha_activacion <= TODAY ");
	strcat(sql, "AND (f.fecha_desactivac IS NULL OR f.fecha_desactivac > TODAY) ");
	strcat(sql, "AND p.numero_cliente = c.numero_cliente ");

   if(giTipoCorrida == 1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

   if(giEstadoCliente != 0)
      strcat(sql, "AND si.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;
		
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
	strcat(sql, "'DEPGAR', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT depgar FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, depgar ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "depgar = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

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
	strcpy(sql, "SELECT TO_CHAR(MAX(h2.fecha_lectura), '%Y%m%d') ");
	strcat(sql, "FROM hisfac h1, hislec h2 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.fecha_lectura < h1.fecha_facturacion ");
	strcat(sql, "AND h2.tipo_lectura IN (1, 2, 3, 4, 8) ");
	
	$PREPARE selFechaFactura FROM $sql;

	/********** Fecha Alta Instalacion ************/
   
	strcpy(sql, "SELECT fecha_val_tarifa, TO_CHAR(fecha_val_tarifa, '%Y%m%d') FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selFechaInstal FROM $sql;
   	
   /********* Registra Corrida **********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'DEPGAR', ?, CURRENT, ?)";
   
         
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
short LeoCliente(regCli, regFP, regPos)
$ClsCliente *regCliente;
$ClsFormaPago *regFP;
$ClsPostal *regPos;
{
	InicializaCliente(regCli, regFP, regPos);

	$FETCH curClientes INTO
		:regCli->numero_cliente,
      :regCli->razonSocial,
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
		:regCli->tipo_reparto,
		:regFP->fp_banco,
		:regFP->fp_tipocuenta,
		:regFP->fp_nrocuenta,
		:regFP->fp_sucursal,
		:regFP->fecha_activacion,
		:regFP->fecha_desactivac,
		:regFP->fp_cbu,
		:regPos->dp_nom_calle,
		:regPos->dp_nro_dir,
		:regPos->dp_piso_dir,
		:regPos->dp_depto_dir,
		:regPos->dp_nom_entre,
		:regPos->dp_nom_entre1,
		:regPos->dp_cod_provincia,
		:regPos->dp_nom_partido,
		:regPos->dp_cod_postal,
		:regPos->dp_telefono;
		
    if ( SQLCODE != 0 ){
		if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Clientes !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

    if(risnull(CINTTYPE,(char *) &(regCli->cod_postal))){
    	regCli->cod_postal=0;
    }
    
	if(risnull(CFLOATTYPE,(char *) &(regCli->nro_doc))){
		regCli->nro_doc=0;	
	}
   
	alltrim(regCli->telefono, ' ');
		
   alltrim(regCli->razonSocial, ' ');
   
	alltrim(regCli->obs_dir, ' ');
	
	/* Reemp Comillas y # */
	strcpy(regCli->razonSocial, strReplace(regCli->razonSocial, "'", " "));
	strcpy(regCli->razonSocial, strReplace(regCli->razonSocial, "#", "N"));
	
   if(!SeparaNombre(regCli)){
      printf("No se pudo separar el nombre de cliente %ld\n", regCli->numero_cliente);
   }
   
	alltrim(regCli->nombre, ' ');
   alltrim(regCli->apellido, ' ');
   
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "'", " "));
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "#", "N"));
	
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "'", " "));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "#", "N"));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "*", " "));
	
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "'", " "));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "#", "N"));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "*", " "));
	
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "'", " "));
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "#", "N"));

	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "'", " "));
	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "#", "N"));
		
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "'", " "));
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "#", "N"));
      
   if(regCli->tipo_fpago[0]=='D'){   
      $EXECUTE selFPago INTO :iValor USING :regCli->numero_cliente;
      
      if(SQLCODE != 0){
         printf("No se pudo validar Forma Pago para cliente %ld\n\tSe lo pasa a Normal.\n", regCli->numero_cliente);
         strcpy(regCli->tipo_fpago, "N");   
      }else{
         if(iValor <= 0){
            printf("No se encontro Forma Pago para cliente %ld\n\tSe lo pasa a Normal.\n", regCli->numero_cliente);
            strcpy(regCli->tipo_fpago, "N");   
         }
      }
   }
   
	return 1;	
}


void InicializaCliente(regCli, regFP, regPos)
$ClsCliente	*reg;
$ClsFormaPago *regFP;
$ClsPostal *regPos;
{

	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
	memset(regCli->nombre, '\0', sizeof(regCli->nombre));
   memset(regCli->apellido, '\0', sizeof(regCli->apellido));
   memset(regCli->razonSocial, '\0', sizeof(regCli->razonSocial));
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
	memset(regCli->tipo_reparto, '\0', sizeof(regCli->tipo_reparto));
	memset(regCli->sAccount, '\0', sizeof(regCli->sAccount));
	
	memset(regFP->fp_banco, '\0', sizeof(regFP->fp_banco));
	memset(regFP->fp_tipocuenta, '\0', sizeof(regFP->fp_tipocuenta));
	memset(regFP->fp_nrocuenta, '\0', sizeof(regFP->fp_nrocuenta));
	rsetnull(CINTTYPE, (char *) &(regFP->fp_sucursal));
	rsetnull(CLONGTYPE, (char *) &(regFP->fecha_activacion));
	rsetnull(CLONGTYPE, (char *) &(regFP->fecha_desactivac));
	memset(regFP->fp_cbu, '\0', sizeof(regFP->fp_cbu));
	
	memset(regPos->dp_nom_calle, '\0', sizeof(regFP->dp_nom_calle));
	memset(regPos->dp_nro_dir, '\0', sizeof(regFP->dp_nro_dir));
	memset(regPos->dp_piso_dir, '\0', sizeof(regFP->dp_piso_dir));
	memset(regPos->dp_depto_dir, '\0', sizeof(regFP->dp_depto_dir));
	memset(regPos->dp_nom_entre, '\0', sizeof(regFP->dp_nom_entre));
	memset(regPos->dp_nom_entre1, '\0', sizeof(regFP->dp_nom_entre1));
	memset(regPos->dp_cod_provincia, '\0', sizeof(regFP->dp_cod_provincia));
	memset(regPos->dp_nom_partido, '\0', sizeof(regFP->dp_nom_partido));
	rsetnull(CINTTYPE, (char *) &(regPos->dp_cod_postal));
	memset(regPos->dp_telefono, '\0', sizeof(regFP->dp_telefono));
	
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

short CargaAltaCliente(regDep)
$ClsDepgar *regDep;
{
	$long lFechaAlta;
	$char sFechaAlta[9];
	$long iCorrFactuInicio;
	
	memset(sFechaAlta, '\0', sizeof(sFechaAlta));


   $EXECUTE selFechaInstal INTO :lFechaAlta, :sFechaAlta
      USING :regDep->numero_cliente;
      
   if(SQLCODE !=0){
		printf("Error al buscar fecha de Alta para cliente %ld.\n", regDep->numero_cliente);
		exit(2);
   }
   
   strcpy(regDep->sFechaVigTarifa, sFechaAlta);
   regDep->lFechaVigTarifa = lFechaAlta;
   
   
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

short GenerarPlano(fp, regDep)
FILE 				*fp;
$ClsDepgar		regDep;
{
	/* SEC_D */	
	GeneraSEC_D(fp, regDep);

	/* SEC_C */	
	GeneraSEC_C(fp, regDep);

	/* ENDE */
	GeneraENDE(fp, regDep);
	
	return 1;
}

void GeneraENDE(fp, regDep)
FILE *fp;
$ClsDepgar	regDep;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%ld\t&ENDE", regDep.numero_cliente, regDep.numero_dg);

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
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "DEPGAR");
		strcpy(sNombreArchivo, sSoloArchivoData);
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

void GeneraSEC_D(fp, regDep)
FILE 		*fp;
ClsDepgar	regDep;
{
	char	sLinea[1000];	
	int  iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%ld\tSECD\t", regDep.numero_cliente, regDep.numero_dg);
	
/* APPLK */
   /*strcat(sLinea, "R\t");*/
   
/* NON-CASH */
	if(risnull(CLONGTYPE, (char *) &regDep.garante)){
      strcat(sLinea, "\t");
   }else{
      strcat(sLinea, "X\t");
   }
   
/* VKONT */
   sprintf(sLinea, "%sT1%ld\t", sLinea, regDep.numero_cliente);
   
/* WAERS */
   /*strcat(sLinea, "ARS\t");*/
   
/* REASON */
   strcat(sLinea, "0001\t");

/* SEC_START */
   sprintf(sLinea, "%s%s\t", sLinea, regDep.sFechaDeposito);

/* SEC_RETURN */
/*
   sprintf(sLinea, "%s%s\t", sLinea, regDep.sFechaReintegro);
*/
/* NC_STATUS ????*/
   strcat(sLinea, "00\t");

/* TYP */
   strcat(sLinea, "0003\t");

/* REFNO ????*/
   strcat(sLinea, "\t");
   
/* SEC_EXPIRE */
   /*strcat(sLinea, "\t");*/

/* GPART_GUARANTOR */
   if(!risnull(CLONGTYPE, (char *) &regDep.garante)){
      sprintf(sLinea, "%sT1%ld\t", sLinea, regDep.garante);
   }else{
      strcat(sLinea, "\t");
   }

/* VKONT_GUARANTOR */
   if(!risnull(CLONGTYPE, (char *) &regDep.garante)){
      sprintf(sLinea, "%sT1%ld", sLinea, regDep.garante);
   }else{
      /*strcat(sLinea, "\t");*/
   }


/* BUKRS */
   /*strcat(sLinea, "EDES");*/

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir SEC_D\n");
      exit(1);
   }	
	
}

void GeneraSEC_C(fp, regDep)
FILE 		*fp;
ClsDepgar	regDep;
{
	char	sLinea[1000];	
	int  iRcv;
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%ld\tSECC\t", regDep.numero_cliente, regDep.numero_dg);
	
/* VTREF ????*/
   strcat(sLinea, "\t");
   
/* REQUEST */
	if(risnull(CLONGTYPE, (char *) &regDep.garante)){
      sprintf(sLinea, "%s%.2f", sLinea, regDep.valor_deposito);
   }

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir SEC_C\n");
      exit(1);
   }	
	
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

