$ ifndef CALC_INT_H;
$ define CALC_INT_H;

$include cliente.h;
$include hisfac.h;
$include pagco.h;
$include codigos.h;

/*Constantes utilizadas para tipo de operacion en los vectores de movimiento*/
/*
$define  PAGO       	  1;	 //Pago de factura
$define  CONVENIO   	  2;	 //Inicio Convenio
$define  CONVCAD    	  3;	 //Convenio caducado
$define  SALDOANT   	  4;	 //Saldo de la factura anterior
$define  TOTFACT    	  5;	 //Total facturado
$define  CNR        	  6;   //Cnr vencido
$define  CONVCNR       7;   //Inicio de convenios en vector de cnr.
$define  FIN        	  8;	 //Fin de periodo de corte
*/
		/* PDP - Proyecto Saldos en disputa */
$define  PAGO       	  1;	 //Pago de factura
$define  SD_AUTORIZ 	  2;	 //Autorizacion de Saldo en Disputa
$define  SD_RESOL   	  3;	 //Resolucion de Saldo en Disputa
$define  CONVENIO   	  4;	 //Inicio Convenio
$define  CONVCAD    	  5;	 //Convenio caducado
$define  SALDOANT   	  6;	 //Saldo de la factura anterior
$define  TOTFACT    	  7;	 //Total facturado
$define  CNR        	  8;	 //Cnr vencido
$define  CONVCNR    	  9;	 //Inicio de convenios en vector de cnr.
$define  FIN        	 10;	 //Fin de periodo de corte

$define  MAXROWSFAC    50;  //Cantidad de elementos de los vectores de facturas
$define  MAXROWSAUX    40;  //Cantidad de elementos de los vectores auxiliares.

/*Encabezado de procedimientos del modulo calc_cli.ec*/
/* estructura de los nodos necesarios para el calculo de interes */
$ typedef struct recInteres
   {
   int             tipoOperacion;
   TCvalor         valor;
   TCfecha         fecha_vencimiento;
   TCcorrConvenio  correlativo;
   }Tinteres;

/* estructura de los nodos complementarios para el armado del vector
   de movimientos de cnr */
$ typedef struct addCnr
   {
   TCfecha            fecha_emision;
   TCcorrFacturacion  corr_facturacion;
   }TaddCnr;

/* estructura del vector de movimientos cnr */
$ typedef struct recCnr
   {
    Tinteres  vCnr[MAXROWSAUX];
    TaddCnr   aCnr[MAXROWSAUX];
    int       index;
    int       iParent ;
   }TvecCnr;

/* estructura utilizada para recuperar los pagos CNR */
$ typedef struct vecPago
   {
    TCcorrFacturacion    corr_facturacion;
    TCcorrPago           corr_pago;
    TCvalor              monto_pago;
    TCfecha              fecha_pago;
    int                  procesado;
   }TPagoCnr;

/* estructura utilizada para recuperar los convenios */
$ typedef struct vecConvenio
   {
    TCfecha              fecha_vigencia;
    TCfecha              fecha_caducado;
    TCvalor              monto;
    TCcorrConvenio       correlativo;
   }TConvenio;

/* PDP - Proyecto Saldos en Disputa */
/* estructura utilizada para recuperar los sd de los cnr en un array */
$ typedef struct SdCnr
   {
    TCvalor              monto;
    TCfecha              fecha_autoriza;
    TCfecha              fecha_finalizacion;
  }TSdCnr;

/* estructura utilizada para recuperar los cnr en un array */
$ typedef struct arrCnr
   {
    TCvalor              valor;
    TCfecha              fecha_vencimiento;
    TCfecha              fecha_emision;
    TCcorrFacturacion    corr_facturacion;
    string               tipo_docto [ 7 ] ;
    char                 c_s_querella [ 2 ] ;
	TCfecha				 fecha_anulacion;
    /* PDP - Proyecto Saldos en Disputa */
    int                  nro_expediente;
    int                  ano_expediente;
    string               sucursal [ 5 ];
    int                  cantSd;
    TSdCnr               aSdCnr[MAXROWSFAC];
  }TArrCnr;

void CalcularIntereses (
       Tcliente cliente,
       TCvalor  totalNCAnterior,
       TCvalor  totalNCPeriodo,
       Thisfac  registroHisfac,
       TCvalor  baseInteresConvenioCad,
       TCfecha  fechaCaducado,
       Trefac   arrayNotas[],
       int      cantNotas,
       long     lFechaFacturacion);

void RecuperarSaldosAnt(
       Tinteres  vInteresFC[MAXROWSFAC],
       Thisfac   *registroHisfac,
       TCfecha   fechaUltimaFact,
       TCvalor   *totalNCAnterior,
       int       *indexFC,
       int       *buscoPagos,
       int       tieneHisFac);

void RecuperarTotalFac(
       Tinteres  vInteresFC[MAXROWSFAC],
       Thisfac   registroHisfac,
       TCvalor   totalNCPeriodo,
       int       *indexFC,
       int       *buscoPagos,
       TConvenio aConvenio[MAXROWSAUX],
       int       indexConvenio);

void CopiaPagos(
       long      numeroCliente,
       Tinteres  vInteresFC[MAXROWSFAC],
       TvecCnr   vInteresCNR[MAXROWSAUX],
       Tpagco    registroPago[CANT_MAX_PAGOS_PERIODO],
       int       cantFilasPagos,
       int       *indexFC,
       int       *indexCNR);

void OrdenarVector(
       Tinteres  *vInteres,
       int       index);

/*int InteresQsort(
       Tinteres *conceptoUno,
       Tinteres *conceptoDos);*/

int InteresQsort(const void *, const void *); /*Se modifico para migracion a AIX*/

/* PDP - OM2148 - Se agrega codigo valor */
TCvalor CalcularInteres(
       Tinteres  *vInteres,
       int       index,
       char      *sCodigoValor);

void BuscarPagoCnr(
       TCnumeroCliente   numeroCliente,
       TPagoCnr          pagoCnr[MAXROWSAUX],
       int               *cantPagosCnr,
       TvecCnr           vInteresCNR[MAXROWSAUX],
       int               indexCNR);

void RecuperarCnr(
       TArrCnr   aFactCnr[MAXROWSAUX],
       Tcliente  cliente,
       int       *indexFactCnr,
       TCfecha   fechaHoy,
       TCfecha   *minima_fecha_cnr);

void RecuperarFinCalculo(
       Tinteres  vInteresFC[MAXROWSFAC],
       TvecCnr   vInteresCNR[MAXROWSAUX],
       TCfecha   fechaHoy,
       int       *indexFC,
       int       *indexCNR);

void BuscarMemoria(
       int       *index,
       int       max);

int RecuperarPagos(
       Tpagco   registroPago[CANT_MAX_PAGOS_PERIODO],
       Tcliente cliente);

void RecuperarConvenios(
       TConvenio       aConvenio[MAXROWSAUX],
       TCnumeroCliente numeroCliente,
       int             *indexConvenio,
       TCfecha         minima_fecha_cnr,
       TCvalor         baseInteresConvenioCad,
       TCfecha         fechaCaducado,
       TCfecha         fechaHoy,
       TCfecha         fechaUltFac);

void CopiaCnr(
       TvecCnr   vInteresCNR[MAXROWSAUX],
       int       *indexCNR,
       TArrCnr   aFactCnr[MAXROWSAUX],
       int       indexFactCnr,
       TConvenio aConvenio[MAXROWSAUX],
       int       indexConvenio,
       int       *buscoPagos,
       Thisfac   *registroHisfac,
       TCfecha   fechaUltimaFact,
       TCfecha   fechaHoy);     /*PDP - Proyecto Saldo en Disputa - Se agrega parametro fechaHoy*/
void CopiaNC(
       Trefac    arrayNotas[],
       int       cantNotas,
       TConvenio aConvenio[MAXROWSAUX],
       int       indexConvenio,
       TCfecha   fechaUltimaFact);

void CopiaConvenios(
       TvecCnr    vInteresCNR[MAXROWSAUX],
       int        *indexCNR,
       Tinteres   vInteresFC[MAXROWSFAC],
       int        *indexFC,
       TConvenio  aConvenio[MAXROWSAUX],
       int        indexConvenio,
       TCfecha    fechaUltimaFact,
       int        *buscoPagos);

void PasoPagosCNRaFC(
       Tinteres   vInteresFC[MAXROWSAUX],
       int        *indexFC,
       TvecCnr    vInteresCNR[MAXROWSAUX],
       int        indexCNR);

/*PDP - Proyecto Saldo en Disputa*/
void RecuperarSdosDisp(
       Tinteres  vInteresFC[MAXROWSFAC],
       int       *indexFC,
       TCfecha   fechaHoy,
       Tcliente  cliente);

void RecuperarSdosDispCnr(
    TArrCnr    aFactCnr[MAXROWSFAC],
    int        indexFactCnr,
    long       fechaHoy);

/*PDP - Proyecto Saldo en Disputa */
void ImprimirEventos (Tinteres  *vInteres, int i, TCvalor baseCalculo );

$ endif;
