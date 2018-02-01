/*******************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_cta_contrato
    
	Fecha : 03/10/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para la estructura CUENTAS CONTRATO T1
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Estado Cliente>: 0 = Activo; 1 = No Activo; 2 = Todos
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
					   
		<Nro Cliente>: Opcional. Si se carga el valor, se extrae SOLO para el cliente en cuestion

*******************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_cta_contrato.h";

/* Variables Globales */
char	sMensMail[1024];	
$int	giEstadoCliente;
$char	gsTipoGenera[2];
$long	glNroCliente;

long	cantActivoProcesada;
long	cantNoActivoProcesada;
long	cantFicticia;
long	cantCorpoT1;
long 	cantPreexistente;

int		CantTipoRegistro;

FILE	*pFileCtaActivaUnx;
FILE	*pFileCtaNoActivaUnx;
FILE	*pFileCtaFicticiaUnx;
FILE	*pFileCtaCorpoT1Unx;

char	sArchCtaActivaUnx[100];
char	sArchCtaNoActivaUnx[100];
char	sArchCtaFicticiaUnx[100];
char	sArchCtaCorpoT1Unx[100];

char	sArchCtaActivaDos[100];
char	sArchCtaNoActivaDos[100];
char	sArchCtaFicticiaDos[100];

char	sSoloArchivoCtaActiva[100];
char	sSoloArchivoCtaNoActiva[100];
char	sSoloArchivoCtaFicticia[100];
char	sSoloArchivoCtaCorpoT1[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
char	sCommand[1000];
int		iRcv, i;

long	lCorrelativoActivo;
long	lCorrelativoNoActivo;
long	lCorrelativoFicticia;

/* Variables Globales Host */
$ClsCliente	regCliente;
$char	fecha[9];



$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		idArchivo;
int		iEsCorpo;
int		iFlagMigra;

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

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(! AbreArchivos()){
		exit(2);	
	}

	cantActivoProcesada=0;
	cantNoActivoProcesada=0;
	cantPreexistente=0;
	cantFicticia=0;
   cantCorpoT1=0;
   
	/*********************************************
				AREA CORPO T1
	**********************************************/
/*   
   $OPEN curCorpoT1;
   
	while(LeoCorpoT1(&regCliente)){

		if(regCliente.estado_cliente[0]=='0'){

			iFlagMigra=0;
			if(! ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra)){
            $BEGIN WORK;

				if (!GenerarPlanoT1(pFileCtaCorpoT1Unx, regCliente, 1)){
					$ROLLBACK WORK;
					exit(1);	
				}

				if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);	
				}

				cantCorpoT1++;

				$COMMIT WORK;
			}
		}
   }
   
   $CLOSE curCorpoT1;
*/
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
	if(glNroCliente > 0 ){
    	$OPEN curClientes using :glNroCliente;
    }else{
		$OPEN curClientes;
	}

	iEsCorpo=0;
	while(LeoClientes(&regCliente)){

		if(regCliente.estado_cliente[0]=='0'){

			/* Los Activos */
			iFlagMigra=0;
			if(! ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra)){
            $BEGIN WORK;
				if(! CorporativoT23(&regCliente)){

					/* Generar Plano */
					if (!GenerarPlanoT1(pFileCtaActivaUnx, regCliente, 2)){
						$ROLLBACK WORK;
						exit(1);	
					}

					/* Registrar Control Cliente */
					if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
						$ROLLBACK WORK;
						exit(1);	
					}

					cantActivoProcesada++;
					
				}else{
					/* Hijo de Corporativo de T23 */	
					/* Generar Plano */
					if (!GenerarPlanoT23(pFileCtaFicticiaUnx, regCliente)){
						$ROLLBACK WORK;
						exit(1);	
					}

					/* Registrar Control Cliente */
					if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
						$ROLLBACK WORK;
						exit(1);	
					}
					cantFicticia++;
					
					cantActivoProcesada++;

				}
				$COMMIT WORK;
			}/* Verif de Cliente ya migrado*/
		}else{
			/* CLIENTES NO ACTIVOS */

			iFlagMigra=0;
			if(! ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra)){
            $BEGIN WORK;
				iEsCorpo=0;

				/* Generar Plano */
				if (!GenerarPlanoT1(pFileCtaNoActivaUnx, regCliente, 2)){
					$ROLLBACK WORK;
					exit(1);	
				}

				/* Registrar Control Cliente */
				if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);	
				}
            $COMMIT WORK;
				cantNoActivoProcesada++;
			}
		}/* Verif Estado Cliente */
		
	}/* Fin While */

	$CLOSE curClientes;

	CierroArchivos();

	/* Registrar Control Plano */
   
   $BEGIN WORK;
      
	AdministraPlanos();

	$COMMIT WORK;

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
	printf("CUENTA CONTRATO\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Cuentas Activas :          %ld \n", cantActivoProcesada);
	printf("Cuentas No Activas:        %ld \n", cantNoActivoProcesada);
	printf("Cuentas a Ficticias T23:   %ld \n", cantFicticia);
	printf("Clientes Preexistentes:    %ld \n", cantPreexistente);
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

	if(argc > 5 || argc < 4){
		MensajeParametros();
		return 0;
	}
	
	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0){
		MensajeParametros();
		return 0;	
	}

	
	giEstadoCliente=atoi(argv[2]);
	strcpy(gsTipoGenera, argv[3]);
	
	if(argc == 5){	
		glNroCliente=atol(argv[4]);
	}else{
		glNroCliente=-1;	
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("\t<Base> = synergia.\n");
		printf("\t<Estado Cliente> = 0 Activo - 1 No Activo 2 - Todos.\n");
		printf("\t<Tipo Generación> G = Generación, R = Regeneración.\n");
		printf("\t<Nro.Cliente> Opcional.\n");

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
	
   /******** Cursor Corpos T1 ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "t6.acronimo_sap, ");  /* CDC - Tipo Cliente */
	strcat(sql, "t6.cod_sap, ");		/* Categoria de cuenta*/
	strcat(sql, "c.tipo_fpago, ");
	strcat(sql, "c.minist_repart, ");
	strcat(sql, "t1.cod_sap[1,4], ");
	strcat(sql, "t4.cod_sap, "); /* Tipo IVA */
	strcat(sql, "c.tipo_reparto, ");
	strcat(sql, "t2.cod_sap, ");  /* provincia - region*/
	strcat(sql, "t5.cod_sap, ");  /* partido-condado */
	strcat(sql, "c.estado_cliente, ");
	strcat(sql, "t7.cod_sap, ");   /* Tipo Reparto codificado a SAP*/
	strcat(sql, "case ");
	strcat(sql, "	WHEN cd.numero_cliente IS NOT NULL THEN 'S' ");
	strcat(sql, "	ELSE 'N' ");
	strcat(sql, "END, ");
	strcat(sql, "c.tipo_sum, ");
   strcat(sql, "t8.cod_sap, ");  /* Estado Cobrabilidad */
   strcat(sql, "c.tiene_corte_rest, ");
   strcat(sql, "t9.cod_sap "); /* Sucursal SAP */   
	strcat(sql, "FROM corpoT1migrado ct, cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2,  OUTER sap_transforma t4, OUTER sap_transforma t5, sap_transforma t6, ");
	strcat(sql, "OUTER(postal p, sap_transforma t3), sap_transforma t7, OUTER clientes_digital cd, OUTER sap_transforma t8, sap_transforma t9 ");
	strcat(sql, "WHERE c.numero_cliente = ct.numero_cliente ");
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND t1.clave = 'TIPO_VENCIM' ");
	strcat(sql, "AND t1.cod_mac = c.tipo_vencimiento ");
	strcat(sql, "AND t2.clave = 'REGION' ");
	strcat(sql, "AND t2.cod_mac = c.provincia ");
	strcat(sql, "AND p.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND t3.clave = 'REGION' ");
	strcat(sql, "AND t3.cod_mac = p.dp_provincia  ");
	strcat(sql, "AND t4.clave = 'TIPIVA' ");
	strcat(sql, "AND t4.cod_mac = c.tipo_iva  ");	
	strcat(sql, "AND t5.clave = 'CONDADO' ");
	strcat(sql, "AND t5.cod_mac = c.partido  ");
	strcat(sql, "AND t6.clave = 'TIPCLI' ");
	strcat(sql, "AND t6.cod_mac = c.tipo_cliente ");
	strcat(sql, "AND t7.clave = 'TIPOREPARTO' ");
	strcat(sql, "AND t7.cod_mac = c.tipo_reparto ");
	strcat(sql, "AND cd.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cd.fecha_alta <= TODAY ");
	strcat(sql, "AND (cd.fecha_baja IS NULL OR cd.fecha_baja > TODAY) ");
	strcat(sql, "AND t8.clave = 'ESTCOB' ");
	strcat(sql, "AND t8.cod_mac = c.estado_cobrabilida ");
   strcat(sql, "AND t8.clave = 'CENTROOP' ");
	strcat(sql, "AND t9.cod_mac = c.sucursal ");
   
	$PREPARE selCorpoT1 FROM $sql;
	
	$DECLARE curCorpoT1 CURSOR WITH HOLD FOR selCorpoT1;		

   
	/******** Cursor Clientes  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");

	strcat(sql, "t6.acronimo_sap, ");  /* CDC - Tipo Cliente */
	strcat(sql, "t6.cod_sap, ");		/* Categoria de cuenta*/
	
	strcat(sql, "c.tipo_fpago, ");
	strcat(sql, "c.minist_repart, ");
	strcat(sql, "t1.cod_sap[1,4], ");
	
	strcat(sql, "t4.cod_sap, "); /* Tipo IVA */
	
	strcat(sql, "c.tipo_reparto, ");
	/*
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', t3.cod_sap, t2.cod_sap) provincia, ");
	*/
	strcat(sql, "t2.cod_sap, ");  /* provincia - region*/
	strcat(sql, "t5.cod_sap, ");  /* partido-condado */
	
	strcat(sql, "c.estado_cliente, ");
	
	strcat(sql, "t7.cod_sap, ");   /* Tipo Reparto codificado a SAP*/
	strcat(sql, "case ");
	strcat(sql, "	WHEN cd.numero_cliente IS NOT NULL THEN 'S' ");
	strcat(sql, "	ELSE 'N' ");
	strcat(sql, "END, ");
	strcat(sql, "c.tipo_sum, ");
   strcat(sql, "t8.cod_sap, ");  /* Estado Cobrabilidad */
   strcat(sql, "c.tiene_corte_rest, ");
   strcat(sql, "t9.cod_sap ");   /* sucursal SAP */
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2,  OUTER sap_transforma t4, OUTER sap_transforma t5, sap_transforma t6, ");
	strcat(sql, "OUTER(postal p, sap_transforma t3), sap_transforma t7, OUTER clientes_digital cd, OUTER sap_transforma t8, sap_transforma t9 ");

strcat(sql, ", migra_activos ma ");   
   
/*	
if(giEstadoCliente!=0){
	strcat(sql, ", sap_inactivos si ");
}
*/
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
	
/*	
	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
		strcat(sql, "AND si.elegido = 'S' ");
	}
*/	
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
	strcat(sql, "AND t1.clave = 'TIPO_VENCIM' ");
	strcat(sql, "AND t1.cod_mac = c.tipo_vencimiento ");
	strcat(sql, "AND t2.clave = 'REGION' ");
	strcat(sql, "AND t2.cod_mac = c.provincia ");
	strcat(sql, "AND p.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND t3.clave = 'REGION' ");
	strcat(sql, "AND t3.cod_mac = p.dp_provincia  ");
	strcat(sql, "AND t4.clave = 'TIPIVA' ");
	strcat(sql, "AND t4.cod_mac = c.tipo_iva  ");	
	strcat(sql, "AND t5.clave = 'CONDADO' ");
	strcat(sql, "AND t5.cod_mac = c.partido  ");
	strcat(sql, "AND t6.clave = 'TIPCLI' ");
	strcat(sql, "AND t6.cod_mac = c.tipo_cliente ");
	strcat(sql, "AND t7.clave = 'TIPOREPARTO' ");
	strcat(sql, "AND t7.cod_mac = c.tipo_reparto ");
	strcat(sql, "AND cd.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cd.fecha_alta <= TODAY ");
	strcat(sql, "AND (cd.fecha_baja IS NULL OR cd.fecha_baja > TODAY) ");
	strcat(sql, "AND t8.clave = 'ESTCOB' ");
	strcat(sql, "AND t8.cod_mac = c.estado_cobrabilida ");
   strcat(sql, "AND t8.clave = 'CENTROOP' ");
	strcat(sql, "AND t8.cod_mac = c.sucursal ");
/*      
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM corpoT1migrado ct ");
	strcat(sql, "   WHERE ct.numero_cliente = c.numero_cliente) ");
*/   
strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
/*	
	strcat(sql, "ORDER BY c.numero_cliente ");
*/

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;		

   /************** Tipo Debito Automatico *************/
   strcpy(sql, "SELECT NVL(s.acronimo_sap, 'D') "); 
   strcat(sql, "FROM forma_pago f, OUTER sap_transforma s ");
   strcat(sql, "WHERE f.numero_cliente = ? ");
   strcat(sql, "AND f.fecha_activacion <= TODAY ");
   strcat(sql, "AND (f.fecha_desactivac IS NULL OR f.fecha_desactivac > TODAY) ");
   strcat(sql, "AND s.clave = 'CARDTYPE' ");
   strcat(sql, "AND s.cod_mac = f.fp_banco ");

   $PREPARE selTipoDebito FROM $sql;
   		
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

	/********* Select Tipo Entidad Debito **********/
   
	strcpy(sql, "SELECT e.tipo ");
	strcat(sql, "FROM forma_pago f, entidades_debito e ");
	strcat(sql, "WHERE f.numero_cliente = ? ");
	strcat(sql, "AND f.fecha_activacion <= TODAY ");
	strcat(sql, "AND (f.fecha_desactivac IS NULL OR f.fecha_desactivac > TODAY) ");
	strcat(sql, "AND e.oficina = f.fp_banco ");
	strcat(sql, "AND e.fecha_activacion <= TODAY ");
	strcat(sql, "AND (e.fecha_desactivac IS NULL OR e.fecha_desactivac > TODAY) ");
	
	$PREPARE selTipoEntidad	FROM $sql;
	
	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT cuenta_contrato FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;
	
	/********* Select Corporativo T23 **********/
	strcpy(sql, "SELECT NVL(cod_corporativo, '000'), cod_corpo_padre FROM mg_corpor_t23 ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selCorpoT23 FROM $sql;
	
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
	strcat(sql, "'CUENTA_CONTRATO', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");	
	
	$PREPARE insGenPartner FROM $sql;
	
	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, cuenta_contrato ");
	strcat(sql, ")VALUES(?, 'S') ");

	$PREPARE insClientesMigra FROM $sql;
	
	/*********Update Clientes extraidos **********/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "cuenta_contrato = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;
      
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

long getCorrelativo(sTipo)
$char	sTipo[21];
{
$long iValor=0;

	/*alltrim(sTipo, ' ');*/

	$EXECUTE selCorrelativo INTO :iValor using :sTipo;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el correlativo del archivo %s.\n", sTipo);
        exit(1);
    }	

    return iValor;
}

short LeoClientes(regCli)
$ClsCliente *regCli;
{
	InicializaCliente(regCli);
	
	$FETCH curClientes into
		:regCli->numero_cliente,
		:regCli->tipo_cliente,
		:regCli->sCategoCuenta,
		:regCli->tipo_fpago,
		:regCli->minist_repart,
		:regCli->tipo_vencimiento,
		:regCli->tipo_iva,
		:regCli->tipo_reparto,
		:regCli->cod_provincia,
		:regCli->comuna,
		:regCli->estado_cliente,
		:regCli->sTipoRepartoSAP,
		:regCli->sFacturaDigital,
		:regCli->sTipoSum,
      :regCli->sEstadoCobrabilidad,
      :regCli->tiene_corte_rest,
      :regCli->sCodSucurSap;
      			

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Clientes !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
	alltrim(regCli->tipo_cliente, ' ');
	alltrim(regCli->sCategoCuenta, ' ');
	alltrim(regCli->tipo_vencimiento, ' ');
	alltrim(regCli->tipo_reparto, ' ');
	alltrim(regCli->cod_provincia, ' ');
	alltrim(regCli->sTipoSum, ' ');
   alltrim(regCli->sEstadoCobrabilidad, ' ');
   alltrim(regCli->tiene_corte_rest, ' ');
   
   if(strcmp(regCli->tipo_fpago, "D")==0){
      strcpy(regCli->sTipoDebito, getTipoDebito(regCli->numero_cliente));
      strcpy(regCli->sTipoEntidadDebito, getTipoEntidad(regCli->numero_cliente));
   }
			
	return 1;	
}

short LeoCorpoT1(regCli)
$ClsCliente *regCli;
{
	InicializaCliente(regCli);
	
	$FETCH curCorpoT1 into
		:regCli->numero_cliente,
		:regCli->tipo_cliente,
		:regCli->sCategoCuenta,
		:regCli->tipo_fpago,
		:regCli->minist_repart,
		:regCli->tipo_vencimiento,
		:regCli->tipo_iva,
		:regCli->tipo_reparto,
		:regCli->cod_provincia,
		:regCli->comuna,
		:regCli->estado_cliente,
		:regCli->sTipoRepartoSAP,
		:regCli->sFacturaDigital,
		:regCli->sTipoSum,
      :regCli->sEstadoCobrabilidad,
      :regCli->tiene_corte_rest,
      :regCli->sCodSucurSap;
      			

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Corporativos T1 !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
	alltrim(regCli->tipo_cliente, ' ');
	alltrim(regCli->sCategoCuenta, ' ');
	alltrim(regCli->tipo_vencimiento, ' ');
	alltrim(regCli->tipo_reparto, ' ');
	alltrim(regCli->cod_provincia, ' ');
	alltrim(regCli->sTipoSum, ' ');
   alltrim(regCli->sEstadoCobrabilidad, ' ');
   alltrim(regCli->tiene_corte_rest, ' ');
   
   if(strcmp(regCli->tipo_fpago, "D")==0){
      strcpy(regCli->sTipoDebito, getTipoDebito(regCli->numero_cliente));
      strcpy(regCli->sTipoEntidadDebito, getTipoEntidad(regCli->numero_cliente));
   }
			
	return 1;	
}


void InicializaCliente(regCli)
$ClsCliente	*regCli;
{

	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
	memset(regCli->tipo_cliente, '\0', sizeof(regCli->tipo_cliente));
	memset(regCli->sCategoCuenta, '\0', sizeof(regCli->sCategoCuenta));
	memset(regCli->tipo_fpago, '\0', sizeof(regCli->tipo_fpago));
	rsetnull(CLONGTYPE, (char *) &(regCli->minist_repart));
	memset(regCli->tipo_vencimiento, '\0', sizeof(regCli->tipo_vencimiento));
	memset(regCli->tipo_iva, '\0', sizeof(regCli->tipo_iva));
	memset(regCli->tipo_reparto, '\0', sizeof(regCli->tipo_reparto));
	memset(regCli->cod_provincia, '\0', sizeof(regCli->cod_provincia));
	memset(regCli->comuna, '\0', sizeof(regCli->comuna));
	memset(regCli->estado_cliente, '\0', sizeof(regCli->estado_cliente));
	memset(regCli->sCodCorpoT23, '\0', sizeof(regCli->sCodCorpoT23));
	memset(regCli->sCodCorpoPadreT23, '\0', sizeof(regCli->sCodCorpoPadreT23));

	memset(regCli->sTipoRepartoSAP, '\0', sizeof(regCli->sTipoRepartoSAP));
	memset(regCli->sFacturaDigital, '\0', sizeof(regCli->sFacturaDigital));
	memset(regCli->sTipoSum, '\0', sizeof(regCli->sTipoSum));
   memset(regCli->sTipoDebito, '\0', sizeof(regCli->sTipoDebito));
   memset(regCli->sEstadoCobrabilidad, '\0', sizeof(regCli->sEstadoCobrabilidad));
   memset(regCli->tiene_corte_rest, '\0', sizeof(regCli->tiene_corte_rest));
   memset(regCli->sTipoEntidadDebito, '\0', sizeof(regCli->sTipoEntidadDebito));
   
   memset(regCli->sCodSucurSap, '\0', sizeof(regCli->sCodSucurSap));
 
}

char *getTipoDebito(lNroCliente)
$long lNroCliente;
{
   $char sTipo[21];
   
   memset(sTipo, '\0', sizeof(sTipo));
   
   $EXECUTE selTipoDebito INTO :sTipo USING :lNroCliente;
   
   if(SQLCODE != 0){
      printf("No se encontró forma de pago para cliente %ld\n.", lNroCliente);
   }

   alltrim(sTipo, ' ');
   
   if(strcmp(sTipo, " ")==0){
      strcpy(sTipo, "D");
   }

   return sTipo;
}

char *getTipoEntidad(lNroCliente)
$long lNroCliente;
{
   $char sTipo[21];
   
   memset(sTipo, '\0', sizeof(sTipo));
   
   $EXECUTE selTipoEntidad INTO :sTipo USING :lNroCliente;
   
   if(SQLCODE != 0){
      printf("No se encontró entidad débito para cliente %ld\n.", lNroCliente);
   }

   alltrim(sTipo, ' ');

   return sTipo;
}


short GenerarPlanoT1(fp, regCliente, iTipo)
FILE 			*fp;
$ClsCliente		regCliente;
int         iTipo;
{
		
	/* INIT */
	GeneraINIT(fp, regCliente, "T1", iTipo);

	/* VK */
	GeneraVK(fp, regCliente, iTipo);

	/* VKP */
	GeneraVKP(fp, regCliente, "T1", iTipo);

	/* VKLOCK */
	/*GeneraVKLOCK(fp, regCliente, "T1");*/

	/* VKTXEX */
	/*GeneraVKTXEX(fp, regCliente);*/

	/* ENDE */
	GeneraENDE(fp, regCliente, iTipo);

	return 1;
}

void GeneraINIT(fp, regCliente, sTarifa, iTipo)
FILE *fp;
$ClsCliente	regCliente;
char	sTarifa[3];
int   iTipo;
{
	char	sLinea[1000];	
	char	sTipoCuenta[3];
	
	memset(sLinea, '\0', sizeof(sLinea));
	
	
	if(regCliente.sTipoSum[0]=='6'){
		if(strcmp(regCliente.tipo_cliente, "M1")==0 || strcmp(regCliente.tipo_cliente, "P1")==0 || strcmp(regCliente.tipo_cliente, "N1")==0){
			strcpy(sTipoCuenta, "07");
		}else{
			strcpy(sTipoCuenta, "06");
		}		
	}else{
		if(strcmp(regCliente.tipo_cliente, "M1")==0 || strcmp(regCliente.tipo_cliente, "P1")==0 || strcmp(regCliente.tipo_cliente, "N1")==0){
			strcpy(sTipoCuenta, "01");
		}else{
			if(strcmp(regCliente.tipo_cliente, "AP")==0){
				strcpy(sTipoCuenta, "08");
			}else if(strcmp(regCliente.tipo_cliente, "RP")==0){
				strcpy(sTipoCuenta, "05");
			}else{
				strcpy(sTipoCuenta, "02");
			}
		}		
	}

	/* LLAVE */
   if(iTipo == 1){
      sprintf(sLinea, "T1%ldCORP\tINIT\t", regCliente.numero_cliente);   
   }else{
	  sprintf(sLinea, "T1%ld\tINIT\t", regCliente.numero_cliente);
   }
   
   /* AKTYP*/
	strcat(sLinea, "01\t");
  
   /* VKONT luego será un valor de SF */
   if(iTipo == 2){
      if(regCliente.minist_repart > 0){
         sprintf(sLinea, "%s%ldCORP\t", sLinea, regCliente.minist_repart);
      }else{
         sprintf(sLinea, "%s%ld\t", sLinea, regCliente.numero_cliente);
      }
   }else{
      sprintf(sLinea, "%s%ld\t", sLinea, regCliente.numero_cliente);   
   }
   
   /* GPART */
	if (strcmp(sTarifa, "T1")==0){
		if(regCliente.minist_repart > 0){
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.minist_repart);
		}else{
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
		}
	}else{
		if(strcmp(regCliente.sCodCorpoPadreT23, "")!=0){
			sprintf(sLinea, "%sT23%s\t", sLinea, regCliente.sCodCorpoPadreT23);
		}else{
			strcat(sLinea, "\t");	
		}
	}

   /* VKTYP */
	sprintf(sLinea,"%s%s\t", sLinea, sTipoCuenta);
   /* VKONA */
	sprintf(sLinea, "%s%ld\t", sLinea, regCliente.numero_cliente);
   /* APPLK */
	strcat(sLinea, "R");

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
	
}

void GeneraVK(fp, regCliente, iTipo)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	
	int		iTipoPersona;

	memset(sLinea, '\0', sizeof(sLinea));
	
   if(iTipo == 1){
      sprintf(sLinea, "T1%ldCORP\tVK\t", regCliente.numero_cliente);
   }else{
      sprintf(sLinea, "T1%ld\tVK\t", regCliente.numero_cliente);
   }
	
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}

void GeneraVKLOCK(fp, regCliente, sTarifa, iTipo)
FILE *fp;
$ClsCliente	regCliente;
char	sTarifa[3];
int   iTipo;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));

   if(iTipo == 1){
      sprintf(sLinea, "T1%ldCORP\tVKLOCK\t", regCliente.numero_cliente);
   }else{
	  sprintf(sLinea, "T1%ld\tVKLOCK\t", regCliente.numero_cliente);
   }
   
   /* LOCKAKTYP */
	strcat(sLinea, "I\t");
	
   /* LOCKPARTNER */
	if(strcmp(sTarifa, "T1")==0){
		if(regCliente.minist_repart > 0){
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.minist_repart);
		}else{
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
		}
	}else{
		if(strcmp(regCliente.sCodCorpoPadreT23, "")!=0){
			sprintf(sLinea, "%sT23%ld\t", sLinea, regCliente.sCodCorpoPadreT23);
		}else{
			strcat(sLinea, "\t");	
		}
	}
   
   /* LOTYP_KEY */
   if(regCliente.tiene_corte_rest[0]=='S'){
      strcat(sLinea, "04\t"); /* Cuenta */
   }else{
      strcat(sLinea, "\t");
   }
   
   /* PROID_KEY */
   if(regCliente.tiene_corte_rest[0]=='S'){
      strcat(sLinea, "01\t"); /* Reclamacion */
   }else{
      strcat(sLinea, "\t");
   }

   /* LOCKR_KEY */		
   if(regCliente.tiene_corte_rest[0]=='S'){
      strcat(sLinea, "E\t"); /* Lock Reclamacion */
   }else{
      strcat(sLinea, "\t");
   }

   /* FDATE_KEY */
	strcat(sLinea, "\t");
   /* TDATE_KEY */
	strcat(sLinea, "\t");
	
	strcat(sLinea, "\t\t\t\t\t\t\t");
	
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);
}


void GeneraVKP(fp, regCliente, sTarifa, iTipo)
FILE *fp;
$ClsCliente	regCliente;
char	sTarifa[3];
int iTipo;
{
	char	sLinea[1000];	
	char	sTipoPago[2];
	char	sTipoReclamo[2];
	char	sEstrategiaReclamo[3];
	char	sAux[11];
	
	memset(sTipoPago, '\0', sizeof(sTipoPago));
	memset(sTipoReclamo, '\0', sizeof(sTipoReclamo));
	memset(sAux, '\0', sizeof(sAux));
	memset(sEstrategiaReclamo, '\0', sizeof(sEstrategiaReclamo));
	
   alltrim(regCliente.sTipoDebito, ' ');
   
	if(strcmp(regCliente.tipo_fpago, "D")==0){
		strcpy(sTipoPago, regCliente.sTipoDebito);
	}else if(strcmp(regCliente.tipo_fpago, "N")==0){
		strcpy(sTipoPago, "");
	}else{
		strcpy(sTipoPago, "K"); /* Ver como se que puede ser compensador */
	}

	/* Anulador de Reclamacion */	
	
	if(strcmp(regCliente.tipo_cliente, "M1")==0 || strcmp(regCliente.tipo_cliente, "P1")==0 || strcmp(regCliente.tipo_cliente, "N1")==0){
		strcpy(sTipoReclamo, "X");
		strcpy(sEstrategiaReclamo, "Z2");
	}else{
		strcpy(sTipoReclamo, "");
		strcpy(sEstrategiaReclamo, "Z1");
	}
	
   /* llave */
   if(iTipo == 1){
      sprintf(sLinea, "T1%ldCORP\tVKP\t",regCliente.numero_cliente);
   }else{
	  sprintf(sLinea, "T1%ld\tVKP\t",regCliente.numero_cliente);
   }

   /* PARTNER */
	if(strcmp(sTarifa, "T1")==0){	
		if(regCliente.minist_repart > 0){
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.minist_repart);	
		}else{
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
		}
	}else{
		if(strcmp(regCliente.sCodCorpoPadreT23, "")!=0){
			sprintf(sLinea, "%sT23%s\t", sLinea, regCliente.sCodCorpoPadreT23);
		}else{
			strcat(sLinea, "\t");	
		}
	}
   
   /* OPBUK */
	strcat(sLinea, "EDES\t");
   
   /* EZAWE */
	sprintf(sLinea, "%s%s\t", sLinea,  sTipoPago);
   
   /* ABWVK */
	strcat(sLinea, "\t");
   
   /* IKEY */
   strcat(sLinea, "Z1\t");
   
	/* MANSP */
	if(strcmp(sTarifa, "T1")==0){
		sprintf(sLinea, "%s%s\t", sLinea, sTipoReclamo);
	}else{
		strcat(sLinea, "\t");	
	}
   
	/* MGGRUP + VKONV + ABWRH */
	if(strcmp(sTarifa, "T1")==0){
      /* MGGRUP */
      strcat(sLinea, "\t");
      /* VKONV */
      if(iTipo ==1 ){
         sprintf(sLinea, "%sT1%ldCORP\t", sLinea, regCliente.numero_cliente); 
      }else{
         if(regCliente.minist_repart > 0){
            sprintf(sLinea, "%sT1%ldCORP\t", sLinea, regCliente.minist_repart);
         }else{
            strcat(sLinea, "\t");
         }
      }
      /* ABWRH */
		if(regCliente.minist_repart > 0){
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.minist_repart);	
		}else{
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
		}
		
	}else{
		strcat(sLinea, "\t");
		if(strcmp(regCliente.sCodCorpoT23, "000")==0){
			strcat(sLinea, "\t");	
		}else{
			if(strcmp(regCliente.sCodCorpoT23, "")!=0){
				sprintf(sLinea, "%sT23%s\t", sLinea, regCliente.sCodCorpoT23);
			}else{
				strcat(sLinea, "\t");	
			}
		}
		if(strcmp(regCliente.sCodCorpoPadreT23, "")!=0){
			sprintf(sLinea, "%sT23%s\t", sLinea, regCliente.sCodCorpoPadreT23);
		}else{
			strcat(sLinea, "\t");	
		}
	}
	
	/* ADRRH */
	if(strcmp(regCliente.tipo_reparto, "POSTAL")==0){
		sprintf(sAux, "POS_%ld", regCliente.numero_cliente);
	}else{
		sprintf(sAux, "SUM_%ld", regCliente.numero_cliente);
	}
	sprintf(sLinea, "%s%s\t", sLinea, sAux);
	
   /* BEGRU  + TOGRU */
	strcat(sLinea, "T1\tGTED\t");
   /* VBUND*/
	strcat(sLinea, "\t");
   
   /* ZAHLKOND */
	strcat(sLinea, "C010\t"); /* 10 días habiles */
   
   /* VERTYP */
	strcat(sLinea, "0001\t");
	
   /* KOFIZ_SD */
	if(strcmp(regCliente.tipo_cliente, "XX")==0){
		strcat(sLinea, "\t");	
	}else{
		sprintf(sLinea, "%s%s\t", sLinea, regCliente.tipo_cliente);
	}
   
   /* KTOKL*/
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.sCategoCuenta);
	
	/*
	strcat(sLinea, "Z_FORM_FACT_T1\t");
	*/
	
   /* FORMKEY */
	strcat(sLinea, "IS_U_BILL_SSF\t");
	
   /* AUSGRUP_IN + MANOUTS_IN */
	strcat(sLinea, "\t\t");
   
   /* GSBER */
   sprintf(sLinea, "%s%s\t", sLinea, regCliente.sCodSucurSap);
   
   /* CCARD_ID */
  	if(regCliente.tipo_fpago[0] == 'D'){
		if(regCliente.sTipoEntidadDebito[0]!='B'){
         strcat(sLinea, "000001\t");
      }else{
         strcat(sLinea, "\t");
      }
   }else{
      strcat(sLinea, "\t");
   }
   
   
   /* CORR_MAHNV */
   strcat(sLinea, "\t");
   /* FITYP */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.tipo_iva);
   /* PROVINCE */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.cod_provincia);
   /* COUNTY */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.comuna);
   
   /* GPARV */
	if(strcmp(sTarifa, "T1")==0){	
		if(regCliente.minist_repart > 0){
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.minist_repart);	
		}else{
			sprintf(sLinea, "%sT1%ld\t", sLinea, regCliente.numero_cliente);
		}
	}else{
		if(strcmp(regCliente.sCodCorpoPadreT23, "")!=0){
			sprintf(sLinea, "%sT23%s\t", sLinea, regCliente.sCodCorpoPadreT23);
		}else{
			strcat(sLinea, "\t");	
		}
	}
   
   
   /* LANDL */
	strcat(sLinea, "AR\t");

/*	
	if(regCliente.sFacturaDigital[0]=='S'){
		strcat(sLinea, "MAIL\t");	
	}else{
		strcat(sLinea, "\t");
	}
*/
   /* STDBK */	
	strcat(sLinea, "EDES\t");
	/* STRAT */
	sprintf(sLinea, "%s%s\t", sLinea, sEstrategiaReclamo);
	
   /* ZZ_FATTURA_EMAIL */
	if(regCliente.sFacturaDigital[0]=='S'){
		strcat(sLinea, "SI\t");	
	}else{
		strcat(sLinea, "NO\t");
	}

   /* ZZ_CANALE_STAMPA */   
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.sTipoRepartoSAP);
	
   /* ZZESCOB */
   if(strcmp(regCliente.sEstadoCobrabilidad, "")!=0)
      sprintf(sLinea, "%s%s", sLinea, regCliente.sEstadoCobrabilidad);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraVKTXEX(fp, regCliente, iTipo)
FILE *fp;
$ClsCliente	regCliente;
int   iTipo;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   if(iTipo == 1){
	  sprintf(sLinea, "T1%ldCORP\tVKTXEX\t", regCliente.numero_cliente);   
   }else{
	  sprintf(sLinea, "T1%ld\tVKTXEX\t", regCliente.numero_cliente);
   }
	strcat(sLinea, "I\t");
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.tipo_iva);
	strcat(sLinea, "\t\t\t\t\t\t");

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
}

void GeneraENDE(fp, regCliente, iTipo)
FILE *fp;
$ClsCliente	regCliente;
int   iTipo;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   if(iTipo == 1){
     sprintf(sLinea, "T1%ldCORP\t&ENDE", regCliente.numero_cliente);
   }else{
	  sprintf(sLinea, "T1%ld\t&ENDE", regCliente.numero_cliente);
   }

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	
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
			*iFlagMigra=1; /* Se debera hacer un insert */
			return 0;
		}else{
			printf("ErroR al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
		cantPreexistente++;
		return 1;
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
	return 0;
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

short CorporativoT23(regCliente)
$ClsCliente *regCliente;
{
	$int	iCant=0;

	$EXECUTE selCorpoT23 into :regCliente->sCodCorpoT23, 
							  :regCliente->sCodCorpoPadreT23 
						using :regCliente->numero_cliente;

	if(SQLCODE == SQLNOTFOUND)
		return 0;

	if(SQLCODE != 0){
		printf("ErroR al verificar si el cliente %ld es corporativo T23.\n",regCliente->numero_cliente);
		exit(1);
	}
	
	return 1;
}


short RegistraArchivo(nomArchivo, sTipoArchivo, iCant)
$char	nomArchivo[100];
$char	sTipoArchivo[21];
$long	iCant;
{
	$int iEstado=giEstadoCliente;
	$long	lNroCliente=glNroCliente;
	
	/*alltrim(sTipoArchivo, ' ');*/
	
	$EXECUTE updGenArchivos using :sTipoArchivo;
	
	if(SQLCODE !=0){
		printf("Fallo UpdateGenArchivos\n");
		exit(2);
	}
	
	$EXECUTE insGenPartner using
			:gsTipoGenera,
			:iCant,
			:lNroCliente,
			:nomArchivo;

	if(SQLCODE !=0){
		printf("Fallo insGenPartner\n");
		exit(2);
	}
		
	return 1;
}

short AbreArchivos(){

	memset(sArchCtaActivaUnx,'\0',sizeof(sArchCtaActivaUnx));
	memset(sArchCtaNoActivaUnx,'\0',sizeof(sArchCtaNoActivaUnx));
	memset(sArchCtaFicticiaUnx,'\0',sizeof(sArchCtaFicticiaUnx));
   memset(sArchCtaCorpoT1Unx,'\0',sizeof(sArchCtaCorpoT1Unx));

	memset(sArchCtaActivaDos,'\0',sizeof(sArchCtaActivaDos));
	memset(sArchCtaNoActivaDos,'\0',sizeof(sArchCtaNoActivaDos));
	memset(sArchCtaFicticiaDos,'\0',sizeof(sArchCtaFicticiaDos));

	memset(sSoloArchivoCtaActiva,'\0',sizeof(sSoloArchivoCtaActiva));
	memset(sSoloArchivoCtaNoActiva,'\0',sizeof(sSoloArchivoCtaNoActiva));
	memset(sSoloArchivoCtaFicticia,'\0',sizeof(sSoloArchivoCtaFicticia));
   memset(sSoloArchivoCtaCorpoT1,'\0',sizeof(sSoloArchivoCtaCorpoT1));

	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
    FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );

	alltrim(sPathSalida,' ');

	switch (giEstadoCliente){
		case 0: /* Activos */

			lCorrelativoActivo = getCorrelativo("CTACONTRA_ACTIVA");

		   sprintf( sArchCtaActivaUnx  , "%sT1ACCOUNT_ACTIVA.unx", sPathSalida );
			strcpy( sSoloArchivoCtaActiva, "T1ACCOUNT_ACTIVA.unx" );

			pFileCtaActivaUnx=fopen( sArchCtaActivaUnx, "w" );
			if( !pFileCtaActivaUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchCtaActivaUnx );
				return 0;
			}

         /* Corpo T1 */
/*         
		   sprintf( sArchCtaCorpoT1Unx  , "%sT1ACCOUNT_CORPOT1.unx", sPathSalida );
			strcpy( sSoloArchivoCtaCorpoT1, "T1ACCOUNT_CORPOT1.unx" );

			pFileCtaCorpoT1Unx=fopen( sArchCtaCorpoT1Unx, "w" );
			if( !pFileCtaCorpoT1Unx ){
				printf("ERROR al abrir archivo %s.\n", sArchCtaCorpoT1Unx );
				return 0;
			}
*/
			break;
			
		case 1: /* No Activos */
			lCorrelativoNoActivo = getCorrelativo("CTACONTRA_NOACTIVA");
		
		   sprintf( sArchCtaNoActivaUnx  , "%sT1ACCOUNT_INACTIVA.unx", sPathSalida );
			strcpy( sSoloArchivoCtaNoActiva, "T1ACCOUNT_INACTIVA.unx");
		
			pFileCtaNoActivaUnx=fopen( sArchCtaNoActivaUnx, "w" );
			if( !pFileCtaNoActivaUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchCtaNoActivaUnx );
				return 0;
			}			
			
			break;
			
		case 2:	/* Activos y No Activos */
			lCorrelativoActivo = getCorrelativo("CTACONTRA_ACTIVA");
		
		   sprintf( sArchCtaActivaUnx  , "%sCtaContratoActiva_T1_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativoActivo );
			sprintf( sSoloArchivoCtaActiva, "CtaContratoActiva_T1_%s_%d.txt", FechaGeneracion, lCorrelativoActivo );
		
			pFileCtaActivaUnx=fopen( sArchCtaActivaUnx, "w" );
			if( !pFileCtaActivaUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchCtaActivaUnx );
				return 0;
			}

			lCorrelativoNoActivo = getCorrelativo("CTACONTRA_NOACTIVA");
		
		    sprintf( sArchCtaNoActivaUnx  , "%sCtaContratoNoActiva_T1_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativoNoActivo );
			sprintf( sSoloArchivoCtaNoActiva, "CtaContratoNoActiva_T1_%s_%d.txt", FechaGeneracion, lCorrelativoNoActivo );
		
			pFileCtaNoActivaUnx=fopen( sArchCtaNoActivaUnx, "w" );
			if( !pFileCtaNoActivaUnx ){
				printf("ERROR al abrir archivo %s.\n", sArchCtaNoActivaUnx );
				return 0;
			}						
			break;
	}

	lCorrelativoFicticia = getCorrelativo("CTACONTRA_FICTICIA");

    sprintf( sArchCtaFicticiaUnx  , "%sT1ACCOUNT_CorpoT23.unx", sPathSalida);
	strcpy( sSoloArchivoCtaFicticia, "T1ACCOUNT_CorpoT23.unx");

	pFileCtaFicticiaUnx=fopen( sArchCtaFicticiaUnx, "w" );
	if( !pFileCtaFicticiaUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchCtaFicticiaUnx );
		return 0;
	}

	return 1;	
}

void CierroArchivos(){
	switch (giEstadoCliente){
		case 0:
			fclose(pFileCtaActivaUnx);
         /*fclose(pFileCtaCorpoT1Unx);*/
			break;
		case 1:
			fclose(pFileCtaNoActivaUnx);
			break;			
		case 2:	
			fclose(pFileCtaActivaUnx);
			fclose(pFileCtaNoActivaUnx);
			break;
	}
	fclose(pFileCtaFicticiaUnx);
}

void AdministraPlanos(){
	switch(giEstadoCliente){
		case 0:
			if(cantActivoProcesada>0){
				if(!RegistraArchivo(sSoloArchivoCtaActiva, "CTACONTRA_ACTIVA", cantActivoProcesada)){
					$ROLLBACK WORK;
					exit(1);
				}
			}

			if(cantFicticia > 0){
				if(!RegistraArchivo(sSoloArchivoCtaFicticia, "CTACONTRA_FICTICIA", cantFicticia)){
					$ROLLBACK WORK;
					exit(1);
				}
			}
			break;
			
		case 1:
			if(cantNoActivoProcesada > 0){
				if(!RegistraArchivo(sSoloArchivoCtaNoActiva, "CTACONTRA_NOACTIVA", cantNoActivoProcesada)){
					$ROLLBACK WORK;
					exit(1);
				}
			}
			break;
			
		case 2:	
			if(cantActivoProcesada>0){
				if(!RegistraArchivo(sSoloArchivoCtaActiva, "CTACONTRA_ACTIVA", cantActivoProcesada)){
					$ROLLBACK WORK;
					exit(1);
				}
			}
			if(cantNoActivoProcesada > 0){
				if(!RegistraArchivo(sSoloArchivoCtaNoActiva, "CTACONTRA_NOACTIVA", cantNoActivoProcesada)){
					$ROLLBACK WORK;
					exit(1);
				}
			}
			if(cantFicticia > 0){
				if(!RegistraArchivo(sSoloArchivoCtaFicticia, "CTACONTRA_FICTICIA", cantFicticia)){
					$ROLLBACK WORK;
					exit(1);
				}
			}
			break;			
	}	
}


short GenerarPlanoT23(fp, regCliente)
FILE 			*fp;
$ClsCliente		regCliente;
{
		
	/* INIT */
	GeneraINIT(fp, regCliente, "T2", 0);

	/* VK */
	GeneraVK(fp, regCliente, 0);

	/* VKP */
	GeneraVKP(fp, regCliente, "T2", 0);

	/* VKLOCK */
	/*GeneraVKLOCK(fp, regCliente, "T2", 0);*/

	/* VKTXEX */
	/*GeneraVKTXEX(fp, regCliente, 0);*/

	/* ENDE */
	GeneraENDE(fp, regCliente, 0);

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


static char *strReplace(sCadena, cFind, cRemp)
char *sCadena;
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;

	memset(sNvaCadena, '\0', sizeof(sNvaCadena));
	
	lLargo=strlen(sCadena);

    if (lLargo == 0)
    	return sCadena;

	for(lPos=0; lPos<lLargo; lPos++){

       if (sCadena[lPos] != cFind[0]) {
       	sNvaCadena[lPos]=sCadena[lPos];
       }else{
	       if(strcmp(cRemp, "")!=0){
	       		sNvaCadena[lPos]=cRemp[0];  
	       }else {
	            sNvaCadena[lPos]=' ';   
	       }
       }
	}

	return sNvaCadena;
}

void FormateaArchivos(void){
char	sCommand[1000];
char	sDestino[100];
int		iRcv, i;
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sDestino, '\0', sizeof(sDestino));
	
	if(giEstadoCliente==0){
		strcpy(sDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");
	}else{
		strcpy(sDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");
	}

	if(cantActivoProcesada>0){
		sprintf(sCommand, "chmod 755 %s", sArchCtaActivaUnx);
		iRcv=system(sCommand);		
		sprintf(sCommand, "cp %s %s", sArchCtaActivaUnx, sDestino);
		iRcv=system(sCommand);
	}

	if(cantNoActivoProcesada>0){
		sprintf(sCommand, "chmod 755 %s", sArchCtaNoActivaUnx);
		iRcv=system(sCommand);		
		sprintf(sCommand, "cp %s %s", sArchCtaNoActivaUnx, sDestino);
		iRcv=system(sCommand);
	}

	if(cantFicticia>0){
		sprintf(sCommand, "chmod 755 %s", sArchCtaFicticiaUnx);
		iRcv=system(sCommand);		
		sprintf(sCommand, "cp %s %s", sArchCtaFicticiaUnx, sDestino);
		iRcv=system(sCommand);
	}

	if(cantCorpoT1>0){
		sprintf(sCommand, "chmod 755 %s", sArchCtaCorpoT1Unx);
		iRcv=system(sCommand);		
		sprintf(sCommand, "cp %s %s", sArchCtaCorpoT1Unx, sDestino);
		iRcv=system(sCommand);
	}
	
/*
	if(cantActivoProcesada>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchCtaActivaUnx, sArchCtaActivaDos);
		iRcv=system(sCommand);
	}

	if(cantNoActivoProcesada>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchCtaNoActivaUnx, sArchCtaNoActivaDos);
		iRcv=system(sCommand);
	}

	if(cantFicticia>0){
		sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchCtaFicticiaUnx, sArchCtaFicticiaDos);
		iRcv=system(sCommand);
	}


	sprintf(sCommand, "rm -f %s", sArchCtaActivaUnx);
	iRcv=system(sCommand);	

	sprintf(sCommand, "rm -f %s", sArchCtaNoActivaUnx);
	iRcv=system(sCommand);	

	sprintf(sCommand, "rm -f %s", sArchCtaFicticiaUnx);
	iRcv=system(sCommand);		
*/
}

