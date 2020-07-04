/*******************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_move_in
    
	Fecha : 17/10/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura MOVE_IN de clientes ACTIVOS
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		<Nro.Cliente>: Opcional

*******************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_move_in.h";

/* Variables Globales */
$long	glNroCliente;
$long	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileAltas;

char	sArchAltasUnx[100];
char	sArchAltasDos[100];
char	sSoloArchivoAltas[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];

long	cantProcesada;
long 	cantPreexistente;

/* Variables Globales Host */
$ClsAltas	regAltas;
$long	lFechaLimiteInferior;
$long lFechaRti;
$long lFechaPivote;
$int	iCorrelativos;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
int      iFlagExiste=0;
$ClsEstados regSts;
long     iCantCalculos=0;

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

   /*
	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;

	$EXECUTE selCorrelativos into :iCorrelativos;
   */
   
   $EXECUTE selFechaRti INTO :lFechaRti;	
   
   $EXECUTE selFechaPivote INTO :lFechaPivote;
		
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
		$OPEN curAltas using :glNroCliente;
	}else{
		$OPEN curAltas;
	}

	while(LeoAltas(&regAltas)){
      iFlagMigra=0;
      iFlagExiste=0;
      InicializaEstados(&regSts);
		if(! ClienteYaMigrado(regAltas.numero_cliente, &iFlagMigra, &iFlagExiste, &regSts)){

         if(iFlagExiste == 1){
            CargaCalculados(&regAltas, regSts);
         }else{
            CalculoDatos(&regAltas);
            iCantCalculos++;         
         }
                           
			if (!GenerarPlanoAltas(pFileAltas, regAltas)){
				$ROLLBACK WORK;
				exit(1);	
			}
         if(iFlagExiste != 1){         
            $BEGIN WORK;			
   			if(!RegistraCliente(regAltas, iFlagMigra)){
   				$ROLLBACK WORK;
   				exit(1);	
   			}
            $COMMIT WORK;
         }                           			
			cantProcesada++;
		}else{
			cantPreexistente++;			
		}
	}
	
	$CLOSE curAltas;
			
	CerrarArchivos();

	/* Registrar Control Plano */
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
	printf("MOVE IN.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Clientes Preexistentes :    %ld \n",cantPreexistente);
   printf("Clientes Calculados    :    %ld \n",iCantCalculos);
   
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
		printf("	<Estado> 0 = Activos, 1 = No Activos.\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("	<Tipo Corrida> 0 = Normal, 1 = Reducida.\n");
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos()
{
	int iCorrAlta=0;
		
	memset(sArchAltasUnx,'\0',sizeof(sArchAltasUnx));
	memset(sArchAltasDos,'\0',sizeof(sArchAltasDos));
	memset(sSoloArchivoAltas,'\0',sizeof(sSoloArchivoAltas));	
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));
   
	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchAltasUnx  , "%sT1MOVEIN.unx", sPathSalida );
	/*sprintf( sArchAltasDos  , "%sMove_In_T1_%s_%d.txt", sPathSalida, FechaGeneracion, iCorrAlta );*/
	strcpy( sSoloArchivoAltas, "T1MOVEIN.unx" );

	pFileAltas=fopen( sArchAltasUnx, "w" );
	if( !pFileAltas ){
		printf("ERROR al abrir archivo %s.\n", sArchAltasUnx );
		return 0;
	}
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileAltas);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
   sprintf(sPathCp, "%sActivos/", sPathCopia);
	
	sprintf(sCommand, "chmod 755 %s", sArchAltasUnx);
	iRcv=system(sCommand);	
	
	sprintf(sCommand, "cp %s %s", sArchAltasUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv == 0){
	  sprintf(sCommand, "rm -f %s", sArchAltasUnx);
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
	
   /******** Fecha Pivote  ****************/
   strcpy(sql, "SELECT TODAY - 420 FROM dual");
   
   $PREPARE selFechaPivote FROM $sql;
   
	/******** Cursor Altas  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, c.tarifa), ");
	strcat(sql, "t2.cod_sap, "); 			   /* Categoria Cliente */
	strcat(sql, "t2.acronimo_sap, "); 		/* CDC */
	strcat(sql, "t3.cod_sap, ");           /* sucursal */
	strcat(sql, "NVL(c.nro_beneficiario, 0), ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN cv.numero_cliente IS NOT NULL THEN 'SI' ");
	strcat(sql, "	ELSE 'NO' ");
	strcat(sql, "END, ");
   strcat(sql, "c.sucursal ");
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER (clientes_vip cv, tabla tb1) ");
   strcat(sql, ", OUTER sap_transforma t3 ");

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

   if(giTipoCorrida == 1)	
      strcat(sql, "AND c.numero_cliente = ma.numero_cliente ");

	strcat(sql, "AND c.tipo_sum != 5 ");
	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
/*		
		strcat(sql, "AND si.fecha_baja >= TODAY - 365 ");	
*/		
	}
   
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");
	strcat(sql, "AND t2.clave = 'TIPCLI' ");
	strcat(sql, "AND t2.cod_mac = c.tipo_cliente ");
	strcat(sql, "AND cv.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cv.fecha_activacion <= TODAY ");
	strcat(sql, "AND (cv.fecha_desactivac IS NULL OR cv.fecha_desactivac > TODAY) ");
   
	strcat(sql, "AND tb1.nomtabla = 'SDCLIV' ");
	strcat(sql, "AND tb1.codigo = cv.motivo ");
   strcat(sql, "AND tb1.valor_alf[4] = 'S' ");
	strcat(sql, "AND tb1.sucursal = '0000' ");
	strcat(sql, "AND tb1.fecha_activacion <= TODAY "); 
	strcat(sql, "AND ( tb1.fecha_desactivac >= TODAY OR tb1.fecha_desactivac IS NULL ) ");    
   
	strcat(sql, "AND t3.clave = 'CENTROOP' ");
	strcat(sql, "AND t3.cod_mac = c.sucursal ");
	
	$PREPARE selAltas FROM $sql;
	
	$DECLARE curAltas CURSOR WITH HOLD FOR selAltas;

	/******** Buscamos el Alta Medidor en ESTOC *********/
	strcpy(sql, "SELECT TO_CHAR(fecha_terr_puser, '%Y%m%d') ");
	strcat(sql, "FROM estoc ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selEstoc FROM $sql;

	/******** Buscamos el Alta en ESTOC *********/
	strcpy(sql, "SELECT TO_CHAR(fecha_traspaso, '%Y%m%d') ");
	strcat(sql, "FROM estoc ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selEstoc2 FROM $sql;

	/******** Select Retiros Medidor *********/	
	strcpy(sql, "SELECT TO_CHAR(MAX(m2.fecha_modif), '%Y%m%d') ");
	strcat(sql, "FROM modif m2 ");
	strcat(sql, "WHERE m2.numero_cliente = ? ");
	strcat(sql, "AND m2.codigo_modif = 58 ");

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
	
	/*$PREPARE selCorrelativo FROM $sql;*/

	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	/*$PREPARE updGenArchivos FROM $sql;*/
		
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
	
	/*$PREPARE insGenAltas FROM $sql;*/
	
	/********* Select Cliente ya migrado ***********/
	strcpy(sql, "SELECT move_in, fecha_alta_real, fecha_move_in, motivo_alta, fecha_ultima_lectu FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos Altas **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, move_in, fecha_move_in ");
	strcat(sql, ")VALUES(?, 'S', ?) ");
	
	$PREPARE insClientesMigraA FROM $sql;
	
	/************ Update Clientes Migra Altas **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
   strcat(sql, "fecha_move_in = ?, ");
	strcat(sql, "move_in = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigraA FROM $sql;

	/************ Busca Instalacion **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(MIN(m.fecha_ult_insta), '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");

	$PREPARE selFechaInstal FROM $sql;	
	
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
/*	
	strcpy(sql, "SELECT TO_CHAR(MIN(h.fecha_facturacion), '%Y%m%d') ");
	strcat(sql, "FROM hisfac h, cliente c ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND fecha_facturacion >= ? ");
	strcat(sql, "AND h.corr_facturacion >= c.corr_facturacion - ? ");
*/
	strcpy(sql, "SELECT TO_CHAR(fecha_facturacion, '%Y%m%d') FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	
	$PREPARE selFechaFactura FROM $sql;
		
   /********* Fecha RTi **********/
	strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;

   /*********** Fecha Alta ***********/
	strcpy(sql, "SELECT TO_CHAR(MIN(h1.fecha_lectura), '%Y%m%d') ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND tipo_lectura = 8 ");
	strcat(sql, "AND h1.fecha_lectura > (SELECT MIN(h2.fecha_lectura) ");
	strcat(sql, "	FROM hislec h2 "); 
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "  AND h2.tipo_lectura IN (1,2,3,4) ");
	strcat(sql, "  AND h2.fecha_lectura > ?) ");
   
   $PREPARE selFechaAlta FROM $sql;

   /*********** Fecha Move In 1 ***********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (1, 2, 3, 4) ");
      
   $PREPARE selMoveIn1 FROM $sql;
               
   /******** FEcha Move In 2 *********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (6, 7) ");
      
   $PREPARE selMoveIn2 FROM $sql;


   /******** FEcha Primera factura *********/
	strcpy(sql, "SELECT TO_CHAR(h1.fecha_facturacion, '%Y%m%d') ");
	strcat(sql, "FROM hisfac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = (SELECT MIN(h2.corr_facturacion) ");
	strcat(sql, "	FROM hisfac h2 WHERE h2.numero_cliente = h1.numero_cliente) ");
   
   $PREPARE selPrimFactu FROM $sql;
   
   /************ Motivo Alta *************/
	strcpy(sql, "SELECT e.cod_motivo "); 
	strcat(sql, "FROM solicitud s, est_sol e ");
	strcat(sql, "WHERE s.numero_cliente = ? "); 
	strcat(sql, "AND e.nro_solicitud = s.nro_solicitud ");
   
   $PREPARE selMotiAlta FROM $sql;
   
   /************* Buscar ID Sales Forces ************/
/*   
	strcpy(sql, "SELECT asset FROM sap_sfc_inter ");
	strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE selAsset FROM $sql;   
*/
   /* Fecha Move In Trucha */
   $PREPARE selMoveInTrucho FROM "SELECT TO_CHAR(fecha_lectura, '%Y%m%d')
      FROM hisfac
      WHERE numero_cliente = ?
      AND corr_facturacion = ? ";
   
      
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
short LeoAltas(regAlta)
$ClsAltas *regAlta;
{
	$long	lCorrFactuInicio;
	$char sMotivo[7];
   
	InicializaAltas(regAlta);

	$FETCH curAltas into
		:regAlta->numero_cliente,
		:regAlta->tarifa,
		:regAlta->tipo_cliente,
		:regAlta->sCDC,
		:regAlta->sucursal_sap,
		:regAlta->nro_beneficiario,
		:regAlta->corr_facturacion,
		:regAlta->sElectro,
      :regAlta->sucursal_mac;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de ALTAS !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	alltrim(regAlta->sCDC, ' ');
	
   
   /* ID Sales Forces */
/*   
   $EXECUTE selAsset INTO :regAlta->sAsset USING :regAlta->numero_cliente;
   
   if(SQLCODE != 0){
      printf("Error al buscar ID Sales Forces para cliente %ld\n", regAlta->numero_cliente);
      exit(1);
   }
   
   alltrim(regAlta->sAsset, ' ');
*/   
	return 1;	
}


short CargaAltaReal(regAlta)
$ClsAltas   *regAlta;
{
	$EXECUTE selEstoc into :regAlta->fecha_alta_sistema using :regAlta->numero_cliente;

	if(SQLCODE != 0){

		if(SQLCODE != SQLNOTFOUND){
			printf("Error al buscar fecha de Alta Real para cliente %ld.\n", regAlta->numero_cliente);
			exit(2);
		}else{
			if(regAlta->nro_beneficiario > 0){
				$EXECUTE selRetiro  into :regAlta->fecha_alta_sistema using :regAlta->nro_beneficiario;
					
				if(SQLCODE != 0){
					if(SQLCODE != SQLNOTFOUND){
						printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld.\n", regAlta->nro_beneficiario);
						exit(2);
					}else{
						strcpy(regAlta->fecha_alta_sistema, "19950924");
					}
				}
			}else{
				/* Busco la fecha de instalacion */
				$EXECUTE selFechaInstal into :regAlta->fecha_alta_sistema using :regAlta->numero_cliente;
				
				if(SQLCODE != 0){
					strcpy(regAlta->fecha_alta_sistema, "19950924");
				}
			}
		}
	}

   return 1;
}


short CargaAlta(regAlta)
$ClsAltas   *regAlta;
{

	$EXECUTE selEstoc into :regAlta->fecha_alta using :regAlta->numero_cliente;

	if(SQLCODE != 0){

		if(SQLCODE != SQLNOTFOUND){
			printf("Error al buscar fecha de RETIRO de medidor para cliente %ld.\n", regAlta->numero_cliente);
			exit(2);
		}else{
			if(regAlta->nro_beneficiario > 0){
				$EXECUTE selRetiro  into :regAlta->fecha_alta using :regAlta->nro_beneficiario;
					
				if(SQLCODE != 0){
					if(SQLCODE != SQLNOTFOUND){
						printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld.\n", regAlta->nro_beneficiario);
						exit(2);
					}else{
						strcpy(regAlta->fecha_alta, "19950924");
					}
				}
			}else{
				/* Busco la fecha de instalacion */
				$EXECUTE selFechaInstal into :regAlta->fecha_alta using :regAlta->numero_cliente;
				
				if(SQLCODE != 0){
					strcpy(regAlta->fecha_alta, "19950924");
				}
			}
		}
	}
   
   alltrim(regAlta->fecha_alta, ' ');
   if(strcmp(regAlta->fecha_alta, "")==0){
      $EXECUTE selPrimFactu INTO :regAlta->fecha_alta USING :regAlta->numero_cliente;
      
      if(SQLCODE != 0){
         strcpy(regAlta->fecha_alta, "19950924");
      }
   }

   return 1;
}

char *getFechaFactura(lNroCliente, lCorrFactuInicio)
$long	lNroCliente;
$long 	lCorrFactuInicio;
{
	$char	sFechaFactura[9];
	
	memset(sFechaFactura, '\0', sizeof(sFechaFactura));
	
	/* Reemplazo la fecha lectura por la fecha de primera factura a migrar */
	$EXECUTE selFechaFactura into :sFechaFactura using :lNroCliente, :lCorrFactuInicio;
		
	if(SQLCODE != 0){
		printf("No se encontró factura historica para cliente %ld\n", lNroCliente);
		return;
	}
		
	return sFechaFactura;
}

void InicializaAltas(regAlta)
$ClsAltas	*regAlta;
{
	rsetnull(CLONGTYPE, (char *) &(regAlta->numero_cliente));
	memset(regAlta->tarifa, '\0', sizeof(regAlta->tarifa));
	memset(regAlta->tipo_cliente, '\0', sizeof(regAlta->tipo_cliente));
	memset(regAlta->sCDC, '\0', sizeof(regAlta->sCDC));
	memset(regAlta->sucursal_sap, '\0', sizeof(regAlta->sucursal_sap));
	rsetnull(CLONGTYPE, (char *) &(regAlta->nro_beneficiario));
	rsetnull(CLONGTYPE, (char *) &(regAlta->corr_facturacion));
	memset(regAlta->fecha_alta, '\0', sizeof(regAlta->fecha_alta));
	memset(regAlta->sElectro, '\0', sizeof(regAlta->sElectro));
   memset(regAlta->sMotivoAlta, '\0', sizeof(regAlta->sMotivoAlta));
   memset(regAlta->sAsset, '\0', sizeof(regAlta->sAsset));
   memset(regAlta->sucursal_mac, '\0', sizeof(regAlta->sucursal_mac));
}

short ClienteYaMigrado(nroCliente, iFlagMigra, iFlagExiste, regSts)
$long	nroCliente;
int		*iFlagMigra;
int      *iFlagExiste;
$ClsEstados *regSts;
{
	$char	sMarca[2];
	
   *iFlagMigra=2;

	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado INTO :sMarca, 
                                 :regSts->fecha_alta_real,
                                 :regSts->fecha_move_in,
                                 :regSts->motivo_alta,
                                 :regSts->fecha_ultima_lectura
            using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
         *iFlagExiste=0;
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}

   alltrim(regSts->motivo_alta, ' ');
   if(regSts->fecha_alta_real > 0 && regSts->fecha_move_in > 0 && strcmp(regSts->motivo_alta, "")!=0){
      *iFlagExiste=1;
   }
	
   if(risnull(CLONGTYPE, (char *) regSts->fecha_ultima_lectura)){
      regSts->fecha_ultima_lectura=regSts->fecha_alta_real;
   }
   
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
   	if(gsTipoGenera[0]=='R'){
   		return 0;	
   	}
		return 1;
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
	return 0;
}



void GeneraENDE(fp, regAlta)
FILE *fp;
$ClsAltas	regAlta;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regAlta.numero_cliente);

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
		strcpy(sTipoArchivo, "MOVE_IN");
		strcpy(sNombreArchivo, sSoloArchivoAltas);
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenAltas using
				:gsTipoGenera,
				:lCantidad,
				:glNroCliente,
				:sNombreArchivo;
	}
	
	return 1;
}
*/
short RegistraCliente(reg, iFlagMigra)
$ClsAltas reg;
int		 iFlagMigra;
{
$long lFecha;

   rdefmtdate(&lFecha, "yyyymmdd", reg.fecha_alta); /*char a long*/
      
	if(iFlagMigra==1){
		$EXECUTE insClientesMigraA using :reg.numero_cliente, :lFecha;
	}else{
		$EXECUTE updClientesMigraA using :lFecha, :reg.numero_cliente;
	}

	return 1;
}

short GenerarPlanoAltas(fp, regAlta)
FILE 				*fp;
$ClsAltas		regAlta;
{

	/* EVERD */	
	GeneraEVER(fp, regAlta);
	
	/* ENDE */
	GeneraENDE(fp, regAlta);

	return 1;	
}

void GeneraEVER(fp, regAlta)
FILE 				*fp;
$ClsAltas		regAlta;
{
	char	sLinea[1000];	
	char	sFechaAlta2[9];
	long 	lFechaAlta;
   int   iRcv;
	
	memset(sLinea, '\0', sizeof(sLinea));
	memset(sFechaAlta2, '\0', sizeof(sFechaAlta2));
/*
	rdefmtdate(&lFechaAlta, "yyyymmdd", regAlta.fecha_alta);
	
	if(lFechaAlta < lFechaLimiteInferior){
		strcpy(sFechaAlta2, "20151101");
	}else{
		strcpy(sFechaAlta2, regAlta.fecha_alta);
	}
*/
/*
   strcpy(regAlta.fecha_alta_sistema, regAlta.fecha_alta);
*/
   /* LLAVE */
	sprintf(sLinea, "T1%ld\tEVER\t", regAlta.numero_cliente);
   
   /* VERTRAG es un valor que tienen que venir de Sales Forces */
   /*sprintf(sLinea, "%s%s\t", sLinea, regAlta.sAsset);*/
   sprintf(sLinea, "%s%ld\t", sLinea, regAlta.numero_cliente);  

   /* KOFIZ */
	sprintf(sLinea, "%s%s\t", sLinea, regAlta.sCDC);
   
	/* ABSZYK + GEMFACT*/
	strcat(sLinea, "\t3\t");
   
   /* ABRSPERR + ABRFREIG + VBEZ */
	strcat(sLinea, "\t\t\t");
   
   /* VREFER*/
	sprintf(sLinea, "%s%ld\t", sLinea, regAlta.numero_cliente);
   
   /* BEGRU */
	strcat(sLinea, "T1\t");
   
   /* MANOUTSORT */
	strcat(sLinea, "\t");
	/*
	sprintf(sLinea, "%s%s\t", sLinea, regAlta.tarifa);
	*/
   
   /* AUSGRUP */
	strcat(sLinea, "ZT1\t");
	
   /* OUTCOUNT */
	strcat(sLinea, "\t");
   
   /* ANLAGE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regAlta.numero_cliente);
   
   /* VKONTO */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regAlta.numero_cliente);
	/*
	sprintf(sLinea, "%s%s\t", sLinea, regAlta.fecha_alta);

	sprintf(sLinea, "%s%s\t", sLinea, sFechaAlta2);
   */
   
   /* EINZDAT*/
   sprintf(sLinea, "%s%s\t", sLinea, regAlta.fecha_alta);
	
   /* MAHNV */
	strcat(sLinea, "\t");
   
   /* GSBER */
	/*strcat(sLinea, "0001\t");*/
   sprintf(sLinea, "%s%s\t", sLinea, regAlta.sucursal_sap);
   
   /* STAGRUVER */
   sprintf(sLinea, "%s%s\t", sLinea, regAlta.sMotivoAlta);
   
	
   /* EINZDATALT */
	sprintf(sLinea, "%s%s\t", sLinea, regAlta.fecha_alta_sistema);
   
   /* SRVPRVREF */
/*   
	sprintf(sLinea, "%s%ld\t", sLinea, regAlta.numero_cliente);
*/   
   /* COKEY */
	strcat(sLinea, "\t");
   
   /* BUPLA */
	sprintf(sLinea, "%s%s\t", sLinea, regAlta.sucursal_mac);
   
   /* EXTRAPOLWASTE */
	strcat(sLinea, "\t");
   /* OSB_GROUP */
	strcat(sLinea, "\t");
   /* INVLOCKR */
	strcat(sLinea, "\t");
	/*
	sprintf(sLinea, "%s%s", sLinea, regAlta.tipo_cliente);
	*/
	
   /* ZZ_DESALIM */
	sprintf(sLinea, "%s%s", sLinea, regAlta.sElectro);
   
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir EVER\n");
      exit(1);
   }	

	
}

void CargaCalculados(regAltas, regSts)
ClsAltas    *regAltas;
ClsEstados  regSts;
{
   /*rfmtdate(regSts.fecha_move_in, "yyyymmdd", regAltas->fecha_alta); */  /* long to char */
   rfmtdate(regSts.fecha_ultima_lectura, "yyyymmdd", regAltas->fecha_alta); /* long to char */
   rfmtdate(regSts.fecha_alta_real, "yyyymmdd", regAltas->fecha_alta_sistema); /* long to char */
   strcpy(regAltas->sMotivoAlta, regSts.motivo_alta);
}


void CalculoDatos(regAlta)
$ClsAltas   *regAlta;
{
	$long	lCorrFactuInicio;
	$char sMotivo[7];
   long  lFechaAltaReal;
   $long lFecha;
   
   if(!CargaAltaReal(regAlta)){
       printf("Error al buscar fecha de Alta Real para cliente %ld.\n", regAlta->numero_cliente);
       exit(2);
   }

   rdefmtdate(&lFechaAltaReal, "yyyymmdd", regAlta->fecha_alta_sistema);
   
   if(lFechaAltaReal < lFechaPivote){
      $EXECUTE selMoveIn1 INTO :lFecha USING :regAlta->numero_cliente, :lFechaPivote;
   }else{
      $EXECUTE selMoveIn2 INTO :lFecha USING :regAlta->numero_cliente, :lFechaPivote;
   }
   
   if(SQLCODE != 0){
      lFecha = lFechaAltaReal;
   }
   
   if(lFecha <= 0 || risnull(CDOUBLETYPE, (char *) &lFecha)){
      lFecha = lFechaAltaReal;
   }
   rfmtdate(lFecha, "yyyymmdd", regAlta->fecha_alta);
   
	/* Ahora es la fecha de la primera factura que se migra */
/*   
	if(regAlta->corr_facturacion > 0){
   
      $EXECUTE selFechaAlta INTO :regAlta->fecha_alta
         USING :regAlta->numero_cliente,
               :lFechaRti;
               
      if(SQLCODE != 0){
		    printf("Error al buscar fecha de Alta para cliente %ld.\n", regAlta->numero_cliente);
		    exit(2);
      }

      alltrim(regAlta->fecha_alta, ' ');
      if(strcmp(regAlta->fecha_alta, "")==0){
         if(!CargaAlta(regAlta)){
   		    printf("Error al buscar fecha de Alta para cliente %ld.\n", regAlta->numero_cliente);
   		    exit(2);
         }
      }
	}else{
      if(!CargaAlta(regAlta)){
		    printf("Error al buscar fecha de Alta para cliente %ld.\n", regAlta->numero_cliente);
		    exit(2);
      }
	}
*/	
   /* Motivo de Alta */
   memset(sMotivo, '\0', sizeof(sMotivo));
   
   $EXECUTE selMotiAlta INTO :sMotivo USING :regAlta->numero_cliente;
   
   if(SQLCODE!=0){
      strcpy(regAlta->sMotivoAlta, "N2");
   }else{
      alltrim(sMotivo, ' ');
      if(strcmp(sMotivo,"S16")==0){
         strcpy(regAlta->sMotivoAlta, "N1");
      }else{
         strcpy(regAlta->sMotivoAlta, "N2");
      }
   }
   

}

void InicializaEstados(reg)
ClsEstados *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_val_tarifa));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_alta_real));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_move_in));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_pivote));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->ul, '\0', sizeof(reg->ul));
   memset(reg->motivo_alta, '\0', sizeof(reg->motivo_alta));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_ultima_lectura));
}

void FechaMoveInTrucha(reg)
$ClsAltas   *reg;
{
   $long corrFactuAux = reg->corr_facturacion - 1;
   
   $EXECUTE selMoveInTrucho INTO :reg->fecha_alta
      USING :reg->numero_cliente,
            :corrFactuAux;
            
   
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

