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

FILE	*pFile417Unx;
FILE	*pFile418Unx;

char	sPathArch417Unx[100];
char	sSoloArchivo417Unx[100];
char	sPathArch418Unx[100];
char	sSoloArchivo418Unx[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
$char fechaActual[11];

int   giTipoCorrida;
int   giArchivo;
/* Variables Globales Host */
$ClsAgenda	regAge;

$long       lFechaPivote;
char        sFechaPivote[11];

$long       lFechaPivote2;
char        sFechaPivote2[11];
$long       glFechaParametro;
$dtime_t    gtInicioCorrida;
$char       sLstParametros[100];

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fpPortion;
FILE	*fpUL;
char     portionAnterior[9];
char     ulAnterior[9];
int      anio_anterior;
int      periodo_anterior;
int      iVuelta; 

$long    lMinFeGeneracion;
$long    lMinFeLectura;
$long    lMaxFeLectura;
$long    lMaxFeLectuAnterior;

$long    lMinFeUL;
$long    lMaxFeUL;
$long    lMaxFeULAnterior;

long     iCantPortion;
long     iCantUL;
int      iRcv;
$ClsAgenda  regAgeAux;  

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
	
	/* $BEGIN WORK;*/

	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	if(!AbreArchivos()){
		exit(1);	
	}

   memset(fechaActual, '\0', sizeof(fechaActual));
   
   $EXECUTE selFechaActual INTO :fechaActual;


	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   memset(portionAnterior, '\0', sizeof(portionAnterior));
   anio_anterior=0;
   periodo_anterior=0;; 
   iVuelta=0;
   lMinFeGeneracion=0;;
   lMinFeLectura=0;
   
   iCantPortion=0;
   iCantUL=0;
   
   if(glFechaParametro <= 0){
      $EXECUTE selPivote INTO :lFechaPivote;
   }else{
      lFechaPivote = glFechaParametro;   
   }

   /* Procesa 417 */
/*   
   if(giArchivo==0 || giArchivo==1){
   	$OPEN cur417 USING :lFechaPivote;
   
      if(Leo417(&regAge)){
         iRcv=1;
         strcpy(portionAnterior, regAge.cod_porcion);
         strcpy(ulAnterior, regAge.cod_ul);
         anio_anterior = regAge.anio_periodo;
         periodo_anterior = regAge.periodo;
         lMinFeGeneracion = regAge.fecha_generacion;
         
         lMinFeLectura = regAge.min_fecha_lectu;
         lMaxFeLectura = regAge.max_fecha_lectu;
         
         lMaxFeLectuAnterior = lMinFeLectura - 30;
       }
      while(iRcv){
   
         while(iRcv && strcmp(regAge.cod_porcion, portionAnterior)==0 && 
               regAge.anio_periodo == anio_anterior &&
               regAge.periodo == periodo_anterior){
      
            if( regAge.fecha_generacion < lMinFeGeneracion )
               lMinFeGeneracion = regAge.fecha_generacion;
            if( regAge.min_fecha_lectu < lMinFeLectura )
               lMinFeLectura = regAge.min_fecha_lectu;
      
            if( regAge.max_fecha_lectu > lMaxFeLectura )
               lMaxFeLectura = regAge.max_fecha_lectu;
      
            iRcv=Leo417(&regAge);
         }   
         Generar417(pFile417Unx, portionAnterior, lMinFeGeneracion, lMinFeLectura, lMaxFeLectura, lMaxFeLectuAnterior);
         
         lMaxFeLectuAnterior = lMaxFeLectura;      
         iCantPortion++;
         strcpy(portionAnterior, regAge.cod_porcion);
         anio_anterior = regAge.anio_periodo;
         periodo_anterior = regAge.periodo;
         lMinFeGeneracion = regAge.fecha_generacion;
         lMinFeLectura = regAge.min_fecha_lectu;
         lMaxFeLectura = regAge.max_fecha_lectu; 
         
      }   
   
      $CLOSE cur417;
   }   
*/
   
   if(giArchivo==0 || giArchivo==2){
      /* Procesa 418 */
      
      $BEGIN WORK;
      
      $EXECUTE delAgenda;
   
      $COMMIT WORK;
      
   	$OPEN cur418 USING :lFechaPivote;
      
      if(Leo418(&regAge)){
         iRcv=1;
         strcpy(portionAnterior, regAge.cod_porcion);
         strcpy(ulAnterior, regAge.cod_ul);
         anio_anterior = regAge.anio_periodo;
         periodo_anterior = regAge.periodo;
         lMinFeGeneracion = regAge.fecha_generacion;
         
         lMinFeLectura = regAge.min_fecha_lectu;
         lMaxFeLectura = regAge.max_fecha_lectu;
   
         lMinFeUL = regAge.min_fecha_lectu; 
         lMaxFeUL = regAge.max_fecha_lectu;
          
         lMaxFeLectuAnterior = lMinFeLectura - 30;
         lMaxFeULAnterior = lMaxFeLectuAnterior;
   
         CopiaEstructura(regAge, &regAgeAux);
         
         while(iRcv){
            while(iRcv && strcmp(regAge.cod_porcion, portionAnterior)==0 &&
                  strcmp(regAge.cod_ul, ulAnterior)==0 &&
                  regAge.anio_periodo == anio_anterior &&
                  regAge.periodo == periodo_anterior){
                  
               if(regAge.min_fecha_lectu < lMinFeUL )
                  lMinFeUL = regAge.min_fecha_lectu;
                  
               if(regAge.max_fecha_lectu > lMaxFeUL )
                  lMaxFeUL = regAge.max_fecha_lectu;

               iRcv=Leo418(&regAge);
            }

            $BEGIN WORK;
            if(!RegistraAgenda(regAgeAux, lMinFeUL, lMaxFeUL)){
               printf("No se grabó la agenda %ld\n", regAge.identif_agenda);
            }
            $COMMIT WORK;
                      
            Generar418(pFile418Unx, regAgeAux, portionAnterior, ulAnterior, lMinFeUL, lMaxFeUL, lMaxFeULAnterior);
            iCantUL++;

            CopiaEstructura(regAge, &regAgeAux);

            if(strcmp(regAge.cod_porcion, portionAnterior)==0 && strcmp(regAge.cod_ul, ulAnterior)==0 ){
               lMaxFeULAnterior = lMaxFeUL;
            }else{
               lMaxFeULAnterior =  lMinFeUL-30;
            }
                     
            lMinFeUL = regAge.min_fecha_lectu; 
            lMaxFeUL = regAge.max_fecha_lectu;
       
            strcpy(portionAnterior, regAge.cod_porcion);
            strcpy(ulAnterior, regAge.cod_ul);
            anio_anterior = regAge.anio_periodo;
            periodo_anterior = regAge.periodo;
      
         }
      }
      $CLOSE cur418;
   }

   /* Procesa 417 */
   if(giArchivo==0 || giArchivo==1){
   	$OPEN cur417;
   
      if(Leo417B(&regAge)){
         iRcv=1;
         lMaxFeLectuAnterior = regAge.min_fecha_lectu - 30;
       }
      while(iRcv){
         Generar417B(pFile417Unx, regAge, lMaxFeLectuAnterior);
         
         lMaxFeLectuAnterior = regAge.max_fecha_lectu;      
         iCantPortion++;
         
         iRcv = Leo417B(&regAge);
      }   
   
      $CLOSE cur417;
   }   

      
/**************************************/
/************** INICIO VIEJO ************************/
/**************************************/
/*
	while(Leo417(&regAge)){
      if(iVuelta==0){
         strcpy(portionAnterior, regAge.cod_porcion);
         strcpy(ulAnterior, regAge.cod_ul);
         anio_anterior = regAge.anio_periodo;
         periodo_anterior = regAge.periodo;
         lMinFeGeneracion = regAge.fecha_generacion;
         
         lMinFeLectura = regAge.min_fecha_lectu;
         lMaxFeLectura = regAge.max_fecha_lectu;
         
         lMinFeUL = regAge.min_fecha_lectu; 
         lMaxFeUL = regAge.max_fecha_lectu;
          
         lMaxFeLectuAnterior = lMinFeLectura - 30;
         lMaxFeULAnterior = lMaxFeLectuAnterior;
         iVuelta = 1;
      }
         
      if(strcmp(regAge.cod_porcion, portionAnterior)==0 && 
            regAge.anio_periodo == anio_anterior &&
            regAge.periodo == periodo_anterior){
         // Porcion para el mismo año mes            
         if( regAge.fecha_generacion < lMinFeGeneracion )
            lMinFeGeneracion = regAge.fecha_generacion;
         if( regAge.min_fecha_lectu < lMinFeLectura )
            lMinFeLectura = regAge.min_fecha_lectu;

         if( regAge.max_fecha_lectu > lMaxFeLectura )
            lMaxFeLectura = regAge.max_fecha_lectu;
                         
      }else{
         
         Generar417(pFile417Unx, portionAnterior, lMinFeGeneracion, lMinFeLectura, lMaxFeLectura, lMaxFeLectuAnterior);
         lMaxFeLectuAnterior = lMaxFeLectura;      
         iCantPortion++;
         strcpy(portionAnterior, regAge.cod_porcion);
         anio_anterior = regAge.anio_periodo;
         periodo_anterior = regAge.periodo;
         lMinFeGeneracion = regAge.fecha_generacion;
         lMinFeLectura = regAge.min_fecha_lectu;
         lMaxFeLectura = regAge.max_fecha_lectu; 

         
      }
      if(iVuelta==0)
         regAge.fechaAgendaAnterior = lMaxFeLectuAnterior;

      if(strcmp(regAge.cod_porcion, portionAnterior)==0 &&
            strcmp(regAge.cod_ul, ulAnterior)==0 &&
            regAge.anio_periodo == anio_anterior &&
            regAge.periodo == periodo_anterior){
            
            if(regAge.min_fecha_lectu < lMinFeUL )
               lMinFeUL = regAge.min_fecha_lectu;
               
            if(regAge.max_fecha_lectu > lMaxFeUL )
               lMaxFeUL = regAge.max_fecha_lectu;
            
      }else{
      
         $BEGIN WORK;
         if(!RegistraAgenda(regAge, lMinFeUL, lMaxFeUL)){
            printf("No se grabó la agenda %ld\n", regAge.identif_agenda);
         }
         $COMMIT WORK;
                   
         Generar418(pFile418Unx, regAge, lMinFeUL, lMaxFeUL, lMaxFeULAnterior);
         iCantUL++;
      
         lMinFeUL = regAge.min_fecha_lectu; 
         lMaxFeUL = regAge.max_fecha_lectu;
         lMaxFeULAnterior = lMaxFeUL;
         strcpy(ulAnterior, regAge.cod_ul); 
      
      }

   // El ultimo 417    
   Generar417(pFile417Unx, portionAnterior, lMinFeGeneracion, lMinFeLectura, lMaxFeLectura, lMaxFeLectuAnterior);
   iCantPortion++;

   // El ultimo 418 
   $BEGIN WORK;
   if(!RegistraAgenda(regAge, lMinFeUL, lMaxFeUL )){
      printf("No se grabó la agenda %ld\n", regAge.identif_agenda);
   }
   $COMMIT WORK;

   Generar418(pFile418Unx, regAge, lMinFeUL, lMaxFeUL, lMaxFeULAnterior);
   iCantUL++;
*/
/**************************************/
/************** CIERRE VIEJO ************************/
/**************************************/
			
	CerrarArchivos();

   /* Registro la corrida */
   $BEGIN WORK;
   
   $EXECUTE insRegiCorrida USING :gtInicioCorrida,
                                 :sLstParametros;
   
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
	printf("SAP_AGENDAS - Proceso Concluido.\n");
	printf("==============================================\n");
   printf("Cantidad de Porciones:  %ld\n", iCantPortion);
   printf("Cantidad de ULs      :  %ld\n", iCantUL);
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
   
   if(argc > 5 || argc < 4){
		MensajeParametros();
		return 0;
	}
	
   giTipoCorrida = atoi(argv[2]);
   
   giArchivo = atoi(argv[3]);
   
   if(argc == 5){
      strcpy(sFechaPar, argv[4]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
      sprintf(sLstParametros, "%s %s %s", argv[1], argv[2], argv[3], argv[4]);
   }else{
      glFechaParametro=-1;
      sprintf(sLstParametros, "%s %s", argv[1], argv[2], argv[3]);
   }
   
   alltrim(sLstParametros, ' ');
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
      printf("	<Tipo Corrida> = 0=total, 1=reducida.\n");
      printf("	<Archivos> = 0=Todos, 1=417, 2=418.\n");
      printf("	<Fecha Inicio> = dd/mm/aaaa (opcional).\n");
}

short AbreArchivos()
{
	
	memset(sPathArch417Unx,'\0',sizeof(sPathArch417Unx));
	memset(sSoloArchivo417Unx,'\0',sizeof(sSoloArchivo417Unx));

	memset(sPathSalida,'\0',sizeof(sPathSalida));
   memset(sPathCopia,'\0',sizeof(sPathCopia));

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
	
   /*********************/
   if(giArchivo==0 || giArchivo==1){
   	sprintf( sPathArch417Unx  , "%sT1TE417.unx", sPathSalida );
   	strcpy( sSoloArchivo417Unx, "T1TE417.unx");
   	
   	pFile417Unx=fopen( sPathArch417Unx, "w" );
   	if( !pFile417Unx ){
   		printf("ERROR al abrir archivo %s.\n", sPathArch417Unx );
   		return 0;
   	}
   }			
   /*********************/
   if(giArchivo==0 || giArchivo==2){
   	memset(sPathArch418Unx,'\0',sizeof(sPathArch418Unx));
   	memset(sSoloArchivo418Unx,'\0',sizeof(sSoloArchivo418Unx));
   
   	sprintf( sPathArch418Unx  , "%sT1TE418.unx", sPathSalida );
   	strcpy( sSoloArchivo418Unx, "T1TE418.unx");
   	
   	pFile418Unx=fopen( sPathArch418Unx, "w" );
   	if( !pFile418Unx ){
   		printf("ERROR al abrir archivo %s.\n", sPathArch418Unx );
   		return 0;
   	}			
   }   
	
	return 1;	
}

void CerrarArchivos(void)
{
   if(giArchivo==0 || giArchivo==1)
      fclose(pFile417Unx);
      
   if(giArchivo==0 || giArchivo==2)   
      fclose(pFile418Unx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
   sprintf(sPathCp, "%sActivos/", sPathCopia);

   if(giArchivo==0 || giArchivo==1){
   	sprintf(sCommand, "chmod 755 %s", sPathArch417Unx);
   	iRcv=system(sCommand);
   	
   	sprintf(sCommand, "cp %s %s", sPathArch417Unx, sPathCp);
   	iRcv=system(sCommand);
   }
   
   if(giArchivo==0 || giArchivo==2){
   	sprintf(sCommand, "chmod 755 %s", sPathArch418Unx);
   	iRcv=system(sCommand);
   	
   	sprintf(sCommand, "cp %s %s", sPathArch418Unx, sPathCp);
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
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d.%m.%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

   /******** Fecha Pivote  ****************/
   /*strcpy(sql, "SELECT TODAY - 420 FROM dual ");*/
   strcpy(sql, "SELECT fecha_pivote - 60 FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = 0 ");
   
   $PREPARE selPivote FROM $sql;

   /******** Fecha Pivote 2  ****************/
   strcpy(sql, "SELECT TODAY - 70 FROM dual ");
   
   $PREPARE selPivote2 FROM $sql;
	
   /******** Cursor 417  ****************/
/*   
	strcpy(sql, "SELECT "); 
	strcat(sql, " TRIM(sc.cod_ul_sap || "); 	
	strcat(sql, "      lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end, 2, 0)|| "); 
	strcat(sql, "      lpad(d.zona,5,0)) unidad_lectura, "); 
	strcat(sql, "'000T1'|| "); 
	strcat(sql, "   lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end,2,0) || sc.cod_ul_sap porcion, "); 
	strcat(sql, "a1.fecha_generacion, ");
	strcat(sql, "TO_CHAR(a1.fecha_generacion, '%d.%m.%Y'), ");
	strcat(sql, "a1.tipo_ciclo, ");
	strcat(sql, "a1.sucursal, ");
	strcat(sql, "a1.sector, ");
	strcat(sql, "d.zona, ");
	strcat(sql, "a1.fecha_emision_real, ");
	strcat(sql, "a1.anio_periodo, ");
	strcat(sql, "a1.periodo, ");
   strcat(sql, "a1.identif_agenda ");    
	strcat(sql, "FROM agenda a1, sucur_centro_op sc, det_agenda d ");
	strcat(sql, "WHERE a1.sector <= 82 "); 
	strcat(sql, "AND a1.fecha_generacion >= ? ");
	strcat(sql, "AND sc.cod_centro_op = a1.sucursal "); 
	strcat(sql, "AND sc.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (sc.fecha_desactivac IS NULL OR sc.fecha_desactivac > TODAY) "); 
	strcat(sql, "AND d.identif_agenda = a1.identif_agenda "); 
	strcat(sql, "ORDER BY porcion, anio_periodo, periodo ");
*/
   strcpy(sql, "SELECT porcion, anio_periodo, periodo, MIN(inicio_ventana), MAX(fin_ventana) ");
	strcat(sql, "FROM sap_agenda ");
	strcat(sql, "GROUP BY porcion, anio_periodo, periodo ");
	strcat(sql, "ORDER BY 1,2,3 ");
   
	$PREPARE sel417 FROM $sql;
	
	$DECLARE cur417 CURSOR WITH HOLD FOR sel417;	

   /******** Cursor 418  ****************/
	strcpy(sql, "SELECT "); 
	strcat(sql, " TRIM(sc.cod_ul_sap || "); 	
	strcat(sql, "      lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end, 2, 0)|| "); 
	strcat(sql, "      lpad(d.zona,5,0)) unidad_lectura, "); 
	strcat(sql, "'000T1'|| "); 
	strcat(sql, "   lpad(case when a1.sector>60 and a1.sector < 81 then a1.sector else a1.sector end,2,0) || sc.cod_ul_sap porcion, "); 
	strcat(sql, "a1.fecha_generacion, ");
	strcat(sql, "TO_CHAR(a1.fecha_generacion, '%d.%m.%Y'), ");
	strcat(sql, "a1.tipo_ciclo, ");
	strcat(sql, "a1.sucursal, ");
	strcat(sql, "a1.sector, ");
	strcat(sql, "d.zona, ");
	strcat(sql, "a1.fecha_emision_real, ");
	strcat(sql, "a1.anio_periodo, ");
	strcat(sql, "a1.periodo, ");
   strcat(sql, "a1.identif_agenda ");    
	strcat(sql, "FROM agenda a1, sucur_centro_op sc, det_agenda d ");
	strcat(sql, "WHERE a1.sector <= 82 "); 
	strcat(sql, "AND a1.fecha_generacion >= ? ");
	strcat(sql, "AND sc.cod_centro_op = a1.sucursal "); 
	strcat(sql, "AND sc.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (sc.fecha_desactivac IS NULL OR sc.fecha_desactivac > TODAY) "); 
	strcat(sql, "AND d.identif_agenda = a1.identif_agenda "); 
	strcat(sql, "ORDER BY porcion, unidad_lectura, anio_periodo, periodo ");
	/*strcat(sql, "ORDER BY 2,1,3 ");*/   
   
	$PREPARE sel418 FROM $sql;
	
	$DECLARE cur418 CURSOR WITH HOLD FOR sel418;	

   /******** Min.Fecha Lectura *************/
   strcpy(sql, "SELECT MIN(h.fecha_lectura) ");
   strcat(sql, "FROM hisfac h ");
if(giTipoCorrida == 1){
   strcat(sql, ", migra_activos ma ");
}   
   strcat(sql, "WHERE h.sucursal = ? ");
   strcat(sql, "AND h.sector = ? ");
   strcat(sql, "AND h.zona = ? ");
   strcat(sql, "AND h.fecha_facturacion = ? ");
if(giTipoCorrida == 1){
   strcat(sql, "AND ma.numero_cliente = h.numero_cliente ");
}   


   $PREPARE selMinLectu FROM $sql;

   /******** Max.Fecha Lectura *************/
   strcpy(sql, "SELECT MAX(h.fecha_lectura) ");
   strcat(sql, "FROM hisfac h ");
if(giTipoCorrida == 1){
   strcat(sql, ", migra_activos ma ");
}   
   strcat(sql, "WHERE h.sucursal = ? ");
   strcat(sql, "AND h.sector = ? ");
   strcat(sql, "AND h.zona = ? ");
   strcat(sql, "AND h.fecha_facturacion = ? ");
if(giTipoCorrida == 1){
   strcat(sql, "AND ma.numero_cliente = h.numero_cliente ");
}   

   $PREPARE selMaxLectu FROM $sql;

	/******** Fecha Cierre Agenda Anterior *********/
   strcpy(sql, "SELECT MAX(h.fecha_lectura) ");
   strcat(sql, "FROM hisfac h ");
if(giTipoCorrida == 1){
   strcat(sql, ", migra_activos ma ");
}   
   strcat(sql, "WHERE h.sucursal = ? ");
   strcat(sql, "AND h.sector = ? ");
   strcat(sql, "AND h.zona = ? ");
   strcat(sql, "AND h.fecha_facturacion = (SELECT MAX(a.fecha_emision_real) ");
   strcat(sql, "FROM agenda a "); 
   strcat(sql, "WHERE a.sucursal = h.sucursal ");
   strcat(sql, "AND a.sector = h.sector ");
   strcat(sql, "AND a.fecha_generacion < ? ) ");
if(giTipoCorrida == 1){
   strcat(sql, "AND ma.numero_cliente = h.numero_cliente ");
}   

   $PREPARE selFechaCierreAnterior FROM $sql;   
   
   
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
   
   /******* Inicializa Agenda  ********/
   $PREPARE delAgenda FROM "DELETE FROM sap_agenda ";   
   
  /*********** Grabo Agenda SAP ***********/
   $PREPARE insAgenda FROM "INSERT INTO sap_agenda (
      porcion,
      ul,
      fecha_generacion, 
      tipo_ciclo, 
      sucursal, 
      sector, 
      zona, 
      fecha_emision_real, 
      anio_periodo, 
      periodo,
      inicio_ventana,
      fin_ventana,
      identif_agenda
      )VALUES(
      ?,?,?,?,?,?,?,?,?,?,?,?,?)";
  
   /******* Registro Corrida *********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'AGENDA', ?, CURRENT, ?)";
   
           		
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

short Leo417(reg)
$ClsAgenda *reg;
{
	InicializaAgenda(reg);
	
	$FETCH cur417 into
      :reg->cod_ul,
      :reg->cod_porcion,
      :reg->fecha_generacion,
      :reg->fecha_lectura_fmt,
      :reg->tipo_ciclo,
      :reg->sucursal,   
      :reg->sector,
      :reg->zona,
      :reg->fecha_emision_real,
      :reg->anio_periodo,
      :reg->periodo,
      :reg->identif_agenda;
			
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Agendas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
   /* Busca Minima Fecha Lectura para la agenda */
   $EXECUTE selMinLectu INTO :reg->min_fecha_lectu
         USING :reg->sucursal,
               :reg->sector,
               :reg->zona,
               :reg->fecha_emision_real;
               
   if(SQLCODE != 0){
      printf("No se encontró minima para Suc %s Sec %d Zona %d emi.real %ld\n", reg->sucursal,
               reg->sector, reg->zona, reg->fecha_emision_real);
               
      reg->min_fecha_lectu = reg->fecha_generacion;
   }               

   if(reg->min_fecha_lectu <= 0 || risnull(CLONGTYPE, (char *) reg->min_fecha_lectu)){
      reg->min_fecha_lectu = reg->fecha_generacion;
   }

   /* Busca Maxima Fecha Lectura para la agenda */
   $EXECUTE selMaxLectu INTO :reg->max_fecha_lectu
         USING :reg->sucursal,
               :reg->sector,
               :reg->zona,
               :reg->fecha_emision_real;
               
   if(SQLCODE != 0){
      printf("No se encontró maxima para Suc %s Sec %d Zona %d emi.real %ld\n", reg->sucursal,
               reg->sector, reg->zona, reg->fecha_emision_real);
               
      reg->max_fecha_lectu = reg->fecha_generacion;
   }               

   if(reg->max_fecha_lectu <= 0 || risnull(CLONGTYPE, (char *) reg->max_fecha_lectu)){
      reg->max_fecha_lectu = reg->fecha_generacion;
   }
   
  
	return 1;	
}

short Leo417B(reg)
$ClsAgenda *reg;
{
	InicializaAgenda(reg);
	
	$FETCH cur417 into
      :reg->cod_porcion,
      :reg->anio_periodo,
      :reg->periodo,
      :reg->min_fecha_lectu,
      :reg->max_fecha_lectu;
			
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


short Leo418(reg)
$ClsAgenda *reg;
{
	InicializaAgenda(reg);
	
	$FETCH cur418 into
      :reg->cod_ul,
      :reg->cod_porcion,
      :reg->fecha_generacion,
      :reg->fecha_lectura_fmt,
      :reg->tipo_ciclo,
      :reg->sucursal,   
      :reg->sector,
      :reg->zona,
      :reg->fecha_emision_real,
      :reg->anio_periodo,
      :reg->periodo,
      :reg->identif_agenda;
			
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Agendas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	
   /* Busca Minima Fecha Lectura para la agenda */
   $EXECUTE selMinLectu INTO :reg->min_fecha_lectu
         USING :reg->sucursal,
               :reg->sector,
               :reg->zona,
               :reg->fecha_emision_real;
               
   if(SQLCODE != 0){
      printf("No se encontró minima para Suc %s Sec %d Zona %d emi.real %ld\n", reg->sucursal,
               reg->sector, reg->zona, reg->fecha_emision_real);
               
      reg->min_fecha_lectu = reg->fecha_generacion;
   }               

   if(reg->min_fecha_lectu <= 0 || risnull(CLONGTYPE, (char *) reg->min_fecha_lectu)){
      reg->min_fecha_lectu = reg->fecha_generacion;
   }

   /* Busca Maxima Fecha Lectura para la agenda */
   $EXECUTE selMaxLectu INTO :reg->max_fecha_lectu
         USING :reg->sucursal,
               :reg->sector,
               :reg->zona,
               :reg->fecha_emision_real;
               
   if(SQLCODE != 0){
      printf("No se encontró maxima para Suc %s Sec %d Zona %d emi.real %ld\n", reg->sucursal,
               reg->sector, reg->zona, reg->fecha_emision_real);
               
      reg->max_fecha_lectu = reg->fecha_generacion;
   }               

   if(reg->max_fecha_lectu <= 0 || risnull(CLONGTYPE, (char *) reg->max_fecha_lectu)){
      reg->max_fecha_lectu = reg->fecha_generacion;
   }
   

   /* El menor menos 3 días. */
   /*reg->menorMenos3 = getMenorMenos3(reg->min_fecha_lectu);*/

          
   /* Busca Cierre Agenda Anterior */
         
   $EXECUTE selFechaCierreAnterior INTO :reg->fechaAgendaAnterior
      USING :reg->sucursal,
            :reg->sector,
            :reg->zona,
            :reg->fecha_generacion;

   if(SQLCODE != 0){
      printf("No se encontró cierre agenda anterior para Suc %s Sec %d Zona %d fe.generacion %ld\n", reg->sucursal,
               reg->sector, reg->zona, reg->fecha_generacion);
               
      reg->fechaAgendaAnterior = reg->min_fecha_lectu - 1;
   }               

   if(reg->fechaAgendaAnterior <= 0 || risnull(CLONGTYPE, (char *) reg->fechaAgendaAnterior)){
      reg->fechaAgendaAnterior = reg->min_fecha_lectu - 1;
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
   memset(reg->tipo_ciclo, '\0', sizeof(reg->tipo_ciclo));
   memset(reg->sucursal, '\0', sizeof(reg->sucursal));   
   rsetnull(CINTTYPE, (char *) &(reg->sector));
   rsetnull(CINTTYPE, (char *) &(reg->zona));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_emision_real));
   rsetnull(CINTTYPE, (char *) &(reg->anio_periodo));
   rsetnull(CINTTYPE, (char *) &(reg->periodo));
   
   rsetnull(CLONGTYPE, (char *) &(reg->min_fecha_lectu));
   rsetnull(CLONGTYPE, (char *) &(reg->max_fecha_lectu));
   rsetnull(CLONGTYPE, (char *) &(reg->fechaAgendaAnterior));
   rsetnull(CLONGTYPE, (char *) &(reg->menorMenos3));
   rsetnull(CLONGTYPE, (char *) &(reg->identif_agenda));
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


void Generar417(fp, portion, lFeGeneracion, lFeMinLectu, lFeMaxLectu, lFeMaxAnterior)
FILE 			 *fp;
char        portion[9];
long        lFeGeneracion;
long        lFeMinLectu;
long        lFeMaxLectu;
long        lFeMaxAnterior;
{
	char	sLinea[1000];	
   char  sFechaAux[11];
   char  sFechaGenera[11];

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sFechaAux, '\0', sizeof(sFechaAux));
   memset(sFechaGenera, '\0', sizeof(sFechaGenera));
   rfmtdate( lFeGeneracion, "dd.mm.yyyy", sFechaGenera);
	
   /* MANDT */
   strcpy(sLinea, "100\t");
      
   /* TERMSCHL */
   sprintf(sLinea, "%s%s\t", sLinea, portion);
   
   /* TERMTDAT */
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);*/
   if(lFeMaxLectu > 0){
      rfmtdate( lFeMaxLectu, "dd.mm.yyyy", sFechaAux);
      sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);
   }else{
      sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);
   }
   
   /* TERMPDAT */
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   
   /* ZUORDDAT */
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);*/
   if(lFeMaxLectu > 0){
      rfmtdate( lFeMaxLectu, "dd.mm.yyyy", sFechaAux);
      sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);
   }else{
      sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);
   }
   
   /* ABRDATS */
   if(lFeMinLectu > 0){
      rfmtdate( lFeMinLectu, "dd.mm.yyyy", sFechaAux);
      sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);
   }else{
      sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);
   }
   
   /* ABSCHLE (vacio)*/
   strcat(sLinea, "\t");
   /* ABSCHLL (vacio) */
   strcat(sLinea, "\t");
   /* ABRVORG */
   strcat(sLinea, "01\t");
   /* THGDAT */
   strcat(sLinea, "\t");
   /* DATUMDF */
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);*/
   if(lFeMaxLectu > 0){
      rfmtdate( lFeMaxLectu, "dd.mm.yyyy", sFechaAux);
      sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);
   }else{
      sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);
   }
   
   /* MSPABPLF */
   strcat(sLinea, "\t");
   /* PTERMSCHL */
   strcat(sLinea, "0001\t");
   
   /* ENDVOPER */
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);*/
   if(lFeMaxAnterior > 0){
      rfmtdate( lFeMaxAnterior, "dd.mm.yyyy", sFechaAux);
      sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);
   }else{
      sprintf(sLinea, "%s%s\t", sLinea, sFechaGenera);
   }
   
   /* ERDAT */
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   /* ERNAM */
   strcat(sLinea, "AR38638501\t");
   /* AEDAT */
   strcat(sLinea, "\t");
   /* AENAM */
   strcat(sLinea, "\t");
   /* SAPKAL */
   strcat(sLinea, "2\t");
   /* IDENT */
   strcat(sLinea, "AR\t");
   /* TS_DYN (vacio)*/

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

/*
rdefmtdate(&lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); //char to long
lFechaAux=lFechaAux+1;
rfmtdate(lFechaAux, "yyyymmdd", regLecturas.fecha_lectura); // long to char 

lFechaAux1 = RestarDiasHabiles(lFechaAux, 1, lFDesde);
lFechaAux2 = RestarDiasHabiles(lFechaAux1, 3, lFDesde); 
*/

}

void Generar417B(fp, reg, lFeMaxAnterior)
FILE 			 *fp;
ClsAgenda   reg;
long        lFeMaxAnterior;
{
	char	sLinea[1000];	
   char  sFechaIni[11];
   char  sFechaCierre[11];
   char  sFechaCierreAnterior[11];

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sFechaIni, '\0', sizeof(sFechaIni));
   memset(sFechaCierre, '\0', sizeof(sFechaCierre));
   memset(sFechaCierreAnterior, '\0', sizeof(sFechaCierreAnterior));
   
   rfmtdate( reg.min_fecha_lectu, "dd.mm.yyyy", sFechaIni);
   rfmtdate( reg.max_fecha_lectu, "dd.mm.yyyy", sFechaCierre);
   rfmtdate( lFeMaxAnterior, "dd.mm.yyyy", sFechaCierreAnterior);
	
   /* MANDT */
   strcpy(sLinea, "100\t");
      
   /* TERMSCHL */
   sprintf(sLinea, "%s%s\t", sLinea, reg.cod_porcion);
   
   /* TERMTDAT (fecha cierre) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCierre);
   
   /* TERMPDAT (fecha corrida) */
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   
   /* ZUORDDAT (fecha cierre)*/
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCierre);
   
   /* ABRDATS (fecha inicio) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaIni);
   
   /* ABSCHLE (vacio)*/
   strcat(sLinea, "\t");
   /* ABSCHLL (vacio) */
   strcat(sLinea, "\t");
   /* ABRVORG */
   strcat(sLinea, "01\t");
   /* THGDAT */
   strcat(sLinea, "\t");
   /* DATUMDF (fecha cierre) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCierre);
   
   /* MSPABPLF */
   strcat(sLinea, "\t");
   /* PTERMSCHL */
   strcat(sLinea, "0001\t");
   
   /* ENDVOPER (fecha cierre anterior) */
   sprintf(sLinea, "%s%s\t", sLinea, sFechaCierreAnterior);
   
   /* ERDAT */
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   /* ERNAM */
   strcat(sLinea, "AR38638501\t");
   /* AEDAT */
   strcat(sLinea, "\t");
   /* AENAM */
   strcat(sLinea, "\t");
   /* SAPKAL */
   strcat(sLinea, "2\t");
   /* IDENT */
   strcat(sLinea, "AR\t");
   /* TS_DYN (vacio)*/

	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

}



void Generar418(fp, reg, portion, ul, lDesde, lHasta, lHastaAnterior)
FILE *fp;
ClsAgenda   reg;
char        portion[9];
char        ul[9];
long        lDesde;
long        lHasta;
long        lHastaAnterior;
{
	char	sLinea[1000];
   char  sFechaMin[11];
   char  sFechaMinMenos3[11];
   char  sFechaAux[11];
   
   char  sDesde[11];
   char  sHasta[11];
   char  sHastaAnterior[11];
   
   long  lMenorMenos3;
   
   memset(sLinea, '\0', sizeof(sLinea));
   memset(sFechaMin, '\0', sizeof(sFechaMin));
   memset(sFechaMinMenos3, '\0', sizeof(sFechaMinMenos3));
   memset(sFechaAux, '\0', sizeof(sFechaAux));
   
   memset(sDesde, '\0', sizeof(sDesde));
   memset(sHasta, '\0', sizeof(sHasta));
   memset(sHastaAnterior, '\0', sizeof(sHastaAnterior));
/*   
   rfmtdate( reg.min_fecha_lectu, "dd.mm.yyyy", sFechaMin);
   rfmtdate( reg.menorMenos3, "dd.mm.yyyy", sFechaMinMenos3);
*/
   
   rfmtdate( lDesde, "dd.mm.yyyy", sDesde);
   rfmtdate( lHasta, "dd.mm.yyyy", sHasta);
   rfmtdate( lHastaAnterior, "dd.mm.yyyy", sHastaAnterior);
   
   lMenorMenos3 = getMenorMenos3(lDesde);
   rfmtdate( lMenorMenos3, "dd.mm.yyyy", sFechaMinMenos3);
      
   /* MANDT */
   strcpy(sLinea, "100\t");	
   /* TERMSCHL	*/
   sprintf(sLinea, "%s%s\t", sLinea, ul);
   
   /* TERMTDAT	(Fin Ventana) */
   /*sprintf(sLinea, "%s%s\t", sLinea, reg.fecha_lectura_fmt);
   rfmtdate( reg.max_fecha_lectu, "dd.mm.yyyy", sFechaAux);
   sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);*/
   sprintf(sLinea, "%s%s\t", sLinea, sHasta);
   
   /* TERMPDAT */
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   /* ADATSOLL	(inicio ventana) */
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABLV	*/
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaMinMenos3);*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABLK	*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABLA	*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABLP	*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABLD	*/
   /*sprintf(sLinea, "%s%s\t", sLinea, sFechaMinMenos3);*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* SAPKAL	*/
   strcat(sLinea, "2\t");
   /* IDENT	*/
   strcat(sLinea, "AR\t");
   /* ZUORDDAT	*/
   sprintf(sLinea, "%s%s\t", sLinea, sDesde);
   /* BEGABL (fin Ventana) */
   /*sprintf(sLinea, "%s%s\t", sLinea, reg.fecha_lectura_fmt);*/
   sprintf(sLinea, "%s%s\t", sLinea, sHasta);
   /* ALKARDAT	*/
   strcat(sLinea, "\t");
   /* ABLESGR	*/
   strcat(sLinea, "01\t");
   /* ABLESART	*/
   if(reg.tipo_ciclo[0]=='R'){
      strcat(sLinea, "04\t");
   }else{
      strcat(sLinea, "01\t");
   }
   /* THGDAT	*/
   strcat(sLinea, "\t");
   /* DATUMDF	*/
   strcat(sLinea, "\t");
   
   /* ENDVOPER	(fin ventana agenda anterior) */
   /*memset(sFechaAux, '\0', sizeof(sFechaAux));
   rfmtdate( reg.fechaAgendaAnterior, "dd.mm.yyyy", sFechaAux);
   sprintf(sLinea, "%s%s\t", sLinea, sFechaAux);*/
   sprintf(sLinea, "%s%s\t", sLinea, sHastaAnterior);
   
   /* ABRDATS */
   strcat(sLinea, "\t");
   /* ERDAT	*/
   sprintf(sLinea, "%s%s\t", sLinea, fechaActual);
   /* ERNAM	*/
   strcat(sLinea, "AR38638501");
   /* AEDAT */
   strcat(sLinea, "\t");
   /* AENAM */
   strcat(sLinea, "\t");
   /* TS_DYN */
   strcat(sLinea, "\t");
   /* ESTINBILL */
   strcat(sLinea, "\t");
   /* ABSLANP (vacio) */
   
	strcat(sLinea, "\n");
	
	fprintf(fp, sLinea);	

}


long getMenorMenos3(lFecha)
$long lFecha;
{
   $long lFechaDesde=lFecha - 30;
   int i=0;

   lFecha = lFecha-3;
   
   while(EsDiaFeriado(lFecha, lFechaDesde) && i < 10){
      lFecha=lFecha-1;
      i++;
   }      

   return lFecha;
}

short RegistraAgenda(reg, fDesde, fHasta)
$ClsAgenda  reg;
$long       fDesde;
$long       fHasta;
{

   $EXECUTE insAgenda USING
      :reg.cod_porcion,
   	:reg.cod_ul,
   	:reg.fecha_generacion,
      :reg.tipo_ciclo,
      :reg.sucursal,
      :reg.sector,
      :reg.zona,
      :reg.fecha_emision_real,
      :reg.anio_periodo,
      :reg.periodo,
      :fDesde,
      :fHasta,
      :reg.identif_agenda;

   if(SQLCODE != 0){
      printf("Fallo insert sap_agenda\n");
      return 0;
   }      

   return 1;
}

void CopiaEstructura(reg, rAux)
ClsAgenda      reg;
$ClsAgenda     *rAux;
{
   strcpy(rAux->cod_ul, reg.cod_ul);
   strcpy(rAux->cod_porcion, reg.cod_porcion);
   rAux->fecha_generacion = reg.fecha_generacion;
   strcpy(rAux->tipo_ciclo, reg.tipo_ciclo);
   strcpy(rAux->sucursal, reg.sucursal);   
   rAux->sector = reg.sector;
   rAux->zona = reg.zona;
   rAux->fecha_emision_real = reg.fecha_emision_real;
   rAux->anio_periodo = reg.anio_periodo;   
   rAux->periodo = reg.periodo;
   rAux->identif_agenda = reg.identif_agenda;
   rAux->min_fecha_lectu = reg.min_fecha_lectu;
   rAux->max_fecha_lectu = reg.max_fecha_lectu;
   rAux->fechaAgendaAnterior = reg.fechaAgendaAnterior;

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

