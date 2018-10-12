/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_partner
    
	Fecha : 01/09/2016

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para la estructura INTERLOCUTOR COMERCIAL T1
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Estado Cliente>: 0 = Activo; 1 = No Activo; 2 = Todos
		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
					   
		<Nro Cliente>: Opcional. Si se carga el valor, se extrae SOLO para el cliente en cuestion

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_partner.h";

/* Variables Globales */
$int	giEstadoCliente;
$char	gsSucursal[5];
$int	giPlan;
$long	glNroCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;

long	cantProcesada;
long 	cantPreexistente;
long	cantActivos;
long	cantNoActivos;

int		CantTipoRegistro;

/* Variables Globales Host */
$ClsCliente	regCliente;

char	sMensMail[1024];

FILE	*pFileLog;
char	sArchLogUnx[100];


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;

FILE	*pFileUnx;
char	sArchUnx[100];
char	sArchDos[100];
char	sSoloArchivo[100];

FILE	*pFileCorpoUnx;
char	sArchCorpoUnx[100];
char	sSoloArchivoCorpo[100];

FILE	*pFileInactivosUnx;
char	sArchInactivosUnx[100];
char	sArchInactivosDos[100];
char	sSoloInactivosArchivo[100];

char	sPathSalida[100];
char	sPathDestino[100];

char	FechaGeneracion[9];	
char	MsgControl[100];
char	sCommand[100];
int		iRcv, i;
$char	fecha[9];
long	lCorrelativo;

$ClsCliente	  regCliente;
$ClsFormaPago regFP;
$ClsTelefonos  *regTelefonos=NULL;
$ClsEmail     regEmail;
int		iCantTelefonos;
int		iCantEmail;
int		iEsCorpo;
int		iFlagMigra;

long  lCantInFiles;

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
	memset(sArchUnx,'\0',sizeof(sArchUnx));
	memset(sArchDos,'\0',sizeof(sArchDos));
	memset(sSoloArchivo,'\0',sizeof(sSoloArchivo));

	memset(sArchCorpoUnx,'\0',sizeof(sArchCorpoUnx));
	memset(sSoloArchivoCorpo,'\0',sizeof(sSoloArchivoCorpo));
	
	memset(FechaGeneracion,'\0',sizeof(FechaGeneracion));
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathDestino,'\0',sizeof(sPathDestino));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');
   
	RutaArchivos( sPathDestino, "SAPCPY" );
	alltrim(sPathDestino,' ');

	if(giEstadoCliente==0){
		/******** Activos ********/	
		/*
	    sprintf( sArchUnx  , "%sPartnerIC_T1_Activos_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativo );
	    sprintf( sArchDos  , "%sPartnerIC_T1_Activos_%s_%d.txt", sPathSalida, FechaGeneracion, lCorrelativo );
		sprintf( sSoloArchivo, "PartnerIC_T1_Activos_%s_%d.txt", FechaGeneracion, lCorrelativo );
		*/
	   sprintf( sArchUnx  , "%sT1PARTNER_Activos.unx", sPathSalida);
		strcpy( sSoloArchivo, "T1PARTNER_Activos.unx");
			
		pFileUnx=fopen( sArchUnx, "w" );
		if( !pFileUnx ){
			printf("ERROR al abrir archivo %s.\n", sArchUnx );
			exit(1);
		}

	   sprintf( sArchCorpoUnx  , "%sT1PARTNER_CORPO_Activos.unx", sPathSalida);
		strcpy( sSoloArchivoCorpo, "T1PARTNER_CORPO_Activos.unx");
			
		pFileCorpoUnx=fopen( sArchCorpoUnx, "w" );
		if( !pFileCorpoUnx ){
			printf("ERROR al abrir archivo %s.\n", sArchCorpoUnx );
			exit(1);
		}
	}else{
		/******** No Activos ********/	
		/*
	    sprintf( sArchInactivosUnx  , "%sPartnerIC_T1_NoActivos_%s_%d.unx", sPathSalida, FechaGeneracion, lCorrelativo );
	    sprintf( sArchInactivosDos  , "%sPartnerIC_T1_NoActivos_%s_%d.txt", sPathSalida, FechaGeneracion, lCorrelativo );
		sprintf( sSoloInactivosArchivo, "PartnerIC_T1_NoActivos_%s_%d.txt", FechaGeneracion, lCorrelativo );
		*/
	    sprintf( sArchUnx  , "%sT1PARTNER_Inactivos.unx", sPathSalida);
		strcpy( sSoloArchivo, "T1PARTNER_Inactivos.unx");
		
		pFileUnx=fopen( sArchUnx, "w" );
		if( !pFileUnx ){
			printf("ERROR al abrir archivo %s.\n", sArchUnx );
			exit(1);
		}
	}
	
	/******** Log ********/	
    sprintf( sArchLogUnx  , "%sPartnerIC_Log_%s_%d.log", sPathSalida, FechaGeneracion, lCorrelativo );

	pFileLog=fopen( sArchLogUnx, "w" );
	if( !pFileLog ){
		printf("ERROR al abrir archivo %s.\n", sArchLogUnx );
		exit(1);
	}

	cantActivos=0;
	cantNoActivos=0;			
	cantProcesada=0;
	cantPreexistente=0;

	if(glNroCliente > 0 ){
    	$OPEN curClientes using :glNroCliente;
    }else{
		$OPEN curClientes;
	}

 	/* Borro Registro Contingente del Corporativo T1 */
   printf("Inicializando Corporativoss.\n");
   $BEGIN WORK;
   
	if(!BorraCorpoT1()){
		$ROLLBACK WORK;
		exit(1);	
	}
   
   $COMMIT WORK;	

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   lCantInFiles=0;
	iEsCorpo=0;
	while(LeoClientes(&regCliente, &regFP)){
      /*$BEGIN WORK;*/
		if(regCliente.estado_cliente[0]=='0'){
			iFlagMigra=0;
			if(! ClienteYaMigrado(regCliente.numero_cliente, 1, &iFlagMigra)){

				if(! CorporativoT23(regCliente.numero_cliente)){  /* Modifique esta función para que diga siempre que no es corpot23 */
					/* Vemos que no sea hijo de un corporativo propio */

					if(risnull(CLONGTYPE, (char *) &regCliente.minist_repart) || regCliente.minist_repart <= 0){
						iEsCorpo=0;

						/* Cargar Telefonos */
						iCantTelefonos=0;
						if(! CargaTelefonos(regCliente, &(regTelefonos), &iCantTelefonos)){
							exit(1);
						}

						/* Cargar eMail */
						iCantEmail=0;
						if(! CargaEmail(regCliente, &regEmail, &iCantEmail)){
							exit(1);
						}		

						/* Generar Plano */
						if (!GenerarPlano(pFileUnx, regCliente, regFP, regTelefonos, regEmail, iCantTelefonos, iCantEmail, iEsCorpo)){
							printf("Error al generar el archivo\n");
							exit(1);	
						}
                  lCantInFiles++;

						/* Registrar Control Cliente */
                  $BEGIN WORK;
						if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
							$ROLLBACK WORK;
							exit(1);	
						}
                  $COMMIT WORK;
						cantProcesada++;
						cantActivos++;
					}else{
/***************  Se le crea el partner al hijo y luego veo si le tengo que generar el partner a su papa 06/07/2018 */
						/* Cargar Telefonos */
						iCantTelefonos=0;
						if(! CargaTelefonos(regCliente, &(regTelefonos), &iCantTelefonos)){
							exit(1);
						}
						/* Cargar eMail */
						iCantEmail=0;
						if(! CargaEmail(regCliente, &regEmail, &iCantEmail)){
							exit(1);
						}		
						/* Generar Plano */
						if (!GenerarPlano(pFileUnx, regCliente, regFP, regTelefonos, regEmail, iCantTelefonos, iCantEmail, iEsCorpo)){
							printf("Error al generar el archivo\n");
							exit(1);	
						}
                  lCantInFiles++;
						/* Registrar Control Cliente */
                  $BEGIN WORK;
						if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
							$ROLLBACK WORK;
							exit(1);	
						}
                  $COMMIT WORK;
						cantProcesada++;
						cantActivos++;
/****************/
						if(LeoCorpoPropio(&regCliente, &regFP)){

							iEsCorpo=1;
							iFlagMigra=0;
							if(! ClienteYaMigrado(regCliente.numero_cliente, 2, &iFlagMigra)){
								if(! CorporativoT23(regCliente.numero_cliente)){
									/* Cargar Telefonos */
									iCantTelefonos=0;
									if(! CargaTelefonos(regCliente, &(regTelefonos), &iCantTelefonos)){
										exit(1);
									}
									
									/* Cargar eMail */
									iCantEmail=0;
									if(! CargaEmail(regCliente, &regEmail, &iCantEmail)){
										exit(1);
									}		
									
									/* Generar Plano */
									if (!GenerarPlano(pFileCorpoUnx, regCliente, regFP, regTelefonos, regEmail, iCantTelefonos, iCantEmail, iEsCorpo)){
                              printf("Error al generar el archivo\n");
										exit(1);	
									}
                           lCantInFiles++;
									$BEGIN WORK;
									/* Registrar Control Cliente */
									if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
										$ROLLBACK WORK;
										exit(1);	
									}

									/* Registro Contingente del Corporativo T1 */
									if(!RegistraCorpoT1(regCliente.numero_cliente)){
										$ROLLBACK WORK;
										exit(1);	
									}
									$COMMIT WORK;
									cantProcesada++;
									cantActivos++;
								}
							}
						}
					}
				}/* Verif Corpo T23 */
				
			}/* Verif de Cliente ya migrado*/
		}else{
			/* CLIENTES NO ACTIVOS */
			iFlagMigra=0;
			if(! ClienteYaMigrado(regCliente.numero_cliente, 1, &iFlagMigra)){
				iEsCorpo=0;
				/* Cargar Telefonos */
				iCantTelefonos=0;
				if(! CargaTelefonos(regCliente, &(regTelefonos), &iCantTelefonos)){
					exit(1);
				}
				
				/* Cargar eMail */
				iCantEmail=0;
				if(! CargaEmail(regCliente, &regEmail, &iCantEmail)){
					exit(1);
				}		

            /* Carga ID Sales Forces */
/*            
            if(! CargaIdSF(&regCliente)){
					$ROLLBACK WORK;
					exit(1);
            }
*/				
				/* Generar Plano */
				if (!GenerarPlano(pFileUnx, regCliente, regFP, regTelefonos, regEmail, iCantTelefonos, iCantEmail, iEsCorpo)){
					printf("Error al generar archivo\n");
					exit(1);	
				}
				lCantInFiles++;
				/* Registrar Control Cliente */
            $BEGIN WORK;
				if(!RegistraCliente(regCliente.numero_cliente, iFlagMigra)){
					$ROLLBACK WORK;
					exit(1);	
				}
            $COMMIT WORK;
				cantNoActivos++;
				cantProcesada++;
			}
		}/* Verif Estado Cliente */
      /*$COMMIT WORK;*/
		
	}/* Fin While */

	$CLOSE curClientes;
	
	fclose(pFileUnx);
	fclose(pFileCorpoUnx);
	fclose(pFileLog);
	
	/* Registrar Control Plano */
/*   
	if(!RegistraArchivo(sSoloArchivo, cantProcesada)){
		$ROLLBACK WORK;
		exit(1);
	}
*/	


	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */
		
	
	if(giEstadoCliente==0){
		/*strcpy(sPathDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      strcat(sPathDestino, "Activos/");
	}else{
		/*strcpy(sPathDestino, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      strcat(sPathDestino, "Inactivos/");
	}

	sprintf(sCommand, "chmod 755 %s", sArchUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchUnx, sPathDestino);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchUnx);
      iRcv=system(sCommand);
   }

  	sprintf(sCommand, "chmod 755 %s", sArchCorpoUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchCorpoUnx, sPathDestino);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchCorpoUnx);
      iRcv=system(sCommand);
   }

	
/*
	memset(sCommand, '\0', sizeof(sCommand));
	sprintf(sCommand, "ux2dos %s | tr -d '\32' > %s", sArchUnx, sArchDos);
	iRcv=system(sCommand);
	sprintf(sCommand, "rm -f %s", sArchUnx);
	iRcv=system(sCommand);	
*/
	/***** No Activos ****/
/*
	memset(sCommand, '\0', sizeof(sCommand));
	sprintf(sCommand, "ux2dos %s | tr -d '\32' > %s", sArchInactivosUnx, sArchInactivosDos);
	iRcv=system(sCommand);
	sprintf(sCommand, "rm -f %s", sArchInactivosUnx);
	iRcv=system(sCommand);	
*/
	
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
	printf("INTERLOCUTOR COMERCIAL.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Extraídos :    %ld \n",cantProcesada);
	printf("Clientes Activos :      %ld \n",cantActivos);
	printf("Clientes No Activos :   %ld \n",cantNoActivos);
	printf("Clientes Preexistentes: %ld \n",cantPreexistente);
   printf("Clientes En Archivo   : %ld \n",lCantInFiles);
	printf("==============================================\n");
	printf("Archivo Salida: %s\n", sArchUnx);
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

	if(argc > 6 || argc < 5){
		MensajeParametros();
		return 0;
	}
	
	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0){
		MensajeParametros();
		return 0;	
	}

	
	giEstadoCliente=atoi(argv[2]);
	strcpy(gsTipoGenera, argv[3]);
   giTipoCorrida=atoi(argv[4]);
	
	if(argc == 6){	
		glNroCliente=atol(argv[5]);
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
      printf("\t<Tipo Corrida> 0 = Normal, 1 = Reducida.\n");
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
	
	/******** Cursor Clientes  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
	
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.nombre IS NOT NULL AND c.nombre != ' ' THEN UPPER(c.nombre[1,40]) ");
	strcat(sql, " 	ELSE 'SIN NOMBRE' ");
	strcat(sql, "END, ");

	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, '0000') actividad_economica, "); 

	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.cod_calle), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_calle), UPPER(c.nom_calle)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_nro_dir, c.nro_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_piso_dir, c.piso_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_depto_dir, c.depto_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre), UPPER(c.nom_entre)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre1), UPPER(c.nom_entre1)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', t4.cod_sap, t2.cod_sap) provincia, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.partido), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_partido), UPPER(c.nom_partido)), ");
	strcat(sql, "c.comuna, ");
	strcat(sql, "c.nom_comuna, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_cod_postal, c.cod_postal), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.obs_dir[1,40]), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_telefono, c.telefono), ");

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
	strcat(sql, "f.fp_cbu ");
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3, ");
	strcat(sql, "OUTER forma_pago f, OUTER (postal p, sap_transforma t4) ");
   
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
	
/*	
	strcat(sql, "ORDER BY c.numero_cliente ");
*/

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;		
	
	
	/********* Select Corporativo Propio**********/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "UPPER(c.nombre[1,40]), ");
	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, '0000') actividad_economica, "); 
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.cod_calle), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_calle), UPPER(c.nom_calle)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_nro_dir, c.nro_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_piso_dir, c.piso_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_depto_dir, c.depto_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre), UPPER(c.nom_entre)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre1), UPPER(c.nom_entre1)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', t4.cod_sap, t2.cod_sap) provincia, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.partido), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_partido), UPPER(c.nom_partido)), ");
	strcat(sql, "c.comuna, ");
	strcat(sql, "c.nom_comuna, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_cod_postal, c.cod_postal), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.obs_dir[1,40]), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_telefono, c.telefono), ");
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
	strcat(sql, "f.fp_cbu ");
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3, ");
	strcat(sql, "OUTER forma_pago f, OUTER (postal p, sap_transforma t4) ");
	strcat(sql, "WHERE c.numero_cliente = ? ");	
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

	$PREPARE selCorpoPropio FROM $sql;
		
	/***** Cursor Direccion Postal Hijos *******/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "UPPER(c.nombre[1,40]), ");
	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "NVL(t1.cod_sap, '0000') actividad_economica, "); 
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.cod_calle), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_calle), UPPER(c.nom_calle)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_nro_dir, c.nro_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_piso_dir, c.piso_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_depto_dir, c.depto_dir), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre), UPPER(c.nom_entre)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_entre1), UPPER(c.nom_entre1)), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', t4.cod_sap, t2.cod_sap) provincia, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.partido), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', UPPER(p.dp_nom_partido), UPPER(c.nom_partido)), ");
	strcat(sql, "c.comuna, ");
	strcat(sql, "c.nom_comuna, ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_cod_postal, c.cod_postal), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', ' ', c.obs_dir[1,40]), ");
	strcat(sql, "DECODE (c.tipo_reparto,'POSTAL', p.dp_telefono, c.telefono), ");
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
	strcat(sql, "f.fp_cbu ");
	strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3, ");
	strcat(sql, "OUTER forma_pago f, OUTER (postal p, sap_transforma t4) ");
	strcat(sql, "WHERE c.minist_repart = ? ");	
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

	$PREPARE selPostalesHijos  FROM $sql;
	
	$DECLARE curPostalHijos CURSOR FOR selPostalesHijos;
	
	/******** Cursor Telefonos  ****************/
	strcpy(sql, "SELECT tipo_te, ");
	strcat(sql, "cod_area_te, ");
	strcat(sql, "prefijo_te, ");
	strcat(sql, "TO_CHAR(numero_te), ");
	strcat(sql, "ppal_te ");
	strcat(sql, "FROM telefono ");
	strcat(sql, "WHERE cliente =	? ");
	strcat(sql, "AND ppal_te = 'P' ");
	strcat(sql, "UNION ");
	strcat(sql, "SELECT tipo_te, ");
	strcat(sql, "cod_area_te, ");
	strcat(sql, "prefijo_te, ");
	strcat(sql, "TO_CHAR(numero_te), ");
	strcat(sql, "ppal_te ");
	strcat(sql, "FROM telefono ");
	strcat(sql, "WHERE cliente =	? ");
	strcat(sql, "AND ppal_te != 'P' ");	

	$PREPARE selTelefonos FROM $sql;
	
	$DECLARE curTelefonos CURSOR FOR selTelefonos;	
	
	/******** Cursor email  ****************/
	strcpy(sql, "SELECT FIRST 1 email_1, ");
	strcat(sql, "email_2, ");
	strcat(sql, "email_3 ");
	strcat(sql, "FROM clientes_digital ");
	strcat(sql, "WHERE numero_cliente =	? ");
	strcat(sql, "AND fecha_alta <= TODAY ");
	strcat(sql, "AND (fecha_baja IS NULL OR fecha_baja > TODAY) ");
	
	$PREPARE selEmail FROM $sql;

	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/********* Select Tipo Entidad Debito **********/
	strcpy(sql, "SELECT tipo ");
	strcat(sql, "FROM entidades_debito ");
	strcat(sql, "WHERE oficina = ? ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
	
	$PREPARE selTipoDebito	FROM $sql;
	
	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT interloc_comercial FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;
	
	/********* Select Corporativo T23 **********/
	strcpy(sql, "SELECT COUNT(*) FROM mg_corpor_t23 ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selCorpoT23 FROM $sql;

	/******** Select Correlativo ****************/
	strcpy(sql, "SELECT correlativo +1 FROM sap_gen_archivos ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = 'PARTNER' ");
	
	/*$PREPARE selCorrelativo FROM $sql;*/
	
	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = 'PARTNER' ");
	
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
	strcat(sql, "'INTERLOC_COMERCIAL', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");	
	
	/*$PREPARE insGenPartner FROM $sql;*/
	
	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, interloc_comercial ");
	strcat(sql, ")VALUES(?, 'S') ");

	$PREPARE insClientesMigra FROM $sql;
	
	/*********Updae Clientes extraidos **********/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "interloc_comercial = 'S' ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/********* get Codigo Tarjetas **********/
	strcpy(sql, "SELECT cod_sap FROM sap_transforma ");
	strcat(sql, "WHERE clave = 'CARDTYPE' ");
	strcat(sql, "AND cod_mac = ? ");

	$PREPARE selCodTarjeta FROM $sql;

	/********* Select corpoT1migrado **********/
	strcpy(sql, "SELECT COUNT(*) FROM corpoT1migrado ");
	strcat(sql, "WHERE numero_cliente = ? ");

	$PREPARE selCorpoT1migrado FROM $sql;

	/********* Insert corpoT1migrado **********/	
	strcpy(sql, "INSERT INTO corpoT1migrado ( numero_cliente )VALUES( ? ) ");
	
	$PREPARE insCorpoT1migrado FROM $sql;
	
	/********* Delete corpoT1migrado **********/
	strcpy(sql, "DELETE FROM corpoT1migrado	");
	
	$PREPARE delCorpoT1migrado FROM $sql;
   
   /************* Valida Forma Pago ************/
   $PREPARE selFPago FROM "SELECT COUNT(*) FROM forma_pago
      WHERE numero_cliente = ?
      AND fecha_activacion <= TODAY
      AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";

   
   /************* Buscar ID Sales Forces ************/
/*   
	strcpy(sql, "SELECT account FROM sap_sfc_inter ");
	strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE selAccount FROM $sql;   
*/   
   
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
long getCorrelativo(void){
$long iValor=0;

	$EXECUTE selCorrelativo INTO :iValor;
	
    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el correlativo del archivo.\n");
        exit(1);
    }	
    
    return iValor;
}
*/
short LeoClientes(regCli, regFP)
$ClsCliente *regCli;
$ClsFormaPago *regFP;
{
   $int  iValor;
   
	InicializaCliente(regCli, regFP);
	
	$FETCH curClientes into
		:regCli->numero_cliente,
		:regCli->nombre,
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
		:regFP->fp_cbu;

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
		
	alltrim(regCli->nombre, ' ');
	alltrim(regCli->obs_dir, ' ');
	
	/* Reemp Comillas y # */
	strcpy(regCli->nombre, strReplace(regCli->nombre, "'", " "));
	strcpy(regCli->nombre, strReplace(regCli->nombre, "#", "Ñ"));
	
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "'", " "));
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "#", "Ñ"));
	
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "'", " "));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "#", "Ñ"));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "*", " "));
	
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "'", " "));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "#", "Ñ"));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "*", " "));
	
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "'", " "));
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "#", "Ñ"));

	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "'", " "));
	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "#", "Ñ"));
		
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "'", " "));
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "#", "Ñ"));
			
      
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


short LeoHijos(regCli, regFP)
$ClsCliente *regCli;
$ClsFormaPago *regFP;
{
	InicializaCliente(regCli, regFP);
	
	$FETCH curPostalHijos into
		:regCli->numero_cliente,
		:regCli->nombre,
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
		:regFP->fp_cbu;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Hijos !!!\nProceso Abortado.\n");
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
		
	alltrim(regCli->nombre, ' ');
	alltrim(regCli->obs_dir, ' ');
	alltrim(regCli->tipo_reparto, ' ');
	
	/* Reemp Comillas */
	strcpy(regCli->nombre, strReplace(regCli->nombre, "'", " "));
	strcpy(regCli->nombre, strReplace(regCli->nombre, "#", "Ñ"));
	
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "'", " "));
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "#", "Ñ"));
	
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "'", " "));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "#", "Ñ"));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "*", " "));
	
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "'", " "));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "#", "Ñ"));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "*", " "));
	
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "'", " "));
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "#", "Ñ"));

	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "'", " "));
	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "#", "Ñ"));
		
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "'", " "));
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "#", "Ñ"));
			
	return 1;	
}

void InicializaCliente(regCli, regFP)
$ClsCliente	*regCli;
$ClsFormaPago *regFP;
{

	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
	memset(regCli->nombre, '\0', sizeof(regCli->nombre));
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
	
	memset(regFP->fp_banco, '\0', sizeof(regFP->fp_banco));
	memset(regFP->fp_tipocuenta, '\0', sizeof(regFP->fp_tipocuenta));
	memset(regFP->fp_nrocuenta, '\0', sizeof(regFP->fp_nrocuenta));
	rsetnull(CINTTYPE, (char *) &(regFP->fp_sucursal));
	rsetnull(CLONGTYPE, (char *) &(regFP->fecha_activacion));
	rsetnull(CLONGTYPE, (char *) &(regFP->fecha_desactivac));
	memset(regFP->fp_cbu, '\0', sizeof(regFP->fp_cbu));
   memset(regCli->sAccount, '\0', sizeof(regCli->sAccount));
	
}

void InicializaTelefonos(reg)
$ClsTelefonos *reg;
{

	memset(reg->tipo_te, '\0', sizeof(reg->tipo_te));
	memset(reg->cod_area_te, '\0', sizeof(reg->cod_area_te));
	memset(reg->prefijo_te, '\0', sizeof(reg->prefijo_te));
	rsetnull(CLONGTYPE, (char *) &(reg->numero_te));
	memset(reg->ppal_te, '\0', sizeof(reg->ppal_te));

}

void InicializaEmail(reg)
$ClsEmail  *reg;
{
	memset(reg->email1, '\0', sizeof(reg->email1));
	memset(reg->email2, '\0', sizeof(reg->email2));
	memset(reg->email3, '\0', sizeof(reg->email3));
}

short CargaEmail(regCliente, regEmail, iCant)
$ClsCliente regCliente;
$ClsEmail *regEmail;
int	*iCant;
{
	InicializaEmail(regEmail);

	$EXECUTE selEmail into
			:regEmail->email1,
			:regEmail->email2,
			:regEmail->email3
		using :regCliente.numero_cliente;
		
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			return 1;	
		}else{
			printf("Error al buscar eMail para cliente %ld.\nCargaEmal()\n",regCliente.numero_cliente);
			return 0;
		}	
	}
	
	*iCant=1;
	
	return 1;
}

short GenerarPlano(fp, regCliente, regFpago, regTelefonos, regEmail, iCantTelefonos, iCantEmail, iEsCorpo)
FILE 			*fp;
$ClsCliente		regCliente;
$ClsFormaPago	regFpago;
ClsTelefonos 	*regTelefonos;
ClsEmail		regEmail;
int				iCantTelefonos;
int				iCantEmail;
int				iEsCorpo;
{
	char	sTipoDD[2];
	
	$ClsCliente	regHijos;
	$ClsFormaPago regFpHijos;
   $ClsEmail	  regEmailHijos;
	char		*sDireccionPostal[1000];
	char		sDirPostalAux[200];
	int			indice=0;
	int			i,s;
	int 		iSalida=0;
	char		sLineaLog[1000];
   int      iCantMail;
	
	memset(sLineaLog, '\0', sizeof(sLineaLog));
	
	if(regCliente.tipo_fpago[0] == 'D'){
		/* Tengo que ver si es banco o tarjeta */
		strcpy(sTipoDD, getTipoDD(regFpago.fp_banco, &iSalida));
		if(iSalida==1){
			strcpy(regCliente.tipo_fpago, "N");
			sprintf(sLineaLog, "Se cambio forma pago a NORMAL para cliente %ld\n", regCliente.numero_cliente);
			fprintf(pFileLog, sLineaLog);
		}
	}

	/* INIT */
	GeneraINIT(fp, regCliente);
	
	/* BUT000 */
	GeneraBUT000(fp, regCliente);
	
	/* BUTCOM */
	GeneraBUTCOM(fp, regCliente, regTelefonos, regEmail, iCantTelefonos, iCantEmail);

	if(regCliente.tipo_fpago[0] == 'D'){
		if(sTipoDD[0]=='B'){
			/* BUT0BK */
			GeneraBUT0BK(fp, regCliente, regFpago);
		}
	}
	
	/* BUT020 */
	GeneraBUT020(fp, regCliente, regEmail, regCliente.numero_cliente, iEsCorpo);
/*   
	if(iEsCorpo==1){
		// Si es un corporativo propio agrego las direcciones postales de los hijos 
		//free(sDireccionPostal);
		//Incorporo la direccion del padre a la comparacion
		memset(sDirPostalAux, '\0', sizeof(sDirPostalAux));
		alltrim(regCliente.nom_calle, ' ');
		alltrim(regCliente.nro_dir, ' ');
		alltrim(regCliente.piso_dir, ' ');
		alltrim(regCliente.depto_dir, ' ');
		sprintf(sDirPostalAux, "$s %s %s %s", regCliente.nom_calle, regCliente.nro_dir, regCliente.piso_dir, regCliente.depto_dir);
		sDireccionPostal[indice]=sDirPostalAux;
		indice++;					
		
		$OPEN curPostalHijos using :regCliente.numero_cliente;
		while(LeoHijos(&regHijos, &regFpHijos)){
			memset(sDirPostalAux, '\0', sizeof(sDirPostalAux));
			alltrim(regHijos.nom_calle, ' ');
			alltrim(regHijos.nro_dir, ' ');
			alltrim(regHijos.piso_dir, ' ');
			alltrim(regHijos.depto_dir, ' ');
			sprintf(sDirPostalAux, "$s %s %s %s", regHijos.nom_calle, regHijos.nro_dir, regHijos.piso_dir, regHijos.depto_dir);
			// Me voy armando un array de direcciones para tratar de no repetir direcciones 

			i=0;s=0;
			while(i<indice && s==0){
				if(strcmp(sDireccionPostal[i], sDirPostalAux)==0){
					s=1;
				}					
				i++;
			}
         iCantMail=0;
         if (! CargaEmail(regHijos, &regEmailHijos, &iCantMail)){
         
         }
         
			if(s==0){
				sDireccionPostal[indice]=sDirPostalAux;
				indice++;					
				GeneraBUT020(fp, regHijos, regEmailHijos, regCliente.numero_cliente,0);
			}
			
			GeneraBUT020(fp, regHijos, regEmailHijos, regCliente.numero_cliente, 0);
		}
		$CLOSE curPostalHijos;
	}
*/   

	if(regCliente.tipo_fpago[0] == 'D'){
		if(sTipoDD[0]!='B'){
			/* BUT0CC */
			GeneraBUT0CC(fp, regCliente, regFpago);
		}
	}
	
	/* TAXNUM */
	GeneraTAXNUM(fp, regCliente);

	/* BUT0ID */
	if(strcmp(regCliente.tipo_cliente, "PR")==0 || strcmp(regCliente.tipo_cliente, "RP")==0){
		GeneraBUT0ID(fp, regCliente);
	}
	
	/* ENDE */
	GeneraENDE(fp, regCliente);
	
	return 1;
}


void GeneraINIT(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	
	int		iTipoPersona;
	char	sAux[5];
	int  iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	memset(sAux, '\0', sizeof(sAux));
	
	iTipoPersona=getTipoPersona(regCliente.tipo_cliente);
	
	if(strcmp(regCliente.tipo_cliente, "PR")==0 || strcmp(regCliente.tipo_cliente, "RP")==0){
		strcpy(sAux, "ZT1");		
	}else{
		strcpy(sAux, "ZT2");
	}
		
   /* LLAVE */
	sprintf(sLinea, "T1%ld\tINIT\t", regCliente.numero_cliente);
   
   /* PARTNER (valor que viene de SF)*/
   /*sprintf(sLinea, "%s%s\t", sLinea, regCliente.sAccount);*/
   sprintf(sLinea, "%s%ld\t", sLinea, regCliente.numero_cliente);
   
   /* MASTER_KUN */
   strcat(sLinea, "CALL\t");
   
	sprintf(sLinea, "%s%d\t", sLinea, iTipoPersona);
	
	sprintf(sLinea, "%sZEMG\t", sLinea);
	/*sprintf(sLinea, "%sZT1\t", sLinea);*/
	
	sprintf(sLinea, "%s%s\t", sLinea, sAux);

	sprintf(sLinea, "%s%ld\t", sLinea, regCliente.numero_cliente);
	sprintf(sLinea, "%sMKK",sLinea);
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir INIT\n");
      exit(1);
   }	
   
	
}

void GeneraBUT000(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	
	int		iTipoPersona;
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	alltrim(regCliente.nombre, ' ');
	alltrim(regCliente.actividad_economic, ' ');
	alltrim(regCliente.rut, ' ');
	
	iTipoPersona=getTipoPersona(regCliente.tipo_cliente);
	
	sprintf(sLinea, "T1%ld\tBUT000\t%s\t%s\t0004\t", regCliente.numero_cliente, regCliente.nombre, regCliente.rut);
   
	if(iTipoPersona==1){
		/* Es persona */
		strcat(sLinea, "0002\t");
	}else{
		/* Es Empresa */
		strcat(sLinea, "\t");
	}
	
	sprintf(sLinea, "%sT1\t", sLinea);
	
	if(iTipoPersona==2){
		sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);	
	}else{
		strcat(sLinea, "\t");
	}
	strcat(sLinea, "\t");
	
	if(iTipoPersona==2){
		strcat(sLinea, "01\t");	
	}else{
		strcat(sLinea, "\t");
	}
/*
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.actividad_economic);
*/
	strcat(sLinea, "\t");
	
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);	
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);	
	
	if(iTipoPersona==1){	
		sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);	
	}else{
		strcat(sLinea, "\t");
	}
	
	strcat(sLinea, "X\tS");
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir BUT000\n");
      exit(1);
   }	
   
}

void GeneraBUT0ID(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	alltrim(regCliente.tip_doc, ' ');

	sprintf(sLinea, "T1%ld\tBUT0ID\tI\t\t", regCliente.numero_cliente);
	sprintf(sLinea, "%s%.0f\t", sLinea, regCliente.nro_doc);
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.tip_doc);
	sprintf(sLinea, "%s\t\t", sLinea);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir BUT0ID\n");
      exit(1);
   }	
}

void GeneraBUTCOM(fp, regCliente, regTelefonos, regEmail, iCantTele, iCantMail)
FILE *fp;
$ClsCliente	regCliente;
$ClsTelefonos *regTelefonos;
$ClsEmail	regEmail;
int			iCantTele;
int			iCantMail;
{
	char	sLinea[10000];
	char	sAux[10];
	int		i=0;
	int		s=0;
	int     iRcv;
   
	alltrim(regCliente.telefono, ' ');

	if(iCantTele==0 && iCantMail==0 && strcmp(regCliente.telefono, "")==0)
		return;

	/* Primero los telefonos */
	for(i=0; i<iCantTele; i++){
		memset(sLinea, '\0', sizeof(sLinea));
		
		memset(sAux, '\0', sizeof(sAux));
		alltrim(regTelefonos[i].numero_te, ' ');		
		
		if(strcmp(regTelefonos[i].numero_te, regCliente.telefono)==0){
			/* Si el de CLIENTE existe en TELEFONO marco el flag para no copiarlo 2 veces */
			s=1;
		}

		sprintf(sLinea, "T1%ld\tBUTCOM\tI\t", regCliente.numero_cliente);

		sprintf(sLinea, "%s%s%s%s\t", sLinea, regTelefonos[i].cod_area_te, regTelefonos[i].prefijo_te, regTelefonos[i].numero_te);

		sprintf(sLinea, "%s\t\t\t", sLinea);

		strcat(sLinea, "\n");
	
   	iRcv=fprintf(fp, sLinea);
      if(iRcv < 0){
         printf("Error al escribir BUTCOM\n");
         exit(1);
      }	
      		
	}
	/* Inserto el de la tabla CLIENTE si es que no estaba en TELEFONO */	
	if(s==0 && strcmp(regCliente.telefono, "")!=0){
		memset(sLinea, '\0', sizeof(sLinea));
		
		sprintf(sLinea, "T1%ld\tBUTCOM\tI\t", regCliente.numero_cliente);

		sprintf(sLinea, "%s%s\t", sLinea, regCliente.telefono);

		sprintf(sLinea, "%s\t\t\t", sLinea);

		strcat(sLinea, "\n");
	
   	iRcv=fprintf(fp, sLinea);
      if(iRcv < 0){
         printf("Error al escribir BUTCOM\n");
         exit(1);
      }	
		
	}
	
	
	/* Despues los eMail */
	if(iCantMail>0){
		alltrim(regEmail.email1, ' ');
		alltrim(regEmail.email2, ' ');
		alltrim(regEmail.email3, ' ');
		
		if(strcmp(regEmail.email1,"")!=0){
			memset(sLinea, '\0', sizeof(sLinea));
		
			sprintf(sLinea, "T1%ld\tBUTCOM\t\t\t\t\tI\t%s\n", regCliente.numero_cliente, regEmail.email1);
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir BUTCOM\n");
            exit(1);
         }	
	
		}
		if(strcmp(regEmail.email2,"")!=0){
			memset(sLinea, '\0', sizeof(sLinea));
		
			sprintf(sLinea, "T1%ld\tBUTCOM\t\t\t\t\tI\t%s\n", regCliente.numero_cliente, regEmail.email2);
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir BUTCOM\n");
            exit(1);
         }	
	
		}
		if(strcmp(regEmail.email3,"")!=0){
			memset(sLinea, '\0', sizeof(sLinea));
		
			sprintf(sLinea, "T1%ld\tBUTCOM\t\t\t\t\tI\t%s\n", regCliente.numero_cliente, regEmail.email3);
      	iRcv=fprintf(fp, sLinea);
         if(iRcv < 0){
            printf("Error al escribir BUTCOM\n");
            exit(1);
         }	
	
		}				
	}
}

void GeneraBUT020(fp, regCliente, regMail, lNroCliente, iEsCorpo)
FILE *fp;
$ClsCliente	regCliente;
$ClsEmail   regMail;
long	lNroCliente;
int		iEsCorpo;
{
	char	sLinea[10000];	
	char	sAux[300];
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	memset(sAux, '\0', sizeof(sAux));
	
	alltrim(regCliente.cod_calle, ' ');
	alltrim(regCliente.nom_partido, ' ');
	alltrim(regCliente.nom_calle, ' ');
	alltrim(regCliente.nro_dir, ' ');
	alltrim(regCliente.nom_entre, ' ');
	alltrim(regCliente.nom_entre1, ' ');
	alltrim(regCliente.piso_dir, ' ');
	alltrim(regCliente.depto_dir, ' ');
	alltrim(regCliente.provincia, ' ');
	alltrim(regCliente.obs_dir, ' ');
	alltrim(regCliente.nom_comuna, ' ');

	if(strcmp(regCliente.provincia, "")!=0){
		if(strcmp(regCliente.provincia, "00")==0){
			if(regCliente.cod_postal > 1499 || regCliente.cod_postal < 1000 || risnull(CINTTYPE, (char *) &regCliente.cod_postal)){
				regCliente.cod_postal = 1076;
			}
		}else{
			if(regCliente.cod_postal <= 1499 || risnull(CINTTYPE, (char *) &regCliente.cod_postal)){
				regCliente.cod_postal = 1876;
			}
		}
	}


	
   /* LLAVE */
	sprintf(sLinea, "T1%ld\tBUT020\t",lNroCliente);
   
   /* ADEXT_ADDR */
   sprintf(sLinea, "%s%s\t", sLinea, regCliente.cod_calle);
   
   /* CHIND_ADDR*/
   strcat(sLinea, "I\t");
  
   /* XDFADR */
	strcat(sLinea, "\t");
   
	/* NAME_CO */
	memset(sAux, '\0', sizeof(sAux));
   
   if(strcmp(regCliente.piso_dir, "")!=0){
      sprintf(sAux, "Piso: %s", regCliente.piso_dir);
   }
   if(strcmp(regCliente.depto_dir, "")!=0){
      sprintf(sAux, "%s Depto. %s ", sAux, regCliente.depto_dir);
   }
   alltrim(sAux, ' ');
   
/*	
   if(strcmp(regCliente.tipo_reparto, "POSTAL")==0){
		sprintf(sAux, "POS_%ld", regCliente.numero_cliente);
	}else{
		sprintf(sAux, "SUM_%ld", regCliente.numero_cliente);
	}
*/   
	sprintf(sLinea, "%s%s\t", sLinea, sAux);
		
   /* CITY */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_partido);
   /* POST_CODE1 */
   if(regCliente.cod_postal!=0){
	  sprintf(sLinea, "%s%d\t", sLinea, regCliente.cod_postal);
   }else{
     strcat(sLinea, "\t");   
   }
   /* STREET */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_calle);
   /* HOUSE_NUM1 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nro_dir);
   /* STR_SUPPL1 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_entre);
   /* STR_SUPPL2 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_entre1);
   /* BUILDING */
	sprintf(sLinea, "%s\t", sLinea);
   /* FLOOR */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.piso_dir);
   /* ROOMNUMBER */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.depto_dir);
   /* COUNTRY */
	sprintf(sLinea, "%sAR\t", sLinea);
   /* LANGU */
   strcat(sLinea, "S\t");
   /* REGION */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.provincia);

   /* SORT 1 */
	sprintf(sAux, "%s %s", regCliente.nom_calle, regCliente.nro_dir);
	sprintf(sLinea, "%s%s\t", sLinea, sAux);
   /* SORT 2 */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nom_comuna);
   /* TIME ZONE */
	sprintf(sLinea, "%sUTC-3\t", sLinea);
   /* REMARK */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.obs_dir);
	
   /* GUID */
	memset(sAux, '\0', sizeof(sAux));
	if(strcmp(regCliente.tipo_reparto, "POSTAL")==0){
		sprintf(sAux, "POS_%ld", regCliente.numero_cliente);
	}else{
		sprintf(sAux, "SUM_%ld", regCliente.numero_cliente);
	}
	sprintf(sLinea, "%s%s\t", sLinea, sAux);
   
   /* SMTP_ADDR */
   if(strcmp(regMail.email1,"")!=0){
      sprintf(sLinea, "%s%s", sLinea, regMail.email1);
   }

	strcat(sLinea, "\n");
	

	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir BUT020\n");
      exit(1);
   }	
   	
}

void GeneraBUT0BK(fp, regCliente, regFpago)
FILE *fp;
$ClsCliente	regCliente;
$ClsFormaPago	regFpago;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	alltrim(regFpago.fp_nrocuenta, ' ');
	alltrim(regCliente.nombre, ' ');
	alltrim(regFpago.fp_cbu, ' ');
	
   /* Llave + BKVID + CHIND BANKS + BANKS */
	sprintf(sLinea, "T1%ld\tBUT0BK\t0001\tI\tAR\t", regCliente.numero_cliente);
   /* BANKL */
	sprintf(sLinea, "%s%s\t", sLinea, regFpago.fp_banco);
   /* BANKN */
	sprintf(sLinea, "%s%s\t", sLinea, regFpago.fp_nrocuenta);
   /* BKONT */
	sprintf(sLinea, "%s\t", sLinea);
   /* KOINH */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);
   
	/*sprintf(sLinea, "%s\t", sLinea);*/
   /* ACCNAME */
	sprintf(sLinea, "%s%s", sLinea, regFpago.fp_cbu);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir BUT0BK\n");
      exit(1);
   }	
   	
}

void GeneraBUT0CC(fp, regCliente, regFpago)
FILE *fp;
$ClsCliente	regCliente;
$ClsFormaPago	regFpago;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	alltrim(regFpago.fp_nrocuenta, ' ');
	alltrim(regCliente.nombre, ' ');
	
	strcpy(regFpago.cod_tarjeta, getCodTarjeta(regFpago.fp_banco));
	alltrim(regFpago.cod_tarjeta, ' ');
	
/*
	sprintf(sLinea, "T1%ld\tBUT0CC\t%s\t", regCliente.numero_cliente, regFpago.fp_banco);
*/
   /* LLAVE + CCARD_ID */
	sprintf(sLinea, "T1%ld\tBUT0CC\t000001\t", regCliente.numero_cliente);
	/* CHIND_CCARD */
	sprintf(sLinea, "%sI\t", sLinea);
   /* CCINS */
	sprintf(sLinea, "%s%s\t", sLinea, regFpago.cod_tarjeta);
   /* CCNUM */
	sprintf(sLinea, "%s%s\t", sLinea, regFpago.fp_nrocuenta);
   /* CCDEF */
	sprintf(sLinea, "%sX\t", sLinea);
   /* CCNAME */
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.nombre);
   /* DATAB + DATBI + AUSGDAT + ISSBANK + CCTYP + CCLOCK */
	sprintf(sLinea, "%s\t\t\t\t01\t", sLinea);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir BUT0CC\n");
      exit(1);
   }	
   	
}

void GeneraTAXNUM(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];
	char	sAux[4];
	int  iRcv;
   
	memset(sAux, '\0', sizeof(sAux));	

	alltrim(regCliente.rut, ' ');
	if(strcmp(regCliente.rut, "")==0){
		return;	
	}

	if(strcmp(regCliente.tipo_cliente, "PR")==0 || strcmp(regCliente.tipo_cliente, "RP")==0){
		strcpy(sAux, "AR1B");		
	}else{
		strcpy(sAux, "AR1A");
	}
	
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\tTAXNUM\t%s\tI\t", regCliente.numero_cliente, sAux);
	sprintf(sLinea, "%s%s\t", sLinea, regCliente.rut);
	sprintf(sLinea, "%sX", sLinea);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir TAXNUM\n");
      exit(1);
   }	

}

void GeneraENDE(fp, regCliente)
FILE *fp;
$ClsCliente	regCliente;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", regCliente.numero_cliente);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
	
}

int getTipoPersona(sTipoCliente)
char	sTipoCliente[3];
{
	int iTipo=0;
	
	if(strcmp(sTipoCliente, "PR")==0 || strcmp(sTipoCliente, "RP")==0){
		iTipo=1;	
	}else{
		iTipo=2;
	}	
	
	return iTipo;
}

char *getTipoDD(sIdEntidad, iSalida)
$char	sIdEntidad[7];
int		*iSalida;
{
	$char	sTipo[2];
	
	memset(sTipo, '\0', sizeof(sTipo));
	
	$EXECUTE selTipoDebito into :sTipo using :sIdEntidad;
	
	if(SQLCODE != 0){
		*iSalida = 1;		
	}
	
	return sTipo;
}


short ClienteYaMigrado(nroCliente, iTipo, iFlagMigra)
$long	nroCliente;
int	    iTipo;
int		*iFlagMigra;
{
	$char	sMarca[2];
	$int	iCant=0;
	
	if(gsTipoGenera[0]=='R' && iTipo==1 ){
		return 0;	
	}else if(gsTipoGenera[0]=='R' && iTipo==2 ){
		$EXECUTE selCorpoT1migrado into :iCant using :nroCliente;
			
		if(SQLCODE != 0){
			if(SQLCODE==SQLNOTFOUND){
				return 0;
			}else{
				printf("Error al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
				exit(1);
			}
		}
		
		if(iCant<=0){
			return 0;	
		}else{
			return 1;
		}
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

short RegistraCorpoT1(nroCliente)
$long	nroCliente;
{

	$EXECUTE insCorpoT1migrado using :nroCliente;

	return 1;
}

short BorraCorpoT1(void){
	
	$EXECUTE delCorpoT1migrado;
		
	return 1;	
}

short CorporativoT23(nroCliente)
$long	nroCliente;
{
	$int	iCant=0;
	
   return 0; /* 06/07/2018 */
   
	$EXECUTE selCorpoT23 into :iCant using :nroCliente;

	if(SQLCODE != 0){
		printf("ErroR al verificar si el cliente %ld es corporativo T23.\n", nroCliente);
		exit(1);
	}

	if(iCant>0)
		return 1;		
		
	return 0;
}

short LeoCorpoPropio(regCli, regFP)
$ClsCliente *regCli;
$ClsFormaPago *regFP;
{
$long	lNroCliente;

	lNroCliente=regCli->minist_repart;	

	InicializaCliente(regCli, regFP);

	$EXECUTE selCorpoPropio into :regCli->numero_cliente,
		:regCli->nombre,
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
		:regFP->fp_cbu
	using :lNroCliente;

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cliente Corporativo Propio %ld\nProceso Abortado.\n", lNroCliente);
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
		
	alltrim(regCli->nombre, ' ');
	alltrim(regCli->obs_dir, ' ');

	strcpy(regCli->nombre, strReplace(regCli->nombre, "'", " "));
	strcpy(regCli->nombre, strReplace(regCli->nombre, "#", "Ñ"));
	
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "'", " "));
	strcpy(regCli->nom_calle, strReplace(regCli->nom_calle, "#", "Ñ"));
	
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "'", " "));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "#", "Ñ"));
	strcpy(regCli->nom_entre, strReplace(regCli->nom_entre, "*", " "));
	
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "'", " "));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "#", "Ñ"));
	strcpy(regCli->nom_entre1, strReplace(regCli->nom_entre1, "*", " "));
	
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "'", " "));
	strcpy(regCli->nom_partido, strReplace(regCli->nom_partido, "#", "Ñ"));

	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "'", " "));
	strcpy(regCli->nom_comuna, strReplace(regCli->nom_comuna, "#", "Ñ"));
		
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "'", " "));
	strcpy(regCli->obs_dir, strReplace(regCli->obs_dir, "#", "Ñ"));
	
	return 1;	
}
/*
short RegistraArchivo(nomArchivo, iCant)
$char	nomArchivo[100];
$long	iCant;
{
	$int iEstado=giEstadoCliente;
	$char	sSucursal[5];
	$int	iPlan=giPlan;
	$long	lNroCliente=glNroCliente;
	
	strcpy(sSucursal, gsSucursal);
	
	$EXECUTE updGenArchivos;
	
	$EXECUTE insGenPartner using
			:gsTipoGenera,
			:iCant,
			:lNroCliente,
			:nomArchivo;
	
	return 1;
}
*/
char *getCodTarjeta(sCodMac)
$char	sCodMac[5];
{
	$char	sCodSap[5];
	
	memset(sCodSap, '\0', sizeof(sCodSap));
	
	$EXECUTE selCodTarjeta into :sCodSap using :sCodMac;
		
	if(SQLCODE != 0){
		printf("Error al recuperar cod sap para tarjeta credito %s\n", sCodMac);
		strcpy(sCodSap, "XXXX");
	}
	
	return sCodSap;
	
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

short CargaTelefonos(regCliente, regTelefonos, iCant)
$ClsCliente regCliente;
$ClsTelefonos **regTelefonos;
int	*iCant;
{
$ClsTelefonos	*regAux=NULL;
$ClsTelefonos	reg;
int indice=0;

	*iCant = indice;
	
	if(*regTelefonos != NULL)
		free(*regTelefonos);
		
	*regTelefonos = (ClsTelefonos *) malloc (sizeof(ClsTelefonos));
	if(*regTelefonos == NULL){
		printf("Fallo Malloc CargaTelefonos().\n");
		return 0;
	}
	
	$OPEN curTelefonos using :regCliente.numero_cliente, :regCliente.numero_cliente;
		
	while(LeoTelefonos(&reg)){
		
		regAux = (ClsTelefonos*) realloc(*regTelefonos, sizeof(ClsTelefonos) * (++indice) );
		if(regAux == NULL){
			printf("Fallo Realloc CargaTelefonos().\n");
			return 0;
		}		
		
		(*regTelefonos) = regAux;
		
		strcpy((*regTelefonos)[indice-1].tipo_te, reg.tipo_te);
		strcpy((*regTelefonos)[indice-1].cod_area_te, reg.cod_area_te);
		strcpy((*regTelefonos)[indice-1].prefijo_te, reg.prefijo_te);
		strcpy((*regTelefonos)[indice-1].numero_te, reg.numero_te);
		strcpy((*regTelefonos)[indice-1].ppal_te, reg.ppal_te);
	}	

	*iCant = indice;
	
	return 1;
}

short LeoTelefonos(reg)
$ClsTelefonos *reg;
{
	InicializaTelefonos(reg);
	
	$FETCH curTelefonos  into
		:reg->tipo_te,
		:reg->cod_area_te,
		:reg->prefijo_te,
		:reg->numero_te,
		:reg->ppal_te;
			
	if(SQLCODE==SQLNOTFOUND){
		return 0;
	}
	
	return 1;					
}

/*
short CargaIdSF(reg)
$ClsCliente *reg;
{

   $EXECUTE selAccount INTO :reg->sAccount USING :reg->numero_cliente;
   
   if(SQLCODE != 0){
      printf("Error al buscar ACCOUNT para cliente %ld\n", reg->numero_cliente);
      return 0;
   }

   alltrim(reg->sAccount, ' ');

   return 1;
}
*/

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


