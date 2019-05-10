/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_disc_doc
    
	Fecha : 23/05/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura DISC_DOC
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>

*******************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_disc_doc.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
$long glFechaParametro;

FILE	*pFileUnx;
char	sArchUnx[100];
char	sSoloArchivo[100];

char	sPathSalida[100];
char	sPathCopia[100];

long	cantProcesada;

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
$ClsCorte   regCorte;
$long			lFechaPivote;
$char       sFechaCorte[17];

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;

	CreaPrepare();

   memset(sFechaCorte, '\0', sizeof(sFechaCorte));
   
	$EXECUTE selFechaPivote into :lFechaPivote;
   
   if(giTipoCorrida==3 && glFechaParametro > 0)
      lFechaPivote=glFechaParametro;
		
	rfmtdate(lFechaPivote, "yyyy-mm-dd 00:00", sFechaCorte);
   	
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;

	$OPEN curCortes using :sFechaCorte;
		
	while(LeoCortes(&regCorte)){
      GenerarPlano(pFileUnx, regCorte);
      cantProcesada++;
   }

	$CLOSE curCortes;
			
	CerrarArchivos();

	FormateaArchivos();

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
	printf("DISC_DOC.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Cortes Procesados :       %ld \n",cantProcesada);
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

	if(argc < 3 || argc > 4){
		MensajeParametros();
		return 0;
	}
	
   giTipoCorrida = atoi(argv[3]);
   
   if(giTipoCorrida==3 && argc==4 ){
      strcpy(sFechaPar, argv[5]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
   }else{
      glFechaParametro=-1;
   }
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("\t<Base> = synergia.\n");
      printf("\t<Tipo Corrida> 0=gral. 1=reducida. 3=Delta\n");
      printf("\t<Fecha Desde> dd/mm/aaaa (opcional)\n");
}

short AbreArchivos()
{
	
	memset(sArchUnx,'\0',sizeof(sArchUnx));
	memset(sSoloArchivo,'\0',sizeof(sSoloArchivo));
	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');

	sprintf( sArchUnx  , "%sT1DISC_DOC.unx", sPathSalida );
	strcpy( sSoloArchivo, "T1DISC_DOC.unx");
	
	pFileUnx=fopen( sArchUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchUnx );
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
	    /*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
       sprintf(sPathCp, "%sActivos/", sPathCopia);
	}else{
	    /*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
       sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv == 0){
   	sprintf(sCommand, "rm -f %s", sArchUnx);
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
	
	/******** CORTES *********/
	strcpy(sql, "SELECT c.numero_cliente, "); 
	strcat(sql, "TO_CHAR(c.fecha_corte, '%Y%m%d'), "); 
	strcat(sql, "c.motivo_corte, "); 
	strcat(sql, "c.accion_corte, "); 
	strcat(sql, "c.funcionario_corte, "); 
	strcat(sql, "TO_CHAR(c.fecha_ini_evento, '%Y%m%d'), "); 
	strcat(sql, "c.sit_encon ");
	strcat(sql, "FROM correp c ");
   if(giTipoCorrida==1){
      strcat(sql, ", migra_activos ma ");
   }
	strcat(sql, "WHERE c.fecha_reposicion is null ");
	strcat(sql, "AND c.fecha_corte >= ? ");

   if(giTipoCorrida==1){
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
   }
   
	$PREPARE selCortes FROM $sql;
	
	$DECLARE curCortes CURSOR FOR selCortes;
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	
	/************ Fecha Pivote **************/
	strcpy(sql, "SELECT fecha_pivote FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = 0 ");
		
	$PREPARE selFechaPivote FROM $sql;

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


short LeoCortes(reg)
$ClsCorte *reg;
{
	InicializaCorte(reg);

	$FETCH curCortes INTO
      :reg->numero_cliente, 
      :reg->fecha_corte, 
      :reg->motivo_corte, 
      :reg->accion_corte, 
      :reg->funcionario_corte, 
      :reg->fecha_ini_evento, 
      :reg->sit_encon;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Cortes !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
   
	alltrim(reg->fecha_corte, ' ');
	alltrim(reg->motivo_corte, ' ');
   
   alltrim(reg->accion_corte, ' ');
   alltrim(reg->funcionario_corte, ' ');
   alltrim(reg->fecha_ini_evento, ' ');
   alltrim(reg->sit_encon, ' ');
	
	return 1;	
}


void InicializaCorte(reg)
$ClsCorte	*reg;
{

	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente)); 
	memset(reg->fecha_corte, '\0', sizeof(reg->fecha_corte)); 
	memset(reg->motivo_corte, '\0', sizeof(reg->motivo_corte)); 
	memset(reg->accion_corte, '\0', sizeof(reg->accion_corte)); 
	memset(reg->funcionario_corte, '\0', sizeof(reg->funcionario_corte)); 
	memset(reg->fecha_ini_evento, '\0', sizeof(reg->fecha_ini_evento)); 
	memset(reg->sit_encon, '\0', sizeof(reg->sit_encon));
	
}


short GenerarPlano(fp, reg)
FILE 				*fp;
$ClsCorte		reg;
{
	/* HEADER */	
	GeneraHEADER(fp, reg);

	/* FKKMAZ */	
	/*GeneraFKKMAZ(fp, reg);*/
		
	/* ENDE */
	GeneraENDE(fp, reg);
	
	return 1;
}

void GeneraENDE(fp, reg)
FILE *fp;
$ClsCorte	reg;
{
	char	sLinea[1000];	
   int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "T1%ld\t&ENDE", reg.numero_cliente);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir ENDE\n");
      exit(1);
   }	
	
}

void GeneraHEADER(fp, reg)
FILE 		*fp;
ClsCorte	reg;
{
	char	sLinea[1000];	
	int  iRcv;
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
	sprintf(sLinea, "T1%ld\tHEADER\t", reg.numero_cliente);
   
   /* DISCREASON */
   /*sprintf(sLinea, "%s%s\t", sLinea, reg.motivo_corte);*/
   strcat(sLinea, "03\t");
   
   /* REFOBJTYPE */
   strcat(sLinea, "ISUACCOUNT\t");
  
   /* REFOBJKEY */
	/*sprintf(sLinea, "%s%012ld%012ld\t", sLinea, reg.numero_cliente, reg.numero_cliente);*/
   strcat(sLinea, "\t");
      
   /* ANLAGE */
   /*sprintf(sLinea, "%sT1%ld\t", sLinea, reg.numero_cliente);*/
   
   /* VKONTO */
   sprintf(sLinea, "%sT1%ld\t", sLinea, reg.numero_cliente);
   
   /* AB */
   sprintf(sLinea, "%s%s\t", sLinea, reg.fecha_corte);
   
   /* AB_TIME */
   /*strcat(sLinea, "");*/
   
   /* ORDERCODE */
   strcat(sLinea, "\t");
   /* ORDERWERK */
   
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir HEADER\n");
      exit(1);
   }	
	
}

void GeneraFKKMAZ(fp, reg)
FILE 		*fp;
ClsCorte	reg;
{
	char	sLinea[1000];	
	int  iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

   /* LLAVE */
	sprintf(sLinea, "T1%ld\tFKKMAZ\t", reg.numero_cliente);

   /* MAHNS */
   strcat(sLinea, "03\t");
   
   /* MAHNV */
   strcat(sLinea, "Z1\t");
   
   /* OPBEL (?) */
   strcat(sLinea, "\t");
   
   /* OPUPK */
   strcat(sLinea, "\t");
   /* OPUPW */
   strcat(sLinea, "");
   
	strcat(sLinea, "\n");
	
   iRcv=fprintf(fp, sLinea);
   if(iRcv < 0){
      printf("Error al escribir FKKMAZ\n");
      exit(1);
   }	
	
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

