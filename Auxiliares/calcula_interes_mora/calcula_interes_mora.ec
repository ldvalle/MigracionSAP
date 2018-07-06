/*********************************************************************************
 *
 *  Modulo: calcula_interes_mora.exe
 *
 *  Fecha: 06/2015
 *
 *  Autor: Pablo D. Privitera
 *
 *  Objetivo: Recalcula Intereses por Mora simulando estar parado en una fecha de facturacion determinada
 *            El calculo se le realiza a los clientes cargados previamente en la tabla HISFAC_CONT_TEMP
 *            Se imprime por pantalla el cliente, corr_facturacion e importe recalculado
 *            en /tmp queda el detalle de como se hizo el calculo en el archivo
 *            int_mora_dd_mm_yyyy_yyyymmdd_hhMM.txt
 *            dd_mm_yyyy    es la fecha de facturacion
 *            yyyymmdd_hhMM es la fecha y hora de ejecucion del proceso
 *
 *  Parametros: base
 *              fecha_facturacion
 *
 ********************************************************************************/

EXEC SQL include calcula_interes_mora.h;
$char    sCentroOp[5];

void main(int iVargs, char **vVargs)
{
    time_t          hora;
    $ThisfacCont    regHisfacCont;
    $Tcliente       cliente;
    $Thisfac        regHisfac;
    $TdatosGen      datosGen;
    TconcCalc       concepto;
    Trefac          arrayNotas[CANT_MAX_NOTAS_PERIODO_DE_CLIENTE];
    int             cantNotas;
    double          totalNCPeriodo = 0.0;
    double          totalNCAnterior = 0.0;
    double          totalNDPeriodo = 0.0;
    double          totalNDPeriodoSujYNoSuj = 0.0;
    double          totalNCPeriodoSujYNoSuj = 0.0;
    double          montoIntMora = 0.0;
    long            lHoy;
    int             i, iCalculoInt;
    long             cantProcesada; 
   
   memset(sSucursal, '\0', sizeof(sSucursal)); 
    
    if (!ValidarParametros(iVargs, vVargs))
        exit(1);
   
    hora = time(&hora);
    
    EXEC SQL CONNECT TO :sBaseSynergia;

    EXEC SQL SET ISOLATION TO DIRTY READ;
    $SET ISOLATION TO CURSOR STABILITY;



    if (!IniciaAmbiente())
        exit(1);

        
/*
    hora = time(&hora);
    printf("\nHora antes de cargar datos generales: %s\n", ctime(&hora));
*/
    rtoday(&lHoy);
    lFechaFacturacion=lHoy;
    CargarPrecaEnMemoria(35581, lHoy + 1000);
    
    AlmacenarRangoClientes(0, MAXLONG);
    
    RecuperarDatosGen(&datosGen, lFechaFacturacion);
    
/*
    hora = time(&hora);
    printf("\nHora antes de procesar datos: %s\n", ctime(&hora));
*/

    EXEC SQL OPEN curHisfacContTemp
            USING :sCentroOp;

    /*printf("Cliente|Corr Fact|Interes Recalculado|\n");*/
    cantProcesada=0;
    while (FetchHisfacContTemp(&regHisfacCont, &cliente, &regHisfac))
    {
    
        montoIntMora = 0.0;
        totalNCAnterior = 0.0;
        totalNCPeriodo = 0.0;
        totalNDPeriodo = 0.0;
        totalNDPeriodoSujYNoSuj = 0.0;
        totalNCPeriodoSujYNoSuj = 0.0;
        cantNotas = 0;
        BorrarConcCalc();

        strcpy(datosGen.sucursal, cliente.sucursal);
        datosGen.sector   = cliente.sector;
        cliente.fechaUltimaFact = regHisfac.fechaFacturacion;
        strcpy(cliente.tarifa, regHisfacCont.tarifa);
        /*rsetnull(CLONGTYPE, (char*) &regHisfacCont.coFechaCaducado);*/
        regHisfacCont.coFechaCaducado = lFechaFacturacion;
/*
        printf("%ld|%d|", regHisfacCont.numeroCliente, regHisfacCont.corrFacturacion);
*/        
        FacturadorTotalNotasCreditoDebitoDelPeriodo(
                                                 &totalNCAnterior,
                                                 &totalNCPeriodo,
                                                 &totalNDPeriodo,
                                                 &totalNDPeriodoSujYNoSuj,
                                                 &totalNCPeriodoSujYNoSuj,
                                                 arrayNotas,
                                                 &cantNotas,
                                                 cliente,
                                                 &regHisfacCont);

        CalcularIntereses(cliente,
                          totalNCAnterior,
                          totalNCPeriodo,
                          regHisfac,
                          montoIntMora,
                          regHisfacCont.coFechaCaducado,
                          arrayNotas,
                          cantNotas,
                          lFechaFacturacion);

    	iCalculoInt = 0;
    	for (i = 0; i < CantidadConcCalc(); i++)
    	{
    		concepto = RecuperarConcCalc(i);
    		if (!strcmp(concepto.codigoCargo, COD_CARGO_INT_MORA)) {
                iCalculoInt = 1;
                /*
                printf("%.2lf|", concepto.valorCalculado);
                */
            }

    	}
      
      if(!iCalculoInt)
         concepto.valorCalculado=0.0;
         
      $BEGIN WORK;
      if(!GrabaInteres(regHisfacCont.numeroCliente, regHisfacCont.corrFacturacion, concepto.valorCalculado)){
         $ROLLBACK WORK;
         printf("Error al registrar interes para cliente %ld.\n", regHisfacCont.numeroCliente);
      }
      $COMMIT WORK;
      cantProcesada++;
      
      /*
    	if (!iCalculoInt)
    	    printf("0|");
    	    
        printf("\n");
      */        
    }

    EXEC SQL CLOSE curHisfacContTemp;

/*
    hora = time(&hora);
    printf("\nHora de fin: %s\n", ctime(&hora));
*/
    TerminaAmbiente(0);
    
	printf("==============================================\n");
	printf("CALCULA INTERESES MORA\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
   printf("Sucursal Procesada  :       %s\n", sCentroOp);
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	
    
}


int ValidarParametros(int iVargs, char **vVargs)
{
    if (iVargs != CANTIDAD_PARAMETROS) {
        fprintf(stderr, "\nERROR en los parámetros\n\n");
        fprintf(stderr, "Parámetros: base \n");
        fprintf(stderr, "            sucursal\n");
        return (ERROR);
    }

    strcpy(sBaseSynergia, vVargs[1]);
    strcpy(sSucursal, vVargs[2]);
    strcpy(sCentroOp, vVargs[2]);
    
    return (OK);
}


int IniciaAmbiente(void)
{
    char nomArchivo[90], sFechaFacturacion[11];
    time_t     hora;
    struct tm *fecArchivo;

    PreparaQuerys();

	hora = time(&hora);
	fecArchivo = gmtime(&hora);

	rfmtdate (lFechaFacturacion, "dd_mm_yyyy", sFechaFacturacion);
   
   
	sprintf(nomArchivo, "/tmp/int_mora_%s_%04d%02d%02d_%02d%02d.txt", sFechaFacturacion, fecArchivo->tm_year + 1900,
            fecArchivo->tm_mon + 1, fecArchivo->tm_mday, fecArchivo->tm_hour - 3, fecArchivo->tm_min);
	if((fEvenCalInt = fopen(nomArchivo, "w")) == NULL)
		fprintf(stderr, "%s (%d): Fallo al intentar abrir el archivo %s\n", __FILE__, __LINE__, nomArchivo);

    return (OK);
}


void TerminaAmbiente(int fg)
{
    if(fEvenCalInt != NULL) fclose(fEvenCalInt);

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


void PreparaQuerys(void)
{
    $char strSql[1600];

    EXEC SQL PREPARE selHisfacContTemp FROM
      "SELECT hc.*, c.*, h.*
         FROM hisfac_cont_temp hc,
              cliente c,
              hisfac h
        WHERE hc.sucursal    = ?
          AND hc.numero_cliente       = c.numero_cliente
          AND hc.numero_cliente       = h.numero_cliente
          AND hc.corr_facturacion - 1 = h.corr_facturacion";

    EXEC SQL DECLARE curHisfacContTemp CURSOR WITH HOLD FOR selHisfacContTemp;


   /*Cursor de recupero de las facturas cnr de un cliente*/
   sprintf(strSql, "%s", "SELECT cnr_f1.total_suj_interes, "
                                "cnr_f1.fecha_vencimiento, "
                                "cnr_f1.fecha_tran_saldo, "
                                "cnr_f1.corr_facturacion, "
                                "cnr_f1.tipo_docto, "
                                "cnr_n.c_s_querella, "
                                "cnr_f2.fecha_emision "
                                ", cnr_f1.nro_expediente "
                                ", cnr_f1.ano_expediente "
                                ", cnr_f1.sucursal " /* PDP - Fin */
                           "FROM cnr_new cnr_n, "
                                "cnr_factura cnr_f1, "
                                "OUTER cnr_factura cnr_f2 "
                          "WHERE cnr_f1.numero_cliente = ? "
                            "AND cnr_f1.fecha_vencimiento >= ? "
                            "AND cnr_f1.fecha_vencimiento < ? "
                            "AND cnr_f1.incluido_cta_cte = 'S' "
                            "AND cnr_f1.tipo_docto <> '19' "
                            "AND cnr_n.nro_expediente = cnr_f1.nro_expediente "
                            "AND cnr_n.ano_expediente = cnr_f1.ano_expediente "
                            "AND cnr_n.sucursal = cnr_f1.sucursal "
                            "AND cnr_f1.sucursal = cnr_f2.sucursal "
                            "AND cnr_f1.ano_expediente = cnr_f2.ano_expediente "
                            "AND cnr_f1.nro_expediente = cnr_f2.nro_expediente "
                            "AND cnr_f2.tipo_docto = '19' "
                            "AND cnr_f2.corr_facturacion = (cnr_f1.corr_facturacion + 1)");
   RegistraInicioSql("PREPARE CCnr");
   $PREPARE CnrStr FROM $strSql;

   RegistraInicioSql("DECLARE CCnr");
   $DECLARE CCnr CURSOR WITH HOLD FOR CnrStr;


   /*Cursor de recupero de los convenios de un cliente*/
   sprintf(strSql, "%s", "SELECT fecha_vigencia, "
                                "fecha_caducado, "
                                "monto_cadu_suj_int, "
                                "corr_convenio "
                           "FROM conve "
                          "WHERE numero_cliente = ? "
                            "AND ((estado = 'C' "
                            "AND (fecha_vigencia > ? "
                              "OR (fecha_caducado > ? "
                              "AND usuario_termino IS NULL)) "
                            " AND fecha_caducado <= ?) "
                            "OR (estado = 'V' OR (estado IN ('C','T') AND fecha_termino >= ?)))");

   RegistraInicioSql("PREPARE CConvenio");
   $PREPARE ConveStr FROM $strSql;

   RegistraInicioSql("DECLARE CConvenio");
   $DECLARE CConvenio CURSOR WITH HOLD FOR ConveStr;


   /* Recupero los saldos en disputa que afectaron las facturas CNR que vencen en el periodo*/
   sprintf(strSql, "%s", "SELECT NVL(SUM(sd_cnr.saldo_actual + sd_cnr.saldo_imp_suj_i), 0) "
                                ", NVL(sd.fecha_autoriza, 0) "
                                ", NVL(sd.fecha_finalizacion, 0) "
                           "FROM sd_saldo_disputa sd, sd_cnr_saldos sd_cnr "
                          "WHERE sd.nro_saldo_disputa  = sd_cnr.nro_saldo_disputa "
                            "AND sd_cnr.nro_expediente = ? "
                            "AND sd_cnr.ano_expediente = ? "
                            "AND sd_cnr.sucursal       = ? "
                            "AND sd.estado            IN ('V', 'F') "
                            "AND sd.fecha_autoriza    <= ? "
                       "GROUP BY sd.fecha_autoriza "
                              ", sd.fecha_finalizacion ");
   RegistraInicioSql("PREPARE SDcnrStr");
   $PREPARE SDcnrStr FROM $strSql;

   RegistraInicioSql("DECLARE CSDcnrStr");
   $DECLARE CSDcnrStr CURSOR WITH HOLD FOR SDcnrStr;


   /*Recupero los saldos en disputa de un cliente que se autorizaron y/o finalizaron en el periodo*/
   sprintf(strSql, "%s", "SELECT sd.saldo_actual + sd.saldo_imp_suj_int - "
                                " (SELECT NVL(SUM(sd_cnr.saldo_actual + sd_cnr.saldo_imp_suj_i), 0) "
                                "    FROM sd_cnr_saldos sd_cnr, cnr_factura cnr "
                                "   WHERE sd_cnr.nro_saldo_disputa = sd.nro_saldo_disputa "
								"     AND sd_cnr.sucursal = cnr.sucursal "
								"     AND sd_cnr.ano_expediente = cnr.ano_expediente "
								"     AND sd_cnr.nro_expediente = cnr.nro_expediente "
								"     AND cnr.tipo_docto <> '19' "
								"     AND cnr.cod_estado <> 'A' "
								"     AND cnr.fecha_vencimiento >= ? "
								"     AND cnr.fecha_vencimiento < ? ), "
                                "NVL(sd.fecha_autoriza, 0), "
                                "NVL(sd.fecha_finalizacion, 0), "
                                "sd.estado "
                           "FROM sd_saldo_disputa sd "
                          "WHERE sd.numero_cliente = ? "
                            "AND ((sd.estado = 'V' "
                            "AND sd.fecha_autoriza > ? "
                            "AND sd.fecha_autoriza <= ?) "
                             "OR (sd.estado = 'F' "
                            "AND sd.fecha_finalizacion > ? "
                            "AND sd.fecha_finalizacion <= ?) "
                            "OR (sd.estado = 'F' "
                            "AND sd.fecha_autoriza > ? "
                            "AND sd.fecha_autoriza <= ? "
                            "AND sd.fecha_finalizacion > ? ))");

   RegistraInicioSql("PREPARE SdoDispStr");
   $PREPARE SdoDispStr FROM $strSql;

   RegistraInicioSql("DECLARE CSdoDisp");
   $DECLARE CSdoDisp CURSOR WITH HOLD FOR SdoDispStr;


   /*Cursor de recupero de los pagos de expedientes cnr*/
   sprintf(strSql, "%s", "SELECT corr_facturacion, "
                                "corr_pagos, "
                                "importe_pago_suj_i, "
                                "fecha_pago "
                           "FROM cnr_pago "
                          "WHERE numero_cliente = ? "
                            "AND corr_facturacion in (?)");

   RegistraInicioSql("PREPARE CPagosCnr");
   $PREPARE PagosCnrStr FROM $strSql;

   RegistraInicioSql("DECLARE CPagosCnr");
   $DECLARE CPagosCnr CURSOR WITH HOLD FOR PagosCnrStr;
   
   /* Insertar Intereses calculados */
   strcpy(strSql, "INSERT INTO sap_calcu_inter ( ");
   strcat(strSql, "numero_cliente, ");
   strcat(strSql, "corr_facturacion, ");
   strcat(strSql, "inter_calculado ");
   strcat(strSql, ")VALUES( ");
   strcat(strSql, "?, ?, ?) ");   
   
   $PREPARE insCalcuInter FROM $strSql;
   
}


int FetchHisfacContTemp(stHisfacCont, stCliente, stHisfac)
EXEC SQL BEGIN DECLARE SECTION;
    PARAMETER ThisfacCont *stHisfacCont;
    PARAMETER Tcliente    *stCliente;
    PARAMETER Thisfac     *stHisfac;
EXEC SQL END DECLARE SECTION;
{
    EXEC SQL FETCH curHisfacContTemp
        INTO :*stHisfacCont,
             :*stCliente,
             :*stHisfac;

    return (SQLCODE == 0);
}

short GrabaInteres(lNroCliente, lCorrFacturacion, dMonto)
$long    lNroCliente;
$long    lCorrFacturacion;
$double  dMonto;  
{

   $EXECUTE insCalcuInter USING :lNroCliente, :lCorrFacturacion, :dMonto;
   
   if(SQLCODE != 0 ){
      return 0;
   }
   
   
   return 1;
}
