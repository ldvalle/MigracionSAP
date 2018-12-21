/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_doc_fica
    
	Fecha : 19/06/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura DOCUMENTOS FICA
		
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
#include <math.h>

$include "sap_doc_fica.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileGral;
char	sArchSalidaGral[100];
char	sSoloArchSalidaGral[100];

FILE	*pFileCNR;
char	sArchCNR[100];
char	sSoloArchCNR[100];

FILE	*pFileConve;
char	sArchConve[100];
char	sSoloArchConve[100];

FILE	*pFileDispu;
char	sArchDispu[100];
char	sSoloArchDispu[100];

FILE	*pFileCredito;
char	sArchCredito[100];
char	sSoloArchCredito[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

ClsOPL   *regOPL;
long     iCantOPL;
char     sSucursalActual[5];

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;
$char sFechaCorrida[11];

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
$ClsCliente regCliente;
$ClsImpuesto regImpu;
ClsOP   regOP;
ClsOPK  regOPK;
double   dSaldoGral;
double   sumaOp;
$long    lFechaVigTarifa;
char     sTipo[2];

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	$SET ISOLATION TO CURSOR STABILITY;
	
	CreaPrepare();

/*
	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
*/
		
	
	/* Registrar Control Plano */
/*   
   $BEGIN WORK;
   
   iCorrelativos = getCorrelativo("FICA");
   
	if(!RegistraArchivo()){
		$ROLLBACK WORK;
		exit(1);
	}
	$COMMIT WORK;
*/

   $EXECUTE selFechaRti INTO :lFechaRti;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha RTI\n");
      exit(2);
   }
   		
   memset(sFechaCorrida, '\0', sizeof(sFechaCorrida));
   $EXECUTE selFechaActualFmt INTO :sFechaCorrida;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha Corrida\n");
      exit(2);
   }
   
   
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */

	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(sSucursal, '\0', sizeof(sSucursal));
   memset(sSucursalActual, '\0', sizeof(sSucursalActual));
   
/*
	for(i=0; i<12; i++){
*/   
   	/* Registrar Control Plano */
      $BEGIN WORK;
      
      iCorrelativos = getCorrelativo("FICA");
      
   	if(!RegistraArchivo()){
   		$ROLLBACK WORK;
   		exit(1);
   	}
   	$COMMIT WORK;
/*   
		strcpy(sSucursal, vSucursal[i]);
      strcpy(sSucursalActual, vSucursal[i]);
*/
		if(!AbreArchivos(sSucursal)){
			exit(1);	
		}
		
		if(glNroCliente > 0){
			$OPEN curClientes using :glNroCliente, :sSucursal;
		}else{
			/*$OPEN curClientes using :sSucursal;*/
         $OPEN curClientes;
		}
		
		printf("Procesando Sucursal %s......\n", sSucursal);
      
      while(LeoCliente(&regCliente)){
         
         if(!ClienteYaMigrado(regCliente.numero_cliente, &lFechaVigTarifa, &iFlagMigra)){
            dSaldoGral = getSaldoGral(regCliente);
            rfmtdate(lFechaVigTarifa, "yyyymmdd", regCliente.sFechaVigTarifa); /* long to char */
            inicializaOPL(&(regOPL));
            strcpy(sTipo, "D");
            if(dSaldoGral < 0){
               /* Saldo a favor del Cliente */
               GeneraSaldoCliente(pFileGral, regCliente);
               strcpy(sTipo, "C");
            }else{
               strcpy(sTipo, "D");
               /* ageing */
               ProcesaAgeing(regCliente);
            }

            /* Saldos en disputa */
            ProcesaDisputa(regCliente, sTipo);
            inicializaOPL(&(regOPL));
            
            /* Saldos Convenios */
            ProcesaConvenios(regCliente, sTipo);

            /* Genera Bloqueos */
/*            
            if(iCantOPL>0){
               GenerarKO(pFileLock, regCliente);
               GenerarOPL(pFileLock, regCliente, regOPL);
               GeneraENDE(pFileLock, regCliente);
            }            
*/

/*                           
            $BEGIN WORK;
            
            if(!RegistraCliente(regCliente.numero_cliente,iFlagMigra)){
              $ROLLBACK WORK;
              exit(2);
            }
            $COMMIT WORK;
*/            
            cantProcesada++;
         }else{
            cantPreexistente++;
         }         
         
      } /* Clientes */
   
      $CLOSE curClientes;

      CerrarArchivos();
      
      FormateaArchivos();
/*      
   }  // Sucursales 
*/
	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */




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
	printf("Documentos FICA\n");
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
   
	if(argc==6){
		glNroCliente=atoi(argv[5]);
	}else{
		glNroCliente=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos, 2=Ambos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0=Normal, 1=Reducida\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos(sSucur)
char  sSucur[5];
{
	
   strcpy(sSucur, "");
   
	memset(sArchSalidaGral,'\0',sizeof(sArchSalidaGral));
	memset(sSoloArchSalidaGral,'\0',sizeof(sSoloArchSalidaGral));

	memset(sArchCNR,'\0',sizeof(sArchCNR));
	memset(sSoloArchCNR,'\0',sizeof(sSoloArchCNR));

	memset(sArchConve,'\0',sizeof(sArchConve));
	memset(sSoloArchConve,'\0',sizeof(sSoloArchConve));

	memset(sArchDispu,'\0',sizeof(sArchDispu));
	memset(sSoloArchDispu,'\0',sizeof(sSoloArchDispu));
/*
	memset(sArchCredito,'\0',sizeof(sArchCredito));
	memset(sSoloArchCredito,'\0',sizeof(sSoloArchCredito));
*/
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

   /* SALDO GENERAL */
	sprintf( sArchSalidaGral  , "%sT1FICA_GRAL_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchSalidaGral, "T1FICA_GRAL_%s.unx", sSucur);

	pFileGral=fopen( sArchSalidaGral, "w" );
	if( !pFileGral ){
		printf("ERROR al abrir archivo %s.\n", sArchSalidaGral );
		return 0;
	}
	
   /* SALDO CNR */
	sprintf( sArchCNR  , "%sT1FICA_CNR_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchCNR, "T1FICA_CNR_%s.unx", sSucur);

	pFileCNR=fopen( sArchCNR, "w" );
	if( !pFileCNR ){
		printf("ERROR al abrir archivo %s.\n", sArchCNR );
		return 0;
	}
   
   /* SALDO CONVENIOS */
	sprintf( sArchConve  , "%sT1FICA_CONVE_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchConve, "T1FICA_CONVE_%s.unx", sSucur);

	pFileConve=fopen( sArchConve, "w" );
	if( !pFileConve ){
		printf("ERROR al abrir archivo %s.\n", sArchConve );
		return 0;
	}
   
   /* SALDO DISPUTA */
	sprintf( sArchDispu  , "%sT1FICA_DISPUTA_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchDispu, "T1FICA_DISPUTA_%s.unx", sSucur);

	pFileDispu=fopen( sArchDispu, "w" );
	if( !pFileDispu ){
		printf("ERROR al abrir archivo %s.\n", sArchDispu );
		return 0;
	}
   
   /* SALDO CREDITO PARA EL CLIENTE */
/*   
	sprintf( sArchCredito  , "%sT1FICA_CREDITO_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchCredito, "T1FICA_CREDITO_%s.unx", sSucur);

	pFileCredito=fopen( sArchCredito, "w" );
	if( !pFileCredito ){
		printf("ERROR al abrir archivo %s.\n", sArchCredito );
		return 0;
	}
*/ 
	return 1;	
}

void CerrarArchivos(void){
	fclose(pFileGral);
   fclose(pFileCNR);
   fclose(pFileConve);
   fclose(pFileDispu);
   /*fclose(pFileCredito);*/
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];


	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	if(giEstadoCliente==0){
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/Fica/", sPathCopia);
	}else{
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}
	
   /* Saldo General */
	sprintf(sCommand, "chmod 755 %s", sArchSalidaGral);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchSalidaGral, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchSalidaGral);
   iRcv=system(sCommand);
   
   /* Saldo CNR */
	sprintf(sCommand, "chmod 755 %s", sArchCNR);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchCNR, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchCNR);
   iRcv=system(sCommand);
   
   /* Saldo Convenios */
	sprintf(sCommand, "chmod 755 %s", sArchConve);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchConve, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchConve);
   iRcv=system(sCommand);
   
   /* Saldo Disputa */
	sprintf(sCommand, "chmod 755 %s", sArchDispu);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDispu, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchDispu);
   iRcv=system(sCommand);
   
   /* Saldo Credito */
/*   
	sprintf(sCommand, "chmod 755 %s", sArchCredito);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchCredito, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchCredito);
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
   strcat(sql, "TRIM(t1.acronimo_sap), ");    /* CDC*/
   strcat(sql, "TRIM(t2.cod_sap), ");         /* Tipo IVA*/
   strcat(sql, "c.corr_convenio, ");
   strcat(sql, "c.estado_cobrabilida, ");
   strcat(sql, "c.tiene_convenio, ");
   strcat(sql, "c.tiene_cnr, ");
   strcat(sql, "c.tiene_cobro_int, ");
   strcat(sql, "c.tiene_cobro_rec, ");
   strcat(sql, "c.saldo_actual, ");
   strcat(sql, "c.saldo_int_acum, ");
   strcat(sql, "c.saldo_imp_no_suj_i, ");
   strcat(sql, "c.saldo_imp_suj_int, ");
   strcat(sql, "c.valor_anticipo, ");
   strcat(sql, "c.antiguedad_saldo, ");
   strcat(sql, "TRIM(t3.cod_sap), ");         /* sucursal SAP */
   strcat(sql, "c.corr_facturacion ");
   strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3 ");

   if(giTipoCorrida == 1)	
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
/*   
	strcat(sql, "AND c.sucursal = ? ");
*/   
	strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND c.sector != 88 ");
   strcat(sql, "AND t1.clave = 'TIPCLI' ");
   strcat(sql, "AND t1.cod_mac = c.tipo_cliente ");
   strcat(sql, "AND t2.clave = 'TIPIVA' ");
   strcat(sql, "AND t2.cod_mac = c.tipo_iva ");
   strcat(sql, "AND t3.clave = 'CENTROOP' ");
   strcat(sql, "AND t3.cod_mac = c.sucursal ");

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

   /******** Cursor Impuestos ****************/
	strcpy(sql, "SELECT s.codigo_impuesto, "); 
	strcat(sql, "c.descripcion, "); 
	strcat(sql, "s.saldo, "); 
	strcat(sql, "c.ind_afecto_int, ");
	strcat(sql, "t1.hvorg, "); 
	strcat(sql, "t1.hkont, "); 
	strcat(sql, "t1.tvorg, "); 
	strcat(sql, "t1.optxt ");
	strcat(sql, "FROM saldos_impuestos s, codca c, sap_trafo_fica t1 ");
	strcat(sql, "WHERE s.numero_cliente = ? ");
	strcat(sql, "AND s.saldo != 0 ");
	strcat(sql, "AND c.codigo_cargo = s.codigo_impuesto ");
	strcat(sql, "AND t1.cod_mac = s.codigo_impuesto ");
	strcat(sql, "AND ((s.saldo >=0 and t1.tipo_cargo = 'S') OR (s.saldo < 0 and t1.tipo_cargo = 'H'))");   

	$PREPARE selImpuestos FROM $sql;
	
	$DECLARE curImpuestos CURSOR WITH HOLD FOR selImpuestos;
	
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
	strcat(sql, "'FICA', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT fica, fecha_val_tarifa FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, fica ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "fica = 'S' ");
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

   /************ Cursor Ageing **************/
   $PREPARE selAgeing FROM "SELECT a.tipo_saldo,
      a.corr_facturacion,
      a.fecha_vencimiento1,
      a.cod_cargo,
      a.valor_cargo,
      t.hvorg,
      t.hkont,
      t.tvorg,
      t.optxt
      FROM sap_ageing a, sap_trafo_fica t
      WHERE a.numero_cliente = ?
      AND a.valor_cargo != 0
      AND a.cod_cargo NOT IN ('SA8', 'SA9')
      AND t.cod_mac = a.cod_cargo
      AND ((a.tipo_saldo != 'CNR' and t.cnr='N' 
      		and(a.valor_cargo >=0 and t.tipo_cargo = 'S') OR (a.valor_cargo < 0 and t.tipo_cargo = 'H'))      
      	OR
       		(a.tipo_saldo = 'CNR' and a.cod_cargo not in ('SA4', 'SA5') and t.cnr='N'
         	and (a.valor_cargo >=0 and t.tipo_cargo = 'S') OR (a.valor_cargo < 0 and t.tipo_cargo = 'H')) 
        OR
       		(a.tipo_saldo = 'CNR' and a.cod_cargo in ('SA4', 'SA5') and t.cnr = 'S'
         	and (a.valor_cargo >=0 and t.tipo_cargo = 'S') OR (a.valor_cargo < 0 and t.tipo_cargo = 'H'))
      ) 
      ORDER BY a.tipo_saldo ASC, a.corr_facturacion, 
      a.fecha_vencimiento1 ASC, a.cod_cargo DESC ";

   $DECLARE curAgeing CURSOR FOR selAgeing;

   /************ Saldos Convenio **************/
   $PREPARE selConvenio FROM "SELECT saldo_actual, 
      saldo_int_acum, 
      saldo_imp_no_suj_i, 
      saldo_imp_suj_int
      FROM saldos_convenio
      WHERE numero_cliente = ? ";
   
   /************ Saldos en Disputa **************/
   $PREPARE selDisputa FROM "SELECT nro_saldo_disputa, 
      ndocum_enre, 
      reclamo, 
      monto_disputa, 
      saldo_actual, 
      saldo_int_acum, 
      saldo_imp_no_suj_i, 
      saldo_imp_suj_int, 
      fecha_autoriza
      FROM sd_saldo_disputa
      WHERE numero_cliente = ?
      AND estado = 'V' 
      ORDER BY nro_saldo_disputa ";
      
   $DECLARE curDisputa CURSOR FOR selDisputa;      	

   /************ Saldos Impuestos en Disputa **************/
   $PREPARE selImpDispu FROM "SELECT s.codigo_impuesto,  
      c.descripcion,  
      s.saldo,  
      c.ind_afecto_int, 
      t1.hvorg,  
      t1.hkont,  
      t1.tvorg,  
      t1.optxt 
      FROM sd_saldos_imp s, codca c, sap_trafo_fica t1 
      WHERE s.numero_cliente = ? 
      AND s.nro_saldo_disputa = ?
      AND s.saldo != 0 
      AND c.codigo_cargo = s.codigo_impuesto 
      AND t1.cod_mac = s.codigo_impuesto  
      AND ((s.saldo >=0 and t1.tipo_cargo = 'S') OR (s.saldo < 0 and t1.tipo_cargo = 'H')) ";
      
   $DECLARE curImpDispu CURSOR FOR selImpDispu;
   
   /************ Ultima Factura **************/
   $PREPARE selUltFactu FROM "SELECT TO_CHAR(fecha_facturacion, '%Y%m%d')
      FROM hisfac
      WHERE numero_cliente = ?
      AND corr_facturacion = ?";
   
   /********** Impuestos Saldos Convenios **********/
   $PREPARE selImpuConve FROM "SELECT i.codigo_impuesto,  
      c.descripcion,  
      i.saldo,  
      c.ind_afecto_int, 
      t1.hvorg,  
      t1.hkont,  
      t1.tvorg,  
      t1.optxt 
      FROM detalle_imp_conve i, codca c, sap_trafo_fica t1
      WHERE i.numero_cliente = ?
      AND i.saldo != 0 
      AND c.codigo_cargo = i.codigo_impuesto 
      AND t1.cod_mac = i.codigo_impuesto  
      AND ((i.saldo >=0 and t1.tipo_cargo = 'S') OR (i.saldo < 0 and t1.tipo_cargo = 'H'))";

   $DECLARE curImpuConve CURSOR FOR selImpuConve;
   
   /********** Registra Corrida **********/
   $PREPARE insCorrida FROM "INSERT INTO sap_regiextra (
      estructura,
      fecha_corrida
      )VALUES(
      'FICA',
      CURRENT)";
   
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

short LeoCliente(regCli)
$ClsCliente *regCli;
{

   InicializaCliente(regCli);

	$FETCH curClientes INTO
      :regCli->numero_cliente,
      :regCli->cdc,
      :regCli->tipo_iva,
      :regCli->corr_convenio,
      :regCli->estado_cobrabilida,
      :regCli->tiene_convenio,
      :regCli->tiene_cnr,
      :regCli->tiene_cobro_int,
      :regCli->tiene_cobro_rec,
      :regCli->saldo_actual,
      :regCli->saldo_int_acum,
      :regCli->saldo_imp_no_suj_i,
      :regCli->saldo_imp_suj_int,
      :regCli->valor_anticipo,
      :regCli->antiguedad_saldo,
      :regCli->sucur_sap,
      :regCli->corr_facturacion;
      
  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

  $EXECUTE selUltFactu INTO :regCli->sFechaUltFactura USING :regCli->numero_cliente,
                                                            :regCli->corr_facturacion;
                                                            
   if(SQLCODE != 0){
      strcpy(regCli->sFechaUltFactura, FechaGeneracion);
      printf("No se encontró ult.factura del cliente %ld !!!\nProceso Abortado.\n", regCli->numero_cliente);
   }                                                            
  
  alltrim(regCli->cdc, ' ');
  alltrim(regCli->tipo_iva, ' ');
  alltrim(regCli->sucur_sap, ' ');
  
	return 1;	
}

void InicializaCliente(regCli)
$ClsCliente *regCli;
{
	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
   memset(regCli->cdc, '\0', sizeof(regCli->cdc));

   memset(regCli->tipo_iva, '\0', sizeof(regCli->tipo_iva));
   rsetnull(CINTTYPE, (char *) &(regCli->corr_convenio));
   memset(regCli->estado_cobrabilida, '\0', sizeof(regCli->estado_cobrabilida));
   memset(regCli->tiene_convenio, '\0', sizeof(regCli->tiene_convenio));
   memset(regCli->tiene_cnr, '\0', sizeof(regCli->tiene_cnr));
   memset(regCli->tiene_cobro_int, '\0', sizeof(regCli->tiene_cobro_int));
   memset(regCli->tiene_cobro_rec, '\0', sizeof(regCli->tiene_cobro_rec));
   rsetnull(CDOUBLETYPE, (char *) &(regCli->saldo_actual));
   rsetnull(CDOUBLETYPE, (char *) &(regCli->saldo_int_acum));
   rsetnull(CDOUBLETYPE, (char *) &(regCli->saldo_imp_no_suj_i));
   rsetnull(CDOUBLETYPE, (char *) &(regCli->saldo_imp_suj_int));
   rsetnull(CDOUBLETYPE, (char *) &(regCli->valor_anticipo));
   rsetnull(CINTTYPE, (char *) &(regCli->antiguedad_saldo));
   memset(regCli->sucur_sap, '\0', sizeof(regCli->sucur_sap));
   memset(regCli->sFechaVigTarifa, '\0', sizeof(regCli->sFechaVigTarifa));
   memset(regCli->sFechaUltFactura, '\0', sizeof(regCli->sFechaUltFactura));
   rsetnull(CINTTYPE, (char *) &(regCli->corr_facturacion));
}


short ClienteYaMigrado(nroCliente, lFecha, iFlagMigra)
$long	   nroCliente;
$long    *lFecha;
int		*iFlagMigra;
{
	$char	sMarca[2];
	$long   lFechaAux;
   
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca, :lFechaAux using :nroCliente;
		
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
		
   *lFecha = lFechaAux;
   
	return 0;
}

void GeneraSaldoCliente(fp, regClie)
FILE           *fp;
$ClsCliente     regClie;
{
   ClsOP regOP;
   ClsOPK   regOPK;
   $ClsImpuesto regImpu;
   double dMonto;
   int      inx1, inx2;
   
   inx1=1;
   inx2=1;
   
   BORRA_STR(&regOP);
   
   GenerarKO(fp, regClie, 1);
   
   CopiaClienteToOp(regClie, &regOP);

   memset(regOP.HKONT, '\0', sizeof(regOP.HKONT));
   
   /* Operacion Plana Cliente */
   
   /*strcpy(regOP.TVORG, "996");*/
   if(regClie.saldo_actual != 0.00){
      if(regClie.saldo_actual > 0){
         strcpy(regOP.TVORG, "0001");
      }else{
         strcpy(regOP.TVORG, "1001");   
      }
      strcpy(regOP.OPTXT, "MIG - Saldo Actual");
      sprintf(regOP.BETRW, "%.02lf", regClie.saldo_actual);
      strcpy(regOP.PSWBT, regOP.BETRW);
      GenerarOP(fp, regOP, inx1, "C", 1);
      CargaOPL(regClie, inx1, &(regOPL), "M", 0);
      
      inx1++;
   }

   /*strcpy(regOP.TVORG, "995");*/
   if(regClie.saldo_int_acum != 0.00){
      if(regClie.saldo_int_acum > 0){
         strcpy(regOP.TVORG, "0002");
      }else{
         strcpy(regOP.TVORG, "1002");   
      }
      strcpy(regOP.OPTXT, "MIG - Intereses Acumulados");
      sprintf(regOP.BETRW, "%.02lf", regClie.saldo_int_acum);
      strcpy(regOP.PSWBT, regOP.BETRW);
      GenerarOP(fp, regOP, inx1, "C", 1);
      CargaOPL(regClie, inx1, &(regOPL), "M", 0);
      inx1++;
   }

   if(fabs(regClie.valor_anticipo) >= 0.01){
      strcpy(regOP.TVORG, "0003");
      strcpy(regOP.OPTXT, "MIG - Valor Anticipo");
      sprintf(regOP.BETRW, "%.02lf", regClie.valor_anticipo);
      strcpy(regOP.PSWBT, regOP.BETRW);
      GenerarOP(fp, regOP, inx1, "C", 1);
      CargaOPL(regClie, inx1, &(regOPL), "M", 0);
      inx1++;
   }   

/*
   strcpy(regOP.TVORG, "997");
   strcpy(regOP.OPTXT, "Saldo No Sujeto a Intereses");
   strcpy(regOP.BETRW, "0.00");
   strcpy(regOP.PSWBT, regOP.BETRW);
   
   GenerarOP(regOP, inx1);
   CargaOPL(regClie, inx1, &(regOPL));   
   inx1++;

   if(regClie.saldo_imp_suj_int >= 0){
      strcpy(regOP.TVORG, "998");
   }else{
      strcpy(regOP.TVORG, "1998");   
   }
   strcpy(regOP.OPTXT, "Saldo Impuestos Sujeto a Intereses");
   sprintf(regOP.BETRW, "%.02lf", regClie.saldo_imp_suj_int);
   strcpy(regOP.PSWBT, regOP.BETRW);
   GenerarOP(regOP, inx1);
   CargaOPL(regClie, inx1, &(regOPL));
   inx1++;   

   if(regClie.saldo_imp_no_suj_i >= 0){
      strcpy(regOP.TVORG, "999");
   }else{
      strcpy(regOP.TVORG, "1999");   
   }
   strcpy(regOP.OPTXT, "Saldo Impuestos No Sujeto a Intereses");
   sprintf(regOP.BETRW, "%.02lf", regClie.saldo_imp_no_suj_i);
   strcpy(regOP.PSWBT, regOP.BETRW);
   GenerarOP(regOP, inx1);
   CargaOPL(regClie, inx1, &(regOPL));
   inx1++;   
*/   
/*   
   dMonto = (regClie.saldo_int_acum + regClie.saldo_imp_no_suj_i + regClie.saldo_imp_suj_int) * -1;   
   BORRA_STR(&regOPK);
   CopiaClienteToOpk(regClie, dMonto, &regOPK);
   GenerarOPK(regOPK, 1);

*/
   dMonto = regClie.saldo_actual + regClie.saldo_int_acum + regClie.valor_anticipo;
   /*dMonto = (regClie.saldo_int_acum + regClie.saldo_imp_no_suj_i + regClie.saldo_imp_suj_int);*/

   /* Saldos Impuestos */               
   
   
   $OPEN curImpuestos USING :regClie.numero_cliente;
   
   while(LeoImpuestos(&regImpu, regClie.numero_cliente)){
      BORRA_STR(&regOP);
      CopiaImpuToOp(regClie, regImpu, &regOP);
      GenerarOP(fp, regOP, inx1, "C", 1);
      
      CargaOPL(regClie, inx1, &(regOPL), "M", 0);
      inx1++;
      
      dMonto+=regImpu.saldo;
      
   }
   $CLOSE curImpuestos;

	if(risnull(CDOUBLETYPE, (char *) &dMonto)){
      dMonto=0;
   }

   if(dMonto != 0.00){
      dMonto=dMonto * -1;
   }
   
   BORRA_STR(&regOPK);
   CopiaClienteToOpk(regClie, dMonto, &regOPK);
   GenerarOPK(fp, regOPK, 1, "C");

   if(iCantOPL>0){
      GenerarOPL(fp, regClie, regOPL, "G", 1);
   }
               
   GeneraENDE(fp, regClie, 1);
}

/*
void GenerarPlanos(regClie)
ClsCliente     regClie;
{
   int i=1;
   double dMonto;
   
   // GenerarKO(regClie); 

   // Operacion Plana Cliente 
      dMonto = (regClie.saldo_int_acum + regClie.saldo_imp_no_suj_i + regClie.saldo_imp_suj_int) * -1;
      
      // intereses acum    
      GenerarOP(regClie, 1, "0995");
      // saldo sujeto a intereses
      GenerarOP(regClie, 2, "0996");
      // saldo NO sujeto a intereses
      GenerarOP(regClie, 3, "0997");
      // Impuestos sujeto a intereses
      GenerarOP(regClie, 4, "0998");
      // Impuestos No sujeto a intereses
      GenerarOP(regClie, 5, "0999");

      GenerarOPK(regClie, 1, dMonto);
            
   GenerarOPL(regClie);
   
   GeneraENDE(regClie);

}
*/

void GenerarKO(fp, regClie, inx)
FILE *fp;
ClsCliente  regClie;
int   inx;
{
   char  sLinea[1000];
   int   iRcv;
   
   memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
   sprintf(sLinea, "T1%ld-%ld\tKO\t", regClie.numero_cliente, inx);   

   /* FIKEY (eliminado) */
   /*sprintf(sLinea, "%sMSGD%sT1\t", sLinea, sSucursalActual);*/
   /*sprintf(sLinea, "%sMSGD%02dT1\t", sLinea, iCorrelativos);*/
   /*strcat(sLinea, "MGSDOT1\t");*/
   
   /* APPLK */
   strcat(sLinea, "R\t");
   
   /* BLART */
   strcat(sLinea, "MGSDOT1\t");
   
   /* HERKF */
   strcat(sLinea, "R1\t");
   
   /* WAERS */
   strcat(sLinea, "ARS\t");
   
   /* BLDAT */
   /*sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);*/
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCorrida);
   
   /* BUDAT */
   /*sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);*/
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCorrida);
   
   /* XBLNR */
   sprintf(sLinea, "%s%ld", sLinea, regClie.numero_cliente);

   strcat(sLinea, "\n");
  
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KO\n");
      exit(1);
   }	


}


void GenerarOP(fp, regOp, inx, sTipo, inx1)
FILE  *fp;
ClsOP regOp;
int   inx;
char  sTipo[2];
int   inx1;
{
   char  sLinea[1000];
   double   auxDbl;
   int   iRcv;
   
   memset(sLinea, '\0', sizeof(sLinea));

   alltrim(regOp.nroCliente, ' ');
   alltrim(regOp.BUKRS, ' ');
   alltrim(regOp.GSBER, ' ');
   alltrim(regOp.GPART, ' ');
   alltrim(regOp.VTREF, ' ');
   alltrim(regOp.VKONT, ' ');
   alltrim(regOp.HVORG, ' ');
   alltrim(regOp.TVORG, ' ');
   alltrim(regOp.KOFIZ, ' ');
   alltrim(regOp.SPART, ' ');
   alltrim(regOp.HKONT, ' ');
   alltrim(regOp.MWSKZ, ' ');
   alltrim(regOp.XANZA, ' ');
   alltrim(regOp.STAKZ, ' ');
   alltrim(regOp.BUDAT, ' ');
   alltrim(regOp.OPTXT, ' ');
   alltrim(regOp.FAEDN, ' ');
   alltrim(regOp.BETRW, ' ');
   alltrim(regOp.SBETW, ' ');
   alltrim(regOp.AUGRS, ' ');
   alltrim(regOp.SPERZ, ' ');
   alltrim(regOp.BLART, ' ');
   alltrim(regOp.FINRE, ' ');
   alltrim(regOp.PSWBT, ' ');
   alltrim(regOp.SEGMENT, ' ');
   
   /* LLAVE */
   sprintf(sLinea, "T1%s-%ld\tOP\t", regOp.nroCliente, inx1);   

   /* OPUPK */
   sprintf(sLinea, "%s%04d\t", sLinea, inx);
   
   /* BUKRS */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.BUKRS);
   
   /* GSBER */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.GSBER);
   
   /* GPART */
   sprintf(sLinea, "%sT1%s\t", sLinea, regOp.GPART);
   
   /* VTREF (vacio) */
   strcat(sLinea, "\t");
   
   /* VKONT */
   sprintf(sLinea, "%sT1%s\t", sLinea, regOp.VKONT);
   
   /* HVORG */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.HVORG);
   
   /* TVORG */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.TVORG);
   
   /* KOFIZ */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.KOFIZ);
   
   /* SPART (vacio) */
   strcat(sLinea, "\t");
   
   /* HKONT (a definir) */
   strcat(sLinea, "0099999994\t");
   /*strcat(sLinea, "0099999996\t");*/
   /*
   if(strcmp(regOp.HKONT, "")!=0){
      sprintf(sLinea, "%s%s\t", sLinea, regOp.HKONT);
   }else{
      strcat(sLinea, "\t");
   }
   */
   
   /* MWSKZ  (vacio) */
   strcat(sLinea, "\t");
   /* XANZA (vacio) */
   strcat(sLinea, "\t");
   /* STAKZ (vacio) */
   strcat(sLinea, "\t");
   
   /* BUDAT */
   sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);
   
   /* OPTXT */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.OPTXT);
   
   /* FAEDN () */
   if(strcmp(regOp.FAEDN, "")!= 0){
      sprintf(sLinea, "%s%s\t", sLinea, regOp.FAEDN);
   }else{
      strcat(sLinea, "99991231\t");
   }
   
   /* BETRW */
   /*
   auxDbl = atof(regOp.BETRW);
   if(auxDbl < 0)
      sprintf(regOp.BETRW, "%.02f", auxDbl);
   
   if(auxDbl!=0){
      if(sTipo[0]=='D'){
         sprintf(sLinea, "%s-%s\t", sLinea, regOp.BETRW);
      }else{
         sprintf(sLinea, "%s%s\t", sLinea, regOp.BETRW);;
      }
   }else{
      strcat(sLinea, "0.00\t");
   }
   */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.BETRW);;
   
   /* SBETW (vacio) */
   strcat(sLinea, "\t");
   
   /* AUGRS (vacio) */
   strcat(sLinea, "\t");
      
   /* SPERZ (?) */
   strcat(sLinea, "\t");
   
   /* BLART */
   sprintf(sLinea, "%s%s\t", sLinea, regOp.BLART);
   
   /* FINRE (vacio) */
   strcat(sLinea, "\t");
   
   /* PSWBT */
/*   
   auxDbl = atof(regOp.PSWBT);
   if(auxDbl < 0)
      sprintf(regOp.PSWBT, "%.02f", auxDbl);
   if(auxDbl!=0){
      if(sTipo[0]=='D'){
         sprintf(sLinea, "%s-%s\t", sLinea, regOp.PSWBT);
      }else{
         sprintf(sLinea, "%s%s\t", sLinea, regOp.PSWBT);
      }
   }else{
      strcat(sLinea, "0.00\t");
   }
*/   
   sprintf(sLinea, "%s%s\t", sLinea, regOp.PSWBT);
   /* SEGMENT (vacio) */

   strcat(sLinea, "\n");
  
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir OP\n");
      exit(1);
   }	


}

void GenerarOPK(fp, regOpk, inx, sTipo)
FILE *fp;
ClsOPK      regOpk;
int         inx;
char        sTipo[2];
{
   char  sLinea[1000];
   double auxDbl;
   int   iRcv;
   
   memset(sLinea, '\0', sizeof(sLinea));

   alltrim(regOpk.nroCliente, ' ');
   alltrim(regOpk.BUKRS, ' ');
   alltrim(regOpk.HKONT, ' ');
   alltrim(regOpk.PRCTR, ' ');
   alltrim(regOpk.KOSTL, ' ');
   alltrim(regOpk.BETRW, ' ');
   alltrim(regOpk.MWSKZ, ' ');
   alltrim(regOpk.SBASH, ' ');
   alltrim(regOpk.SBASW, ' ');
   alltrim(regOpk.KTOSL, ' ');
   alltrim(regOpk.STPRZ, ' ');
   alltrim(regOpk.KSCHL, ' ');
   alltrim(regOpk.SEGMENT, ' ');


   /* LLAVE */
   sprintf(sLinea, "T1%s-%ld\tOPK\t", regOpk.nroCliente, inx);   

   /* OPUPK */
   sprintf(sLinea, "%s%04d\t", sLinea, inx);
   
   /* BUKRS */
   sprintf(sLinea, "%s%s\t", sLinea, regOpk.BUKRS);
   
   /* HKONT (?) */
   strcat(sLinea, "0099999996\t");
   /*strcat(sLinea, "0099999994\t");*/
         
   /* PRCTR (vacio) */
   strcat(sLinea, "\t");
   
   /* KOSTL (vacio) */
   strcat(sLinea, "\t");
   
   /* BETRW */
/*   
   auxDbl=atof(regOpk.BETRW);
   if(auxDbl !=  0.00){
      if(auxDbl<0)
         auxDbl = auxDbl * -1;
      
      sprintf(regOpk.BETRW, "%.02f", auxDbl);
         
      if(sTipo[0]=='D'){
         sprintf(sLinea, "%s-%s\t", sLinea, regOpk.BETRW);
      }else{
         sprintf(sLinea, "%s%s\t", sLinea, regOpk.BETRW);
      }
   }else{
      strcat(sLinea, "0.00\t");
   }
*/
   sprintf(sLinea, "%s%s\t", sLinea, regOpk.BETRW);
   
   /* MWSKZ */
   /*sprintf(sLinea, "%s%s\t", sLinea, regOpk.MWSKZ);*/
   strcat(sLinea, "\t");
      
   /* SBASH (?) */
   strcat(sLinea, "\t");
   
   /* SBASW (?) */
   strcat(sLinea, "\t");
   
   /* KTOSL (vacio) */
   strcat(sLinea, "\t");
   
   /* STPRZ (?) */
   strcat(sLinea, "\t");
   
   /* KSCHL (vacio) */
   strcat(sLinea, "\t");
   
   /* SEGMENT (vacio) */

   strcat(sLinea, "\n");
  
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir OPK\n");
      exit(1);
   }	


}

void GenerarOPL(fp, regClie, regOpl, sTipo, inx)
FILE *fp;
ClsCliente regClie;
ClsOPL      *regOpl;
char        sTipo[2];
int         inx;
{
	char	sLinea[1000];
   long  iFila;	
   long  lSize;
   int   iRcv;
   
   for(iFila=0; iFila<iCantOPL; iFila++){
   	memset(sLinea, '\0', sizeof(sLinea));

      /**** El de Intereses ****/   
      /* LLAVE */
      sprintf(sLinea, "T1%ld-%d\tOPL\t", regClie.numero_cliente, inx);   
      /* OPUPK (vacio) */
      sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].OPUPK);
      /* PROID (vacio) */
      sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].PROID);
      /* LOCKR (vacio) */
      sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].LOCKR);
      /* FDATE (vacio) */
      sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].FDATE);
      /* TDATE (vacio) */
      sprintf(sLinea, "%s%s", sLinea, regOpl[iFila].TDATE);
      
      strcat(sLinea, "\n");
      
   	iRcv=fprintf(fp, sLinea);
      if(iRcv < 0){
         printf("Error al escribir OPL\n");
         exit(1);
      }	

   
      if(sTipo[0]=='D'){
         /**** El de Reclamaciones ****/
         memset(sLinea, '\0', sizeof(sLinea));
         /* LLAVE */
         sprintf(sLinea, "T1%ld-%d\tOPL\t", regClie.numero_cliente, inx);   
         /* OPUPK (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].OPUPK);
         /* PROID (vacio) */
         sprintf(sLinea, "%s01\t", sLinea);
         /* LOCKR (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].LOCKR);
         /* FDATE (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regClie.sFechaVigTarifa);
         /* TDATE (vacio) */
         sprintf(sLinea, "%s99991231", sLinea);
         
         strcat(sLinea, "\n");
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir OPL\n");
            exit(1);
         }	

   
         /**** El de Contabilizar ****/
         memset(sLinea, '\0', sizeof(sLinea));
         /* LLAVE */
         sprintf(sLinea, "T1%ld-%d\tOPL\t", regClie.numero_cliente, inx);   
         /* OPUPK (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].OPUPK);
         /* PROID (vacio) */
         sprintf(sLinea, "%s09\t", sLinea);
         /* LOCKR (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].LOCKR);
         /* FDATE (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regClie.sFechaVigTarifa);
         /* TDATE (vacio) */
         sprintf(sLinea, "%s99991231", sLinea);
         
         strcat(sLinea, "\n");
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir OPL\n");
            exit(1);
         }	

         
         /**** El de Pagos ****/
         memset(sLinea, '\0', sizeof(sLinea));
         /* LLAVE */
         sprintf(sLinea, "T1%ld-%d\tOPL\t", regClie.numero_cliente, inx);   
         /* OPUPK (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].OPUPK);
         /* PROID (vacio) */
         sprintf(sLinea, "%s10\t", sLinea);
         /* LOCKR (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regOpl[iFila].LOCKR);
         /* FDATE (vacio) */
         sprintf(sLinea, "%s%s\t", sLinea, regClie.sFechaVigTarifa);
         /* TDATE (vacio) */
         sprintf(sLinea, "%s99991231", sLinea);
         
         strcat(sLinea, "\n");
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir OPL\n");
            exit(1);
         }	

      }      
   }
   

}

void GeneraENDE(fp, regCli, inx)
FILE *fp;
ClsCliente  regCli;
int   inx;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   sprintf(sLinea, "T1%ld-%ld\t&ENDE", regCli.numero_cliente, inx);
   
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
   strcpy(sTipoArchivo, "FICA");
   
	$EXECUTE updGenArchivos using :sTipoArchivo;
/*  
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "FICA");
		strcpy(sNombreArchivo, sSoloArchSalidaGral);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenInstal using
				:gsTipoGenera,
				:lCantidad,
				:glNroCliente,
				:sNombreArchivo;
	}
*/
   $EXECUTE insCorrida;
   	
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

double getSaldoGral(reg)
ClsCliente reg;
{
   double saldo=0;
   
   saldo = reg.saldo_actual + reg.saldo_int_acum + reg.saldo_imp_no_suj_i + reg.saldo_imp_suj_int - reg.valor_anticipo;
   
   return saldo;
}

short LeoImpuestos(reg, lNroCliente)
$ClsImpuesto *reg;
long  lNroCliente;
{

   InicializaImpuesto(reg);
   
   $FETCH curImpuestos INTO 
      :reg->codigo_impuesto, 
      :reg->descripcion, 
      :reg->saldo, 
      :reg->ind_afecto_int,
      :reg->hvorg, 
      :reg->hkont, 
      :reg->tvorg, 
      :reg->optxt;

   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error al buscar impuestos para cliente %ld\n", lNroCliente);
      }
      return 0;
   }
   
   alltrim(reg->descripcion, ' ');
   alltrim(reg->optxt, ' ');
   
   return 1;
}

void InicializaImpuesto(reg)
ClsImpuesto *reg;
{

   memset(reg->codigo_impuesto, '\0', sizeof(reg->codigo_impuesto)); 
   memset(reg->descripcion, '\0', sizeof(reg->descripcion)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo)); 
   memset(reg->ind_afecto_int, '\0', sizeof(reg->ind_afecto_int));
   memset(reg->hvorg, '\0', sizeof(reg->hvorg)); 
   memset(reg->hkont, '\0', sizeof(reg->hkont)); 
   memset(reg->tvorg, '\0', sizeof(reg->tvorg)); 
   memset(reg->optxt, '\0', sizeof(reg->optxt));

}

void CopiaClienteToOp(regClie, regOp)
ClsCliente regClie;
ClsOP       *regOp;
{

   InicializaOP(regOp);
   
   sprintf(regOp->nroCliente, "%ld", regClie.numero_cliente);
   /* BUKRS */
   strcpy(regOp->BUKRS, "EDES");
   
   /* GSBER */
   strcpy(regOp->GSBER, regClie.sucur_sap);
   
   /* GPART */
   sprintf(regOp->GPART, "%ld", regClie.numero_cliente);
   
   /* VTREF (vacio) */
   /* VKONT */
   sprintf(regOp->VKONT, "%ld", regClie.numero_cliente);
   
   /* HVORG */
   strcpy(regOp->HVORG, "9996");
   
   /* TVORG (lo cargo afuera)*/
   /* KOFIZ */
   strcpy(regOp->KOFIZ, regClie.cdc);
   
   /* SPART (vacio) */
   /* HKONT (a definir) */
   /* MWSKZ  (vacio) */
   /* XANZA (vacio) */
   /* STAKZ (vacio) */
   
   /* BUDAT */
   strcpy(regOp->BUDAT, FechaGeneracion); 
   
   /* OPTXT (lo cargo afuera)*/
   /* FAEDN (?) */
   /* BETRW (lo cargo afuera) */
   /* SBETW (vacio) */
   /* AUGRS (vacio) */
   /* SPERZ (?) */
   /* BLART */
   
   strcpy(regOp->BLART, "MG");
   
   /* FINRE (vacio) */
   /* PSWBT (lo cargo afuera )*/
   /* SEGMENT (vacio) */

   
}

void InicializaOPK(reg)
ClsOPK   *reg;
{
   memset(reg->nroCliente, '\0', sizeof(reg->nroCliente));
   
   memset(reg->BUKRS, '\0', sizeof(reg->nroCliente));
   memset(reg->HKONT, '\0', sizeof(reg->nroCliente));
   memset(reg->PRCTR, '\0', sizeof(reg->nroCliente));
   memset(reg->KOSTL, '\0', sizeof(reg->nroCliente));
   memset(reg->BETRW, '\0', sizeof(reg->nroCliente));
   memset(reg->MWSKZ, '\0', sizeof(reg->nroCliente));
   memset(reg->SBASH, '\0', sizeof(reg->nroCliente));
   memset(reg->SBASW, '\0', sizeof(reg->nroCliente));
   memset(reg->KTOSL, '\0', sizeof(reg->nroCliente));
   memset(reg->STPRZ, '\0', sizeof(reg->nroCliente));
   memset(reg->KSCHL, '\0', sizeof(reg->nroCliente));
   memset(reg->SEGMENT, '\0', sizeof(reg->nroCliente));

}


void CopiaClienteToOpk(regClie, dMonto, regOpk)
ClsCliente regClie;
double      dMonto;
ClsOPK     *regOpk;
{
   
   InicializaOPK(regOpk);
   
   sprintf(regOpk->nroCliente, "%ld", regClie.numero_cliente);
   
   /* BUKRS */
   strcpy(regOpk->BUKRS, "EDES");
   
   /* HKONT (?) */
   /* PRCTR (vacio) */
   /* KOSTL (vacio) */
   
   /* BETRW */
   if(!risnull(CDOUBLETYPE, (char *) &dMonto)){
      sprintf(regOpk->BETRW, "%.02f", dMonto);
   }else{
      strcpy(regOpk->BETRW, "0.00");   
   }
   
   /* MWSKZ */
   sprintf(regOpk->MWSKZ, "%s", regClie.tipo_iva);
      
   /* SBASH (?) */
   /* SBASW (?) */
   /* KTOSL (vacio) */
   /* STPRZ (?) */
   /* KSCHL (vacio) */
   /* SEGMENT (vacio) */

}

void CopiaImpuToOp(regClie, regImpu, regOp)
ClsCliente  regClie;
ClsImpuesto regImpu;
ClsOP       *regOp;
{
   double dValor=0;
   
   InicializaOP(regOp);
   
   sprintf(regOp->nroCliente, "%ld", regClie.numero_cliente);
   /* BUKRS */
   strcpy(regOp->BUKRS, "EDES");
   
   /* GSBER */
   strcpy(regOp->GSBER, regClie.sucur_sap);
   
   /* GPART */
   sprintf(regOp->GPART, "%ld", regClie.numero_cliente);
   
   /* VTREF (vacio) */
   /* VKONT */
   sprintf(regOp->VKONT, "%ld", regClie.numero_cliente);
   
   /* HVORG */
   sprintf(regOp->HVORG, "%s", regImpu.hvorg);
   
   /* TVORG */
   sprintf(regOp->TVORG, "%s", regImpu.tvorg);
   
   /* KOFIZ */
   strcpy(regOp->KOFIZ, regClie.cdc);
   
   /* SPART (vacio) */
   /* HKONT (a definir) */
   sprintf(regOp->HKONT, "%s", regImpu.hkont);
   
   /* MWSKZ  (vacio) */
   /* XANZA (vacio) */
   /* STAKZ (vacio) */
   
   /* BUDAT */
   strcpy(regOp->BUDAT, FechaGeneracion); 
   
   /* OPTXT */
   sprintf(regOp->OPTXT, "%s", regImpu.optxt);
   
   /* FAEDN (?) */
   /* BETRW  */
   sprintf(regOp->BETRW, "%.02lf", regImpu.saldo);
   
   /* SBETW (vacio) */
   /* AUGRS (vacio) */
   /* SPERZ (?) */
   /* BLART */
   
   strcpy(regOp->BLART, "MG");
   
   /* FINRE (vacio) */
   /* PSWBT */
   sprintf(regOp->PSWBT, "%.02lf", regImpu.saldo);
   
   /* SEGMENT (vacio) */




}

void ProcesaAgeing(regCli)
$ClsCliente regCli;
{
   $ClsAgeing regAge;
   $int  iTeracion=0;
   char  sTipoAnterior[4];
   int   iCorrelAnterior;
   double   dSuma;
   FILE *fpLocal;
   ClsOP   regOP;
   ClsOPK  regOPK;
   int   inx1, inx2;
   $ClsImpuesto regImpu;
   
   inx1=1; inx2=1;
   
   inicializaOPL(&(regOPL));
   
   $OPEN curAgeing USING :regCli.numero_cliente;

   while(LeoAgeing(&regAge)){
      if(iTeracion==0){
         if(strcmp(regAge.tipo_saldo, "SCL")==0){
            fpLocal = pFileGral;
         }else if(strcmp(regAge.tipo_saldo, "CNR")==0){
            fpLocal = pFileCNR;
         }else if(strcmp(regAge.tipo_saldo, "FAC")==0){
            fpLocal = pFileGral;
         }else{
            printf("Tipo de saldo [%s] desconocido para cliente %ld del ageing.\n", regAge.tipo_saldo, regCli.numero_cliente);
            return;
         }
         GenerarKO(fpLocal, regCli, inx2);
         strcpy(sTipoAnterior, regAge.tipo_saldo);
         iCorrelAnterior = regAge.corr_facturacion;
         dSuma=0;
      }   
      if(strcmp(regAge.tipo_saldo, sTipoAnterior)==0 && regAge.corr_facturacion == iCorrelAnterior){
         dSuma += regAge.valor_cargo;
         BORRA_STR(&regOP);
         CopiaClienteAgeToOp(regCli, regAge, &regOP);
         GenerarOP(fpLocal, regOP, inx1, "D", inx2);
         CargaOPL(regCli, inx1, &(regOPL), "M", regAge.fecha_vencimiento1);
         inx1++;
      }else{

         if(risnull(CDOUBLETYPE, (char *) &dSuma)){
            dSuma=0;
         }
         if(dSuma != 0.00){
            dSuma=dSuma *-1;
         }
         
         BORRA_STR(&regOPK);
         CopiaClienteToOpk(regCli, dSuma, &regOPK);
         GenerarOPK(fpLocal, regOPK, inx2, "D");

         /* Cierre y reapertura*/
         if(iCantOPL>0){
            GenerarOPL(fpLocal, regCli, regOPL, "A", inx2);
            inicializaOPL(&(regOPL));
         }
         GeneraENDE(fpLocal, regCli, inx2);

         inx2++;
         
         /* Siguiente documento del cliente */         
         inx1=1;
         if(strcmp(regAge.tipo_saldo, "SCL")){
            fpLocal = pFileGral; 
         }else if(strcmp(regAge.tipo_saldo, "CNR")){
            fpLocal = pFileCNR;
         }else if(strcmp(regAge.tipo_saldo, "FAC")){
            fpLocal = pFileGral;
         }else{
            printf("Tipo de saldo [%s] desconocido para cliente %ld del ageing.\n", regAge.tipo_saldo, regCli.numero_cliente);
            return;
         }
         GenerarKO(fpLocal, regCli, inx2);
         
         /*************************/

         BORRA_STR(&regOP);
         CopiaClienteAgeToOp(regCli, regAge, &regOP);
         GenerarOP(fpLocal, regOP, inx1, "D", inx2);
         CargaOPL(regCli, inx1, &(regOPL), "M", regAge.fecha_vencimiento1);
         inx1++;

         strcpy(sTipoAnterior, regAge.tipo_saldo);
         iCorrelAnterior = regAge.corr_facturacion;
         dSuma = regAge.valor_cargo;
          
      }
      
      iTeracion++;
   }

   if(iTeracion > 0){
      /* El Ultimo es el Saldo General */
      /* Le hago el saldos Impuestos */
/*      
      $OPEN curImpuestos USING :regCli.numero_cliente;
      
      while(LeoImpuestos(&regImpu, regCli.numero_cliente)){
         BORRA_STR(&regOP);
         CopiaImpuToOp(regCli, regImpu, &regOP);
         GenerarOP(fpLocal, regOP, inx1, "C");
         
         CargaOPL(regCli, inx1, &(regOPL), "M");
         inx1++;
         
         dSuma+=regImpu.saldo;
         
      }
      $CLOSE curImpuestos;
*/   
   
   	if(risnull(CDOUBLETYPE, (char *) &dSuma)){
         dSuma=0;
      }
      if(dSuma != 0.00){
         dSuma=dSuma *-1;
      }

      BORRA_STR(&regOPK);
      CopiaClienteToOpk(regCli, dSuma, &regOPK);
      GenerarOPK(fpLocal, regOPK, inx2, "D");

      if(iCantOPL>0){
         GenerarOPL(fpLocal, regCli, regOPL, "A", inx2);
         inicializaOPL(&(regOPL));
      }            
      
      GeneraENDE(fpLocal, regCli, inx2);
      
      inx2++; 
      
   }else{
      dSuma=0;
   }
   $CLOSE curAgeing;
}


short LeoAgeing(reg)
$ClsAgeing   *reg;
{

   InicializaAgeing(reg);

   $FETCH curAgeing INTO
      :reg->tipo_saldo,
      :reg->corr_facturacion,
      :reg->fecha_vencimiento1,
      :reg->cod_cargo,
      :reg->valor_cargo,
      :reg->hvorg,
      :reg->hkont,
      :reg->tvorg,
      :reg->optxt;
   
   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error al leer el ageing\n");
      }
      return 0;
   }
   
   return 1;
}

void InicializaAgeing(reg)
ClsAgeing   *reg;
{

   memset(reg->tipo_saldo, '\0', sizeof(reg->tipo_saldo));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_vencimiento1));
   memset(reg->cod_cargo, '\0', sizeof(reg->cod_cargo));
   rsetnull(CDOUBLETYPE, (char *) &(reg->valor_cargo));
   memset(reg->hvorg, '\0', sizeof(reg->hvorg));
   memset(reg->hkont, '\0', sizeof(reg->hkont));
   memset(reg->tvorg, '\0', sizeof(reg->tvorg));
   memset(reg->optxt, '\0', sizeof(reg->optxt));

}

void CopiaClienteAgeToOp(regClie, regAge, regOp)
ClsCliente  regClie;
ClsAgeing   regAge;
ClsOP       *regOp;
{
   char  sFechaVenc[9];
   double dValor=0;
      
   memset(sFechaVenc, '\0', sizeof(sFechaVenc));
   
   InicializaOP(regOp);
   
   sprintf(regOp->nroCliente, "%ld", regClie.numero_cliente);
   /* BUKRS */
   strcpy(regOp->BUKRS, "EDES");
   
   /* GSBER */
   strcpy(regOp->GSBER, regClie.sucur_sap);
   
   /* GPART */
   sprintf(regOp->GPART, "%ld", regClie.numero_cliente);
   
   /* VTREF (vacio) */
   /* VKONT */
   sprintf(regOp->VKONT, "%ld", regClie.numero_cliente);
   
   /* HVORG */
   strcpy(regOp->HVORG, regAge.hvorg);
   
   /* TVORG */
   strcpy(regOp->TVORG, regAge.tvorg);
   
   /* KOFIZ */
   strcpy(regOp->KOFIZ, regClie.cdc);
   
   /* SPART (vacio) */
   /* HKONT  */
   strcpy(regOp->HKONT, regAge.hkont);
   
   /* MWSKZ  (vacio) */
   /* XANZA (vacio) */
   /* STAKZ (vacio) */
   
   /* BUDAT */
   strcpy(regOp->BUDAT, FechaGeneracion); 
   
   /* OPTXT */
   strcpy(regOp->OPTXT, regAge.optxt);
   
   /* FAEDN (Fecha Vencimiento) */
   if(strcmp(regAge.tipo_saldo, "SCL")!=0){
      if(regAge.fecha_vencimiento1 >0){
         rfmtdate(regAge.fecha_vencimiento1, "yyyymmdd", regOp->FAEDN); /* long to char */
      }else{
         strcpy(regOp->FAEDN, "");
      }
   }
   
   /* BETRW */
   sprintf(regOp->BETRW, "%.02lf", regAge.valor_cargo);
   
   /* SBETW (vacio) */
   /* AUGRS (vacio) */
   /* SPERZ (?) */
   /* BLART */
   
   strcpy(regOp->BLART, "MG");
   
   /* FINRE (vacio) */
   /* PSWBT */
   sprintf(regOp->PSWBT, "%.02lf", regAge.valor_cargo);
   
   /* SEGMENT (vacio) */


}

void ProcesaConvenios(regClie, sTipo)
$ClsCliente regClie;
char  sTipo[2];
{
$ClsConve   regConve;
$ClsImpuesto   regImpu;
double      dMonto;
ClsOP       regOP;
ClsOPK      regOPK;
int         iExisteConve=0;
int         iPrimaVolta=0;
int   inx1, inx2;

   inx1=1; inx2=1;
   dMonto=0;
   
   $EXECUTE selConvenio INTO :regConve.saldo_actual,
            :regConve.saldo_int_acum,
            :regConve.saldo_imp_no_suj_i,
            :regConve.saldo_imp_suj_int
         USING :regClie.numero_cliente; 

   /*$OPEN curConvenio USING :regClie.numero_cliente;*/
   
   if(SQLCODE == 0){
      GenerarKO(pFileConve, regClie, 1);
      dMonto += regConve.saldo_actual + regConve.saldo_int_acum;
      
      BORRA_STR(&regOP);
      
      CopiaClienteToOp(regClie, &regOP);
   
      memset(regOP.HKONT, '\0', sizeof(regOP.HKONT));

      if(regConve.saldo_actual != 0.00){
         if(regConve.saldo_actual>0){
            strcpy(regOP.TVORG, "0001");
         }else{
            strcpy(regOP.TVORG, "1001");
         }
         strcpy(regOP.OPTXT, "MIG - Saldo Actual");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_actual);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileConve, regOP, inx1, sTipo, 1);
         inx1++;
      }
      
      if(regConve.saldo_int_acum != 0.00){
         if(regConve.saldo_int_acum>0){
            strcpy(regOP.TVORG, "0002");
         }else{
            strcpy(regOP.TVORG, "1002");
         }
         strcpy(regOP.OPTXT, "MIG - Intereses Acumulados");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_int_acum);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileConve, regOP, inx1, sTipo, 1);
         inx1++;
      }

      /* Los impuestos de convenios  */
      $OPEN curImpuConve USING :regClie.numero_cliente;
      
      while(LeoImpuConve(&regImpu)){
         BORRA_STR(&regOP);
         CopiaImpuToOp(regClie, regImpu, &regOP);
         GenerarOP(pFileConve, regOP, inx1, sTipo, 1);
         inx1++;
         dMonto+=regImpu.saldo;
      }
       
      $CLOSE curImpuConve;

      dMonto=dMonto * -1;
      
      BORRA_STR(&regOPK);
      CopiaClienteToOpk(regClie, dMonto, &regOPK);
      GenerarOPK(pFileConve, regOPK, inx2, sTipo);
     
      GeneraENDE(pFileConve, regClie, 1);
      inx2++;
            
   }
/*   
   while(LeoConvenio(&regConve)){
         if(iPrimaVolta==0){
            GenerarKO(pFileConve, regClie);
            iPrimaVolta=1;
         }
         dMonto += regConve.saldo_actual + regConve.saldo_int_acum + regConve.saldo_imp_no_suj_i + regConve.saldo_imp_suj_int;
                 
         BORRA_STR(&regOP);
         
         CopiaClienteToOp(regClie, &regOP);
      
         memset(regOP.HKONT, '\0', sizeof(regOP.HKONT));

         if(regConve.saldo_actual>=0){
            strcpy(regOP.TVORG, "0001");
         }else{
            strcpy(regOP.TVORG, "1001");
         }
         strcpy(regOP.OPTXT, "MIG - Saldo Actual");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_actual);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileConve, regOP, inx1, sTipo);
         inx1++;

         if(regConve.saldo_int_acum>=0){
            strcpy(regOP.TVORG, "0002");
         }else{
            strcpy(regOP.TVORG, "1002");
         }
         strcpy(regOP.OPTXT, "MIG - Intereses Acumulados");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_int_acum);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileConve, regOP, inx1, sTipo);
         inx1++;

// esto no va mas ----------------
         if(regConve.saldo_imp_suj_int>=0){
            strcpy(regOP.TVORG, "998");
         }else{
            strcpy(regOP.TVORG, "1998");
         }
         strcpy(regOP.OPTXT, "Saldo Impuestos Sujeto a Intereses");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_imp_suj_int);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(regOP, inx1);
         CargaOPL(regClie, inx1, &(regOPL));
         inx1++;

         if(regConve.saldo_imp_no_suj_i>=0){
            strcpy(regOP.TVORG, "999");
         }else{
            strcpy(regOP.TVORG, "1999");
         }
         strcpy(regOP.OPTXT, "Saldo Impuestos No Sujeto a Intereses");
         sprintf(regOP.BETRW, "%.02lf", regConve.saldo_imp_no_suj_i);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(regOP, inx1);
         CargaOPL(regClie, inx1, &(regOPL));
         inx1++;
//   hasta aqui no va mas --------------
      
         iExisteConve++;
   }
   
   $CLOSE curConvenio;
   
   if(iPrimaVolta == 1){
   	if(risnull(CDOUBLETYPE, (char *) &dMonto)){
         dMonto=0;
      }
      dMonto=dMonto * -1;
      
      BORRA_STR(&regOPK);
      CopiaClienteToOpk(regClie, dMonto, &regOPK);
      GenerarOPK(pFileConve, regOPK, inx2, sTipo);
     
      GeneraENDE(pFileConve, regClie);
      inx2++;
   }
*/      
}

short LeoConvenio(reg)
$ClsConve   *reg;
{

   InicializaConvenio(reg);

   $FETCH curConvenio INTO
         :reg->saldo_actual,
         :reg->saldo_int_acum,
         :reg->saldo_imp_no_suj_i,
         :reg->saldo_imp_suj_int;

   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error al buscar CONVENIOS\n");
      }
      return 0;
   }         

   return 1;
}

void InicializaConvenio(reg)
$ClsConve   *reg;
{
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_actual));
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_int_acum));
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_imp_no_suj_i));
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_imp_suj_int));
}

void ProcesaDisputa(regCli, sTipo)
$ClsCliente regCli;
char  sTipo[2];
{
   $ClsDisputa    regDispu;
   $ClsImpuesto   regImpu;
   double         dMonto;
   ClsOP          regOP;
   ClsOPK         regOPK;
   int            iExisteDispu=0;
   int            iPrimaVolta=0;
   int   inx1, inx2;

   iCantOPL=0;
   inx1=1; inx2=1;
   
   $OPEN curDisputa USING :regCli.numero_cliente;   

   while(LeoDisputa(&regDispu)){
      if(iPrimaVolta==0){
         GenerarKO(pFileDispu, regCli, 1);
         iPrimaVolta=1;
      }
      
      dMonto=0;
      /*dMonto = regDispu.saldo_actual + regDispu.saldo_int_acum + regDispu.saldo_imp_no_suj_i + regDispu.saldo_imp_suj_int;*/
      dMonto = regDispu.saldo_actual + regDispu.saldo_int_acum;
              
      BORRA_STR(&regOP);
      
      CopiaClienteToOp(regCli, &regOP);
   
      memset(regOP.HKONT, '\0', sizeof(regOP.HKONT));
      
      if(regDispu.saldo_actual != 0.00){
         if(regDispu.saldo_actual >0){
            strcpy(regOP.TVORG, "0001");
         }else{
            strcpy(regOP.TVORG, "1001");
         }
         strcpy(regOP.OPTXT, "MIG - Saldo Actual");
         sprintf(regOP.BETRW, "%.02lf", regDispu.saldo_actual);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileDispu, regOP, inx1, sTipo, 1);
         CargaOPL(regCli, inx1, &(regOPL), "D", 0);
         inx1++;
      }
      
      if(regDispu.saldo_int_acum != 0.00){
         if(regDispu.saldo_int_acum >0){
            strcpy(regOP.TVORG, "0002");
         }else{
            strcpy(regOP.TVORG, "1002");
         }
         strcpy(regOP.TVORG, "0002");
         strcpy(regOP.OPTXT, "MIG - Intereses Acumulados");
         sprintf(regOP.BETRW, "%.02lf", regDispu.saldo_int_acum);
         strcpy(regOP.PSWBT, regOP.BETRW);
         GenerarOP(pFileDispu, regOP, inx1, sTipo, 1);
         CargaOPL(regCli, inx1, &(regOPL), "D", 0);
         inx1++;
      }
/*
      if(regDispu.saldo_imp_suj_int >=0){
         strcpy(regOP.TVORG, "998");
      }else{
         strcpy(regOP.TVORG, "1998");
      }
      strcpy(regOP.OPTXT, "Saldo Impuestos Sujeto a Intereses");
      sprintf(regOP.BETRW, "%.02lf", regDispu.saldo_imp_suj_int);
      strcpy(regOP.PSWBT, regOP.BETRW);
      GenerarOP(regOP, inx1);
      CargaOPL(regCli, inx1, &(regOPL));
      inx1++;

      if(regDispu.saldo_imp_no_suj_i >=0){
         strcpy(regOP.TVORG, "999");
      }else{
         strcpy(regOP.TVORG, "1999");
      }
      strcpy(regOP.OPTXT, "Saldo Impuestos No Sujeto a Intereses");
      sprintf(regOP.BETRW, "%.02lf", regDispu.saldo_imp_no_suj_i);
      strcpy(regOP.PSWBT, regOP.BETRW);
      GenerarOP(regOP, inx1);
      CargaOPL(regCli, inx1, &(regOPL));
      inx1++;
*/
      /* Hago los saldos impuestos de esto */
      $OPEN curImpDispu USING :regCli.numero_cliente, :regDispu.nro_saldo_disputa;
      
      while(LeoImpuDispu(&regImpu)){
         BORRA_STR(&regOP);
         CopiaImpuToOp(regCli, regImpu, &regOP);
         GenerarOP(pFileDispu, regOP, inx1, sTipo, 1);
         CargaOPL(regCli, inx1, &(regOPL), "D", 0);
         inx1++;
         dMonto+=regImpu.saldo;
      }
      $CLOSE curImpDispu;
   }

   if(iPrimaVolta==1){
      if(dMonto != 0.00){
         dMonto=dMonto * -1;
      }
   	if(risnull(CDOUBLETYPE, (char *) &dMonto)){
         dMonto=0;
      }

      BORRA_STR(&regOPK);
      CopiaClienteToOpk(regCli, dMonto, &regOPK);
      GenerarOPK(pFileDispu, regOPK, inx2, sTipo);
      inx2++;
   
      if(iCantOPL>0){
         GenerarOPL(pFileDispu, regCli, regOPL, "D", 1);
      }            
      iCantOPL=0;
      GeneraENDE(pFileDispu, regCli, 1);
      iExisteDispu++;
   
   }
}

short LeoDisputa(reg)
$ClsDisputa *reg;
{

   InicializaDisputa(reg);
   
   $FETCH curDisputa INTO
      :reg->nro_saldo_disputa, 
      :reg->ndocum_enre, 
      :reg->reclamo, 
      :reg->monto_disputa, 
      :reg->saldo_actual, 
      :reg->saldo_int_acum, 
      :reg->saldo_imp_no_suj_i, 
      :reg->saldo_imp_suj_int, 
      :reg->fecha_autoriza;
      
   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error al buscar DISPUTAS\n");      
      }
      return 0;
   }

   return 1;
}

void  InicializaDisputa(reg)
$ClsDisputa *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->nro_saldo_disputa)); 
   memset(reg->ndocum_enre, '\0', sizeof(reg->ndocum_enre)); 
   rsetnull(CLONGTYPE, (char *) &(reg->reclamo)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->monto_disputa)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_actual)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_int_acum)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_imp_no_suj_i)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_imp_suj_int)); 
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_autoriza));
}

short LeoImpuDispu(reg)
$ClsImpuesto   *reg;
{
   InicializaImpuesto(reg);
   
   $FETCH curImpDispu INTO
      :reg->codigo_impuesto, 
      :reg->descripcion, 
      :reg->saldo, 
      :reg->ind_afecto_int,
      :reg->hvorg, 
      :reg->hkont, 
      :reg->tvorg, 
      :reg->optxt;
    
   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error leyendo SD_SALDOS_IMP.\n");
      }
      return 0;
   }

   alltrim(reg->descripcion, ' ');
   alltrim(reg->optxt, ' ');
   
   return 1;
}

short LeoImpuConve(reg)
$ClsImpuesto   *reg;
{
   InicializaImpuesto(reg);
   
   $FETCH curImpuConve INTO
      :reg->codigo_impuesto, 
      :reg->descripcion, 
      :reg->saldo, 
      :reg->ind_afecto_int,
      :reg->hvorg, 
      :reg->hkont, 
      :reg->tvorg, 
      :reg->optxt;
    
   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("Error leyendo DETALLE_IMP_CONVE.\n");
      }
      return 0;
   }

   alltrim(reg->descripcion, ' ');
   alltrim(reg->optxt, ' ');
   
   return 1;
}


void inicializaOPL(regOPL)
ClsOPL   **regOPL;
{
ClsOPL	*regAux=NULL;
ClsOPL	reg;
	
	if(*regOPL != NULL)
		free(*regOPL);
		
	*regOPL = (ClsOPL *) malloc (sizeof(ClsOPL));
	if(*regOPL == NULL){
		printf("Fallo Malloc inicializaOPL().\n");
	}

   iCantOPL=0;
}

void  CargaOPL(regCli, index, regOpl, sTipo, lFechaVto)
ClsCliente  regCli;
long        index;
ClsOPL      **regOpl;
char        sTipo[2];
long        lFechaVto;
{
$ClsOPL	*regAux=NULL;
$ClsOPL	reg;
int      indice=index-1;
long     lFechaUltimaFactura;
char     sFechaVto[11];

/*
   if(regCli.tiene_cobro_int[0]=='N'){
*/
      memset(sFechaVto, '\0', sizeof(sFechaVto));
      
      if(lFechaVto>0){
         rdefmtdate(&lFechaUltimaFactura, "yyyymmdd", regCli.sFechaUltFactura); /*char a long*/
         if(lFechaVto > lFechaUltimaFactura){
            rfmtdate(lFechaVto, "yyyymmdd", sFechaVto); /* long to char */
         }else{
            strcpy(sFechaVto, regCli.sFechaUltFactura);
         }
      }else{
         strcpy(sFechaVto, regCli.sFechaUltFactura); 
      }   
      /* El de Intereses */
		regAux = (ClsOPL*) realloc(*regOpl, sizeof(ClsOPL) * (++indice) );
		if(regAux == NULL){
			printf("Fallo Realloc CargaOPL().\n");
		}		
		
		(*regOpl) = regAux;
		
		sprintf((*regOpl)[indice-1].OPUPK, "%04ld", index);
		strcpy((*regOpl)[indice-1].PROID, "04");
		strcpy((*regOpl)[indice-1].LOCKR, sTipo);
		strcpy((*regOpl)[indice-1].FDATE, regCli.sFechaVigTarifa);
		strcpy((*regOpl)[indice-1].TDATE, sFechaVto);
         
      iCantOPL++;
/*      
   }
*/   
}

void InicializaOP(reg)
ClsOP *reg;
{
   memset(reg->nroCliente, '\0', sizeof(reg->nroCliente));
   memset(reg->BUKRS, '\0', sizeof(reg->BUKRS));
   memset(reg->GSBER, '\0', sizeof(reg->GSBER));
   memset(reg->GPART, '\0', sizeof(reg->GPART));
   memset(reg->VTREF, '\0', sizeof(reg->VTREF));
   memset(reg->VKONT, '\0', sizeof(reg->VKONT));
   memset(reg->HVORG, '\0', sizeof(reg->HVORG));
   memset(reg->TVORG, '\0', sizeof(reg->TVORG));
   memset(reg->KOFIZ, '\0', sizeof(reg->KOFIZ));
   memset(reg->SPART, '\0', sizeof(reg->SPART));
   memset(reg->HKONT, '\0', sizeof(reg->HKONT));
   memset(reg->MWSKZ, '\0', sizeof(reg->MWSKZ));
   memset(reg->XANZA, '\0', sizeof(reg->XANZA));
   memset(reg->STAKZ, '\0', sizeof(reg->STAKZ));
   memset(reg->BUDAT, '\0', sizeof(reg->BUDAT));
   memset(reg->OPTXT, '\0', sizeof(reg->OPTXT));
   memset(reg->FAEDN, '\0', sizeof(reg->FAEDN));
   memset(reg->BETRW, '\0', sizeof(reg->BETRW));
   memset(reg->SBETW, '\0', sizeof(reg->SBETW));
   memset(reg->AUGRS, '\0', sizeof(reg->AUGRS));
   memset(reg->SPERZ, '\0', sizeof(reg->SPERZ));
   memset(reg->BLART, '\0', sizeof(reg->BLART));
   memset(reg->FINRE, '\0', sizeof(reg->FINRE));
   memset(reg->PSWBT, '\0', sizeof(reg->PSWBT));
   memset(reg->SEGMENT, '\0', sizeof(reg->SEGMENT));
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

