/*********************************************************************************
 *
 *  Modulo: sap_ageing.exe
 *
 *  Fecha: 06/12/2017
 *
 *  Autor: Pablo Privitera
 *
 *  Objetivo: Carga de tabla base para informar a Salesforce
 *
 *  Parametros: base
 *
 ********************************************************************************/

EXEC SQL include "sap_ageing.h";

int  giTipoCliente;
int  giTipoCorrida;

$dtime_t gtInicioCorrida;
$char  sLstParametros[100];
long  lCantLineas;
int   iIndexFile;
int   iNvoArchivo;

void main(int iVargs, char **vVargs)
{
    $Tcliente   RegCliente;
    $Thisfac    RegFactura;
    $TDsaldosImpuestos rSent, rSsal, rFica;
    $TsaldosCnr rSaldosCnrEnt[ MAX_CANT_CNR ], rSaldosCnrSal[ MAX_CANT_CNR ];
    $fpos_t         lStartPoint;
    int resulAmort, cantCnr, i;
    $double totalSujInt=0.0, totalNoSujI=0.0, saldoDG=0.0;
    $double sPositivoSujInt=0.0, sPositivoNoSujI=0.0, dProporcion, sPositivo;
    double dSaldoPlano;
    double  gTotalFacturado;
    time_t      hora;
    long lCantClie;
    int  iRcv;
    
    if (!ValidarParametros(iVargs, vVargs))
        exit(1);

    hora = time(&hora);
    printf("\nHora de comienzo del proceso    : %s\n", ctime(&hora));

    iIndexFile=1;
    if (!IniciaAmbiente())
        exit(1);

   dtcurrent(&gtInicioCorrida);
   
   $BEGIN WORK;
   
   if (!delIndexFile()){
      printf("Error al borrar el indice\n");
      $ROLLBACK WORK;
      exit(1);
   }
   
   $COMMIT WORK;
   
   lCantClie=0;
   lStartPoint=0;
   lCantLineas=0;
   iNvoArchivo=1;
   
    /*EXEC SQL BEGIN WORK;*/
    $OPEN curClientes;
    
    while (FetchClientes(&RegCliente))
    {
    
         /*if(lCantClie!=0){*/
         if(iNvoArchivo==0){
            iRcv = fgetpos(fArchivo, &lStartPoint);
         }else{
            iNvoArchivo=0;
         }

         $BEGIN WORK;
         
         if(!setIndexFile(RegCliente.numeroCliente, lStartPoint, iIndexFile)){
            printf("Error al grabar el indice para cliente %ld\n", RegCliente.numeroCliente);
            $ROLLBACK WORK;
            exit(1);
         }
         
         $COMMIT WORK;
                  

/*fflush(stdout);*/    
         dSaldoPlano = RegCliente.saldoActual+RegCliente.saldoIntAcum+RegCliente.saldoImpNoSujI+RegCliente.saldoImpSujInt-RegCliente.valorAnticipo;
         
/*         
         if(dSaldoPlano > 0){
*/                      
            /*$BEGIN WORK;*/
/* OJO */                  
/* 
printf("\nCliente %ld   CNR [%s]   Saldo %.2lf (%.2lf + %.2lf + %.2lf + %.2lf - %.2lf)\n", 
RegCliente.numeroCliente, RegCliente.tieneCnr, RegCliente.saldoActual+RegCliente.saldoIntAcum+RegCliente.saldoImpNoSujI+RegCliente.saldoImpSujInt-RegCliente.valorAnticipo, RegCliente.saldoActual,RegCliente.saldoIntAcum,RegCliente.saldoImpNoSujI,RegCliente.saldoImpSujInt,RegCliente.valorAnticipo);
fprintf(fArchivo, "\nCliente %ld\n", RegCliente.numeroCliente);
*/
           
           rCli->numeroCliente  = RegCliente.numeroCliente;
   
           rSent.montoPago      = 0;
           rSent.tasa           = Redondear(LeeSaldoTasa(RegCliente.numeroCliente),2);
           rSent.saldoActual    = RegCliente.saldoActual - saldoDG; 
           rSent.saldoIntAcum   = RegCliente.saldoIntAcum;
           rSent.saldoImpNoSujI = RegCliente.saldoImpNoSujI - rSent.tasa;
           rSent.saldoImpSujInt = RegCliente.saldoImpSujInt;
           rSent.valorAnticipo  = RegCliente.valorAnticipo;
           rSent.saldoDG        = saldoDG;
           LlenaArrSaldosImpuestos( &rSent , &totalSujInt , &totalNoSujI );
           CopiaSaldosCli( &rSsal, &rSent );
   
/* OJO */
/*
printf("Ini SA %10.2lf  IAcum %10.2lf  INSI %10.2lf  ISI %10.2lf  DG %10.2lf  T %10.2lf (%s)  TotSI %10.2lf  TotNSI %10.2lf\n", 
rSent.saldoActual, rSent.saldoIntAcum, rSent.saldoImpNoSujI, rSent.saldoImpSujInt, rSent.saldoDG, rSent.tasa, codigoTasa, totalSujInt ,totalNoSujI);
for (i=0; i<rSent.cantSaldosImpuestos; i++)
   printf("   salimp %s  %10.2lf\n", rSent.arrSaldosImpuestos[i].codigoImpuesto, rSent.arrSaldosImpuestos[i].saldo);
*/

          
           if( RegCliente.tieneCnr[0] == 'S' )
           {
           
              if (( resulAmort = CargaDatosCnrParaAmortizacion(
                                     RegCliente.numeroCliente, rSaldosCnrEnt,
                                     rSaldosCnrSal, &cantCnr )) != 0 )
              {
                 MuestraErrorSaldosCnr( RegCliente.numeroCliente, resulAmort );
                 msgErrorPago( ERROR_ABANDONE, 10);
              }

               /*$BEGIN WORK;*/
               if(!MuestraSaldosCnr(RegCliente.numeroCliente, rSaldosCnrSal, cantCnr, "CNR")){
                  printf("1 - aborta para cliente %ld\n", RegCliente.numeroCliente);
                  /*$ROLLBACK WORK;*/
                  exit(1);
               }
               
               /*$COMMIT WORK;*/
               RestaParteCnrACtaCte(&rSent, rSaldosCnrEnt, cantCnr, &rSsal);
               
/* OJO */
/*            
printf("CNR T %10.2lf (%s)  SA %10.2lf  IAcum %10.2lf  INSI %10.2lf  ISI %10.2lf  DG %10.2lf  TotSI %10.2lf  TotNSI %10.2lf\n", 
rSsal.tasa, codigoTasa, rSsal.saldoActual, rSsal.saldoIntAcum, rSsal.saldoImpNoSujI, rSsal.saldoImpSujInt, rSsal.saldoDG, totalSujInt ,totalNoSujI);
for (i=0; i<rSsal.cantSaldosImpuestos; i++)
   printf("   salimp %s  %10.2lf\n", rSsal.arrSaldosImpuestos[i].codigoImpuesto, rSsal.arrSaldosImpuestos[i].saldo);
*/
           }
       
           EXEC SQL OPEN curFacturas
               USING :RegCliente.numeroCliente;
           
           while (FetchFacturas(&RegFactura))
           {
           
/* OJO */
/*
printf("   Factura %d   total %.2lf  sal cli %.2lf Saldo Plano %.2lf\n", RegFactura.corrFacturacion, RegFactura.totalFacturado, rSsal.saldoActual + rSsal.saldoIntAcum + rSsal.saldoImpNoSujI + rSsal.saldoImpSujInt - rSsal.valorAnticipo, dSaldoPlano);
*/
               if (RegFactura.totalFacturado >= (rSsal.saldoActual + rSsal.saldoIntAcum + rSsal.saldoImpNoSujI + rSsal.saldoImpSujInt - rSsal.valorAnticipo))
                   break;
                 
               if(dProporcion == 1)
                  break;
                  
/* OJO */
/*
fprintf(fArchivo, "Corr %d\n", RegFactura.corrFacturacion);
*/

           

/*
               CalcularSPositivo(rSsal.arrSaldosImpuestos, rSsal.cantSaldosImpuestos, &sPositivoSujInt, &sPositivoNoSujI);
               sPositivo = sPositivoSujInt + sPositivoNoSujI;
               sPositivo += (rSsal.saldoActual  > 0) ? rSsal.saldoActual : 0;
               sPositivo += (rSsal.saldoIntAcum > 0) ? rSsal.saldoActual : 0;
*/
               sPositivo = (RegCliente.saldoActual - saldoDG) + RegCliente.saldoIntAcum + (RegCliente.saldoImpNoSujI - rSent.tasa) + RegCliente.saldoImpSujInt;
                 
               /*dProporcion = RegFactura.totalFacturado / sPositivo;*/
               dProporcion = RegFactura.totalFacturado / dSaldoPlano;
               
/* OJO */
/*
printf("   Proporcion %.4lf = RegFactura.totalFacturado %.2lf / sPositivo %.2lf\n", dProporcion, RegFactura.totalFacturado, sPositivo);
*/

               AplicarProporcion(rSsal, dProporcion, &rFica);
               
               /*$BEGIN WORK;*/
               if(!MuestraSaldos(RegFactura.totalFacturado, RegCliente.numeroCliente, RegFactura.fechaVencimiento1 ,RegFactura.corrFacturacion, rFica, codigoTasa, "FAC")){
                  printf("2 - aborta para cliente %ld\n", RegCliente.numeroCliente);
                  /*$ROLLBACK WORK;*/
                  exit(1);
               }
               
               /*$COMMIT WORK;*/
               RestarSaldos(&rSsal, rFica);
               gTotalFacturado=RegFactura.totalFacturado;
               
               
/* OJO */
/*
printf("SA %10.2lf  IAcum %10.2lf  INSI %10.2lf  ISI %10.2lf  DG %10.2lf  T %10.2lf (%s)\n", 
rSsal.saldoActual, rSsal.saldoIntAcum, rSsal.saldoImpNoSujI, rSsal.saldoImpSujInt, rSsal.saldoDG, rSsal.tasa, codigoTasa);
for (i=0; i<rSsal.cantSaldosImpuestos; i++)
   printf("   salimp %s  %10.2lf\n", rSsal.arrSaldosImpuestos[i].codigoImpuesto, rSsal.arrSaldosImpuestos[i].saldo);
*/   
           }
           
           if(dProporcion != 1){
           
              /*$BEGIN WORK;*/
              if(!MuestraSaldos(gTotalFacturado, RegCliente.numeroCliente, 0, 0, rSsal, codigoTasa, "SCL")){
                  printf("3 - aborta para cliente %ld\n", RegCliente.numeroCliente);
                  /*$ROLLBACK WORK;*/
                  exit(1);
              }
              
              /*$COMMIT WORK;*/
           }
           EXEC SQL CLOSE curFacturas;
           /*$COMMIT WORK;*/
/*           
        }
*/        

        lCantClie++;
        
        if(lCantLineas > 60000000){
            fclose(fArchivo);
            iIndexFile++;
            
            /* Abro archivo */
            if(!AbreOtroArchivo()){
               printf("No pudo habrir un nuevo archivo.\nProceso Abortado.\n");
               exit(1);
            }
            lStartPoint=0;
            lCantLineas=0;
            iNvoArchivo=1;
        }
    }

    EXEC SQL CLOSE curClientes;

    $BEGIN WORK;
    
    $EXECUTE insRegiExtra USING :gtInicioCorrida, 
                                 :sLstParametros;

    $COMMIT WORK;
    

    fclose(fArchivo);
    
    /*EXEC SQL COMMIT WORK;*/
    /* OJO fprintf(stderr, "wait ..."); getchar();*/
    /*EXEC SQL ROLLBACK WORK;  OJO */

    hora = time(&hora);
    printf("Hora de finalizacion del proceso: %s\n", ctime(&hora));
    printf("Clientes procesados: %ld\n", lCantClie);

    TerminaAmbiente(0);
}


int ValidarParametros(int iVargs, char **vVargs)
{
    if (iVargs != CANTIDAD_PARAMETROS) {
        fprintf(stderr,"Error en la cantidad de parámetros.\n");
        fprintf(stderr,"Lista de Parámetros:\n");
        fprintf(stderr,"                    Base = synergia \n");
        fprintf(stderr,"                    Tipo Cliente: 0=Activos; 1=Inactivos \n");
        fprintf(stderr,"                    Tipo Corrida: 0=Normal; 1=Reducida \n");
        return (ERROR);
    }

    strcpy(sBaseSynergia, vVargs[1]);
    giTipoCliente = atoi(vVargs[2]);
    giTipoCorrida = atoi(vVargs[3]);

    memset(sLstParametros, '\0', sizeof(sLstParametros));
    sprintf(sLstParametros, "%s %s %s", vVargs[1], vVargs[2], vVargs[3]);
    
    return (OK);
}


int IniciaAmbiente(void)
{
    EXEC SQL CONNECT TO :sBaseSynergia;

    EXEC SQL SET ISOLATION TO COMMITTED READ;
    EXEC SQL SET LOCK MODE TO WAIT 300;
    $SET ISOLATION TO CURSOR STABILITY;
   
    rtoday(&lFechaHoy);

    PreparaQuerys();

    Obtener_ArrayCodca();

    rCli = (Tcliente *)malloc(sizeof(Tcliente));
    if (rCli == NULL) {
       fprintf( stderr, "No se pudo hacer malloc de rCli\n" );
       return (ERROR);
    }
    
    RutaArchivos( sPath, "SAPISU" );
    alltrim(sPath,' ');
    
/*    sprintf(sPath, "/fs/migracion/generacion/SAP/");*/
    if(giTipoCliente==0){
      sprintf(sArchivo, "%ssap_ageing_%d.txt", sPath, iIndexFile);
    }else{
      sprintf(sArchivo, "%ssap_ageing_inactivos_%d.txt", sPath, iIndexFile);
    }
    
    if (!AbreArchivo(sArchivo, &fArchivo, "w"))
        return (ERROR);
    
    return (OK);
}


void TerminaAmbiente(int fg)
{
    if (fg)
        fprintf(stderr, "Programa abortado\n");
    else
        fprintf(stderr, "Finalizacion OK\n");

    exit(fg);
}


int AbreArchivo(char *filename, FILE **arch, char *modo)
{
    if (((*arch)=fopen(filename, modo)) == NULL) {
        fprintf(stderr, "No se pudo abrir el archivo %s\n%s\n", filename, strerror(errno));
        return (ERROR);
    }

    return (OK);
}

short AbreOtroArchivo(){

	  RutaArchivos( sPath, "SAPISU" );
	  alltrim(sPath,' ');

    /*sprintf(sPath, "/fs/migracion/generacion/SAP/");*/
    if(giTipoCliente==0){
      sprintf(sArchivo, "%ssap_ageing_%d.txt", sPath, iIndexFile);
    }else{
      sprintf(sArchivo, "%ssap_ageing_inactivos_%d.txt", sPath, iIndexFile);
    }
    
    if (!AbreArchivo(sArchivo, &fArchivo, "w"))
        return (ERROR);
    
    return (OK);
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


void PreparaQuerys (void)
{
   $char  sql[10000];
   memset(sql, '\0', sizeof(sql));
   
   strcpy(sql, "SELECT c.numero_cliente, ");
   strcat(sql, "c.corr_facturacion, "); 
   strcat(sql, "c.tiene_cnr, ");
   strcat(sql, "c.saldo_actual, ");
   strcat(sql, "c.saldo_int_acum, ");
   strcat(sql, "c.saldo_imp_no_suj_i, ");
   strcat(sql, "c.saldo_imp_suj_int, ");
   strcat(sql, "c.valor_anticipo ");
   strcat(sql, "FROM cliente c ");
   
if(giTipoCorrida==1){   
   strcat(sql, ", migra_activos ma ");
}
   
   if(giTipoCliente==0){
      strcat(sql, "WHERE c.estado_cliente = '0' ");
   }else{
      strcat(sql, ", sap_inactivos si ");
      strcat(sql, "WHERE c.estado_cliente != '0' ");
      strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
      strcat(sql, "AND si.saldo != 0.00 ");
   }

strcat(sql, "AND c.numero_cliente != 3146450 ");

   strcat(sql, "AND c.tipo_sum != 5 ");
	/*strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");*/
	/*strcat(sql, "AND c.sector != 88 ");*/
   strcat(sql, "AND (c.saldo_actual + c.saldo_int_acum + c.saldo_imp_no_suj_i + c.saldo_imp_suj_int - c.valor_anticipo) > 0 ");

	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	
if(giTipoCorrida==1){      
   strcat(sql, "and ma.numero_cliente = c.numero_cliente "); 
}  

   strcat(sql, "ORDER BY 1 ASC ");
   
   $PREPARE selClientes FROM $sql;
   $DECLARE curClientes CURSOR WITH HOLD FOR selClientes;				
   

    EXEC SQL PREPARE selFacturas FROM
        "SELECT h.corr_facturacion, h.fecha_vencimiento1, NVL(h.total_facturado, 0) + NVL(h.suma_convenio, 0) - NVL(t.tasa_facturada, 0)
           FROM hisfac h, OUTER hisfac_tasa t
          WHERE h.numero_cliente   = ?
            AND h.fecha_facturacion IS NOT NULL
            AND h.numero_cliente   = t.numero_cliente
            AND h.corr_facturacion = t.corr_facturacion
          ORDER BY h.corr_facturacion DESC";

    EXEC SQL DECLARE curFacturas CURSOR WITH HOLD FOR selFacturas;
    
    
   $PREPARE insAgeing FROM 
      "INSERT INTO sap_ageing ( 
      numero_cliente,
      tipo_saldo,
      corr_facturacion,
      fecha_vencimiento1,
      cod_cargo,
      valor_cargo
      )VALUES(?, ?, ?, ?, ?, ?)";
/*
   $PREPARE insAgeing FROM 
      "INSERT INTO sap_ageingaux ( 
      numero_cliente,
      tipo_saldo,
      corr_facturacion,
      fecha_vencimiento1,
      cod_cargo,
      valor_cargo
      )VALUES(?, ?, ?, ?, ?, ?)";
*/
   $PREPARE insRegiExtra FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'AGEING', ?, CURRENT, ?)";
      

   $PREPARE delIndexAgeActi FROM "DELETE FROM sap_inx_age WHERE estado_cliente = 0 ";
   
   $PREPARE delIndexAgeInActi FROM "DELETE FROM sap_inx_age WHERE estado_cliente = 1 ";
   
   $PREPARE insIndexAge FROM "INSERT INTO sap_inx_age (numero_cliente, start_point, estado_cliente, index_file
         )VALUES( ?, ?, ?, ?) ";


	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;
          
}


int FetchClientes(ptCliente)
EXEC SQL BEGIN DECLARE SECTION;
    PARAMETER Tcliente *ptCliente;
EXEC SQL END DECLARE SECTION;
{
    EXEC SQL FETCH curClientes
      INTO  :ptCliente->numeroCliente,
            :ptCliente->corrFacturacion,
            :ptCliente->tieneCnr,
            :ptCliente->saldoActual,
            :ptCliente->saldoIntAcum,
            :ptCliente->saldoImpNoSujI,
            :ptCliente->saldoImpSujInt,
            :ptCliente->valorAnticipo;

    if (SQLCODE == SQLNOTFOUND)
        return (ERROR);

    alltrim(ptCliente->tieneCnr, ' ');

    return (OK);
}


int FetchFacturas(ptFactura)
EXEC SQL BEGIN DECLARE SECTION;
    PARAMETER Thisfac *ptFactura;
EXEC SQL END DECLARE SECTION;
{

    EXEC SQL FETCH curFacturas
      INTO  :ptFactura->corrFacturacion,
            :ptFactura->fechaVencimiento1,
            :ptFactura->totalFacturado;

    if (SQLCODE == SQLNOTFOUND)
        return (ERROR);

    return (OK);
}


short MuestraSaldos(dTotal, nroCliente, lFecha, correlativo, rSaldos, sCodTasa, sTipo)
double   dTotal;
$long nroCliente; 
$long lFecha; 
$long correlativo; 
$TDsaldosImpuestos rSaldos; 
$char * sCodTasa; 
$char *sTipo;
{
    int i;
    $char sCodigo[4];
    char sLinea[1000];
    int  iRcv;

    memset(sCodigo, '\0', sizeof(sCodigo));
    
    if(strcmp(sTipo, "SCL")==0){
      correlativo=0;
      lFecha=0;
    }
/*    
    if(dTotal < 0 && (strcmp(sTipo, "SCL")!=0)){
      rSaldos.saldoActual=rSaldos.saldoActual *(-1);
      rSaldos.saldoIntAcum=rSaldos.saldoIntAcum *(-1);
      rSaldos.saldoImpNoSujI=rSaldos.saldoImpNoSujI *(-1);
      rSaldos.saldoImpSujInt=rSaldos.saldoImpSujInt *(-1);
      rSaldos.tasa=rSaldos.tasa *(-1);
      rSaldos.valorAnticipo=rSaldos.valorAnticipo *(-1);
    }
*/    

   /*SqlErrorSetIgnoreI(-1226);*/
   
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.saldoActual)){
       strcpy(sCodigo, "SA6"); /* Saldo Actual*/
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.saldoActual;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.saldoActual);
         return 0;    
       }                         
                                
       if(SQLCODE != 0 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/
       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, correlativo, lFecha, sCodigo, rSaldos.saldoActual);
       iRcv = fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;
                                       
   }
   
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.saldoIntAcum)){
       strcpy(sCodigo, "SA7"); /* Int.Acumulados */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.saldoIntAcum;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.saldoIntAcum);
         return 0;    
       }                         
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/
       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, correlativo, lFecha, sCodigo, rSaldos.saldoIntAcum);
       iRcv = fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;                         
   }
   
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.saldoImpNoSujI)){
       strcpy(sCodigo, "SA8"); /* Impuestos NO sujetos a Int. */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.saldoImpNoSujI;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.saldoImpNoSujI);
         return 0;    
       }                         
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/                                
   }
   
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.saldoImpSujInt)){
       strcpy(sCodigo, "SA9"); /* Impuestos sujetos a Int. */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.saldoImpSujInt;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.saldoImpSujInt);
         return 0;    
       }                         
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/                                
   }
   
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.tasa)){
       if(rSaldos.tasa != 0){
          strcpy(sCodigo, sCodTasa); /* Tasa */
/*          
          $EXECUTE insAgeing USING :nroCliente,
                                   :sTipo,
                                   :correlativo,
                                   :lFecha,
                                   :sCodigo,
                                   :rSaldos.tasa;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.tasa);
         return 0;    
       }                         
                                   
          if(SQLCODE != 0){
            printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
            return 0;    
          }                         
       
*/
          memset(sLinea, '\0', sizeof(sLinea));
          sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, correlativo, lFecha, sCodigo, rSaldos.tasa);
          iRcv = fprintf(fArchivo, sLinea);
          if(iRcv < 0){
            printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
            exit(1);
          }
          lCantLineas++;
        }
    }
    
    if(!risnull(CDOUBLETYPE, (char *) &rSaldos.valorAnticipo)){
       strcpy(sCodigo, "SA3"); /* Anticipo */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.valorAnticipo;

       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.valorAnticipo);
         return 0;    
       }                         
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/
       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, correlativo, lFecha, sCodigo, rSaldos.valorAnticipo);
       iRcv = fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;
                                
   }
    /****************/
/*    
    fprintf(fArchivo, "SA|%2lf\nIAcum|%2lf\nINSI|%2lf\nISI|%2lf\nDG|%2lf\nT|%2lf\nAntic|%2lf\n",  
        rSaldos.saldoActual, rSaldos.saldoIntAcum, rSaldos.saldoImpNoSujI, rSaldos.saldoImpSujInt, rSaldos.saldoDG, rSaldos.tasa, rSaldos.valorAnticipo);
*/
    for (i=0; i<rSaldos.cantSaldosImpuestos; i++){
/*    
         if(dTotal < 0 && (strcmp(sTipo, "SCL")!=0)){
            rSaldos.arrSaldosImpuestos[i].saldo = rSaldos.arrSaldosImpuestos[i].saldo * (-1);
         }
*/         
   if(!risnull(CDOUBLETYPE, (char *) &rSaldos.arrSaldosImpuestos[i].saldo)){
       strcpy(sCodigo, rSaldos.arrSaldosImpuestos[i].codigoImpuesto);
/*        
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.arrSaldosImpuestos[i].saldo;
       if(SQLCODE == -1226 ){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s [%lf]\n", nroCliente, sCodigo, rSaldos.arrSaldosImpuestos[i].saldo);
         return 0;    
       }                         
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }
*/

       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, correlativo, lFecha, sCodigo, rSaldos.arrSaldosImpuestos[i].saldo);
       iRcv = fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;                             
   }
   
   SqlErrorClearIgnore();
/*    
fprintf(fArchivo, "%s|%2lf\n", rSaldos.arrSaldosImpuestos[i].codigoImpuesto, rSaldos.arrSaldosImpuestos[i].saldo);
*/
   }
   
   return 1;
}


short MuestraSaldosCnr(nroCliente, rSaldosCnr, cantidad, sTipo)
$long nroCliente; 
$TsaldosCnr *rSaldosCnr; 
int cantidad; 
$char *sTipo;
{
   int i, j;
   $char sCodigo[4];
   char  sLinea[1000];
   int   iRcv;
    
    memset(sCodigo, '\0', sizeof(sCodigo));
   
   memset(sLinea, '\0', sizeof(sLinea));
   
   for(i=0; i < cantidad; i++)
   {
       strcpy(sCodigo, "SA4"); /* Saldo Actual */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :rSaldosCnr[i].corrFacturacion,
                                :rSaldosCnr[i].fechaVencimiento,
                                :sCodigo,
                                :rSaldosCnr[i].saldoActual;
   
       if(SQLCODE != 0){
         printf("Error al insertar AGEING CNR cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         
*/   
       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, rSaldosCnr[i].corrFacturacion, rSaldosCnr[i].fechaVencimiento, sCodigo, rSaldosCnr[i].saldoActual);
       iRcv=fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;
       strcpy(sCodigo, "SA5"); /* Int.Acumulados */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :rSaldosCnr[i].corrFacturacion,
                                :rSaldosCnr[i].fechaVencimiento,
                                :sCodigo,
                                :rSaldosCnr[i].saldoIntAcum;
   
       if(SQLCODE != 0){
         printf("Error al insertar AGEING CNR cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         
*/
       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, rSaldosCnr[i].corrFacturacion, rSaldosCnr[i].fechaVencimiento, sCodigo, rSaldosCnr[i].saldoIntAcum);
       iRcv = fprintf(fArchivo, sLinea);
       if(iRcv < 0){
         printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
         exit(1);
       }
       lCantLineas++;

       strcpy(sCodigo, "SA8"); /* Impuestos No Suj.Intereses */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :rSaldosCnr[i].corrFacturacion,
                                :rSaldosCnr[i].fechaVencimiento,
                                :sCodigo,
                                :rSaldosCnr[i].saldoIntAcum;
   
       if(SQLCODE != 0){
         printf("Error al insertar AGEING CNR cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         


       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, rSaldosCnr[i].corrFacturacion, rSaldosCnr[i].fechaVencimiento, sCodigo, rSaldosCnr[i].saldoIntAcum);
       fprintf(fArchivo, sLinea);
*/
       strcpy(sCodigo, "SA9"); /* Impuestos Suj.Intereses */
/*       
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :rSaldosCnr[i].corrFacturacion,
                                :rSaldosCnr[i].fechaVencimiento,
                                :sCodigo,
                                :rSaldosCnr[i].saldoIntAcum;
   
       if(SQLCODE != 0){
         printf("Error al insertar AGEING CNR cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         

       memset(sLinea, '\0', sizeof(sLinea));
       sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, rSaldosCnr[i].corrFacturacion, rSaldosCnr[i].fechaVencimiento, sCodigo, rSaldosCnr[i].saldoIntAcum);
       fprintf(fArchivo, sLinea);
*/

/*   
printf("%d  %ld  %s  %d  %ld %ld  %.2lf  %.2lf  %.2lf  %.2lf\n",
rSaldosCnr[i].anoExpediente,
rSaldosCnr[i].nroExpediente,
rSaldosCnr[i].sucursal,
rSaldosCnr[i].corrFacturacion,
rSaldosCnr[i].fechaEmision,
rSaldosCnr[i].fechaVencimiento,
rSaldosCnr[i].saldoActual,
rSaldosCnr[i].saldoIntAcum,
rSaldosCnr[i].saldoImpSujInt,
rSaldosCnr[i].saldoImpNoSujI);
*/
      
      for(j=0; j < rSaldosCnr[i].cantSaldosImpCnr; j++) /*impuestos*/
      {
          strcpy(sCodigo, rSaldosCnr[i].arrSaldosImpCnr[j].codigoImpuesto);
/* 
          $EXECUTE insAgeing USING :nroCliente,
                                   :sTipo,
                                   :rSaldosCnr[i].corrFacturacion,
                                   :rSaldosCnr[i].fechaVencimiento,
                                   :sCodigo,
                                   :rSaldosCnr[i].arrSaldosImpCnr[j].valor;
                                   
          if(SQLCODE != 0){
            printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
            return 0;    
          }                         
*/

          memset(sLinea, '\0', sizeof(sLinea));
          sprintf(sLinea, "%ld|%s|%d|%ld|%s|%.02f|\n", nroCliente, sTipo, rSaldosCnr[i].corrFacturacion, rSaldosCnr[i].fechaVencimiento, sCodigo, rSaldosCnr[i].arrSaldosImpCnr[j].valor);
          iRcv = fprintf(fArchivo, sLinea);
          if(iRcv < 0){
            printf("Error al grabar archivo cliente %ld\n %s\n", nroCliente, sLinea);
            exit(1);
          }
          lCantLineas++;
      
/*      
printf("  %s  %.2lf\n",
rSaldosCnr[i].arrSaldosImpCnr[j].codigoImpuesto,
rSaldosCnr[i].arrSaldosImpCnr[j].valor);
*/
      }
   }
   
   
   return 1;
}


void AplicarProporcion(TDsaldosImpuestos origen, double dProp, TDsaldosImpuestos *destino)
{
   int i;
   
   

   destino->saldoActual    = (origen.saldoActual    > 0) ? Redondear(origen.saldoActual   , 2) * dProp : 0;
   
   destino->saldoIntAcum   = (origen.saldoIntAcum   > 0) ? Redondear(origen.saldoIntAcum  , 2) * dProp : 0;
   
   destino->saldoImpSujInt = (origen.saldoImpSujInt > 0) ? Redondear(origen.saldoImpSujInt, 2) * dProp : 0;
   
   destino->saldoImpNoSujI = (origen.saldoImpNoSujI > 0) ? Redondear(origen.saldoImpNoSujI, 2) * dProp : 0;
   
                                                           
   destino->saldoDG        = (origen.saldoDG        > 0) ? Redondear(origen.saldoDG       , 2)  * dProp : 0;
   
   destino->valorAnticipo  = (origen.valorAnticipo  > 0) ? Redondear(origen.valorAnticipo , 2)  * dProp : 0;
                                                           
   destino->tasa           = (origen.tasa           > 0) ? Redondear(origen.tasa          , 2)  * dProp : 0;
   
/* OJO */
/*
printf("     aplica prop SA %10.2lf  IAcum %10.2lf  INSI %10.2lf  ISI %10.2lf  DG %10.2lf  T %10.2lf  antic %10.2lf\n", 
destino->saldoActual, destino->saldoIntAcum, destino->saldoImpNoSujI, destino->saldoImpSujInt, destino->saldoDG, destino->tasa, destino->valorAnticipo);
*/
   destino->cantSaldosImpuestos = origen.cantSaldosImpuestos;
   for (i=0; i<origen.cantSaldosImpuestos; i++)
   {
      
      strcpy(destino->arrSaldosImpuestos[i].codigoImpuesto, origen.arrSaldosImpuestos[i].codigoImpuesto);
      
      if(risnull(CDOUBLETYPE, (char *) &origen.arrSaldosImpuestos[i].saldo))
         origen.arrSaldosImpuestos[i].saldo=0;
         
      destino->arrSaldosImpuestos[i].saldo = (origen.arrSaldosImpuestos[i].saldo > 0) ? Redondear(origen.arrSaldosImpuestos[i].saldo * dProp, 2) : 0;
      
/* OJO */
/*
printf("     imp %s  %10.2lf\n", destino->arrSaldosImpuestos[i].codigoImpuesto, destino->arrSaldosImpuestos[i].saldo);
*/
   }
   
   
}


void RestarSaldos(TDsaldosImpuestos *destino, TDsaldosImpuestos origen)
{
   int i;
   
   if(risnull(CDOUBLETYPE, (char *) &origen.saldoActual))
      origen.saldoActual=0;  
   destino->saldoActual    = Redondear(destino->saldoActual    - origen.saldoActual, 2);
   

   if(risnull(CDOUBLETYPE, (char *) &origen.saldoIntAcum))
      origen.saldoIntAcum=0;  
   destino->saldoIntAcum   = Redondear(destino->saldoIntAcum   - origen.saldoIntAcum, 2);
   

   if(risnull(CDOUBLETYPE, (char *) &origen.saldoImpSujInt))
      origen.saldoImpSujInt=0;  
   destino->saldoImpSujInt = Redondear(destino->saldoImpSujInt - origen.saldoImpSujInt, 2);

   if(risnull(CDOUBLETYPE, (char *) &origen.saldoImpNoSujI))
      origen.saldoImpNoSujI=0;  
   destino->saldoImpNoSujI = Redondear(destino->saldoImpNoSujI - origen.saldoImpNoSujI, 2);

   if(risnull(CDOUBLETYPE, (char *) &origen.saldoDG))
      origen.saldoDG=0;  
   destino->saldoDG        = Redondear(destino->saldoDG        - origen.saldoDG, 2);

   if(risnull(CDOUBLETYPE, (char *) &origen.valorAnticipo))
      origen.valorAnticipo=0;  
   destino->valorAnticipo  = Redondear(destino->valorAnticipo  - origen.valorAnticipo, 2);
   
   if(risnull(CDOUBLETYPE, (char *) &origen.tasa))
      origen.tasa=0;  
   destino->tasa           = Redondear(destino->tasa           - origen.tasa, 2);

   if(risnull(CDOUBLETYPE, (char *) &origen.cantSaldosImpuestos))
      origen.cantSaldosImpuestos=0;  
   destino->cantSaldosImpuestos = origen.cantSaldosImpuestos;
   
   for (i=0; i<origen.cantSaldosImpuestos; i++)
   {
   
      strcpy(destino->arrSaldosImpuestos[i].codigoImpuesto, origen.arrSaldosImpuestos[i].codigoImpuesto);
      
      destino->arrSaldosImpuestos[i].saldo = Redondear(destino->arrSaldosImpuestos[i].saldo - origen.arrSaldosImpuestos[i].saldo, 2);
      
   }
}

short delIndexFile()
{

   if(giTipoCliente==0){
      $EXECUTE delIndexAgeActi;
   }else{
      $EXECUTE delIndexAgeInActi;   
   }
   
   if(SQLCODE != 0)
      return 0;

   return 1;
}

short setIndexFile(lNroCliente, lPos, iFile)
$long    lNroCliente;
$fpos_t  lPos;
$int     iFile;
{
   $long lMiPos=lPos;
   $int  iEstadoCliente;
   
   if(giTipoCliente==0){
      iEstadoCliente=0;
   }else{
      iEstadoCliente=1;   
   }
   
   $EXECUTE insIndexAge USING :lNroCliente, :lMiPos, :iEstadoCliente, :iFile;
   
   if(SQLCODE != 0)
      return 0;
      
   return 1;
}
