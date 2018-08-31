/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_instalacion
    
	Fecha : 12/10/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructuras MONTAJE  DESMONTAJE
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Clientes>: 0 = Activos; 1 = No Activos; 2=Todos
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_montaje_desmontaje.h";

/* Variables Globales */
$long	glNroCliente;
$char	gsTipoGenera[2];
int	giEstadoCliente;
int   giMovimientos;
int   giTipoCorrida;

FILE  *pFileGral;
FILE  *pFileMontajeReal;

char	sArchGralUnx[100];
char	sSoloArchivoGral[100];

char	sArchMontajeRealUnx[100];
char	sSoloArchivoMontajeReal[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long	cantMontajes;
long	cantDesmontajes;
long 	cantPreexistente;
long	cantMontajesReal;

int     iNroIndex;

/* Variables Globales Host */
$ClsLecturas	regLectu;
$long	lFechaLimiteInferior;
$int	iCorrelativos;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$long	   lNroCliente;
$long    lCorrFactuActual;
$long	   lCorrFactuInicio;
int		iNx;
$ClsLecturas	  regLectu2;
$char		sFechaFactura[9];
$long		lFechaFactura;
int		iSuperaMedid;
long	   lCantOperaciones;
long	   lMaxTrx;
$long    lFechaMoveIn;
$long    lFechaPivote;
$long    lFechaAlta;      

$long    lNroMedidorActual;
$char    sMarcaMedidorActual[4];
$char    sModeloMedidorActual[3];

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

	$EXECUTE selCorrelativos into :iCorrelativos;
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */

	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantMontajes=0;
	cantDesmontajes=0;
	cantPreexistente=0;
	cantMontajesReal=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

	if(glNroCliente > 0){
		$OPEN curClientes using :glNroCliente;
	}else{
		$OPEN curClientes;
	}

	while(LeoClientes(&lNroCliente, &lCorrFactuActual)){
		iSuperaMedid=0;
		
		iSuperaMedid=EncontroMedid(lNroCliente);

		if(!ClienteYaMigrado(lNroCliente, &iFlagMigra, &lFechaMoveIn, &lFechaPivote, &lFechaAlta) && iSuperaMedid==1 ){
			iNx=0;
			iNroIndex=1;
         
         if(giMovimientos==1){
            memset(sMarcaMedidorActual, '\0', sizeof(sMarcaMedidorActual));
            memset(sModeloMedidorActual, '\0', sizeof(sModeloMedidorActual));
            
            lNroMedidorActual = getMedidorActual(lNroCliente, sMarcaMedidorActual, sModeloMedidorActual);
         }
                  
         /*$BEGIN WORK;*/
			if(lCorrFactuActual > 0){

				/*if(LeoPrimerMontajeReal(lNroCliente, lFechaValTarifa, &regLectu)){*/
            if(LeoPrimerMontajeReal(lNroCliente, lFechaPivote, &regLectu)){
					GeneraMontajeReal(regLectu);
					cantMontajesReal++;
				}else{
					if(LeoUltInstalacion(lNroCliente, lFechaMoveIn, &regLectu)){	
						GeneraMontajeReal(regLectu);
						cantMontajesReal++;
					}
				}
				
				/*if(LeoPrimeraLectura(lNroCliente, lFechaValTarifa, &regLectu)){*/
            if(lFechaAlta < lFechaPivote ){
               if(LeoPrimeraLectura(lNroCliente, lFechaPivote, lFechaMoveIn, &regLectu)){
                  if (!GenerarPlanos(regLectu)){
                  	/*$ROLLBACK WORK;*/
                  	exit(2);
                  }
                  iNx++;				
                  iNroIndex++;
               }
 				}
	
            if(giMovimientos==1){
				/*$OPEN curLecturas using :lNroCliente, :lFechaValTarifa;*/
               $OPEN curLecturas using :lNroCliente, :lFechaPivote;
   				while(LeoLecturas(&regLectu) ){
                  /*if(!EsMedidorVigente(lNroMedidorActual, sMarcaMedidorActual, sModeloMedidorActual, regLectu)){*/
      					if (!GenerarPlanos(regLectu)){
      						/*$ROLLBACK WORK;*/
      						exit(2);
      					}			
      					iNroIndex++;
      					iNx++;
                  /*}*/
   				}
   				$CLOSE curLecturas;
            }
			}
			if(giMovimientos==1){
   			if(iNx==0){
   				/* CUANDO NO ENCONTRE MOVIMIENTOS EN El Periodo */
   				
   				/* hay algunos que no tuvieron factura despues del cambio de medidor */
   				/*$OPEN curSinFactura using :lNroCliente,:lFechaValTarifa;*/
               $OPEN curSinFactura using :lNroCliente,:lFechaPivote;
   				
   				if(LeoSinFactura(lFechaMoveIn, &regLectu)){
   					if (!GenerarPlanos(regLectu)){
   						/*$ROLLBACK WORK;*/
   						exit(2);
   					}				
   					iNx++;
   				}
   					
   				$CLOSE curSinFactura;
   				
   				if(iNx==0){
   					if(!LeoUltInstalacion(lNroCliente, lFechaMoveIn, &regLectu)){
   						/*$ROLLBACK WORK;*/
   						exit(2);
   					}				
   					if (!GenerarPlanos(regLectu)){
   						/*$ROLLBACK WORK;*/
   						exit(2);
   					}
   				}
   								
   				if(giEstadoCliente==1){
   					if(LeoUltRetiro(lNroCliente, &regLectu)){
   						if (!GenerarPlanos(regLectu)){
   							/*$ROLLBACK WORK;*/
   							exit(2);
   						}
   					}
   				}				
   			}
         }         
/*         
			if(!RegistraCliente(lNroCliente, iFlagMigra)){
				exit(2);	
			}
*/
         
			cantProcesada++;			
		}else{
			cantPreexistente++;
		}
	}
	$CLOSE curClientes;
				
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
	printf("MONTAJE - DESMONTAJE.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Montajes Procesados :       %ld \n",cantMontajes);
	printf("Desmontajes Procesados :    %ld \n",cantDesmontajes);
	printf("Clientes Preexistentes :    %ld \n",cantPreexistente);
	printf("Montajes Cambiados :        %ld \n",cantMontajesReal);
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

	if(argc < 6 || argc > 7){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));
	
	giEstadoCliente=atoi(argv[2]);
	strcpy(gsTipoGenera, argv[3]);
	giMovimientos=atoi(argv[4]);
   giTipoCorrida=atoi(argv[5]);
   
	if(argc==7){
		glNroCliente=atoi(argv[6]);
	}else{
		glNroCliente=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("\t<Base> = synergia.\n");
		printf("\t<Estado Cliente> 0=Activos; 1=No Activos\n");
		printf("\t<Tipo Generación> G = Generación, R = Regeneración.\n");
      printf("\t<Tipo Frecuencia> 0=Sin Movimientos; 1=Con Movimientos\n");
      printf("\t<Tipo Corrida> 0=Normal; 1=Reducida\n");
		printf("\t<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos()
{
	char	sTipoArchivo[50];
	
	memset(sArchGralUnx,'\0',sizeof(sArchGralUnx));
	memset(sSoloArchivoGral,'\0',sizeof(sSoloArchivoGral));

	memset(sArchMontajeRealUnx,'\0',sizeof(sArchMontajeRealUnx));
	memset(sSoloArchivoMontajeReal,'\0',sizeof(sSoloArchivoMontajeReal));

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	memset(sTipoArchivo, '\0', sizeof(sTipoArchivo));
	
	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	if(giEstadoCliente==0){
		strcpy(sTipoArchivo, "Activos");
	}else{
		strcpy(sTipoArchivo, "NoActivos");
	}

   if(giMovimientos==0){
      strcat(sTipoArchivo, "_SinMovim");
   }else{
      strcat(sTipoArchivo, "_ConMovim");
   }
   
   alltrim(sTipoArchivo, ' ');
   
   /* Archivo General */
	sprintf( sArchGralUnx  , "%sT1MONTA_%s.unx", sPathSalida, sTipoArchivo);
	sprintf( sSoloArchivoGral, "T1MONTA_%s.unx", sTipoArchivo);

	pFileGral=fopen( sArchGralUnx, "w" );
	if( !pFileGral ){
		printf("ERROR al abrir archivo %s.\n", sArchGralUnx );
		return 0;
	}

	/* Archivo de Fechas Reales de Montaje */
	sprintf( sArchMontajeRealUnx  , "%sMontajeReal_%s_T1.unx", sPathSalida, sTipoArchivo);
	sprintf( sSoloArchivoMontajeReal, "MontajeReal_%s_T1.txt", sTipoArchivo);

	pFileMontajeReal=fopen( sArchMontajeRealUnx, "w" );
	if( !pFileMontajeReal ){
		printf("ERROR al abrir archivo %s.\n", sArchMontajeRealUnx );
		return 0;
	}
		
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileGral);
	fclose(pFileMontajeReal);
}

void FormateaArchivos(void){
char	sCommand[1000];
char	sDestino[100];
int		iRcv, i;
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sDestino, '\0', sizeof(sDestino));

	if(giEstadoCliente==0){		
		/*strcpy(sDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sDestino, "%sActivos/Montajes/", sPathCopia);
	}else{
		/*strcpy(sDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sDestino, "%sInactivos/", sPathCopia);
	}

	if(cantProcesada>0){
		sprintf(sCommand, "chmod 755 %s", sArchGralUnx);
		iRcv=system(sCommand);
		
		sprintf(sCommand, "cp %s %s", sArchGralUnx, sDestino);
		iRcv=system(sCommand);

	}

	if(cantMontajesReal > 0){
		sprintf(sCommand, "chmod 755 %s", sArchMontajeRealUnx);
		iRcv=system(sCommand);
				
		sprintf(sCommand, "cp %s %s", sArchMontajeRealUnx, sDestino);
		iRcv=system(sCommand);		
	}

/*
	if(cantProcesada>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchMontajeUnx, sArchMontajeDos);
		iRcv=system(sCommand);

		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchDesmontajeUnx, sArchDesmontajeDos);
		iRcv=system(sCommand);		
	}

	if(cantMontajesReal > 0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchMontajeRealUnx, sArchMontajeRealDos);
		iRcv=system(sCommand);		
	}

	sprintf(sCommand, "rm -f %s", sArchMontajeUnx);
	iRcv=system(sCommand);	

	sprintf(sCommand, "rm -f %s", sArchDesmontajeUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "rm -f %s", sArchMontajeRealUnx);
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

	/******** Cursor Clientes  ****************/
	strcpy(sql, "SELECT c.numero_cliente, NVL(c.corr_facturacion, 0) FROM cliente c ");

   if(giTipoCorrida==1){
      strcat(sql, ", migra_activos mg ");
   }   
   if(giMovimientos==1){
      strcat(sql, ", sap_cambio_medid ma ");
   }

   if(giEstadoCliente!=0){
   	strcat(sql, ", sap_inactivos si ");
   }

	if(glNroCliente != -1){
		strcat(sql, "WHERE c.numero_cliente = ? ");
	}else{
		if(giEstadoCliente==0){
			strcat(sql, "WHERE c.estado_cliente = 0 ");
			strcat(sql,"AND c.tipo_sum != 5 ");
		}else if(giEstadoCliente==1){
			strcat(sql, "WHERE c.estado_cliente != 0 ");
			strcat(sql,"AND c.tipo_sum != 5 ");
		}else{
			strcat(sql,"WHERE c.tipo_sum != 5 ");	
		}
	}

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");

   if(giMovimientos==1){
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
   }else{
      strcat(sql, "AND NOT EXISTS (SELECT 1 FROM sap_cambio_medid ma ");
      strcat(sql, "	WHERE ma.numero_cliente = c.numero_cliente) ");
   }
   	
   if(giTipoCorrida==1){
      strcat(sql, "AND mg.numero_cliente = c.numero_cliente ");
   }
   
	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /************ Ultimo Medidor del Cliente **********/
	strcpy(sql, "SELECT h.numero_medidor, h.marca_medidor, m.modelo_medidor ");
	strcat(sql, "FROM hislec h, medid m ");
	strcat(sql, "WHERE h.numero_cliente = ? ");
	strcat(sql, "AND h.fecha_lectura = (SELECT MAX(h2.fecha_lectura) ");
	strcat(sql, "	FROM hislec h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h.numero_cliente) ");
	strcat(sql, "AND m.numero_cliente = h.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = h.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = h.marca_medidor ");

	$PREPARE selUltMedidor FROM $sql;
   
   $DECLARE curUltMedidor CURSOR FOR selUltMedidor;
   
	/******** Cursor Lecturas  ****************/	
	strcpy(sql, "SELECT la.numero_cliente, ");
	strcat(sql, "la.corr_facturacion, ");
	strcat(sql, "la.numero_medidor, ");
	strcat(sql, "la.marca_medidor, ");
	strcat(sql, "la.lectura_facturac, ");
	strcat(sql, "la.lectura_terreno, ");
   strcat(sql, "la.consumo, "); 
	strcat(sql, "la.fecha_lectura, ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN la.tipo_lectura = 6 THEN TO_CHAR(la.fecha_lectura, '%Y%m%d') ");
	strcat(sql, "	ELSE TO_CHAR(la.fecha_lectura, '%Y%m%d') ");
	strcat(sql, "END, ");
/*
	strcat(sql, "TO_CHAR(la.fecha_lectura, '%Y%m%d'), ");
*/	
	strcat(sql, "la.tipo_lectura, ");
	strcat(sql, "m.modelo_medidor, ");

	strcat(sql, "CASE ");
   strcat(sql, "	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "h.indica_refact, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");

	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");
	
	strcat(sql, "FROM hislec la, cliente c, hisfac h, medid m, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE la.numero_cliente = ? ");
	strcat(sql, "AND la.fecha_lectura > ? ");
	/*
	strcat(sql, "AND la.corr_facturacion > ? ");
   */
	strcat(sql, "AND la.tipo_lectura IN (5, 6, 7) ");
	strcat(sql, "AND c.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND h.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND h.corr_facturacion = la.corr_facturacion ");
	strcat(sql, "AND m.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = la.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = la.marca_medidor ");
	
	strcat(sql, "AND me.mar_codigo = la.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = la.numero_medidor ");
	
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h.tarifa ");
	strcat(sql, "ORDER BY la.fecha_lectura, la.tipo_lectura ASC ");
	
	$PREPARE selLecturas FROM $sql;
	
	$DECLARE curLecturas CURSOR FOR selLecturas;	

	/******** Fecha Primera Factura a Migrar *********/
/*	
	strcpy(sql, "SELECT TO_CHAR(MIN(h.fecha_facturacion), '%Y%m%d') ");
	strcat(sql, "FROM hisfac h, cliente c ");
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND fecha_facturacion >= ? ");
	strcat(sql, "AND h.corr_facturacion >= c.corr_facturacion - ? ");
*/

	strcpy(sql, "SELECT TO_CHAR(fecha_facturacion, '%Y%m%d'), fecha_facturacion FROM hisfac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");

	$PREPARE selFechaFactura FROM $sql;

	/************ Primera Lectura Instalacion ******************/
	strcpy(sql, "SELECT la.numero_cliente, ");
	strcat(sql, "la.corr_facturacion, ");
	strcat(sql, "la.numero_medidor, ");
	strcat(sql, "la.marca_medidor, ");
	strcat(sql, "la.lectura_facturac, ");
	strcat(sql, "la.lectura_terreno, ");
   strcat(sql, "la.consumo, ");
	strcat(sql, "la.fecha_lectura, ");
	strcat(sql, "TO_CHAR(la.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "la.tipo_lectura, ");
	strcat(sql, "m.modelo_medidor, ");

	strcat(sql, "CASE ");
   strcat(sql, "	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");   
	strcat(sql, "	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "'N', ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");

	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");
/*   
	strcat(sql, "MAX(la.fecha_lectura) ");
*/	
	strcat(sql, "FROM hislec la, cliente c, hisfac h, medid m, OUTER sap_transforma t1, medidor me ");
	strcat(sql, "WHERE la.numero_cliente = ? ");

	strcat(sql, "AND la.fecha_lectura = (	SELECT MIN(h2.fecha_lectura) FROM hislec h2 ");
	strcat(sql, "   WHERE h2.numero_cliente = la.numero_cliente ");
	strcat(sql, "   AND h2.tipo_lectura IN (1,2,3,4) "); 
	strcat(sql, "   AND h2.fecha_lectura >= ?) ");
/*
   strcat(sql, "AND la.fecha_lectura = ? ");
*/
	strcat(sql, "AND la.tipo_lectura IN (1,2,3,4) ");
	strcat(sql, "AND c.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.corr_facturacion = la.corr_facturacion ");
	strcat(sql, "AND m.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = la.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = la.marca_medidor ");

	strcat(sql, "AND (m.fecha_prim_insta = (SELECT MAX(m2.fecha_prim_insta) ");
	strcat(sql, "	FROM medid m2 ");
	strcat(sql, " 	WHERE m2.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m2.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m2.marca_medidor = m.marca_medidor) ");
	strcat(sql, "  OR m.fecha_prim_insta IS NULL) ");
	
	strcat(sql, "AND (m.fecha_ult_insta = (SELECT MAX(m3.fecha_ult_insta) ");
	strcat(sql, "	FROM medid m3 ");
	strcat(sql, " 	WHERE m3.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m3.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m3.marca_medidor = m.marca_medidor) ");
	strcat(sql, "  OR m.fecha_ult_insta IS NULL) ");	
	
	strcat(sql, "AND me.mar_codigo = la.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = la.numero_medidor ");
		
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h.tarifa ");
/*   
	strcat(sql, "GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17 ");
*/	
	$PREPARE selPrimLectu FROM $sql;	
	
	$DECLARE curPrimLectu CURSOR FOR selPrimLectu;
	
	/*********** Cambio sin factura *************/
	strcpy(sql, "SELECT la.numero_cliente, ");
	strcat(sql, "la.corr_facturacion, ");
	strcat(sql, "la.numero_medidor, ");
	strcat(sql, "la.marca_medidor, ");
	strcat(sql, "la.lectura_facturac, ");
	strcat(sql, "la.lectura_terreno, ");
   strcat(sql, "la.consumo, ");
	strcat(sql, "la.fecha_lectura, ");
	strcat(sql, "TO_CHAR(la.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "la.tipo_lectura, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");   
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	strcat(sql, "'N', ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales, ");
	strcat(sql, "la.fecha_lectura ");
	strcat(sql, "FROM hislec la, cliente c, medid m, OUTER sap_transforma t1, medidor me ");
	strcat(sql, "WHERE la.numero_cliente = ? ");
	strcat(sql, "AND la.fecha_lectura > ? ");
	strcat(sql, "AND la.tipo_lectura IN (6, 7) ");
	strcat(sql, "AND c.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = la.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = la.marca_medidor ");
	strcat(sql, "AND m.fecha_prim_insta = (SELECT MAX(m2.fecha_prim_insta) ");
	strcat(sql, "	FROM medid m2 ");
	strcat(sql, " 	WHERE m2.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m2.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m2.marca_medidor = m.marca_medidor) ");
	strcat(sql, "AND m.fecha_ult_insta = (SELECT MAX(m3.fecha_ult_insta) ");
	strcat(sql, "	FROM medid m3 ");
	strcat(sql, " 	WHERE m3.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m3.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m3.marca_medidor = m.marca_medidor) ");
	strcat(sql, "AND me.mar_codigo = la.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = la.numero_medidor ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");

	$PREPARE selSinFactura FROM $sql;
	
	$DECLARE curSinFactura CURSOR for selSinFactura;

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
	strcat(sql, "?, ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Montaje Cliente ya migrado **********/
	strcpy(sql, "SELECT montaje, fecha_move_in, fecha_pivote, fecha_alta_real FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigradoM FROM $sql;

	/********* Select Desmontaje Cliente ya migrado **********/
	strcpy(sql, "SELECT desmontaje FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigradoD FROM $sql;
	
	/*********Insert Clientes extraidos Montaje **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, montaje ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigraM FROM $sql;

	/*********Insert Clientes extraidos Desontaje **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, desmontaje ");
	strcat(sql, ")VALUES(?, 'S') ");
	
	$PREPARE insClientesMigraD FROM $sql;
		
	/************ Update Clientes Migra Montaje**************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "montaje = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigraM FROM $sql;

	/************ Update Clientes Migra Desmontaje**************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "desmontaje = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigraD FROM $sql;

	/************* Lectura Activa Rectificada ***********/
	strcpy(sql, "SELECT FIRST 1 h1.lectura_rectif, h1.consumo_rectif ");
	strcat(sql, "FROM hislec_refac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_refacturacion = (SELECT MAX(h2.corr_refacturacion) ");
	strcat(sql, "	FROM hislec_refac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura) ");
   	
   	$PREPARE selActivaRectif FROM $sql;

	/************* Lectura Reactiva Rectificada ***********/
	strcpy(sql, "SELECT FIRST 1 h1.lectu_rectif_reac, h1.consu_rectif_reac ");
	strcat(sql, "FROM hislec_refac_reac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_refacturacion = (SELECT MAX(h2.corr_refacturacion) ");
	strcat(sql, "	FROM hislec_refac_reac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
   	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura) ");
   	
   	$PREPARE selReactivaRectif FROM $sql;

	/************* Lectura Reactiva ***********/
	strcpy(sql, "SELECT DISTINCT h1.lectu_factu_reac, lectu_terreno_reac ");
	strcat(sql, "FROM hislec_reac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.fecha_lectura = (SELECT MAX(h2.fecha_lectura) FROM hislec_reac h2 ");
	strcat(sql, "	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "	AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "	AND h2.tipo_lectura = h1.tipo_lectura) ");
   	
   	$PREPARE selLectuReactiva FROM $sql;
   	   	
	/************ Busca Instalacion en Medid **************/
	strcpy(sql, "SELECT m.numero_cliente, ");
	strcat(sql, "m.numero_medidor, ");
	strcat(sql, "m.marca_medidor, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924'),");
	strcat(sql, "m.lectura_instal, ");
	strcat(sql, "m.lectu_instal_reac, ");
   strcat(sql, "m.consumo_30_dias,");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");

	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");	
	strcat(sql, "END, ");	

	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");
	
	strcat(sql, "FROM medid m, cliente c, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.estado = 'I' ");
	strcat(sql, "AND c.numero_cliente = m.numero_cliente ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");	

	strcat(sql, "AND me.mar_codigo = m.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = m.numero_medidor ");

	$PREPARE selMedid FROM $sql;

	/************ Busca Instalacion 2 en Medid **************/
	strcpy(sql, "SELECT first 1 m1.numero_cliente, ");
	strcat(sql, "m1.numero_medidor, ");
	strcat(sql, "m1.marca_medidor, ");
	strcat(sql, "m1.modelo_medidor, ");
	strcat(sql, "NVL(TO_CHAR(m1.fecha_ult_insta, '%Y%m%d'), '19950924'),");
	strcat(sql, "m1.lectura_instal, ");
	strcat(sql, "m1.lectu_instal_reac, ");
   strcat(sql, "m1.consumo_30_dias,");
	strcat(sql, "NVL(m1.tipo_medidor, 'A'), ");
	
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");

	strcat(sql, "me.med_factor, ");
	strcat(sql, "m1.enteros, ");
	strcat(sql, "m1.decimales ");
		
	strcat(sql, "FROM medid m1, cliente c, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE m1.numero_cliente = ? ");
	strcat(sql, "AND (m1.fecha_prim_insta = (SELECT MAX(m2.fecha_prim_insta) FROM medid m2 ");
	strcat(sql, "   WHERE m2.numero_cliente = m1.numero_cliente) ");
	strcat(sql, "		OR m1.fecha_prim_insta IS NULL ) ");	

	strcat(sql, "AND (m1.fecha_ult_insta = (SELECT MAX(m3.fecha_ult_insta) ");
	strcat(sql, "	FROM medid m3 ");
	strcat(sql, " 	WHERE m3.numero_cliente = m1.numero_cliente ");
	strcat(sql, "   AND m3.numero_medidor = m1.numero_medidor ");
	strcat(sql, "   AND m3.marca_medidor = m1.marca_medidor) ");
	strcat(sql, "		OR m1.fecha_ult_insta IS NULL ) ");	
			
	strcat(sql, "AND c.numero_cliente = m1.numero_cliente ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");		

	strcat(sql, "AND me.mar_codigo = m1.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m1.modelo_medidor ");
	strcat(sql, "AND me.med_numero = m1.numero_medidor ");
		
	$PREPARE selMedid2 FROM $sql;

	/************ Busca Instalacion en Hislec**************/
	strcpy(sql, "SELECT m.numero_cliente, ");
	strcat(sql, "m.numero_medidor, ");
	strcat(sql, "m.marca_medidor, ");
	strcat(sql, "m.modelo_medidor, ");
	strcat(sql, "NVL(TO_CHAR(m.fecha_ult_insta, '%Y%m%d'), '19950924'),");
	strcat(sql, "m.lectura_instal, ");
	strcat(sql, "m.lectu_instal_reac, ");
	strcat(sql, "m.tipo_medidor, ");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");   
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");
		
	strcat(sql, "FROM medid m, cliente c, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
	strcat(sql, "AND m.numero_medidor = ? ");
	strcat(sql, "AND m.marca_medidor = ? ");
	strcat(sql, "AND m.modelo_medidor = ? ");
	strcat(sql, "AND c.numero_cliente = m.numero_cliente ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");	

	strcat(sql, "AND me.mar_codigo = m.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = m.numero_medidor ");
		
	$PREPARE selLectuInstal FROM $sql;
	
	/********** Ultimo Retiro ********/
	strcpy(sql, "SELECT first 1 la.numero_cliente,");
	strcat(sql, "la.corr_facturacion,");
	strcat(sql, "la.numero_medidor,");
	strcat(sql, "la.marca_medidor,");
	strcat(sql, "la.lectura_facturac,");
	strcat(sql, "la.lectura_terreno,");
   strcat(sql, "la.consumo, ");
	strcat(sql, "la.fecha_lectura,");
	strcat(sql, "TO_CHAR(la.fecha_lectura, '%Y%m%d'),");
	strcat(sql, "la.tipo_lectura,");
	strcat(sql, "m.modelo_medidor,");
	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	strcat(sql, "NVL(m.tipo_medidor, 'A'), ");
	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");	
	strcat(sql, "FROM hislec la, cliente c, medid m, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE la.numero_cliente = ? ");
	strcat(sql, "AND la.fecha_lectura = (SELECT MAX(la2.fecha_lectura) FROM hislec la2 ");
	strcat(sql, "	WHERE la2.numero_cliente = la.numero_cliente ");
	strcat(sql, "	AND la2.tipo_lectura = 5) ");
	strcat(sql, "AND la.tipo_lectura = 5 ");
	strcat(sql, "AND c.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = la.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = la.marca_medidor ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = c.tarifa ");
	strcat(sql, "AND me.mar_codigo = la.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = la.numero_medidor ");	
	
	$PREPARE selLectuRetiro FROM $sql;

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


	/******** Montaje Real  ****************/	
	strcpy(sql, "SELECT la.numero_cliente, ");
	strcat(sql, "la.corr_facturacion, ");
	strcat(sql, "la.numero_medidor, ");
	strcat(sql, "la.marca_medidor, ");
	strcat(sql, "la.lectura_facturac, ");
	strcat(sql, "la.lectura_terreno, ");
	strcat(sql, "la.fecha_lectura, ");
	strcat(sql, "TO_CHAR(la.fecha_lectura, '%Y%m%d'), ");
	strcat(sql, "la.tipo_lectura, ");
	strcat(sql, "m.modelo_medidor, ");

	strcat(sql, "CASE ");
   strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' ");
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' ");
	strcat(sql, "	ELSE t1.acronimo_sap ");
	strcat(sql, "END, ");
	
	strcat(sql, "h.indica_refact, ");
	strcat(sql, "m.tipo_medidor, ");

	strcat(sql, "me.med_factor, ");
	strcat(sql, "m.enteros, ");
	strcat(sql, "m.decimales ");
	
	strcat(sql, "FROM hislec la, cliente c, hisfac h, medid m, sap_transforma t1, medidor me ");
	strcat(sql, "WHERE la.numero_cliente = ? ");
	strcat(sql, "AND la.tipo_lectura IN (6,7) ");
	
	strcat(sql, "AND la.fecha_lectura = (SELECT MAX(la2.fecha_lectura) FROM hislec la2 ");
	strcat(sql, "	WHERE la2.numero_cliente = la.numero_cliente ");
	strcat(sql, "	AND la2.tipo_lectura IN (6,7) ");
	strcat(sql, "	AND la2.fecha_lectura < ? ) ");
	
	strcat(sql, "AND c.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND h.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND h.corr_facturacion = la.corr_facturacion ");
	strcat(sql, "AND m.numero_cliente = la.numero_cliente ");
	strcat(sql, "AND m.numero_medidor = la.numero_medidor ");
	strcat(sql, "AND m.marca_medidor = la.marca_medidor ");

	strcat(sql, "AND m.fecha_prim_insta = (SELECT MAX(m2.fecha_prim_insta) ");
	strcat(sql, "	FROM medid m2 ");
	strcat(sql, " 	WHERE m2.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m2.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m2.marca_medidor = m.marca_medidor) ");

	strcat(sql, "AND m.fecha_ult_insta = (SELECT MAX(m3.fecha_ult_insta) ");
	strcat(sql, "	FROM medid m3 ");
	strcat(sql, " 	WHERE m3.numero_cliente = m.numero_cliente ");
	strcat(sql, "   AND m3.numero_medidor = m.numero_medidor ");
	strcat(sql, "   AND m3.marca_medidor = m.marca_medidor) ");
		
	strcat(sql, "AND me.mar_codigo = la.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
	strcat(sql, "AND me.med_numero = la.numero_medidor ");
	
	strcat(sql, "AND t1.clave = 'TARIFTYP' ");
	strcat(sql, "AND t1.cod_mac = h.tarifa ");
	
	$PREPARE selMontajeReal FROM $sql;
	
	$DECLARE curMontajeReal CURSOR FOR selMontajeReal;	
	
	/************* Si existe en Medid **************/

	strcpy(sql, "SELECT COUNT(*) FROM medid ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selEMedid FROM $sql;
	
	
	/********** Fecha Alta Instalacion ************/
	strcpy(sql, "SELECT fecha_val_tarifa, TO_CHAR(fecha_val_tarifa, '%Y%m%d') FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selFechaInstal FROM $sql;
	
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
char *getFechaFactura(lNroCliente, lCorrFactuInicio, lFechaFactura)
$long	lNroCliente;
$long	lCorrFactuInicio;
$long	*lFechaFactura;
{
	$char	sFechaFactura[9];
	$long	lFechaFactuLocal;
	
	memset(sFechaFactura, '\0', sizeof(sFechaFactura));
	
	/* Reemplazo la fecha lectura por la fecha de primera factura a migrar */
	$EXECUTE selFechaFactura into :sFechaFactura, :lFechaFactuLocal using :lNroCliente, :lCorrFactuInicio;
		
	if(SQLCODE != 0){
		printf("No se encontró factura historica para cliente %ld\n", lNroCliente);
		return;
	}
		
	*lFechaFactura=lFechaFactuLocal;
	
	return sFechaFactura;
}

short LeoClientes(lNroCliente, lCorrFactuActual)
$long *lNroCliente;
$long *lCorrFactuActual;
{

	$long localNroCliente;
	$long localCorrelativo;
	
	$FETCH curClientes into :localNroCliente, :localCorrelativo;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
	*lNroCliente = localNroCliente;
	*lCorrFactuActual = localCorrelativo;
	
	return 1;	
}


long  getMedidorActual(lCliente, sMarcaMedid, sModeloMedid)
$long lCliente;
$char *sMarcaMedid;
$char *sModeloMedid;
{
   $long lNroMedidor;
   $char sMarcaAux[4];
   $char sModeloAux[3];
   
   memset(sMarcaAux, '\0', sizeof(sMarcaAux));
   memset(sModeloAux, '\0', sizeof(sModeloAux));
   
   $OPEN curUltMedidor USING :lCliente;
   
   $FETCH curUltMedidor INTO :lNroMedidor,
                                 :sMarcaAux,
                                 :sModeloAux;
                           
                              
   if(SQLCODE != 0){
      printf("Error al buscar ultimo medidor para cliente %ld\n", lCliente);
      strcpy(sMarcaMedid, "XXX");
      strcpy(sModeloMedid, "XX");
      return 0;
   }

   strcpy(sMarcaMedid, sMarcaAux);
   strcpy(sModeloMedid,sModeloAux);

   $CLOSE curUltMedidor;
      
   return lNroMedidor;
}

short LeoLecturas(regLectu)
$ClsLecturas *regLectu;
{
	
	InicializaLecturas(regLectu);
	
	$FETCH curLecturas into 
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->lectura_facturac,
		:regLectu->lectura_terreno,
      :regLectu->consumo,
		:regLectu->fecha_lectura,
		:regLectu->sFechaLectura,
		:regLectu->tipo_lectura,
		:regLectu->modelo_medidor,
		:regLectu->tarifa,
		:regLectu->indica_refact,
		:regLectu->tipo_medidor,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales;
				
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Lecturas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }
    
    alltrim(regLectu->tarifa, ' ');
    
	return 1;	
}

short LeoPrimeraLectura(lNroCliente, lFechaPrimFactu, lFechaMoveIn, regLectu)
$long lNroCliente;
$long lFechaPrimFactu;
$long lFechaMoveIn;
$ClsLecturas *regLectu;
{
	$long	lFechaInstal;
	$char	sFechaInstal[9];
	
	memset(sFechaInstal, '\0', sizeof(sFechaInstal));
	
	InicializaLecturas(regLectu);
	
	$OPEN curPrimLectu 	using :lNroCliente,
		  					  :lFechaPrimFactu;

	$FETCH curPrimLectu into 
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->lectura_facturac,
		:regLectu->lectura_terreno,
      :regLectu->consumo,
		:regLectu->fecha_lectura,
		:regLectu->sFechaLectura,
		:regLectu->tipo_lectura,
		:regLectu->modelo_medidor,
		:regLectu->tarifa,
		:regLectu->indica_refact,
		:regLectu->tipo_medidor,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
    		$CLOSE curPrimLectu;
			return 0;
		}else{
			$CLOSE curPrimLectu;
			printf("Error al leer Primera de Lectura !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }
    
    $CLOSE curPrimLectu;
 
    alltrim(regLectu->tarifa, ' ');
    regLectu->fecha_lectura = lFechaMoveIn;
    rfmtdate(lFechaMoveIn, "yyyymmdd", regLectu->sFechaLectura); /* long to char */
    
	return 1;
}

void InicializaLecturas(regLectu)
$ClsLecturas	*regLectu;
{
	rsetnull(CLONGTYPE, (char *) &(regLectu->numero_cliente));
	rsetnull(CINTTYPE, (char *) &(regLectu->corr_facturacion));
	rsetnull(CLONGTYPE, (char *) &(regLectu->numero_medidor));
	memset(regLectu->marca_medidor, '\0', sizeof(regLectu->marca_medidor));
	rsetnull(CDOUBLETYPE, (char *) &(regLectu->lectura_facturac));
	rsetnull(CDOUBLETYPE, (char *) &(regLectu->lectura_terreno));
   rsetnull(CDOUBLETYPE, (char *) &(regLectu->consumo));
	rsetnull(CLONGTYPE, (char *) &(regLectu->fecha_lectura));
	memset(regLectu->sFechaLectura, '\0', sizeof(regLectu->sFechaLectura));
	rsetnull(CINTTYPE, (char *) &(regLectu->tipo_lectura));
	memset(regLectu->modelo_medidor, '\0', sizeof(regLectu->modelo_medidor));
	memset(regLectu->tarifa, '\0', sizeof(regLectu->tarifa));
	memset(regLectu->indica_refact, '\0', sizeof(regLectu->indica_refact));
	memset(regLectu->tipo_medidor, '\0', sizeof(regLectu->tipo_medidor));
	
	rsetnull(CDOUBLETYPE, (char *) &(regLectu->factor_potencia));
	rsetnull(CINTTYPE, (char *) &(regLectu->enteros));
	rsetnull(CINTTYPE, (char *) &(regLectu->decimales));
	
}

short ClienteYaMigrado(nroCliente, iFlagMigra, lMoveIn, lFechaPivote, lAlta)
$long	nroCliente;
int		*iFlagMigra;
$long    *lMoveIn;
$long    *lFechaPivote;
$long    *lAlta;
{
	$char	sMarca[2];
   $long lFechaMoveIn;
   $long lPivote;
   $long lFechaAlta;
	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigradoM INTO :sMarca, :lFechaMoveIn, :lPivote, :lFechaAlta USING :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}

   *lMoveIn = lFechaMoveIn;
   *lFechaPivote = lPivote;
   *lAlta = lFechaAlta;
    
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

short CargaLecturasActivasRefact(regLectu)
$ClsLecturas *regLectu;
{
	$double	lLectura=0.0;
   $double  lConsumo=0.0;
	
	$EXECUTE selActivaRectif into :lLectura, :lConsumo using :regLectu->numero_cliente,
												  :regLectu->corr_facturacion,
												  :regLectu->tipo_lectura;
												  	
	if(SQLCODE!=0){
		if(SQLCODE==SQLNOTFOUND){
			return 1;	
		}else{
			printf("Error al buscar lectura rectificada activa para cliente %ld correlativo %d\n", regLectu->numero_cliente, regLectu->corr_facturacion);
			return 0;
		}	
	}

	regLectu->lectura_facturac = lLectura;
   regLectu->consumo = lConsumo;
	
	return 1;	
}

short CargaLecturasReactivasRefact(regLectu)
$ClsLecturas *regLectu;
{
	$double	lLectura=0.0;
   $double  lConsumo = 0.0;
	
	$EXECUTE selReactivaRectif into :lLectura, :lConsumo using :regLectu->numero_cliente,
												  :regLectu->corr_facturacion,
												  :regLectu->tipo_lectura;
												  	
	if(SQLCODE!=0){
		if(SQLCODE==SQLNOTFOUND){
			return 1;	
		}else{
			printf("Error al buscar lectura rectificada Reactiva para cliente %ld correlativo %d\n", regLectu->numero_cliente, regLectu->corr_facturacion);
			return 0;
		}	
	}

	regLectu->lectura_facturac = lLectura;
   regLectu->consumo = lConsumo;
	
	return 1;
}

short CargaLecturasReactivas(regLectu)
$ClsLecturas *regLectu;
{
	$double	lLecturaFactu=0.0;
	$double lLecturaTerr=0.0;
	
	$EXECUTE selLectuReactiva into :lLecturaFactu, 
								   :lLecturaTerr 
							 using :regLectu->numero_cliente,
							 	   :regLectu->corr_facturacion,
							 	   :regLectu->tipo_lectura;
				
	if(SQLCODE!=0){
		if(SQLCODE==SQLNOTFOUND){
			return 1;	
		}else{
			printf("Error al buscar lectura  Reactiva para cliente %ld correlativo %d\n", regLectu->numero_cliente, regLectu->corr_facturacion);
			return 0;
		}	
	}

	regLectu->lectura_facturac = lLecturaFactu;
	regLectu->lectura_terreno = lLecturaTerr;
	
	return 1;
}


short GenerarPlanos( regLectu)
$ClsLecturas		regLectu;
{

	FILE 	*fpLocal;
	char	sTipo[2];
	ClsLecturas		regLectuAux;
	
   fpLocal = pFileGral;
	if(regLectu.tipo_lectura==5){
		cantDesmontajes++;
		strcpy(sTipo, "D");
	}else{
		cantMontajes++;
		strcpy(sTipo, "M");
	}
	
	if(regLectu.indica_refact[0]=='S'){
		if(!CargaLecturasActivasRefact(&regLectu)){
			$ROLLBACK WORK;
			exit(2);	
		}	
	}

	/* DI_INT */	
	GeneraDI_INT(fpLocal, sTipo, regLectu);

	/* DI_ZW */	
	if(strcmp(regLectu.tipo_medidor, "R")==0){
		/* Medidor Activa Reactiva */
		GeneraDI_ZW(fpLocal, sTipo, 1, regLectu); /* La de Activa Real */
		CopiaEstructura(regLectu, &regLectuAux);  /* Resguardo la de activa */
				
		/* Hago la de Reactiva */
		if(regLectu.indica_refact[0]=='S'){
			if(!CargaLecturasReactivasRefact(&regLectu)){
				$ROLLBACK WORK;
				exit(2);	
			}						
		}else{
			if(!CargaLecturasReactivas(&regLectu)){
				$ROLLBACK WORK;
				exit(2);	
			}						
		}
		GeneraDI_ZW(fpLocal, sTipo, 3, regLectu);    /* La de Reactiva Real */
		GeneraDI_ZW(fpLocal, sTipo, 2, regLectuAux); /* La de Activa Ficticia */
		CopiaEstructura(regLectu, &regLectuAux);     /* Resguardo la de Reactiva */
		GeneraDI_ZW(fpLocal, sTipo, 4, regLectuAux); /* La de ReActiva Ficticia */
	}else{
		GeneraDI_ZW(fpLocal, sTipo, 1, regLectu); /* La de Activa Real */
		CopiaEstructura(regLectu, &regLectuAux);  /* Resguardo la de activa */
		GeneraDI_ZW(fpLocal, sTipo, 2, regLectuAux); /* La de Activa Ficticia */
	}	
	
	/* DI_GER */
	GeneraDI_GER(fpLocal, sTipo, regLectu);	
	
   /* DI_CNT */
   GeneraDI_CNT(fpLocal, regLectu);
   
	/* ENDE */
	GeneraENDE(fpLocal, regLectu);
	
	return 1;
}

void GeneraDI_GER(fp, sTipo, regLectu)
FILE 			*fp;
char			sTipo[2];
ClsLecturas		regLectu;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%d\tDI_GER\t", regLectu.numero_cliente, iNroIndex);
   
   if(sTipo[0]=='D'){
      /* MATNR */
      strcat(sLinea, "\t");
      
      /* EQUNRNEU */
      strcat(sLinea, "\t");
      
      /* AUSBAU */
      strcat(sLinea, "X\t");
      
      /* SPARTENEU */
      strcat(sLinea, "\t");
      
      /* EQUNRALT */
      sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
         
      /* MATNRALT */
      sprintf(sLinea, "%s%s_%s", sLinea, regLectu.marca_medidor, regLectu.modelo_medidor);
   }else{
      /* MATNR */
      sprintf(sLinea, "%s%s_%s\t", sLinea, regLectu.marca_medidor, regLectu.modelo_medidor);
      
      /* EQUNRNEU */
      sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
      
      /* AUSBAU */
      strcat(sLinea, "\t");
      
      /* SPARTENEU */
      strcat(sLinea,"01\t");
      
      /* EQUNRALT */
      strcat(sLinea, "\t");
      
      /* MATNRALT */
   
   }   
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

void GeneraENDE(fp, regLectu)
FILE *fp;
$ClsLecturas	regLectu;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld-%d\t&ENDE", regLectu.numero_cliente, iNroIndex);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantMontajes > 0){
		strcpy(sTipoArchivo, "MONTAJE");
		strcpy(sNombreArchivo, sSoloArchivoGral);
		lCantidad=cantMontajes;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenInstal using
				:sTipoArchivo,
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
		$EXECUTE insClientesMigraM using :nroCliente;
	}else{
		$EXECUTE updClientesMigraM using :nroCliente;
	}

	return 1;
}

void GeneraDI_ZW(fp, sTipo, iNum, regLectu)
FILE 		*fp;
char		sTipo[2];
int			iNum;
ClsLecturas	regLectu;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

	sprintf(sLinea, "T1%ld-%d\tDI_ZW\t", regLectu.numero_cliente, iNroIndex);

   if(sTipo[0]=='D'){ /* Desmontaje */
      /* ZWNUMMERA */
      sprintf(sLinea, "%s00%d\t",sLinea, iNum);
      
      /* ZWNUMMERE */
      strcat(sLinea, "\t");
      
      /* KONDIGRE */
      strcat(sLinea, "\t");
      
      /* ZWSTANDCA */
      sprintf(sLinea, "%s%.0f\t", sLinea, regLectu.lectura_facturac);
      
      /* ZWSTANDCE */
      strcat(sLinea, "\t");
      
      /* ZWNABR */
      if(regLectu.tipo_medidor[0]=='R'){
         if(iNum==1 || iNum==3){
            strcat(sLinea, "X\t");
         }else{
            strcat(sLinea, "\t");
         }
      }else{
         if(iNum==1){
            strcat(sLinea, "X\t");
         }else{
            strcat(sLinea, "\t");
         }
      }
      
      /* TARIFART */
      strcat(sLinea, "\t");
      
      /* PERVERBR */
      sprintf(sLinea, "%s%.0f\t", sLinea, regLectu.consumo);

      
      /* EQUNRE */
      strcat(sLinea, "\t");
      
      /* EQUNRA */
      sprintf(sLinea, "%sT1%ld%s%s", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
            
      
   }else{ /* Montaje */
      /* ZWNUMMERA */
      strcat(sLinea, "\t");
      
      /* ZWNUMMERE */
      sprintf(sLinea, "%s00%d\t", sLinea, iNum);
      
      /* KONDIGRE */
      if(strcmp(regLectu.tarifa, "T1-GENME")==0){
         strcat(sLinea, "T1-GENMED\t");
      }else{
         strcat(sLinea, "ENERGIA\t");
      }

      
      /* ZWSTANDCA */
      strcat(sLinea, "\t");
      
      /* ZWSTANDCE */
      sprintf(sLinea, "%s%.0f\t", sLinea, regLectu.lectura_facturac);
            
      /* ZWNABR */
      if(regLectu.tipo_medidor[0]=='R'){
         if(iNum==1 || iNum==3){
            strcat(sLinea, "X\t");
         }else{
            strcat(sLinea, "\t");
         }
      }else{
         if(iNum==1){
            strcat(sLinea, "X\t");
         }else{
            strcat(sLinea, "\t");
         }
      }
      
      /* TARIFART */
/*
      if(regLectu.tipo_medidor[0]=='R'){
         if(iNum==2 || iNum==4){
            strcat(sLinea, "T1-REACT\t");
         }else{
            sprintf(sLinea, "%s%s\t", sLinea, regLectu.tarifa);
         }
      }else{
         sprintf(sLinea, "%s%s\t", sLinea, regLectu.tarifa);
      }
*/
      if(regLectu.tipo_medidor[0]=='R'){
         if(iNum==3 || iNum==4){
            strcat(sLinea, "T1-REACT\t");
         }else{
            strcat(sLinea, "T1-RESID\t");
         }
      }else{
         strcat(sLinea, "T1-RESID\t");
      }
      
      /* PERVERBR */
      strcat(sLinea, "0\t");
      
      /* EQUNRE */
      sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor);
      
      /* EQUNRA */

   }   
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
	
}


void GeneraDI_CNT(fp, regLectu)
FILE     *fp;
ClsLecturas regLectu;
{
	char	sLinea[1000];	
	
   memset(sLinea, '\0', sizeof(sLinea));

   sprintf(sLinea, "T1%ld-%d\tDI_CNT\t", regLectu.numero_cliente, iNroIndex);
   
   /* NO_AUTOMOVEIN */
   strcat(sLinea, "X");
   
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

}


void GeneraDI_INT(fp, sTipo, regLectu)
FILE 			*fp;
char			sTipo[2];
ClsLecturas		regLectu;
{
	char	sLinea[1000];	
	
	memset(sLinea, '\0', sizeof(sLinea));

   sprintf(sLinea, "T1%ld-%d\tDI_INT\t", regLectu.numero_cliente, iNroIndex);

   /* ANLAGE */
   sprintf(sLinea, "%sT1%ld\t", sLinea, regLectu.numero_cliente);
   
   /* EADAT */
   sprintf(sLinea, "%s%s\t", sLinea, regLectu.sFechaLectura);
   
   /* ACTION */
	if(sTipo[0]=='M'){
      strcat(sLinea, "04");		
	}else{
		strcat(sLinea, "05");
	}

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

short LeoUltRetiro(lNroCliente, regLectu)
$long			lNroCliente;
$ClsLecturas	*regLectu;
{
	InicializaLecturas(regLectu);

	$EXECUTE selLectuRetiro into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->lectura_facturac,
		:regLectu->lectura_terreno,
      :regLectu->consumo,
		:regLectu->fecha_lectura,
		:regLectu->sFechaLectura,
		:regLectu->tipo_lectura,
		:regLectu->modelo_medidor,
		:regLectu->tarifa,
		:regLectu->tipo_medidor,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales
	using :lNroCliente;
		
	if(SQLCODE !=0){
		if(SQLCODE != SQLNOTFOUND){
			printf("Error al buscar retiro para cliente %ld\n", lNroCliente);
		}else{
			printf("No se encontró retiro para cliente %ld\n", lNroCliente);
		}
		return 0;
	}

	strcpy(regLectu->indica_refact, "N");
	
	return 1;		
}

short LeoUltInstalacion(lNroCliente, lFechaMoveIn, regLectu)
$long			lNroCliente;
long        lFechaMoveIn;
$ClsLecturas	*regLectu;
{
	InicializaLecturas(regLectu);
	
	$EXECUTE selMedid into
		:regLectu->numero_cliente,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->modelo_medidor,
		:regLectu->sFechaLectura,
		:regLectu->lectura_facturac,
		:regLectu->lectura_instal_reac,
      :regLectu->consumo,
		:regLectu->tipo_medidor,
		:regLectu->tarifa,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales
	using :lNroCliente;
		
	if(SQLCODE !=0){
		if(SQLCODE==SQLNOTFOUND){
			$EXECUTE selMedid2 into
				:regLectu->numero_cliente,
				:regLectu->numero_medidor,
				:regLectu->marca_medidor,
				:regLectu->modelo_medidor,
				:regLectu->sFechaLectura,
				:regLectu->lectura_facturac,
				:regLectu->lectura_instal_reac,
            :regLectu->consumo,
				:regLectu->tipo_medidor,
				:regLectu->tarifa,
				:regLectu->factor_potencia,
				:regLectu->enteros,
				:regLectu->decimales
			using :lNroCliente;			
				
			if(SQLCODE !=0){
				printf("Error al buscar MEDID 2 para cliente %ld\n", lNroCliente);
				return 0;
			}
		}else{
			printf("Error al buscar MEDID 1 para cliente %ld\n", lNroCliente);
			return 0;	
		}
	}
	
	regLectu->tipo_lectura = 6;
	
	alltrim(regLectu->tarifa, ' ');
   regLectu->fecha_lectura = lFechaMoveIn;
   rfmtdate(lFechaMoveIn, "yyyymmdd", regLectu->sFechaLectura); /* long to char */
   
	
	return 1;	
}

short LeoInstalacionPuntual(regLectu, regLectu2)
$ClsLecturas	regLectu;
$ClsLecturas	*regLectu2;
{

	InicializaLecturas(regLectu2);
	
	$EXECUTE selLectuInstal into
		:regLectu2->numero_cliente,
		:regLectu2->numero_medidor,
		:regLectu2->marca_medidor,
		:regLectu2->modelo_medidor,
		:regLectu2->sFechaLectura,
		:regLectu2->lectura_facturac,
		:regLectu2->lectura_instal_reac,
		:regLectu2->tipo_medidor,
		:regLectu2->tarifa,
		:regLectu2->factor_potencia,
		:regLectu2->enteros,
		:regLectu2->decimales
			
	using :regLectu.numero_cliente,
		:regLectu.numero_medidor,
		:regLectu.marca_medidor,
		:regLectu.modelo_medidor;
			
	if(SQLCODE !=0){
		printf("No se encontró MEDID puntual para cliente %ld\n", regLectu.numero_cliente);
		return 0;	
	}
	
	return 1;	
}



void GeneraMontajeReal(regLectu)
ClsLecturas	regLectu;
{
	char	sLinea[1000];
	
	sprintf(sLinea, "T1%ld\tMONT_REAL\t", regLectu.numero_cliente);
	sprintf(sLinea, "%sT1%ld\t", sLinea, regLectu.numero_cliente);	/* Llave Instalacion*/
	sprintf(sLinea, "%sT1%ld%s%s\t", sLinea, regLectu.numero_medidor, regLectu.marca_medidor, regLectu.modelo_medidor); /* Llave Device */

	sprintf(sLinea, "%s%s", sLinea, regLectu.sFechaLectura);

	strcat(sLinea, "\n");
	
	fprintf(pFileMontajeReal, sLinea);
	
	/* ENDE */
	GeneraENDE(pFileMontajeReal, regLectu);	
	
}

short LeoPrimerMontajeReal(lNroCliente, lFechaFactura, regLectu)
$long	lNroCliente;
$long	lFechaFactura;
$ClsLecturas	*regLectu;
{
	InicializaLecturas(regLectu);
	
	$OPEN curMontajeReal using :lNroCliente, :lFechaFactura;
	
	$FETCH curMontajeReal into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->lectura_facturac,
		:regLectu->lectura_terreno,
		:regLectu->fecha_lectura,
		:regLectu->sFechaLectura,
		:regLectu->tipo_lectura,
		:regLectu->modelo_medidor,
		:regLectu->tarifa,
		:regLectu->indica_refact,
		:regLectu->tipo_medidor,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales;
				
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
    		$CLOSE curMontajeReal;
			return 0;
		}else{
			$CLOSE curMontajeReal;
			printf("Error al leer Cursor de Monajes Reales !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }
    
    $CLOSE curMontajeReal;
    
    alltrim(regLectu->tarifa, ' ');
    
	return 1;
	
}

short EncontroMedid(lNroCliente)
$long lNroCliente;
{
	$long iValor=0;
	
	$EXECUTE selEMedid into :iValor using :lNroCliente;
	
	if(SQLCODE!=0){
		return 0;	
	}
	
	if(iValor <=0){
		return 0;
	}
	
	return 1;	
}

void CopiaEstructura(regLectu, regLectuAux)
ClsLecturas	regLectu;
ClsLecturas *regLectuAux;
{
	InicializaLecturas(regLectuAux);
	
	regLectuAux->numero_cliente=regLectu.numero_cliente;
	regLectuAux->corr_facturacion=regLectu.corr_facturacion;

	regLectuAux->numero_medidor=regLectu.numero_medidor;
	strcpy(regLectuAux->marca_medidor, regLectu.marca_medidor);
	strcpy(regLectuAux->modelo_medidor, regLectu.modelo_medidor);
		
	regLectuAux->lectura_facturac=0.00;
	regLectuAux->lectura_terreno=0.00;
	regLectuAux->consumo = 0.00;
  	regLectuAux->fecha_lectura=regLectu.fecha_lectura;
		
	strcpy(regLectuAux->sFechaLectura, regLectu.sFechaLectura);
	
	regLectuAux->tipo_lectura=regLectu.tipo_lectura;
	
	
	strcpy(regLectuAux->tarifa, regLectu.tarifa);
	strcpy(regLectuAux->indica_refact, regLectu.indica_refact);
	strcpy(regLectuAux->tipo_medidor, regLectu.tipo_medidor);
	regLectuAux->lectura_instal_reac=0.00;
	
	regLectuAux->factor_potencia=regLectu.factor_potencia;
	regLectuAux->enteros=regLectu.enteros;
	regLectuAux->decimales=regLectu.decimales;
	
}

short LeoSinFactura(lFechaMoveIn, regLectu)
long  lFechaMoveIn;
$ClsLecturas *regLectu;
{
	$FETCH curSinFactura into
		:regLectu->numero_cliente,
		:regLectu->corr_facturacion,
		:regLectu->numero_medidor,
		:regLectu->marca_medidor,
		:regLectu->lectura_facturac,
		:regLectu->lectura_terreno,
      :regLectu->consumo,
		:regLectu->fecha_lectura,
		:regLectu->sFechaLectura,
		:regLectu->tipo_lectura,
		:regLectu->modelo_medidor,
		:regLectu->tarifa,
		:regLectu->indica_refact,
		:regLectu->tipo_medidor,
		:regLectu->factor_potencia,
		:regLectu->enteros,
		:regLectu->decimales;
			
	if(SQLCODE!=0){
		return 0;	
	}

    regLectu->fecha_lectura = lFechaMoveIn;
    rfmtdate(lFechaMoveIn, "yyyymmdd", regLectu->sFechaLectura); /* long to char */
	
	return 1;
}

short EsMedidorVigente(lNroMedidor, sMarcaMedidor, sModeloMedidor, regLectu)
long        lNroMedidor;
char        sMarcaMedidor[4];
char        sModeloMedidor[3];
ClsLecturas regLectu;     
{

   if(lNroMedidor == regLectu.numero_medidor){
      if(strcmp(sMarcaMedidor, regLectu.marca_medidor) == 0){
         if(strcmp(sModeloMedidor, regLectu.modelo_medidor) == 0){
            return 1;
         }
      }
   }

   return 0;
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

