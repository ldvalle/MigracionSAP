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

FILE	*pFileDepgarUnx;

char	sArchDepgarUnx[100];
char	sSoloArchivoDepgar[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long	cantActivos;
long	cantInactivos;
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
$long	   lCorrFactuIni;
$ClsDepgar	regDepgar;
int				iNx;
$long			lFechaAlta;
$long			lFechaIniAnterior;
$long			lFechaHastaAnterior;
long			lDifDias;
char			sFechaAlta[9];

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


	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
		
	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantActivos=0;
	cantInactivos=0;
	cantPreexistente=0;


   if(glFechaParametro <= 0){
      $OPEN curDepgar;
   }else{
      $OPEN curDepgar USING :glFechaParametro;
   }

/*	
   if(glNroCliente > 0){
		$OPEN curDepgar using :glNroCliente;
	}else{
		$OPEN curDepgar;
	}
*/
	
	while(LeoDepgar(&regDepgar)){
		if(! ClienteYaMigrado(regDepgar.numero_cliente, &iFlagMigra)){
			/* Obtener la Fecha Montaje */
			memset(sFechaAlta, '\0', sizeof(sFechaAlta));
			
			if(!CargaAltaCliente(&regDepgar)){
				/*$ROLLBACK WORK;*/
				exit(1);				
			}
         /*
         if(regDepgar.lFechaVigTarifa > regDepgar.lFechaDeposito){
            strcpy(regDepgar.sFechaDeposito, regDepgar.sFechaVigTarifa);
         }
         */
         GenerarPlano(pFileDepgarUnx, regDepgar);
         /*
			if(giTipoCorrida==0){
            $BEGIN WORK;
            if(!RegistraCliente(regDepgar.numero_cliente, iFlagMigra)){
               $ROLLBACK WORK;
            }
            $COMMIT WORK;
         }
         */         
         cantProcesada++;
		}else{
			cantPreexistente++;
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
   
   glNroCliente=-1;
	
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

short AbreArchivos()
{
	
	memset(sArchDepgarUnx,'\0',sizeof(sArchDepgarUnx));
	memset(sSoloArchivoDepgar,'\0',sizeof(sSoloArchivoDepgar));

	
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
		sprintf( sArchDepgarUnx  , "%sT1SECURITY_Activo.unx", sPathSalida );
		strcpy( sSoloArchivoDepgar, "T1SECURITY_Activo.unx");
	}else{
		sprintf( sArchDepgarUnx  , "%sT1SECURITY_Inactivo.unx", sPathSalida );
		strcpy( sSoloArchivoDepgar, "T1SECURITY_Inactivo.unx");
	}
	
	pFileDepgarUnx=fopen( sArchDepgarUnx, "w" );
	if( !pFileDepgarUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchDepgarUnx );
		return 0;
	}

	return 1;	
}

void CerrarArchivos(void)
{
    
	fclose(pFileDepgarUnx);
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

	sprintf(sCommand, "chmod 755 %s", sArchDepgarUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDepgarUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchDepgarUnx);
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
	
	/******** DEPGAR  *********/
	strcpy(sql, "SELECT d.numero_dg, ");
	strcat(sql, "d.numero_cliente, ");
	strcat(sql, "d.nro_comprob, ");
	strcat(sql, "TO_CHAR(d.fecha_deposito, '%Y%m%d'), ");
	strcat(sql, "d.fecha_deposito, ");
	strcat(sql, "TO_CHAR(d.fecha_reintegro, '%Y%m%d'), ");
	strcat(sql, "d.fecha_reintegro, ");
	strcat(sql, "d.valor_deposito, ");
	strcat(sql, "d.estado, ");
	strcat(sql, "d.estado_dg, ");
	strcat(sql, "d.origen, ");
	strcat(sql, "d.motivo, ");
	strcat(sql, "d.garante ");
	strcat(sql, "FROM cliente c, depgar d ");   

   if(giTipoCorrida==1)	
      strcat(sql, ",migra_activos m ");	

	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si ");
	}		

	if(giEstadoCliente==0){
		strcat(sql, "WHERE c.estado_cliente = 0 ");
		strcat(sql, "AND c.tipo_sum != 5 ");
	}else{
		strcat(sql, "WHERE c.estado_cliente != 0 ");
      strcat(sql, "AND si.numero_cliente = c.numero_cliente ");      
	}		
	
   if(glFechaParametro > 0){
      strcat(sql, "AND d.fecha_emision > ? ");   
   }

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND d.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND d.estado_dg NOT IN ('D','A','E') ");
	strcat(sql, "AND d.estado NOT IN (1,2) ");
   strcat(sql, "AND d.fecha_aplica_cap IS NULL ");

   if(giTipoCorrida==1)	
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	$PREPARE selDepgar FROM $sql;
	
	$DECLARE curDepgar CURSOR WITH HOLD FOR selDepgar;
		
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
short LeoDepgar(regDep)
$ClsDepgar *regDep;
{
	InicializaDepgar(regDep);

	$FETCH curDepgar into
    :regDep->numero_dg,
    :regDep->numero_cliente,
    :regDep->numero_comprob,
    :regDep->sFechaDeposito,
    :regDep->lFechaDeposito,
    :regDep->sFechaReintegro,
    :regDep->lFechaReintegro,
    :regDep->valor_deposito,
    :regDep->estado,
    :regDep->estado_dg,
    :regDep->origen,
    :regDep->motivo,
    :regDep->garante;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de DEPGAR !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	return 1;	
}


void InicializaDepgar(regDep)
$ClsDepgar	*regDep;
{

   rsetnull(CLONGTYPE, (char *) &(regDep->numero_dg));
   rsetnull(CLONGTYPE, (char *) &(regDep->numero_cliente));
   memset(regDep->sFechaDeposito, '\0', sizeof(regDep->sFechaDeposito));
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaDeposito));
   memset(regDep->sFechaReintegro, '\0', sizeof(regDep->sFechaReintegro));
   rsetnull(CDOUBLETYPE, (char *) &(regDep->valor_deposito));
   memset(regDep->estado, '\0', sizeof(regDep->estado));
   memset(regDep->estado_dg, '\0', sizeof(regDep->estado_dg));
   memset(regDep->origen, '\0', sizeof(regDep->origen));  
   memset(regDep->motivo, '\0', sizeof(regDep->motivo));
   rsetnull(CLONGTYPE, (char *) &(regDep->garante));
   memset(regDep->sFechaVigTarifa, '\0', sizeof(regDep->sFechaVigTarifa));
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaVigTarifa));
   
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaReintegro));
   rsetnull(CLONGTYPE, (char *) &(regDep->numero_comprob));

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
		strcpy(sNombreArchivo, sSoloArchivoDepgar);
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
   strcat(sLinea, "R\t");
   
/* NON-CASH */
	if(risnull(CLONGTYPE, (char *) &regDep.garante)){
      strcat(sLinea, "\t");
   }else{
      strcat(sLinea, "X\t");
   }
   
/* VKONT */
   sprintf(sLinea, "%sT1%ld\t", sLinea, regDep.numero_cliente);
   
/* WAERS */
   strcat(sLinea, "ARS\t");
   
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
      sprintf(sLinea, "%sT1%ld\t", sLinea, regDep.garante);
   }else{
      strcat(sLinea, "\t");
   }


/* BUKRS */
   strcat(sLinea, "EDES");

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

