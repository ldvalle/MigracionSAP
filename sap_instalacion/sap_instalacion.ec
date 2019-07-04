/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_instalacion
    
	Fecha : 21/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura INSTALACION
		
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

$include "sap_instalacion.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

FILE	*pFileInstalacionUnx;
FILE	*pFileInstalZZUnx;

char	sArchInstalacionUnx[100];
char	sArchInstalacionDos[100];
char	sSoloArchivoInstalacion[100];

char	sArchInstalZZUnx[100];
char	sSoloArchivoInstalZZ[100];

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
$ClsInstalacion	regInstal;
$long lFechaPivote;
char  sFechaPivote[9];
$long	lFechaLimiteInferior;
$int	iCorrelativos;
$char sFechaRTI[9];
$long lFechaRTI;


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char     nombreBase[20];
time_t 	 hora;
FILE	    *fpIntalacion;
int		 iFlagMigra=0;
int       iFlagExiste=0;
$ClsEstados regSts;

int      iCalculo=0;
int      iRecupero=0;
$long    lFechaMoveIn;

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

   memset(sFechaRTI, '\0', sizeof(sFechaRTI));
/*   
	$EXECUTE selFechaPivote INTO :lFechaPivote;

   CargaLimiteInferior();
*/
   $EXECUTE selParametros INTO :lFechaPivote, :lFechaLimiteInferior;      
      
   $EXECUTE selFechaRti into :sFechaRTI, :lFechaRTI;
		
	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
 
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantActivos=0;
	cantInactivos=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

	if(glNroCliente > 0){
		$OPEN curInstal using :glNroCliente;
	}else{
		$OPEN curInstal;
	}


	fpIntalacion=pFileInstalacionUnx;

	while(LeoInstalacion(&regInstal)){
	   iFlagMigra=0;
      iFlagExiste=0;
      InicializaEstados(&regSts);
      
		if(! ClienteYaMigrado(regInstal.numero_cliente, &iFlagMigra, &iFlagExiste, &regSts)){
        
        if(iFlagExiste == 1){
            CargaCalculados(&regInstal, regSts);
            iRecupero++;                    
        }else{
        
            /* Esto no lo hacemos mas xq es un valor fijo 20141201
            if(!CargaAltaCliente(&regInstal)){
            	printf("No se pudo cargar Fecha Vigencia Tarifa cliente nro %ld\n", regInstal.numero_cliente);
            	exit(1);				
            }
            */
            strcpy(regInstal.fecha_vig_tarifa, "20141201");

            if(!CargaAltaReal(&regInstal)){
            	printf("No se pudo cargar Fecha Alta Real cliente nro %ld\n", regInstal.numero_cliente);
            	exit(1);				
            }

            lFechaMoveIn=getFechaMoveIn(regInstal);
            
            if(!CargaTarifaInstal(&regInstal, lFechaMoveIn)){
            	printf("No se pudo cargar Tarifa y UL Instal a cliente nro %ld\n", regInstal.numero_cliente);
            	exit(1);				
            }
            
            iCalculo++;
        }

			if (!GenerarPlano(fpIntalacion, regInstal)){
				printf("Fallo generacion planos cliente nro %ld\n", regInstal.numero_cliente);
				exit(1);	
			}

         GenerarZZ(pFileInstalZZUnx, regInstal);
         
			if(regInstal.estado_cliente[0]=='0'){
				cantActivos++;
			}else{
				cantInactivos++;
			}
         
         $BEGIN WORK;
			if(!RegistraCliente(regInstal.numero_cliente, regInstal.fecha_vig_tarifa, lFechaPivote, regInstal.sFechaAltaReal, iFlagMigra)){
				$ROLLBACK WORK;
				exit(1);	
			}			
         $COMMIT WORK;
			cantProcesada++;
         
		}else{
			cantPreexistente++;			
		}
		
	}
	
	$CLOSE curInstal;
			
	CerrarArchivos();

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
	printf("INSTALACION\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Clientes Activos :          %ld \n",cantActivos);
	printf("Clientes No Activos :       %ld \n",cantInactivos);
	printf("Clientes Preexistentes :    %ld \n",cantPreexistente);
	printf("Recupero :       %ld \n",iRecupero);
	printf("Calculo :    %ld \n",iCalculo);
   
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

short AbreArchivos()
{
	
	memset(sArchInstalacionUnx,'\0',sizeof(sArchInstalacionUnx));
	memset(sArchInstalacionDos,'\0',sizeof(sArchInstalacionDos));
	memset(sSoloArchivoInstalacion,'\0',sizeof(sSoloArchivoInstalacion));

	memset(sArchInstalZZUnx,'\0',sizeof(sArchInstalZZUnx));
	memset(sSoloArchivoInstalZZ,'\0',sizeof(sSoloArchivoInstalZZ));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
strcpy(sPathSalida, "/fs/migracion/generacion/SAP/");   
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

   if(giEstadoCliente==0){
   	sprintf( sArchInstalacionUnx  , "%sT1INSTALN_Activos.unx", sPathSalida );
   	strcpy( sSoloArchivoInstalacion, "T1INSTALN_Activos.unx");
   }else{
   	sprintf( sArchInstalacionUnx  , "%sT1INSTALN_Inactivos.unx", sPathSalida);
   	strcpy( sSoloArchivoInstalacion, "T1INSTALN_Inactivos");
   }

	pFileInstalacionUnx=fopen( sArchInstalacionUnx, "w" );
	if( !pFileInstalacionUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchInstalacionUnx );
		return 0;
	}

	sprintf( sArchInstalZZUnx  , "%sT1INSTALN_ZZ.unx", sPathSalida);
	strcpy( sSoloArchivoInstalZZ, "T1INSTALN_ZZ");

	pFileInstalZZUnx=fopen( sArchInstalZZUnx, "w" );
	if( !pFileInstalZZUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchInstalZZUnx );
		return 0;
	}
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileInstalacionUnx);
	fclose(pFileInstalZZUnx);
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

   /* El de Instalacion */
	sprintf(sCommand, "chmod 755 %s", sArchInstalacionUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchInstalacionUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv == 0){
      sprintf(sCommand, "rm -f %s", sArchInstalacionUnx);
      iRcv=system(sCommand);
   }
	
   /* El archivo ZZ */
	sprintf(sCommand, "chmod 755 %s", sArchInstalZZUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchInstalZZUnx, sPathCp);
	iRcv=system(sCommand);

   if(iRcv == 0){
      sprintf(sCommand, "rm -f %s", sArchInstalZZUnx);
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

   /********* Parametros **********/
	strcpy(sql, "SELECT fecha_pivote, fecha_limi_inf FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = 0 ");   
   
   $PREPARE selParametros FROM $sql;
   
   /********* Fecha RTi **********/
	strcpy(sql, "SELECT TO_CHAR(fecha_modificacion, '%Y%m%d'), fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;
	
	/******** Cursor Principal  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, ");
	/*strcat(sql, "sc.cod_ul_sap || lpad(case when c.sector>60 then c.sector -20 else c.sector end, 2, 0)|| ");*/
	
strcat(sql, "CASE ");
strcat(sql, "	WHEN c.sector = 81 THEN 'Plan81' ");
strcat(sql, "	WHEN c.sector = 82 THEN 'Plan82' ");
strcat(sql, "	ELSE sc.cod_ul_sap || lpad(c.sector, 2, 0)|| lpad(c.zona,5,0) ");
strcat(sql, "END unidad_lectura, ");
	
/*	strcat(sql, "sc.cod_ul_sap || lpad(c.sector, 2, 0)|| ");
	strcat(sql, "lpad(c.zona,5,0) unidad_lectura, ");
*/	
	strcat(sql, "NVL(t1.cod_sap, '00') voltaje, ");
	strcat(sql, "NVL(t4.cod_sap, ' ') electrodep, ");
	strcat(sql, "CASE ");					/* TArifa*/
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t2.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(t3.cod_sap, '000') ramo, ");
	strcat(sql, "NVL(c.nro_beneficiario, 0), ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "c.estado_cliente, ");

	strcat(sql, "t.nro_subestacion, ");
	strcat(sql, "t.tec_nom_subest, ");
	strcat(sql, "t.tec_alimentador, ");
	strcat(sql, "t.tec_centro_trans, ");
	strcat(sql, "t.tec_fase, ");
	strcat(sql, "NVL(t.tec_acometida, 0), ");
	strcat(sql, "t.tec_tipo_instala, ");
	strcat(sql, "t.tec_nom_calle, ");
	strcat(sql, "t.tec_nro_dir, ");
	strcat(sql, "t.tec_piso_dir, ");
	strcat(sql, "t.tec_depto_dir, ");
	strcat(sql, "t.tec_entre_calle1, ");
	strcat(sql, "t.tec_entre_calle2, ");
	strcat(sql, "t.tec_manzana, ");
	strcat(sql, "t.tec_barrio, ");
	strcat(sql, "t.tec_localidad, ");
	strcat(sql, "t.tec_partido, ");
	strcat(sql, "t.tec_sucursal, ");
	strcat(sql, "NVL(g.x, 0), ");
	strcat(sql, "NVL(g.y, 0), ");
	strcat(sql, "NVL(g.lat, 0), ");
	strcat(sql, "NVL(g.lon, 0), ");
	strcat(sql, "NVL(c.potencia_inst_fp, 0), ");
	strcat(sql, "' ', ");		/* Tipo Obra */
	strcat(sql, "' ', ");		/* Toma */
	strcat(sql, "t.tipo_conexion, ");
	strcat(sql, "t.acometida, ");
	strcat(sql, "NVL(c.cantidad_medidores, 1), ");
	strcat(sql, "' ', ");		/* Fase Neutro */
	strcat(sql, "' ', ");		/* Neutro Metal */
   strcat(sql, "c.correlativo_ruta ");
	strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER (tecni t, sap_transforma t1), sap_transforma t2, ");
	strcat(sql, "OUTER sap_transforma t3, OUTER (clientes_vip cv, tabla tb1, sap_transforma t4), OUTER ubica_geo_cliente g ");

   if(giTipoCorrida==1)
      strcat(sql, ", migra_activos m ");

/*	
strcat(sql, ", sap_sin_fecha m ");
*/
	if(giEstadoCliente!=0){
		strcat(sql, ", sap_inactivos si, medid md ");
	}
	
	if(glNroCliente > 0 ){
		strcat(sql, "WHERE c.numero_cliente = ? ");
		strcat(sql, "AND c.tipo_sum != 5 ");	
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else if(giEstadoCliente == 1){
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
         strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
         strcat(sql, "AND md.numero_cliente = c.numero_cliente ");
         strcat(sql, "AND md.estado = 'I' ");
		}else{
			strcat(sql, "WHERE c.tipo_sum != 5 ");
		}		
	}


	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
		
	strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
	strcat(sql, "AND t.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cv.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cv.fecha_activacion <= TODAY ");
	strcat(sql, "AND (cv.fecha_desactivac IS NULL OR cv.fecha_desactivac > TODAY) ");

	strcat(sql, "AND tb1.nomtabla = 'SDCLIV' ");
	strcat(sql, "AND tb1.codigo = cv.motivo ");
   strcat(sql, "AND tb1.valor_alf[4] = 'S' ");
	strcat(sql, "AND tb1.sucursal = '0000' ");
	strcat(sql, "AND tb1.fecha_activacion <= TODAY "); 
	strcat(sql, "AND ( tb1.fecha_desactivac >= TODAY OR tb1.fecha_desactivac IS NULL ) ");    
   
	strcat(sql, "AND t1.clave = 'SPEBENE' ");			/* voltaje*/
	strcat(sql, "AND t1.cod_mac = t.codigo_voltaje ");
	strcat(sql, "AND t4.clave = 'NODISCONCT' ");		/* categoria electrodepe */
	strcat(sql, "AND t4.cod_mac = cv.motivo ");			
	strcat(sql, "AND t2.clave = 'TARIFTYP' ");			/* tarifa */
	strcat(sql, "AND t2.cod_mac = c.tarifa ");
	strcat(sql, "AND t3.clave = 'BU_TYPE' ");			/* actividad economica */
	strcat(sql, "AND t3.cod_mac = c.actividad_economic ");
	strcat(sql, "AND g.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND g.origen = 'SIS_TEC' ");

   if(giTipoCorrida==1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");

	/*strcat(sql, "ORDER BY c.numero_cliente ");*/
   
   /******************* Cursor Ppal 2 *******************/
	strcpy(sql, "SELECT c.numero_cliente, ");
	/*strcat(sql, "sc.cod_ul_sap || lpad(case when c.sector>60 then c.sector -20 else c.sector end, 2, 0)|| ");*/
	
strcat(sql, "CASE ");
strcat(sql, "	WHEN c.sector IN (81,82) THEN 'DUMMY' ");
strcat(sql, "	ELSE sc.cod_ul_sap || lpad(c.sector, 2, 0)|| lpad(c.zona,5,0) ");
strcat(sql, "END unidad_lectura, ");
	
/*	strcat(sql, "sc.cod_ul_sap || lpad(c.sector, 2, 0)|| ");
	strcat(sql, "lpad(c.zona,5,0) unidad_lectura, ");
*/	
	strcat(sql, "NVL(t1.cod_sap, '00') voltaje, ");
	strcat(sql, "NVL(t4.cod_sap, ' ') electrodep, ");
	strcat(sql, "CASE ");					/* TArifa*/
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t2.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(t3.cod_sap, '000') ramo, ");
	strcat(sql, "NVL(c.nro_beneficiario, 0), ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "c.estado_cliente, ");

	strcat(sql, "t.nro_subestacion, ");
	strcat(sql, "t.tec_nom_subest, ");
	strcat(sql, "t.tec_alimentador, ");
	strcat(sql, "t.tec_centro_trans, ");
	strcat(sql, "t.tec_fase, ");
	strcat(sql, "NVL(t.tec_acometida, 0), ");
	strcat(sql, "t.tec_tipo_instala, ");
	strcat(sql, "t.tec_nom_calle, ");
	strcat(sql, "t.tec_nro_dir, ");
	strcat(sql, "t.tec_piso_dir, ");
	strcat(sql, "t.tec_depto_dir, ");
	strcat(sql, "t.tec_entre_calle1, ");
	strcat(sql, "t.tec_entre_calle2, ");
	strcat(sql, "t.tec_manzana, ");
	strcat(sql, "t.tec_barrio, ");
	strcat(sql, "t.tec_localidad, ");
	strcat(sql, "t.tec_partido, ");
	strcat(sql, "t.tec_sucursal, ");
	strcat(sql, "NVL(c.potencia_inst_fp, 0), ");
	strcat(sql, "' ', ");		/* Tipo Obra */
	strcat(sql, "' ', ");		/* Toma */
	strcat(sql, "t.tipo_conexion, ");
	strcat(sql, "t.acometida, ");
	strcat(sql, "NVL(c.cantidad_medidores, 1), ");
	strcat(sql, "' ', ");		/* Fase Neutro */
	strcat(sql, "' ', ");		/* Neutro Metal */
   strcat(sql, "c.correlativo_ruta ");
	strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER (tecni t, sap_transforma t1), sap_transforma t2, ");
	strcat(sql, "OUTER sap_transforma t3, OUTER (clientes_vip cv, sap_transforma t4) ");

   if(giTipoCorrida==1)
      strcat(sql, ", migra_activos m ");

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
		}else if(giEstadoCliente == 1){
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.tipo_sum != 5 ");
		}		
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}

	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
		
	strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
	strcat(sql, "AND t.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cv.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cv.fecha_activacion <= TODAY ");
	strcat(sql, "AND (cv.fecha_desactivac IS NULL OR cv.fecha_desactivac > TODAY) ");
	strcat(sql, "AND t1.clave = 'SPEBENE' ");			/* voltaje*/
	strcat(sql, "AND t1.cod_mac = t.codigo_voltaje ");
	strcat(sql, "AND t4.clave = 'NODISCONCT' ");		/* categoria electrodepe */
	strcat(sql, "AND t4.cod_mac = cv.motivo ");			
	strcat(sql, "AND t2.clave = 'TARIFTYP' ");			/* tarifa */
	strcat(sql, "AND t2.cod_mac = c.tarifa ");
	strcat(sql, "AND t3.clave = 'BU_TYPE' ");			/* actividad economica */
	strcat(sql, "AND t3.cod_mac = c.actividad_economic ");

   if(giTipoCorrida==1)
      strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
   

	/************* CURSOR CLIENTES *************/
/* La version para que traiga las cosas de a pedazos, tardó mas  */
/*
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.sector IN (81,82) THEN 'DUMMY' ");
	strcat(sql, "	ELSE sc.cod_ul_sap || lpad(c.sector, 2, 0)|| lpad(c.zona,5,0) ");
	strcat(sql, "END unidad_lectura, ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t2.cod_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(t3.cod_sap, '000') ramo, ");
	strcat(sql, "NVL(c.nro_beneficiario, 0), ");
	strcat(sql, "NVL(c.corr_facturacion, 0), ");
	strcat(sql, "c.estado_cliente, ");
	strcat(sql, "NVL(c.potencia_inst_fp, 0), ");
	strcat(sql, "NVL(c.cantidad_medidores, 1), ");	
	strcat(sql, "c.correlativo_ruta ");
	strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER sap_transforma t2, OUTER sap_transforma t3 ");
	
   if(giTipoCorrida==1)
      strcat(sql, ", migra_activos ma ");
      
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
		}else if(giEstadoCliente == 1){
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql, "AND c.tipo_sum != 5 ");
		}else{
			strcat(sql, "WHERE c.tipo_sum != 5 ");
		}		
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
	
   if(giTipoCorrida==1)
      strcat(sql, "AND c.numero_cliente = ma.numero_cliente ");
      
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
	strcat(sql, "AND t2.clave = 'TARIFTYP' "); 
	strcat(sql, "AND t2.cod_mac = c.tarifa ");
	strcat(sql, "AND t3.clave = 'BU_TYPE' ");
	strcat(sql, "AND t3.cod_mac = c.actividad_economic ");
*/	
	$PREPARE selInstal FROM $sql;
	
	$DECLARE curInstal CURSOR WITH HOLD FOR selInstal;	

	/********** DATOS TECNICOS ***********/
	strcpy(sql, "SELECT NVL(t1.cod_sap, '00') voltaje, ");
	strcat(sql, "t.nro_subestacion, ");
	strcat(sql, "t.tec_nom_subest, ");
	strcat(sql, "t.tec_alimentador, ");
	strcat(sql, "t.tec_centro_trans, ");
	strcat(sql, "t.tec_fase, ");
	strcat(sql, "NVL(t.tec_acometida, 0), ");
	strcat(sql, "t.tec_tipo_instala, ");
	strcat(sql, "t.tec_nom_calle, ");
	strcat(sql, "t.tec_nro_dir, ");
	strcat(sql, "t.tec_piso_dir, ");
	strcat(sql, "t.tec_depto_dir, ");
	strcat(sql, "t.tec_entre_calle1, ");
	strcat(sql, "t.tec_entre_calle2, ");
	strcat(sql, "t.tec_manzana, ");
	strcat(sql, "t.tec_barrio, ");
	strcat(sql, "t.tec_localidad, ");
	strcat(sql, "t.tec_partido, ");
	strcat(sql, "t.tec_sucursal, ");
	strcat(sql, "t.tipo_conexion, ");
	strcat(sql, "t.acometida ");
	strcat(sql, "FROM tecni t, OUTER sap_transforma t1 ");
	strcat(sql, "WHERE t.numero_cliente = ? ");
	strcat(sql, "AND t1.clave = 'SPEBENE' ");			/* voltaje*/
	strcat(sql, "AND t1.cod_mac = t.codigo_voltaje ");

	$PREPARE selTecni FROM $sql;

	/********** ELECTRO DEPENDIENTE ***********/
	strcpy(sql, "SELECT  NVL(t4.cod_sap, ' ') electrodep ");
	strcat(sql, "FROM clientes_vip cv, OUTER sap_transforma t4 ");
	strcat(sql, "WHERE cv.numero_cliente = ? ");
	strcat(sql, "AND cv.fecha_activacion <= TODAY ");
	strcat(sql, "AND (cv.fecha_desactivac IS NULL OR cv.fecha_desactivac > TODAY) ");
	strcat(sql, "AND t4.clave = 'NODISCONCT' ");		/* categoria electrodepe */
	strcat(sql, "AND t4.cod_mac = cv.motivo ");	
	
	$PREPARE selElectroDepe FROM $sql;

	/********** UBICACION GEOGRAFICA ******/
	strcpy(sql, "SELECT NVL(g.x, 0), ");
	strcat(sql, "NVL(g.y, 0), ");
	strcat(sql, "NVL(g.lat, 0), ");
	strcat(sql, "NVL(g.lon, 0) ");
	strcat(sql, "FROM ubica_geo_cliente g ");
	strcat(sql, "WHERE g.numero_cliente = ? ");
	strcat(sql, "AND g.origen = 'SIS_TEC' ");
			
	$PREPARE selUbica FROM $sql;
	
	/******** Cursor Facturas *********/	
	strcpy(sql, "SELECT FIRST 12 h.fecha_facturacion, h.tarifa, TO_CHAR(h.fecha_facturacion, '%Y%m%d') ");
	strcat(sql, "FROM hisfac h ");
	strcat(sql, "WHERE h.numero_cliente = ? ");
	strcat(sql, "ORDER BY h.fecha_facturacion DESC ");

	$PREPARE selFactu FROM $sql;
	
	$DECLARE curFacturas CURSOR FOR selFactu;
	
	/****** Buscamos Tarifa Social Activa *******/
	strcpy(sql, "SELECT COUNT(*) FROM tarifa_social ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_inicio <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
	
	$PREPARE selTarsoc FROM $sql;
		
	/******** Buscamos el Alta en ESTOC *********/
	strcpy(sql, "SELECT TO_CHAR(fecha_terr_puser, '%Y%m%d') ");
	strcat(sql, "FROM estoc ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selEstoc FROM $sql;
	
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
		
	/******** Insert gen_archivos ****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'INSTALACION', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT instalacion, ");
   strcat(sql, "fecha_val_tarifa, ");
   strcat(sql, "fecha_alta_real, ");
   strcat(sql, "tarifa, ");
   strcat(sql, "ul ");    
   strcat(sql, "FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, fecha_val_tarifa, fecha_alta_real, fecha_pivote, instalacion ");
	strcat(sql, ")VALUES(?, ?, ?, ?, 'S') ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "fecha_val_tarifa = ?, ");
   strcat(sql, "fecha_alta_real = ?, ");
   strcat(sql, "fecha_pivote = ?, ");
	strcat(sql, "instalacion = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ Busca Instalacion 1 **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.estado = 'I' ");

	$PREPARE selFechaInstal1 FROM $sql;

	/************ Busca Instalacion 2 **************/
	strcpy(sql, "SELECT NVL(TO_CHAR(MIN(m.fecha_ult_insta), '%Y%m%d'), '19950924') ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");

	$PREPARE selFechaInstal2 FROM $sql;
	
	/************ FechaLimiteInferior **************/
	strcpy(sql, "SELECT TODAY - 420 FROM dual ");
/*
	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
*/		
	$PREPARE selFechaPivote FROM $sql;

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
	------------------------------------------------------------------------
	strcpy(sql, "SELECT TO_CHAR(fecha_facturacion, '%Y%m%d') FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
*/
	
	strcpy(sql, "SELECT NVL(TO_CHAR(MAX(h2.fecha_lectura), '%Y%m%d'), '20161101') ");
	strcat(sql, "FROM hisfac h1, hislec h2 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "AND h2.fecha_lectura < h1.fecha_facturacion ");
	strcat(sql, "AND h2.tipo_lectura IN (1, 2, 3, 4, 7, 8) ");
	
	$PREPARE selFechaFactura FROM $sql;

   /*************** Fecha Vig.Tarifa****************/
	strcpy(sql, "SELECT MIN(fecha_lectura) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_lectura > ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 8) ");
   
   $PREPARE selVigTarifa FROM $sql;
   
   /************* Buscar ID Sales Forces ************/
/*   
	strcpy(sql, "SELECT pod FROM sap_sfc_inter ");
	strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE selPod FROM $sql;   
*/
   /************* Tarifa RTI ************/
	strcpy(sql, "SELECT ");  
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN h1.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN h1.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
   strcat(sql, "	WHEN c.tarifa = 'APM' AND c.tipo_sum != 6 THEN 'T1-AP-MED' "); 
	strcat(sql, "	ELSE t1.cod_sap "); 
	strcat(sql, "END ");
	strcat(sql, "FROM cliente c, hisfac h1, sap_transforma t1 ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h1.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h1.fecha_facturacion = (SELECT MIN(h2.fecha_facturacion) ");
	strcat(sql, "	FROM hisfac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = c.numero_cliente ");
	strcat(sql, "  AND h2.fecha_facturacion >= ?) ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h1.tarifa ");
   
   $PREPARE selTarifRTI FROM $sql;
   
   /************ Tarifa a la instalacion ************/
	strcpy(sql, "SELECT first 1 ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "); 
	strcat(sql, "	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
   strcat(sql, "	WHEN c.tarifa = 'APM' AND c.tipo_sum != 6 THEN 'T1-AP-MED' "); 
	strcat(sql, "	ELSE t1.cod_sap "); 
	strcat(sql, "END, "); 
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "LPAD(CASE WHEN h.sector>60 AND h.sector < 81 THEN h.sector ELSE h.sector END, 2, 0) || ");  
	strcat(sql, "LPAD(h.zona,5,0), ");
	strcat(sql, "h.corr_facturacion ");
	strcat(sql, "FROM cliente c, hisfac h, sap_transforma t1, sucur_centro_op s "); 
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.fecha_lectura >= ? ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' "); 
	strcat(sql, "AND t1.cod_mac = h.tarifa "); 
	strcat(sql, "AND s.cod_centro_op = h.sucursal "); 
	strcat(sql, "AND s.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "); 
	strcat(sql, "ORDER BY h.corr_facturacion ASC ");
   
   $PREPARE selTarifInstal FROM $sql;
      
   /************ Tarifa a la instalacion Alternativa ************/
	strcpy(sql, "SELECT ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "); 
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
   strcat(sql, "	WHEN c.tarifa = 'APM' AND c.tipo_sum != 6 THEN 'T1-AP-MED' "); 
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, "); 
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "LPAD(CASE WHEN c.sector>60 AND c.sector < 81 THEN c.sector ELSE c.sector END, 2, 0) || ");  
	strcat(sql, "LPAD(c.zona,5,0) ");
	strcat(sql, "FROM cliente c, sap_transforma t1, sucur_centro_op s "); 
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' " );
	strcat(sql, "AND t1.cod_mac = c.tarifa "); 
	strcat(sql, "AND s.cod_centro_op = c.sucursal "); 
	strcat(sql, "AND s.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "); 
   
   $PREPARE selTarifInstal2 FROM $sql;

   /******** FEcha Move In 1 *********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (1, 2, 3, 4) ");
      
   $PREPARE selMoveIn FROM $sql;
               
   /******** FEcha Move In 2 *********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (6, 7) ");
      
   $PREPARE selMoveIn2 FROM $sql;

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
short LeoInstalacion(regIns)
$ClsInstalacion *regIns;
{
	long lFechaInstal;
	$char sFechaInstal[9];
	$int  iCant;
	
	memset(sFechaInstal, '\0', sizeof(sFechaInstal));
		
	InicializaInstalacion(regIns);

	$FETCH curInstal into
		:regIns->numero_cliente,
		:regIns->cod_ul,
		:regIns->codigo_voltaje,
		:regIns->catego_electrodependiente,
		:regIns->tarifa,
		:regIns->actividad_economic,
		:regIns->nro_beneficiario,
		:regIns->corr_facturacion,
		:regIns->estado_cliente,
		:regIns->nro_subestacion,
		:regIns->tec_nom_subest,
		:regIns->tec_alimentador,
		:regIns->tec_centro_trans,
		:regIns->tec_fase,
		:regIns->tec_acometida,
		:regIns->tec_tipo_instala,
		:regIns->tec_nom_calle,
		:regIns->tec_nro_dir,
		:regIns->tec_piso_dir,
		:regIns->tec_depto_dir,
		:regIns->tec_entre_calle1,
		:regIns->tec_entre_calle2,
		:regIns->tec_manzana,
		:regIns->tec_barrio,
		:regIns->tec_localidad,
		:regIns->tec_partido,
		:regIns->tec_sucursal,
		:regIns->potencia_inst_fp,
		:regIns->tipo_obra,
		:regIns->toma,
		:regIns->tipo_conexion,
		:regIns->acometida,
		:regIns->cantidad_medidores,
		:regIns->fase_neutro,
		:regIns->neutro_metal,
      :regIns->correlativo_ruta;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de INSTALACION !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			


   /* Cursor Clientes */
/*   
	$FETCH curInstal into
		:regIns->numero_cliente,
		:regIns->cod_ul,
		:regIns->tarifa,
		:regIns->actividad_economic,
		:regIns->nro_beneficiario,
		:regIns->corr_facturacion,
		:regIns->estado_cliente,
		:regIns->potencia_inst_fp,
		:regIns->cantidad_medidores,
        :regIns->correlativo_ruta;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de INSTALACION !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
*/
	/* Cargo Datos Tecnicos */
/*   
	$EXECUTE selTecni INTO
			:regIns->codigo_voltaje,
			:regIns->nro_subestacion,
			:regIns->tec_nom_subest, 
			:regIns->tec_alimentador, 
			:regIns->tec_centro_trans,
			:regIns->tec_fase,
			:regIns->tec_acometida,
			:regIns->tec_tipo_instala,
			:regIns->tec_nom_calle,
			:regIns->tec_nro_dir,
			:regIns->tec_piso_dir,
			:regIns->tec_depto_dir,
			:regIns->tec_entre_calle1,
			:regIns->tec_entre_calle2,
			:regIns->tec_manzana,
			:regIns->tec_barrio,
			:regIns->tec_localidad,
			:regIns->tec_partido,
			:regIns->tec_sucursal,
			:regIns->tipo_conexion,
			:regIns->acometida
		USING :regIns->numero_cliente;
	
	if(SQLCODE != 0 && SQLCODE != SQLNOTFOUND){
		printf("Error al buscar datos técnicos para cliente %ld\n", regIns->numero_cliente);
	}
*/
	/* Cargo Electrodependencia */
/*   
	$EXECUTE selElectroDepe
		INTO :regIns->catego_electrodependiente
		USING :regIns->numero_cliente;
	
	if(SQLCODE != 0 && SQLCODE != SQLNOTFOUND){
		printf("Error al buscar Electrodependencia para cliente %ld\n", regIns->numero_cliente);
	}
*/	
	/* Cargo Ubicación Geografica */
  
	$EXECUTE selUbica INTO 
		:regIns->ubi_x,
		:regIns->ubi_y,
		:regIns->ubi_lat,
		:regIns->ubi_long
		USING :regIns->numero_cliente;
	
	if(SQLCODE != 0 && SQLCODE != SQLNOTFOUND){
		printf("Error al buscar Ubicación Geográfica para cliente %ld\n", regIns->numero_cliente);
	}
	
	/* Verifico Tarifa Social */
/*	
	iCant=0;
	
	$EXECUTE selTarsoc into :iCant using :regIns->numero_cliente;
		
	if ( SQLCODE != 0 ){
		printf("Error al verificar tarifa social para cliente %ld\n", regIns->numero_cliente);
		exit(1);		
	}
	
	if(iCant>0)
		strcpy(regIns->tarifa, "T1-RES-TIS");
*/	
	
   /* Piso la tarifa y fuerzo a la de la primera factura post RTI */
/*   
   $EXECUTE selTarifRTI INTO :regIns->tarifa USING :regIns->numero_cliente, :lFechaRTI;
   
   if(SQLCODE != 0){
      printf("Cliente %ld no tiene facturas o no está activo\n", regIns->numero_cliente);
   }
*/   
	alltrim(regIns->codigo_voltaje, ' ');
	alltrim(regIns->catego_electrodependiente, ' ');
	alltrim(regIns->tarifa, ' ');

	alltrim(regIns->nro_subestacion, ' ');
	alltrim(regIns->tec_nom_subest, ' ');
	alltrim(regIns->tec_alimentador, ' ');
	alltrim(regIns->tec_centro_trans, ' ');
	alltrim(regIns->tec_fase, ' ');
	alltrim(regIns->tec_tipo_instala, ' ');
	alltrim(regIns->tec_nom_calle, ' ');
	alltrim(regIns->tec_nro_dir, ' ');
	alltrim(regIns->tec_piso_dir, ' ');
	alltrim(regIns->tec_depto_dir, ' ');
	alltrim(regIns->tec_entre_calle1, ' ');
	alltrim(regIns->tec_entre_calle2, ' ');
	alltrim(regIns->tec_manzana, ' ');
	alltrim(regIns->tec_barrio, ' ');
	alltrim(regIns->tec_localidad, ' ');
	alltrim(regIns->tec_partido, ' ');
	alltrim(regIns->tec_sucursal, ' ');
	alltrim(regIns->tipo_obra, ' ');
	alltrim(regIns->toma, ' ');
	alltrim(regIns->tipo_conexion, ' ');
	alltrim(regIns->acometida, ' ');
	alltrim(regIns->fase_neutro, ' ');
	alltrim(regIns->neutro_metal, ' ');
	
	/* Busco la fecha de instalacion */
   
/*
	$EXECUTE selFechaInstal1 into :regIns->fecha_instalacion using :regIns->numero_cliente;
		
	if(SQLCODE != 0){
		if(SQLCODE == 100){
		
			$EXECUTE selFechaInstal2 into :sFechaInstal using :regIns->numero_cliente;
	
			if(SQLCODE == 0){
				strcpy(regIns->fecha_instalacion, sFechaInstal);
			}else{
				printf("Error al buscar fecha de instalacion 2 para cliente %ld.\n", regIns->numero_cliente);
				exit(1);	
			}			
		}else{
			printf("Error al buscar fecha de instalacion 1 para cliente %ld.\n", regIns->numero_cliente);
			exit(1);
		}
		
	}else{
		rdefmtdate(&lFechaInstal, "yyyymmdd", regIns->fecha_instalacion);
		if(lFechaInstal > lFechaLimiteInferior){
			$EXECUTE selFechaInstal2 into :sFechaInstal using :regIns->numero_cliente;
	
			if(SQLCODE == 0){
				strcpy(regIns->fecha_instalacion, sFechaInstal);
			}else{
				printf("Error al buscar fecha de instalacion 2 para cliente %ld\n", regIns->numero_cliente);
				exit(1);	
			}
		}
	}
*/	
	return 1;	
}

void InicializaInstalacion(regIns)
$ClsInstalacion	*regIns;
{
	rsetnull(CLONGTYPE, (char *) &(regIns->numero_cliente));
	
	memset(regIns->cod_ul, '\0', sizeof(regIns->cod_ul));
	memset(regIns->fecha_vig_tarifa, '\0', sizeof(regIns->fecha_vig_tarifa));
	memset(regIns->codigo_voltaje, '\0', sizeof(regIns->codigo_voltaje));
	memset(regIns->catego_electrodependiente, '\0', sizeof(regIns->catego_electrodependiente));
	memset(regIns->tarifa, '\0', sizeof(regIns->tarifa));
	memset(regIns->actividad_economic, '\0', sizeof(regIns->actividad_economic));
	memset(regIns->cod_porcion, '\0', sizeof(regIns->cod_porcion));
	memset(regIns->fecha_instalacion, '\0', sizeof(regIns->fecha_instalacion));
	rsetnull(CLONGTYPE, (char *) &(regIns->corr_facturacion));
	rsetnull(CLONGTYPE, (char *) &(regIns->nro_beneficiario));
	
	memset(regIns->nro_subestacion, '\0', sizeof(regIns->nro_subestacion));
	memset(regIns->tec_nom_subest, '\0', sizeof(regIns->tec_nom_subest));
	memset(regIns->tec_alimentador, '\0', sizeof(regIns->tec_alimentador));
	memset(regIns->tec_centro_trans, '\0', sizeof(regIns->tec_centro_trans));
	memset(regIns->tec_fase, '\0', sizeof(regIns->tec_fase));
	rsetnull(CLONGTYPE, (char *) &(regIns->tec_acometida));
	memset(regIns->tec_tipo_instala, '\0', sizeof(regIns->tec_tipo_instala));
	memset(regIns->tec_nom_calle, '\0', sizeof(regIns->tec_nom_calle));
	memset(regIns->tec_nro_dir, '\0', sizeof(regIns->tec_nro_dir));
	memset(regIns->tec_piso_dir, '\0', sizeof(regIns->tec_piso_dir));
	memset(regIns->tec_depto_dir, '\0', sizeof(regIns->tec_depto_dir));
	memset(regIns->tec_entre_calle1, '\0', sizeof(regIns->tec_entre_calle1));
	memset(regIns->tec_entre_calle2, '\0', sizeof(regIns->tec_entre_calle2));
	memset(regIns->tec_manzana, '\0', sizeof(regIns->tec_manzana));
	memset(regIns->tec_barrio, '\0', sizeof(regIns->tec_barrio));
	memset(regIns->tec_localidad, '\0', sizeof(regIns->tec_localidad));
	memset(regIns->tec_partido, '\0', sizeof(regIns->tec_partido));
	memset(regIns->tec_sucursal, '\0', sizeof(regIns->tec_sucursal));
	rsetnull(CDOUBLETYPE, (char *) &(regIns->ubi_x));
	rsetnull(CDOUBLETYPE, (char *) &(regIns->ubi_y));
	rsetnull(CDOUBLETYPE, (char *) &(regIns->ubi_lat));
	rsetnull(CDOUBLETYPE, (char *) &(regIns->ubi_long));
	rsetnull(CDOUBLETYPE, (char *) &(regIns->potencia_inst_fp));

	memset(regIns->tipo_obra, '\0', sizeof(regIns->tipo_obra));
	memset(regIns->toma, '\0', sizeof(regIns->toma));

	memset(regIns->tipo_conexion, '\0', sizeof(regIns->tipo_conexion));
	memset(regIns->acometida, '\0', sizeof(regIns->acometida));
	rsetnull(CLONGTYPE, (char *) &(regIns->cantidad_medidores));

	memset(regIns->fase_neutro, '\0', sizeof(regIns->fase_neutro));
	memset(regIns->neutro_metal, '\0', sizeof(regIns->neutro_metal));
   
   memset(regIns->sFechaAltaReal, '\0', sizeof(regIns->sFechaAltaReal));
   memset(regIns->sPod, '\0', sizeof(regIns->sPod));
   
   rsetnull(CLONGTYPE, (char *) &(regIns->correlativo_ruta));
   
}

short ClienteYaMigrado(nroCliente, iFlagMigra, iFlagExiste, reg)
$long	nroCliente;
int		*iFlagMigra;
int      *iFlagExiste;
$ClsEstados *reg;
{
	$char	sMarca[2];
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado INTO :sMarca, 
                                 :reg->fecha_val_tarifa,
                                 :reg->fecha_alta_real,
                                 :reg->tarifa,
                                 :reg->ul    
                     USING :nroCliente;
		
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
	
   alltrim(reg->tarifa, ' ');
   alltrim(reg->ul, ' ');

/*printf("valtarifa [%ld] real [%ld] tarifa[%s] ul [%s]\n", reg->fecha_val_tarifa, reg->fecha_alta_real, reg->tarifa, reg->ul);*/   
   if(reg->fecha_val_tarifa > 0 && reg->fecha_alta_real >0 && strcmp(reg->tarifa, "")!= 0 && strcmp(reg->ul, "")!=0){
/*printf("Lo reconoce\n");*/   
      *iFlagExiste=1;   
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

short CargaAltaCliente(regIns)
$ClsInstalacion *regIns;
{
	$long lFechaAlta;
	char sFechaAlta[9];
   char  sMesAlta[3];
   char  sMesAnal[3];  
	$long iCorrFactuInicio;
   $long lFechaInferior2;
   long  lFechaAltaAux;
   int   iVueltas;
   	
	memset(sFechaAlta, '\0', sizeof(sFechaAlta));
   memset(sMesAlta, '\0', sizeof(sMesAlta));
   memset(sMesAnal, '\0', sizeof(sMesAnal));

	if(regIns->corr_facturacion > 0){
   
      $EXECUTE selVigTarifa INTO :lFechaAlta USING
         :regIns->numero_cliente,
         :lFechaLimiteInferior;
         
      if(SQLCODE !=0){
			printf("Error al buscar fecha de Alta para cliente %ld.\n", regIns->numero_cliente);
			exit(2);
      }
      
      if(lFechaAlta > lFechaLimiteInferior){
         rfmtdate(lFechaAlta, "yyyymmdd", regIns->fecha_vig_tarifa); /* long to char */
      }else{
         rfmtdate(lFechaLimiteInferior, "yyyymmdd", regIns->fecha_vig_tarifa); /* long to char */
      }
      
/*   
      if(lFechaAlta > 0){
         rfmtdate(lFechaLimiteInferior, "mm", sMesAnal);
         rfmtdate(lFechaAlta, "mm", sMesAlta);
   
         
         // Me fijo si me tengo que ir un mes mas atras para buscar 
         lFechaAltaAux=lFechaAlta;
         lFechaInferior2=lFechaLimiteInferior - 30;
         iVueltas=0;
         
         while((atoi(sMesAnal)< atoi(sMesAlta)) && lFechaInferior2 > 0 && iVueltas <2){
             $EXECUTE selVigTarifa INTO :lFechaAlta USING
                :regIns->numero_cliente,
                :lFechaInferior2;
                
            if(SQLCODE != 0){
               lFechaAlta = lFechaAltaAux;
               lFechaInferior2=0;   
            }
            rfmtdate(lFechaAlta, "mm", sMesAlta);
            lFechaInferior2-=30;
            iVueltas++;
         }
        
         rfmtdate(lFechaAlta, "yyyymmdd", regIns->fecha_vig_tarifa);
                     
      }else{
         if(!CargaAltaCliente2(regIns)){
            return 0;
         }
      }
*/            	
	}else{

      if(!CargaAltaCliente2(regIns)){
         return 0;
      }
	}
	
   /*rdefmtdate(&lFechaAlta, "yyyymmdd", regIns->fecha_vig_tarifa);*/ /*char a long*/
   
   strcpy(regIns->fecha_instalacion, regIns->fecha_vig_tarifa);
   
	return 1;	
}


short CargaAltaCliente2(regIns)
$ClsInstalacion *regIns;
{
	$long lFechaAlta;

	/* Primero busco la fecha de alta en ESTOC */
	$EXECUTE selEstoc into :regIns->fecha_vig_tarifa using :regIns->numero_cliente;

	if(SQLCODE != 0){

		if(SQLCODE != SQLNOTFOUND){
			printf("Error al buscar fecha de Alta para cliente %ld.\n", regIns->numero_cliente);
			exit(2);
		}else{
			if(regIns->nro_beneficiario > 0){
				$EXECUTE selRetiro  into :regIns->fecha_vig_tarifa using :regIns->nro_beneficiario;
					
				if(SQLCODE != 0){
					if(SQLCODE != SQLNOTFOUND){
						printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld.\n", regIns->nro_beneficiario);
						exit(2);						
					}else{
						strcpy(regIns->fecha_vig_tarifa, "19950924");
					}
				}
			}else{
				strcpy(regIns->fecha_vig_tarifa, "19950924");
			}
		}
	}	
	
	rdefmtdate(&lFechaAlta, "yyyymmdd", regIns->fecha_vig_tarifa); 
	if(lFechaAlta < lFechaLimiteInferior){
      rfmtdate(lFechaLimiteInferior, "yyyymmdd", regIns->fecha_vig_tarifa);
	}

   return 1;
}


short CargaAltaReal(regIns)
$ClsInstalacion *regIns;
{
   $long lFechaAlta;
   
	$EXECUTE selEstoc into :regIns->sFechaAltaReal using :regIns->numero_cliente;

	if(SQLCODE != 0){

		if(SQLCODE != SQLNOTFOUND){
			printf("Error al buscar fecha de Alta Real para cliente %ld.\n", regIns->numero_cliente);
         return 0;
		}else{
			if(regIns->nro_beneficiario > 0){
				$EXECUTE selRetiro  into :regIns->sFechaAltaReal using :regIns->nro_beneficiario;
					
				if(SQLCODE != 0){
					if(SQLCODE != SQLNOTFOUND){
						printf("Error al buscar fecha de RETIRO de medidor para cliente antecesor %ld para fecha alta real.\n", regIns->nro_beneficiario);
						return 0;						
					}else{
						strcpy(regIns->sFechaAltaReal, "19950924");
					}
				}
			}else{
				strcpy(regIns->sFechaAltaReal, "19950924");
			}
		}
	}	

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

short CargaCambioTarifa(regIns)
$ClsInstalacion *regIns;
{
	char			sTarifa[4];
	char			sFecha[9];
	$ClsHisfac		regFactu;
	int				salida=0;
	int 			i=0;
	
	memset(sTarifa, '\0', sizeof(sTarifa));
	memset(sFecha, '\0', sizeof(sFecha));
	
	$OPEN curFacturas using :regIns->numero_cliente;
	
	$FETCH curFacturas into :regFactu.lFecha,
							:regFactu.tarifa,
							:regFactu.fecha_facturacion;
								
	strcpy(sTarifa, regFactu.tarifa);
	strcpy(sFecha, regFactu.fecha_facturacion);
	
	while((SQLCODE != SQLNOTFOUND) && (salida == 0)){
		i++;		

		if(strcmp(sTarifa, regFactu.tarifa)==0){
			strcpy(sFecha, regFactu.fecha_facturacion);
		}else{
			salida=1;	
		}
	
		$FETCH curFacturas into :regFactu.lFecha,
								:regFactu.tarifa,
								:regFactu.fecha_facturacion;		
		
		if(i>12)
			salida=1;
	}
	
	$CLOSE curFacturas;
	
	strcpy(regIns->fecha_vig_tarifa, sFecha);
	
	return 1;
}

short GenerarPlano(fp, regIns)
FILE 				*fp;
$ClsInstalacion		regIns;
{

	/* KEY */	
	GeneraKEY(fp, regIns);

	/* DATA */	
	GeneraDATA(fp, regIns);	
	
	/* ENDE */
	GeneraENDE(fp, regIns);
	
	return 1;
}

void GeneraENDE(fp, regIns)
FILE *fp;
$ClsInstalacion	regIns;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regIns.numero_cliente);

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
		strcpy(sTipoArchivo, "INSTAL");
		strcpy(sNombreArchivo, sSoloArchivoInstalacion);
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
short RegistraCliente(nroCliente, sFechaVigencia, lFechaPivote, sFechaAlta, iFlagMigra)
$long	nroCliente;
char	sFechaVigencia[9];
$long lFechaPivote;
char  sFechaAlta[9];
int	iFlagMigra;
{
	$long	lFechaVigencia;
   $long lFechaAlta;
	
	rdefmtdate(&lFechaVigencia, "yyyymmdd", sFechaVigencia); /*char a long*/
   rdefmtdate(&lFechaAlta, "yyyymmdd", sFechaAlta); /*char a long*/
	
	if(iFlagMigra==1){
      $EXECUTE insClientesMigra using :nroCliente, :lFechaVigencia, :lFechaAlta, :lFechaPivote;
	}else{
      $EXECUTE updClientesMigra using :lFechaVigencia, :lFechaAlta, :lFechaPivote, :nroCliente;
	}

	return 1;
}

void GeneraKEY(fp, regIns)
FILE 		*fp;
ClsInstalacion	regIns;
{
	char	sLinea[1000];	
   int   iRcv;
   	
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
	sprintf(sLinea, "T1%ld\tKEY\t", regIns.numero_cliente);
   
   /* ANLAGE */
   /*sprintf(sLinea, "%s%s\t", sLinea, regIns.sPod);*/
   /*sprintf(sLinea, "%s%ldAR\t", sLinea, regIns.numero_cliente);*/
   sprintf(sLinea, "%s%ld\t", sLinea, regIns.numero_cliente);
   
   /* BIS */
	strcat(sLinea, "99991231");
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir KEY\n");
      exit(1);
   }	
	
	
}

void GeneraDATA(fp, regIns)
FILE 			*fp;
ClsInstalacion	regIns;
{
	char	sLinea[1000];	
   long  lFechaAlta;
   long  lFechaRti;
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
   /* LLAVE */
	sprintf(sLinea, "T1%ld\tDATA\t", regIns.numero_cliente);
   
   /* SPARTE */
	strcat(sLinea, "01\t");
   /* VSTELLE */
	sprintf(sLinea, "%sT1%ld\t", sLinea, regIns.numero_cliente);
   
   /* ABLSPERR */
   if(strcmp(regIns.cod_ul, "Plan81")==0 || strcmp(regIns.cod_ul, "Plan82")==0){
      strcat(sLinea, "04\t");
   }else{
      strcat(sLinea, "\t");
   } 
	
   /* BAPERTYP */
   strcat(sLinea, "\t");
   /* SPEBENE */
	if(strcmp(regIns.codigo_voltaje, "00")!=0){
		sprintf(sLinea, "%s%s\t", sLinea, regIns.codigo_voltaje);
	}else{
		strcat(sLinea, "\t");	
	}
   /* ANLART */
	strcat(sLinea, "0007\t"); /* Clase de Instalación - Ex-T1*/
   /* ABLESARTST */
	strcat(sLinea, "\t");
   /* NODISCONCT */
	if(strcmp(regIns.catego_electrodependiente, "")==0){
		strcat(sLinea, "\t");			
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.catego_electrodependiente);
	}
   /* AB */
	sprintf(sLinea, "%s%s\t", sLinea, regIns.fecha_vig_tarifa);
/*
	sprintf(sLinea, "%s%s\t", sLinea, regIns.fecha_instalacion);
*/	

   /* TARIFTYP*/
   lFechaAlta = atol(regIns.sFechaAltaReal);
   lFechaRti = atol(sFechaRTI);
   /*
   if(lFechaAlta > lFechaRti ){
      sprintf(sLinea, "%s%s\t", sLinea, regIns.tarifa);
   }else{
      strcat(sLinea, "DUMMY\t");
   }
	*/
   sprintf(sLinea, "%s%s\t", sLinea, regIns.tarifa);
   
   /* BRANCHE */
	sprintf(sLinea, "%s%s\t", sLinea, regIns.actividad_economic);
	/* AKLASSE */
	strcat(sLinea, "EDE\t");
   /* ABLEINH */
	sprintf(sLinea, "%s%s\t", sLinea, regIns.cod_ul);
   /* ERDAT */
	/*sprintf(sLinea, "%s%s\t", sLinea, regIns.fecha_instalacion);*/
   strcat(sLinea, "\t");
   
   /* BEGRU + ETIMEZONE */
	strcat(sLinea, "T1\tUTC-3");
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir DATA\n");
      exit(1);
   }	

}

/*
short CargaIdSF(reg)
$ClsInstalacion *reg;
{
   $char sValor[21];
   
   memset(sValor, '\0', sizeof(sValor));
   
   $EXECUTE selPod INTO :sValor USING :reg->numero_cliente;
   
   if(SQLCODE != 0){
      return 0;
   }

   alltrim(sValor, ' ');
   strcpy(reg->sPod, sValor);   

   return 1;
}
*/
void CargaLimiteInferior(void){
char  sFecha[11];

   strcpy(sFecha, "20141201");
   
   rdefmtdate(&lFechaLimiteInferior, "yyyymmdd", sFecha); /*char a long*/

}

short CargaTarifaInstal(reg, lFechaMoveIn)
$ClsInstalacion *reg;
$long             lFechaMoveIn;
{
   $long lFechaAlta;
   $long lCorr;
/*   
   rdefmtdate(&lFechaAlta, "yyyymmdd", reg->fecha_vig_tarifa); // char a long
*/
   $EXECUTE selTarifInstal INTO :reg->tarifa, :reg->cod_ul, :lCorr 
                           USING :reg->numero_cliente, :lFechaMoveIn;  /*:lFechaPivote;*/

   if(SQLCODE != 0){
      if(SQLCODE == 100){
         $EXECUTE selTarifInstal2 INTO :reg->tarifa, :reg->cod_ul, :lCorr 
                                 USING :reg->numero_cliente;
      
      }else{ 
         return 0;
      }
   }
                                 
   return 1;
}

void  InicializaEstados(reg)
ClsEstados  *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_val_tarifa));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_alta_real));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_move_in));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_pivote));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->ul, '\0', sizeof(reg->ul));
   memset(reg->motivo_alta, '\0', sizeof(reg->motivo_alta));
}

void CargaCalculados(regIns, regSts)
ClsInstalacion *regIns;
ClsEstados     regSts;
{

   rfmtdate(regSts.fecha_val_tarifa, "yyyymmdd", regIns->fecha_vig_tarifa); /* long to char */
   strcpy(regIns->fecha_instalacion, regIns->fecha_vig_tarifa);

   alltrim(regSts.tarifa, ' ');
   alltrim(regSts.ul, ' ');
   strcpy(regIns->tarifa, regSts.tarifa);
   strcpy(regIns->cod_ul, regSts.ul);
   
   rfmtdate(regSts.fecha_alta_real, "yyyymmdd", regIns->sFechaAltaReal); /* long to char */
}

void GenerarZZ(fp, regIns)
FILE 			    *fp;
ClsInstalacion	 regIns;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
   /* LLAVE */
	sprintf(sLinea, "T1%ld\t", regIns.numero_cliente);

   /* ZZ_SUBESTACION */
	if(strcmp(regIns.nro_subestacion, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.nro_subestacion);
	}
   /* ZZ_NOM_SUBESTACION */
	if(strcmp(regIns.tec_nom_subest, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_nom_subest);
	}
   /* ZZ_ALIMENTADOR */
	if(strcmp(regIns.tec_alimentador, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_alimentador);
	}
   /* ZZ_CENTROTRASFORMACION */
	if(strcmp(regIns.tec_centro_trans, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_centro_trans);
	}
   /* ZZ_FASE */
	if(strcmp(regIns.tec_fase, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_fase);
	}
	/* ZZ_ACOMETIDA */
	sprintf(sLinea, "%s%d\t", sLinea, regIns.tec_acometida);
	/* ZZ_TIPOINSTALACION */
	if(strcmp(regIns.tec_tipo_instala, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_tipo_instala);
	}
   /* ZZ_NOMCALLE */
	if(strcmp(regIns.tec_nom_calle, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_nom_calle);
	}
   /* ZZ_NRODIR */			
	if(strcmp(regIns.tec_nro_dir, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_nro_dir);
	}
   /* ZZ_PISODIR */
	if(strcmp(regIns.tec_piso_dir, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_piso_dir);
	}
   /* ZZ_DPTODIR */
	if(strcmp(regIns.tec_depto_dir, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_depto_dir);
	}
   /* ZZ_ENTRECALLE1 */
	if(strcmp(regIns.tec_entre_calle1, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_entre_calle1);
	}
   /* ZZ_ENTRECALLE2 */	
	if(strcmp(regIns.tec_entre_calle2, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_entre_calle2);
	}
   /* ZZ_MANZANA */
	if(strcmp(regIns.tec_manzana, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_manzana);
	}
   /* ZZ_BARRIO */
	if(strcmp(regIns.tec_barrio, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_barrio);
	}
   /* ZZ_LOCALIDAD */
	if(strcmp(regIns.tec_localidad, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_localidad);
	}
   /* ZZ_PARTIDO */
	if(strcmp(regIns.tec_partido, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_partido);
	}
   /* ZZ_SUCURSAL */
	if(strcmp(regIns.tec_sucursal, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tec_sucursal);
	}
   /* ZZ_X */
	sprintf(sLinea, "%s%f\t", sLinea, regIns.ubi_x);
   /* ZZ_Y */
	sprintf(sLinea, "%s%f\t", sLinea, regIns.ubi_y);
   /* ZZ_LATITUD */
	sprintf(sLinea, "%s%f\t", sLinea, regIns.ubi_lat);
   /* ZZ_LONGITUD */
	sprintf(sLinea, "%s%f\t", sLinea, regIns.ubi_long);
   /* ZZ_POTENCIA */
	sprintf(sLinea, "%s%f\t", sLinea, regIns.potencia_inst_fp);
   /* ZZ_TIPOOBRA */
	if(strcmp(regIns.tipo_obra, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tipo_obra);
	}
   /* ZZ_TOMA */	
	if(strcmp(regIns.toma, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.toma);
	}
   /* ZZ_CONEXION */	
	if(strcmp(regIns.tipo_conexion, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.tipo_conexion);
	}
   /* ZZ_EACOMETIDA */
	if(strcmp(regIns.acometida, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.acometida);
	}
   /* ZZ_CANTCONEX */
	sprintf(sLinea, "%s%d\t", sLinea, regIns.cantidad_medidores);
   /* ZZ_FASENEUTRO */
	if(strcmp(regIns.fase_neutro, "")==0){
		strcat(sLinea, "\t");
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regIns.fase_neutro);
	}
   /* ZZ_NEUTROMETAL */	
	if(strcmp(regIns.neutro_metal, "")!=0){
		sprintf(sLinea, "%s%s\t", sLinea, regIns.neutro_metal);
	}else{
      strcat(sLinea, "\t");         
   }	

   /* ZZSEC_LECT */
   sprintf(sLinea, "%s%ld", sLinea, regIns.correlativo_ruta);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ZZ\n");
      exit(1);
   }	


}

long getFechaMoveIn(reg)
$ClsInstalacion   reg;
{
   long  lFechaAlta;
   $long lFecha=0;

   rdefmtdate(&lFechaAlta, "yyyymmdd", reg.sFechaAltaReal);

   /*$EXECUTE selMoveIn INTO :lFecha USING :reg.numero_cliente, :lFechaRti;*/
   
   if(lFechaAlta < lFechaPivote ){
      $EXECUTE selMoveIn INTO :lFecha USING :reg.numero_cliente, :lFechaPivote;
   }else{
      $EXECUTE selMoveIn2 INTO :lFecha USING :reg.numero_cliente, :lFechaPivote;
   }
   
   if(SQLCODE != 0){
      lFecha = lFechaPivote;
   }

   if(lFecha<=0 || risnull(CLONGTYPE, (char *) &lFecha)){
      lFecha = lFechaPivote; 
   }

   return lFecha;
   

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

