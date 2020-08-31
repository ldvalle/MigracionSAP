/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_operandos_bim
    
	Fecha : 23/05/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura OPERANDOS para operandos
      bimestrales.
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0=Activos; 1= No Activos; 2= Todos;		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		<Fecha Inicio Busqueda> <Opcional>: dd/mm/aaaa

********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_operando_nvo.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
$long glFechaDesde;

char	sArchOperandos[100];
char	sSoloArchivoOperandos[100];

FILE  *fpOperandos;

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

$ClsConsuBim      *vecConsuBim;
$ClsFactura       *vecFacturas;
$ClsElectro       *vecElectro;
$ClsFactorPot     *vecFactorPot;

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
$long    lFechaRti;

char	*vSucursal[]={"0003", "0004", "0010", "0020", "0023", "0026", "0050", "0065", "0053", "0056", "0059", "0069"};
$char	sSucursal[5];
int		i;
$ClsCliente       regCliente;
$ClsConsuBim		regConsumo;
$ClsFactura       regFactu;
int         index;
int         iFila;

$ClsAhorroHist    regAhorro;
$ClsFacts         regFact;
FILE              *fpUnx;

int         iFlagRefacturada;
$long       lFechaInicio;
$long       lFechaLecturaPrima;
$long       lFechaLectuAnterior;
long        lContador;
int         iIndice;

char        sFechaDesde[11];
char        sFechaHasta[11];
$long       lFechaDesde;
$long       lFechaHasta;

$long       cantConsu;
$long       cantLectuActi;
int         iOcurrCliente;
int         tiene_QCONSBIMES;
int         tiene_FACDIASPC;
int         tiene_QCONBFPACT;
int         tiene_QCONBFPREAC;
int         tiene_VIP;
int         tiene_TIS;
int         tiene_FLAGTAP;
int         tiene_FACTOR_TAP;
int         tiene_QPTAP;
int         tiene_FLAGEBP;
int         tiene_FLAGFP;
int			tiene_FLAGCLUB;
int         iOcurrClienteQB;
int         iOcurrClienteQBreac;
int         iMoviArchivos;
int			iBucle;

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
	
	CreaPrepare();


	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
   
   $EXECUTE selFechaRti INTO :lFechaRti;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha RTI\n");
      exit(2);
   }
            
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(sSucursal, '\0', sizeof(sSucursal));
   
      strcpy(sSucursal, "");
      
      lContador=0;
      iIndice=1;
      
		if(!AbreArchivos(sSucursal, iIndice)){
			exit(1);	
		}
		
      fpUnx=fpOperandos;
      iMoviArchivos=0;
      
		$OPEN curClientes;
      while(LeoCliente(&regCliente)){
         cantConsu=0;
         cantLectuActi=0;
         
         iOcurrCliente=0;
         tiene_QCONBFPACT=0;
         tiene_QCONBFPREAC=0;
         tiene_QCONSBIMES=0;
         tiene_FACDIASPC=0;
         tiene_VIP=0;
         tiene_TIS=0;
         tiene_FLAGTAP=0;
         tiene_FACTOR_TAP=0;
         tiene_QPTAP=0;
         tiene_FLAGEBP=0;
         tiene_FLAGFP=0;
         tiene_FLAGCLUB=0;
         iOcurrClienteQB=0;
         iOcurrClienteQBreac=0;
         
         if(!ClienteYaMigrado(regCliente.numero_cliente, &lFechaInicio, &iFlagMigra)){
            
            index=1;
            iFila=0;
                        
            if(regCliente.corr_facturacion > 1){
               lFechaLecturaPrima=0;
               lFechaLectuAnterior=0;
               cantLectuActi=0;
               cantConsu=0;
               
               /* Abre Cliente */
               GeneraKey3(fpUnx, regCliente.numero_cliente);
               
               if(glFechaParametro > 0)
                  lFechaInicio = glFechaParametro;
/*                
               InicializaVectorFacturas(&(vecFacturas));
                 
               $OPEN curFactura USING  :regCliente.numero_cliente, :lFechaInicio;
               
               while(LeoFactura(&regFactu)){
                  CargaVectorFacturas(regFactu, index, &(vecFacturas));
                  index++;   
               }

               $CLOSE curFactura;
*/

					InicializaVectorConsumos(&(vecConsuBim));
					$OPEN curConsuBim USING :regCliente.numero_cliente;
               
               while(LeoConsumos(&regConsumo)){
                  CargaVectorConsumos(regConsumo, index, &(vecConsuBim));
                  index++;   
               }					
					
					$CLOSE curConsuBim;
					
					/* QCONSBIMES */
					iBucle=0;
               for(iFila=index-1; iFila >=0; iFila--){
						iBucle++;
                  TraspasoDatosConsu(1, regCliente, vecConsuBim[iFila], &regFact);               
                  GenerarPlanos(fpUnx, 1, regFact, iBucle);
                  lContador++;
                  cantLectuActi++;
                  cantConsu++;
                  tiene_QCONSBIMES=1;
               }
					
               /* FACDIASPC  */
               iBucle=0;
               for(iFila=1; iFila < index; iFila++){
						iBucle++;
                  TraspasoDatosConsu(2, regCliente, vecConsuBim[iFila], &regFact);
                  GenerarPlanos(fpUnx, 2, regFact, iBucle);
                  lContador++;
                  tiene_FACDIASPC=1;
               }					
/*					
               // QCONSBIMES ahora mensual
               for(iFila=1; iFila < index; iFila++){
                  TraspasoDatosFactu(1, regCliente, vecFacturas[iFila], &regFact);               
                  GenerarPlanos(fpUnx, 1, regFact, iFila);
                  lContador++;
                  cantLectuActi++;
                  cantConsu++;
                  tiene_QCONSBIMES=1;
               }
               if(tiene_QCONSBIMES==1){
                  TraspasoDatosFactu(1, regCliente, vecFacturas[1], &regFact);
                  //GeneraENDE2(fpUnx, 1, regCliente.numero_cliente);
               }
               
               // FACDIASPC 
               for(iFila=1; iFila < index; iFila++){
                  TraspasoDatosFactu(2, regCliente, vecFacturas[iFila], &regFact);               
                  GenerarPlanos(fpUnx, 2, regFact, iFila);
                  lContador++;
                  tiene_FACDIASPC=1;
               }
               if(tiene_FACDIASPC==1){
                  TraspasoDatosFactu(2, regCliente, vecFacturas[1], &regFact);
                  //GeneraENDE2(fpUnx, 2, regCliente.numero_cliente);
               }
               
               // QCONBFPACT
               for(iFila=1; iFila < index; iFila++){
                  TraspasoDatosFactu(3, regCliente, vecFacturas[iFila], &regFact);               
                  GenerarPlanos(fpUnx, 3, regFact, iFila);
                  lContador++;
                  tiene_QCONBFPACT=1;
               }
               if(tiene_QCONBFPACT==1){
                  TraspasoDatosFactu(3, regCliente, vecFacturas[1], &regFact);
                  //GeneraENDE2(fpUnx, 3, regCliente.numero_cliente);
               }
               
               // QCONBFPREAC
               for(iFila=0; iFila < index; iFila++){               
                  if(vecFacturas[iFila].tipo_medidor[0]=='R'){
                     if(getConsuReactiva(&(vecFacturas[iFila]))){
                        TraspasoDatosFactu(4, regCliente, vecFacturas[iFila], &regFact);
                        GenerarPlanos(fpUnx, 4, regFact, iFila);
                        lContador++;
                        tiene_QCONBFPREAC=1;
                     }else{
                        printf("No se encontró consumo reactiva para cliente %ld correlativo %d\n", vecFacturas[iFila].numero_cliente, vecFacturas[iFila].corr_facturacion);
                     }
                  }
               }
               if(tiene_QCONBFPREAC==1){
                  TraspasoDatosFactu(4, regCliente, vecFacturas[1], &regFact);
                  //GeneraENDE2(fpUnx, 4, regCliente.numero_cliente);
               }
*/               
               
               
               /* VIP */
               if(ProcesaElectro(regCliente.numero_cliente, lFechaInicio, &lContador)){
                  tiene_VIP=1;
               }
               
               /* TIS */
               if(ProcesaTarSoc(regCliente.numero_cliente, lFechaInicio, &lContador)){
                  tiene_TIS=1;
               }

               /* TASA */
               if(ProcesaTasas(regCliente.numero_cliente, lFechaInicio, &lContador)){
                  tiene_FLAGTAP=1;
                  tiene_FACTOR_TAP=1;
                  tiene_QPTAP=1;
               }               
               
               /* Entidad Bien Publico */
               if(ProcesaEBP(regCliente.numero_cliente, lFechaInicio, &lContador)){
                  tiene_FLAGEBP=1;
               }               
               
               /* Factor Potencia */
               if(ProcesaFP(regCliente.numero_cliente, lFechaInicio, &lContador)){
                  tiene_FLAGFP=1;
               }               
               
               /* Club de Barrio */
               if(ProcesaClubBarrio(regCliente.numero_cliente, lFechaInicio, &lContador)){
						tiene_FLAGCLUB=1;
					}
               
               /* Cierre Cliente */
               GeneraENDE3(fpUnx, regCliente.numero_cliente);
               
               if(lContador >= 700000){
                  fclose(fpUnx);
                  MueveArchivos();
                  iIndice++;
                  lContador=0;
            		if(!AbreArchivos(sSucursal, iIndice)){
            			exit(1);	
            		}
                  iMoviArchivos=1;
               }
            }

            /*if(giTipoCorrida==0){*/            
               $BEGIN WORK;            
               if(!RegistraCliente(regCliente.numero_cliente, cantConsu, cantLectuActi, iFlagMigra)){
                  $ROLLBACK WORK;
                  printf("No se registro cliente Oper Bim %ld\n", regCliente.numero_cliente);
                  exit(2);
               }
               
               if(tiene_VIP==1){
                  if(!RegistraClienteFLAG("VIP", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente VIP %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
               }

               if(tiene_TIS==1){
                  if(!RegistraClienteFLAG("TIS", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente TIS %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
               }
               
               if(tiene_FLAGTAP==1){
                  if(!RegistraClienteFLAG("TASAFF", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente TASAFF %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
                  if(!RegistraClienteFLAG("QTASA", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente QTASA %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
                  
               }
               
               if(tiene_FLAGEBP==1){
                  if(!RegistraClienteFLAG("EBP", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente EBP %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
               }
               
               if(tiene_FLAGFP == 1){
                  if(!RegistraClienteFLAG("FP", regCliente.numero_cliente, 1, iFlagMigra)){
                     $ROLLBACK WORK;
                     printf("No se registro cliente FP %ld\n", regCliente.numero_cliente);
                     exit(2);
                  }
               }
               
               $COMMIT WORK;
            /*}*/            
            cantProcesada++;
         }else{
            cantPreexistente++;
         } 
                 
      } /* Clientes */
   
      $CLOSE curClientes;

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
   
*/

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

   MueveArchivos();


	printf("==============================================\n");
	printf("Operandos Consolidado\n");
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

short AbreArchivos(sSucur, indice)
char  sSucur[5];
int   indice;
{
	
	memset(sArchOperandos,'\0',sizeof(sArchOperandos));
	memset(sSoloArchivoOperandos,'\0',sizeof(sSoloArchivoOperandos));

   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchOperandos  , "%sT1FACTS_CONSOLIDADO_%d.unx", sPathSalida, indice );
	sprintf( sSoloArchivoOperandos, "T1FACTS_CONSOLIDADO_%d.unx", indice);

	fpOperandos=fopen( sArchOperandos, "w" );
	if( !fpOperandos ){
		printf("ERROR al abrir archivo %s.\n", sArchOperandos );
		return 0;
	}
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(fpOperandos);
}

void  MueveArchivos()
{
char	sCommand[1000];
int	iRcv;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	if(giEstadoCliente==0){
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/Operandos/", sPathCopia);
	}else{
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchOperandos);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchOperandos, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchOperandos);
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
   strcat(sql, "TRIM(t2.acronimo_sap) tipo_tarifa "); 
   strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER sap_transforma t1, OUTER sap_transforma t2 ");

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
   strcat(sql, "AND t2.clave = 'TARIFTYP' ");
   strcat(sql, "AND t2.cod_mac = c.tarifa ");

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

   /*********** Consumos Bimestrales ************/
	$PREPARE selConsuBim FROM "SELECT FIRST 6 f1.numero_cliente,
		f1.corr_fact_ant,
		f1.corr_facturacion,
		f1.tipo_lectura,
		f1.tarifa,
		f1.fecha_lectura_ant +1,
		CASE 
			WHEN f1.fecha_lectura_ver IS NULL THEN f1.fecha_lectura
			ELSE f1.fecha_lectura_ver
		END fecha_lectu_cierre,
		CASE 
			WHEN f1.fecha_lectura_ver IS NULL THEN f1.fecha_lectura - f1.fecha_lectura_ant
			ELSE f1.fecha_lectura_ver - f1.fecha_lectura_ant
		END cant_dias,
		f1.cons_activa_p1,
		f1.cons_activa_p2,
		f1.cons_activa_p1 + f1.cons_activa_p2 consumo_activa,
		f1.lectura_ant,
		CASE
			WHEN f1.tipo_lectura = 1 THEN f1.lectura_prop
		  WHEN f1.tipo_lectura = 4 THEN f1.lectura_a_fact
		  WHEN f1.ind_verificacion='S' AND f1.tipo_lectura in (2,3) AND f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif
			WHEN f1.ind_verificacion='S' AND f1.tipo_lectura = 2 AND f1.fecha_lectura_ver IS NULL THEN f1.lectura_actual
		  WHEN (f1.ind_verificacion !='S' OR f1.ind_verificacion IS NULL) AND f1.tipo_lectura = 2 THEN f1.lectura_actual  
		  ELSE -1
		END lectura_cierre,
		f1.cons_reac_p2 - f1.cons_reac_p1 cons_reactiva,
		f1.numero_medidor,
		f1.marca_medidor,
		f1.tipo_medidor
		FROM fp_lectu f1
		WHERE f1.numero_cliente = ?
		ORDER BY f1.corr_facturacion desc ";

	$DECLARE curConsuBim CURSOR WITH HOLD FOR selConsuBim;
	
	/*********** Hislec Refac ************/ 
	$PREPARE selRefac FROM "SELECT NVL(SUM(r.kwh_refacturados), 0) 
		FROM hisfac h, refac r
		WHERE h.numero_cliente = ?
		AND h.corr_facturacion = ?
		AND r.numero_cliente = h.numero_cliente
		AND r.fecha_fact_afect = h.fecha_facturacion
		AND r.nro_docto_afect = h.numero_factura";
	

/*   
   strcpy(sql, "SELECT DISTINCT h.numero_cliente, "); 
   strcat(sql, "h.corr_facturacion, ");
   strcat(sql, "l1.lectura_facturac - l2.lectura_facturac, "); 
   strcat(sql, "h.tarifa, "); 
   strcat(sql, "h.indica_refact, ");
   strcat(sql, "l2.fecha_lectura + 1 fdesde, "); 
   strcat(sql, "l1.fecha_lectura fhasta, ");
   strcat(sql, "(l1.fecha_lectura - (l2.fecha_lectura + 1)) difdias, ");
   strcat(sql, "((l1.lectura_facturac - l2.lectura_facturac)/ (l1.fecha_lectura - (l2.fecha_lectura + 1))) * 61 cons_61, ");
   strcat(sql, "h.fecha_facturacion, ");
   strcat(sql, "h.numero_factura, ");
   strcat(sql, "l1.tipo_lectura, ");
   strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
   strcat(sql, "'000T1'|| lpad(h.sector,2,0) || sc.cod_ul_sap porcion, ");
   strcat(sql, "TRIM(sc.cod_ul_sap || lpad(h.sector , 2, 0) ||  lpad(h.zona,5,0)) unidad_lectura, ");
   strcat(sql, "h.coseno_phi/100, ");
   strcat(sql, "h.consumo_sum, ");
   strcat(sql, "l1.lectura_facturac ");
   strcat(sql, "FROM hisfac h, hislec l1, hislec l2, medid m, sucur_centro_op sc ");
   strcat(sql, "WHERE h.numero_cliente = ? ");
   strcat(sql, "AND h.tipo_docto IN ('01', '07') ");
   strcat(sql, "AND l1.numero_cliente = h.numero_cliente ");
   strcat(sql, "AND l1.corr_facturacion = h.corr_facturacion ");
   strcat(sql, "AND l1.tipo_lectura IN (1,2,3,4,7,8) ");
   strcat(sql, "AND l2.numero_cliente = h.numero_cliente ");
   strcat(sql, "AND l2.corr_facturacion = (SELECT MAX(l3.corr_facturacion) FROM hislec l3 ");
   strcat(sql, "	WHERE l3.numero_cliente = h.numero_cliente ");
   strcat(sql, " 	AND l3.corr_facturacion < h.corr_facturacion ");
   strcat(sql, "  AND l3.tipo_lectura IN (1,2,3,4,7)) ");
   strcat(sql, "AND l2.fecha_lectura >= ? ");
   strcat(sql, "AND l2.tipo_lectura IN (1,2,3,4,7) ");   
   strcat(sql, "AND m.numero_medidor = l1.numero_medidor ");
   strcat(sql, "AND m.marca_medidor = l1.marca_medidor ");
   strcat(sql, "AND sc.cod_centro_op = h.sucursal ");
   
   strcat(sql, "ORDER BY h.corr_facturacion ASC ");

   
   $PREPARE selFactura FROM $sql;

   $DECLARE curFactura CURSOR WITH HOLD FOR selFactura;
*/
   /************ Consumos Activa Refacturados ************/
/*   
   strcpy(sql, "SELECT kwh_refacturados, kvar_refac_reac "); 
   strcat(sql, "FROM refac ");
   strcat(sql, "WHERE numero_cliente = ? ");
   strcat(sql, "AND nro_docto_afect = ? ");
   strcat(sql, "AND fecha_fact_afect = ? ");

   $PREPARE selRefac FROM $sql;

   $DECLARE curRefac CURSOR WITH HOLD FOR selRefac;
*/   
   /********** Ahorro_Hist ************/
   strcpy(sql, "SELECT a1.numero_cliente, ");
   strcat(sql, "a1.corr_fact_act, ");
   strcat(sql, "a1.fecha_lectura_act_2 + 1, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act_2 + 1, '%Y%m%d'), ");
   strcat(sql, "a1.fecha_lectura_act, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act, '%Y%m%d'), ");
   strcat(sql, "a1.consumo_61dias_act, ");
   strcat(sql, "a1.dias_per_act ");
   strcat(sql, "FROM ahorro_hist a1 ");
   strcat(sql, "WHERE a1.numero_cliente = ? ");
   strcat(sql, "ORDER BY corr_fact_act ASC ");
   
   $PREPARE selAhorro FROM $sql;

   $DECLARE curAhorro CURSOR WITH HOLD FOR selAhorro;

   /************* Primera Lectura *****************/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.tipo_lectura IN (1,2,3,4,7) ");   
   
   $PREPARE selPrimaLectura FROM $sql;

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
	strcat(sql, "'FACTSBIM', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	/*strcpy(sql, "SELECT facts_bim, fecha_val_tarifa FROM sap_regi_cliente ");*/
   strcpy(sql, "SELECT facts_bim, fecha_pivote FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, facts_bim, qconsbimes, facdiaspc, qconbfpact ");
	strcat(sql, ")VALUES(?, 'S', ?, ?, ?) ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "facts_bim = 'S', ");
	strcat(sql, "qconsbimes = ?, ");
	strcat(sql, "facdiaspc = ?, ");
	strcat(sql, "qconbfpact = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ FechaLimiteInferior **************/
	/* strcpy(sql, "SELECT TODAY-365 FROM dual ");

	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
*/		
	$PREPARE selFechaLimInf FROM "SELECT fecha_pivote FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
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
	
   /********* Registra Corrida **********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'OPEBIM', ?, CURRENT, ?)";

   /******** Fecha Inicio busqueda *******/
   $PREPARE selFechaDesde FROM "SELECT fecha_limi_inf FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
   /******* Consumo Reactiva *******/
   $PREPARE selConsuReac FROM "SELECT h1.cons_reac + h2.cons_reac 
      FROM hisfac_adic h1, hisfac_adic h2
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h2.numero_cliente = h1.numero_cliente
      AND h2.corr_facturacion = h1.corr_facturacion-1 ";

   /******* Lectura Reactiva *******/
   $PREPARE selLectuReac FROM "SELECT lectu_factu_reac 
      FROM hislec_reac
      WHERE numero_cliente = ?
      AND corr_facturacion = ?
      AND tipo_lectura IN (1,2,3,4) ";   
   
   /******* Lectura Reactiva Ajustada *******/
   $PREPARE selLectuReacRefac FROM "SELECT h1.lectu_rectif_reac
      FROM hislec_refac_reac h1
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h1.corr_refacturacion = ( SELECT MAX(h2.corr_refacturacion)
      	FROM hislec_refac_reac h2
      	WHERE h2.numero_cliente = h1.numero_cliente
      	AND h2.corr_facturacion = h1.corr_facturacion ) ";
   
   /******* Ini Ventana Agenda 1 *******/
   $PREPARE selIniVentana1 FROM "SELECT MIN(inicio_ventana)+1 FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND ? BETWEEN inicio_ventana AND fin_ventana ";
	
   /******* Ini Ventana Agenda 2 *******/	
   $PREPARE selIniVentana2 FROM "SELECT MAX(inicio_ventana)+1 FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND inicio_ventana <= ? ";
   
   /******* Leyenda CosPhi *******/
   $PREPARE selLeyenda FROM "SELECT evento, fecha_evento
      FROM rer_eventos_cabe
      WHERE numero_cliente = ? ";

   /******* FP Lectu  ******/         
   $PREPARE selFpLectu FROM "SELECT cons_activa_p1 + cons_activa_p2 
      FROM fp_lectu
      WHERE numero_cliente = ?
      AND corr_facturacion = ? ";
   
   /******* FP Lectu Reac ******/
   $PREPARE selFpLectuReac FROM "SELECT cons_reac_p1 + cons_reac_p2 
      FROM fp_lectu
      WHERE numero_cliente = ?
      AND corr_facturacion = ? ";

   /* ELECTRO DEPENDIENTE */
   $PREPARE selElectro FROM "SELECT v.numero_cliente,
      v.fecha_activacion + 1,
      TO_CHAR(v.fecha_activacion + 1, '%Y%m%d'),
      NVL(v.fecha_desactivac, 0),
      NVL(TO_CHAR(v.fecha_desactivac, '%Y%m%d'), '99991231'),
      v.motivo,
      NVL(c.corr_facturacion, 0),
      NVL(c.nro_beneficiario, 0)
      FROM cliente c, clientes_vip v, tabla tb1
      WHERE c.numero_cliente = ?
      AND v.numero_cliente = c.numero_cliente
      AND v.numero_cliente = c.numero_cliente
		AND ( ( ? BETWEEN v.fecha_activacion AND v.fecha_desactivac )
			 OR
			 (v.fecha_activacion >= ?))      
      AND tb1.nomtabla = 'SDCLIV'
      AND tb1.codigo = v.motivo
      AND tb1.valor_alf[4] = 'S'
      AND tb1.sucursal = '0000'
      AND tb1.fecha_activacion <= TODAY
      AND ( tb1.fecha_desactivac >= TODAY OR tb1.fecha_desactivac IS NULL )
      ORDER BY 2 ASC ";

   $DECLARE curElectro CURSOR FOR selElectro;
   
   /* TARIFA SOCIAL */
   $PREPARE selTarifaSocial FROM "SELECT v.numero_cliente,
      v.fecha_inicio + 1,
      TO_CHAR(v.fecha_inicio + 1, '%Y%m%d'),
      NVL(v.fecha_desactivac, 0),
      NVL(TO_CHAR(v.fecha_desactivac, '%Y%m%d'), '99991231'),
      v.motivo,
      NVL(c.corr_facturacion, 0),
      NVL(c.nro_beneficiario, 0)
      FROM cliente c, tarifa_social v
      WHERE c.numero_cliente = ?
      AND v.numero_cliente = c.numero_cliente
		AND ( ( ? BETWEEN v.fecha_inicio AND v.fecha_desactivac )
			 OR
			 (v.fecha_inicio >= ?))      
      ORDER BY 2 ASC ";      

   $DECLARE curTarifaSocial CURSOR FOR selTarifaSocial;

   /* FLAG y FACTOR TASA */
   $PREPARE selTasaVig FROM "SELECT numero_cliente, 
      fecha_activacion + 1,
      TO_CHAR(fecha_activacion + 1, '%Y%m%d'),
      NVL(TO_CHAR(fecha_desactivac, '%Y%m%d'), '99991231'),
      cant_valor_tasa
      FROM tasas_vigencia
      WHERE numero_cliente = ?
		AND ( ( ? BETWEEN fecha_activacion AND fecha_desactivac )
			 OR
			 (fecha_activacion >= ?))       
      ORDER BY fecha_activacion ASC ";
         
   $DECLARE curTasasVig CURSOR FOR selTasaVig;
   
   /* PRECIOS TASA */
   $PREPARE selPrecioTasa FROM "SELECT h.numero_cliente, 
      h.corr_facturacion corr,
      h.fecha_facturacion ffac, 
      p.fecha, 
      p.valor,
      c.codigo_valor,
      'PT1TAP' || h.partido precio_sap
      FROM hisfac h, carfac c2, condic_impositivas c, preca p
      WHERE h.numero_cliente = ?
      AND h.fecha_facturacion > ?
      AND c2.numero_cliente= h.numero_cliente
      AND c2.corr_facturacion = h.corr_facturacion
      AND c2.codigo_cargo = c.codigo_impuesto
      AND c2.codigo_cargo IN ('580','886','887')
      AND c.cod_municipio = h.partido
      AND c.clase_servicio = h.clase_servicio
      AND p.codigo_valor = c.codigo_valor      
      AND p.fecha = (SELECT MAX(p2.fecha) FROM preca p2
      	WHERE p2.codigo_valor = p.codigo_valor
        AND p2.fecha < h.fecha_facturacion)
      ORDER BY 2 ASC ";
  
   $DECLARE curPrecioTasa CURSOR FOR selPrecioTasa;  

   /* Entidad Bien Publico */   
   $PREPARE selEBP FROM "SELECT e.numero_cliente,
   e.fecha_inicio + 1,
   TO_CHAR(e.fecha_inicio + 1, '%Y%m%d'),
   NVL(TO_CHAR(e.fecha_desactivac, '%Y%m%d'), '99991231')
   FROM entid_bien_publico e
   WHERE e.numero_cliente = ?
	AND ( ( ? BETWEEN e.fecha_inicio AND e.fecha_desactivac )
		 OR
		 (e.fecha_inicio >= ?))   
   ORDER BY 2 ASC ";

   $DECLARE curEBP CURSOR FOR selEBP;

   /* Factor Potencia */
   $PREPARE selFP FROM "SELECT r.numero_cliente, t2.cod_sap, r.evento, r.fecha_evento, 
      TRIM(t1.acronimo_sap) tipo_tarifa
      FROM rer_eventos_cabe r, cliente c, sap_transforma t1, OUTER sap_transforma t2
      WHERE r.numero_cliente = ?
      AND c.numero_cliente = r.numero_cliente
      AND t1.clave = 'TARIFTYP'
      AND t1.cod_mac = c.tarifa
      AND t2.clave = 'BFP'
      AND t2.cod_mac = r.evento
      ORDER BY r.fecha_evento ASC ";   

   $DECLARE curFP CURSOR FOR selFP;
   
   /* Club Barrio */
	$PREPARE selBarrio FROM "SELECT numero_cliente, 
		fecha_inicio + 1, 
		TO_CHAR(fecha_inicio + 1, '%Y%m%d'),
		NVL(fecha_desactivac, 0),
		NVL(TO_CHAR(fecha_desactivac, '%Y%m%d'), '99991231')
		FROM club_barrio
		WHERE numero_cliente = ?
		AND ( ( ? BETWEEN fecha_inicio AND fecha_desactivac )
			 OR
			 (fecha_inicio >= ?))		
		ORDER BY 2 ASC ";
		
	$DECLARE curBarrio CURSOR FOR selBarrio;
      
   /***** Updates registros ******/
	/************ Update Clientes Migra VIP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_vip = 'S', ");
   strcat(sql, "flag_vip = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagVip FROM $sql;

	/************ Update Clientes Migra TIS **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "operando_tis = 'S', ");
   strcat(sql, "flag_tis = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagTis FROM $sql;

	/************ Update Flag Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "flag_tap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFlagTasa FROM $sql;

	/************ Update Factor Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "factor_tap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFactorTasa FROM $sql;

	/************ Update Precio Tasa **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "qptap = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updQTasa FROM $sql;

	/************ Update EBP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "flag_ebp = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updEbp FROM $sql;

	/************ Update FP **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "qcontador = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updFp FROM $sql;
         
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
short LeoCliente(regCli)
$ClsCliente *regCli;
{

   InicializaCliente(regCli);

	$FETCH curClientes INTO
      :regCli->numero_cliente,
      :regCli->corr_facturacion,
      :regCli->tarifa; 

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
   memset(regCli->tarifa, '\0', sizeof(regCli->tarifa));
}

void getPrimaLectura(lNroCliente, lFechaLectura)
$long lNroCliente;
$long *lFechaLectura;
{
   $long lFechaAux;
   
   $EXECUTE selPrimaLectura INTO :lFechaAux
      USING :lNroCliente;
      
   if(SQLCODE != 0){
      printf("No se pudo cargar primera lectura para cliente %ld.\n", lNroCliente);
      return;
   }

   *lFechaLectura = lFechaAux;
}


short LeoConsumos(reg)
$ClsConsuBim *reg;
{
	int     iTieneAju;
	$double consuAjuP1;
	$double consuAjuP2;
	$double consuAjuBim;
	$int corrFactuAux;
	
	iTieneAju=0;
	rsetnull(CINTTYPE, (char *) &(consuAjuP1)); 
	rsetnull(CINTTYPE, (char *) &(consuAjuP2)); 
	rsetnull(CINTTYPE, (char *) &(consuAjuBim)); 
	
	InicializaConsumo(reg);
	
	$FETCH curConsuBim INTO
		:reg->numero_cliente,
		:reg->corr_fact_ant,
		:reg->corr_facturacion,
		:reg->tipo_lectura,
		:reg->tarifa,
		:reg->fecha_lectura_ant,
		:reg->fecha_lectu_cierre,
		:reg->cant_dias,
		:reg->consumo_activa_p1,
		:reg->consumo_activa_p2,
		:reg->consumo_activa,
		:reg->lectura_ant,
		:reg->lectura_cierre,
		:reg->cons_reactiva,
		:reg->numero_medidor,
		:reg->marca_medidor,
		:reg->tipo_medidor;	
	
   if(SQLCODE != 0){
      return 0;
   }

	/* Vemos si se ajusto el tramo 1 */
	corrFactuAux=reg->corr_fact_ant + 1;
	
	$EXECUTE selRefac INTO :consuAjuP1 USING :reg->numero_cliente, :corrFactuAux;

   if(SQLCODE != 0){
      printf("Error al buscar ajuste cliente %ld correlativo %d\n", reg->numero_cliente, corrFactuAux);
   }else{
		if( consuAjuP1 != 0.00){
			reg->consumo_activa_p1 += consuAjuP1;
			iTieneAju=1;
		}
	}

	/* Vemos si se ajusto el tramo 2 */
	corrFactuAux=reg->corr_facturacion + 1;
	
	$EXECUTE selRefac INTO :consuAjuP2 USING :reg->numero_cliente, :corrFactuAux;

   if(SQLCODE != 0){
      printf("Error al buscar ajuste cliente %ld correlativo %d\n", reg->numero_cliente, corrFactuAux);
   }else{
		if( consuAjuP2 != 0.00){
			reg->consumo_activa_p2 += consuAjuP2;
			iTieneAju=1;
		}
	}	
	
	if(iTieneAju == 1){
		reg->consumo_activa = reg->consumo_activa_p1 + reg->consumo_activa_p2;
	}
	
	return 1;
}

void InicializaConsumo(reg)
$ClsConsuBim *reg;
{
	
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_fact_ant)); 
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion)); 
	rsetnull(CINTTYPE, (char *) &(reg->tipo_lectura));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
	rsetnull(CLONGTYPE, (char *) &(reg->fecha_lectura_ant)); 
	rsetnull(CLONGTYPE, (char *) &(reg->fecha_lectu_cierre)); 
	rsetnull(CINTTYPE, (char *) &(reg->cant_dias));
	rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_activa_p1));
	rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_activa_p2));
	rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_activa));
	rsetnull(CDOUBLETYPE, (char *) &(reg->lectura_ant));
	rsetnull(CDOUBLETYPE, (char *) &(reg->lectura_cierre));
	rsetnull(CDOUBLETYPE, (char *) &(reg->cons_reactiva));
	rsetnull(CLONGTYPE, (char *) &(reg->numero_medidor)); 
	memset(reg->marca_medidor, '\0', sizeof(reg->marca_medidor));
	memset(reg->tipo_medidor, '\0', sizeof(reg->tipo_medidor));
	
}

short LeoFactura(reg)
$ClsFactura *reg;
{
   $long lCorrFactuFP;
   
   InicializaFactura(reg);
   
   $FETCH curFactura INTO
      :reg->numero_cliente, 
      :reg->corr_facturacion, 
      :reg->consumo_sum, 
      :reg->tarifa,
      :reg->indica_refact,
      :reg->fdesde, 
      :reg->fhasta,
      :reg->difdias,
      :reg->cons_61,
      :reg->fecha_facturacion,
      :reg->numero_factura,
      :reg->tipo_lectura,
      :reg->tipo_medidor,
      :reg->porcion,
      :reg->ul,
      :reg->cosenoPhi,
      :reg->consumo_sum2,
      :reg->lectura_activa;

   if(SQLCODE != 0){
      return 0;
   }

   if(reg->consumo_sum <0){
      lCorrFactuFP=reg->corr_facturacion - 1;
      $EXECUTE selFpLectu INTO :reg->consumo_sum USING :reg->numero_cliente, :lCorrFactuFP;
      if(SQLCODE != 0){
         if(SQLCODE==100){
            if(reg->tarifa[2]=='B'){
               reg->consumo_sum=reg->consumo_sum2;
            }else{
               reg->consumo_sum=reg->lectura_activa;            
            }
         }else{
            printf("Error al buscar FP_LECTU para cliente %ld correlativo %d\n", reg->numero_cliente, lCorrFactuFP);
         }   
      }
      reg->cons_61 = ((reg->consumo_sum / reg->difdias) * 61); 
   }

   /* Actualiza con los ajustes */
   if(reg->indica_refact[0]== 'S'){
      if(reg->tipo_medidor[0]=='R'){
         if(!getConsuReactiva(reg)){
            printf("No se encontró consumo reactiva para cliente %ld correlativo %d\n", reg->numero_cliente, reg->corr_facturacion);                           
         }
      }
      /* Actualizar el consumo_sum con los refac */
      $OPEN curRefac USING :reg->numero_cliente, :reg->numero_factura, :reg->fecha_facturacion;
      
      while(LeoRefac(reg)){
         /* Reevalua el consumo_sum */
      }
      
      $CLOSE curRefac;
   }

   
   return 1;
}

void InicializaFactura(reg)
$ClsFactura    *reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum)); 
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->indica_refact, '\0', sizeof(reg->indica_refact));
   rsetnull(CLONGTYPE, (char *) &(reg->fdesde)); 
   rsetnull(CLONGTYPE, (char *) &(reg->fhasta));
   rsetnull(CINTTYPE, (char *) &(reg->difdias));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cons_61));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->numero_factura));
   rsetnull(CINTTYPE, (char *) &(reg->tipo_lectura));
   memset(reg->tipo_medidor, '\0', sizeof(reg->tipo_medidor));
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum_reactiva));
   memset(reg->porcion, '\0', sizeof(reg->porcion));
   memset(reg->ul, '\0', sizeof(reg->ul));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cosenoPhi));
   memset(reg->leyendaPhi, '\0', sizeof(reg->leyendaPhi));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaEvento));
   memset(reg->sFechaEvento, '\0', sizeof(reg->sFechaEvento));
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum2));
   rsetnull(CLONGTYPE, (char *) &(reg->lectura_activa));
}


short LeoAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{
   InicializaAhorro(regAhorro);
   
   $FETCH curAhorro INTO
      :regAhorro->numero_cliente,
      :regAhorro->corr_fact_act,
      :regAhorro->lFechaInicio,
      :regAhorro->sFechaInicio,
      :regAhorro->lFechaFin,
      :regAhorro->sFechaFin,
      :regAhorro->consumo_61dias_act,
      :regAhorro->dias_per_act;

   if(SQLCODE != 0){
      return 0;
   }

   return 1;
}

void InicializaAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{

   rsetnull(CLONGTYPE, (char *) &(regAhorro->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regAhorro->corr_fact_act));
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaInicio));
   memset(regAhorro->sFechaInicio, '\0', sizeof(regAhorro->sFechaInicio)); 
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaFin));
   memset(regAhorro->sFechaFin, '\0', sizeof(regAhorro->sFechaFin));
   rsetnull(CDOUBLETYPE, (char *) &(regAhorro->consumo_61dias_act));
   rsetnull(CINTTYPE, (char *) &(regAhorro->dias_per_act));

}

short LeoRefac(reg)
$ClsFactura *reg;
{
   $double  kwhRefac=0.00;
   $double  kwhRefacReac=0.00;
   
   $FETCH curRefac INTO :kwhRefac, :kwhRefacReac;
   
   if(SQLCODE != 0){
      return 0;
   }

   if(!risnull(CDOUBLETYPE, (char *) &kwhRefac))
      reg->consumo_sum += kwhRefac;
   
   if(!risnull(CDOUBLETYPE, (char *) &kwhRefacReac))
      reg->consumo_sum_reactiva += kwhRefacReac;
   
   reg->cons_61 = (reg->consumo_sum / reg->difdias) * 61;
   
   return 1;
}

void  TraspasoDatos(iMarca, regClie, lFechaAlta, regAhorro, regFact)
int            iMarca;
ClsCliente     regClie;
long           lFechaAlta;
ClsAhorroHist  regAhorro;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);

   rfmtdate(lFechaAlta, "yyyymmdd", sAux);

   regFact->numero_cliente = regAhorro.numero_cliente;
   if(iMarca == 1){
      regFact->corr_facturacion = regAhorro.corr_fact_act;
   }else{
      regFact->corr_facturacion = regAhorro.corr_fact_act + 1;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   if(iMarca == 1){
      strcpy(regFact->operand, "QCONSBIMES");
   }else{
      strcpy(regFact->operand, "FADIASPC");
   }
   
   /* AB */
   strcpy(regFact->ab, regAhorro.sFechaInicio);
   
   /* BIS2 */
   strcpy(regFact->bis2, regAhorro.sFechaFin);
   
   /* LMENGE */
   if(iMarca == 1){
      sprintf(regFact->lmenge, "%.0lf", regAhorro.consumo_61dias_act);
   }else if(iMarca==2){
      sprintf(regFact->lmenge, "%ld", regAhorro.dias_per_act);
   }
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}


void  TraspasoDatosFactu(iMarca, regClie, regFactu, regFact)
int            iMarca;
ClsCliente     regClie;
ClsFactura  regFactu;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);


   regFact->numero_cliente = regFactu.numero_cliente;
   if(iMarca == 2 ){
      regFact->corr_facturacion = regFactu.corr_facturacion + 1;
   }else{
      regFact->corr_facturacion = regFactu.corr_facturacion;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   switch(iMarca){
      case 1:
         strcpy(regFact->operand, "QCONSBIMES");
         break;
      case 2:
         strcpy(regFact->operand, "FADIASPC");
         break;
      case 3:
         strcpy(regFact->operand, "QCONBFPACT");
         break;
      case 4:
         strcpy(regFact->operand, "QCONBFPREAC");
         break;
      case 5:
         strcpy(regFact->operand, "QCONTADOR");
         break;
   }
   
   /* AB */
   if(iMarca==5){
      strcpy(regFact->ab, regFactu.sFechaEvento);
   }else{
      rfmtdate(regFactu.fdesde, "yyyymmdd", regFact->ab);
   }
   
   /* BIS2 */
   if(iMarca==5){
      strcpy(regFact->bis2, "99991231");
   }else{
      rfmtdate(regFactu.fhasta, "yyyymmdd", regFact->bis2);
   }
   
      
   /* LMENGE */
   switch(iMarca){
      case 1:
         sprintf(regFact->lmenge, "%.0lf", regFactu.cons_61);
         break;
      case 2:
         sprintf(regFact->lmenge, "%ld", regFactu.difdias);
         break;
      case 3:
         if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
            strcpy(regFact->lmenge, "0");
         }else{
            sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum);
         }
         break;
      case 4:
         if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
            strcpy(regFact->lmenge, "0");
         }else{
            sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum_reactiva);
         }
         break;
      case 5:
         alltrim(regFactu.leyendaPhi, ' ');
         sprintf(regFact->lmenge, "%s", regFactu.leyendaPhi);
         break;
   }
   
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}


void  TraspasoDatosConsu(iMarca, regClie, regConsu, regFact)
int            iMarca;
ClsCliente     regClie;
ClsConsuBim    regConsu;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);


   regFact->numero_cliente = regConsu.numero_cliente;
   if(iMarca == 2 ){
      regFact->corr_facturacion = regConsu.corr_facturacion + 1;
   }else{
      regFact->corr_facturacion = regConsu.corr_facturacion;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   switch(iMarca){
      case 1:
         strcpy(regFact->operand, "QCONSBIMES");
         break;
      case 2:
         strcpy(regFact->operand, "FADIASPC");
         break;
   }
   
   /* AB */
   rfmtdate(regConsu.fecha_lectura_ant, "yyyymmdd", regFact->ab);

   
   /* BIS2 */
   rfmtdate(regConsu.fecha_lectu_cierre, "yyyymmdd", regFact->bis2);

   
      
   /* LMENGE */
   switch(iMarca){
      case 1:
         sprintf(regFact->lmenge, "%.0lf", regConsu.consumo_activa);
         break;
      case 2:
         sprintf(regFact->lmenge, "%ld", regConsu.cant_dias);
         break;
   }
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}


void InicializaOperandos(regFact)
ClsFacts *regFact;
{

   memset(regFact->anlage, '\0', sizeof(regFact->anlage));
   memset(regFact->bis1, '\0', sizeof(regFact->bis1));
   memset(regFact->auto_inser, '\0', sizeof(regFact->auto_inser));
   memset(regFact->operand, '\0', sizeof(regFact->operand));
   memset(regFact->ab, '\0', sizeof(regFact->ab));
   memset(regFact->bis2, '\0', sizeof(regFact->bis2));
   memset(regFact->lmenge, '\0', sizeof(regFact->lmenge));
   memset(regFact->tarifart, '\0', sizeof(regFact->tarifart));
   memset(regFact->kondigr, '\0', sizeof(regFact->kondigr));
   rsetnull(CDOUBLETYPE, (char *) &(regFact->valorReal));   

}

short ClienteYaMigrado(nroCliente, lFechaInicio, iFlagMigra)
$long	nroCliente;
$long *lFechaInicio;
int		*iFlagMigra;
{
   $long lFecha;
	$char	sMarca[2];
/*	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}
*/	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca, :lFecha using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("Error al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
      if(gsTipoGenera[0]=='G'){	
		    /*return 1;*/
      }
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
   *lFechaInicio = lFecha;

	return 0;
}


void GenerarPlanos(fpSalida, iMarca, regFact, iOcurr)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
int      iOcurr;
{


   if(iOcurr==1){
      GeneraCuerpo(fpSalida, iMarca, regFact);
   }

   GeneraPie(fpSalida, iMarca, regFact);

}

void GeneraKey3(fpSalida, lNroCliente)
FILE     *fpSalida;
long     lNroCliente;
{
	char	sLinea[1000];	
   int   iRcv;
       
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   sprintf(sLinea, "T1%ld\tKEY\t", lNroCliente);
   
   /* ANLAGE */
   sprintf(sLinea, "%sT1%ld\t", sLinea, lNroCliente);

   /* BIS1 */
   strcat(sLinea, "99990101");
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KEY\n");
      exit(1);
   }	

}

void GeneraKey(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   char  sMarca[3];
   int   iRcv;
       
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));

   switch(iMarca){
      case 1:
      case 3:
      case 4:
         strcpy(sMarca, "QC");
         break;
      case 2:
         strcpy(sMarca, "FP");
         break;
      case 5:
         strcpy(sMarca, "FV");
         break;
      case 6:
         strcpy(sMarca, "FT");
         break;
      case 7:
         strcpy(sMarca, "FA");
         break;
      case 8:
         strcpy(sMarca, "FF");
         break;
      case 9:
         strcpy(sMarca, "QT");
         break;
      case 10:
         strcpy(sMarca, "FE");
         break;
      case 11:
         strcpy(sMarca, "QF");
         break;
      case 12:
         strcpy(sMarca, "FS");
         break;
         
   }

   /* llave */
   /*sprintf(sLinea, "T1%ld-%ld%s\tKEY\t", regFact.numero_cliente, regFact.corr_facturacion, sMarca);*/
   sprintf(sLinea, "T1%ld-%s\tKEY\t", regFact.numero_cliente, sMarca);
   
   /* ANLAGE */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.anlage);

   /* BIS1 */
   sprintf(sLinea, "%s%s", sLinea, regFact.bis1);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KEY\n");
      exit(1);
   }	


}

void GeneraCuerpo(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
      case 1:
      case 3:
      case 4:
         /*sprintf(sLinea, "T1%ld-%ldQC\tF_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);*/
         /*sprintf(sLinea, "T1%ld-QC\tF_QUAN\t", regFact.numero_cliente );*/
         sprintf(sLinea, "T1%ld\tF_QUAN\t", regFact.numero_cliente );
         break;
      case 2:
         /*sprintf(sLinea, "T1%ld-%ldFP\tF_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);*/
         /*sprintf(sLinea, "T1%ld-FP\tF_FACT\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FACT\t", regFact.numero_cliente);
         break;
      case 5:
         /*sprintf(sLinea, "T1%ld-FV\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;
      case 6:
         /*sprintf(sLinea, "T1%ld-FT\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;
      case 7:
         /*sprintf(sLinea, "T1%ld-FA\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;
      case 8:
         /*sprintf(sLinea, "T1%ld-FF\tF_FACT\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FACT\t", regFact.numero_cliente);
         break;
      case 9:
         /*sprintf(sLinea, "T1%ld-QT\tF_QPRI\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_QPRI\t", regFact.numero_cliente);
         break;
      case 10:
         /*sprintf(sLinea, "T1%ld-FE\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;
      case 11:
         /*sprintf(sLinea, "T1%ld-QF\tF_QUAN\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_QUAN\t", regFact.numero_cliente);
         break;
      case 12:
         /*sprintf(sLinea, "T1%ld-FS\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;
      case 13:
         /*sprintf(sLinea, "T1%ld-FS\tF_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tF_FLAG\t", regFact.numero_cliente);
         break;         
         
   }

   /* OPERAND */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.operand);

   /* AUTO_INSER */
   sprintf(sLinea, "%s%s", sLinea, regFact.auto_inser);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir Cuerpo\n");
      exit(1);
   }	

}

void GeneraPie(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
      case 1:
      case 3:
      case 4:
         /*sprintf(sLinea, "T1%ld-%ldQC\tV_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);*/
         /*sprintf(sLinea, "T1%ld-QC\tV_QUAN\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_QUAN\t", regFact.numero_cliente);
         break;
      case 2:
         /*sprintf(sLinea, "T1%ld-%ldFP\tV_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);*/
         /*sprintf(sLinea, "T1%ld-FP\tV_FACT\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FACT\t", regFact.numero_cliente);
         break;
      case 5:
         /*sprintf(sLinea, "T1%ld-FV\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;
      case 6:
         /*sprintf(sLinea, "T1%ld-FT\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;
      case 7:
         /*sprintf(sLinea, "T1%ld-FA\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;
      case 8:
         /*sprintf(sLinea, "T1%ld-FF\tV_FACT\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FACT\t", regFact.numero_cliente);
         break;
      case 9:
         /*sprintf(sLinea, "T1%ld-QT\tV_QPRI\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_QPRI\t", regFact.numero_cliente);
         break;
      case 10:
         /*sprintf(sLinea, "T1%ld-FE\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;
      case 11:
         /*sprintf(sLinea, "T1%ld-QF\tV_QUAN\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_QUAN\t", regFact.numero_cliente);
         break;
      case 12:
         /*sprintf(sLinea, "T1%ld-FS\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;
      case 13:
         /*sprintf(sLinea, "T1%ld-FS\tV_FLAG\t", regFact.numero_cliente);*/
         sprintf(sLinea, "T1%ld\tV_FLAG\t", regFact.numero_cliente);
         break;      
   }
   
   /* AB */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.ab);
   
   /* BIS2 */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.bis2);
   
   /* LMENGE */
   if(iMarca!= 8 && iMarca !=9)
      sprintf(sLinea, "%s%s\t", sLinea, regFact.lmenge);

   switch(iMarca){
      case 1:
      case 2:
      case 3:
      case 4:
      case 11:
         /* TARIFART */
         sprintf(sLinea, "%s%s\t", sLinea, regFact.tarifart);
         
         /* KONDIGR */
         sprintf(sLinea, "%s%s", sLinea, regFact.kondigr);
         break;
      case 5:
      case 6:
      case 7:
      case 10:
      case 12:
      case 13:
         /* TARIFART + KONDRIG */
         strcat(sLinea, "\t");
         break;
      case 8:
         /* el valor del factor de la tasa */
         sprintf(sLinea, "%s%.02f", sLinea, regFact.valorReal);
         break;          
      case 9:
         /* el valor del precio codificado */
         sprintf(sLinea, "%s%s\t", sLinea, regFact.tarifart);
         break;          
                   
   }   

   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir Pie\n");
      exit(1);
   }	

}


void GeneraENDE(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   char  sMarca[3];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));
   
   switch(iMarca){
      case 1:
      case 3:
      case 4:
      case 5:
         strcpy(sMarca, "QC");
         break;
      case 2:
         strcpy(sMarca, "FP");
         break;
   }
	
   sprintf(sLinea, "T1%ld-%ld%s\t&ENDE", regFact.numero_cliente, regFact.corr_facturacion, sMarca);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
   	
}

void GeneraENDE2(fpSalida, iMarca, lNroCliente)
FILE     *fpSalida;
int      iMarca;
long     lNroCliente;
{
	char	sLinea[1000];
   char  sMarca[3];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));
   
   switch(iMarca){
      case 1:
      case 3:
      case 4:
         strcpy(sMarca, "QC");
         break;
      case 2:
         strcpy(sMarca, "FP");
         break;
      case 5:
         strcpy(sMarca, "FV");
         break;
      case 6:
         strcpy(sMarca, "FT");
         break;
      case 7:
         strcpy(sMarca, "FA");
         break;
      case 8:
         strcpy(sMarca, "FF");
         break;
      case 9:
         strcpy(sMarca, "QT");
         break;
      case 10:
         strcpy(sMarca, "FE");
         break;
      case 11:
         strcpy(sMarca, "QF");
         break;
      case 12:
         strcpy(sMarca, "FS");
         break;
         
   }
	
   sprintf(sLinea, "T1%ld-%s\t&ENDE", lNroCliente, sMarca);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
   	
}

void GeneraENDE3(fpSalida, lNroCliente)
FILE     *fpSalida;
long     lNroCliente;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
   
   sprintf(sLinea, "T1%ld\t&ENDE", lNroCliente);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fpSalida, sLinea);
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
		strcpy(sTipoArchivo, "FACTSBIM");
		strcpy(sNombreArchivo, sArchQConsBimesUnx);
      
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
short RegistraCliente(nroCliente, cantConsu, cantActi, iFlagMigra)
$long	nroCliente;
$long  cantConsu;
$long  cantActi;
int		iFlagMigra;
{
	
	if(iFlagMigra==1){
		$EXECUTE insClientesMigra using :nroCliente, :cantConsu, :cantConsu, :cantActi;
	}else{
		$EXECUTE updClientesMigra using :cantConsu, :cantConsu, :cantActi, :nroCliente;
	}

	return 1;
}

short getConsuReactiva(reg)
$ClsFactura *reg;
{
   $long lCorrFactuFP;
   
   $EXECUTE selConsuReac INTO :reg->consumo_sum_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;
      
   if(SQLCODE != 0){
      return 0;
   }
   
   if(reg->consumo_sum_reactiva <0){
      lCorrFactuFP=reg->corr_facturacion - 1;
      
      $EXECUTE selFpLectuReac INTO :reg->consumo_sum_reactiva
         USING :reg->numero_cliente,
               :lCorrFactuFP;

      if(SQLCODE !=0){
         $EXECUTE selLectuReac INTO :reg->consumo_sum_reactiva
            USING :reg->numero_cliente,
                  :reg->corr_facturacion;
                  
         if(SQLCODE !=0){
            printf("No se encontró consumo reactiva para cliente %ld correlativo %ld\n", reg->numero_cliente, reg->corr_facturacion);
         }
      }

   }
   return 1;
}

short getLectuReactiva(reg)
$ClsFactura *reg;
{

   $EXECUTE selLectuReac INTO :reg->lectura_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;

   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

short getLectuReactivaRefac(reg)
$ClsFactura *reg;
{

   $EXECUTE selLectuReacRefac INTO :reg->lectura_reactiva
      USING :reg->numero_cliente,
            :reg->corr_facturacion;

   if(SQLCODE != 0){
      $EXECUTE selLectuReac INTO :reg->lectura_reactiva
         USING :reg->numero_cliente,
               :reg->corr_facturacion;
               
      if(SQLCODE != 0){
         return 0;
      }
   }

   return 1;
}

short getIniVentanaAgenda(reg)
$ClsFactura *reg;
{
   $long lFecha;
   
   rsetnull(CLONGTYPE, (char *) &(lFecha));
   
   $EXECUTE selIniVentana1 INTO :lFecha
      USING :reg->porcion,
            :reg->ul,
            :reg->fdesde;
            
   if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
      $EXECUTE selIniVentana2 INTO :lFecha
         USING :reg->porcion,
               :reg->ul,
               :reg->fdesde;
   
      if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
         return 0;
      }
   }            

   reg->fdesde = lFecha;
   
   return 1;
}

short getLeyenda(reg, lValTarifa)
$ClsFactura *reg;
$long       lValTarifa;
{

   $EXECUTE selLeyenda INTO :reg->leyendaPhi,
                            :reg->lFechaEvento;
                            
   if(SQLCODE != 0){
      return 0;
   }

   if(reg->lFechaEvento < lValTarifa)
      reg->lFechaEvento = lValTarifa;
      
   rfmtdate(reg->lFechaEvento, "yyyymmdd", reg->sFechaEvento); /* long to char */   

   return 1;
}


void InicializaVectorConsumos(reg)
ClsConsuBim **reg;
{
	if(*reg != NULL)
		free(*reg);
		
	*reg = (ClsConsuBim *) malloc (sizeof(ClsConsuBim));
	if(*reg == NULL){
		printf("Fallo Malloc InicializaVectorConsumos().\n");
	}	
}

void InicializaVectorFacturas(reg)
ClsFactura **reg;
{
	if(*reg != NULL)
		free(*reg);
		
	*reg = (ClsFactura *) malloc (sizeof(ClsFactura));
	if(*reg == NULL){
		printf("Fallo Malloc InicializaVectorFacturas().\n");
	}
}


void CargaVectorConsumos(regConsu, index, vec)
ClsConsuBim  regConsu;
int         index;
ClsConsuBim  **vec;
{
   ClsConsuBim	*regAux=NULL;
   ClsConsuBim  reg;
   
	regAux = (ClsConsuBim*) realloc(*vec, sizeof(ClsConsuBim) * (++index) );
	if(regAux == NULL){
		printf("Fallo Realloc CargaVectorConsumos().\n");
	}		
	
	(*vec) = regAux;

   (*vec)[index-1].numero_cliente = regConsu.numero_cliente;
   (*vec)[index-1].corr_fact_ant = regConsu.corr_fact_ant;   
   (*vec)[index-1].corr_facturacion = regConsu.corr_facturacion;   
   (*vec)[index-1].tipo_lectura = regConsu.tipo_lectura;
   strcpy((*vec)[index-1].tarifa, regConsu.tarifa ); 
   (*vec)[index-1].fecha_lectura_ant = regConsu.fecha_lectura_ant;
   (*vec)[index-1].fecha_lectu_cierre = regConsu.fecha_lectu_cierre;
   (*vec)[index-1].cant_dias = regConsu.cant_dias;
   (*vec)[index-1].consumo_activa_p1 = regConsu.consumo_activa_p1;
   (*vec)[index-1].consumo_activa_p2 = regConsu.consumo_activa_p2;
   (*vec)[index-1].consumo_activa = regConsu.consumo_activa;
   (*vec)[index-1].lectura_ant = regConsu.lectura_ant;
   (*vec)[index-1].lectura_cierre = regConsu.lectura_cierre;   
   (*vec)[index-1].cons_reactiva = regConsu.cons_reactiva;
   (*vec)[index-1].numero_medidor = regConsu.numero_medidor;   
   strcpy((*vec)[index-1].marca_medidor, regConsu.marca_medidor ); 
   strcpy((*vec)[index-1].tipo_medidor, regConsu.tipo_medidor ); 

}




void CargaVectorFacturas(regFactu, index, vec)
ClsFactura  regFactu;
int         index;
ClsFactura  **vec;
{
   ClsFactura	*regAux=NULL;
   ClsFactura  reg;
   
	regAux = (ClsFactura*) realloc(*vec, sizeof(ClsFactura) * (++index) );
	if(regAux == NULL){
		printf("Fallo Realloc CargaVectorFacturas().\n");
	}		
	
	(*vec) = regAux;

   (*vec)[index-1].numero_cliente = regFactu.numero_cliente;
   (*vec)[index-1].corr_facturacion = regFactu.corr_facturacion;   
   (*vec)[index-1].consumo_sum = regFactu.consumo_sum;
   strcpy((*vec)[index-1].tarifa, regFactu.tarifa ); 
   strcpy((*vec)[index-1].indica_refact, regFactu.indica_refact ); 
   (*vec)[index-1].fdesde = regFactu.fdesde;
   (*vec)[index-1].fhasta = regFactu.fhasta;
   (*vec)[index-1].difdias = regFactu.difdias; 
   (*vec)[index-1].cons_61 = regFactu.cons_61;
   (*vec)[index-1].fecha_facturacion = regFactu.fecha_facturacion;
   (*vec)[index-1].numero_factura = regFactu.numero_factura;
   (*vec)[index-1].tipo_lectura = regFactu.tipo_lectura;
   strcpy((*vec)[index-1].tipo_medidor, regFactu.tipo_medidor );   
   strcpy((*vec)[index-1].porcion, regFactu.porcion );
   strcpy((*vec)[index-1].ul, regFactu.ul );
   (*vec)[index-1].consumo_sum_reactiva = regFactu.consumo_sum_reactiva;
   (*vec)[index-1].lectura_reactiva = regFactu.lectura_reactiva;
   (*vec)[index-1].cosenoPhi = regFactu.cosenoPhi;
   strcpy((*vec)[index-1].leyendaPhi, regFactu.leyendaPhi );
   (*vec)[index-1].lFechaEvento = regFactu.lFechaEvento;
   strcpy((*vec)[index-1].sFechaEvento, regFactu.sFechaEvento );
   (*vec)[index-1].consumo_sum2 = regFactu.consumo_sum2;
   (*vec)[index-1].lectura_activa = regFactu.lectura_activa;

}

short ProcesaElectro(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsElectro reg;
   ClsFacts    regF;
   long iFilas=0;
   long lFechaAux;
   
   $OPEN curElectro USING :nroCliente, :lFechaInicio, :lFechaInicio;
   
   while(LeoElectro(&reg)){
      iFilas++;
      
      TraspasoDatosElectro(iFilas, reg, &regF);
      /*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
      if(iFilas==1 && (reg.lFechaActivacion < lFechaInicio)){
			lFechaAux = lFechaInicio+1;
			rfmtdate(lFechaAux, "yyyymmdd", regF.ab);
		}
      GenerarPlanos(fpOperandos, 5, regF, iFilas);
   }
   
   $CLOSE curElectro;

   if(iFilas>0){
      /*GeneraENDE2(fpOperandos, 5, nroCliente);*/
   }else{
      return 0;
   }
   
   *lFilas+=iFilas;
   
   return 1;
}

short LeoElectro(reg)
$ClsElectro *reg;
{
   InicializaElectro(reg);
   
   $FETCH curElectro INTO 
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->lFechaDesactivac,
      :reg->sFechaDesactivac,
      :reg->motivo,
      :reg->corr_facturacion,
      :reg->nro_beneficiario;
      
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         printf("Error al leer cursor de ElectroDependientes.\n");
      }
      return 0;   
   }
      
   return 1;
}

void InicializaElectro(reg)
$ClsElectro *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaActivacion));   
   memset(reg->sFechaActivacion, '\0', sizeof(reg->sFechaActivacion));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaDesactivac));
   memset(reg->sFechaDesactivac, '\0', sizeof(reg->sFechaDesactivac));
   memset(reg->motivo, '\0', sizeof(reg->motivo));
   rsetnull(CLONGTYPE, (char *) &(reg->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->nro_beneficiario)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->valorReal));
}

void TraspasoDatosElectro(iFilas, reg, regF)
int iFilas;
ClsElectro reg;
$ClsFacts *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "FLAGVIP");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, reg.sFechaActivacion);
   strcpy(regF->bis2, reg.sFechaDesactivac);
   strcpy(regF->lmenge, "X");
}

short RegistraClienteFLAG(sOpe, nroCliente, cantidad, iModo)
char  *sOpe;
$long nroCliente;
$int  cantidad;
int   iModo;
{

	if(strcmp(sOpe, "VIP")==0){
   	$EXECUTE updFlagVip using :cantidad, :nroCliente;
   }
   
	if(strcmp(sOpe, "TIS")==0){
		$EXECUTE updFlagTis using :cantidad, :nroCliente;
	}

   if(strcmp(sOpe, "TASAFF")==0){
		$EXECUTE updFlagTasa using :cantidad, :nroCliente;
      $EXECUTE updFactorTasa using :cantidad, :nroCliente;
   }

   if(strcmp(sOpe, "QTASA")==0){
		$EXECUTE updQTasa using :cantidad, :nroCliente;
   }

   if(strcmp(sOpe, "EBP")==0){
		$EXECUTE updEbp using :cantidad, :nroCliente;
   }

   if(strcmp(sOpe, "FP")==0){
		$EXECUTE updFp using :cantidad, :nroCliente;
   }
   
	return 1;
}

short ProcesaTarSoc(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsElectro reg;
   ClsFacts    regF;
   long iFilas=0;
   long lFechaAux;
   
   $OPEN curTarifaSocial USING :nroCliente, :lFechaInicio, :lFechaInicio;
   
   while(LeoTarifaSocial(&reg)){
      iFilas++;
      InicializaOperandos(&regF);
      TraspasoDatosTarSoc(iFilas, reg, &regF);
      /*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
      if(iFilas == 1 && reg.lFechaActivacion < lFechaInicio){
			lFechaAux=lFechaInicio+1;
			rfmtdate(lFechaAux, "yyyymmdd", regF.ab);
		}
      GenerarPlanos(fpOperandos, 6, regF, iFilas);
   }
   
   $CLOSE curTarifaSocial;

   if(iFilas>0){
      /*GeneraENDE2(fpOperandos, 6, nroCliente);*/
   }else{
      return 0;
   }
   
   *lFilas+=iFilas;
   
   return 1;
}

short LeoTarifaSocial(reg)
$ClsElectro *reg;
{
   InicializaElectro(reg);
   
   $FETCH curTarifaSocial INTO 
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->lFechaDesactivac,
      :reg->sFechaDesactivac,
      :reg->motivo,
      :reg->corr_facturacion,
      :reg->nro_beneficiario;
      
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         printf("Error al leer cursor de Tarifa Social.\n");
      }
      return 0;   
   }
      
   return 1;
}


void TraspasoDatosTarSoc(iFilas, reg, regF)
int iFilas;
ClsElectro reg;
$ClsFacts *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "FLAGTIS");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, reg.sFechaActivacion);
   strcpy(regF->bis2, reg.sFechaDesactivac);
   strcpy(regF->lmenge, "X");
}

short LeoClub(reg)
$ClsElectro *reg;
{
   InicializaElectro(reg);
   
   $FETCH curBarrio INTO 
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->lFechaDesactivac,
      :reg->sFechaDesactivac;
      
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         printf("Error al leer cursor de Club de Barrio.\n");
      }
      return 0;   
   }
      
   return 1;
}

void TraspasoDatosClub(iFilas, reg, regF)
int iFilas;
ClsElectro reg;
$ClsFacts *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "FLAGCLUB");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, reg.sFechaActivacion);
   strcpy(regF->bis2, reg.sFechaDesactivac);
   strcpy(regF->lmenge, "X");
}

short ProcesaTasas(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsElectro    reg;
   $ClsFacts      regF;
   $ClsPrecioTasa regP;
   
   long  iTieneFilas=0;
   int   iTieneTasa=0;
   int   index=1;
   int   iFila;
   long  lContador=0;
   long  lFechaDesde;
   double   dMonto;
   long  lFechaAux;
      
   InicializaVectorElectro(&(vecElectro));
   
   $OPEN curTasasVig USING :nroCliente, :lFechaInicio, :lFechaInicio;
   
   while(LeoTasasVig(&reg)){
      iTieneTasa=1;
      CargaVectorElectro(reg, index, &(vecElectro));
      index++;   
   }
   
   $CLOSE curTasasVig;
   
   if(iTieneTasa==1){
      rsetnull(CLONGTYPE, (char *) &(lFechaDesde));
      rsetnull(CDOUBLETYPE, (char *) &(dMonto));
      
      /* FLAG TAP */
      for(iFila=1; iFila < index; iFila++){
         InicializaOperandos(&regF);
         TraspasoDatosTasas1(vecElectro[iFila], &regF);
         if(iFila == 1){
				if(vecElectro[iFila].lFechaActivacion < lFechaInicio){
					lFechaAux=lFechaInicio+1;
					/*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
					rfmtdate(lFechaAux, "yyyymmdd", regF.ab);               
				}
			}
         
         GenerarPlanos(fpOperandos, 7, regF, iFila);
         lContador++;
         iTieneFilas=1;
      }
      if(iTieneFilas>0){
         /*GeneraENDE2(fpOperandos, 7, nroCliente);*/
      }

      /* FACTOR TAP */
      iTieneFilas=0;
      for(iFila=1; iFila < index; iFila++){
         InicializaOperandos(&regF);
         TraspasoDatosTasas2(vecElectro[iFila], &regF);
         if(vecElectro[iFila].lFechaActivacion < lFechaInicio){
				lFechaAux=lFechaInicio+1;
				/*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1); */
				rfmtdate(lFechaAux, "yyyymmdd", regF.ab);
			}
         GenerarPlanos(fpOperandos, 8, regF, iFila);
         lContador++;
         iTieneFilas=1;
      }
      
      if(iTieneFilas>0){
         /*GeneraENDE2(fpOperandos, 8, nroCliente);*/
      }
   
      /* QPTAP */
      $OPEN curPrecioTasa USING :nroCliente, :lFechaInicio;
      
      iTieneFilas=0;
      iFila=0;
      while(LeoPrecioTasa(&regP)){
         if(iFila==0){
            /*reservo datos para inicio de ciclo.*/
            lFechaDesde=regP.lFechaFactura + 1;
            dMonto=regP.valor;
         }else{
            /*cierro ciclo y genero lineas*/
            InicializaOperandos(&regF);
            TraspasoDatosTasas3(lFechaDesde, dMonto, regP, &regF);
            rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);
            GenerarPlanos(fpOperandos, 9, regF, iFila);
            lContador++;
            iTieneFilas=1;
            
            /*reservo datos para inicio de ciclo siguiente.*/
            lFechaDesde=regP.lFechaFactura + 1;
            dMonto=regP.valor;
         }
         iFila++;
      }
      $CLOSE curPrecioTasa;
      
      if(iTieneFilas>0){
         /*GeneraENDE2(fpOperandos, 9, nroCliente);*/
      }
   }else{
      return 0;
   }

   *lFilas += lContador;
   
   return 1;
}


short LeoTasasVig(reg)
$ClsElectro *reg;
{
   InicializaElectro(reg);
   
   $FETCH curTasasVig INTO 
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->sFechaDesactivac,
      :reg->valorReal;
      
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         printf("Error al leer cursor de Tasas Vigencia.\n");
      }
      return 0;   
   }
      
   return 1;
}

void InicializaVectorElectro(reg)
ClsElectro **reg;
{
	if(*reg != NULL)
		free(*reg);
		
	*reg = (ClsElectro *) malloc (sizeof(ClsElectro));
	if(*reg == NULL){
		printf("Fallo Malloc InicializaVectorElectro().\n");
	}
}


void CargaVectorElectro(regElectro, index, vec)
ClsElectro  regElectro;
int         index;
ClsElectro  **vec;
{
   ClsElectro	*regAux=NULL;
   ClsElectro  reg;
   
	regAux = (ClsElectro*) realloc(*vec, sizeof(ClsElectro) * (++index) );
	if(regAux == NULL){
		printf("Fallo Realloc CargaVectorElectro().\n");
	}		
	
	(*vec) = regAux;

   (*vec)[index-1].numero_cliente = regElectro.numero_cliente;
   (*vec)[index-1].lFechaActivacion = regElectro.lFechaActivacion;
   strcpy((*vec)[index-1].sFechaActivacion, regElectro.sFechaActivacion);
   strcpy((*vec)[index-1].sFechaDesactivac, regElectro.sFechaDesactivac);
   (*vec)[index-1].valorReal = regElectro.valorReal;   

}

void TraspasoDatosTasas1(regEle, regF)
ClsElectro  regEle;
ClsFacts    *regF;
{

   regF->numero_cliente = regEle.numero_cliente; 
   sprintf(regF->anlage, "%ld", regEle.numero_cliente);
   
   strcpy(regF->operand, "FLAGTAP");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, regEle.sFechaActivacion);
   strcpy(regF->bis2, regEle.sFechaDesactivac);
   strcpy(regF->lmenge, "X");

}

void TraspasoDatosTasas2(regEle, regF)
ClsElectro  regEle;
ClsFacts    *regF;
{

   regF->numero_cliente = regEle.numero_cliente; 
   sprintf(regF->anlage, "%ld", regEle.numero_cliente);
   
   strcpy(regF->operand, "FACTOR_TAP");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, regEle.sFechaActivacion);
   strcpy(regF->bis2, regEle.sFechaDesactivac);
   strcpy(regF->lmenge, "X");
   regF->valorReal = regEle.valorReal;

}

short LeoPrecioTasa(reg)
$ClsPrecioTasa *reg;
{

   InicializaPrecioTasa(reg);
   
   $FETCH curPrecioTasa INTO
      :reg->numero_cliente,
      :reg->corr_facturacion,
      :reg->lFechaFactura,
      :reg->lFechaTasa,
      :reg->valor,
      :reg->cod_mac,
      :reg->cod_sap;

   if(SQLCODE != 0){
      return 0;
   }
      
   return 1;
}

void InicializaPrecioTasa(reg)
$ClsPrecioTasa *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaFactura));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaTasa));
   rsetnull(CDOUBLETYPE, (char *) &(reg->valor));
   memset(reg->cod_mac, '\0', sizeof(reg->cod_mac));
   memset(reg->cod_sap, '\0', sizeof(reg->cod_sap));
}

void TraspasoDatosTasas3(lFechaDesde, dMonto, regP, regF)
long  lFechaDesde;
double   dMonto;
ClsPrecioTasa  regP;
ClsFacts       *regF;
{
   char  sFechaActivacion[9];
   char  sFechaDesactivac[9];
   
   memset(sFechaActivacion, '\0', sizeof(sFechaActivacion));
   memset(sFechaDesactivac, '\0', sizeof(sFechaDesactivac));
   alltrim(regP.cod_sap, ' ');
   
   lFechaDesde=lFechaDesde + 1;
   rfmtdate(lFechaDesde, "yyyymmdd", sFechaActivacion);
   
   rfmtdate(regP.lFechaFactura, "yyyymmdd", sFechaDesactivac);
   
   regF->numero_cliente = regP.numero_cliente; 
   sprintf(regF->anlage, "%ld", regP.numero_cliente);
   
   strcpy(regF->operand, "QPTAP");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, sFechaActivacion);
   strcpy(regF->bis2, sFechaDesactivac);
   strcpy(regF->lmenge, "X");
   regF->valorReal = regP.valor;
   strcpy(regF->tarifart, regP.cod_sap);

}

short ProcesaEBP(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsElectro reg;
   ClsFacts    regF;
   long iFilas=0;
   long lFechaAux;
   
   $OPEN curEBP USING :nroCliente, :lFechaInicio, :lFechaInicio;
   
   while(LeoEBP(&reg)){
      iFilas++;
      InicializaOperandos(&regF);
      TraspasoDatosEBP(iFilas, reg, &regF);
      /*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
      if(iFilas==1 && (reg.lFechaActivacion < lFechaInicio )){
			lFechaAux = lFechaInicio +1;
			rfmtdate(lFechaAux, "yyyymmdd", regF.ab);
		}
      GenerarPlanos(fpOperandos, 10, regF, iFilas);
   }
   
   $CLOSE curEBP;

   if(iFilas>0){
      /*GeneraENDE2(fpOperandos, 10, nroCliente);*/
   }else{
      return 0;
   }
   
   *lFilas+=iFilas;
   
   return 1;
}

short LeoEBP(reg)
$ClsElectro *reg;
{

   InicializaElectro(reg);
   
   $FETCH curEBP INTO
      :reg->numero_cliente,
      :reg->lFechaActivacion,
      :reg->sFechaActivacion,
      :reg->sFechaDesactivac;
   
   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

void TraspasoDatosEBP(iFilas, reg, regF)
long        iFilas;
ClsElectro  reg;
ClsFacts    *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "FLAGEBP");
   strcpy(regF->auto_inser, "X");
   strcpy(regF->ab, reg.sFechaActivacion);
   strcpy(regF->bis2, reg.sFechaDesactivac);
   strcpy(regF->lmenge, "X");
}

short ProcesaFP(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsFactorPot reg;
   ClsFacts    regF;
   long iFilas=0;
   long  iFila=0;
   int   index=1;
   int   vectorHay=0;
   int   iTieneFilas;
   long  lContador=0;
      
   InicializaVectorFactorPot(&(vecFactorPot));
   
   $OPEN curFP USING :nroCliente;
   while(LeoFP(&reg)){
      CargaVectorFactorPot(reg, index, &(vecFactorPot));
      index++;
      vectorHay=1;
   }
   $CLOSE curEBP;

   
   if(vectorHay>0){
      /* El QCONTADOR Ver que piden xq no se entiende 2020 */
      iTieneFilas=0;
      for(iFila=1; iFila < index; iFila++){
         alltrim(vecFactorPot[iFila].evento_mac, ' ');
         if(strcmp(vecFactorPot[iFila].evento_mac, "SB")){
            InicializaOperandos(&regF);
            
            TraspasoDatosQC(vecFactorPot[iFila], &regF);
            rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);
            GenerarPlanos(fpOperandos, 11, regF, iFila);
            lContador++;
            iTieneFilas=1;
            iFilas++;
         }
      }
      if(iTieneFilas>0){
         /*GeneraENDE2(fpOperandos, 11, nroCliente);*/
      }
   
      /* EL STANDBY */
      iTieneFilas=0;
      for(iFila=1; iFila < index; iFila++){
         alltrim(vecFactorPot[iFila].evento_mac, ' ');
         if(strcmp(vecFactorPot[iFila].evento_mac, "SB")==0){
            InicializaOperandos(&regF);
            
            TraspasoDatosSB(vecFactorPot[iFila], &regF);
            /*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
            GenerarPlanos(fpOperandos, 12, regF, iFila);
            lContador++;
            iTieneFilas=1;
            iFilas++;
         }
      }
      if(iTieneFilas>0){
         /*GeneraENDE2(fpOperandos, 12, nroCliente);*/
      }
      
   }
   
   *lFilas+=iFilas;
   
   return 1;
}

short LeoFP(reg)
$ClsFactorPot  *reg;
{
   InicializaFP(reg);
   
   $FETCH curFP INTO
      :reg->numero_cliente,
      :reg->evento_sap,
      :reg->evento_mac,   
      :reg->lFechaEvento,
      :reg->clase_tarifa_sap;
   
   if(SQLCODE != 0){
      return 0;
   }
         
   return 1;
}

void InicializaFP(reg)
$ClsFactorPot  *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->evento_sap, '\0', sizeof(reg->evento_sap));
   memset(reg->evento_mac, '\0', sizeof(reg->evento_mac));   
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaEvento));
   memset(reg->clase_tarifa_sap, '\0', sizeof(reg->clase_tarifa_sap));
}

void TraspasoDatosQC( reg, regF)
ClsFactorPot  reg;
ClsFacts    *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "QCONTADOR");
   strcpy(regF->auto_inser, "X");
   rfmtdate(reg.lFechaEvento, "yyyymmdd", regF->ab); /* long to char */
   strcpy(regF->bis2, "99991231");
   strcpy(regF->lmenge, reg.evento_sap);
   
   strcpy(regF->tarifart, reg.clase_tarifa_sap);
   strcpy(regF->kondigr, "ENERGIA");
   
   alltrim(regF->lmenge, ' ');
   alltrim(regF->tarifart, ' ');
}

void TraspasoDatosSB( reg, regF)
ClsFactorPot  reg;
ClsFacts    *regF;
{
   regF->numero_cliente = reg.numero_cliente; 
   sprintf(regF->anlage, "%ld", reg.numero_cliente);
   
   strcpy(regF->operand, "FLAGSTBY");
   strcpy(regF->auto_inser, "X");
   rfmtdate(reg.lFechaEvento, "yyyymmdd", regF->ab); /* long to char */
   strcpy(regF->bis2, "99991231");
   strcpy(regF->lmenge, "X");
   
}


void InicializaVectorFactorPot(reg)
ClsFactorPot **reg;
{
	if(*reg != NULL)
		free(*reg);
		
	*reg = (ClsFactorPot *) malloc (sizeof(ClsFactorPot));
	if(*reg == NULL){
		printf("Fallo Malloc InicializaVectorFactorPot().\n");
	}
}


void CargaVectorFactorPot(regFactor, index, vec)
ClsFactorPot  regFactor;
int         index;
ClsFactorPot  **vec;
{
   ClsFactorPot	*regAux=NULL;
   ClsFactorPot  reg;
   
	regAux = (ClsFactorPot*) realloc(*vec, sizeof(ClsFactorPot) * (++index) );
	if(regAux == NULL){
		printf("Fallo Realloc CargaVectorFactorPot().\n");
	}		
	
	(*vec) = regAux;

   (*vec)[index-1].numero_cliente = regFactor.numero_cliente;
   strcpy((*vec)[index-1].evento_sap, regFactor.evento_sap);   
   strcpy((*vec)[index-1].evento_mac, regFactor.evento_mac);
   (*vec)[index-1].lFechaEvento = regFactor.lFechaEvento;
   strcpy((*vec)[index-1].clase_tarifa_sap, regFactor.clase_tarifa_sap);
}


short ProcesaClubBarrio(nroCliente, lFechaInicio, lFilas)
$long nroCliente;
$long lFechaInicio;
$long *lFilas;
{
   $ClsElectro reg;
   ClsFacts    regF;
   long iFilas=0;
   long lFechaAux;
   
   $OPEN curBarrio USING :nroCliente, :lFechaInicio, :lFechaInicio;
   
   while(LeoClub(&reg)){
      iFilas++;
      InicializaOperandos(&regF);
      TraspasoDatosClub(iFilas, reg, &regF);
      /*rfmtdate(lFechaInicio, "yyyymmdd", regF.bis1);*/
      if(iFilas == 1 && reg.lFechaActivacion < lFechaInicio){
			lFechaAux=lFechaInicio+1;
			rfmtdate(lFechaAux, "yyyymmdd", regF.ab);
		}
      GenerarPlanos(fpOperandos, 13, regF, iFilas);
   }
   
   $CLOSE curTarifaSocial;

   if(iFilas>0){
      /*GeneraENDE2(fpOperandos, 3, nroCliente);*/
   }else{
      return 0;
   }
   
   *lFilas+=iFilas;
   
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

