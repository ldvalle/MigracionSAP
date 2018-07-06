/*********************************************************************************
 *
 *  Modulo: ageing.exe
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

EXEC SQL include "ageing.h";

int  giTipoCliente;
char   giTipoCorrida[2];

void main(int iVargs, char **vVargs)
{
    $Tcliente   RegCliente;
    $Thisfac    RegFactura;
    $TDsaldosImpuestos rSent, rSsal, rFica;
    $TsaldosCnr rSaldosCnrEnt[ MAX_CANT_CNR ], rSaldosCnrSal[ MAX_CANT_CNR ];
    int resulAmort, cantCnr, i;
    $double totalSujInt=0.0, totalNoSujI=0.0, saldoDG=0.0;
    $double sPositivoSujInt=0.0, sPositivoNoSujI=0.0, dProporcion, sPositivo;
    double dSaldoPlano;
    double  gTotalFacturado;
    time_t      hora;

    if (!ValidarParametros(iVargs, vVargs))
        exit(1);

    hora = time(&hora);
    printf("\nHora de comienzo del proceso    : %s\n", ctime(&hora));

    if (!IniciaAmbiente())
        exit(1);

    /*EXEC SQL BEGIN WORK;*/
    $OPEN curClientes;
    
    while (FetchClientes(&RegCliente))
    {
         dSaldoPlano = RegCliente.saldoActual+RegCliente.saldoIntAcum+RegCliente.saldoImpNoSujI+RegCliente.saldoImpSujInt-RegCliente.valorAnticipo;
         
         if(dSaldoPlano > 0){
                      
            $BEGIN WORK;
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
               if(!MuestraSaldosCnr(RegCliente.numeroCliente, rSaldosCnrSal, cantCnr, "CNR")){
                  $ROLLBACK WORK;
                  exit(1);
               }
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

               if(!MuestraSaldos(RegFactura.totalFacturado, RegCliente.numeroCliente, RegFactura.fechaVencimiento1 ,RegFactura.corrFacturacion, rFica, codigoTasa, "FAC")){
               
                  $ROLLBACK WORK;
                  exit(1);
               }
              
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
              if(!MuestraSaldos(gTotalFacturado, RegCliente.numeroCliente, 0, 0, rSsal, codigoTasa, "SCL")){
                  $ROLLBACK WORK;
                  exit(1);
              }
           }
           EXEC SQL CLOSE curFacturas;
           $COMMIT WORK;
        }
    }

    EXEC SQL CLOSE curClientes;

    /*fclose(fArchivo);*/
    
    /*EXEC SQL COMMIT WORK;*/
    /* OJO fprintf(stderr, "wait ..."); getchar();*/
    /*EXEC SQL ROLLBACK WORK;  OJO */

    hora = time(&hora);
    printf("Hora de finalizacion del proceso: %s\n", ctime(&hora));

    TerminaAmbiente(0);
}


int ValidarParametros(int iVargs, char **vVargs)
{
    if (iVargs != CANTIDAD_PARAMETROS) {
        fprintf(stderr,"Error en la cantidad de parámetros.\n");
        fprintf(stderr,"Lista de Parámetros:\n");
        fprintf(stderr,"                    Base = synergia \n");
        fprintf(stderr,"                    Tipo Cliente: 0=Activos; 1=Inactivos \n");
        fprintf(stderr,"                    Tipo Corrida: G=Generacion; R=Regeneracion  \n");
        return (ERROR);
    }

    strcpy(sBaseSynergia, vVargs[1]);
    giTipoCliente = atoi(vVargs[2]);
    strcpy(giTipoCorrida, vVargs[3]); 


    return (OK);
}


int IniciaAmbiente(void)
{
    EXEC SQL CONNECT TO :sBaseSynergia;

    EXEC SQL SET ISOLATION TO COMMITTED READ;
    EXEC SQL SET LOCK MODE TO WAIT 300;

    rtoday(&lFechaHoy);

    PreparaQuerys();

    Obtener_ArrayCodca();

    rCli = (Tcliente *)malloc(sizeof(Tcliente));
    if (rCli == NULL) {
       fprintf( stderr, "No se pudo hacer malloc de rCli\n" );
       return (ERROR);
    }
/*    
    sprintf(sPath, "/tmp/ldvalle/SAP/");
    sprintf(sArchivo, "%sageing.txt", sPath);
    if (!AbreArchivo(sArchivo, &fArchivo, "w"))
        return (ERROR);
*/    
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
/*   
strcat(sql, ", migra_activos ma ");
*/   
   if(giTipoCliente==0){
      strcat(sql, "WHERE c.estado_cliente = '0' ");
   }else{
      strcat(sql, "WHERE c.estado_cliente != '0' ");
   }

   strcat(sql, "AND c.tipo_sum != 5 ");
	/*strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");*/
	/*strcat(sql, "AND c.sector != 88 ");*/
   strcat(sql, "AND (c.saldo_actual + c.saldo_int_acum + c.saldo_imp_no_suj_i + c.saldo_imp_suj_int - c.valor_anticipo) > 0 ");

	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	
/*      
strcat(sql, "and ma.numero_cliente = c.numero_cliente "); 
*/   
   $PREPARE selClientes FROM $sql;
   $DECLARE curClientes CURSOR WITH HOLD FOR selClientes;				

   

    EXEC SQL PREPARE selFacturas FROM
        "SELECT h.corr_facturacion, h.fecha_vencimiento1, h.total_facturado + h.suma_convenio - t.tasa_facturada
           FROM hisfac h, hisfac_tasa t
          WHERE h.numero_cliente   = ?
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
    strcpy(sCodigo, "SA6"); /* Saldo Actual*/
    $EXECUTE insAgeing USING :nroCliente,
                             :sTipo,
                             :correlativo,
                             :lFecha,
                             :sCodigo,
                             :rSaldos.saldoActual;
                             
    if(SQLCODE != 0){
      printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
      return 0;    
    }                         

    strcpy(sCodigo, "SA7"); /* Int.Acumulados */
    $EXECUTE insAgeing USING :nroCliente,
                             :sTipo,
                             :correlativo,
                             :lFecha,
                             :sCodigo,
                             :rSaldos.saldoIntAcum;
                             
    if(SQLCODE != 0){
      printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
      return 0;    
    }                         

    strcpy(sCodigo, "SA8"); /* Impuestos NO sujetos a Int. */
    $EXECUTE insAgeing USING :nroCliente,
                             :sTipo,
                             :correlativo,
                             :lFecha,
                             :sCodigo,
                             :rSaldos.saldoImpNoSujI;
                             
    if(SQLCODE != 0){
      printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
      return 0;    
    }                         

    strcpy(sCodigo, "SA9"); /* Impuestos sujetos a Int. */
    $EXECUTE insAgeing USING :nroCliente,
                             :sTipo,
                             :correlativo,
                             :lFecha,
                             :sCodigo,
                             :rSaldos.saldoImpSujInt;
                             
    if(SQLCODE != 0){
      printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
      return 0;    
    }                         

    if(rSaldos.tasa != 0){
       strcpy(sCodigo, sCodTasa); /* Tasa */
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.tasa;
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         
    }
    
    strcpy(sCodigo, "SA3"); /* Anticipo */
    $EXECUTE insAgeing USING :nroCliente,
                             :sTipo,
                             :correlativo,
                             :lFecha,
                             :sCodigo,
                             :rSaldos.valorAnticipo;
                             
    if(SQLCODE != 0){
      printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
      return 0;    
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
       strcpy(sCodigo, rSaldos.arrSaldosImpuestos[i].codigoImpuesto); 
       $EXECUTE insAgeing USING :nroCliente,
                                :sTipo,
                                :correlativo,
                                :lFecha,
                                :sCodigo,
                                :rSaldos.arrSaldosImpuestos[i].saldo;
                                
       if(SQLCODE != 0){
         printf("Error al insertar AGEING cliente %ld cod.concepto %s\n", nroCliente, sCodigo);
         return 0;    
       }                         

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
    
    memset(sCodigo, '\0', sizeof(sCodigo));
   
   for(i=0; i < cantidad; i++)
   {
       strcpy(sCodigo, "SA4"); /* Saldo Actual */
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
   
       strcpy(sCodigo, "SA5"); /* Int.Acumulados */
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

       strcpy(sCodigo, "SA8"); /* Impuestos No Suj.Intereses */
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

       strcpy(sCodigo, "SA9"); /* Impuestos Suj.Intereses */
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
   
   destino->saldoActual    = Redondear(destino->saldoActual    - origen.saldoActual, 2);
   destino->saldoIntAcum   = Redondear(destino->saldoIntAcum   - origen.saldoIntAcum, 2);
   destino->saldoImpSujInt = Redondear(destino->saldoImpSujInt - origen.saldoImpSujInt, 2);
   destino->saldoImpNoSujI = Redondear(destino->saldoImpNoSujI - origen.saldoImpNoSujI, 2);
                             
   destino->saldoDG        = Redondear(destino->saldoDG        - origen.saldoDG, 2);
   destino->valorAnticipo  = Redondear(destino->valorAnticipo  - origen.valorAnticipo, 2);
                             
   destino->tasa           = Redondear(destino->tasa           - origen.tasa, 2);
   
   destino->cantSaldosImpuestos = origen.cantSaldosImpuestos;
   for (i=0; i<origen.cantSaldosImpuestos; i++)
   {
      strcpy(destino->arrSaldosImpuestos[i].codigoImpuesto, origen.arrSaldosImpuestos[i].codigoImpuesto);
      destino->arrSaldosImpuestos[i].saldo = Redondear(destino->arrSaldosImpuestos[i].saldo - origen.arrSaldosImpuestos[i].saldo, 2);
   }
}
