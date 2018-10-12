/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_doc_calculo
    
	Fecha : 16/05/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura DOCUMENTOS DE CALCULO
		
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

$include "sap_doc_calculo.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileUnx;

char	sArchDocuCalcuUnx[100];
char	sArchDocuCalcuDos[100];
char	sSoloArchivoDocuCalcu[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;
$long lFechaHoy;

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
int      iNx;
$ClsCliente regCliente;
$ClsHisfac  regFactuCabe;
$ClsDetalle regFactuDeta;
int       iFlagRefacturada;
$ClsCtaAgrupa  *regCtas=NULL;
int            iCantCtas;

int      iIndexFile;
long     lCliFile;
int      iNumFactuClie;
long     iTopeFile=300000;

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
		
	$EXECUTE selCorrelativos into :iCorrelativos;
*/
   $EXECUTE selFechaRti INTO :lFechaRti;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha RTI\n");
      exit(2);
   }
   	
   $EXECUTE selFechaHoy INTO :lFechaHoy;

   if(SQLCODE != 0){
      printf("No se logró recuperar fecha de hoy\n");
      exit(2);
   }
         
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */

	cantProcesada=0;
	cantPreexistente=0;
   iCantCtas=0;
   
   if(!CargarCtas(&(regCtas), &iCantCtas)){
      printf("Aborto Proceso por no poder cargar las cuentas y agrupaciones\n");
      exit(2);
   }

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(sSucursal, '\0', sizeof(sSucursal));
   iIndexFile=1;
   lCliFile=1;
   
/*
	for(i=0; i<12; i++){
		strcpy(sSucursal, vSucursal[i]);
*/      

		if(!AbreArchivos(sSucursal, iIndexFile)){
			exit(1);	
		}
		
		if(glNroCliente > 0){
			$OPEN curClientes using :glNroCliente;
		}else{
			$OPEN curClientes;
		}
		
		printf("Procesando ......\n");
      
      while(LeoCliente(&regCliente)){
         
         if(!ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra)){
               /*
             if(! CorporativoT23(&regCliente)){
               if(! CorporativoPropio(&regCliente)){
                  sprintf(regCliente.cod_agrupa, "T1%ld", regCliente.numero_cliente);                      
               }                                     
             }
               */
               sprintf(regCliente.cod_agrupa, "T1%ld", regCliente.numero_cliente);
                              
             if(regCliente.corr_facturacion > 0){
                $OPEN curHisfac USING :regCliente.numero_cliente, :lFechaRti;
                iNumFactuClie=1;
                while(LeoFacturasCabe(&regFactuCabe, iNumFactuClie)){
                   Calculos(&regFactuCabe);
                
                   /* Generacion de plano cabecera */
                   GenerarCabecera(regCliente, regFactuCabe);
                   
                   if(regFactuCabe.indica_refact[0]=='S'){
                      $OPEN curCarfacAux USING :regFactuCabe.numero_cliente, :regFactuCabe.corr_facturacion, :regFactuCabe.consumo_sum;
                      iFlagRefacturada=1;            
                   }else{
                      $OPEN curCarfac USING :regFactuCabe.numero_cliente, :regFactuCabe.corr_facturacion, :regFactuCabe.consumo_sum;
                      iFlagRefacturada=0;
                   }
                   iNx=1;    
                   while(LeoFacturasDeta(regFactuCabe, &regFactuDeta, iFlagRefacturada)){
                      /* Generacion de plano Detalle  */
                     if(BuscaCuenta(regCliente, regFactuCabe, regCtas, iCantCtas, &regFactuDeta)){
                        GenerarDetalle(regCliente, regFactuCabe, regFactuDeta, iNx);
                     }                
                   }
                   GeneraENDE(regFactuCabe, regFactuDeta, iNx);
                   
                   iNx++;
                   if(regFactuCabe.indica_refact[0]=='S'){
                      $CLOSE curCarfacAux;            
                   }else{
                      $CLOSE curCarfac;
                   }
                   iNumFactuClie++;
                } /* Facturas Cabe */
                
                $CLOSE curHisfac;
                lCliFile++;
             }
/*
             $BEGIN WORK;
             
             if(!RegistraCliente(regCliente.numero_cliente,iFlagMigra)){
                 $ROLLBACK WORK;
                 exit(2);
             }
             
             $COMMIT WORK;
*/            
   
             if(iCliFile > iTopeFile){
               CerrarArchivos();
               FormateaArchivos(iIndexFile);
               iIndexFile++;
         		if(!AbreArchivos(sSucursal, iIndexFile)){
         			exit(1);	
         		}
               
               iCliFile=1
             }          
             cantProcesada++;
         }else{
             cantPreexistente++;
         }         
         
      } /* Clientes */
   
      $CLOSE curClientes;

      CerrarArchivos();
/*      
   }  // Sucursales 
*/
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

	FormateaArchivos(iIndexFile);

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
	printf("Documentos de Calculo\n");
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

short AbreArchivos(sSucur, indFile)
char  sSucur[5];
int   indFile
{
	
	memset(sArchDocuCalcuUnx,'\0',sizeof(sArchDocuCalcuUnx));
	memset(sSoloArchivoDocuCalcu,'\0',sizeof(sSoloArchivoDocuCalcu));

   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchDocuCalcuUnx  , "%sT1BILLDOC_%d.unx", sPathSalida, indFile );
	sprintf( sSoloArchivoDocuCalcu, "T1BILLDOC_%d.unx", indFile);

	pFileUnx=fopen( sArchDocuCalcuUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchDocuCalcuUnx );
		return 0;
	}
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileUnx);
}

void FormateaArchivos(indFile)
int   indFile
{
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];


	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	if(giEstadoCliente==0){
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/BillDoc/", sPathCopia);
	}else{
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}
	

	sprintf(sCommand, "chmod 755 %s", sArchDocuCalcuUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDocuCalcuUnx, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchDocuCalcuUnx);
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

	/******** Fecha Hoy  ****************/
	strcpy(sql, "SELECT TODAY FROM dual ");
	
	$PREPARE selFechaHoy FROM $sql;	

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
   strcat(sql, "NVL(c.corr_facturacion, 0), ");
   strcat(sql, "'0000T1' || LPAD(c.sector, 2, 0) porcion, "); 
   strcat(sql, "TRIM(sc.cod_ul_sap) || LPAD(c.sector, 2, 0) || LPAD(c.zona, 5, 0) ul, ");
   strcat(sql, "TRIM(t1.acronimo_sap) cdc, ");
   strcat(sql, "c.tipo_fpago, ");
   strcat(sql, "c.minist_repart, ");
   strcat(sql, "c.tipo_cliente "); 
   strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER sap_transforma t1 ");

   if(giTipoCorrida==1)	
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
	/*strcat(sql, "AND c.sucursal = ? ");*/
	strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND c.sector != 88 ");
   strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
   strcat(sql, "AND t1.clave = 'TIPCLI' ");
   strcat(sql, "AND t1.cod_mac = c.tipo_cliente ");

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
		
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	

   if(giTipoCorrida==1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;
   
	/******** Cursor HISFAC  ****************/
	strcpy(sql, "SELECT hf.numero_cliente, ");
   strcat(sql, "hf.corr_facturacion, ");
   strcat(sql, "TO_CHAR(hf.fecha_lectura, '%Y%m%d'), ");
   strcat(sql, "TO_CHAR(hf.fecha_vencimiento1, '%Y%m%d'), ");
   strcat(sql, "TO_CHAR(hf.fecha_facturacion, '%Y%m%d'), ");
   strcat(sql, "hf.fecha_facturacion, ");
   strcat(sql, "hf.centro_emisor, ");
   strcat(sql, "hf.tipo_docto, ");
   strcat(sql, "hf.numero_factura, ");
   strcat(sql, "TRIM(t2.acronimo_sap) tarifa, ");
   strcat(sql, "TRIM(t3.cod_sap) tipo_iva, ");
   strcat(sql, "hf.consumo_sum, ");
   strcat(sql, "hf.tarifa, ");
   strcat(sql, "hf.subtarifa, ");
   strcat(sql, "hf.indica_refact, ");
   strcat(sql, "hf.corr_facturacion, ");
   strcat(sql, "hf.clase_servicio, ");
   strcat(sql, "TRIM(t4.acronimo_sap) cdc, ");
   
   strcat(sql, "hf.fecha_lectura, ");
   strcat(sql, "TRIM(sc.cod_ul_sap || lpad(hf.sector , 2, 0) ||  lpad(hf.zona,5,0)) unidad_lectura, "); 
   strcat(sql, "'000T1'|| lpad(hf.sector,2,0) || sc.cod_ul_sap porcion, ");
   strcat(sql, "hl.tipo_lectura ");
      
   strcat(sql, "FROM hislec hl, hisfac hf, sucur_centro_op sc ");
   strcat(sql, ", OUTER sap_transforma t2 ");
   strcat(sql, ", OUTER sap_transforma t3 ");
   strcat(sql, ", OUTER sap_transforma t4 ");   
   strcat(sql, "WHERE hl.numero_cliente = ? ");
   strcat(sql, "AND hl.fecha_lectura > ? ");
   strcat(sql, "AND hl.tipo_lectura NOT IN (5, 6) ");
   strcat(sql, "AND hf.numero_cliente = hl.numero_cliente ");
   strcat(sql, "AND hf.corr_facturacion = hl.corr_facturacion ");
   
   strcat(sql, "AND sc.cod_centro_op = hf.sucursal ");
   
   strcat(sql, "AND t2.clave = 'TARIFTYP' ");
   strcat(sql, "AND t2.cod_mac = hf.tarifa ");
   strcat(sql, "AND t3.clave = 'TIPIVA' ");
   strcat(sql, "AND t3.cod_mac = hf.tipo_iva ");
   strcat(sql, "AND t4.clave = 'TIPCLI' ");
   strcat(sql, "AND t4.cod_mac = hf.clase_servicio ");
   
   strcat(sql, "ORDER BY 1, 2 ASC ");
	
	$PREPARE selHisfac FROM $sql;
	
	$DECLARE curHisfac CURSOR WITH HOLD FOR selHisfac;	

   /********** Fecha Lectura Anterior **********/
	strcpy(sql, "SELECT TO_CHAR(MAX(fecha_lectura) + 1, '%Y%m%d') "); 
	strcat(sql, "FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? "); 
	strcat(sql, "AND corr_facturacion = ? ");
	strcat(sql, "AND tipo_lectura IN (1,2,3,4,7,8) ");
   
   $PREPARE selLecturaAnt FROM $sql;

   /************* Factura Ajustada ***************/
	strcpy(sql, "SELECT TRIM(t1.cod_sap), ");
	strcat(sql, "TRIM(t2.acronimo_sap), ");
	strcat(sql, "r.kwh, ");
   strcat(sql, "r.corr_refacturacion, ");
   strcat(sql, "r.clase_servicio, ");
   strcat(sql, "TRIM(t3.acronimo_sap) cdc ");   
	strcat(sql, "FROM refac r, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3 ");
	strcat(sql, "WHERE r.numero_cliente = ? ");
	strcat(sql, "AND r.fecha_fact_afect = ? ");
	strcat(sql, "AND r.nro_docto_afect = ? ");
	strcat(sql, "AND r.corr_refacturacion = (SELECT MAX(r2.corr_refacturacion) ");
	strcat(sql, "	FROM refac r2 ");
	strcat(sql, "	WHERE r2.numero_cliente = r.numero_cliente ");
	strcat(sql, "	AND r2.fecha_fact_afect = r.fecha_fact_afect ");
	strcat(sql, "	AND r2.nro_docto_afect = r.nro_docto_afect) ");
	strcat(sql, "AND t1.clave = 'TIPIVA' ");
	strcat(sql, "AND t1.cod_mac = r.resp_iva ");
	strcat(sql, "AND t2.clave = 'TARIFTYP' ");
	strcat(sql, "AND t2.cod_mac = r.tarifa ");
   strcat(sql, "AND t4.clave = 'TIPCLI' ");
   strcat(sql, "AND t4.cod_mac = hf.clase_servicio ");
   
   $PREPARE selRefac FROM $sql;

   /************* Detalle Carfac ***************/
/*   
	strcpy(sql, "SELECT ca.codigo_cargo, ");
   strcat(sql, "ca.valor_cargo, ");
	strcat(sql, "co.unidad, "); 
	strcat(sql, "t.clase_pos_doc, ");
	strcat(sql, "t.contrapartida, ");
	strcat(sql, "t.cte_de_calculo, ");
	strcat(sql, "t.tipo_precio, ");
	strcat(sql, "t.tarifa, ");
	strcat(sql, "t.deriv_contable, ");
   strcat(sql, "t.tipo_cargo_tarifa ");
	strcat(sql, "FROM carfac ca, codca co, sap_trafo_cargos t ");
	strcat(sql, "WHERE ca.numero_cliente = ? ");
	strcat(sql, "AND ca.corr_facturacion = ? ");
strcat(sql, "AND ca.codigo_cargo = '020' ");   
	strcat(sql, "AND co.codigo_cargo = ca.codigo_cargo ");
	strcat(sql, "AND t.cod_cargo_mac = ca.codigo_cargo ");
	strcat(sql, "ORDER BY 1 ASC ");

   $PREPARE selCarfac FROM $sql;
*/

   $PREPARE selCarfac FROM "SELECT ca.codigo_cargo,
      ca.valor_cargo,
      co.unidad,
      TRIM(t.descripcion),
      t.vonzone,
      t.biszone,
      TRIM(t.tariftyp),
      TRIM(t.tarifnr),
      TRIM(t.belzart),
      t.preistyp,
      TRIM(t.massbill),
      TRIM(t.preis),
      t.zonennr,
      TRIM(t.ein01),
      TRIM(t.tvorg),
      TRIM(t.gegen_tvorg),
      TRIM(t.sno)
      FROM carfac ca, codca co, sap_trafo_billdoc t 
      WHERE ca.numero_cliente = ? 
      AND ca.corr_facturacion = ? 
      AND ca.codigo_cargo = '020' 
      AND co.codigo_cargo = ca.codigo_cargo 
      AND t.cod_cargo_mac = ca.codigo_cargo 
      AND ? BETWEEN t.vonzone AND t.biszone
      ORDER BY 1 ASC";
   
   $DECLARE curCarfac CURSOR FOR selCarfac; 

   /************* Detalle Carfac Aux ***************/
/*   
	strcpy(sql, "SELECT ca.codigo_cargo, ");
   strcat(sql, "ca.valor_cargo, ");
	strcat(sql, "co.unidad, "); 
	strcat(sql, "t.clase_pos_doc, ");
	strcat(sql, "t.contrapartida, ");
	strcat(sql, "t.cte_de_calculo, ");
	strcat(sql, "t.tipo_precio, ");
	strcat(sql, "t.tarifa, ");
	strcat(sql, "t.deriv_contable, ");
   strcat(sql, "t.tipo_cargo_tarifa ");
	strcat(sql, "FROM carfac_aux ca, codca co, sap_trafo_cargos t ");
	strcat(sql, "WHERE ca.numero_cliente = ? ");
	strcat(sql, "AND ca.corr_facturacion = ? ");
strcat(sql, "AND ca.codigo_cargo = '020' ");   
	strcat(sql, "AND co.codigo_cargo = ca.codigo_cargo ");
	strcat(sql, "AND t.cod_cargo_mac = ca.codigo_cargo ");
	strcat(sql, "ORDER BY 1 ASC ");

   $PREPARE selCarfacAux FROM $sql;
*/

   $PREPARE selCarfacAux FROM "SELECT ca.codigo_cargo,
      ca.valor_cargo,
      co.unidad,
      TRIM(t.descripcion),
      t.vonzone,
      t.biszone,
      TRIM(t.tariftyp),
      TRIM(t.tarifnr),
      TRIM(t.belzart),
      t.preistyp,
      TRIM(t.massbill),
      TRIM(t.preis),
      t.zonennr,
      TRIM(t.ein01),
      TRIM(t.tvorg),
      TRIM(t.gegen_tvorg),
      TRIM(t.sno)
      FROM carfac_aux ca, codca co, sap_trafo_billdoc t 
      WHERE ca.numero_cliente = ? 
      AND ca.corr_facturacion = ? 
      AND ca.codigo_cargo = '020' 
      AND co.codigo_cargo = ca.codigo_cargo 
      AND t.cod_cargo_mac = ca.codigo_cargo 
      AND ? BETWEEN t.vonzone AND t.biszone
      ORDER BY 1 ASC";
      
   $DECLARE curCarfacAux CURSOR FOR selCarfacAux; 

	/********* Select Corporativo T23 **********/
	strcpy(sql, "SELECT NVL(cod_corporativo, '000') FROM mg_corpor_t23 ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selCorpoT23 FROM $sql;

   /********* Detalle Valoriz Cargos *********/
	strcpy(sql, "SELECT MAX(d1.precio_unitario) "); 
	strcat(sql, "FROM det_val_tarifas_hist d1 ");
	strcat(sql, "WHERE d1.numero_cliente = ? ");
	strcat(sql, "AND d1.corr_facturacion = ? ");
	strcat(sql, "AND d1.tipo_cargo_tarifa = ? ");
	strcat(sql, "AND d1.duracion_periodo = (SELECT MAX(d2.duracion_periodo) ");
	strcat(sql, "   FROM det_val_tarifas_hist d2 ");
	strcat(sql, "   WHERE d2.numero_cliente = d1.numero_cliente ");
	strcat(sql, "   AND d2.corr_facturacion = d1.corr_facturacion ");
	strcat(sql, "   AND d2.tipo_cargo_tarifa = d1.tipo_cargo_tarifa) ");
   
   $PREPARE selDetValor FROM $sql;
	
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
	strcat(sql, "'BILLDOC', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT billdoc FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, billdoc ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "billdoc = 'S' ");
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
	
   /*************** Fecha Vig.Tarifa****************/
	strcpy(sql, "SELECT MIN(fecha_lectura) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_lectura > ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 7, 8) ");
   
   $PREPARE selVigTarifa FROM $sql;

   /*************** Cuenta y Agrupa ****************/
	strcpy(sql, "SELECT codigo_cargo, codigo_cuenta, agrupacion, descripcion "); 
	strcat(sql, "FROM sap_conce_ctaagrupa ");
	strcat(sql, "ORDER BY codigo_cargo ");
	
   $PREPARE selCtaAgrupa FROM $sql;
   
   $DECLARE curCtaAgrupa CURSOR FOR selCtaAgrupa;
   
   /******** Detalle Trafo *******/
   $PREPARE selDetaTrafo FROM "SELECT descripcion,
      vonzone,
      biszone,
      tariftyp,
      tarifnr,
      belzart,
      preistip,
      massbill,
      preis,
      zonennr,
      eint01,
      tvorg
      FROM sap_trafo_billdoc
      WHERE cod_cargo_mac = ?
      AND ? BETWEEN vonzone AND biszone ";
      
   /******** Busca Inicio Ventana  (Adatsoll) *********/
   $PREPARE selIniVentana1 FROM "SELECT MIN(inicio_ventana) FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND ? BETWEEN inicio_ventana AND fin_ventana ";
		
   $PREPARE selIniVentana2 FROM "SELECT MAX(inicio_ventana) FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND inicio_ventana <= ? ";

   $PREPARE selIniVentana3 FROM "SELECT MIN(inicio_ventana) FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND inicio_ventana > ? ";
   
      
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
      :regCli->corr_facturacion,
      :regCli->cod_portion,
      :regCli->cod_ul,
      :regCli->cdc,
      :regCli->tipo_fpago,
      :regCli->minist_repart,
      :regCli->tipo_cliente; 

  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

	return 1;	
}

void InicializaCliente(regCli)
$ClsCliente *regCli;
{
	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regCli->corr_facturacion));
	memset(regCli->cod_portion, '\0', sizeof(regCli->cod_portion));
	memset(regCli->cod_ul, '\0', sizeof(regCli->cod_ul));
   memset(regCli->cdc, '\0', sizeof(regCli->cdc));
   memset(regCli->tipo_fpago, '\0', sizeof(regCli->tipo_fpago));
   memset(regCli->cod_agrupa, '\0', sizeof(regCli->cod_agrupa));
   rsetnull(CLONGTYPE, (char *) &(regCli->minist_repart));
   memset(regCli->tipo_cliente, '\0', sizeof(regCli->tipo_cliente));
}

short CorporativoT23(regClie)
$ClsCliente    *regClie;
{

	$EXECUTE selCorpoT23 into :regClie->cod_agrupa 
						using :regClie->numero_cliente;

	if(SQLCODE == SQLNOTFOUND)
		return 0;

	if(SQLCODE != 0){
		printf("ErroR al verificar si el cliente %ld es corporativo T23.\n",regClie->numero_cliente);
		exit(1);
	}

   return 1;
}

short CorporativoPropio(regClie)
ClsCliente  *regClie;
{
   
   if(risnull(CLONGTYPE, (char *) &regClie->minist_repart) || regClie->minist_repart <= 0){
      return 0;
   }

   sprintf(regClie->cod_agrupa, "T1%ld", regClie->minist_repart);
   return 1;
}


short LeoFacturasCabe(regFactu, iFactu)
$ClsHisfac  *regFactu;
int         iFactu;
{
   $long lFechaAux;
   
   InicializaFacturasCabe(regFactu);
   
   $FETCH curHisfac INTO
      :regFactu->numero_cliente,
      :regFactu->corr_facturacion,
      :regFactu->fecha_lectura,
      :regFactu->fecha_vencimiento,
      :regFactu->fecha_facturacion,
      :regFactu->lFechaFacturacion,
      :regFactu->centro_emisor,
      :regFactu->tipo_docto,
      :regFactu->numero_factura,
      :regFactu->tipo_tarifa,
      :regFactu->tipo_iva,
      :regFactu->consumo_sum,
      :regFactu->tarifa,
      :regFactu->subtarifa,
      :regFactu->indica_refact,
      :regFactu->clase_servicio,
      :regFactu->cdc,
      :regFactu->lFechaLectura,
      :regFactu->cod_ul,
      :regFactu->cod_porcion,
      :regFactu->iTipoLectura;
      

   if(SQLCODE != 0){
      return 0;
   }

   /* Busca inicio Ventana */
   lFechaAux = regFactu->lFechaLectura; 
   alltrim(regFactu->cod_ul, ' ');
   alltrim(regFactu->cod_porcion, ' ');
   
   if(iTipoLectura == 8 && iFactu != 1){
      $EXECUTE selIniVentana3 INTO :regFactu->lFechaIniVentana USING
            :regFactu->cod_porcion,
            :regFactu->cod_ul,
            :lFechaAux;
         
      if(SQLCODE != 0 || strcmp(regFactu->lFechaIniVentana,"")==0){
         printf("No se encontró fecha ini ventana para cliente %ld Porcion %s UL %s Fecha Lectura %ld lectura tipo 8\n", regFactu->numero_cliente, regFactu->cod_porcion, regFactu->cod_ul, lFechaAux);
      }      
   
   }else{
      $EXECUTE selIniVentana1 INTO :regFactu->lFechaIniVentana USING
            :regFactu->cod_porcion,
            :regFactu->cod_ul,
            :lFechaAux;
         
      if(SQLCODE != 0 || strcmp(regFactu->lFechaIniVentana,"")==0){
         $EXECUTE selIniVentana2 INTO :regFactu->lFechaIniVentana USING
            :regFactu->cod_porcion,
            :regFactu->cod_ul,
            :lFechaAux;
   
         if(SQLCODE != 0 || strcmp(regFactu->lFechaIniVentana,"")==0){
            printf("No se encontró fecha ini ventana para cliente %ld Porcion %s UL %s Fecha Lectura %ld intento 2\n", regFactu->numero_cliente, regFactu->cod_porcion, regFactu->cod_ul, lFechaAux);
         }      
      }      
   }

   if(!getFechaLectuAnterior(regFactu)){
      printf("Error al buscar lectura anterior para cliente %ld Correlativo %d\n", regFactu->numero_cliente, regFactu->corr_facturacion);
      return 0;
   }
   
   if(regFactu->indica_refact[0]=='S'){
      if(!TraeRefacturada(regFactu)){
         printf("Error al buscar refacturada para cliente %ld Correlativo %d\n", regFactu->numero_cliente, regFactu->corr_facturacion);
         return 0;
      }
   }
  
   alltrim(regFactu->tipo_tarifa, ' ');
   alltrim(regFactu->tipo_iva, ' ');
   alltrim(regFactu->cdc, ' ');
   
   return 1;
}

void InicializaFacturasCabe(regFactu)
$ClsHisfac  *regFactu;
{

  rsetnull(CLONGTYPE, (char *) &(regFactu->numero_cliente));
  rsetnull(CINTTYPE, (char *) &(regFactu->corr_facturacion));
  memset(regFactu->fecha_lectura, '\0', sizeof(regFactu->fecha_lectura));
  memset(regFactu->fecha_vencimiento, '\0', sizeof(regFactu->fecha_vencimiento));
  memset(regFactu->fecha_facturacion, '\0', sizeof(regFactu->fecha_facturacion));
  rsetnull(CLONGTYPE, (char *) &(regFactu->lFechaFacturacion));
  memset(regFactu->centro_emisor, '\0', sizeof(regFactu->centro_emisor));
  memset(regFactu->tipo_docto, '\0', sizeof(regFactu->tipo_docto));
  rsetnull(CLONGTYPE, (char *) &(regFactu->numero_factura));
  memset(regFactu->tipo_tarifa, '\0', sizeof(regFactu->tipo_tarifa));
  memset(regFactu->tipo_iva, '\0', sizeof(regFactu->tipo_iva));
  rsetnull(CDOUBLETYPE, (char *) &(regFactu->consumo_sum));
  memset(regFactu->tarifa, '\0', sizeof(regFactu->tarifa));
  rsetnull(CINTTYPE, (char *) &(regFactu->subtarifa));
  memset(regFactu->indica_refact, '\0', sizeof(regFactu->indica_refact));
  
  memset(regFactu->fecha_lectura_anterior, '\0', sizeof(regFactu->fecha_lectura_anterior));
  rsetnull(CINTTYPE, (char *) &(regFactu->dias_periodo));
  rsetnull(CDOUBLETYPE, (char *) &(regFactu->consumo_normalizado));
  rsetnull(CINTTYPE, (char *) &(regFactu->corr_refacturacion));
  memset(regFactu->clase_servicio, '\0', sizeof(regFactu->clase_servicio));
  memset(regFactu->cdc, '\0', sizeof(regFactu->cdc));

  rsetnull(CDOUBLETYPE, (char *) &(regFactu->lFechaLectura));
  memset(regFactu->cod_ul, '\0', sizeof(regFactu->cod_ul));
  memset(regFactu->cod_porcion, '\0', sizeof(regFactu->cod_porcion));
  rsetnull(CDOUBLETYPE, (char *) &(regFactu->lFechaIniVentana));
  
}

short getFechaLectuAnterior(regFactu)
$ClsHisfac  *regFactu;
{
   $int iCorrFactuAnterior;
   
   iCorrFactuAnterior = regFactu->corr_facturacion - 1;

   $EXECUTE selLecturaAnt INTO :regFactu->fecha_lectura_anterior
      USING :regFactu->numero_cliente,
            :regFactu->corr_facturacion;
            
   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

void Calculos(regFactu)
ClsHisfac   *regFactu;
{
   long     lFechaDesde;
   long     lFechaHasta;
   long     lDiferencia;
   double   dConsumoNorm;
   
   rdefmtdate(&lFechaDesde, "yyyymmdd", regFactu->fecha_lectura_anterior);
   rdefmtdate(&lFechaHasta, "yyyymmdd", regFactu->fecha_lectura);
   
   lDiferencia = lFechaHasta - lFechaDesde;
   regFactu->dias_periodo = lDiferencia;
   
   dConsumoNorm = ((regFactu->consumo_sum / 30.5) * lDiferencia);
   
   regFactu->consumo_normalizado = dConsumoNorm;

}

short TraeRefacturada(regFactu)
$ClsHisfac   *regFactu;
{

   $EXECUTE selRefac INTO
      :regFactu->tipo_iva,
      :regFactu->tipo_tarifa,
      :regFactu->consumo_sum,
      :regFactu->corr_refacturacion,
      :regFactu->clase_servicio,
      :regFactu->cdc
   USING
      :regFactu->numero_cliente,
      :regFactu->lFechaFacturacion,
      :regFactu->numero_factura;
      
   if(SQLCODE !=0){
      return 0;
   }      

   return 1;
}

short LeoFacturasDeta(regFactu, regDeta, iFlagR)
$ClsHisfac  regFactu;
$ClsDetalle *regDeta;
int         iFlagR;
{

   InicializaDetalle(regDeta);
   
   if(iFlagR==0){
      $FETCH curCarfac INTO
        :regDeta->codigo_cargo,
        :regDeta->valor_cargo,
        :regDeta->unidad, 
        :regDeta->descripcion,
        :regDeta->vonzone,
        :regDeta->biszone,
        :regDeta->tariftyp,
        :regDeta->tarifnr,
        :regDeta->belzart,
        :regDeta->preistyp,
        :regDeta->massbill,
        :regDeta->preis,
        :regDeta->zonennr,
        :regDeta->ein01,
        :regDeta->tvorg,
        :regDeta->gegen_tvorg,
        :regDeta->sno;

   }else{
      $FETCH curCarfacAux INTO
        :regDeta->codigo_cargo,
        :regDeta->valor_cargo,
        :regDeta->unidad, 
        :regDeta->descripcion,
        :regDeta->vonzone,
        :regDeta->biszone,
        :regDeta->tariftyp,
        :regDeta->tarifnr,
        :regDeta->belzart,
        :regDeta->preistyp,
        :regDeta->massbill,
        :regDeta->preis,
        :regDeta->zonennr,
        :regDeta->ein01,
        :regDeta->tvorg,
        :regDeta->gegen_tvorg,
        :regDeta->sno;

   }

   if(SQLCODE != 0){
      return 0;
   }
   
   if(!getPrecioUnitario(regFactu, regDeta)){
      return 0;
   }

   alltrim(regDeta->codigo_cargo, ' ');
   alltrim(regDeta->unidad, ' ');
   alltrim(regDeta->descripcion, ' ');
   alltrim(regDeta->tariftyp, ' ');
   alltrim(regDeta->tarifnr, ' ');
   alltrim(regDeta->belzart, ' ');
   alltrim(regDeta->massbill, ' ');
   alltrim(regDeta->preis, ' ');
   alltrim(regDeta->ein01, ' ');
   alltrim(regDeta->tvorg, ' ');
   alltrim(regDeta->gegen_tvorg, ' ');
   alltrim(regDeta->sno, ' ');

   
   return 1;
}

void InicializaDetalle(regDeta)
$ClsDetalle *regDeta;
{

  memset(regDeta->codigo_cargo, '\0', sizeof(regDeta->codigo_cargo));
  rsetnull(CLONGTYPE, (char *) &(regDeta->valor_cargo));
  memset(regDeta->unidad, '\0', sizeof(regDeta->unidad)); 
  rsetnull(CDOUBLETYPE, (char *) &(regDeta->precio_unitario));
  
/*  
  memset(regDeta->clase_pos_doc, '\0', sizeof(regDeta->clase_pos_doc));
  memset(regDeta->contrapartida, '\0', sizeof(regDeta->contrapartida));
  memset(regDeta->cte_de_calculo, '\0', sizeof(regDeta->cte_de_calculo));
  memset(regDeta->tipo_precio, '\0', sizeof(regDeta->tipo_precio));
  memset(regDeta->tarifa, '\0', sizeof(regDeta->tarifa));
  memset(regDeta->deriv_contable, '\0', sizeof(regDeta->deriv_contable));
  
  memset(regDeta->ctaContable, '\0', sizeof(regDeta->ctaContable));
  memset(regDeta->tvorg, '\0', sizeof(regDeta->tvorg));
  memset(regDeta->belzart, '\0', sizeof(regDeta->belzart));
  memset(regDeta->preistyp, '\0', sizeof(regDeta->preistyp));
  memset(regDeta->tarifnr, '\0', sizeof(regDeta->tarifnr));
  memset(regDeta->gegen_tvorg, '\0', sizeof(regDeta->gegen_tvorg));
  memset(regDeta->mngbasis, '\0', sizeof(regDeta->mngbasis));   
*/
   memset(regDeta->tipo_cargo_tarifa, '\0', sizeof(regDeta->tipo_cargo_tarifa));

   memset(regDeta->descripcion, '\0', sizeof(regDeta->descripcion));
   rsetnull(CLONGTYPE, (char *) &(regDeta->vonzone));
   rsetnull(CLONGTYPE, (char *) &(regDeta->biszone));
   memset(regDeta->tariftyp, '\0', sizeof(regDeta->tariftyp));
   memset(regDeta->tarifnr, '\0', sizeof(regDeta->tarifnr));
   memset(regDeta->belzart, '\0', sizeof(regDeta->belzart));
   rsetnull(CINTTYPE, (char *) &(regDeta->preistyp));
   memset(regDeta->massbill, '\0', sizeof(regDeta->massbill));
   memset(regDeta->preis, '\0', sizeof(regDeta->preis));
   rsetnull(CINTTYPE, (char *) &(regDeta->zonennr));   
   memset(regDeta->ein01, '\0', sizeof(regDeta->ein01));
   memset(regDeta->tvorg, '\0', sizeof(regDeta->tvorg));   

   memset(regDeta->gegen_tvorg, '\0', sizeof(regDeta->gegen_tvorg));
   memset(regDeta->sno, '\0', sizeof(regDeta->sno));   

}

short getPrecioUnitario(regFactu, regDeta)
$ClsHisfac  regFactu;
$ClsDetalle *regDeta;
{

printf("Buscando precio unitario para Cliente %ld Corr Factu %ld cargo %s Tipo Cargo: %s\n", 
   regFactu.numero_cliente, regFactu.corr_facturacion, regDeta->codigo_cargo, regDeta->tipo_cargo_tarifa);
  
   
   $EXECUTE selDetValor INTO :regDeta->precio_unitario
      USING :regFactu.numero_cliente,
            :regFactu.corr_facturacion,
            :regDeta->tipo_cargo_tarifa;
            
   if(SQLCODE != 0){
      printf("Error al buscar precio unitario para Cliente %ld Corr Factu %ld cargo %s Tipo Cargo: %s\n", 
         regFactu.numero_cliente, regFactu.corr_facturacion, regDeta->codigo_cargo, regDeta->tipo_cargo_tarifa);

      exit(2);          
   }

   return 1;
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


void GenerarCabecera(regClie, regFactu)
ClsCliente     regClie;
ClsHisfac      regFactu;
{
	char	sLinea[1000];	
   char  sIdDocumento[21];
   char  sTipoFpago[2];
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sIdDocumento, '\0', sizeof(sIdDocumento));
   memset(sTipoFpago, '\0', sizeof(sTipoFpago));

   /* Armo el ID de la factura */   
   if(strcmp(regFactu.tipo_iva, "RIN")==0 || strcmp(regFactu.tipo_iva, "RM")==0 ){
      sprintf(sIdDocumento, "A %s%s-%ld", regFactu.centro_emisor, regFactu.tipo_docto, regFactu.numero_factura);
   }else{
      sprintf(sIdDocumento, "B %s%s-%ld", regFactu.centro_emisor, regFactu.tipo_docto, regFactu.numero_factura);
   }
   alltrim(sIdDocumento, ' ');
   
   /* Armo la forma de pago */
   if(strcmp(regClie.cod_agrupa, "")==0){
      strcpy(sTipoFpago, "C");
   }else{
      if(regClie.tipo_fpago[0]=='D'){
         strcpy(sTipoFpago, "D");
      }else{
         strcpy(sTipoFpago, "N");
      }
   }

   /******** HEAD *********/
   /* LLAVE */
   sprintf(sLinea, "T1%ld-%ldHEAD\t", regClie.numero_cliente, regFactu.corr_facturacion);

  /* VERTRAG */
  sprintf(sLinea, "%sT1%ld", sLinea, regClie.numero_cliente);

  strcat(sLinea, "\n");

  fprintf(pFileUnx, sLinea);
  
  /* el ENDE*/
/*  
  memset(sLinea, '\0', sizeof(sLinea));
	
  sprintf(sLinea, "T1%ld-%ld\t&ENDE", regClie.numero_cliente, regFactu.corr_facturacion);

  strcat(sLinea, "\n");
	
  fprintf(pFileUnx, sLinea);	
*/

   
  /******** ERCH *********/
  memset(sLinea, '\0', sizeof(sLinea));
  
  /* LLAVE */
  sprintf(sLinea, "T1%ld-%ldERCH\t", regClie.numero_cliente, regFactu.corr_facturacion);

  /* VERTRAG */
  sprintf(sLinea, "%sT1%ld\t", sLinea, regClie.numero_cliente);

  /* BELNR nuevo */
  strcat(sLinea, "\t");
  
  /* BUKRS */
  strcat(sLinea, "EDES\t");

  /* SPARTE */
  strcat(sLinea, "01\t");

  /* VERTRAG anulado */
  /*sprintf(sLinea, "%sT1%ld", sLinea, regClie.numero_cliente);*/

  /* BEGABRPE */
  sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_lectura_anterior);

  /* ENDABRPE */
  sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_lectura);

  /* ABRDATS */
  strcat(sLinea, "\t");

  /* ADATSOLL */
  strcat(sLinea, "\t");

  /* PTERMTDAT */
  sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_vencimiento);

  /* BELEGDAT */
  sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_facturacion);

  /* ABWVK anulado*/
   /*sprintf(sLinea, "%s%s\t",sLinea, regClie.cod_agrupa);*/

  /* BELNRALT */
  strcat(sLinea, "\t");

  /* STORNODAT */
  strcat(sLinea, "\t");
  
  /* ABRVORG */
  strcat(sLinea, "01\t");

  /* HVORG */
  strcat(sLinea, "0100\t");

  /* KOFIZ */
  sprintf(sLinea, "%s%s\t", sLinea, regFactu.cdc);

  /* PORTION */
  sprintf(sLinea, "%s%s\t", sLinea, regClie.cod_portion);

  /* FORMULAR */
  strcat(sLinea, "IS_U_BILL_SSF\t");

  /* BELEGART */
  strcat(sLinea, "VA\t");

  /* BEGNACH */
  strcat(sLinea, "\t");

  /* KONZVER */
  strcat(sLinea, "\t");

  /* ERCHZ_V */
  strcat(sLinea, "X\t");

  /* ABLEINH */
  sprintf(sLinea, "%s%s\t", sLinea, regClie.cod_ul);
  
  /* BEGEND */
  strcat(sLinea, "\t");
  
  /* ORIGDOC */
  strcat(sLinea, "\t");

  /* NOCANC */
  strcat(sLinea, "\t");

  /* EXBILLDOCNO */
  sprintf(sLinea, "%s%s\t", sLinea, sIdDocumento);

  /* CORRECTION_DATE */
  strcat(sLinea, "\t");

  /* EZAWE */
  /*
  if(sTipoFpago[0]=='N'){
   strcat(sLinea, "\t");
  }else{
   sprintf(sLinea, "%s%s\t", sLinea, sTipoFpago);
  }
  */
  if(sTipoFpago[0]!='N'){
   sprintf(sLinea, "%s%s\t", sLinea, sTipoFpago);
  }

  /* BILLING_PERIOD nuevo */
  strcat(sLinea, "\t");
  
  /* ZZTOTAL_AMNT nuevo */
  strcat(sLinea, "");
  
  
  /* BELNR */
/*  
  strcat(sLinea, "\t");
*/  
  

  /* ----------------- */ 
  strcat(sLinea, "\n");

  fprintf(pFileUnx, sLinea);
  
  /* el ENDE*/
  memset(sLinea, '\0', sizeof(sLinea));
	
  sprintf(sLinea, "T1%ld-%ld\t&ENDE", regClie.numero_cliente, regFactu.corr_facturacion);

  strcat(sLinea, "\n");
	
  iRcv=fprintf(pFileUnx, sLinea);
  
   if(iRcv < 0){
      printf("Error al escribir Cabecera\n");
      exit(1);
   }	

}

void GenerarDetalle(regClie, regFactu, regDeta, inx)
ClsCliente     regClie;
ClsHisfac      regFactu;
ClsDetalle     regDeta;
int            inx;
{
   char  sLinea[1000];
   int   iMarca;
   
   memset(sLinea, '\0', sizeof(sLinea));
   iMarca=0;
      
   /* LLAVE */
   sprintf(sLinea, "T1%ld-%ld-%s-%dERCHZ\t", regClie.numero_cliente, regFactu.corr_facturacion, regDeta.belzart, inx);

   /* BELZART */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.belzart);

   /* BUCHREL */
   strcat(sLinea, "X\t");
   iMarca=1;

   /* PRINTREL anulado */
   /*if(iMarca==1){
      strcat(sLinea, "X\t");
   }else{
      strcat(sLinea, "\t");
   }*/

   /* TVORG */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.tvorg);

   /* AB (????)*/
   sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_lectura_anterior);

   /* BIS (????)*/
   sprintf(sLinea, "%s%s\t", sLinea, regFactu.fecha_lectura);

   /* SNO (????)*/
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.sno);
   
   /* MASSBILL */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.unidad);

   /* TARIFTYP */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.tariftyp);

   /* KONDIGR (?) */
   strcat(sLinea, "ENERGIA\t");

   /* MWSKZ */
   sprintf(sLinea, "%s%s\t", sLinea, regFactu.tipo_iva);

   /* NETTOBTR */
   sprintf(sLinea, "%s%.2f\t", sLinea, regDeta.valor_cargo);

   /* TWAERS anulado */
   /*strcat(sLinea, "ARS\t");*/

   /* PREISTYP */
   sprintf(sLinea, "%s%d\t", sLinea, regDeta.preistyp);
   
   /* PREIS */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.preis);

   /* VONZONE */
   sprintf(sLinea, "%s%ld\t", sLinea, regDeta.vonzone);
   /* BISZONE */
   sprintf(sLinea, "%s%ld\t", sLinea, regDeta.biszone);

   /* ZONENNR */
   sprintf(sLinea, "%s%d\t", sLinea, regDeta.zonennr);

   /* PREISBTR */
   sprintf(sLinea, "%s%.2f\t", sLinea, regDeta.precio_unitario);

   /* I_ZWSTAND */
   strcat(sLinea, "0\t");

   /* I_ABRMENGE */
   sprintf(sLinea, "%s%.0f\t", sLinea, regFactu.consumo_sum);
   
   /* AKLASSE anulado */
   /*strcat(sLinea, "01\t");*/

   /* LINESORT anulado */
   /*strcat(sLinea, "0002\t");*/

   /* TARIFNR */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.tarifnr);

   /* GEGEN_TVORG */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.gegen_tvorg);

   /* MNGBASIS anulado */
   /*sprintf(sLinea, "%s%s\t", sLinea, regDeta.cte_de_calculo);*/
   
   /* EIN01 */
   sprintf(sLinea, "%s%s\t", sLinea, regDeta.ein01);
   
   /* ZZHASH_COD nuevo*/
   strcat(sLinea, "\t");
   /* ZZMONT_LIQ nuevo*/
   strcat(sLinea, "\t");
   /* ZZSBASW nuevo */
   strcat(sLinea, "\t");
   /* ZZSTPRZ nuevo */
   strcat(sLinea, "");

      
   strcat(sLinea, "\n");
  
   iRcv=fprintf(pFileUnx, sLinea);

   if(iRcv < 0){
      printf("Error al escribir Detalle\n");
      exit(1);
   }	

}


void GeneraENDE(regFactu, regDeta, inx)
ClsHisfac   regFactu;
ClsDetalle  regDeta;
int         inx;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   sprintf(sLinea, "T1%ld-%ld-%s-%&ENDE", regFactu.numero_cliente, regFactu.corr_facturacion, regDeta.clase_pos_doc, inx);
   
	strcat(sLinea, "\n");
	
	iRcv = fprintf(pFileUnx, sLinea);
   
   if(iRcv < 0){
      printf("Error al escribir Detalle\n");
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
		strcpy(sTipoArchivo, "BILLDOC");
		strcpy(sNombreArchivo, sSoloArchivoDocuCalcu);
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

short CargarCtas(regCta, iCant)
$ClsCtaAgrupa  **regCta;
int            *iCant;
{
$ClsCtaAgrupa	*regAux=NULL;
$ClsCtaAgrupa	reg;
int indice=0;
   
   *iCant = indice;
   
	if(*regCta != NULL)
		free(*regCta);
		
	*regCta = (ClsCtaAgrupa *) malloc (sizeof(ClsCtaAgrupa));
	if(*regCta == NULL){
		printf("Fallo Malloc CargarCtas().\n");
		return 0;
	}
   
   $OPEN curCtaAgrupa;
   
   while(LeoCuenta(&reg)){
   
		regAux = (ClsCtaAgrupa*) realloc(*regCta, sizeof(ClsCtaAgrupa) * (++indice) );
		if(regAux == NULL){
			printf("Fallo Realloc CargarCtas().\n");
			return 0;
		}		
		
		(*regCta) = regAux;
		
		strcpy((*regCta)[indice-1].codigo_cargo, reg.codigo_cargo);
		strcpy((*regCta)[indice-1].codigo_cuenta, reg.codigo_cuenta);
		strcpy((*regCta)[indice-1].agrupacion, reg.agrupacion);
      strcpy((*regCta)[indice-1].descripcion, reg.descripcion);
   
   }
   
   $CLOSE curCtaAgrupa;

   *iCant = indice;

   return 1;
}

short LeoCuenta(reg)
$ClsCtaAgrupa  *reg;
{

   InicializoCta(reg);
   
   $FETCH curCtaAgrupa INTO
      :reg->codigo_cargo, 
      :reg->codigo_cuenta, 
      :reg->agrupacion,
      :reg->descripcion;
   
   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

void  InicializoCta(reg)
$ClsCtaAgrupa  *reg;
{

   memset(reg->codigo_cargo, '\0', sizeof(reg->codigo_cargo)); 
   memset(reg->codigo_cuenta, '\0', sizeof(reg->codigo_cuenta)); 
   memset(reg->agrupacion, '\0', sizeof(reg->agrupacion));
   memset(reg->descripcion, '\0', sizeof(reg->descripcion));

}

short BuscaCuenta(regClie, regFactu, vecCta, iCant, regDeta)
ClsCliente  regClie;
ClsHisfac   regFactu;
ClsCtaAgrupa   *vecCta;
int         iCant;
ClsDetalle  *regDeta;
{
   
   int i;
   int s;
   char  sCta[9];
   char  sAgrupa[4];
   char  sCtaAux[5];
   
   memset(sCta, '\0', sizeof(sCta));
   memset(sAgrupa, '\0', sizeof(sAgrupa));
   memset(sCtaAux, '\0', sizeof(sCtaAux));
   
   i=0; s=0;
   
   while(i < iCant){
      if(strcmp(vecCta[i].codigo_cargo, regDeta->codigo_cargo)==0){
         strcpy(sCta, vecCta[i].codigo_cuenta);
         sprintf(sAgrupa, "%c%c", vecCta[i].agrupacion[1], vecCta[i].agrupacion[2]);
         s=1;
      }
      i++;
   }

   if(s==0){
      printf("No se encontró referencias para concepto %s\n", regDeta->codigo_cargo);
      return 0;
   }

   strcpy(sCtaAux, getNroCuentaAux(regClie, regFactu, sAgrupa)); 
   
   strcat(sCta, sCtaAux);

   strcpy(regDeta->ctaContable, sCta);
      
   return 1;
}

char *getNroCuentaAux(regClie, regFactu, sAgrupa)
ClsCliente  regClie;
ClsHisfac   regFactu;
char        sAgrupa[4];
{
   char  sCtaAux[5];

   memset(sCtaAux, '\0', sizeof(sCtaAux));
   
   switch(atoi(sAgrupa)){
      case 1:
         sprintf(sCtaAux, "%s%s0", getTarifa(regFactu.tarifa), getClase(regClie.tipo_cliente));
         break;
         
      case 2:
      case 12:
         sprintf(sCtaAux, "%s%s0", getTarifa(regFactu.tarifa), getExigibilidad(regFactu.fecha_vencimiento));
         break;
      case 3:
         sprintf(sCtaAux, "%s%s%s", getTarifa(regFactu.tarifa), getSubTarifa(regFactu.tarifa, regFactu.subtarifa), getClase(regClie.tipo_cliente));
         break;
         
      case 4:
         sprintf(sCtaAux, "%s00", getTarifa(regFactu.tarifa));
         break;
         
      case 14:
         sprintf(sCtaAux, "%s%s0", getTarifa(regFactu.tarifa), getSubTarifa(regFactu.tarifa, regFactu.subtarifa));
         break;
   }   
   
   return sCtaAux;
}

char *getClase(sCodMac)
char  sCodMac[3];
{
   char  sClase[2];
   
   memset(sClase, '\0', sizeof(sClase));
   
   if(strcmp(sCodMac, "ON")==0){
      strcpy(sClase, "1");
   }else if(strcmp(sCodMac, "OP")==0){
      strcpy(sClase, "2");
   }else if(strcmp(sCodMac, "OM")==0 || strcmp(sCodMac, "AP")==0){
      strcpy(sClase, "3");
   }else{
      strcpy(sClase, "0");
   }

   return sClase;   
}

char  *getTarifa(sCodMac)
char  sCodMac[4];
{
   char  sAux[3];
   char  sTarMap[3];
   
   memset(sAux, '\0', sizeof(sAux));
   memset(sTarMap, '\0', sizeof(sTarMap));

   sprintf(sAux, "%c%c", sCodMac[0], sCodMac[1]);

   if(strcmp(sAux, "1R")==0 || strcmp(sAux, "1G")==0){
      strcpy(sTarMap, "01");
   }else if(strcmp(sAux, "1A")==0 || strcmp(sAux, "AP")==0){
      strcpy(sTarMap, "06");
   }else if(strcmp(sAux, "1J")==0 ){
      strcpy(sTarMap, "07");
   }else{
      strcpy(sTarMap, "08");
   }
   
   return sTarMap;
}

char  *getSubTarifa(sTar, iSubTar)
char  sTar[3];
int   iSubTar;
{
   char  sSubTar[2];
   char  sAux[3];
   
   memset(sAux, '\0', sizeof(sAux));
   memset(sSubTar, '\0', sizeof(sSubTar));

   sprintf(sAux, "%c%c", sTar[0], sTar[1]);

   if(strcmp(sAux, "PR")==0 || strcmp(sAux, "PJ")==0 || strcmp(sAux, "PG")==0 || strcmp(sAux, "1R")==0){
      strcpy(sSubTar, "0");
   }else{
      sprintf(sSubTar, "%d", iSubTar);
   }

   return sSubTar;
}

char *getExigibilidad(sFechaVto)
char  sFechaVto[9];
{
   long lFechaVto;
   char  exige[2];
   
   memset(exige, '\0', sizeof(exige));

   rdefmtdate(&lFechaVto, "yyyymmdd", sFechaVto);
   
   if(lFechaVto > lFechaHoy){
      strcpy(exige, "1");
   }else{
      strcpy(exige, "0");
   }

   return exige;
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

