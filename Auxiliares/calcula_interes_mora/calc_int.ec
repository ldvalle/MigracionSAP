/******************************************************************************
* calc_int.ec - Modulo de calculo de intereses de un cliente
* JZ - 12/01/2000 - Este modulo fue reprogramado para su adaptacion al uso de
* expedientes CNR
*******************************************************************************/
#include <string.h>
#include <stdlib.h> /*Se incluye para migracion a AIX*/
$include errores.h;
$include sqltypes;
$include cliente.h;
$include hisfac.h;
$include pagco.h;
$include campos.h;
$include codigos.h;
$include macmath.h;
$include refac.h;
$include math.h;

#include <stdio.h>
$include calc_inter.h;
$include datos_gen.h;
$include conc_calc.h;
$include recu_val.h;
$include funcdt.h; /*Se incluye para migracion a AIX*/

extern FILE *fEvenCalInt; /* FAM - Proyecto Saldos en Disputa */

/******************************************************************************
* CalcularIntereses
* Calculo los intereses de un cliente determinado el periodo que se este factu-
* rando
*******************************************************************************/
void CalcularIntereses( cliente,
                        totalNCAnterior,
                        totalNCPeriodo,
                        registroHisfac,
                        baseInteresConvenioCad,
                        fechaCaducado,
                        arrayNotas,
                        cantNotas,
                        lFechaFacturacion)
$Tcliente cliente;
TCvalor   totalNCAnterior;
TCvalor   totalNCPeriodo;
$Thisfac  registroHisfac;
TCvalor   baseInteresConvenioCad;
TCfecha   fechaCaducado;
Trefac    arrayNotas[];
int       cantNotas;
$long     lFechaFacturacion;
{

$TCfecha         fechaHoy;
Tinteres         vInteresFC[MAXROWSFAC];
TvecCnr          vInteresCNR[MAXROWSAUX];
int              indexFC = 0;
int              indexCNR = 0;
TdatosGen        datosGenerales;
TCvalor          interesesFC = 0.0;
TCvalor          interesesCNR = 0.0;
TconcCalc        concCalc;
int              cantFilasPagos  = 0;
$Tpagco          registroPago[CANT_MAX_PAGOS_PERIODO];
int              i;
int              buscoPagos = FALSE;
TCfecha          minima_fecha_cnr;
int              indexFactCnr = 0;
TArrCnr          aFactCnr[MAXROWSAUX];
TConvenio        aConvenio[MAXROWSAUX];
int              indexConvenio = 0;
int              tieneHisFac;
TSdCnr           aSdCnr[MAXROWSAUX];
int              indexSdCnr = 0;

    $WHENEVER ERROR CALL ProcesaErrores;

    tieneHisFac = !risnull(CLONGTYPE, (void *) &(registroHisfac.numeroCliente));

    minima_fecha_cnr = cliente.fechaUltimaFact;

    /*rtoday(&fechaHoy);*/
    fechaHoy = lFechaFacturacion; /* PDP - Calculo Interes Mora MAL */

	/* FAM - Proyecto Saldos en Disputa */
	if(fEvenCalInt != NULL) fprintf(fEvenCalInt, "\nNumero cliente: %ld\n", cliente.numeroCliente);

/* OJO printf("A - Recupera CNR\n");*/
    /*Recupero los CNR del cliente*/
    RecuperarCnr( aFactCnr, cliente, &indexFactCnr, fechaHoy, &minima_fecha_cnr );

/* OJO printf("B - Recupera Convenios\n");*/
    /*Recupero los convenios del cliente*/
    RecuperarConvenios( aConvenio, cliente.numeroCliente, &indexConvenio,
                        minima_fecha_cnr, baseInteresConvenioCad, fechaCaducado,
                        fechaHoy, cliente.fechaUltimaFact );

/* OJO printf("C - Recupera Saldo Disp CNR\n");*/
    /*PDP - Proyecto Saldo en Disputa - Recupero los SD de los CNR */
    RecuperarSdosDispCnr(aFactCnr, indexFactCnr, fechaHoy);

/* OJO printf("D - Copia CNR\n");*/
    /*Copio los CNR validos al vector de CNR segun los convenios*/
    CopiaCnr( vInteresCNR, &indexCNR, aFactCnr, indexFactCnr,
              aConvenio, indexConvenio, &buscoPagos, &registroHisfac,
              cliente.fechaUltimaFact, fechaHoy);  /*PDP - Proyecto Saldo en Disputa - Se agrega parametro fechaHoy*/

    if ((tieneHisFac) || (indexCNR > 0))
       {
/* OJO printf("E - Recupera Saldo Ant\n");*/
        /*Cargo saldos anteriores en los vectores de movimientos*/
        RecuperarSaldosAnt(vInteresFC, &registroHisfac, cliente.fechaUltimaFact,
                            &totalNCAnterior, &indexFC, &buscoPagos, tieneHisFac );

/* OJO printf("F - Recupera Saldo Disputa\n");*/
        /*PDP - Proyecto Saldo en Disputa*/
        /* Cargo Saldos en Disputa en los vectores de movimientos */
        RecuperarSdosDisp( vInteresFC, &indexFC, fechaHoy, cliente);

/* OJO printf("G - Copia NC\n");*/
        /*Cargo las notas de credito del periodo y periodos anteriores.*/
        CopiaNC( arrayNotas, cantNotas, aConvenio, indexConvenio,
                 cliente.fechaUltimaFact);

/* OJO printf("H - Copia Convenios\n");*/
        /*Copio los convenios a los vectores de facturas de ciclo y cnr*/
        CopiaConvenios(vInteresCNR, &indexCNR, vInteresFC, &indexFC, aConvenio,
                       indexConvenio, cliente.fechaUltimaFact, &buscoPagos);

/* OJO printf("I - Recupera Fin Calculo\n");*/
        /*Cargo la fecha de fin de calculo*/
        RecuperarFinCalculo( vInteresFC, vInteresCNR, fechaHoy,
                             &indexFC, &indexCNR );

/* OJO printf("J - Recupera Total Fact\n");*/
        /*Cargo total factura en los vectores de movimientos*/
        RecuperarTotalFac( vInteresFC, registroHisfac, totalNCPeriodo,
                           &indexFC, &buscoPagos, aConvenio, indexConvenio );

        /*Recupero los pagos dentro de los vectores de movimientos si y solo si
        existen datos dentro de los vectores con valores que afecten la base
        base de calculo de interes.*/
        if (buscoPagos)
           {
/* OJO printf("K - Recupera Pagos\n");*/
            cantFilasPagos  = RecuperarPagos( registroPago, cliente );
            CopiaPagos(cliente.numeroCliente, vInteresFC, vInteresCNR, registroPago,
                        cantFilasPagos, &indexFC, &indexCNR );

            if (indexCNR > 0)
               {
                /*Calculo los interes para todos los cnr del cliente*/
                for (i=0; i < indexCNR; i++)
                   {
                    /*Ordeno vector de movimientos de facturas CNR */
                    OrdenarVector( vInteresCNR[i].vCnr, vInteresCNR[i].index );

                    /* ARA - 06/11/2001
                     * Si el cliente tiene incluido en su cuenta, una Factura Complementaria
                     * con Querella, no tenerla en cuenta para el calculo de intereses en la
                     * primera factura de ciclo posterior a la transferencia.
                     * Ver OM 779/3
                     */

                    if (( strcmp ( aFactCnr [ vInteresCNR[i].iParent ].tipo_docto, "18" ) != 0 ) ||
                        ( aFactCnr [ vInteresCNR[i].iParent ].c_s_querella [ 0 ] != 'S' ) ||
                        ( aFactCnr [ vInteresCNR[i].iParent ].fecha_emision <= registroHisfac.fechaFacturacion ))
                       {
                        /*Calculo intereses a partir del vector de movimientos de facturas CNR */
							double interes;
							if(fEvenCalInt != NULL)
                                fprintf(fEvenCalInt, "\nEVENTOS CNR %ld-%ld\n",
										aFactCnr [ vInteresCNR[i].iParent ].ano_expediente,
                                        aFactCnr [ vInteresCNR[i].iParent ].nro_expediente);
							/* PDP - OM2148 - Se agrega codigo valor que depende de tarifa */
							/*interes = CalcularInteres( vInteresCNR[i].vCnr, vInteresCNR[i].index );*/
/* OJO printf("L - CalcularInteres\n");*/
							interes = CalcularInteres( vInteresCNR[i].vCnr, vInteresCNR[i].index, (cliente.tarifa[1]=='R')? COD_VALOR_INTERES_MORA_PASIVO : COD_VALOR_INTERES_MORA_ACTIVO );
							if(fEvenCalInt != NULL) /*FAM - Proyecto Saldos en Disputa*/
								fprintf(fEvenCalInt, "Interés por mora por CNR %ld-%ld $%.2f\n",
										aFactCnr [ vInteresCNR[i].iParent ].ano_expediente,
										aFactCnr [ vInteresCNR[i].iParent ].nro_expediente, interes);
							interesesCNR += interes;
                       }
                   }
               }

            if (indexFC > 0)
               {
/* OJO printf("M - Pasa Pagos CNR a FC\n");*/
                /*Paso los pagos de facturas cnr posteriores al inicio de un convenio al
                vector de la factura de ciclo.*/
                PasoPagosCNRaFC(vInteresFC, &indexFC, vInteresCNR, indexCNR);

                /*Ordeno vector de movimientos de factura de ciclo*/
                OrdenarVector( vInteresFC, indexFC );

                /*Calculo intereses a partir del vector de movimientos de factura de ciclo*/
				if(fEvenCalInt != NULL) fprintf(fEvenCalInt, "\nEVENTOS NO CNR\n");
                /* PDP - OM2148 - Se agrega codigo valor que depende de tarifa */
                /*interesesFC = CalcularInteres( vInteresFC, indexFC );*/
/* OJO printf("N - CalcularInteres\n");*/
                interesesFC = CalcularInteres( vInteresFC, indexFC, (cliente.tarifa[1]=='R')? COD_VALOR_INTERES_MORA_PASIVO : COD_VALOR_INTERES_MORA_ACTIVO );
				if(fEvenCalInt != NULL) fprintf(fEvenCalInt, "Interés por mora NO CNR $%.2f\n",
												interesesFC); /* FAM - Proyecto Saldos en Disputa*/
               }

/* OJO printf("O - Inserta Interes en estructura\n");*/
            strcpy(concCalc.codigoCargo, COD_CARGO_INT_MORA );
            strcpy(concCalc.tipoCargo, TIP_CON_INTERES);
            strcpy(concCalc.indAfectoInt, "N" );
            concCalc.grabaEnBase = SI;
            concCalc.cantidad = 0.0;
            concCalc.valorCalculado = interesesFC + interesesCNR;
			if(fEvenCalInt != NULL) /* FAM - Proyecto Saldos en Disputa */
				fprintf(fEvenCalInt, "\nInterés por mora TOTAL calculado: %.2f.-\n\n", concCalc.valorCalculado);

            if ( round ( concCalc.valorCalculado ) > 0.0 )
               InsertarConcCalc( concCalc );
           }
       }
}


/******************************************************************************
* RecuperarSaldosAnt
* Pasa al vector de movimientos de la factura de ciclo el saldo del periodo
* anterior.
*******************************************************************************/
void RecuperarSaldosAnt( vInteresFC, registroHisfac, fechaUltimaFact,
                         totalNCAnterior, indexFC, buscoPagos, tieneHisFac )
Tinteres  vInteresFC[];
Thisfac   *registroHisfac;
TCfecha   fechaUltimaFact;
TCvalor   *totalNCAnterior;
int       *indexFC;
int       *buscoPagos;
int       tieneHisFac;
{
   if (tieneHisFac)
     {
       BuscarMemoria(indexFC, MAXROWSFAC);
       vInteresFC[*indexFC-1].tipoOperacion = SALDOANT;
       vInteresFC[*indexFC-1].fecha_vencimiento = fechaUltimaFact;
       vInteresFC[*indexFC-1].correlativo = 0;

       (*registroHisfac).saldoAntSujInt-=fabs(*totalNCAnterior);
       vInteresFC[*indexFC-1].valor = (*registroHisfac).saldoAntSujInt;
       *totalNCAnterior = 0;
       if ( vInteresFC[*indexFC-1].valor >= 0.01 )
           *buscoPagos = TRUE;
     }
}

/******************************************************************************
* RecuperarTotalFac
* Pasa al vector de movimientos de la factura de ciclo el total facturado en el
* periodo para el cual se esta facturando.
*******************************************************************************/
void RecuperarTotalFac( vInteresFC, registroHisfac, totalNCPeriodo,
                        indexFC, buscoPagos, aConvenio, indexConvenio )
Tinteres  vInteresFC[];
Thisfac   registroHisfac;
TCvalor   totalNCPeriodo;
int       *indexFC;
int       *buscoPagos;
TConvenio aConvenio[];
int       indexConvenio;
{
int       i;
int       IncluirTotalFacturado = TRUE;

 if (*indexFC > 0)
    {
     for (i=0; (i<indexConvenio) && IncluirTotalFacturado; i++)
        {
         if ((aConvenio[i].fecha_vigencia > vInteresFC[0].fecha_vencimiento) &&
             (aConvenio[i].fecha_vigencia <= registroHisfac.fechaVencimiento2))
            IncluirTotalFacturado = FALSE;
        }

     if (IncluirTotalFacturado)
        {
         BuscarMemoria(indexFC, MAXROWSFAC);
         vInteresFC[*indexFC-1].valor = registroHisfac.totFacSujInt +
                                        totalNCPeriodo -
                                        registroHisfac.sumaRecargo;
         vInteresFC[*indexFC-1].tipoOperacion = TOTFACT;
         vInteresFC[*indexFC-1].fecha_vencimiento = registroHisfac.fechaVencimiento2;
         vInteresFC[*indexFC-1].correlativo = 0;
         if ( vInteresFC[*indexFC-1].valor >= 0.01 )
             *buscoPagos = TRUE;
        }
    }
}


/******************************************************************************
* CopiaPagos
* A partir de los pagos realizados en el periodo que se esta facturando y de
* los pagos realizados para las facturas cnr, reparte segun corresponda los
* pagos en los vectores de movimiento de las facturas.
*******************************************************************************/
void CopiaPagos(
        long      numeroCliente,
        Tinteres  vInteresFC[],
        TvecCnr   vInteresCNR[],
        Tpagco    registroPago[],
        int       cantFilasPagos,
        int      *indexFC,
        int      *indexCNR
        )

{
    int       i;
    int       j;
    int       k;
    TPagoCnr  pagoCnr[MAXROWSAUX];
    int       index;
    int       cantPagosCnr = 0;
    TCvalor   montoPagoCnr = 0.0;
    long      fechaPago;

    /* Recupero los pagos de todas las facturas CNR que vencen en el periodo */
    if (*indexCNR > 0)
    {
        BuscarPagoCnr(numeroCliente, pagoCnr, &cantPagosCnr,
                      vInteresCNR, *indexCNR );
    }

    /* Distribuyo los pagos generados en el periodo entre los vectores de
       movimientos de las facturas*/
    for (i=0; i<cantFilasPagos; i++)
    {
        montoPagoCnr = 0.0;
        if (*indexCNR > 0)
        {
            j=0;
            while (j < cantPagosCnr)
            {
                if (registroPago[i].corrPagos == pagoCnr[j].corr_pago)
                {
                    if ((pagoCnr[j].fecha_pago > vInteresFC[0].fecha_vencimiento) ||
                        (registroPago[i].fechaActualiza > vInteresFC[0].fecha_vencimiento))
                    /* PJP - 12/08/2002 - No se marca como procesado cualquier pago de CNR con
                       fecha = a la fecha de factura anterior si la fecha de amortizacion es <=
                       fecha de factura anterior (porque el pago correspondiente de pagco solo
                       se incorpora al vector de FC cuando se amortizó después de la f.fact.ant.*/
                    {
                        for (k=0;
                             ((k < *indexCNR) && (vInteresCNR[k].aCnr[0].corr_facturacion != pagoCnr[j].corr_facturacion));
                             k++)
                        {
                            /* empty loop */;
                        }

                        BuscarMemoria(&vInteresCNR[k].index, MAXROWSAUX);
                        index = (vInteresCNR[k].index) - 1;
                        vInteresCNR[k].aCnr[index].corr_facturacion = pagoCnr[j].corr_facturacion;
                        vInteresCNR[k].vCnr[index].valor = pagoCnr[j].monto_pago;
                        vInteresCNR[k].vCnr[index].fecha_vencimiento = pagoCnr[j].fecha_pago;
                        vInteresCNR[k].vCnr[index].tipoOperacion = PAGO;
                        vInteresCNR[k].vCnr[index].correlativo = 0;
                        pagoCnr[j].procesado = TRUE;
                        montoPagoCnr += pagoCnr[j].monto_pago;
                    }
                }
                j++;
           }
        }

        if (registroPago[i].valorPagoSujInt - montoPagoCnr >= 0.01)
        {
            if (*indexFC > 0)
            {
                if (registroPago[i].fechaActualiza > vInteresFC[0].fecha_vencimiento)
                {
                    PasaFechaHoraALong(&(registroPago[i].fechaPago), &fechaPago); /*Se agrega el & para migracion a AIX*/
                    BuscarMemoria(indexFC, MAXROWSFAC);
                    vInteresFC[*indexFC-1].valor = registroPago[i].valorPagoSujInt - montoPagoCnr;
                    vInteresFC[*indexFC-1].fecha_vencimiento = fechaPago;
                    vInteresFC[*indexFC-1].tipoOperacion = PAGO;
                    vInteresFC[*indexFC-1].correlativo = 0;
                }
            }
        }
    }

    /* Todos aquellos pagos que se efecturan en periodos anteriores se los
     * sumo a la base de calculo de las facturas de ciclo y las ingreso en
     * el vector de facturas cnr como un pago con fecha de vencimiento igual
     * a la fecha de inicio del calculo.
     */
    for (i=0; i < cantPagosCnr; i++)
    {
        if (pagoCnr[i].procesado == FALSE)
        {
            for (k=0; ((k < *indexCNR) && (vInteresCNR[k].aCnr[0].corr_facturacion !=
                      pagoCnr[i].corr_facturacion)); k++)
            {
                /* empty loop */;
            }

            BuscarMemoria(&vInteresCNR[k].index, MAXROWSAUX);
            index = (vInteresCNR[k].index) - 1;
            vInteresCNR[k].aCnr[index].corr_facturacion = pagoCnr[i].corr_facturacion;
            vInteresCNR[k].vCnr[index].valor = pagoCnr[i].monto_pago;
            vInteresCNR[k].vCnr[index].tipoOperacion = PAGO;
            vInteresCNR[k].vCnr[index].correlativo = 0;

            if (*indexFC > 0)
            {
                if (pagoCnr[i].fecha_pago <= vInteresFC[0].fecha_vencimiento)
                /* PJP - 09/08/2002 - Se incluye el = */
                {
                    vInteresCNR[k].vCnr[index].fecha_vencimiento = vInteresFC[0].fecha_vencimiento;
                    vInteresFC[0].valor += pagoCnr[i].monto_pago;
                }
                else
                    vInteresCNR[k].vCnr[index].fecha_vencimiento = pagoCnr[i].fecha_pago;
            }
            else
            {
                vInteresCNR[k].vCnr[index].fecha_vencimiento = pagoCnr[i].fecha_pago;
            }
        }
    }

}  /* fin CopiaPagos */


/******************************************************************************
* OrdenarVector
* Ordena el vector de movimientos de un fatura (de ciclo o cnr)
*******************************************************************************/
void OrdenarVector( vInteres, index )
Tinteres  *vInteres;
int       index;
{
int InteresQsort();
   qsort((void *) vInteres,
    (size_t) index,
    sizeof(Tinteres),
    InteresQsort);
}


/******************************************************************************
* InteresQsort
* Condicion por la cual ordena los vectores de movimientos de factura
*******************************************************************************/
/*Se modifica la funcion para migracion a AIX*/
int InteresQsort(const void *conceptoUno, const void  *conceptoDos)
{
 if ((((Tinteres *)conceptoUno)->fecha_vencimiento - ((Tinteres *)conceptoDos)->fecha_vencimiento) == 0)
    {
     if ((((Tinteres *)conceptoUno)->tipoOperacion - ((Tinteres *)conceptoDos)->tipoOperacion)==0)
        return (((Tinteres *)conceptoUno)->correlativo - ((Tinteres *)conceptoDos)->correlativo);
     else
        {
         if (((((Tinteres *)conceptoUno)->tipoOperacion == CONVENIO) &&
              (((Tinteres *)conceptoDos)->tipoOperacion == CONVCAD)) ||
             ((((Tinteres *)conceptoDos)->tipoOperacion == CONVENIO) &&
              (((Tinteres *)conceptoUno)->tipoOperacion == CONVCAD)))
            {
             if ((((Tinteres *)conceptoUno)->correlativo - ((Tinteres *)conceptoDos)->correlativo) == 0)
                return (((Tinteres *)conceptoUno)->tipoOperacion - ((Tinteres *)conceptoDos)->tipoOperacion);
             else
                return (((Tinteres *)conceptoUno)->correlativo - ((Tinteres *)conceptoDos)->correlativo);
            }
         else
            return (((Tinteres *)conceptoUno)->tipoOperacion - ((Tinteres *)conceptoDos)->tipoOperacion);
        }
    }
 else
   return (((Tinteres *)conceptoUno)->fecha_vencimiento - ((Tinteres *)conceptoDos)->fecha_vencimiento);
}


/******************************************************************************
* CalcularInteres
* Para un determinado vector de movimientos de factura (de ciclo o cnr)
* calculo los intereses.
*******************************************************************************/
TCvalor CalcularInteres( vInteres, index, sCodigoValor )
Tinteres  *vInteres;
int       index;
char      *sCodigoValor;
{
    int     i = 0;
    TCvalor interes = 0.0;
    TCvalor baseCalculo = 0.0;
    TCvalor tasa = 0.0;
    char    sCodAux[4];

    while (i < index)
    {
        tasa = 0.0;

        /*Calculo el interes*/
        if ((i > 0) && (baseCalculo > 0.01))
        {
            /* PDP - OM2148 - Se considera fecha de implementacion de Ley de Defensa del Consumidor */
            if( vInteres[i-1].fecha_vencimiento < DIA_LEY_DFENSA_CONSUMIDOR && vInteres[i].fecha_vencimiento > DIA_LEY_DFENSA_CONSUMIDOR )
            {
                tasa = RecuperaValorUnico ( CODIGO_VALOR_INTERES_MORA,
                                            vInteres[i-1].fecha_vencimiento,
                                            DIA_LEY_DFENSA_CONSUMIDOR);
                interes += (DIA_LEY_DFENSA_CONSUMIDOR - vInteres[i-1].fecha_vencimiento ) *
                            tasa * INCREMENTO_TASA * baseCalculo / 100;

                tasa = RecuperaValorUnico ( sCodigoValor,
                                            DIA_LEY_DFENSA_CONSUMIDOR,
                                            vInteres[i].fecha_vencimiento);
                interes += (vInteres[i].fecha_vencimiento - DIA_LEY_DFENSA_CONSUMIDOR ) *
                            tasa * INCREMENTO_TASA * baseCalculo / 100;
            } else {
                if ( vInteres[i-1].fecha_vencimiento >= DIA_LEY_DFENSA_CONSUMIDOR )
                    strcpy(sCodAux, sCodigoValor);
                else    /* vInteres[i].fecha_vencimiento <= DIA_LEY_DFENSA_CONSUMIDOR */
                    strcpy(sCodAux, CODIGO_VALOR_INTERES_MORA);

                tasa = RecuperaValorUnico ( sCodAux,
                                            vInteres[i-1].fecha_vencimiento,
                                            vInteres[i].fecha_vencimiento);
                interes += (vInteres[i].fecha_vencimiento - vInteres[i-1].fecha_vencimiento ) *
                            tasa * INCREMENTO_TASA * baseCalculo / 100;
            }
        }

        /* PDP Saldos en Disputa */ ImprimirEventos(vInteres, i, baseCalculo);

        /*modifico la base de calculo*/
        switch (vInteres[i].tipoOperacion)
        {
            case SALDOANT:
            case TOTFACT:
            case CNR:
            case CONVCAD:
            case SD_RESOL: /* PDP - Proyecto Saldos en disputa */
                baseCalculo += vInteres[i].valor;
                break;

            case PAGO:
            case SD_AUTORIZ: /* PDP - Proyecto Saldos en disputa */
                baseCalculo -= vInteres[i].valor;
                break;

            case FIN:
            case CONVCNR:
                i = index;
                break;

            case CONVENIO:
                baseCalculo = 0.0;
                break;
        }
        i++;
    }

    if (interes >= 0.01)
        return interes;
    else
        return 0.0;
}


/******************************************************************************
* BuscarPagoCnr
* Busca los pagos de facturas cnr que vencen en el periodo a facturar
*******************************************************************************/
void BuscarPagoCnr(numeroCliente, pagoCnr, cantPagosCnr,
                   vInteresCNR, indexCNR)
$TCnumeroCliente  numeroCliente;
$TPagoCnr         pagoCnr[];
int               *cantPagosCnr;
TvecCnr           vInteresCNR[];
int               indexCNR;
{
$TCcorrFacturacion    corr_facturacion;
$TCcorrPago           corr_pago;
$TCvalor              monto_pago;
$dtime_t              fecha_pago;
long                  fecha_aux;
int                   index;
$TCcorrFacturacion    corr_aux;
int                   i;

*cantPagosCnr = 0;

for (i=0; i<indexCNR; i++)
   {
    corr_aux = vInteresCNR[i].aCnr[0].corr_facturacion;

    $OPEN CPagosCnr USING $numeroCliente,
                          $corr_aux;

    $FETCH CPagosCnr INTO $corr_facturacion,
                          $corr_pago,
                          $monto_pago,
                          $fecha_pago;

    if (SQLCODE != SQLNOTFOUND)
       {
        pagoCnr[*cantPagosCnr].corr_facturacion = 0;
        pagoCnr[*cantPagosCnr].corr_pago = 0;
        pagoCnr[*cantPagosCnr].monto_pago = 0;
        pagoCnr[*cantPagosCnr].fecha_pago = 0;
       }

    while (SQLCODE != SQLNOTFOUND)
       {
        PasaFechaHoraALong(&fecha_pago, &fecha_aux); /*Se agrego el & para migracion a AIX*/

        pagoCnr[*cantPagosCnr].corr_facturacion = corr_facturacion;
        pagoCnr[*cantPagosCnr].corr_pago = corr_pago;
        pagoCnr[*cantPagosCnr].monto_pago = monto_pago;
        pagoCnr[*cantPagosCnr].fecha_pago = fecha_aux;
        pagoCnr[*cantPagosCnr].procesado = FALSE;
        (*cantPagosCnr)++;

        $FETCH CPagosCnr INTO $corr_facturacion,
                              $corr_pago,
                              $monto_pago,
                              $fecha_pago;
       }
    $CLOSE CPagosCnr;
   }
}


/******************************************************************************
* RecuperarCnr
* Busca las facturas cnr que vencen en le periodo y las pasa al array de
* facturas cnr
*******************************************************************************/
void RecuperarCnr( aFactCnr, cliente, indexFactCnr, fechaHoy, minima_fecha_cnr)
TArrCnr   aFactCnr[];
Tcliente  cliente;
int       *indexFactCnr;
$TCfecha  fechaHoy;
$TCfecha  *minima_fecha_cnr;
{
$TCvalor               monto;
$TCfecha               fecha_vencimiento;
$TCfecha               fecha_emision;
$TCcorrFacturacion     corr_facturacion;
$string                tipo_docto [ 7 ] ;
$char                  c_s_querella [ 2 ] ;
$TCfecha               fecha_anulacion;
/* PDP - Proyecto Saldos en Disputa */
$int                    nro_expediente;
$int                    ano_expediente;
$char                   sucursal [ 5 ];

$OPEN CCnr USING $cliente.numeroCliente,
                 $cliente.fechaUltimaFact,
                 $fechaHoy;

$FETCH CCnr INTO $monto,
                 $fecha_vencimiento,
                 $fecha_emision,
                 $corr_facturacion,
                 $tipo_docto,
                 $c_s_querella,
                 $fecha_anulacion,
                 /* PDP - Proyecto Saldos en Disputa */
                 $nro_expediente,
                 $ano_expediente,
                 $sucursal;

while (SQLCODE != SQLNOTFOUND)
   {
    BuscarMemoria(indexFactCnr, MAXROWSAUX);

    aFactCnr[*indexFactCnr-1].valor = monto;
    aFactCnr[*indexFactCnr-1].fecha_vencimiento = fecha_vencimiento;
    aFactCnr[*indexFactCnr-1].fecha_emision = fecha_emision;
    aFactCnr[*indexFactCnr-1].corr_facturacion = corr_facturacion;
    aFactCnr[*indexFactCnr-1].fecha_anulacion = fecha_anulacion;
    /* PDP - Calculo Interes Mora MAL */
    if (fecha_anulacion > fechaHoy)
        rsetnull(CLONGTYPE, (char*) &(aFactCnr[*indexFactCnr-1].fecha_anulacion));

    ( void ) strcpy ( aFactCnr[*indexFactCnr-1].tipo_docto, tipo_docto ) ;
    ( void ) strcpy ( aFactCnr[*indexFactCnr-1].c_s_querella, c_s_querella ) ;

    /* PDP - Proyecto Saldos en Disputa */
    aFactCnr[*indexFactCnr-1].nro_expediente = nro_expediente;
    aFactCnr[*indexFactCnr-1].ano_expediente = ano_expediente;
    ( void ) strcpy ( aFactCnr[*indexFactCnr-1].sucursal, sucursal ) ;
    aFactCnr[*indexFactCnr-1].cantSd = 0;
     /* Fin PDP */

    /*Guardo la minima fecha de emision de las facturas*/
    if (*minima_fecha_cnr > fecha_emision)
       *minima_fecha_cnr = fecha_emision;

    $FETCH CCnr INTO $monto,
                     $fecha_vencimiento,
                     $fecha_emision,
                     $corr_facturacion,
                     $tipo_docto,
                     $c_s_querella,
                     $fecha_anulacion,
                     /* PDP - Proyecto Saldos en Disputa */
                     $nro_expediente,
                     $ano_expediente,
                     $sucursal;
   }

$CLOSE CCnr;
}


/******************************************************************************
* RecuperarFinCalculo
* Pasa a todos los vectores de movimientos de facturas (ciclo o cnr) la fecha
* hasta la cual se esta facturando
*******************************************************************************/
void RecuperarFinCalculo( vInteresFC, vInteresCNR, fechaHoy,
                          indexFC, indexCNR )
Tinteres  vInteresFC[];
TvecCnr   vInteresCNR[];
TCfecha   fechaHoy;
int       *indexFC;
int       *indexCNR;

{
int i;
int index;

   if (*indexFC > 0)
      {
       BuscarMemoria(indexFC, MAXROWSFAC);
       vInteresFC[*indexFC-1].valor = 0.0;
       vInteresFC[*indexFC-1].tipoOperacion = FIN;
       vInteresFC[*indexFC-1].fecha_vencimiento = fechaHoy;
       vInteresFC[*indexFC-1].correlativo = 0;
      }

   if (*indexCNR > 0)
      {
       for (i=0; i < *indexCNR; i++)
          {
           BuscarMemoria(&vInteresCNR[i].index, MAXROWSAUX);
           index = (vInteresCNR[i].index) - 1;

           vInteresCNR[i].vCnr[index].valor = 0.0;
           vInteresCNR[i].vCnr[index].tipoOperacion = FIN;
           vInteresCNR[i].vCnr[index].fecha_vencimiento = fechaHoy;
           vInteresCNR[i].vCnr[index].correlativo = 0;
          }
      }
}


/******************************************************************************
* BuscarMemoria
* Se controla el maximo de elementos de los vectores.
*******************************************************************************/
void BuscarMemoria(index, max)
int       *index;
int       max;
{
 if (((*index % max) == 0) && (*index != 0))
    {
     fprintf ( stderr , "Se ha superado el maximo de %ld elementos del vector."
                        "(calc_int). \n", max );
     exit(1);
    }
 (*index)++;
}

/******************************************************************************
* RecuperarPagos
* Recupera los pagos del cliente
*******************************************************************************/
int RecuperarPagos( registroPago, cliente )
$parameter Tpagco registroPago[];
$parameter Tcliente cliente;
{
int cantReg ;
int huboPagoDeAnticipo = 0;
$Tpagco *regPago;

   regPago = ObtenerPrimerPagoCliente (cliente.numeroCliente);

   for (cantReg=0; regPago != NULL; cantReg++)
      {
       registroPago[cantReg] = (*regPago);
       regPago = ObtenerSiguientePagoCliente (cliente.numeroCliente);
      }

return (cantReg);

}


/******************************************************************************
* RecuperarConvenios
* Recupero los convenios del cliente dentro de un array de convenios
*******************************************************************************/
void RecuperarConvenios( aConvenio, numeroCliente, indexConvenio,
                         minima_fecha_cnr, baseInteresConvenioCad, fechaCaducado,
                         fechaHoy, fechaUltFac)
TConvenio        aConvenio[];
TCnumeroCliente  numeroCliente;
int              *indexConvenio;
TCfecha          minima_fecha_cnr;
TCvalor          baseInteresConvenioCad;
TCfecha          fechaCaducado;
TCfecha          fechaHoy;
$TCfecha         fechaUltFac;
{
$TCvalor               monto;
$TCfecha               fecha_vigencia;
$TCfecha               fecha_caducado;
$TCnumeroCliente       numero_cliente;
$TCfecha               fecha_minima;
$TCcorrConvenio        correlativo;

numero_cliente = numeroCliente;
fecha_minima = minima_fecha_cnr;

$OPEN CConvenio USING $numero_cliente,
                      $fecha_minima,
                      $fechaUltFac,
                      $fechaHoy,
                      $fechaHoy;

$FETCH CConvenio INTO $fecha_vigencia,
                      $fecha_caducado,
                      $monto,
                      $correlativo;

while (SQLCODE != SQLNOTFOUND)
   {
    BuscarMemoria(indexConvenio, MAXROWSAUX);
    aConvenio[*indexConvenio-1].fecha_vigencia = fecha_vigencia;
    aConvenio[*indexConvenio-1].correlativo = correlativo;

    if (!risnull(CLONGTYPE, (void *) &(fecha_caducado)) && fecha_caducado <= fechaHoy)
       {
        aConvenio[*indexConvenio-1].fecha_caducado = fecha_caducado;
        aConvenio[*indexConvenio-1].monto = monto;
       }
    else
       {
        aConvenio[*indexConvenio-1].fecha_caducado = fechaCaducado;
        aConvenio[*indexConvenio-1].monto = 0;
       }

    $FETCH CConvenio INTO $fecha_vigencia,
                          $fecha_caducado,
                          $monto,
                          $correlativo;
   }

$CLOSE CConvenio;
}


/******************************************************************************
* CopiaCnr
* Busca las facturas cnr que vencen en le periodo y las pasa al vector de
* movimientos de facturas cnr
*******************************************************************************/
void CopiaCnr( vInteresCNR, indexCNR, aFactCnr, indexFactCnr,
               aConvenio, indexConvenio, buscoPagos, registroHisfac,
               fechaUltimaFact, fechaHoy)   /*PDP - Proyecto Saldo en Disputa - Se agrega parametro fechaHoy*/
TvecCnr   vInteresCNR[];
int       *indexCNR;
TArrCnr   aFactCnr[];
int       indexFactCnr;
TConvenio aConvenio[];
int       indexConvenio;
int       *buscoPagos;
Thisfac   *registroHisfac;
TCfecha   fechaUltimaFact;
TCfecha   fechaHoy;
{
$TCvalor               monto;
$TCfecha               fecha_vencimiento;
$TCfecha               fecha_emision;
$TCcorrFacturacion     corr_facturacion;
int                    index = 0;
int                    i;
int                    j;
int                    Copiar;
TSdCnr                 *regSdCnr;
TSdCnr                 regCnrKey;

 for (i = 0; i<indexFactCnr; i++)
   {
    if (!(risnull(CLONGTYPE, (void *) &(aFactCnr[i].fecha_anulacion))))
        Copiar = FALSE;
    else
        Copiar = TRUE;

    for (j=0; (j < indexConvenio) && Copiar; j++)
        {
         if ((aConvenio[j].fecha_vigencia >= aFactCnr[i].fecha_emision) &&
             (aConvenio[j].fecha_vigencia < aFactCnr[i].fecha_vencimiento))
            Copiar = FALSE;
        }

    if (Copiar)
       {
        BuscarMemoria(indexCNR, MAXROWSAUX);
        vInteresCNR[*indexCNR-1].index = 0;
        vInteresCNR[*indexCNR-1].iParent = i ;
        BuscarMemoria(&vInteresCNR[*indexCNR-1].index, MAXROWSAUX);
        index = (vInteresCNR[*indexCNR-1].index) - 1;

        if (aFactCnr[i].fecha_vencimiento > aFactCnr[i].fecha_emision)
           vInteresCNR[*indexCNR-1].vCnr[index].fecha_vencimiento =
                                                   aFactCnr[i].fecha_vencimiento;
        else
           vInteresCNR[*indexCNR-1].vCnr[index].fecha_vencimiento =
                                                   aFactCnr[i].fecha_emision;

        vInteresCNR[*indexCNR-1].vCnr[index].valor = aFactCnr[i].valor;
        vInteresCNR[*indexCNR-1].vCnr[index].tipoOperacion = CNR;
        vInteresCNR[*indexCNR-1].vCnr[index].correlativo = 0;
        vInteresCNR[*indexCNR-1].aCnr[index].fecha_emision = aFactCnr[i].fecha_emision;
        vInteresCNR[*indexCNR-1].aCnr[index].corr_facturacion = aFactCnr[i].corr_facturacion;

        /* PDP - Proyecto Saldos en disputa */
        for (j = 0; j<aFactCnr[i].cantSd; j++)
           {
            if (aFactCnr[i].aSdCnr[j].fecha_autoriza > fechaUltimaFact &&
				aFactCnr[i].aSdCnr[j].fecha_autoriza <= fechaHoy)
            {
                BuscarMemoria(&vInteresCNR[*indexCNR-1].index, MAXROWSAUX);
                index = (vInteresCNR[*indexCNR-1].index) - 1;
                vInteresCNR[*indexCNR-1].vCnr[index].tipoOperacion = SD_AUTORIZ;
                vInteresCNR[*indexCNR-1].vCnr[index].fecha_vencimiento = aFactCnr[i].aSdCnr[j].fecha_autoriza;
                vInteresCNR[*indexCNR-1].vCnr[index].valor = aFactCnr[i].aSdCnr[j].monto;
                vInteresCNR[*indexCNR-1].vCnr[index].correlativo = 0;
            }

            if (aFactCnr[i].aSdCnr[j].fecha_finalizacion > fechaUltimaFact &&
				aFactCnr[i].aSdCnr[j].fecha_finalizacion <= fechaHoy)
            {
                BuscarMemoria(&vInteresCNR[*indexCNR-1].index, MAXROWSAUX);
                index = (vInteresCNR[*indexCNR-1].index) - 1;
                vInteresCNR[*indexCNR-1].vCnr[index].tipoOperacion = SD_RESOL;
                vInteresCNR[*indexCNR-1].vCnr[index].fecha_vencimiento = aFactCnr[i].aSdCnr[j].fecha_finalizacion;
                vInteresCNR[*indexCNR-1].vCnr[index].valor = aFactCnr[i].aSdCnr[j].monto;
                vInteresCNR[*indexCNR-1].vCnr[index].correlativo = 0;

				if (aFactCnr[i].aSdCnr[j].fecha_autoriza &&
					aFactCnr[i].aSdCnr[j].fecha_autoriza <= fechaUltimaFact)
				{
                	BuscarMemoria(&vInteresCNR[*indexCNR-1].index, MAXROWSAUX);
                	index = (vInteresCNR[*indexCNR-1].index) - 1;
                	vInteresCNR[*indexCNR-1].vCnr[index].tipoOperacion = SD_AUTORIZ;
                	vInteresCNR[*indexCNR-1].vCnr[index].fecha_vencimiento = fechaUltimaFact;
                	vInteresCNR[*indexCNR-1].vCnr[index].valor = aFactCnr[i].aSdCnr[j].monto;
                	vInteresCNR[*indexCNR-1].vCnr[index].correlativo = 0;
				}
				if (aFactCnr[i].aSdCnr[j].fecha_autoriza <= fechaUltimaFact)
                	(*registroHisfac).saldoAntSujInt += aFactCnr[i].aSdCnr[j].monto;

            	/* si aFactCnr[i].aSdCnr[j].fecha_finalizacion = 0 quiere decir que es nula */
            	if (aFactCnr[i].aSdCnr[j].fecha_finalizacion <= fechaUltimaFact &&
					aFactCnr[i].aSdCnr[j].fecha_finalizacion > 0)
                		(*registroHisfac).saldoAntSujInt -= aFactCnr[i].aSdCnr[j].monto;
			}

           }
        /* Fin PDP */
       }

    if (( (risnull(CLONGTYPE, (void *) &(aFactCnr[i].fecha_anulacion))) &&
          (aFactCnr[i].fecha_emision <= fechaUltimaFact) ) ||
        ( !(risnull(CLONGTYPE, (void *) &(aFactCnr[i].fecha_anulacion))) &&
           (aFactCnr[i].fecha_anulacion > fechaUltimaFact)))
                /* PJP - 09/08/2002 - Se incluye el = */
            (*registroHisfac).saldoAntSujInt -= aFactCnr[i].valor;
   }

 if (*indexCNR > 0)
   *buscoPagos = TRUE;
}


/******************************************************************************
* CopiaNC
* Cargo las notas de credito del periodo y periodos anteriores.
*******************************************************************************/
void CopiaNC( arrayNotas, cantNotas, aConvenio, indexConvenio, fechaUltimaFact)
Trefac    arrayNotas[];
int       cantNotas;
TConvenio *aConvenio;
int       indexConvenio;
TCfecha   fechaUltimaFact;

{
int   i;
int   j;

 for (i = 0; i < cantNotas; i++)
    {
     if (strcmp(arrayNotas[i].tipoNota, "C") == 0)
        {
         for (j=0; j < indexConvenio; j++)
            {
             if ((aConvenio[j].fecha_vigencia >= fechaUltimaFact) &&
                 (aConvenio[j].fecha_vigencia < arrayNotas[i].fechaRefacturac))
                if ((aConvenio[j].fecha_vigencia > fechaUltimaFact) ||
                    (arrayNotas[i].fechaFactAfect < fechaUltimaFact))
                   /* PJP - 09/08/2002 - No se restan las notas cuando se hace el convenio
                      el mismo día de la última factura y la nota afecta a esa factura
                      porque se asume que la factura no entró al convenio. */
                   aConvenio[j].monto -=fabs(arrayNotas[i].totRefacSujInt);
            }
        }
    }
}


/******************************************************************************
* CopiaConvenios
* Copio los convenios a los vectores de facturas de ciclo y cnr.
*******************************************************************************/
void CopiaConvenios(vInteresCNR, indexCNR, vInteresFC, indexFC,
                    aConvenio, indexConvenio, fechaUltimaFact, buscoPagos)
TvecCnr    vInteresCNR[];
int        *indexCNR;
Tinteres   vInteresFC[];
int        *indexFC;
TConvenio  aConvenio[];
int        indexConvenio;
TCfecha    fechaUltimaFact;
int        *buscoPagos;
{
int i;
int j;
int index;
 for (j=0; j<indexConvenio; j++)
    {
     if (aConvenio[j].fecha_caducado > fechaUltimaFact)
        {
         if (*indexFC > 0)
            {
             /*Paso inicio de convenio*/
             BuscarMemoria(indexFC, MAXROWSFAC);
             vInteresFC[*indexFC-1].valor = 0.0;
             vInteresFC[*indexFC-1].tipoOperacion = CONVENIO;
             vInteresFC[*indexFC-1].fecha_vencimiento = aConvenio[j].fecha_vigencia;
             vInteresFC[*indexFC-1].correlativo = aConvenio[j].correlativo;

             /*Paso fin de convenio*/
             BuscarMemoria(indexFC, MAXROWSFAC);
             vInteresFC[*indexFC-1].valor = aConvenio[j].monto;
             vInteresFC[*indexFC-1].tipoOperacion = CONVCAD;
             vInteresFC[*indexFC-1].fecha_vencimiento = aConvenio[j].fecha_caducado;
             vInteresFC[*indexFC-1].correlativo = aConvenio[j].correlativo;
             if ( vInteresFC[*indexFC-1].valor >= 0.01 )
                 *buscoPagos = TRUE;
            }

         if (*indexCNR > 0)
            {
             for (i=0; i < *indexCNR; i++)
                {
                 if (aConvenio[j].fecha_vigencia >= vInteresCNR[i].aCnr[0].fecha_emision)
                    {
                     /*Paso inicio de convenio*/
                     BuscarMemoria(&vInteresCNR[i].index, MAXROWSAUX);
                     index = (vInteresCNR[i].index) - 1;

                     vInteresCNR[i].vCnr[index].valor = 0.0;
                     vInteresCNR[i].vCnr[index].tipoOperacion = CONVCNR;
                     vInteresCNR[i].vCnr[index].fecha_vencimiento = aConvenio[j].fecha_vigencia;
                     vInteresCNR[i].vCnr[index].correlativo = aConvenio[j].correlativo;
                    }
                }
            }
        }
    }
}


/******************************************************************************
* PasoPagosCNRaFC
*Paso los pagos de facturas cnr posteriores al inicio de un convenio al
*vector de la factura de ciclo.
*******************************************************************************/
void PasoPagosCNRaFC(vInteresFC, indexFC, vInteresCNR, indexCNR)
Tinteres   vInteresFC[];
int        *indexFC;
TvecCnr    vInteresCNR[];
int        indexCNR;
{
int  i;
int  j;
int  Seguir;

 for (i=0; i < indexCNR; i++)
    {
     Seguir = TRUE;
     for (j=0; (j < vInteresCNR[i].index) && Seguir ; j++)
        {
         if (vInteresCNR[i].vCnr[j].tipoOperacion == CONVCNR)
            Seguir = FALSE;
        }

     for (j=j; j < vInteresCNR[i].index; j++)
        {
         /* PDP - Proyecto Saldos en disputa */
         /*if (vInteresCNR[i].vCnr[j].tipoOperacion == PAGO)*/
         if (vInteresCNR[i].vCnr[j].tipoOperacion == PAGO ||
             vInteresCNR[i].vCnr[j].tipoOperacion == SD_AUTORIZ ||
             vInteresCNR[i].vCnr[j].tipoOperacion == SD_RESOL )
            {
             BuscarMemoria(indexFC, MAXROWSFAC);
             vInteresFC[*indexFC-1].valor = vInteresCNR[i].vCnr[j].valor;
             vInteresFC[*indexFC-1].tipoOperacion = vInteresCNR[i].vCnr[j].tipoOperacion;
             vInteresFC[*indexFC-1].fecha_vencimiento =
                                               vInteresCNR[i].vCnr[j].fecha_vencimiento;
             vInteresFC[*indexFC-1].correlativo = vInteresCNR[i].vCnr[j].correlativo;
            }
        }
    }
}

/******************************************************************************
* RecuperarSdosDisp
* Busca los saldos en disputa vigentes y finalizados del periodo y
* los pasa al array de facturas de ciclo
*******************************************************************************/
void RecuperarSdosDisp(vInteresFC, indexFC, fechaHoy, cliente)
Tinteres  vInteresFC[];
int       *indexFC;
$PARAMETER TCfecha  fechaHoy;
Tcliente  cliente;
{
$TCvalor               monto=0;
$TCfecha               fecha_autoriza=0;
$TCfecha               fecha_finalizacion=0;
$char                  estado [ 2 ] ;

$OPEN CSdoDisp USING $cliente.fechaUltimaFact,
					 $fechaHoy,
					 $cliente.numeroCliente,
                     $cliente.fechaUltimaFact,
                     $fechaHoy,
                     $cliente.fechaUltimaFact,
                     $fechaHoy,
                     $cliente.fechaUltimaFact,
                     $fechaHoy,
                     $fechaHoy;

$FETCH CSdoDisp INTO $monto,
                     $fecha_autoriza,
                     $fecha_finalizacion,
                     $estado;

while (SQLCODE != SQLNOTFOUND)
   {
    if (!strcmp(estado, "V") || (!strcmp(estado, "F") && fecha_finalizacion < fechaHoy)) 
    {
        BuscarMemoria(indexFC, MAXROWSFAC);
    	vInteresFC[*indexFC-1].tipoOperacion = (!strcmp(estado, "V")) ? SD_AUTORIZ : SD_RESOL;
        vInteresFC[*indexFC-1].valor = monto;
        vInteresFC[*indexFC-1].fecha_vencimiento = (!strcmp(estado, "V")) ? fecha_autoriza : fecha_finalizacion;
        vInteresFC[*indexFC-1].correlativo = 0;
    }

    if (!strcmp(estado, "F") && fecha_autoriza > cliente.fechaUltimaFact && fecha_autoriza <= fechaHoy)
       {
        BuscarMemoria(indexFC, MAXROWSFAC);
        vInteresFC[*indexFC-1].tipoOperacion = SD_AUTORIZ;
        vInteresFC[*indexFC-1].valor = monto;
        vInteresFC[*indexFC-1].fecha_vencimiento = fecha_autoriza <= cliente.fechaUltimaFact? cliente.fechaUltimaFact: fecha_autoriza;
        vInteresFC[*indexFC-1].correlativo = 0;
       }
		monto = 0;
    	fecha_autoriza = 0;
    	fecha_finalizacion = 0;

    $FETCH CSdoDisp INTO $monto,
                         $fecha_autoriza,
                         $fecha_finalizacion,
                         $estado;
   }

$CLOSE CSdoDisp;

}

/******************************************************************************
* RecuperarSdosDispCnr
* Busca los saldos en disputa vigentes y finalizados de los CNR
*******************************************************************************/
void RecuperarSdosDispCnr(aFactCnr, indexFactCnr, fechaHoy)
$TArrCnr   aFactCnr[];
int        indexFactCnr;
$long      fechaHoy;
{
int             i;
int             j;
int             cant;
$TCvalor        monto=0;
$TCfecha        fecha_autoriza=0;
$TCfecha        fecha_finalizacion=0;

    for (i = 0; i<indexFactCnr; i++)
       {
        $OPEN CSDcnrStr USING $aFactCnr[i].nro_expediente,
                              $aFactCnr[i].ano_expediente,
                              $aFactCnr[i].sucursal,
                              $fechaHoy;

        $FETCH CSDcnrStr INTO $monto,
                              $fecha_autoriza,
                              $fecha_finalizacion;

        while (SQLCODE != SQLNOTFOUND)
           {
            BuscarMemoria(&aFactCnr[i].cantSd, MAXROWSFAC);
            cant = (aFactCnr[i].cantSd) - 1;
            aFactCnr[i].aSdCnr[cant].monto = monto;
            aFactCnr[i].aSdCnr[cant].fecha_autoriza = fecha_autoriza;
            aFactCnr[i].aSdCnr[cant].fecha_finalizacion = fecha_finalizacion;

			monto=0;
            fecha_autoriza=0;
            fecha_finalizacion = 0;

            $FETCH CSDcnrStr INTO $monto,
                                  $fecha_autoriza,
                                  $fecha_finalizacion;
           }

        $CLOSE CSDcnrStr;
       }
}

void ImprimirEventos (Tinteres  *vInteres, int i, TCvalor baseCalculo )
{
    char sFechaDesde[11];
    char sFechaHasta[11];
    char sEvento[100];

    if (i > 0)
        rfmtdate (vInteres[i-1].fecha_vencimiento, "dd/mm/yyyy", sFechaDesde);
	else sFechaDesde[0] = '\0';

    rfmtdate (vInteres[i].fecha_vencimiento, "dd/mm/yyyy", sFechaHasta);

    switch (vInteres[i].tipoOperacion)
    {
        case SALDOANT:
            strcpy(sEvento,"SALDO_ANTERIOR");
            break;
        case TOTFACT:
            strcpy(sEvento,"TOTAL_FACTURADO");
            break;
        case CNR:
            strcpy(sEvento,"TOTAL_FACTURADO CNR");
            break;
        case CONVCAD:
            strcpy(sEvento,"CADUCACION_CONVENIO");
            break;
        case PAGO:
            strcpy(sEvento,"PAGO");
            break;
        case FIN:
            strcpy(sEvento,"FIN");
            break;
        case CONVCNR:
            strcpy(sEvento,"CONVENIO_CNR");
            break;
        case CONVENIO:
            strcpy(sEvento,"CONVENIO");
            break;
        case SD_AUTORIZ:
            strcpy(sEvento,"AUTORIZACION SD");
            break;
        case SD_RESOL:
            strcpy(sEvento,"RESOLUCION SD");
            break;
    }
	if(fEvenCalInt != NULL)
		fprintf(fEvenCalInt, "%19s monto: % 010.2f - Calcula Int. a: % 010.2f  desde: %10s hasta: %10s\n",
				sEvento, vInteres[i].valor, baseCalculo, sFechaDesde, sFechaHasta);
}
