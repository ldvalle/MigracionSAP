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

$include "sap_doc_fica.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];

FILE	*pFileUnx;

char	sArchSalidaUnx[100];
char	sSoloArchSalida[100];

char	sPathSalida[100];
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
   		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */

	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(sSucursal, '\0', sizeof(sSucursal));
   

	for(i=0; i<12; i++){
		strcpy(sSucursal, vSucursal[i]);

		if(!AbreArchivos(sSucursal)){
			exit(1);	
		}
		
		if(glNroCliente > 0){
			$OPEN curClientes using :glNroCliente, :sSucursal;
		}else{
			$OPEN curClientes using :sSucursal;
		}
		
		printf("Procesando Sucursal %s......\n", sSucursal);
      
      while(LeoCliente(&regCliente)){
         
         if(!ClienteYaMigrado(regCliente.numero_cliente, &iFlagMigra)){
            
            GenerarPlanos(regCliente);
                           
            $BEGIN WORK;
            
            if(!RegistraCliente(regCliente.numero_cliente,iFlagMigra)){
              $ROLLBACK WORK;
              exit(2);
            }
            $COMMIT WORK;
            
            cantProcesada++;
         }else{
            cantPreexistente++;
         }         
         
      } /* Clientes */
   
      $CLOSE curClientes;

      CerrarArchivos();
      
   }  /* Sucursales */ 


	
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

	if(argc < 4 || argc > 5){
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
	
	if(argc==5){
		glNroCliente=atoi(argv[4]);
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
		printf("	<Nro.Cliente>(Opcional)\n");
}

short AbreArchivos(sSucur)
char  sSucur[5];
{
	
	memset(sArchSalidaUnx,'\0',sizeof(sArchSalidaUnx));
	memset(sSoloArchSalida,'\0',sizeof(sSoloArchSalida));

   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	RutaArchivos( sPathSalida, "SAPISU" );
/*	
	lCorrelativo = getCorrelativo("FICA");
*/	
	alltrim(sPathSalida,' ');

	sprintf( sArchSalidaUnx  , "%sT1FICA_%s.unx", sPathSalida, sSucur );
	sprintf( sSoloArchSalida, "T1FICA_%s.unx", sSucur);

	pFileUnx=fopen( sArchSalidaUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchSalidaUnx );
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
		strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");
	}else{
		strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");
	}
	

	sprintf(sCommand, "chmod 755 %s", sArchSalidaUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchSalidaUnx, sPathCp);
	iRcv=system(sCommand);		

   sprintf(sCommand, "rm %s", sArchSalidaUnx);
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
   strcat(sql, "TRIM(t3.cod_sap) ");         /* sucursal SAP */
   strcat(sql, "FROM cliente c, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER sap_transforma t3 ");
	
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
	strcat(sql, "AND c.sucursal = ? ");
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

strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

	
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
	
	$PREPARE insGenInstal FROM $sql;

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT fica FROM sap_regi_cliente ");
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
      :regCli->sucur_sap;
      
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

void GenerarPlanos(regClie)
ClsCliente     regClie;
{
   int i=1;
   double dMonto;
   
   GenerarKO(regClie);

   /* Operacion Plana Cliente */
      dMonto = (regClie.saldo_int_acum + regClie.saldo_imp_no_suj_i + regClie.saldo_imp_suj_int) * -1;
      
      /* intereses acum */   
      GenerarOP(regClie, 1, "0995");
      /* saldo sujeto a intereses */
      GenerarOP(regClie, 2, "0996");
      /* saldo NO sujeto a intereses */
      GenerarOP(regClie, 3, "0997");
      /* Impuestos sujeto a intereses */
      GenerarOP(regClie, 4, "0998");
      /* Impuestos No sujeto a intereses */
      GenerarOP(regClie, 5, "0999");

      GenerarOPK(regClie, 1, dMonto);
            
   GenerarOPL(regClie);
   
   GeneraENDE(regClie);

}

void GenerarKO(regClie)
ClsCliente  regClie;
{
   char  sLinea[1000];
   
   memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
   sprintf(sLinea, "T1%ldKO\t", regClie.numero_cliente);   

   /* FIKEY */
   strcat(sLinea, "MGSDOT1\t");
   
   /* APPLK */
   strcat(sLinea, "R\t");
   
   /* BLART */
   strcat(sLinea, "MGSDOT1\t");
   
   /* HERKF */
   strcat(sLinea, "R1\t");
   
   /* WAERS */
   strcat(sLinea, "ARS\t");
   
   /* BLDAT */
   sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);
   
   /* BUDAT */
   sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);
   
   /* XBLNR */
   sprintf(sLinea, "%s%ld", sLinea, regClie.numero_cliente);

   strcat(sLinea, "\n");
  
   fprintf(pFileUnx, sLinea);

}


void GenerarOP(regClie, inx, codConcepto)
ClsCliente  regClie;
int         inx;
char        codConcepto[5];
{
   char  sLinea[1000];
   long  lConcepto;
   char  sTexto[100];
   double   dMonto;
   
   lConcepto=atol(codConcepto);
   memset(sLinea, '\0', sizeof(sLinea));

   switch(lConcepto){
      case 995:
         strcpy(sTexto, "Intereses Acumulados");
         dMonto = regClie.saldo_int_acum;
         break;
      case 996:
         strcpy(sTexto, "Saldo Sujeto a Intereses");
         dMonto = 0;
         break;
      case 997:
         strcpy(sTexto, "Saldo No Sujeto a Intereses");
         dMonto = regClie.saldo_actual;
         break;
      case 998:
         strcpy(sTexto, "Saldo Impuestos Sujeto a Intereses");
         dMonto = regClie.saldo_imp_suj_int;
         break;
      case 999:
         strcpy(sTexto, "Saldo Impuestos No Sujeto a Intereses");
         dMonto = regClie.saldo_imp_no_suj_i;
         break;
   }

   /* LLAVE */
   sprintf(sLinea, "T1%ldOP\t", regClie.numero_cliente);   

   /* OPUPK */
   sprintf(sLinea, "%s%04d\t", sLinea, inx);
   
   /* BUKRS */
   strcat(sLinea, "EDES\t");
   
   /* GSBER */
   sprintf(sLinea, "%s%s\t", sLinea, regClie.sucur_sap);
   
   /* GPART */
   sprintf(sLinea, "%sT1%ld\t", sLinea, regClie.numero_cliente);
   
   /* VTREF (vacio) */
   strcat(sLinea, "\t");
   
   /* VKONT */
   sprintf(sLinea, "%sT1%ld\t", sLinea, regClie.numero_cliente);
   
   /* HVORG */
   strcat(sLinea, "9996\t");
   
   /* TVORG */
   sprintf(sLinea, "%s%s\t", sLinea, codConcepto);
   
   /* KOFIZ */
   sprintf(sLinea, "%s%s\t", sLinea, regClie.cdc);
   
   /* SPART (vacio) */
   strcat(sLinea, "\t");
   
   /* HKONT (a definir) */
   strcat(sLinea, "\t");
   
   /* MWSKZ  (vacio) */
   strcat(sLinea, "\t");
   /* XANZA (vacio) */
   strcat(sLinea, "\t");
   /* STAKZ (vacio) */
   strcat(sLinea, "\t");
   
   /* BUDAT */
   sprintf(sLinea, "%s%s\t", sLinea, FechaGeneracion);
   
   /* OPTXT */
   sprintf(sLinea, "%s%s\t", sLinea, sTexto);
   
   /* FAEDN (?) */
   strcat(sLinea, "\t");
   
   /* BETRW */
   sprintf(sLinea, "%s%.02f\t", sLinea, dMonto);
   
   /* SBETW (vacio) */
   strcat(sLinea, "\t");
   
   /* AUGRS (vacio) */
   strcat(sLinea, "\t");
      
   /* SPERZ (?) */
   strcat(sLinea, "\t");
   
   /* BLART */
   strcat(sLinea, "MG\t");
   
   /* FINRE (vacio) */
   strcat(sLinea, "\t");
   
   /* PSWBT */
   sprintf(sLinea, "%s%.02f\t", sLinea, dMonto);
   
   /* SEGMENT (vacio) */

   strcat(sLinea, "\n");
  
   fprintf(pFileUnx, sLinea);

}

void GenerarOPK(regClie, inx, dMonto)
ClsCliente  regClie;
int         inx;
double      dMonto;
{
   char  sLinea[1000];
   
   memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
   sprintf(sLinea, "T1%ldOPK\t", regClie.numero_cliente);   

   /* OPUPK */
   sprintf(sLinea, "%s%04d\t", sLinea, inx);
   
   /* BUKRS */
   strcat(sLinea, "EDES\t");
   
   /* HKONT (?) */
   strcat(sLinea, "\t");
   
   /* PRCTR (vacio) */
   strcat(sLinea, "\t");
   
   /* KOSTL (vacio) */
   strcat(sLinea, "\t");
   
   /* BETRW */
   sprintf(sLinea, "%s%.02f\t", sLinea, dMonto);
   
   /* MWSKZ */
   sprintf(sLinea, "%s%s\t", sLinea, regClie.tipo_iva);
      
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
  
   fprintf(pFileUnx, sLinea);

}

void GenerarOPL(regClie)
ClsCliente regClie;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
   sprintf(sLinea, "T1%ldOPL\t", regClie.numero_cliente);   

   /* OPUPK (vacio) */
   strcat(sLinea, "\t");
   /* PROID (vacio) */
   strcat(sLinea, "\t");
   /* LOCKR (vacio) */
   strcat(sLinea, "\t");
   /* FDATE (vacio) */
   strcat(sLinea, "\t");
   /* TDATE (vacio) */

   strcat(sLinea, "\n");
  
   fprintf(pFileUnx, sLinea);

}

void GeneraENDE(regCli)
ClsCliente  regCli;
{
	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
   sprintf(sLinea, "T1%ld&ENDE", regCli.numero_cliente);
   
	strcat(sLinea, "\n");
	
	fprintf(pFileUnx, sLinea);	
}

short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "FICA");
		strcpy(sNombreArchivo, sSoloArchSalida);
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

