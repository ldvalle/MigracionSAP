/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_instplan
    
	Fecha : 05/04/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura INSTPLAN (Planes de Pago CONVE)
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
      <Estado Cliente> : 0 = Activos; 1 = No Activos
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_instplan.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileUnx;

char	sArchUnx[100];
char	sSoloArchivo[100];

char	sPathSalida[100];
char	sPathCopia[100];
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
$char sFechaFica[11];
/*
$long	lFechaLimiteInferior;
$int	iCorrelativos;
*/
$long       glFechaParametro;
$dtime_t    gtInicioCorrida;
$char       sLstParametros[100];

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$ClsConve	regConve;
int			iNx;
$long			lFechaAlta;
char			sFechaAlta[9];
int         iFica;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;
	
	/*$BEGIN WORK;*/

	CreaPrepare();

   memset(sFechaFica, '\0', sizeof(sFechaFica));
   $EXECUTE selFica INTO :sFechaFica;
   
   if(SQLCODE != 0){
      printf("No se pudo encontrar la fecha de corrida de fica\n");
      exit(1);
   }
/*
	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
	$EXECUTE selCorrelativos into :iCorrelativos;
*/
		
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

	if(glFechaParametro > 0){
		$OPEN curConve using :glFechaParametro;
	}else{
		$OPEN curConve;
	}

	
	while(LeoConve(&regConve)){
		if(! ClienteYaMigrado(regConve.numero_cliente, &iFlagMigra)){
         iFica = getFica(regConve.numero_cliente);
         
         GenerarPlano(pFileUnx, iFica, regConve);
			
         cantProcesada++;
		}else{
			cantPreexistente++;
		}
						
	}

	$CLOSE curConve;
			
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
	printf("INSTPLAN (conve).\n");
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

   if(argc == 6){
      strcpy(sFechaPar, argv[5]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
      sprintf(sLstParametros, "%s %s %s", argv[1], argv[2], argv[3], argv[4], argv[5]);
   }else{
      glFechaParametro=-1;
      sprintf(sLstParametros, "%s %s", argv[1], argv[2], argv[3], argv[4]);
   }
   
   alltrim(sLstParametros, ' ');
	
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
	
	memset(sArchUnx,'\0',sizeof(sArchUnx));
	memset(sSoloArchivo,'\0',sizeof(sSoloArchivo));

	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	if(giEstadoCliente==0){
		sprintf( sArchUnx  , "%sT1INSTPLAN.unx", sPathSalida );
		strcpy( sSoloArchivo, "T1INSTPLAN.unx");
	}else{
		sprintf( sArchUnx  , "%sT1INSTPLAN_Inactivo.unx", sPathSalida );
		strcpy( sSoloArchivo, "T1INSTPLAN_Inactivo.unx");
	}
	
	pFileUnx=fopen( sArchUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchUnx );
		return 0;
	}

	return 1;	
}

void CerrarArchivos(void)
{
    
	fclose(pFileUnx);
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

	sprintf(sCommand, "chmod 755 %s", sArchUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchUnx, sPathCp);
	iRcv=system(sCommand);
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
	
   /******** Fecha FICA  ****************/
   $PREPARE selFica FROM "SELECT TO_CHAR(MAX(fecha_corrida), '%Y%m%d')
      FROM sap_regiextra
      WHERE estructura = 'FICA'";

	/******** CONVE  *********/
	strcpy(sql, "SELECT v.numero_cliente, "); 
	strcat(sql, "v.corr_convenio, "); 
	strcat(sql, "v.deuda_origen, ");
	strcat(sql, "v.saldo_origen, ");
	strcat(sql, "v.deuda_convenida, ");
	strcat(sql, "v.numero_tot_cuotas, ");
	strcat(sql, "v.numero_ult_cuota, ");
	strcat(sql, "v.valor_cuota, ");
	strcat(sql, "v.valor_cuota_ini, ");
	strcat(sql, "v.fecha_vigencia, ");
	strcat(sql, "TO_CHAR(v.fecha_vigencia, '%Y%m%d'), ");
   strcat(sql, "NVL(h.fecha_vencimiento1, 0) ");   
	strcat(sql, "FROM cliente c, conve v, OUTER hisfac h ");   
	
   if(giTipoCorrida==1)
      strcat(sql, ",migra_activos m ");	

	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si ");
	}		
	
	if(glNroCliente > 0 ){
		strcat(sql, "WHERE c.numero_cliente = ? ");
		strcat(sql, "AND c.tipo_sum != 5 ");	
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}		
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
   	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "	WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "	AND cm.fecha_activacion < TODAY ");
	strcat(sql, "	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND v.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND v.estado = 'V' ");
   if(glFechaParametro > 0){
      strcat(sql, "AND v.fecha_creacion >= ? ");   
   }
	strcat(sql, "AND v.numero_tot_cuotas != v.numero_ult_cuota ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.corr_facturacion = c.corr_facturacion ");
	
   if(giTipoCorrida == 1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	$PREPARE selConve FROM $sql;
	
	$DECLARE curConve CURSOR FOR selConve;
		
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
	strcat(sql, "fecha_fin, ");
	strcat(sql, "parametros ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'DEPGAR', ");
	strcat(sql, "?, CURRENT, ?) ");

	
	$PREPARE insGenInstal FROM $sql;

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
   	
   /********** Saldos Convenio ************/
   $PREPARE selSaldoConve FROM "SELECT saldo_actual, saldo_int_acum
      FROM saldos_convenio
      WHERE numero_cliente = ?";
   
   /********** Saldos Imp.Convenio ************/
   $PREPARE selImpuConve FROM "SELECT COUNT(*)
      FROM detalle_imp_conve
      WHERE numero_cliente = ?
      and saldo != 0";
   
   
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

short LeoConve(reg)
$ClsConve *reg;
{
	InicializaConve(reg);

	$FETCH curConve INTO
      :reg->numero_cliente, 
      :reg->corr_convenio, 
      :reg->deuda_origen,
      :reg->saldo_origen,
      :reg->deuda_convenida,
      :reg->numero_tot_cuotas,
      :reg->numero_ult_cuota,
      :reg->valor_cuota,
      :reg->valor_cuota_ini,
      :reg->lFechaVigencia,
      :reg->sFechaVigencia,
      :reg->lFechaVtoUltimaFactura;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de CONVE !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	return 1;	
}


void InicializaConve(reg)
$ClsConve	*reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente)); 
   rsetnull(CINTTYPE, (char *) &(reg->corr_convenio)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->deuda_origen));
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_origen));
   rsetnull(CDOUBLETYPE, (char *) &(reg->deuda_convenida));
   rsetnull(CINTTYPE, (char *) &(reg->numero_tot_cuotas));
   rsetnull(CINTTYPE, (char *) &(reg->numero_ult_cuota));
   rsetnull(CDOUBLETYPE, (char *) &(reg->valor_cuota));
   rsetnull(CDOUBLETYPE, (char *) &(reg->valor_cuota_ini));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaVigencia));
   memset(reg->sFechaVigencia, '\0', sizeof(reg->sFechaVigencia));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaVtoUltimaFactura));
}

short ClienteYaMigrado(nroCliente, iFlagMigra)
$long	nroCliente;
int		*iFlagMigra;
{
	$char	sMarca[2];
	
	
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
   	if(gsTipoGenera[0]=='G'){
   		return 1;	
   	}
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
	return 0;
}

/*
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
   
	return 1;	
}


char *getFechaFactura(lNroCliente, lCorrFactuInicio)
$long	lNroCliente;
$long   lCorrFactuInicio;
{
	$char	sFechaFactura[9];
	
	memset(sFechaFactura, '\0', sizeof(sFechaFactura));
	
	$EXECUTE selFechaFactura into :sFechaFactura using :lNroCliente, :lCorrFactuInicio;
		
	if(SQLCODE != 0){
		printf("No se encontró factura historica para cliente %ld\n", lNroCliente);
		return sFechaFactura;
	}
		
	return sFechaFactura;
}
*/

short GenerarPlano(fp, iFica, reg)
FILE 				*fp;
int            iFica;
$ClsConve		reg;
{
   int   iCuotas;
   int   iCuota;
   int   i;
   double   dValorCuota;
   double   dDiffSaldo;
   long  lVencimiento;

   iCuotas = reg.numero_tot_cuotas - reg.numero_ult_cuota;
   iCuota = reg.numero_ult_cuota + 1;
   /*
   if(reg.numero_ult_cuota == 0){
      dDiffSaldo = reg.deuda_convenida - (reg.valor_cuota_ini + ((iCuotas-1) * reg.valor_cuota));
   }else{
      dDiffSaldo = reg.deuda_convenida - (iCuotas * reg.valor_cuota);
   }
   */
   dDiffSaldo = reg.deuda_convenida - (iCuotas * reg.valor_cuota);

	/* IPKEY */	
	GeneraIPKEY(fp, reg);

   lVencimiento=reg.lFechaVtoUltimaFactura;
   for(i=1; i<= iCuotas; i++){
      if (iCuota == 1){
         /*dValorCuota = reg.valor_cuota_ini;*/
         dValorCuota = reg.valor_cuota;
      }else{
         if(i == iCuotas){
            /* Si es la ultima le agrego la diferencia */
            dValorCuota = reg.valor_cuota + dDiffSaldo;
         }else{
            dValorCuota = reg.valor_cuota;
         }
      }
      /* IPDATA */
      lVencimiento += 30;
      GeneraIPDATA(fp, i, iCuota, dValorCuota, reg, lVencimiento);
      
      iCuota++;
   }

	/* IPOPKY */	
   for(i=1; i<= iFica; i++){
	  GeneraIPOPKY(fp, i, reg);
   }

	/* ENDE */
	GeneraENDE(fp, reg);
	
	return 1;
}

void GeneraIPDATA(fp, i, iCuota, dValorCuota, reg, lVto)
FILE  *fp;
int   i;
int   iCuota;
double   dValorCuota;
ClsConve reg;
long  lVto;
{
	char	sLinea[1000];	
   char  sVto[11];
   
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sVto, '\0', sizeof(sVto));
   
   rfmtdate(lVto, "yyyymmdd", sVto); /* long to char */
	
	sprintf(sLinea, "T1%ld\tIPDATA\t", reg.numero_cliente);

   /* FAEDN (Vencimiento Cuota)*/
   sprintf(sLinea, "%s%s\t", sLinea, sVto);

   /* BETRW */
   sprintf(sLinea, "%s%.02lf\t", sLinea, dValorCuota);
   
   /* OPTXT */
   sprintf(sLinea, "%sCuota %d", sLinea, iCuota);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

}

void GeneraENDE(fp, reg)
FILE *fp;
$ClsConve	reg;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", reg.numero_cliente);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "DEPGAR");
		strcpy(sNombreArchivo, sSoloArchivo);
		lCantidad=cantProcesada;
				
		/*$EXECUTE updGenArchivos using :sTipoArchivo;*/
			
		$EXECUTE insGenInstal using
				:gtInicioCorrida,
				:sLstParametros;
	}
	
	return 1;
}

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

void GeneraIPKEY(fp, reg)
FILE 		*fp;
ClsConve	reg;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
	sprintf(sLinea, "T1%ld\tIPKEY\t", reg.numero_cliente);

   /* WAERS */
   strcat(sLinea, "ARS\t");
   /* BUDAT (Fecha Corrida Fica) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaFica);
   /* BLDAT (Fecha Corrida Fica) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaFica);
   /* GPART */
   sprintf(sLinea, "%sT1%ld\t", sLinea, reg.numero_cliente);
   /* VKONT */
   sprintf(sLinea, "%sT1%ld\t", sLinea, reg.numero_cliente);
   /* BLART */
   strcat(sLinea, "PP\t");
   /* BUKRS */
   strcat(sLinea, "EDES\t");
   /* RPCAT */
   strcat(sLinea, "E1\t");
   /* RPRDA */
	strcat(sLinea, "0");

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraIPOPKY(fp, i, reg)
FILE 		*fp;
int      i;
ClsConve	reg;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
   sprintf(sLinea, "T1%ld\tIPOPKY\t", reg.numero_cliente);

   /* OPBEL (Llave FICA)*/
   sprintf(sLinea, "%sT1%ld-1\t", sLinea, reg.numero_cliente);
   /* OPUPW */
   /*strcat(sLinea, "000\t");*/
   /* OPUPK */
   sprintf(sLinea, "%s%04d", sLinea, i);

   /* OPUPZ */
   /*strcat(sLinea, "0000\t");*/

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

int getFica(lNroCliente)
$long lNroCliente;
{
   $int iCant=0;
   $double dSaldoActual=0.00;
   $double dSaldoIntAcum=0.00;
   int   iFica=0;

   $EXECUTE selSaldoConve INTO :dSaldoActual, :dSaldoIntAcum
      USING :lNroCliente;
      
   if(SQLCODE != 0){
      printf("No se encontró SaldosConvenio para cliente %ld\n", lNroCliente);
   }
   
   if(dSaldoActual != 0.00)
      iFica++;
      
   if(dSaldoIntAcum != 0.00)
      iFica++;
      
   
   $EXECUTE selImpuConve INTO :iCant USING :lNroCliente;
   
   if(SQLCODE != 0){
      printf("No se encontró detalleImpConve para cliente %ld\n", lNroCliente);
   }

   iFica = iFica + iCant;
   
   return iFica;
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

