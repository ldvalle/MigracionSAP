/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_barra_factu
    
	Fecha : 27/07/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
      Graba datos de la facturación en curso incluyendo el Codigo de Barras
      para luego poder ser exportada a SAP.
      		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Sucursal> : XXXX
		<Plan>     : ##
      <Fecha generacion>: dd/mm/aaaa
********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_barra_factu.h";

/* Variables Globales */
char  gsFechaGeneracion[11];

/* Variables Globales Host */
$char gsSucursal[5];
$int  giPlan;
$long glFechaGeneracion;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
long	lCantFacturas;
$long lIdAgenda;
$ClsFactu regFactu;
$char sBarra[47];

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
	lCantFacturas=0;
   rdefmtdate(&glFechaGeneracion, "dd/mm/yyyy", gsFechaGeneracion);

   $EXECUTE selIdAgenda INTO :lIdAgenda USING
      :gsSucursal,
      :giPlan,
      :glFechaGeneracion;
      
   if(SQLCODE != 0){
      printf("La agenda no existe para los parámetros indicados o no está en estado 9.\nProceso Abortado.");
      exit(1);
   }      
    
	$OPEN curFacturas USING :lIdAgenda;
	
	while(LeoFacturas(&regFactu)){
      memset(sBarra, '\0', sizeof(sBarra));
      strcpy(sBarra, getBarra(regFactu));
      
      $BEGIN WORK;
      
      if(!setBarra(regFactu, sBarra)){
         printf("Fallo insert de barra para cliente %ld Correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
         exit(1);
      }
      
      $COMMIT WORK;
      
      lCantFacturas++;
	}
   

	$CLOSE curFacturas;

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SAP_BARRA_FACTU.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Facturas Procesadas :       %ld \n",lCantFacturas);
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

	if(argc != 5){
		MensajeParametros();
		return 0;
	}
	
   strcpy(gsSucursal, argv[2]);
   giPlan = atoi(argv[3]);
   strcpy(gsFechaGeneracion, argv[4]);
  
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
      printf("	<Sucursal> XXXX \n");
      printf("	<Plan>  ## \n");
      printf("	<Fecha Generacion> dd/mm/aaaa \n");
}


void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	
	
   /******** Identif Agenda  ****************/
   $PREPARE selIdAgenda FROM "SELECT identif_agenda FROM agenda
      WHERE sucursal = ?
      AND sector = ?
      AND fecha_generacion = ?
      AND estado = 9 "; 
   
	/******** Facturas  *********/
   $PREPARE selFacturas FROM "SELECT numero_cliente, 
      corr_facturacion,
      numero_factura,
      sucursal,
      sector,
      zona,
      fecha_facturacion,
      TO_CHAR(fecha_vencimiento1, '%y%m%d'),
      TO_CHAR(fecha_vencimiento2, '%m%d'),
      total_a_pagar,
      centro_emisor,
      tipo_docto
      FROM hisfac_cont
      WHERE identif_agenda = ? ";
	
	$DECLARE curFacturas CURSOR WITH HOLD FOR selFacturas;
		
   /************** Recargos *************/
   $PREPARE selRecargo FROM "SELECT NVL(SUM(valor_cargo), 0) FROM recargo
      WHERE numero_cliente = ?
      AND corr_fact = ? ";

   /************** grabar barra *************/   
   $PREPARE setBarra from "INSERT INTO sap_barra_factu (
      numero_cliente,
      corr_facturacion,
      fecha_facturacion,
      barra
      )VALUES(
      ?, ?, ?, ?)";
   
   
}


short LeoFacturas(reg)
$ClsFactu *reg;
{
	InicializaFacturas(reg);

	$FETCH curFacturas INTO
      :reg->numero_cliente, 
      :reg->corr_facturacion,
      :reg->numero_factura,
      :reg->sucursal,
      :reg->sector,
      :reg->zona,
      :reg->fecha_facturacion,
      :reg->fecha_vencimiento1,
      :reg->fecha_vencimiento2,
      :reg->total_a_pagar,
      :reg->saldo_anterior,
      :reg->centro_emisor,
      :reg->tipo_docto;
   
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de HISFAC_CONT !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

    /* Cargo el Tipo de Documento */
    if(reg->saldo_anterior <= 0.01){
      strcpy(reg->tipo_nota, "06");
    }else{
      strcpy(reg->tipo_nota, "96");
    }
    
    /* Cargo los recargos */
    
    $EXECUTE selRecargo INTO :reg->recargo
         USING :reg->numero_cliente,
               :reg->corr_facturacion;
               
   if(SQLCODE != 0 ){
      printf("Error al buscar Recargos para cliente %ld Correlativo %ld\n", reg->numero_cliente, reg->corr_facturacion);
      exit(1);
   }               
    
	return 1;	
}


void InicializaFacturas(reg)
$ClsFactu	*reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->numero_factura));
   memset(reg->sucursal, '\0', sizeof(reg->sucursal));
   rsetnull(CINTTYPE, (char *) &(reg->sector));
   rsetnull(CINTTYPE, (char *) &(reg->zona));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_facturacion));
   memset(reg->fecha_vencimiento1, '\0', sizeof(reg->fecha_vencimiento1));
   memset(reg->fecha_vencimiento2, '\0', sizeof(reg->fecha_vencimiento2));
   rsetnull(CDOUBLETYPE, (char *) &(reg->total_a_pagar));   
   rsetnull(CDOUBLETYPE, (char *) &(reg->saldo_anterior));
   memset(reg->centro_emisor, '\0', sizeof(reg->centro_emisor));
   memset(reg->tipo_docto, '\0', sizeof(reg->tipo_docto));      
   memset(reg->tipo_nota, '\0', sizeof(reg->tipo_nota));
   rsetnull(CDOUBLETYPE, (char *) &(reg->recargo));
   
}

char *getBarra(reg)
ClsFactu reg;
{
   char	sLinea[47];
   char  sTotalAPagar[11];
   char  sTotalEnteros[8];
   char  sTotalDecimales[3];
   char  sRecargo[8];
   char  sRecargoEnteros[5];
   char  sRecargoDecimales[3];
   int	dv_codbar=0;
   
   memset(sLinea, '\0', sizeof(sLinea));
   memset(sTotalAPagar, '\0', sizeof(sTotalAPagar));
   memset(sTotalEnteros, '\0', sizeof(sTotalEnteros));
   memset(sTotalDecimales, '\0', sizeof(sTotalDecimales));
   memset(sRecargo, '\0', sizeof(sRecargo));
   memset(sRecargoEnteros, '\0', sizeof(sRecargoEnteros));
   memset(sRecargoDecimales, '\0', sizeof(sRecargoDecimales));
      
   sprintf(sTotalAPagar, "%9.2f", reg.total_a_pagar);
   substr(sTotalEnteros, sTotalAPagar, 0, 6);
   substr(sTotalDecimales, sTotalAPagar, 7, 2);

   sprintf(sRecargo, "%6.2f", reg.recargo);
   substr(sRecargoEnteros, sRecargo, 0, 3);
   substr(sRecargoDecimales, sRecargo, 4, 2);
   
   /* EMPRESA */
   strcpy(sLinea, "009");

   /* SUCURSAL */
   sprintf(sLinea, "%s%c%c", sLinea, reg.sucursal[2], reg.sucursal[3]);
   
   /* SECTOR */
   sprintf(sLinea, "%s%02d", sLinea, reg.sector);
   
   /* NRO.CLIENTE */
   sprintf(sLinea, "%s%08ld", sLinea, reg.numero_cliente);
   
   /* TOTAL A PAGAR */
   sprintf(sLinea, "%s%07ld%02d", sLinea, atol(sTotalEnteros), atoi(sTotalDecimales));
   
   /* FECHA VTO.1 */
   sprintf(sLinea, "%s%s", sLinea, reg.fecha_vencimiento1);
   
   /* RECARGO */
   sprintf(sLinea, "%s%04d%02d", sLinea, atoi(sRecargoEnteros), atoi(sRecargoDecimales));

   /* FECHA VTO.2 */
   sprintf(sLinea, "%s%s", sLinea, reg.fecha_vencimiento2);
   
   /* CORR FACTURACION */
   sprintf(sLinea, "%s%03d", sLinea, reg.corr_facturacion);
   
   /* TIPO DOCUMENTO */
   sprintf(sLinea, "%s%s", sLinea, reg.tipo_nota);
   
   
   /* DIGITO VERIF */
   dv_codbar=ObtenerDigitoVerificador(sLinea);
   sprintf(sLinea, "%s%d", sLinea, dv_codbar);

   return sLinea;
}

short setBarra(reg, sBarra)
$ClsFactu reg;
$char	sBarra[47];       
{

   $EXECUTE setBarra USING
      :reg.numero_cliente,
      :reg.corr_facturacion,  
      :reg.fecha_facturacion,
      :sBarra; 

   if(SQLCODE != 0){
      printf("No se grabó barra para Cliente %ld Corr.Factu. %ld\n", reg.numero_cliente, reg.corr_facturacion);
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

