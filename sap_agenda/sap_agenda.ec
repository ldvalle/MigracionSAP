/*********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_portion
    
	Fecha : 16/07/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las AGENDAS
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_agenda.h";

/* Variables Globales */

FILE	*pFileUnx;

char	sPathArchUnx[100];
char	sSoloArchivoUnx[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];

/* Variables Globales Host */
$ClsAgenda	regAge;

$long       lFechaPivote;
char        sFechaPivote[11];

$long       lFechaPivote2;
char        sFechaPivote2[11];

char	sMensMail[1024];	/*jhuck ME089 */

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fpPortion;
FILE	*fpUL;


	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
	/* $BEGIN WORK;*/

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}



	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   $EXECUTE selPivote INTO :lFechaPivote;

	$OPEN curAgenda USING :lFechaPivote;

	while(LeoAgenda(&regAge)){
      
      GenerarPlano(pFileUnx, regAge);
      
	}
	$CLOSE curAgenda;
			
	CerrarArchivos();

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
	printf("SAP_AGENDAS - Proceso Concluido.\n");
	printf("==============================================\n");
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

	if(argc != 2){
		MensajeParametros();
		return 0;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
}

short AbreArchivos()
{
	
	memset(sPathArchUnx,'\0',sizeof(sPathArchUnx));
	memset(sSoloArchivoUnx,'\0',sizeof(sSoloArchivoUnx));

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
	
	sprintf( sPathArchUnx  , "%sT1AGENDA.unx", sPathSalida );
	strcpy( sSoloArchivoUnx, "T1AGENDA.unx");
	
	pFileUnx=fopen( sPathArchUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sPathArchUnx );
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

	/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
   sprintf(sPathCp, "%sActivos/", sPathCopia);

	sprintf(sCommand, "chmod 755 %s", sPathArchUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sPathArchUnx, sPathCp);
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

   /******** Fecha Pivote  ****************/
   strcpy(sql, "SELECT TODAY - 420 FROM dual ");
   
   $PREPARE selPivote FROM $sql;

   /******** Fecha Pivote 2  ****************/
   strcpy(sql, "SELECT TODAY - 70 FROM dual ");
   
   $PREPARE selPivote2 FROM $sql;
	
   /******** Cursor Agenda  ****************/
	strcpy(sql, "SELECT "); 
	strcat(sql, " TRIM(sc.cod_ul_sap || "); 	
	strcat(sql, "      lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end, 2, 0)|| "); 
	strcat(sql, "      lpad(d.zona,5,0)) unidad_lectura, "); 
	strcat(sql, "'000T1'|| "); 
	strcat(sql, "   lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end,2,0) || sc.cod_ul_sap porcion, "); 
	strcat(sql, "a1.fecha_generacion, ");
	strcat(sql, "TO_CHAR(a1.fecha_generacion, '%d.%m.%Y') ");
	strcat(sql, "FROM agenda a1, sucur_centro_op sc, det_agenda d ");
	strcat(sql, "WHERE a1.sector <= 82 "); 
	strcat(sql, "AND a1.fecha_generacion >= ? ");
	strcat(sql, "AND sc.cod_centro_op = a1.sucursal "); 
	strcat(sql, "AND sc.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (sc.fecha_desactivac IS NULL OR sc.fecha_desactivac > TODAY) "); 
	strcat(sql, "AND d.identif_agenda = a1.identif_agenda "); 
	strcat(sql, "ORDER BY 2,1,3 ");   
   
	$PREPARE selAgenda FROM $sql;
	
	$DECLARE curAgenda CURSOR FOR selAgenda;	
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

   /********* Fecha RTi **********/
	strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;

  
   /*********** Año Atras ***********/
	strcpy(sql, "SELECT TODAY-574 FROM dual ");
      
   $PREPARE selAnoRetro FROM $sql;
   
  
     		
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

short LeoAgenda(reg)
$ClsAgenda *reg;
{
	InicializaAgenda(reg);
	
	$FETCH curAgenda into
      :reg->cod_ul,
      :reg->cod_porcion,
      :reg->fecha_generacion,
      :reg->fecha_lectura_fmt;
			
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Agendas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
	return 1;	
}

void InicializaAgenda(reg)
$ClsAgenda	*reg;
{
   memset(reg->cod_ul, '\0', sizeof(reg->cod_ul));
	memset(reg->cod_porcion, '\0', sizeof(reg->cod_porcion));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_generacion));
	memset(reg->fecha_lectura_fmt, '\0', sizeof(reg->fecha_lectura_fmt));
}

void GenerarPlano(fp, reg)
FILE 			*fp;
$ClsAgenda		reg;
{

	char	sLinea[1000];	

	memset(sLinea, '\0', sizeof(sLinea));
	
	sprintf(sLinea, "%s\t", reg.cod_ul);
   
   sprintf(sLinea, "%s%s\t", sLinea, reg.cod_porcion);
   
   sprintf(sLinea, "%s%s", sLinea, reg.fecha_lectura_fmt);

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

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

