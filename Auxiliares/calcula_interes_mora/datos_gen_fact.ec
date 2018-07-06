/*------------------------------------------------------------------------+
 |  Fuente      : datos_gen.ec                                            |
 |  Tipo        : Fuente que define las funciones para operar             |
 |                con la estruct. de datos gen.                           |
 |  Parametros  :                                                         |
 |  Autor       : Gerardo Matias Ratto                                    |
 |  Fecha       : 22/02/1995                                              |
 |  Descripcion :                                                         |
 |                                                                        |
 |  Parametros  :                                                         |
 |  Autor       : Patricia Prestia                                        |
 |  Fecha       : Octubre 1997                                            |
 |  Descripcion : Se agrego a la rutina que cuenta la cantidad de         |
 |                conceptos de tarifa para un cliente, que tomara         |
 |                en cuenta los conceptos resultantes de la valorizacion  |
 |                de consumos convenidos (estado de agenda =              |
 |                EST_AGE_TAR_CONS_CONV )                                 |
 |                                                                        |
 |  Parametros  :                                                         |
 |  Autor       : Andres Galaz V.                                         |
 |  Fecha       : 25/11/1997                                              |
 |  Descripcion : Se optimizan las funciones que utilizan rango de        |
 |                clientes, se separa con un IF para poner una SQL con    |
 |                numero de cliente individual y otra con rango de        |
 |                clientes.                                               |
 |                Ademas a algunas SQL se les saca la llamada la tabla    |
 |                hisfac_cont_temp.                                            |
 |  Autor       : PHA                                                     |
 |  Fecha       : Diciembre 1997                                          |
 |  Descripcion : Se corrige el select de las funciones:                  |
 |                ObtenerCantRegPagosParaInteresesAnteriores y            |
 |                ObtenerArrayPagosParaInteresesAnteriores                |
 |                                                                        |
 |  Autor       : Marisa Rodriguez                                        |
 |  Fecha       : 11/05/1998                                              |
 |  Descripcion : Se agrego a la estructura datosGen el campo             |
 |                deudaMinNotificacion.                                   |
 |                                                                        |
 |  Autor       : Marisa Rodriguez                                        |
 |  Fecha       : 08/09/1998                                              |
 |  Descripcion : Se mofifico la funcion  ObtenerRegVencimDep() y         |
 |                ObtenerCantRegVencimDep () para que considere que el    /
 /                anio es mayor = al anio actual.                         |
 |                                                                        |
 |  Autor       : Pablo Fernandez                                         |
 |  Fecha       : 05/08/1999                                              |
 |  Descripcion : Se multiplica el porcentaje del recargo por un          |
 |                incremento de tasa segun Res. 736.                      |
 |                                                                        |
 |  Autor       : Pablo Fernandez                                         |
 |  Fecha       : 04/11/1999                                              |
 |  Descripcion : Se deja sin efecto la utilizacion de la tabla           |
 |                vencim_dep. Se elimina la carga de la tabla (OM581).    |
 |                                                                        |
 |  Autor       : Pablo Fernandez                                         |
 |  Fecha       : 07/04/2000                                              |
 |  Descripcion : Se corrigen errores de logica y de manejo de cursores   |
 |                de la funcion EsDiaFeriado que NUNCA estuvo funcionando.|
 |                                                                        |
 |  Autor       : Jorge Zambrana                                          |
 |  Fecha       : 03/02/2001                                              |
 |  Descripcion : Se agrega al recupero de pagos de intereses la condicion|
 |                de tipo pago != TIPO_PAGO_ANTICIPO_CONVENIO y se elimina|
 |                la carga de pagos para intereses anteriores.            |

 |  Autor       : Pablo D Privitera                                       |
 |  Fecha       : 10/06/2004                                              |
 |  Descripcion : Se agregaron datos de reactiva en lectura de lectu de la|
 |                funcion ObtenerArrayLectu                               |
 +------------------------------------------------------------------------*/
#include <stdio.h>
#include <strings.h>
#include <time.h>
#include <string.h> /*Se incluye para migracion a AIX*/
#include <stdlib.h> /*Se incluye para migracion a AIX*/
$include datos_gen.h;
$include codigos.h;
$include mensajes.h;
$include pagco.h ;
$include errores.h; /*Se incluye para migracion a AIX*/
$include funcdt.h; /*Se incluye para migracion a AIX*/
$include sqltypes;

int ObtenerCantRegTabla(char *, char *, long); /*Se agregaron los tipos de los parametros para migracion a AIX*/

Ttabla *ObtenerArrayTabla(char *, int, char *, long); /*Se agregaron los tipos de los parametros para migracion a AIX*/
void AjustarDiasVencim();
int ObtenerCantRegCodca(long); /*Se agrega el tipo de parametro de la funcion para migracion a AIX*/
Tcodca *ObtenerArrayCodca(int,long); /*Se agregan los tipos de parametros para migracion a AIX*/
int ObtenerCantRegMensajesFijos(long); /*Se agrega el tipo de parametro para migracion a AIX*/
Tmensajes *ObtenerArrayMensajesFijos(int, long); /*Se agregan los tipos de los parametros para migracion a AIX*/
int ObtenerCantRegVenage(void); /*Se agrega el void por migracion a AIX*/
Tvenage *ObtenerArrayVenage(int); /*Se agrega el tipo del parametro para migracion a AIX*/
int ObtenerCantRegVenageProximo(void); /*Se agrega el void para migracion a AIX*/
Tvenage *ObtenerArrayVenageProximo(int); /*Se agrega el int por migracion a AIX*/


int           ObtenerCantRegConceptosPorAplicar(long); /*Se agrega el long por migracion a AIX*/

TcarcoConInt *ObtenerArrayConceptosPorAplicar(long, long); /*Se modifica por migracion a AIX*/

int           ComparaRegCarcoConInt (const void *, const void *); /*Se modifica por migracion a AIX*/

int           ObtenerCantRegConceptosTemporales(long, long); /*Se modifica por migracion a AIX*/

TarrieConInt *ObtenerArrayConceptosTemporales(long, long, long); /*Se modifica para migracion a AIX*/

/* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
int           ObtenerCantRegConceptosTemporalesPendientes(long, long); /*Se modifica por migracion a AIX*/

TarrieConInt *ObtenerArrayConceptosTemporalesPendientes(long, long, long); /*Se modifica para migracion a AIX*/

int           ComparaRegArrieConInt ();

int           ObtenerCantRegConceptosTarifa(long, long); /*Se modifica para migracion a AIX*/

TcarcoConInt *ObtenerArrayConceptosTarifa(long, long, long); /*Se modifica para migracion a AIX*/

int           ObtenerCantRegPagosParaIntereses(long, long); /*Se modifica para migracion a AIX*/

Tpagco       *ObtenerArrayPagosParaIntereses(long, long, long); /*Se modifica para migracion a AIX*/

int           ObtenerCantRegPagosParaInteresesAnteriores();
Tpagco       *ObtenerArrayPagosParaInteresesAnteriores();

int           ComparaRegPagco (const void *, const void *); /*Se modifica por migracion a AIX*/

int           ObtenerCantRegRefac(long, long); /*Se modifica por migracion a AIX*/
Trefac       *ObtenerArrayRefac(long, long, long); /*Se modifica para migracion a AIX*/
int           ObtenerCantRegRefacAnt(long); /*Se agrega el long por migreacion a AIX*/
Trefac       *ObtenerArrayRefacAnt(long, long); /*Se modifica por migracion a AIX*/
int           ComparaRegRefac (const void *, const void *); /*Se modifica por migracion a AIX*/

int           ObtenerCantRegLectu(long, long); /*Se modifica por migracion a AIX*/
Tlectu       *ObtenerArrayLectu(long, long, long); /*Se modifica por migracion a AIX*/
int           ComparaRegLectu ();


int           ObtenerCantRegDetalle(long, long); /*Se modifica por migracion a AIX*/
TdetValTarifas *ObtenerArrayDetalle(long, long, long); /*Se modifica por migracion a AIX*/
int           ComparaRegDetalle ();


int           ObtenerCantRegConsumo(long); /*Se agrega el long por migracion a AIX*/

Tconsumo      *ObtenerArrayConsumo(long, long); /*Se modifica por migracion a AIX*/
int           ComparaRegConsumo ();


int           ObtenerCantRegPromedio(long); /*Seagrega el long por migracion a AIX*/
Tpromedio     *ObtenerArrayPromedio(long, long); /*Se modifica por migracion a AIX*/

int           ComparaRegPromedio ();


long          ContarClientesConConveAnt(void); /*Se agrega el void por migracion a AIX*/
long         *ObtenerClientesConConveAnt(void); /*Se agrega el void por migracion a AIX*/
int           ComparaNumerosCliente ();

int           ObtenerCantRegConveCaducado(void); /*Se agrega el void por migracion a AIX*/
TconveCaducado *ObtenerArrayConveCaducado(void); /*Se agrega el void por migracion a AIX*/
int           ComparaRegConveCaducado(const void *, const void *); /*Se modifica por migracion a AIX*/

/* PDP - OM3245 */
int           ObtenerCantRegCliDDI(void);
TclientesDdi *ObtenerArrayCliDDI(long);
int           ComparaRegClienteDDI(const void *, const void *);
int           EsClienteDDI(long, double, int);
int           GrabaLogComprob(long, int, int *);
int           ObtenerNroComprobante(void);
int           BuscarNroComprob(long);
double        ObtenerSecuencia(void);

$static TdatosGen       datosGen;
static  int             noCargoDatosGen = SI;

static  TcarcoConInt  * ultimoCPADelCliente ;
static  TcarcoConInt  * CPAInicialDelCliente ;
static  TcarcoConInt  * finArrayConceptosPorAplicar ;
static  int             direccionProxCPA = ABAJO ;

static  TarrieConInt  * ultimoTempDelCliente ;
static  TarrieConInt  * tempInicialDelCliente ;
static  TarrieConInt  * finArrayConceptosTemporales ;
static  int             direccionProxTemp = ABAJO ;
/* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
static  TarrieConInt  * ultimoTempDelClientePendientes ;
static  TarrieConInt  * tempInicialDelClientePendientes ;
static  TarrieConInt  * finArrayConceptosTemporalesPendientes ;
static  int             direccionProxTempPendientes = ABAJO ;

static  TcarcoConInt  * ultimoCargoTarifaDelCliente ;
static  TcarcoConInt  * cargoTarifaInicialDelCliente ;
static  TcarcoConInt  * finArrayConceptosTarifa ;
static  int             direccionProxCargoTarifa = ABAJO ;

static  Tpagco  * ultimoPagoDelCliente ;
static  Tpagco  * pagoInicialDelCliente ;
static  Tpagco  * finArrayPagos ;
static  int       direccionProxPago = ABAJO ;

static  Tpagco  * ultimoPagoAntDelCliente ;
static  Tpagco  * pagoAntInicialDelCliente ;
static  Tpagco  * finArrayPagosAnt ;
static  int       direccionProxPagoAnt = ABAJO ;

static  Trefac  * ultimoRefacDelCliente ;
static  Trefac  * refacInicialDelCliente ;
static  Trefac  * finArrayRefac ;
static  int       direccionProxRefac = ABAJO ;

static  Trefac  * ultimoRefacAntDelCliente ;
static  Trefac  * refacAntInicialDelCliente ;
static  Trefac  * finArrayRefacAnt ;
static  int       direccionProxRefacAnt = ABAJO ;

static  Tlectu  * ultimoLectuDelCliente ;
static  Tlectu  * lectuInicialDelCliente ;
static  Tlectu  * finArrayLectu ;
static  int       direccionProxLectu = ABAJO ;

static  TdetValTarifas  * ultimoDetalleDelCliente ;
static  TdetValTarifas  * finArrayDetalle ;

/* Variable Global utilizada para los cursore dinamicos */
$static char gstrSql[20000];

$WHENEVER ERROR CALL ProcesaErrores;

/*****************************************************************************/

void RecuperarDatosGen( datosGenParam, lFechaFacturacion)
   $TdatosGen *datosGenParam;
   $long lFechaFacturacion;
{
   $Tinsta regInsta;
   Ttabla *regTabla;
   $TCcodigoValor codigoValorRecargo = COD_VALOR_RECARGO;
   time_t hora;

   if ( noCargoDatosGen )
   {
      noCargoDatosGen = NO;
      RegistraInicioSql("SELECT insta ");
      $SELECT insta.nombre_empresa,
              insta.nombre_emp_largo,
              insta.direccion,
              insta.rut,
              insta.dv_rut,
              insta.cant_sectores,
              insta.decimales,
              insta.limite_min30,
              insta.limite_max30,
              insta.limite_min60,
              insta.limite_max60,
              insta.nro_hist_fact,
              insta.nro_hist_conv,
              insta.nro_hist_refa,
              insta.nro_hist_corte,
              insta.nro_hist_pagos,
              insta.dias_valor,
              insta.per_min_factu,
              insta.cant_sel_caja,
              insta.param_sencillo,
              insta.dir_serv_central,
              insta.fec_ultmod_oficina,
              insta.fec_ultmod_cajero,
              insta.nro_empresa,
              insta.consumo_30_dias
         INTO :datosGen.regInsta.nombreEmpresa,
              :datosGen.regInsta.nombreEmpLargo,
              :datosGen.regInsta.direccion,
              :datosGen.regInsta.rut,
              :datosGen.regInsta.dvRut,
              :datosGen.regInsta.cantSectores,
              :datosGen.regInsta.decimales,
              :datosGen.regInsta.limiteMin30,
              :datosGen.regInsta.limiteMax30,
              :datosGen.regInsta.limiteMin60,
              :datosGen.regInsta.limiteMax60,
              :datosGen.regInsta.nroHistFact,
              :datosGen.regInsta.nroHistConv,
              :datosGen.regInsta.nroHistRefa,
              :datosGen.regInsta.nroHistCorte,
              :datosGen.regInsta.nroHistPagos,
              :datosGen.regInsta.diasValor,
              :datosGen.regInsta.perMinFactu,
              :datosGen.regInsta.cantSelCaja,
              :datosGen.regInsta.paramSencillo,
              :datosGen.regInsta.dirServCentral,
              :datosGen.regInsta.fecUltmodOficina,
              :datosGen.regInsta.fecUltmodCajero,
              :datosGen.regInsta.nroEmpresa,
              :datosGen.regInsta.consumo30Dias
         FROM insta ;
      RegistraInicioSql("SELECT preca Recargo");
      $SELECT p1.valor
         INTO :datosGen.porcentajeRecargo
         FROM preca p1
        WHERE p1.codigo_valor = :codigoValorRecargo AND
              p1.fecha = ( SELECT MAX(p2.fecha)
                             FROM preca p2
                            WHERE p2.fecha < current
                              AND p2.codigo_valor = :codigoValorRecargo );

/*** se multiplica por un incremento de tasa segun nuevas disposiciones (PMF - 08/1999) ***/
      datosGen.porcentajeRecargo = datosGen.porcentajeRecargo * INCREMENTO_TASA;

      strcpy( datosGen.codigoRecargo, COD_CARGO_RECARGO );
      strcpy( datosGen.tipoCargoRecargo, TIP_CON_RECARGO );
      RegistraInicioSql("SELECT sucursal");
      if ( datosGen.identifAgenda != 0 ) /* no se trata de finteractiva.exe */
      {
         $SELECT sucursal, sector
            INTO :datosGen.sucursal, :datosGen.sector
            FROM agenda
           WHERE agenda.identif_agenda = :datosGen.identifAgenda;
      }
      else
      {
         $SELECT sucursal, sector
            INTO :datosGen.sucursal, :datosGen.sector
            FROM cliente
           WHERE numero_cliente = :datosGen.numeroClienteInicial;
      };
      /*rtoday(&datosGen.fechaHoy);*/
      datosGen.fechaHoy = lFechaFacturacion; /* PDP - Calculo Interes Mora MAL */

	VerificarCESP(datosGen.fechaHoy, datosGen.sCESP, &datosGen.lFechaVigHasta);

    RegistraInicioSql("SELECT deuda_desde Notpar");
    $SELECT n.deuda_desde
     INTO :datosGen.deudaMinNotificacion
         FROM tabla t, notpar n
    WHERE  t.sucursal = :datosGen.sucursal AND
        t.nomtabla = 'SECTOR' AND
        t.codigo = :datosGen.sector AND
        t.valor_alf[1] = n.frecuencia AND
        t.fecha_activacion <= TODAY AND
        (t.fecha_desactivac is NULL or t.fecha_desactivac >= TODAY) AND
        t.sucursal = n.sucursal;

      datosGen.cantRegTablaTarif  = ObtenerCantRegTabla("TARIFA", "0000",
                                                         datosGen.fechaHoy );
      if( datosGen.cantRegTablaTarif > 0 )
         datosGen.arrayTablaTarif = ObtenerArrayTabla("TARIFA",
                                                   datosGen.cantRegTablaTarif,
                                                   "0000",
                                                   datosGen.fechaHoy );

      datosGen.cantRegTablaTipiva = ObtenerCantRegTabla("TIPIVA", "0000",
                                                        datosGen.fechaHoy );
      if( datosGen.cantRegTablaTipiva > 0 )
         datosGen.arrayTablaTipiva = ObtenerArrayTabla( "TIPIVA" ,
                                                    datosGen.cantRegTablaTipiva,
                                                    "0000",
                                                    datosGen.fechaHoy );

      datosGen.cantRegTablaSector = ObtenerCantRegTabla("SECTOR",
                                                        datosGen.sucursal,
                                                        datosGen.fechaHoy );
      if ( datosGen.cantRegTablaSector > 0 )
         datosGen.arrayTablaSector = ObtenerArrayTabla( "SECTOR" ,
                                                    datosGen.cantRegTablaSector,
                                                    datosGen.sucursal,
                                                    datosGen.fechaHoy );

      datosGen.cantRegTablaClalec = ObtenerCantRegTabla("CLALEC", "0000",
                                                        datosGen.fechaHoy );
      if ( datosGen.cantRegTablaClalec > 0 )
         datosGen.arrayTablaClalec = ObtenerArrayTabla( "CLALEC" ,
                                                    datosGen.cantRegTablaClalec,
                                                    datosGen.sucursal,
                                                    datosGen.fechaHoy );

      regTabla = ObtenerArrayTabla( "DATKWH",
                                    1,
                                    datosGen.sucursal,
                                    datosGen.fechaHoy );
      strncpy( datosGen.codigoValorKWHConvenio,
               regTabla[0].codigo,
               sizeof(TCcodigoValor) - 1 );

      datosGen.cantRegCodca = ObtenerCantRegCodca( datosGen.fechaHoy );

      if ( datosGen.cantRegCodca > 0 )
         datosGen.arrayCodca = ObtenerArrayCodca( datosGen.cantRegCodca,
                                                  datosGen.fechaHoy );

      datosGen.cantRegMensajesFijos = ObtenerCantRegMensajesFijos(
                                                            datosGen.fechaHoy );
      if ( datosGen.cantRegMensajesFijos > 0 )
         datosGen.arrayMensajesFijos = ObtenerArrayMensajesFijos(
                                                  datosGen.cantRegMensajesFijos,
                                                  datosGen.fechaHoy );

      datosGen.cantRegVenage = ObtenerCantRegVenage();
      if ( datosGen.cantRegVenage > 0 )
         datosGen.arrayVenage = ObtenerArrayVenage( datosGen.cantRegVenage );

      datosGen.cantRegVenageProximo  = ObtenerCantRegVenageProximo( );
      if ( datosGen.cantRegVenageProximo > 0 )
         datosGen.arrayVenageProximo = ObtenerArrayVenageProximo(
                                                datosGen.cantRegVenageProximo );

      datosGen.cantRegConceptosPorAplicar = ObtenerCantRegConceptosPorAplicar(
                                                       datosGen.identifAgenda );
      if ( datosGen.cantRegConceptosPorAplicar > 0 )
         datosGen.arrayConceptosPorAplicar = ObtenerArrayConceptosPorAplicar(
                                            datosGen.cantRegConceptosPorAplicar,
                                            datosGen.identifAgenda );

      datosGen.cantRegConceptosTemporales = ObtenerCantRegConceptosTemporales(
                                                         datosGen.identifAgenda,
                                                         datosGen.fechaHoy);
      if ( datosGen.cantRegConceptosTemporales > 0 )
         datosGen.arrayConceptosTemporales = ObtenerArrayConceptosTemporales(
                                            datosGen.cantRegConceptosTemporales,
                                            datosGen.identifAgenda ,
                                            datosGen.fechaHoy);

      /* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
      datosGen.cantRegConceptosTemporalesPendientes = ObtenerCantRegConceptosTemporalesPendientes(
                                                         datosGen.identifAgenda,
                                                         datosGen.fechaHoy);
      if ( datosGen.cantRegConceptosTemporalesPendientes > 0 )
         datosGen.arrayConceptosTemporalesPendientes = ObtenerArrayConceptosTemporalesPendientes(
                                            datosGen.cantRegConceptosTemporalesPendientes,
                                            datosGen.identifAgenda ,
                                            datosGen.fechaHoy);

      datosGen.cantRegConceptosTarifa = ObtenerCantRegConceptosTarifa(
                                                       datosGen.identifAgenda ,
                                                       datosGen.fechaHoy );
      if ( datosGen.cantRegConceptosTarifa > 0 )
         datosGen.arrayConceptosTarifa = ObtenerArrayConceptosTarifa(
                                               datosGen.cantRegConceptosTarifa ,
                                               datosGen.identifAgenda ,
                                               datosGen.fechaHoy );

      datosGen.cantRegPagosParaIntereses = ObtenerCantRegPagosParaIntereses(
                                                       datosGen.identifAgenda ,
                                                       datosGen.fechaHoy );
      if ( datosGen.cantRegPagosParaIntereses > 0 )
         datosGen.arrayPagosParaIntereses = ObtenerArrayPagosParaIntereses(
                                            datosGen.cantRegPagosParaIntereses ,
                                            datosGen.identifAgenda ,
                                            datosGen.fechaHoy );
      /*-------------------------------------------------------------------------+
      | FMO                                                                      |
      |    cargo registros de pagos para calcular intereses periodos anteriores  |
      | JZ                                                                       |
      |    no se carga el array de pagos de intereses anteriores ya que no se    |
      |    usa mas.                                                              |
      +-------------------------------------------------------------------------*/
      /*
      datosGen.cantRegPagosParaInteresesAnteriores =
           ObtenerCantRegPagosParaInteresesAnteriores( datosGen.identifAgenda );
      if ( datosGen.cantRegPagosParaInteresesAnteriores > 0 )
         datosGen.arrayPagosParaInteresesAnteriores =
                      ObtenerArrayPagosParaInteresesAnteriores(
                                  datosGen.cantRegPagosParaInteresesAnteriores ,
                                  datosGen.identifAgenda );
      */

      datosGen.cantRegRefac = ObtenerCantRegRefac( datosGen.identifAgenda ,
                                                   datosGen.fechaHoy );
      if ( datosGen.cantRegRefac > 0 )
         datosGen.arrayRefac = ObtenerArrayRefac( datosGen.cantRegRefac ,
                                                  datosGen.identifAgenda ,
                                                  datosGen.fechaHoy );

      /*-------------------------------------------------------------------------+
      | FMO                                                                     |
      |    carga en memoria refacturaciones del periodo anterior                |
      +-------------------------------------------------------------------------*/
      datosGen.cantRegRefacAnt = ObtenerCantRegRefacAnt(datosGen.identifAgenda);
      if ( datosGen.cantRegRefacAnt > 0 )
         datosGen.arrayRefacAnt = ObtenerArrayRefacAnt(datosGen.cantRegRefacAnt,
                                                       datosGen.identifAgenda);
      /*-------------------------------------------------------------------------+
      | FMO                                                                     |
      |    carga en memoria de los clientes con convenio otorgado en el periodo |
      |    anterior.                                                            |
      +-------------------------------------------------------------------------*/
      datosGen.cantConveAnt = ContarClientesConConveAnt();
      if ( datosGen.cantConveAnt > 0 )
         datosGen.arrayConveAnt = ObtenerClientesConConveAnt();

      /*-------------------------------------------------------------------------+
      | FMO                                                                     |
      |    Carga en memoria de los convenios caducados anteriores               |
      +-------------------------------------------------------------------------*/
      datosGen.cantConveCaducado = ObtenerCantRegConveCaducado();
      if ( datosGen.cantConveCaducado > 0 )
         datosGen.arrayConveCaducado = ObtenerArrayConveCaducado();

      datosGen.cantRegLectu = ObtenerCantRegLectu( datosGen.identifAgenda,
                                                   datosGen.fechaHoy );
      if ( datosGen.cantRegLectu > 0 )
         datosGen.arrayLectu = ObtenerArrayLectu( datosGen.cantRegLectu ,
                                                  datosGen.identifAgenda ,
                                                  datosGen.fechaHoy );

      datosGen.cantRegDetalle = ObtenerCantRegDetalle( datosGen.identifAgenda ,
                                                       datosGen.fechaHoy );
      if ( datosGen.cantRegDetalle > 0 )
         datosGen.arrayDetalle = ObtenerArrayDetalle( datosGen.cantRegDetalle ,
                                                      datosGen.identifAgenda ,
                                                      datosGen.fechaHoy );

      datosGen.cantRegConsumo = ObtenerCantRegConsumo(datosGen.identifAgenda);
      if ( datosGen.cantRegConsumo > 0 )
         datosGen.arrayConsumo = ObtenerArrayConsumo( datosGen.cantRegConsumo ,
                                                      datosGen.identifAgenda );

      datosGen.cantRegPromedio = ObtenerCantRegPromedio(datosGen.identifAgenda);
      if ( datosGen.cantRegPromedio > 0 )
         datosGen.arrayPromedio = ObtenerArrayPromedio(datosGen.cantRegPromedio,
                                                        datosGen.identifAgenda);

      /* PDP - OM3245 - Clientes a los que posiblemente se les devuelva dinero */
      datosGen.cantClientesDdi = ObtenerCantRegCliDDI();
      if ( datosGen.cantClientesDdi > 0 )
         datosGen.arrayClientesDdi = ObtenerArrayCliDDI(datosGen.cantClientesDdi);
   }

   *datosGenParam = datosGen;
}



int ObtenerCantRegTabla( tabla , sucursal , fechaHoy )
    $PARAMETER char * tabla;
    $PARAMETER char * sucursal;
    $PARAMETER long fechaHoy;
{
    $int     cantRegTabla = 0;

    RegistraInicioSql("SET ISOLATION TO REPEATABLE");
    $SET ISOLATION TO REPEATABLE READ;

    RegistraInicioSql("SELECT COUNT");
    $SELECT Count(*) INTO :cantRegTabla
       FROM tabla
      WHERE nomtabla = :tabla
        AND sucursal = :sucursal
        AND fecha_activacion < :fechaHoy
        AND (fecha_desactivac >= :fechaHoy OR fecha_desactivac IS NULL );

    return ( cantRegTabla );
}

Ttabla *ObtenerArrayTabla( tabla , cantRegTabla ,sucursal,  fechaHoy)
    $PARAMETER char * tabla;
    int cantRegTabla;
    $PARAMETER char * sucursal;
    $PARAMETER long fechaHoy;
{
Ttabla  *arrayTabla;
$Ttabla  regTabla;
int i = 0;

arrayTabla = ( Ttabla * ) malloc ( sizeof (Ttabla ) * cantRegTabla );
if ( arrayTabla == NULL )
{
    fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayTabla \n" );
    exit (1);
}
RegistraInicioSql("DECLARE tabla");
$DECLARE tabla CURSOR FOR
 SELECT tabla.sucursal,
        tabla.nomtabla,
        tabla.codigo,
        tabla.descripcion,
        tabla.valor,
        tabla.valor_alf,
        tabla.fecha_activacion,
        tabla.fecha_modificacion,
        tabla.fecha_desactivac
 FROM   tabla
WHERE  nomtabla = :tabla
AND    sucursal = :sucursal
AND   fecha_activacion < :fechaHoy
AND  (fecha_desactivac >= :fechaHoy OR fecha_desactivac IS NULL )
ORDER BY codigo;

RegistraInicioSql("OPEN tabla");
$OPEN tabla;

for ( i= 0 ; i < cantRegTabla && SQLCODE != SQLNOTFOUND ; i++)
   {
   RegistraInicioSql("FETCH tabla");
   $FETCH tabla
     INTO :regTabla.sucursal,
           :regTabla.nomtabla,
           :regTabla.codigo,
           :regTabla.descripcion,
           :regTabla.valor,
           :regTabla.valorAlf,
           :regTabla.fechaActivacion,
           :regTabla.fechaModificacion,
           :regTabla.fechaDesactivac;

   arrayTabla[i] = regTabla;
   }


RegistraInicioSql("CLOSE tabla");
$CLOSE tabla;
RegistraInicioSql("SET ISOLATION TO COMMITED");
$SET ISOLATION TO COMMITTED READ;

return ( arrayTabla );

}


void AjustarDiasVencim( arrayTablaVencim , cantRegVencim )
     Ttabla *arrayTablaVencim;
     int     cantRegVencim;
{
int i = 0;
int diasHabilesRecorridos = 0;
int diasCorridosRecorridos = 0;

for ( i=0 ; i < cantRegVencim ; i++ )
    {
    if ( arrayTablaVencim[i].valorAlf[0] == 'S' )
       {
       while ( diasHabilesRecorridos < arrayTablaVencim[i].valor )
       {
       diasCorridosRecorridos ++;

       if ( rdayofweek (datosGen.fechaHoy + diasCorridosRecorridos) != SABADO  &&
        rdayofweek (datosGen.fechaHoy + diasCorridosRecorridos) != DOMINGO &&
        ! EsDiaFeriado (datosGen.fechaHoy + diasCorridosRecorridos , datosGen.fechaHoy ) )
         {
         diasHabilesRecorridos ++;
         }

       } /* llave del while diasHabilesRecorridos   */

    arrayTablaVencim[i].valor = diasCorridosRecorridos ;
    diasHabilesRecorridos  = 0;
    diasCorridosRecorridos = 1;

    } /* Llave del if strcmp    */

     }  /* Llave del for   */

} /* Llave de la funcion   */



int EsDiaFeriado ( diaAAnalizar , hoy )
    $PARAMETER long diaAAnalizar;
    $PARAMETER long hoy;
{
static int feriadosCargados = NO;
$long fecha;
static long *feriados;
$static int cantRegistros = 0;
int i;

if ( feriadosCargados == NO )
  {
   feriadosCargados = SI;
   RegistraInicioSql("SELECT COUNT");
   $SELECT count (*)
    INTO   :cantRegistros
    FROM feriados;

   feriados = ( long * ) malloc ( sizeof ( long ) * cantRegistros );
if ( feriados == NULL )
    {
    fprintf ( stderr , "Espacio de memoria insuficiente .EsDiaFeriado datos_gen_fact \n" );
    exit (1);
    }

   RegistraInicioSql("DECLARE feriadosCursor");
   $DECLARE feriadosCursor CURSOR FOR
    SELECT  fecha
    FROM    feriados
    WHERE   fecha >= :hoy
    order by 1;

   RegistraInicioSql("OPEN feriadosCursor");
   $OPEN feriadosCursor;
   RegistraInicioSql("FETCH feriadosCursor");
   $FETCH feriadosCursor INTO :fecha;

   for ( i= 0 ; SQLCODE != SQLNOTFOUND && i< cantRegistros ; i++)
      {
      feriados[i] = fecha;
      RegistraInicioSql("FETCH feriadosCursor");
      $FETCH feriadosCursor INTO :fecha;
      };
   RegistraInicioSql("CLOSE feriadosCursor");
   $CLOSE feriadosCursor;

   } /* Llave del if  */

for ( i= 0 ; i< cantRegistros ; i++ )
    if ( feriados[i] == diaAAnalizar )
       return ( SI );

return (NO);
}


/*****************************************************************************/
int ObtenerCantRegCodca(fechaHoy)
    $PARAMETER  long fechaHoy;
{

$int     cantRegTabla = 0;
RegistraInicioSql("SET ISOLATION TO REPEATABLE");
$SET ISOLATION TO REPEATABLE READ;
RegistraInicioSql("SELECT COUNT");
$SELECT count(*)
 INTO   :cantRegTabla
 FROM   codca
 WHERE  fecha_activacion <= :fechaHoy  ;

return ( cantRegTabla );

}

/*****************************************************************************/
Tcodca *ObtenerArrayCodca( cantRegCodca , fechaHoy)
    int cantRegCodca;
    $PARAMETER long fechaHoy;
{

Tcodca *arrayCodca;
$Tcodca  regCodca;
int i = 0;

arrayCodca = ( Tcodca * ) malloc ( sizeof (Tcodca ) * cantRegCodca );
if ( arrayCodca == NULL )
    {
    fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayCodca \n" );
    exit (1);
    }
RegistraInicioSql("DECLARE codca");
$DECLARE codca CURSOR FOR
 SELECT codca.codigo_cargo,
        codca.descripcion,
        codca.unidad,
        codca.nivel_agrupacion,
        codca.tipo_cargo,
        codca.ind_afecto_int,
        codca.orden_impresion,
        codca.ind_tramos,
        codca.fecha_activacion,
        codca.fecha_desactivac,
        codca.ind_afecto_rec            /* PDP - PROYECTO M-7514 */
   FROM   codca
WHERE fecha_activacion <= :fechaHoy
ORDER BY codigo_cargo;

       /* Conste que en el select anterior, se estan trayendo
       * todos los cargos, sin importar cuando fueron desactivados.
       * Esto se realiza partiendo de la definicion de que no
       * pueden existir dos conceptos en codca con el mismo codigo,
       * aunque difieran en otros campos .                           */



RegistraInicioSql("OPEN codca");
$OPEN codca;

for ( i= 0 ; i < cantRegCodca && SQLCODE != SQLNOTFOUND ; i++)
   {
   RegistraInicioSql("FETCH codca");
   $FETCH codca
     INTO :regCodca.codigoCargo,
           :regCodca.descripcion,
           :regCodca.unidad,
           :regCodca.nivelAgrupacion,
           :regCodca.tipoCargo,
           :regCodca.indAfectoInt,
           :regCodca.ordenImpresion,
           :regCodca.indTramos,
           :regCodca.fechaActivacion,
           :regCodca.fechaDesactivac,
           :regCodca.indAfectoRec;      /* PDP - PROYECTO M-7514 */

   arrayCodca[i] = regCodca;
   }
RegistraInicioSql("SET ISOLATION TO COMMITED");
$SET ISOLATION TO COMMITTED READ;

return ( arrayCodca );

}


/*****************************************************************************/
int ObtenerCantRegMensajesFijos(fechaHoy)
    $PARAMETER  long fechaHoy;
{
    $int     cantRegMensajesFijos = 0;

    RegistraInicioSql("SET ISOLATION TO REPEATABLE");
    $SET ISOLATION TO REPEATABLE READ;

    RegistraInicioSql("SELECT COUNT");
    $SELECT count (*)
       INTO :cantRegMensajesFijos
       FROM mensajes
      WHERE tipo_mensaje = TIPO_MENSAJE_FIJO
        AND fecha_activacion <= :fechaHoy
        AND (fecha_desactivac > :fechaHoy OR fecha_desactivac IS NULL );

    return ( cantRegMensajesFijos );
}


/*****************************************************************************/
Tmensajes *ObtenerArrayMensajesFijos( cantRegMensajesFijos , fechaHoy)
    int cantRegMensajesFijos;
    $PARAMETER long fechaHoy;
{
    Tmensajes *arrayMensajes;
    $Tmensajes  regMensaje;
    int i = 0;

    arrayMensajes = ( Tmensajes * ) malloc ( sizeof (Tmensajes ) * cantRegMensajesFijos );
    if ( arrayMensajes == NULL )
    {
        fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayMensajesFijos \n" );
        exit (1);
    }

    RegistraInicioSql("DECLARE mensajeFijo");
    $DECLARE mensajeFijo CURSOR FOR
      SELECT mensajes.tipo_mensaje,
             mensajes.codigo_mensaje,
             mensajes.motivo,
             mensajes.talon_cliente,
             mensajes.talon_banco,
             mensajes.talon_edesur,
             mensajes.zona_factura,
             mensajes.fecha_activacion,
             mensajes.fecha_desactivac
       FROM  mensajes
      WHERE tipo_mensaje = TIPO_MENSAJE_FIJO
        AND fecha_activacion <= :fechaHoy
        AND (fecha_desactivac > :fechaHoy OR fecha_desactivac IS NULL )
      ORDER BY zona_factura, codigo_mensaje;

    RegistraInicioSql("OPEN mensajeFijo");
    $OPEN mensajeFijo;

    for ( i= 0 ; i < cantRegMensajesFijos && SQLCODE != SQLNOTFOUND ; i++)
    {
        RegistraInicioSql("FETCH mensajeFijo");
        $FETCH mensajeFijo
          INTO :regMensaje.tipoMensaje,
               :regMensaje.codigoMensaje,
               :regMensaje.motivo,
               :regMensaje.talonCliente,
               :regMensaje.talonBanco,
               :regMensaje.talonEdesur,
               :regMensaje.zonaFactura,
               :regMensaje.fechaActivacion,
               :regMensaje.fechaDesactivac;

        arrayMensajes[i] = regMensaje;
    }

    RegistraInicioSql("SET ISOLATION TO COMMITED");
    $SET ISOLATION TO COMMITTED READ;

    return ( arrayMensajes );
}


/*****************************************************************************/
int ObtenerCantRegVenage()
{

$int     cantRegVenage = 0;
RegistraInicioSql("SET ISOLATION TO REPEATABLE");
$SET ISOLATION TO REPEATABLE READ;
RegistraInicioSql("SELECT COUNT");


$SELECT  count (*)
 INTO   :cantRegVenage
 FROM    venage, agenda
 WHERE   agenda.identif_agenda   = :datosGen.identifAgenda
   AND   agenda.sucursal         = venage.sucursal
    AND   agenda.sector           = venage.sector
   AND   agenda.zona             = venage.zona
   AND   agenda.fecha_generacion = venage.fecha_generacion ;

return ( cantRegVenage );

}


/*****************************************************************************/
Tvenage *ObtenerArrayVenage( cantRegVenage )
    int cantRegVenage;
{

Tvenage *arrayVenage;
$Tvenage  regVenage;
int i = 0;

arrayVenage = ( Tvenage * ) malloc ( sizeof (Tvenage ) * cantRegVenage );
if ( arrayVenage == NULL )
    {
    fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayVenage \n" );
    exit (1);
    }
RegistraInicioSql("DECLARE CurVenage");
$DECLARE CurVenage CURSOR FOR
 SELECT venage.sucursal,
        venage.sector,
        venage.zona,
        venage.tipo_vcto,
        venage.fecha_vcto,
        venage.fecha_generacion
   FROM    venage, agenda
WHERE   agenda.identif_agenda    = :datosGen.identifAgenda
  AND   agenda.sucursal         = venage.sucursal
   AND   agenda.sector           = venage.sector
   AND   agenda.zona             = venage.zona
   AND   agenda.fecha_generacion = venage.fecha_generacion
ORDER BY tipo_vcto ;
RegistraInicioSql("OPEN CurVenage");
$OPEN CurVenage;

for ( i= 0 ; i < cantRegVenage && SQLCODE != SQLNOTFOUND ; i++)
   {
   RegistraInicioSql("FETCH CurVenage");
   $FETCH CurVenage
     INTO :regVenage.sucursal,
           :regVenage.sector,
           :regVenage.zona,
           :regVenage.tipoVcto,
           :regVenage.fechaVcto,
           :regVenage.fechaGeneracion;

   arrayVenage[i] = regVenage;
   }
RegistraInicioSql("SET ISOLATION TO COMMITED");
$SET ISOLATION TO COMMITTED READ;

return ( arrayVenage );

}


/*****************************************************************************/
int ObtenerCantRegVenageProximo()
{

$int     cantRegVenageProximo = 0;
RegistraInicioSql("SET ISOLATION TO REPEATABLE");
$SET ISOLATION TO REPEATABLE READ;
RegistraInicioSql("SELECT COUNT");

$select count (*)
 into :cantRegVenageProximo
from  agenda a1, venage
where a1.identif_agenda = :datosGen.identifAgenda
and   a1.sucursal       = venage.sucursal
and   a1.sector         = venage.sector
and   a1.zona           = venage.zona
and   venage.fecha_generacion = ( select min ( fecha_generacion )
                  from   agenda a2
                  where  a1.sucursal = a2.sucursal
                    and  a1.sector   = a2.sector
                    and  a1.zona     = a2.zona
                    and  a2.fecha_generacion > a1.fecha_generacion
                    and  a2.tipo_agenda = 'L' );

return ( cantRegVenageProximo );

}


/*****************************************************************************/
Tvenage *ObtenerArrayVenageProximo ( int cantRegVenageProximo )
{

Tvenage *arrayVenageProximo ;
$Tvenage  regVenage;
int i = 0;

arrayVenageProximo  = ( Tvenage * ) malloc ( sizeof (Tvenage ) * cantRegVenageProximo );
if ( arrayVenageProximo == NULL )
    {
    fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayVenageProximo \n" );
    exit (1);
    }

RegistraInicioSql("DECLARE CurVenage");
$DECLARE CurVenageProx CURSOR FOR
 SELECT venage.sucursal,
        venage.sector,
        venage.zona,
        venage.tipo_vcto,
        venage.fecha_vcto,
        venage.fecha_generacion
   FROM  agenda a1, venage
where a1.identif_agenda = :datosGen.identifAgenda
and   a1.sucursal       = venage.sucursal
and   a1.sector         = venage.sector
and   a1.zona           = venage.zona
and   venage.fecha_generacion = ( select min ( fecha_generacion )
                  from   agenda a2
                  where  a1.sucursal = a2.sucursal
                    and  a1.sector   = a2.sector
                    and  a1.zona     = a2.zona
                    and  a2.fecha_generacion > a1.fecha_generacion
                    and  a2.tipo_agenda = 'L'  )
order by tipo_vcto ;


RegistraInicioSql("OPEN CurVenageProx ");
$OPEN CurVenageProx ;

for ( i= 0 ; i < cantRegVenageProximo && SQLCODE != SQLNOTFOUND ; i++)
   {
   RegistraInicioSql("FETCH CurVenageProx");
   $FETCH CurVenageProx
     INTO :regVenage.sucursal,
           :regVenage.sector,
           :regVenage.zona,
           :regVenage.tipoVcto,
           :regVenage.fechaVcto,
           :regVenage.fechaGeneracion;

   arrayVenageProximo [i] = regVenage;
   }
RegistraInicioSql("SET ISOLATION TO COMMITED");
$SET ISOLATION TO COMMITTED READ;

return ( arrayVenageProximo );

}



/****************************************************************************/
void AlmacenarIdentifAgenda( identif )    /* el facturador de ciclo debe llamarla si o si */
     long identif;
{
datosGen.identifAgenda = identif;
}


/*****************************************************************************/
void AlmacenarRangoClientes( numeroClienteInicial , numeroClienteFin  ) /* el fact.de c la llama si o si */
     long numeroClienteInicial ;
     long numeroClienteFin ;
{
datosGen.numeroClienteInicial = numeroClienteInicial;
datosGen.numeroClienteFin = numeroClienteFin;
}

/****************************************************************************/
void AlmacenarFechaGeneracion( fechaGeneracion ) /* Se usa para determinacion del periodo */
     long fechaGeneracion;
{
datosGen.fechaGeneracion = fechaGeneracion;
}


/*****************************************************************************/


/* A partir de aqui se vuelve imprescindible utilizar el rango de clientes
 * debido a que los facturadores no de ciclo deben traer datos de un cliente
 * solamente                                                                      */


/*****************************************************************************/
int ObtenerCantRegConceptosPorAplicar( identif )
    $PARAMETER long identif;
{
$int cantReg = 0 ;

   RegistraInicioSql("count de curcpa");
   $SET ISOLATION TO DIRTY READ;

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM carco,
              codca
        WHERE carco.numero_cliente = :datosGen.numeroClienteInicial
          AND carco.identif_agenda IS NULL
          AND carco.estado_agenda IS NULL
          AND carco.codigo_cargo = codca.codigo_cargo;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM carco,
              codca,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND carco.numero_cliente = hisfac_cont_temp.numero_cliente
          AND carco.identif_agenda IS NULL
          AND carco.estado_agenda IS NULL
          AND carco.codigo_cargo = codca.codigo_cargo;
   };
   return ( cantReg );
}


/****************************************************************************/
TcarcoConInt *ObtenerArrayConceptosPorAplicar( cantRegConceptosPorAplicar , identif )
    long cantRegConceptosPorAplicar ;
    $PARAMETER long identif;
{
$TcarcoConInt     regCarcoConInt;
$TcarcoConInt   * arrayConceptosPorAplicar;
int               i = 0;

   arrayConceptosPorAplicar = (TcarcoConInt *) malloc (sizeof (TcarcoConInt) * cantRegConceptosPorAplicar);
   if ( arrayConceptosPorAplicar == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConceptosPorAplicar \n" );
      exit (1);
   };
   finArrayConceptosPorAplicar = arrayConceptosPorAplicar + cantRegConceptosPorAplicar -1 ;                                                      RegistraInicioSql("DECLARE curCPA... de datosgen");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      /* PDP - OM3931 - Neteo FE y FEP - Se agrega tabla que agrupa cptos */
      sprintf(gstrSql, "SELECT carco.numero_cliente,"
                       "       carco.codigo_cargo,"
                       "       carco.valor_cargo,"
                       "       carco.cantidad,"
                       "       carco.identif_agenda,"
                       "       carco.estado_agenda,"
                       "       carco.tipo_cargo,"
                       "       codca.ind_afecto_int,"
                       "       codca.orden_impresion,"
                       "       g.cod_cargo_descr"
                       "  FROM carco, codca,"
                       " OUTER codca_agrupa g" 
                       " WHERE carco.numero_cliente = %ld"
                       "   AND carco.identif_agenda IS NULL"
                       "   AND carco.estado_agenda IS NULL"
                       "   AND carco.codigo_cargo = codca.codigo_cargo"
                       "   AND g.codigo_cargo = codca.codigo_cargo"
                       "   AND g.fecha_activacion <= TODAY"
                       "   AND (g.fecha_desactivac > TODAY OR g.fecha_desactivac IS NULL )"
                       " ORDER BY carco.numero_cliente,"
                       "          carco.codigo_cargo",
                       datosGen.numeroClienteInicial );
   }
   else
   {
      /* PDP - OM3931 - Neteo FE y FEP - Se agrega tabla que agrupa cptos */
      sprintf(gstrSql, "SELECT carco.numero_cliente,"
                       "       carco.codigo_cargo,"
                       "       carco.valor_cargo,"
                       "       carco.cantidad,"
                       "       carco.identif_agenda,"
                       "       carco.estado_agenda,"
                       "       carco.tipo_cargo,"
                       "       codca.ind_afecto_int,"
                       "       codca.orden_impresion,"
                       "       g.cod_cargo_descr"
                       "  FROM carco,"
                       "       codca,"
                       "       hisfac_cont_temp,"
                       " OUTER codca_agrupa g" 
                       " WHERE hisfac_cont_temp.sucursal = '%s'"
                       "   AND hisfac_cont_temp.sector = %ld"
                       "   AND hisfac_cont_temp.identif_agenda = %ld"
                       "   AND hisfac_cont_temp.numero_cliente >= %ld"
                       "   AND hisfac_cont_temp.numero_cliente <= %ld"
                       "   AND carco.numero_cliente = hisfac_cont_temp.numero_cliente"
                       "   AND carco.identif_agenda IS NULL"
                       "   AND carco.estado_agenda IS NULL"
                       "   AND carco.codigo_cargo = codca.codigo_cargo"
                       "   AND g.codigo_cargo = codca.codigo_cargo"
                       "   AND g.fecha_activacion <= TODAY"
                       "   AND (g.fecha_desactivac > TODAY OR g.fecha_desactivac IS NULL )"
                       " ORDER BY carco.numero_cliente,"
                       "          carco.codigo_cargo",
                       datosGen.sucursal,
                       datosGen.sector,
                       identif,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin );
   };
   RegistraInicioSql("calc_otros.ec: [0] Prepare/Declare curCPA...");
   $PREPARE acCPASql FROM $gstrSql;
   $DECLARE curCPA CURSOR FOR acCPASql;
   RegistraInicioSql("calc_otros.ec: [1] OPEN curCPA...");
   $OPEN curCPA;
   RegistraInicioSql("calc_otros.ec: [2] 1er FETCH CurCPA...");
   $FETCH curCPA INTO $regCarcoConInt ;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla carco debe estar lockeada en modo exclusivo */
   {
      arrayConceptosPorAplicar [i] = regCarcoConInt;
      RegistraInicioSql("calc_otros.ec: [4] 2do FETCH curCPA...");
      $FETCH curCPA INTO $regCarcoConInt ;
   };
   RegistraInicioSql("calc_otros.ec: [5] CLOSE curCPA...");
   $CLOSE curCPA;
   return ( arrayConceptosPorAplicar );
}



/****************************************************************************/

TcarcoConInt * ObtenerPrimerCPACliente ( numeroCliente )
    long numeroCliente ;
{

TcarcoConInt regCPAABuscar ;
TcarcoConInt *regCPA ;


if ( datosGen.cantRegConceptosPorAplicar == 0 )
    return ( NULL );

regCPAABuscar.numeroCliente = numeroCliente ;



regCPA = ( TcarcoConInt *) bsearch ((void*) (  &regCPAABuscar),
                      (  void * ) datosGen.arrayConceptosPorAplicar ,
                       datosGen.cantRegConceptosPorAplicar,
                       sizeof ( TcarcoConInt ),
                       ComparaRegCarcoConInt );
CPAInicialDelCliente = regCPA ;
ultimoCPADelCliente  = regCPA ;
direccionProxCPA     = ABAJO  ;


return ( regCPA );

}


/*****************************************************************************/

TcarcoConInt * ObtenerSiguienteCPACliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxCPA == ABAJO )
    {
    if ( ultimoCPADelCliente == finArrayConceptosPorAplicar )
        {
        direccionProxCPA = ARRIBA ;
        ultimoCPADelCliente = CPAInicialDelCliente ;
        }
    else
        {

        ultimoCPADelCliente = ultimoCPADelCliente + 1;

        if ( ultimoCPADelCliente->numeroCliente != numeroCliente )
            {
            direccionProxCPA = ARRIBA ;
            ultimoCPADelCliente = CPAInicialDelCliente ;
            }
        }
    }


if ( direccionProxCPA == ARRIBA )
    {

    if ( ultimoCPADelCliente == datosGen.arrayConceptosPorAplicar )
        ultimoCPADelCliente = NULL;
    else
        {
        ultimoCPADelCliente = ultimoCPADelCliente - 1 ;

        if ( ultimoCPADelCliente->numeroCliente != numeroCliente )
            ultimoCPADelCliente = NULL;
        }
    }


return ( ultimoCPADelCliente ) ;

}


/*****************************************************************************/

/*  Funcion para comparacion de dos registros de carcoConInt
 *   Para uso con bsearch .                                                       */
/*Se modifica por migracion a AIX*/
int ComparaRegCarcoConInt(const void *reg1, const void *reg2)
{
return ( ( ((TcarcoConInt *)reg1)->numeroCliente ) - ( ((TcarcoConInt *)reg2)->numeroCliente) );
}


/*****************************************************************************/

int ObtenerCantRegConceptosTemporales( identif , fechaHoy )
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
   $int cantReg = 0 ;

   RegistraInicioSql("count de curArrie");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM arrie,
              codca
        WHERE arrie.numero_cliente = :datosGen.numeroClienteInicial
          AND arrie.fecha_activacion <= $fechaHoy
          AND(arrie.fecha_desactivac > $fechaHoy OR arrie.fecha_desactivac IS NULL)
          AND codca.fecha_activacion <= $fechaHoy
          AND (codca.fecha_desactivac > $fechaHoy OR codca.fecha_desactivac IS NULL)
          AND arrie.codigo_cargo = codca.codigo_cargo;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM arrie,
              codca,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND arrie.numero_cliente = hisfac_cont_temp.numero_cliente
          AND arrie.fecha_activacion <= $fechaHoy
          AND(arrie.fecha_desactivac > $fechaHoy OR arrie.fecha_desactivac IS NULL)
          AND codca.fecha_activacion <= $fechaHoy
          AND (codca.fecha_desactivac > $fechaHoy OR codca.fecha_desactivac IS NULL)
          AND arrie.codigo_cargo = codca.codigo_cargo;
   };
   return ( cantReg );
}


/*****************************************************************************/

TarrieConInt *ObtenerArrayConceptosTemporales( cantRegConceptosTemporales , identif , fechaHoy  )
    long cantRegConceptosTemporales ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
$TarrieConInt regArrieConInt ;
$TarrieConInt * arrayConceptosTemporales ;
int i = 0 ;

   arrayConceptosTemporales = (TarrieConInt *) malloc ( sizeof (TarrieConInt ) * cantRegConceptosTemporales );
   if ( arrayConceptosTemporales == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConceptosTemporales \n" );
      exit (1);
   };
   finArrayConceptosTemporales = arrayConceptosTemporales + cantRegConceptosTemporales -1 ;
   RegistraInicioSql(" DECLARE CurArrie ...");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT arrie.numero_cliente, "
                       "       arrie.codigo_cargo, "
                       "       arrie.valor_cargo, "
                       "       arrie.factor_aplicacion, "
                       "       arrie.fecha_activacion, "
                       "       arrie.fecha_desactivac, "
                       "       codca.ind_afecto_int "
                       "  FROM arrie, "
                       "       codca "
                       " WHERE arrie.numero_cliente = %ld "
                       "   AND arrie.fecha_activacion <= %ld "
                       "   AND ( arrie.fecha_desactivac > %ld OR arrie.fecha_desactivac IS NULL ) "
                       "   AND codca.fecha_activacion <= %ld "
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL ) "
                       "   AND arrie.codigo_cargo = codca.codigo_cargo "
                       " ORDER BY arrie.numero_cliente, "
                       "          arrie.codigo_cargo",
                       datosGen.numeroClienteInicial,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy );
   }
   else
   {
      sprintf(gstrSql, "SELECT arrie.numero_cliente, "
                       "       arrie.codigo_cargo, "
                       "       arrie.valor_cargo, "
                       "       arrie.factor_aplicacion, "
                       "       arrie.fecha_activacion, "
                       "       arrie.fecha_desactivac, "
                       "       codca.ind_afecto_int "
                       "  FROM arrie, "
                       "       codca, "
                       "       hisfac_cont_temp "
                       " WHERE hisfac_cont_temp.sucursal = '%s' "
                       "   AND hisfac_cont_temp.sector = %ld "
                       "   AND hisfac_cont_temp.identif_agenda = %ld "
                       "   AND hisfac_cont_temp.numero_cliente >= %ld "
                       "   AND hisfac_cont_temp.numero_cliente <= %ld "
                       "   AND arrie.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "   AND arrie.fecha_activacion <= %ld "
                       "   AND ( arrie.fecha_desactivac > %ld OR arrie.fecha_desactivac IS NULL ) "
                       "   AND codca.fecha_activacion <= %ld "
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL ) "
                       "   AND arrie.codigo_cargo = codca.codigo_cargo "
                       " ORDER BY arrie.numero_cliente, "
                       "          arrie.codigo_cargo",
                       datosGen.sucursal,
                       datosGen.sector,
                       identif,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy );
   };
   RegistraInicioSql("PREPARE/DECLARE CurArrie ...");
   $PREPARE acArrieSql FROM $gstrSql;
   $DECLARE CurArrie CURSOR FOR acArrieSql;
   RegistraInicioSql("OPEN CurArrie ...");
   $OPEN CurArrie;
   RegistraInicioSql("primer  FETCH CurArrie ...");
   $FETCH CurArrie INTO $regArrieConInt ;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla arrie debe estar lockeada en modo exclusivo */
   {
      arrayConceptosTemporales [i] = regArrieConInt;
      $FETCH curArrie INTO $regArrieConInt ;
   };
   RegistraInicioSql("CLOSE curArrie...");
   $CLOSE curArrie;
   return ( arrayConceptosTemporales );
}


/*****************************************************************************/

TarrieConInt * ObtenerPrimerTempCliente ( numeroCliente )
    long numeroCliente ;
{

TarrieConInt regTempABuscar ;
TarrieConInt *regTemp ;

if ( datosGen.cantRegConceptosTemporales == 0 )
    return ( NULL );


regTempABuscar.numeroCliente = numeroCliente ;

regTemp = ( TarrieConInt *) bsearch ((void*) (  &regTempABuscar),
                      (  void * ) datosGen.arrayConceptosTemporales ,
                       datosGen.cantRegConceptosTemporales,
                       sizeof ( TarrieConInt ),
                       ComparaRegArrieConInt );
tempInicialDelCliente = regTemp ;
ultimoTempDelCliente  = regTemp ;
direccionProxTemp     = ABAJO  ;


return ( regTemp );

}


/*****************************************************************************/

TarrieConInt * ObtenerSiguienteTempCliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxTemp == ABAJO )
    {
    if ( ultimoTempDelCliente == finArrayConceptosTemporales )
        {
        direccionProxTemp = ARRIBA ;
        ultimoTempDelCliente = tempInicialDelCliente ;
        }
    else
        {

        ultimoTempDelCliente = ultimoTempDelCliente + 1;

        if ( ultimoTempDelCliente->numeroCliente != numeroCliente )
            {
            direccionProxTemp = ARRIBA ;
            ultimoTempDelCliente = tempInicialDelCliente ;
            }
        }
    }


if ( direccionProxTemp == ARRIBA )
    {

    if ( ultimoTempDelCliente == datosGen.arrayConceptosTemporales )
        ultimoTempDelCliente = NULL;
    else
        {
        ultimoTempDelCliente = ultimoTempDelCliente - 1 ;

        if ( ultimoTempDelCliente->numeroCliente != numeroCliente )
            ultimoTempDelCliente = NULL;
        }
    }


return ( ultimoTempDelCliente ) ;

}

/*****************************************************************************/
/* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
int ObtenerCantRegConceptosTemporalesPendientes( identif , fechaHoy )
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
   $int cantReg = 0 ;

   RegistraInicioSql("count de curArrie");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM arrie,
              codca,
              cliente
        WHERE arrie.numero_cliente = :datosGen.numeroClienteInicial
          AND arrie.numero_cliente = cliente.numero_cliente
          AND arrie.fecha_activacion <= $fechaHoy
          AND (cliente.tarifa[3,3] = 'M' AND arrie.fecha_desactivac - 7 > TODAY
            OR cliente.tarifa[3,3] = 'B' AND arrie.fecha_desactivac - 15> TODAY)
          AND codca.fecha_activacion <= $fechaHoy
          AND (codca.fecha_desactivac > $fechaHoy OR codca.fecha_desactivac IS NULL)
          AND arrie.codigo_cargo = codca.codigo_cargo;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM arrie,
              codca,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND arrie.numero_cliente = hisfac_cont_temp.numero_cliente
          AND arrie.fecha_activacion <= $fechaHoy
          AND (hisfac_cont_temp.tarifa[3,3] = 'M' AND arrie.fecha_desactivac - 7 > TODAY
            OR hisfac_cont_temp.tarifa[3,3] = 'B' AND arrie.fecha_desactivac - 15> TODAY)
          AND codca.fecha_activacion <= $fechaHoy
          AND (codca.fecha_desactivac > $fechaHoy OR codca.fecha_desactivac IS NULL)
          AND arrie.codigo_cargo = codca.codigo_cargo;
   };

   return ( cantReg );
}

/*****************************************************************************/

TarrieConInt *ObtenerArrayConceptosTemporalesPendientes( cantRegConceptosTemporalesPendientes , identif , fechaHoy  )
    long cantRegConceptosTemporalesPendientes ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
    $TarrieConInt regArrieConInt ;
    $TarrieConInt * arrayConceptosTemporales ;
    int i = 0 ;

   arrayConceptosTemporales = (TarrieConInt *) malloc ( sizeof (TarrieConInt ) * cantRegConceptosTemporalesPendientes );
   if ( arrayConceptosTemporales == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConceptosTemporalesPendientes \n" );
      exit (1);
   };

   finArrayConceptosTemporalesPendientes = arrayConceptosTemporales + cantRegConceptosTemporalesPendientes -1 ;

   RegistraInicioSql(" DECLARE CurArriePendientes ...");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT arrie.numero_cliente, "
                       "       arrie.codigo_cargo, "
                       "       arrie.valor_cargo, "
                       "       arrie.factor_aplicacion, "
                       "       arrie.fecha_activacion, "
                       "       arrie.fecha_desactivac, "
                       "       codca.ind_afecto_int "
                       "  FROM arrie, "
                       "       codca, "
                       "       cliente "
                       " WHERE arrie.numero_cliente = %ld "
                       "   AND arrie.numero_cliente = cliente.numero_cliente "
                       "   AND arrie.fecha_activacion <= %ld "
                       "   AND (cliente.tarifa[3,3] = 'M' AND arrie.fecha_desactivac - 7 > %ld "
                       "     OR cliente.tarifa[3,3] = 'B' AND arrie.fecha_desactivac - 15> %ld) "
                       "   AND codca.fecha_activacion <= %ld "
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL ) "
                       "   AND arrie.codigo_cargo = codca.codigo_cargo "
                       " ORDER BY arrie.numero_cliente, "
                       "          arrie.codigo_cargo",
                       datosGen.numeroClienteInicial,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy );
   }
   else
   {
      sprintf(gstrSql, "SELECT arrie.numero_cliente, "
                       "       arrie.codigo_cargo, "
                       "       arrie.valor_cargo, "
                       "       arrie.factor_aplicacion, "
                       "       arrie.fecha_activacion, "
                       "       arrie.fecha_desactivac, "
                       "       codca.ind_afecto_int "
                       "  FROM arrie, "
                       "       codca, "
                       "       hisfac_cont_temp "
                       " WHERE hisfac_cont_temp.sucursal = '%s' "
                       "   AND hisfac_cont_temp.sector = %ld "
                       "   AND hisfac_cont_temp.identif_agenda = %ld "
                       "   AND hisfac_cont_temp.numero_cliente >= %ld "
                       "   AND hisfac_cont_temp.numero_cliente <= %ld "
                       "   AND arrie.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "   AND arrie.fecha_activacion <= %ld "
                       "   AND (hisfac_cont_temp.tarifa[3,3] = 'M' AND arrie.fecha_desactivac - 7 > %ld "
                       "     OR hisfac_cont_temp.tarifa[3,3] = 'B' AND arrie.fecha_desactivac - 15> %ld) "
                       "   AND codca.fecha_activacion <= %ld "
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL ) "
                       "   AND arrie.codigo_cargo = codca.codigo_cargo "
                       " ORDER BY arrie.numero_cliente, "
                       "          arrie.codigo_cargo",
                       datosGen.sucursal,
                       datosGen.sector,
                       identif,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy,
                       fechaHoy );
   };

   RegistraInicioSql("PREPARE/DECLARE CurArriePendientes ...");
   $PREPARE acArrieSqlPendientes FROM $gstrSql;
   $DECLARE CurArriePendientes CURSOR FOR acArrieSqlPendientes;

   RegistraInicioSql("OPEN CurArriePendientes ...");
   $OPEN CurArriePendientes;

   RegistraInicioSql("primer  FETCH CurArriePendientes ...");
   $FETCH CurArriePendientes INTO $regArrieConInt ;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla arrie debe estar lockeada en modo exclusivo */
   {
      arrayConceptosTemporales [i] = regArrieConInt;
      $FETCH curArriePendientes INTO $regArrieConInt ;
   };

   RegistraInicioSql("CLOSE curArriePendientes...");
   $CLOSE curArriePendientes;

   return ( arrayConceptosTemporales );
}


/*****************************************************************************/

TarrieConInt * ObtenerPrimerTempClientePendientes ( numeroCliente )
    long numeroCliente ;
{
    TarrieConInt regTempABuscar ;
    TarrieConInt *regTemp ;

    if ( datosGen.cantRegConceptosTemporalesPendientes == 0 )
        return ( NULL );

    regTempABuscar.numeroCliente = numeroCliente ;

    regTemp = ( TarrieConInt *) bsearch ((void*) (  &regTempABuscar),
                          (  void * ) datosGen.arrayConceptosTemporalesPendientes ,
                           datosGen.cantRegConceptosTemporalesPendientes,
                           sizeof ( TarrieConInt ),
                           ComparaRegArrieConInt );
    tempInicialDelClientePendientes = regTemp ;
    ultimoTempDelClientePendientes  = regTemp ;
    direccionProxTempPendientes     = ABAJO  ;

    return ( regTemp );
}

/*****************************************************************************/
TarrieConInt * ObtenerSiguienteTempClientePendientes( numeroCliente )
    long numeroCliente ;
{
    if ( direccionProxTempPendientes == ABAJO )
    {
        if ( ultimoTempDelClientePendientes == finArrayConceptosTemporalesPendientes )
        {
            direccionProxTempPendientes = ARRIBA ;
            ultimoTempDelClientePendientes = tempInicialDelClientePendientes ;
        }
        else
        {
            ultimoTempDelClientePendientes = ultimoTempDelClientePendientes + 1;

            if ( ultimoTempDelClientePendientes->numeroCliente != numeroCliente )
            {
                direccionProxTempPendientes = ARRIBA ;
                ultimoTempDelClientePendientes = tempInicialDelClientePendientes ;
            }
        }
    }

    if ( direccionProxTempPendientes == ARRIBA )
    {
        if ( ultimoTempDelClientePendientes == datosGen.arrayConceptosTemporalesPendientes )
            ultimoTempDelClientePendientes = NULL;
        else
        {
            ultimoTempDelClientePendientes = ultimoTempDelClientePendientes - 1 ;

            if ( ultimoTempDelClientePendientes->numeroCliente != numeroCliente )
                ultimoTempDelClientePendientes = NULL;
        }
    }

    return ( ultimoTempDelClientePendientes ) ;
}


/*************************************************************************************/
/*  Funcion para comparacion de dos registros de arrieConInt
 *   Para uso con bsearch .                                                          */

int
ComparaRegArrieConInt( reg1 , reg2 )
   TarrieConInt *reg1;
   TarrieConInt *reg2;
{
return ( ( reg1->numeroCliente ) - ( reg2->numeroCliente) );
}


/*****************************************************************************/

int ObtenerCantRegConceptosTarifa( identif , fechaHoy)
    $PARAMETER long identif;
    $PARAMETER long fechaHoy ;
{
$int cantReg = 0 ;
   RegistraInicioSql("count de carcoCursor");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM carco,
              codca
        WHERE carco.identif_agenda =:identif
          AND carco.codigo_cargo = codca.codigo_cargo
          AND carco.tipo_cargo = TIP_CON_TARIFA
          AND codca.tipo_cargo = TIP_CON_TARIFA
          AND carco.estado_agenda IN (EST_AGE_ANA_CON, EST_AGE_CAL_CON_VAL_TAR, EST_AGE_TAR_CONS_CONV, EST_AGE_NETEO_FE_FEP)
          AND codca.fecha_activacion <=:fechaHoy
          AND ( codca.fecha_desactivac >:fechaHoy OR codca.fecha_desactivac IS NULL )
          AND carco.numero_cliente = :datosGen.numeroClienteInicial;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM carco,
              codca
        WHERE carco.identif_agenda =:identif
          AND carco.codigo_cargo = codca.codigo_cargo
          AND carco.tipo_cargo = TIP_CON_TARIFA
          AND codca.tipo_cargo = TIP_CON_TARIFA
          AND carco.estado_agenda IN (EST_AGE_ANA_CON, EST_AGE_CAL_CON_VAL_TAR, EST_AGE_TAR_CONS_CONV, EST_AGE_NETEO_FE_FEP)
          AND codca.fecha_activacion <=:fechaHoy
          AND ( codca.fecha_desactivac >:fechaHoy OR codca.fecha_desactivac IS NULL )
          AND carco.numero_cliente >= :datosGen.numeroClienteInicial
          AND carco.numero_cliente <= :datosGen.numeroClienteFin ;
   };
   return ( cantReg );
}


/*****************************************************************************/

TcarcoConInt *ObtenerArrayConceptosTarifa( cantRegConceptosTarifa , identif , fechaHoy)
    long cantRegConceptosTarifa ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
$TcarcoConInt regCarcoConInt ;
$TcarcoConInt * arrayConceptosTarifa ;
int i = 0 ;

   arrayConceptosTarifa = (TcarcoConInt *) malloc ( sizeof (TcarcoConInt) * cantRegConceptosTarifa );
   if( arrayConceptosTarifa == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConceptosTarifa \n" );
      exit (1);
   };
   finArrayConceptosTarifa = arrayConceptosTarifa + cantRegConceptosTarifa - 1;
                                                      RegistraInicioSql("DECLARE curCarco...de datosgen");

   /* PDP - OM1726 - Se agrega orden_impresion en SELECT y ORDER BY de los 2 querys
                     para que BFP salga despues de CF y CV */
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      /* PDP - OM3931 - Neteo FE y FEP - Se agrega tabla que agrupa cptos */
      sprintf(gstrSql, "SELECT carco.numero_cliente,"
                       "       carco.codigo_cargo,"
                       "       carco.valor_cargo,"
                       "       carco.cantidad,"
                       "       carco.identif_agenda,"
                       "       carco.estado_agenda,"
                       "       carco.tipo_cargo,"
                       "       codca.ind_afecto_int"
                       "       ,codca.orden_impresion,"
                       "       g.cod_cargo_descr"
                       "  FROM carco,"
                       "       codca,"
                       " OUTER codca_agrupa g" 
                       " WHERE carco.identif_agenda = %ld"
                       "   AND carco.codigo_cargo = codca.codigo_cargo"
                       "   AND carco.tipo_cargo = '%s'"
                       "   AND codca.fecha_activacion <= %ld"
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL )"
                       "   AND carco.numero_cliente = %ld"
                       "   AND g.codigo_cargo = codca.codigo_cargo"
                       "   AND g.fecha_activacion <= TODAY"
                       "   AND (g.fecha_desactivac > TODAY OR g.fecha_desactivac IS NULL )"
                       " ORDER BY carco.numero_cliente, codca.orden_impresion, carco.codigo_cargo" ,
                       identif,
                       TIP_CON_TARIFA,
                       fechaHoy,
                       fechaHoy,
                       datosGen.numeroClienteInicial );
   }
   else
   {
      /* PDP - OM3931 - Neteo FE y FEP - Se agrega tabla que agrupa cptos */
      sprintf(gstrSql, "SELECT carco.numero_cliente,"
                       "       carco.codigo_cargo,"
                       "       carco.valor_cargo,"
                       "       carco.cantidad,"
                       "       carco.identif_agenda,"
                       "       carco.estado_agenda,"
                       "       carco.tipo_cargo,"
                       "       codca.ind_afecto_int"
                       "       ,codca.orden_impresion,"
                       "       g.cod_cargo_descr"
                       "  FROM carco,"
                       "       codca,"
                       " OUTER codca_agrupa g" 
                       " WHERE carco.identif_agenda = %ld"
                       "   AND carco.codigo_cargo = codca.codigo_cargo"
                       "   AND carco.tipo_cargo = '%s'"
                       "   AND codca.fecha_activacion <= %ld"
                       "   AND ( codca.fecha_desactivac > %ld OR codca.fecha_desactivac IS NULL)"
                       "   AND carco.numero_cliente >= %ld"
                       "   AND carco.numero_cliente <= %ld"
                       "   AND g.codigo_cargo = codca.codigo_cargo"
                       "   AND g.fecha_activacion <= TODAY"
                       "   AND (g.fecha_desactivac > TODAY OR g.fecha_desactivac IS NULL )"
                       " ORDER BY carco.numero_cliente, codca.orden_impresion, carco.codigo_cargo" ,
                       identif,
                       TIP_CON_TARIFA,
                       fechaHoy,
                       fechaHoy,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin );
   };

   RegistraInicioSql("PREPARE/DECLARE carcoCursor");
   $PREPARE accoCursorSql FROM $gstrSql;
   $DECLARE carcoCursor CURSOR FOR accoCursorSql;

   RegistraInicioSql("OPEN carcoCursor");
   $OPEN carcoCursor;
   RegistraInicioSql("FETCH carcoCursor");
   $FETCH carcoCursor INTO:regCarcoConInt;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla carco debe estar lockeada en modo exclusivo */
   {
      arrayConceptosTarifa [i] = regCarcoConInt;
      $FETCH carcoCursor INTO $regCarcoConInt ;
   };
   RegistraInicioSql("calc_otros.ec: [5] CLOSE curCPA...");
   $CLOSE carcoCursor;
   return ( arrayConceptosTarifa );
}


/*****************************************************************************/

/* es funcion tipo abajo                                                         */
TcarcoConInt * ObtenerPrimerCargoTarifaCliente ( numeroCliente )
    long numeroCliente ;
{

TcarcoConInt regCargoABuscar ;
TcarcoConInt *regCargo ;

if ( datosGen.cantRegConceptosTarifa == 0 )
    return ( NULL );

regCargoABuscar.numeroCliente = numeroCliente ;

regCargo = ( TcarcoConInt *) bsearch ((void*) (  &regCargoABuscar),
                      (  void * ) datosGen.arrayConceptosTarifa ,
                       datosGen.cantRegConceptosTarifa,
                       sizeof ( TcarcoConInt ),
                       ComparaRegCarcoConInt );

if ( regCargo == NULL )
    return ( regCargo );

while (  ( regCargo - 1 )->numeroCliente == numeroCliente && regCargo != datosGen.arrayConceptosTarifa )
    {
    regCargo-- ;
    }

ultimoCargoTarifaDelCliente  = regCargo ;


return ( regCargo );

}


/*****************************************************************************/

TcarcoConInt * ObtenerSiguienteCargoTarifaCliente( numeroCliente )
    long numeroCliente ;
{

    if ( ultimoCargoTarifaDelCliente == finArrayConceptosTarifa )
        {
        ultimoCargoTarifaDelCliente = NULL ;
        }
    else
        {

        ultimoCargoTarifaDelCliente = ultimoCargoTarifaDelCliente + 1;

        if ( ultimoCargoTarifaDelCliente->numeroCliente != numeroCliente )
            {
            ultimoCargoTarifaDelCliente = NULL ;
            }
        }

return ( ultimoCargoTarifaDelCliente ) ;

}

/*****************************************************************************/

int ObtenerCantRegPagosParaIntereses( identif , fechaHoy)
    $PARAMETER long identif;
    $PARAMETER long fechaHoy ;
{
   $int cantReg = 0 ;
   $datetime year to second fechaHoyHora;

   PasaFechaAFechaHora(fechaHoy,&fechaHoyHora);
   RegistraInicioSql("count de carcoCursor");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM pagco,
              cliente
        WHERE cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND fecha_pago >= EXTEND(cliente.fecha_ultima_fact, YEAR TO SECOND)
          AND fecha_pago <= :fechaHoyHora
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CUENTA
          AND tipo_pago != TIPO_PAGO_DEPOSITO_GARANTIA
          AND tipo_pago != TIPO_PAGO_ANTICIPO_RETIRO
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CONVENIO
          AND pagco.numero_cliente = cliente.numero_cliente
          AND pagco.numero_cliente = :datosGen.numeroClienteInicial ;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM pagco,
              /*cliente,*/
              hisfac_cont_temp
              , hisfac/* PDP - Calculo Interes Mora MAL */
        WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          /* PDP - Calculo Interes Mora MAL */
          /*AND hisfac_cont_temp.sucursal = cliente.sucursal 
          AND hisfac_cont_temp.sector = cliente.sector */
          /*AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif*/
          AND hisfac_cont_temp.fecha_facturacion = :fechaHoy
          /*AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector*/
          AND hisfac.numero_cliente   = hisfac_cont_temp.numero_cliente
          AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - 1
          AND fecha_pago >= EXTEND(hisfac.fecha_facturacion, YEAR TO SECOND)
          /*AND fecha_pago >= EXTEND(cliente.fecha_ultima_fact, YEAR TO SECOND)*/
          AND fecha_pago <= :fechaHoyHora
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CUENTA
          AND tipo_pago != TIPO_PAGO_DEPOSITO_GARANTIA
          AND tipo_pago != TIPO_PAGO_ANTICIPO_RETIRO
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CONVENIO
          /*AND pagco.numero_cliente = cliente.numero_cliente*/
          AND pagco.numero_cliente = hisfac_cont_temp.numero_cliente ;
   };
   /*----------------------------------------------------------------------------+
| Agregar para implementar pago de debito automatico rechazado:               |
|                                                                             |
| AND NOT EXISTS ( SELECT 'X'                                                 |
|                 FROM pagaut_rechazado                                       |
|                WHERE pagaut_rechazado.numero_cliente = pagco.numero_cliente |
|                  AND pagaut_rechazado.corr_pagos     = pagco.corr_pagos );  | +----------------------------------------------------------------------------*/
   return ( cantReg );
}


/*****************************************************************************/

Tpagco *ObtenerArrayPagosParaIntereses( cantRegPagos , identif , fechaHoy)
    long cantRegPagos ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
$Tpagco     regPago ;
$Tpagco   * arrayPagos ;
int         i = 0 ;

/* $datetime year to second fechaHoyHora;
   PasaFechaAFechaHora(fechaHoy,&fechaHoyHora); */

   arrayPagos = (Tpagco *) malloc ( sizeof (Tpagco ) * cantRegPagos );
   if ( arrayPagos == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayPagosParaIntereses \n" );
      exit (1);
   };
   finArrayPagos = arrayPagos + cantRegPagos -1 ;
   RegistraInicioSql("DECLARE curPagos...de datosgen");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT pagco.numero_cliente,"
                       "       pagco.corr_pagos,"
                       "       pagco.fecha_pago,"
                       "       pagco.tipo_pago,"
                       "       pagco.valor_pago,"
                       "       pagco.fecha_actualiza,"
                       "       pagco.cajero,"
                       "       pagco.oficina,"
                       "       pagco.llave,"
                       "       pagco.nro_docto_asociado,"
                       "       pagco.corr_docto_asocia,"
                       "       pagco.codigo_contable,"
                       "       pagco.valor_pago_suj_int,"
                       "       pagco.sector,"
                       "       pagco.sucursal,"
                       "       pagco.centro_emisor,"
                       "       pagco.tipo_docto"
                       "  FROM pagco,"
                       "       cliente"
                       " WHERE cliente.sucursal = '%s'"
                       "   AND cliente.sector = %ld"
                       "   AND fecha_pago >= EXTEND(cliente.fecha_ultima_fact, YEAR TO SECOND)"
                       "   AND fecha_pago <= EXTEND(DATE(%ld), YEAR TO SECOND)"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       "   AND pagco.numero_cliente = cliente.numero_cliente"
                       "   AND pagco.numero_cliente = %ld"
                       " ORDER BY pagco.numero_cliente ,fecha_pago",
                       datosGen.sucursal,
                       datosGen.sector,
                       fechaHoy,
                       TIPO_PAGO_ANTICIPO_CUENTA,
                       TIPO_PAGO_DEPOSITO_GARANTIA,
                       TIPO_PAGO_ANTICIPO_RETIRO,
                       TIPO_PAGO_ANTICIPO_CONVENIO,
                       datosGen.numeroClienteInicial );
   }
   else
   {
      sprintf(gstrSql, "SELECT pagco.numero_cliente,"
                       "       pagco.corr_pagos,"
                       "       pagco.fecha_pago,"
                       "       pagco.tipo_pago,"
                       "       pagco.valor_pago,"
                       "       pagco.fecha_actualiza,"
                       "       pagco.cajero,"
                       "       pagco.oficina,"
                       "       pagco.llave,"
                       "       pagco.nro_docto_asociado,"
                       "       pagco.corr_docto_asocia,"
                       "       pagco.codigo_contable,"
                       "       pagco.valor_pago_suj_int,"
                       "       pagco.sector,"
                       "       pagco.sucursal,"
                       "       pagco.centro_emisor,"
                       "       pagco.tipo_docto"
                       "  FROM pagco,"
                       /*"       cliente,"*/
                       "       hisfac_cont_temp"
                       "       ,hisfac" /* PDP - Calculo Interes Mora MAL */
                       " WHERE hisfac_cont_temp.numero_cliente >= %ld"
                       "   AND hisfac_cont_temp.numero_cliente <= %ld"
                       /* PDP - Calculo Interes Mora MAL */
                       /*"   AND hisfac_cont_temp.sucursal = cliente.sucursal "
                       "   AND hisfac_cont_temp.sector = cliente.sector "*/
                       /*"   AND hisfac_cont_temp.sucursal = '%s'"
                       "   AND hisfac_cont_temp.sector = %ld"
                       "   AND hisfac_cont_temp.identif_agenda = %ld"*/
                       "   AND hisfac_cont_temp.fecha_facturacion = %ld"
                       /*"   AND cliente.sucursal = '%s'"
                       "   AND cliente.sector = %ld"*/
                       "   AND hisfac.numero_cliente   = hisfac_cont_temp.numero_cliente "
                       "   AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - 1 "
                       "   AND fecha_pago >= EXTEND(hisfac.fecha_facturacion, YEAR TO SECOND) "
                       /*"   AND fecha_pago >= EXTEND(cliente.fecha_ultima_fact, YEAR TO SECOND)"*/
                       "   AND fecha_pago <= EXTEND(DATE(%ld), YEAR TO SECOND)"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       "   AND tipo_pago != '%s'"
                       /*"   AND pagco.numero_cliente = cliente.numero_cliente"*/
                       "   AND pagco.numero_cliente = hisfac_cont_temp.numero_cliente"
                       " ORDER BY pagco.numero_cliente ,fecha_pago",
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       /* PDP - Calculo Interes Mora MAL */
                       /*datosGen.sucursal,
                       datosGen.sector,
                       identif,*/
                       fechaHoy, 
                       /*datosGen.sucursal,
                       datosGen.sector,*/
                       fechaHoy,
                       TIPO_PAGO_ANTICIPO_CUENTA,
                       TIPO_PAGO_DEPOSITO_GARANTIA,
                       TIPO_PAGO_ANTICIPO_RETIRO,
                       TIPO_PAGO_ANTICIPO_CONVENIO);
   };
   /*----------------------------------------------------------------------------+
| Agregar arriba del ORDER BY al implementar rechazo de pago de debito        /
/ automatico                                                                  |
|                                                                             |
| AND NOT EXISTS ( SELECT 'X'                                                 |
|                    FROM pagaut_rechazado                                    |
|                WHERE pagaut_rechazado.numero_cliente = pagco.numero_cliente |
|                  AND pagaut_rechazado.corr_pagos     = pagco.corr_pagos )   | +-----------------------------------------------------------------------------*/
                                                      RegistraInicioSql("PREPARE/DECLARE curPagos");
   $PREPARE acPagosSql FROM $gstrSql;
   $DECLARE curPagos CURSOR FOR acPagosSql;
   RegistraInicioSql("OPEN curPagos");
   $OPEN curPagos;
   RegistraInicioSql("FETCH curPagos");
   $FETCH curPagos INTO :regPago.numeroCliente,
                        :regPago.corrPagos,
                        :regPago.fechaPago,
                        :regPago.tipoPago,
                        :regPago.valorPago,
                        :regPago.fechaActualiza,
                        :regPago.cajero,
                        :regPago.oficina,
                        :regPago.llave,
                        :regPago.nroDoctoAsociado,
                        :regPago.corrDoctoAsocia,
                        :regPago.codigoContable,
                        :regPago.valorPagoSujInt,
                        :regPago.sector,
                        :regPago.sucursal,
                        :regPago.centroEmisor,
                        :regPago.tipoDocto;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla pagco debe estar lockeada en modo exclusivo */
   {
      arrayPagos [i] = regPago;
      $FETCH curPagos INTO :regPago.numeroCliente,
                           :regPago.corrPagos,
                           :regPago.fechaPago,
                           :regPago.tipoPago,
                           :regPago.valorPago,
                           :regPago.fechaActualiza,
                           :regPago.cajero,
                           :regPago.oficina,
                           :regPago.llave,
                           :regPago.nroDoctoAsociado,
                           :regPago.corrDoctoAsocia,
                           :regPago.codigoContable,
                           :regPago.valorPagoSujInt,
                           :regPago.sector,
                           :regPago.sucursal,
                           :regPago.centroEmisor,
                           :regPago.tipoDocto ;
   };
   RegistraInicioSql("CLOSE curPago...");
   $CLOSE curPagos;
   return ( arrayPagos );
}


/*****************************************************************************/

Tpagco * ObtenerPrimerPagoCliente ( numeroCliente )
    long numeroCliente ;
{

Tpagco regPagoABuscar ;
Tpagco *regPago ;

if ( datosGen.cantRegPagosParaIntereses == 0 )
    return ( NULL );


regPagoABuscar.numeroCliente = numeroCliente ;

regPago = ( Tpagco *) bsearch ((void*) (  &regPagoABuscar),
                      (  void * ) datosGen.arrayPagosParaIntereses ,
                       datosGen.cantRegPagosParaIntereses,
                       sizeof ( Tpagco ),
                       ComparaRegPagco );
pagoInicialDelCliente = regPago ;
ultimoPagoDelCliente  = regPago ;
direccionProxPago     = ABAJO  ;


return ( regPago );

}


/*****************************************************************************/

Tpagco * ObtenerSiguientePagoCliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxPago == ABAJO )
    {
    if ( ultimoPagoDelCliente == finArrayPagos )
        {
        direccionProxPago = ARRIBA ;
        ultimoPagoDelCliente = pagoInicialDelCliente ;
        }
    else
        {

        ultimoPagoDelCliente = ultimoPagoDelCliente + 1;

        if ( ultimoPagoDelCliente->numeroCliente != numeroCliente )
            {
            direccionProxPago = ARRIBA ;
            ultimoPagoDelCliente = pagoInicialDelCliente ;
            }
        }
    }


if ( direccionProxPago == ARRIBA )
    {

    if ( ultimoPagoDelCliente == datosGen.arrayPagosParaIntereses )
        ultimoPagoDelCliente = NULL;
    else
        {
        ultimoPagoDelCliente = ultimoPagoDelCliente - 1 ;

        if ( ultimoPagoDelCliente->numeroCliente != numeroCliente )
            ultimoPagoDelCliente = NULL;
        }
    }


return ( ultimoPagoDelCliente ) ;

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de pagco
 *   Para uso con bsearch .                                                       */
/*Se modifica por migracion a AIX*/
int ComparaRegPagco(const void *reg1, const void *reg2)
{
return ( ( ((Tpagco *)reg1)->numeroCliente ) - ( ((Tpagco *)reg2)->numeroCliente) );
}


/*****************************************************************************/

int ObtenerCantRegRefac(identif, fechaHoy)
    $PARAMETER long identif;
    $PARAMETER long fechaHoy ;
{
    $int cantReg = 0 ;

    RegistraInicioSql("count de refac ");
    if ( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
    {
        $SELECT Count(*) INTO :cantReg
           FROM Refac, Cliente
          WHERE Cliente.sucursal     = :datosGen.sucursal
            AND Cliente.sector       = :datosGen.sector
            AND Refac.numero_cliente = Cliente.numero_cliente
            AND Refac.numero_cliente = :datosGen.numeroClienteInicial
            AND fecha_refacturac > Cliente.fecha_ultima_fact
            AND fecha_refacturac <= :fechaHoy;
    }
    else
    {
        $SELECT Count(*) INTO :cantReg
           /*FROM Refac, Cliente, hisfac_cont_temp*/
           FROM Refac, hisfac_cont_temp
               , hisfac /* PDP - Calculo Interes Mora MAL */
          WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
            AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
            /* PDP - Calculo Interes Mora MAL */
            /*AND hisfac_cont_temp.sucursal = Cliente.sucursal 
            AND hisfac_cont_temp.sector   = Cliente.sector   */
            /*AND hisfac_cont_temp.sucursal = :datosGen.sucursal
            AND hisfac_cont_temp.sector   = :datosGen.sector
            AND hisfac_cont_temp.identif_agenda = :identif*/
            AND hisfac_cont_temp.fecha_facturacion = :fechaHoy 
            /*AND Cliente.sucursal = :datosGen.sucursal
            AND Cliente.sector   = :datosGen.sector*/
            /*AND Refac.numero_cliente = Cliente.numero_cliente*/
            AND Refac.numero_cliente = hisfac_cont_temp.numero_cliente
            AND hisfac.numero_cliente   = hisfac_cont_temp.numero_cliente
            AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - 1
            AND fecha_refacturac > hisfac.fecha_facturacion
            /*AND fecha_refacturac > Cliente.fecha_ultima_fact*/
            AND fecha_refacturac <= :fechaHoy;
   };

   return cantReg;
}



/*****************************************************************************/

Trefac *ObtenerArrayRefac(cantRegRefac, identif, fechaHoy)
    long cantRegRefac ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
    $Trefac  regRefac ;
    $Trefac *arrayRefac ;
    int      i = 0 ;

    arrayRefac = (Trefac *) malloc( sizeof(Trefac) * cantRegRefac );
    if ( arrayRefac == NULL )
    {
        fputs("Error malloc ObtenerArrayRefac\n", stderr);
        exit(1);
    };

    finArrayRefac = arrayRefac + cantRegRefac - 1;

    RegistraInicioSql("DECLARE curRefac...de datosgen");

    if ( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
    {
      sprintf(gstrSql, "SELECT refac.numero_cliente,"
                    "       refac.corr_refacturacion,"
                    "       refac.fecha_fact_afect,"
                    "       refac.nro_docto_afect,"
                    "       refac.fecha_refacturac,"
                    "       refac.fecha_vencimiento,"
                    "       refac.total_refacturado,"
                    "       refac.tipo_nota,"
                    "       refac.clase_servicio,"
                    "       refac.resp_iva,"
                    "       refac.jurisdiccion,"
                    "       refac.tarifa,"
                    "       refac.kwh,"
                    "       refac.tot_refac_suj_int,"
                    "       refac.numero_nota,"
                    "       refac.orden_ajuste,"
                    "       refac.total_impuestos,"
                    "       refac.partido,"
                    "       refac.centro_emisor,"
                    "       refac.tipo_docto,"
                    "       refac.motivo,"
                    "       refac.rol"
                    "  FROM refac, cliente"
                    " WHERE cliente.sucursal = '%s'"
                    "   AND cliente.sector = %ld"
                    "   AND refac.numero_cliente = cliente.numero_cliente"
                    "   AND refac.numero_cliente = %ld"
                    "   AND fecha_refacturac > cliente.fecha_ultima_fact"
                    "   AND fecha_refacturac <= %ld"
                    " ORDER BY refac.numero_cliente",
                    datosGen.sucursal,
                    datosGen.sector,
                    datosGen.numeroClienteInicial,
                    fechaHoy );
    }
    else
    {
      sprintf(gstrSql, "SELECT refac.numero_cliente,"
                    "       refac.corr_refacturacion,"
                    "       refac.fecha_fact_afect,"
                    "       refac.nro_docto_afect,"
                    "       refac.fecha_refacturac,"
                    "       refac.fecha_vencimiento,"
                    "       refac.total_refacturado,"
                    "       refac.tipo_nota,"
                    "       refac.clase_servicio,"
                    "       refac.resp_iva,"
                    "       refac.jurisdiccion,"
                    "       refac.tarifa,"
                    "       refac.kwh,"
                    "       refac.tot_refac_suj_int,"
                    "       refac.numero_nota,"
                    "       refac.orden_ajuste,"
                    "       refac.total_impuestos,"
                    "       refac.partido,"
                    "       refac.centro_emisor,"
                    "       refac.tipo_docto,"
                    "       refac.motivo,"
                    "       refac.rol"
                    /* PDP - Calculo Interes Mora MAL*/
                    /*"  FROM refac, cliente, hisfac_cont_temp"*/
                    "  FROM refac, hisfac_cont_temp"
                    "      ,hisfac " 
                    " WHERE hisfac_cont_temp.numero_cliente >= %ld"
                    "   AND hisfac_cont_temp.numero_cliente <= %ld"
                    /* PDP - Calculo Interes Mora MAL*/
                    /*"   AND hisfac_cont_temp.sucursal = cliente.sucursal "
                    "   AND hisfac_cont_temp.sector   = cliente.sector"*/
                    /*"   AND hisfac_cont_temp.sucursal = '%s'"
                    "   AND hisfac_cont_temp.sector   = %ld"
                    "   AND hisfac_cont_temp.identif_agenda = %ld"*/
                    "   AND hisfac_cont_temp.fecha_facturacion = %ld" 
                    /*"   AND cliente.sucursal = '%s'"
                    "   AND cliente.sector   = %ld"*/
                    /*"   AND refac.numero_cliente = cliente.numero_cliente"*/
                    "   AND refac.numero_cliente = hisfac_cont_temp.numero_cliente"
                    "   AND hisfac.numero_cliente   = hisfac_cont_temp.numero_cliente "
                    "   AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - 1 "
                    "   AND fecha_refacturac > hisfac.fecha_facturacion "
                    /*"   AND fecha_refacturac > cliente.fecha_ultima_fact"*/
                    "   AND fecha_refacturac <= %ld"
                    " ORDER BY refac.numero_cliente",
                    datosGen.numeroClienteInicial,
                    datosGen.numeroClienteFin,
                    /* PDP - Calculo Interes Mora MAL*/
                    /*datosGen.sucursal,
                    datosGen.sector,
                    identif,*/
                    fechaHoy, 
                    /*datosGen.sucursal,
                    datosGen.sector,*/
                    fechaHoy );
   }

   RegistraInicioSql("PREPARE/DECLARE filaRefac");
   $PREPARE acaRefacSql FROM $gstrSql;
   $DECLARE filaRefac CURSOR FOR acaRefacSql;

   RegistraInicioSql("OPEN filaRefac");
   $OPEN filaRefac;

   RegistraInicioSql("FETCH NEXT");
   $FETCH filaRefac INTO :regRefac.numeroCliente,
                         :regRefac.corrRefacturacion,
                         :regRefac.fechaFactAfect,
                         :regRefac.nroDoctoAfect,
                         :regRefac.fechaRefacturac,
                         :regRefac.fechaVencimiento,
                         :regRefac.totalRefacturado,
                         :regRefac.tipoNota,
                         :regRefac.claseServicio,
                         :regRefac.respIva,
                         :regRefac.jurisdiccion,
                         :regRefac.tarifa,
                         :regRefac.kwh,
                         :regRefac.totRefacSujInt,
                         :regRefac.numeroNota,
                         :regRefac.ordenAjuste,
                         :regRefac.totalImpuestos,
                         :regRefac.partido,
                         :regRefac.centroEmisor,
                         :regRefac.tipoDocto,
                         :regRefac.motivo,
                         :regRefac.rol;

    /* la tabla refac debe estar lockeada en modo exclusivo */
    for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
    {
        if (i == cantRegRefac)
        {
            fputs("Error: se excedio cant. registros en ObtenerArrayRefac",
                  stderr);
            exit(1);
        }

      arrayRefac[i] = regRefac;
      $FETCH filaRefac INTO :regRefac.numeroCliente,
                            :regRefac.corrRefacturacion,
                            :regRefac.fechaFactAfect,
                            :regRefac.nroDoctoAfect,
                            :regRefac.fechaRefacturac,
                            :regRefac.fechaVencimiento,
                            :regRefac.totalRefacturado,
                            :regRefac.tipoNota,
                            :regRefac.claseServicio,
                            :regRefac.respIva,
                            :regRefac.jurisdiccion,
                            :regRefac.tarifa,
                            :regRefac.kwh,
                            :regRefac.totRefacSujInt,
                            :regRefac.numeroNota,
                            :regRefac.ordenAjuste,
                            :regRefac.totalImpuestos,
                            :regRefac.partido,
                            :regRefac.centroEmisor,
                            :regRefac.tipoDocto,
                            :regRefac.motivo,
                            :regRefac.rol ;
   }

   RegistraInicioSql("CLOSE filaRefac...");
   $CLOSE filarefac;

   return arrayRefac;
}


/*****************************************************************************/

Trefac * ObtenerPrimerRefacCliente ( numeroCliente )
    long numeroCliente ;
{

Trefac regRefacABuscar ;
Trefac *regRefac ;

if ( datosGen.cantRegRefac == 0 )
    return ( NULL );


regRefacABuscar.numeroCliente = numeroCliente ;

regRefac = ( Trefac *) bsearch ((void*) (  &regRefacABuscar),
                      (  void * ) datosGen.arrayRefac ,
                       datosGen.cantRegRefac,
                       sizeof ( Trefac ),
                       ComparaRegRefac );
refacInicialDelCliente = regRefac ;
ultimoRefacDelCliente  = regRefac ;
direccionProxRefac     = ABAJO  ;


return ( regRefac );

}


/*****************************************************************************/

Trefac * ObtenerSiguienteRefacCliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxRefac == ABAJO )
    {
    if ( ultimoRefacDelCliente == finArrayRefac )
        {
        direccionProxRefac = ARRIBA ;
        ultimoRefacDelCliente = refacInicialDelCliente ;
        }
    else
        {

        ultimoRefacDelCliente = ultimoRefacDelCliente + 1;

        if ( ultimoRefacDelCliente->numeroCliente != numeroCliente )
            {
            direccionProxRefac = ARRIBA ;
            ultimoRefacDelCliente = refacInicialDelCliente ;
            }
        }
    }


if ( direccionProxRefac == ARRIBA )
    {

    if ( ultimoRefacDelCliente == datosGen.arrayRefac )
        ultimoRefacDelCliente = NULL;
    else
        {
        ultimoRefacDelCliente = ultimoRefacDelCliente - 1 ;

        if ( ultimoRefacDelCliente->numeroCliente != numeroCliente )
            ultimoRefacDelCliente = NULL;
        }
    }


return ( ultimoRefacDelCliente ) ;

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de refac
 *   Para uso con bsearch .                                                       */

int ComparaRegRefac(const void *reg1 , const void *reg2 )
{
return ( ( ((Trefac *)reg1)->numeroCliente ) - ( ((Trefac *)reg2)->numeroCliente) );
}



/*****************************************************************************/

int ObtenerCantRegLectu( identif , fechaHoy )
$PARAMETER long identif;
$PARAMETER long fechaHoy;
{
$int cantReg = 0 ;
   RegistraInicioSql("count de lectu ");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM lectu
        WHERE lectu.sucursal       = :datosGen.sucursal
          AND lectu.sector         = :datosGen.sector
          AND lectu.numero_cliente = :datosGen.numeroClienteInicial;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM lectu,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector   = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND lectu.sucursal       = :datosGen.sucursal
          AND lectu.sector         = :datosGen.sector
          AND lectu.numero_cliente = hisfac_cont_temp.numero_cliente;
   };
   return ( cantReg );
}



/*****************************************************************************/

Tlectu *ObtenerArrayLectu( cantRegLectu , identif , fechaHoy)
    long cantRegLectu ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
   $Tlectu     regLectu ;
   $Tlectu   * arrayLectu ;
   int         i = 0 ;

   arrayLectu = (Tlectu *) malloc ( sizeof (Tlectu ) * cantRegLectu );
   if( arrayLectu == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayLectu \n" );
      exit (1);
   };

   finArrayLectu = arrayLectu + cantRegLectu -1 ;

   RegistraInicioSql("DECLARE curLectu...de datosgen");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf( gstrSql, "SELECT lectu.numero_cliente,"
                        "       lectu.sector,"
                        "       lectu.zona,"
                        "       lectu.correlativo_ruta,"
                        "       lectu.correl_contador,"
                        "       lectu.sucursal,"
                        "       lectu.tarifa,"
                        "       lectu.consumo_30_dias,"
                        "       lectu.clave_lectura_act,"
                        "       lectu.corr_facturacion,"
                        "       lectu.numero_medidor,"
                        "       lectu.marca_medidor,"
                        "       lectu.enteros,"
                        "       lectu.decimales,"
                        "       lectu.constante,"
                        "       lectu.fecha_lectura_ant,"
                        "       lectu.fecha_lectura,"
                        "       lectu.lectura_ant,"
                        "       lectu.lectura_actual,"
                        "       lectu.consumo_activo,"
                        "       lectu.lectura_min,"
                        "       lectu.lectura_max,"
                        "       lectu.lectura_verif,"
                        "       lectu.estado_suministro,"
                        "       lectu.coseno_phi,"
                        "       lectu.porc_desvio,"
                        "       lectu.porc_desvio_perm,"
                        "       lectu.cant_estim_suces,"
                        "       lectu.cant_estimaciones,"
                        "       lectu.info_adic_lectura,"
                        "       lectu.lectura_a_fact,"
                        "       lectu.ind_verificacion,"
                        "       lectu.consumo_prop,"
                        "       lectu.tipo_lectura,"
                        "       lectu.ind_ret_medidor,"
                        "       lectu.nro_dir,"
                        "       lectu.piso_dir,"
                        "       lectu.depto_dir,"
                        "       lectu.nom_partido,"
                        "       lectu.tiene_calma,"
                        "       lectu.meses_cerrados,"
                        "       lectu.prox_c_meses_cerra,"
                        "       lectu.consumo_forzado,"
                        "       lectu.consumo_real,"
                        "       lectu.consumo_med_ant,"
                        "       lectu.prox_c_est_suces,"
                        "       lectu.prox_c_estimac,"
                        "       lectu.prox_cons_30_dias,"
                        "       lectu.fecha_lectura_ver,"
                        "       lectu.lectura_prop,"
                        "       lectu.frec_facturacion,"
                        "       lectu.nom_calle,"
                        "       lectu.tipo_cliente,"
                        "       lectu.limite_estimacion,"
                        "       lectu.ind_estimacion,"
                        "       lectu.tipo_lectura_reac,"  /* Agregado Reactiva */
                        "       lectu.lectu_actual_reac,"  /* Agregado Reactiva */
                        "       lectu.lectura_verif_reac," /* Agregado Reactiva */
                        "       lectu.lectura_prop_reac,"  /* Agregado Reactiva */
                        "       lectu.lectu_a_fact_reac,"  /* Agregado Reactiva */
                        "       lectu.cons_forzado_reac,"  /* Agregado Reactiva */
                        "       lectu.consumo_reac,"       /* Agregado Reactiva */
                        "       lectu.tipo_medidor,"       /* Agregado Reactiva */
                        "       lectu.lectura_ant_reac,"   /* Agregado Reactiva */
                        "       lectu.lectu_actual_reac,"  /* Agregado Reactiva */
                        "       lectu.evento,"             /* Agregado Reactiva */
                        /* PDP - OM1418 */
                        "       lectu.cons_real_activa,"
                        "       lectu.cons_real_reactiva,"
                        "       lectu.cos_phi_lect_real,"
                        "       lectu.cos_phi_per_cons"
                        "  FROM lectu"
                        " WHERE lectu.sucursal       = '%s'"
                        "   AND lectu.sector         = %ld"
                        "   AND lectu.numero_cliente = %ld"
                        " ORDER BY lectu.numero_cliente,"
                        "          lectu.fecha_lectura",
                        datosGen.sucursal,
                        datosGen.sector,
                        datosGen.numeroClienteInicial );
   }
   else
   {
      sprintf( gstrSql, "SELECT lectu.numero_cliente,"
                        "       lectu.sector,"
                        "       lectu.zona,"
                        "       lectu.correlativo_ruta,"
                        "       lectu.correl_contador,"
                        "       lectu.sucursal,"
                        "       lectu.tarifa,"
                        "       lectu.consumo_30_dias,"
                        "       lectu.clave_lectura_act,"
                        "       lectu.corr_facturacion,"
                        "       lectu.numero_medidor,"
                        "       lectu.marca_medidor,"
                        "       lectu.enteros,"
                        "       lectu.decimales,"
                        "       lectu.constante,"
                        "       lectu.fecha_lectura_ant,"
                        "       lectu.fecha_lectura,"
                        "       lectu.lectura_ant,"
                        "       lectu.lectura_actual,"
                        "       lectu.consumo_activo,"
                        "       lectu.lectura_min,"
                        "       lectu.lectura_max,"
                        "       lectu.lectura_verif,"
                        "       lectu.estado_suministro,"
                        "       lectu.coseno_phi,"
                        "       lectu.porc_desvio,"
                        "       lectu.porc_desvio_perm,"
                        "       lectu.cant_estim_suces,"
                        "       lectu.cant_estimaciones,"
                        "       lectu.info_adic_lectura,"
                        "       lectu.lectura_a_fact,"
                        "       lectu.ind_verificacion,"
                        "       lectu.consumo_prop,"
                        "       lectu.tipo_lectura,"
                        "       lectu.ind_ret_medidor,"
                        "       lectu.nro_dir,"
                        "       lectu.piso_dir,"
                        "       lectu.depto_dir,"
                        "       lectu.nom_partido,"
                        "       lectu.tiene_calma,"
                        "       lectu.meses_cerrados,"
                        "       lectu.prox_c_meses_cerra,"
                        "       lectu.consumo_forzado,"
                        "       lectu.consumo_real,"
                        "       lectu.consumo_med_ant,"
                        "       lectu.prox_c_est_suces,"
                        "       lectu.prox_c_estimac,"
                        "       lectu.prox_cons_30_dias,"
                        "       lectu.fecha_lectura_ver,"
                        "       lectu.lectura_prop,"
                        "       lectu.frec_facturacion,"
                        "       lectu.nom_calle,"
                        "       lectu.tipo_cliente,"
                        "       lectu.limite_estimacion,"
                        "       lectu.ind_estimacion,"
                        "       lectu.tipo_lectura_reac,"  /* Agregado Reactiva */
                        "       lectu.lectu_actual_reac,"  /* Agregado Reactiva */
                        "       lectu.lectura_verif_reac," /* Agregado Reactiva */
                        "       lectu.lectura_prop_reac,"  /* Agregado Reactiva */
                        "       lectu.lectu_a_fact_reac,"  /* Agregado Reactiva */
                        "       lectu.cons_forzado_reac,"  /* Agregado Reactiva */
                        "       lectu.consumo_reac,"       /* Agregado Reactiva */
                        "       lectu.tipo_medidor,"       /* Agregado Reactiva */
                        "       lectu.lectura_ant_reac,"   /* Agregado Reactiva */
                        "       lectu.lectu_actual_reac,"  /* Agregado Reactiva */
                        "       lectu.evento,"             /* Agregado Reactiva */
                        /* PDP - OM1418 */
                        "       lectu.cons_real_activa,"
                        "       lectu.cons_real_reactiva,"
                        "       lectu.cos_phi_lect_real,"
                        "       lectu.cos_phi_per_cons"
                        "  FROM lectu , hisfac_cont_temp"
                        " WHERE hisfac_cont_temp.sucursal = '%s'"
                        "   AND hisfac_cont_temp.sector   = %ld"
                        "   AND hisfac_cont_temp.identif_agenda = %ld"
                        "   AND hisfac_cont_temp.numero_cliente >= %ld"
                        "   AND hisfac_cont_temp.numero_cliente <= %ld"
                        "   AND lectu.sucursal       = '%s'"
                        "   AND lectu.sector         = %ld"
                        "   AND lectu.numero_cliente = hisfac_cont_temp.numero_cliente"
                        " ORDER BY lectu.numero_cliente,"
                        "          lectu.fecha_lectura",
                        datosGen.sucursal,
                        datosGen.sector,
                        identif,
                        datosGen.numeroClienteInicial,
                        datosGen.numeroClienteFin,
                        datosGen.sucursal,
                        datosGen.sector );
   };

   RegistraInicioSql("PREPARE/DECLARE curLectu");
   $PREPARE acLectuSql FROM $gstrSql;
   $DECLARE curLectu CURSOR FOR acLectuSql;

   RegistraInicioSql("OPEN curLectu");
   $OPEN curLectu;

   RegistraInicioSql("FETCH NEXT");
   $FETCH curLectu INTO :regLectu.numeroCliente,
                        :regLectu.sector,
                        :regLectu.zona,
                        :regLectu.correlativoRuta,
                        :regLectu.correlContador,
                        :regLectu.sucursal,
                        :regLectu.tarifa,
                        :regLectu.consumo30Dias,
                        :regLectu.claveLecturaAct,
                        :regLectu.corrFacturacion,
                        :regLectu.numeroMedidor,
                        :regLectu.marcaMedidor,
                        :regLectu.enteros,
                        :regLectu.decimales,
                        :regLectu.constante,
                        :regLectu.fechaLecturaAnt,
                        :regLectu.fechaLectura,
                        :regLectu.lecturaAnt,
                        :regLectu.lecturaActual,
                        :regLectu.consumoActivo,
                        :regLectu.lecturaMin,
                        :regLectu.lecturaMax,
                        :regLectu.lecturaVerif,
                        :regLectu.estadoSuministro,
                        :regLectu.cosenoPhi,
                        :regLectu.porcDesvio,
                        :regLectu.porcDesvioPerm,
                        :regLectu.cantEstimSuces,
                        :regLectu.cantEstimaciones,
                        :regLectu.infoAdicLectura,
                        :regLectu.lecturaAFact,
                        :regLectu.indVerificacion,
                        :regLectu.consumoProp,
                        :regLectu.tipoLectura,
                        :regLectu.indRetMedidor,
                        :regLectu.nroDir,
                        :regLectu.pisoDir,
                        :regLectu.deptoDir,
                        :regLectu.nomPartido,
                        :regLectu.tieneCalma,
                        :regLectu.mesesCerrados,
                        :regLectu.proxCMesesCerra,
                        :regLectu.consumoForzado,
                        :regLectu.consumoReal,
                        :regLectu.consumoMedAnt,
                        :regLectu.proxCEstSuces,
                        :regLectu.proxCEstimac,
                        :regLectu.proxCons30Dias,
                        :regLectu.fechaLecturaVer,
                        :regLectu.lecturaProp,
                        :regLectu.frecFacturacion,
                        :regLectu.nomCalle,
                        :regLectu.tipoCliente,
                        :regLectu.limiteEstimacion,
                        :regLectu.indEstimacion,
                        :regLectu.tipoLecturaReac,   /* Agregado Reactiva */
                        :regLectu.lecturaActualReac, /* Agregado Reactiva */
                        :regLectu.lecturaVerifReac,  /* Agregado Reactiva */
                        :regLectu.lecturaPropReac,   /* Agregado Reactiva */
                        :regLectu.lectuAFactReac,    /* Agregado Reactiva */
                        :regLectu.consForzadoReac,   /* Agregado Reactiva */
                        :regLectu.consumoReac,       /* Agregado Reactiva */
                        :regLectu.tipoMedidor,       /* Agregado Reactiva */
                        :regLectu.lecturaAntReac,    /* Agregado Reactiva */
                        :regLectu.lecturaActualReac, /* Agregado Reactiva */
                        :regLectu.evento,            /* Agregado Reactiva */
                        /* PDP - OM1418 */
                        :regLectu.consRealActiva,
                        :regLectu.consRealReactiva,
                        :regLectu.cosPhiLectReal,
                        :regLectu.cosPhiPerCons;

   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla lectu debe estar lockeada en modo exclusivo */
   {
      arrayLectu [i] = regLectu;
      $FETCH curLectu INTO :regLectu.numeroCliente,
                           :regLectu.sector,
                           :regLectu.zona,
                           :regLectu.correlativoRuta,
                           :regLectu.correlContador,
                           :regLectu.sucursal,
                           :regLectu.tarifa,
                           :regLectu.consumo30Dias,
                           :regLectu.claveLecturaAct,
                           :regLectu.corrFacturacion,
                           :regLectu.numeroMedidor,
                           :regLectu.marcaMedidor,
                           :regLectu.enteros,
                           :regLectu.decimales,
                           :regLectu.constante,
                           :regLectu.fechaLecturaAnt,
                           :regLectu.fechaLectura,
                           :regLectu.lecturaAnt,
                           :regLectu.lecturaActual,
                           :regLectu.consumoActivo,
                           :regLectu.lecturaMin,
                           :regLectu.lecturaMax,
                           :regLectu.lecturaVerif,
                           :regLectu.estadoSuministro,
                           :regLectu.cosenoPhi,
                           :regLectu.porcDesvio,
                           :regLectu.porcDesvioPerm,
                           :regLectu.cantEstimSuces,
                           :regLectu.cantEstimaciones,
                           :regLectu.infoAdicLectura,
                           :regLectu.lecturaAFact,
                           :regLectu.indVerificacion,
                           :regLectu.consumoProp,
                           :regLectu.tipoLectura,
                           :regLectu.indRetMedidor,
                           :regLectu.nroDir,
                           :regLectu.pisoDir,
                           :regLectu.deptoDir,
                           :regLectu.nomPartido,
                           :regLectu.tieneCalma,
                           :regLectu.mesesCerrados,
                           :regLectu.proxCMesesCerra,
                           :regLectu.consumoForzado,
                           :regLectu.consumoReal,
                           :regLectu.consumoMedAnt,
                           :regLectu.proxCEstSuces,
                           :regLectu.proxCEstimac,
                           :regLectu.proxCons30Dias,
                           :regLectu.fechaLecturaVer,
                           :regLectu.lecturaProp,
                           :regLectu.frecFacturacion,
                           :regLectu.nomCalle,
                           :regLectu.tipoCliente,
                           :regLectu.limiteEstimacion,
                           :regLectu.indEstimacion,
                           :regLectu.tipoLecturaReac,   /* Agregado Reactiva */
                           :regLectu.lecturaActualReac, /* Agregado Reactiva */
                           :regLectu.lecturaVerifReac,  /* Agregado Reactiva */
                           :regLectu.lecturaPropReac,   /* Agregado Reactiva */
                           :regLectu.lectuAFactReac,    /* Agregado Reactiva */
                           :regLectu.consForzadoReac,   /* Agregado Reactiva */
                           :regLectu.consumoReac,       /* Agregado Reactiva */
                           :regLectu.tipoMedidor,       /* Agregado Reactiva */
                           :regLectu.lecturaAntReac,    /* Agregado Reactiva */
                           :regLectu.lecturaActualReac, /* Agregado Reactiva */
                           :regLectu.evento,            /* Agregado Reactiva */
                           /* PDP - OM1418 */
                           :regLectu.consRealActiva,
                           :regLectu.consRealReactiva,
                           :regLectu.cosPhiLectReal,
                           :regLectu.cosPhiPerCons;
   };

   RegistraInicioSql("CLOSE curLectu...");
   $CLOSE curLectu;

   return ( arrayLectu );
}



/*****************************************************************************/

Tlectu * ObtenerPrimerLectuCliente ( numeroCliente )
    long numeroCliente ;
{

Tlectu regLectuABuscar ;
Tlectu *regLectu ;

if ( datosGen.cantRegLectu == 0 )
    return ( NULL );


regLectuABuscar.numeroCliente = numeroCliente ;

regLectu = ( Tlectu *) bsearch ((void*) (  &regLectuABuscar),
                      (  void * ) datosGen.arrayLectu ,
                       datosGen.cantRegLectu,
                       sizeof ( Tlectu ),
                       ComparaRegLectu );
lectuInicialDelCliente = regLectu ;
ultimoLectuDelCliente  = regLectu ;
direccionProxLectu     = ABAJO  ;


return ( regLectu );

}


/*****************************************************************************/

Tlectu * ObtenerSiguienteLectuCliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxLectu == ABAJO )
    {
    if ( ultimoLectuDelCliente == finArrayLectu )
        {
        direccionProxLectu = ARRIBA ;
        ultimoLectuDelCliente = lectuInicialDelCliente ;
        }
    else
        {

        ultimoLectuDelCliente = ultimoLectuDelCliente + 1;

        if ( ultimoLectuDelCliente->numeroCliente != numeroCliente )
            {
            direccionProxLectu = ARRIBA ;
            ultimoLectuDelCliente = lectuInicialDelCliente ;
            }
        }
    }


if ( direccionProxLectu == ARRIBA )
    {

    if ( ultimoLectuDelCliente == datosGen.arrayLectu )
        ultimoLectuDelCliente = NULL;
    else
        {
        ultimoLectuDelCliente = ultimoLectuDelCliente - 1 ;

        if ( ultimoLectuDelCliente->numeroCliente != numeroCliente )
            ultimoLectuDelCliente = NULL;
        }
    }


return ( ultimoLectuDelCliente ) ;

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de lectu
 *   Para uso con bsearch .                                                       */

int
ComparaRegLectu( reg1 , reg2 )
   Tlectu *reg1;
   Tlectu *reg2;
{
return ( ( reg1->numeroCliente ) - ( reg2->numeroCliente) );
}



/*****************************************************************************/

int ObtenerCantRegDetalle( identif , fechaHoy)
    $PARAMETER long identif;
    $PARAMETER long fechaHoy ;
{
$int cantReg = 0 ;
   RegistraInicioSql("count de det_val_tarifas ");

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM det_val_tarifas
        WHERE identif_agenda = :identif
          AND det_val_tarifas.numero_cliente = :datosGen.numeroClienteInicial;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM det_val_tarifas
        WHERE identif_agenda = :identif
          AND det_val_tarifas.numero_cliente >= :datosGen.numeroClienteInicial
          AND det_val_tarifas.numero_cliente <= :datosGen.numeroClienteFin ;
   };
   return ( cantReg );
}



/*****************************************************************************/

TdetValTarifas *ObtenerArrayDetalle ( cantRegDetalle , identif , fechaHoy)
    long cantRegDetalle ;
    $PARAMETER long identif;
    $PARAMETER long fechaHoy;
{
$TdetValTarifas   regDetalle ;
$TdetValTarifas * arrayDetalle ;
int               i = 0 ;

   arrayDetalle = (TdetValTarifas *) malloc ( sizeof (TdetValTarifas ) * cantRegDetalle );
   if ( arrayDetalle == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayDetalle \n" );
      exit (1);
   };
   finArrayDetalle = arrayDetalle + cantRegDetalle -1 ;
   RegistraInicioSql("DECLARE curDetalle...de datosgen");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT det_val_tarifas.numero_cliente,"
                    "       det_val_tarifas.corr_facturacion,"
                    "       det_val_tarifas.tipo_cargo_tarifa,"
                    "       det_val_tarifas.corr_precio,"
                    "       det_val_tarifas.duracion_periodo,"
                    "       det_val_tarifas.precio_unitario,"
                    "       det_val_tarifas.dias_totales,"
                    "       det_val_tarifas.precio_ponderado,"
                    "       det_val_tarifas.identif_agenda"
                    "  FROM det_val_tarifas"
                    " WHERE identif_agenda = %ld"
                    "   AND det_val_tarifas.numero_cliente = %ld"
                    " ORDER BY numero_cliente, tipo_cargo_tarifa, corr_precio",
                    identif,
                    datosGen.numeroClienteInicial );
   }
   else
   {
      sprintf(gstrSql, "SELECT det_val_tarifas.numero_cliente,"
                    "       det_val_tarifas.corr_facturacion,"
                    "       det_val_tarifas.tipo_cargo_tarifa,"
                    "       det_val_tarifas.corr_precio,"
                    "       det_val_tarifas.duracion_periodo,"
                    "       det_val_tarifas.precio_unitario,"
                    "       det_val_tarifas.dias_totales,"
                    "       det_val_tarifas.precio_ponderado,"
                    "       det_val_tarifas.identif_agenda"
                    "  FROM det_val_tarifas"
                    " WHERE identif_agenda = %ld"
                    "   AND det_val_tarifas.numero_cliente >= %ld"
                    "   AND det_val_tarifas.numero_cliente <= %ld"
                    " ORDER BY numero_cliente, tipo_cargo_tarifa, corr_precio",
                    identif,
                    datosGen.numeroClienteInicial,
                    datosGen.numeroClienteFin );
   };
   /*-------------------------------------------+
    | NOTA:                                     |
    |    Se supone que cargo fijo viene primero |
    +-------------------------------------------*/
   RegistraInicioSql("OPEN curDetalle");
   $PREPARE acDetalleSql FROM $gstrSql;
   $DECLARE curDetalle CURSOR FOR acDetalleSql;
   RegistraInicioSql("OPEN curDetalle");
   $OPEN curDetalle;
   RegistraInicioSql("FETCH curDetalle");
   $FETCH curDetalle INTO :regDetalle.numeroCliente,
                          :regDetalle.corrFacturacion,
                          :regDetalle.tipoCargoTarifa,
                          :regDetalle.corrPrecio,
                          :regDetalle.duracionPeriodo,
                          :regDetalle.precioUnitario,
                          :regDetalle.diasTotales,
                          :regDetalle.precioPonderado,
                          :regDetalle.identifAgenda;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /*det_val_tarifas debe estar lockeada en modo exclusivo */
   {
      arrayDetalle [i] = regDetalle;
      $FETCH curDetalle INTO :regDetalle.numeroCliente,
                             :regDetalle.corrFacturacion,
                             :regDetalle.tipoCargoTarifa,
                             :regDetalle.corrPrecio,
                             :regDetalle.duracionPeriodo,
                             :regDetalle.precioUnitario,
                             :regDetalle.diasTotales,
                             :regDetalle.precioPonderado,
                             :regDetalle.identifAgenda ;
   };
   RegistraInicioSql("CLOSE curDetalle...");
   $CLOSE curDetalle;
   return ( arrayDetalle );
}



 /******************************************************************************/ /*     funcion tipo abajo                                                        */


TdetValTarifas * ObtenerPrimerDetalleCliente ( numeroCliente )
    long numeroCliente ;
{

TdetValTarifas regDetalleABuscar ;
TdetValTarifas *regDetalle ;

if ( datosGen.cantRegDetalle == 0 )
    return ( NULL );


regDetalleABuscar.numeroCliente = numeroCliente ;

regDetalle = ( TdetValTarifas *) bsearch ((void*) (  &regDetalleABuscar),
                      (  void * ) datosGen.arrayDetalle ,
                       datosGen.cantRegDetalle,
                       sizeof ( TdetValTarifas ),
                       ComparaRegDetalle );

if ( regDetalle == NULL )
    return ( NULL );

while ( (regDetalle-1)->numeroCliente == numeroCliente && regDetalle != datosGen.arrayDetalle )
    {
    regDetalle -- ;
    }

ultimoDetalleDelCliente    = regDetalle ;


return ( regDetalle );

}


/*****************************************************************************/

TdetValTarifas * ObtenerSiguienteDetalleCliente( numeroCliente )
    long numeroCliente ;
{

    if ( ultimoDetalleDelCliente == finArrayDetalle )
        {
        ultimoDetalleDelCliente = NULL ;
        }
    else
        {

        ultimoDetalleDelCliente = ultimoDetalleDelCliente + 1;

        if ( ultimoDetalleDelCliente->numeroCliente != numeroCliente )
            {
            ultimoDetalleDelCliente = NULL ;
            }
        }


return ( ultimoDetalleDelCliente ) ;

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de det_val_tarifas
 *   Para uso con bsearch .                                                       */

int
ComparaRegDetalle( reg1 , reg2 )
   TdetValTarifas *reg1;
   TdetValTarifas *reg2;
{
return ( ( reg1->numeroCliente ) - ( reg2->numeroCliente) );
}


/*****************************************************************************/

int ObtenerCantRegConsumo( identif )
    $PARAMETER long identif;
{
$int cantReg = 0 ;
   RegistraInicioSql("count de consumo ");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM hisfac,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.numero_cliente = :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector   = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda =  :identif
          AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente
          AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - cant_hisfac ( hisfac_cont_temp.tarifa[3] );
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM hisfac,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector   = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda =  :identif
          AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente
          AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion - cant_hisfac ( hisfac_cont_temp.tarifa[3] );
   };
   return ( cantReg );
}



/*****************************************************************************/

Tconsumo *ObtenerArrayConsumo( cantRegConsumo , identif )
   long cantRegConsumo ;
   $PARAMETER long identif;
{
$Tconsumo   regConsumo ;
$Tconsumo * arrayConsumo ;
int         i = 0 ;

   arrayConsumo = (Tconsumo *) malloc ( sizeof (Tconsumo ) * cantRegConsumo );
   if ( arrayConsumo == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConsumo \n" );
      exit (1);
   };
   RegistraInicioSql("DECLARE curConsumo...de datosgen");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT hisfac.numero_cliente,"
                       "       hisfac.consumo_sum"
                       "  FROM hisfac , hisfac_cont_temp"
                       " WHERE hisfac_cont_temp.numero_cliente = %ld"
                       "   AND hisfac_cont_temp.sucursal = '%s'"
                       "   AND hisfac_cont_temp.sector   = %ld"
                       "   AND hisfac_cont_temp.identif_agenda =  %ld"
                       "   AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente"
                       "   AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion -"
                       "                                 cant_hisfac ( hisfac_cont_temp.tarifa[3] )"
                       " ORDER BY hisfac.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.sucursal,
                       datosGen.sector,
                       identif );
   }
   else
   {
      sprintf(gstrSql, "SELECT hisfac.numero_cliente,"
                       "       hisfac.consumo_sum"
                       "  FROM hisfac , hisfac_cont_temp"
                       " WHERE hisfac_cont_temp.numero_cliente >= %ld"
                       "   AND hisfac_cont_temp.numero_cliente <= %ld"
                       "   AND hisfac_cont_temp.sucursal = '%s'"
                       "   AND hisfac_cont_temp.sector   = %ld"
                       "   AND hisfac_cont_temp.identif_agenda =  %ld"
                       "   AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente"
                       "   AND hisfac.corr_facturacion = hisfac_cont_temp.corr_facturacion -"
                       "                                 cant_hisfac ( hisfac_cont_temp.tarifa[3] )"
                       " ORDER BY hisfac.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector,
                       identif );

   };
   RegistraInicioSql("PREPARE/DECLARE curConsumo");
   $PREPARE acConsumoSql FROM $gstrSql;
   $DECLARE curConsumo CURSOR FOR acConsumoSql;
   RegistraInicioSql("OPEN curConsumo");
   $OPEN curConsumo;
   RegistraInicioSql("FETCH NEXT");
   $FETCH NEXT curConsumo into :regConsumo;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
   {
      arrayConsumo [i] = regConsumo;
      $FETCH curConsumo INTO $regConsumo ;
   }
   RegistraInicioSql("CLOSE curCosnumo...");
   $CLOSE curConsumo;
   return ( arrayConsumo );
}



/****************************************************************************/

Tconsumo * ObtenerRegConsumoAnteriorCliente ( numeroCliente )
    long numeroCliente ;
{

Tconsumo regConsumoABuscar ;
Tconsumo *regConsumo ;


if ( datosGen.cantRegConsumo == 0 )
    return ( NULL );

regConsumoABuscar.numeroCliente = numeroCliente ;

regConsumo = ( Tconsumo *) bsearch ((void*) (  &regConsumoABuscar),
                      (  void * ) datosGen.arrayConsumo ,
                       datosGen.cantRegConsumo,
                       sizeof ( Tconsumo ),
                       ComparaRegConsumo );

return ( regConsumo );

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de consumo
 *   Para uso con bsearch .                                                       */

int
ComparaRegConsumo( reg1 , reg2 )
   Tconsumo *reg1;
   Tconsumo *reg2;
{
return ( ( reg1->numeroCliente ) - ( reg2->numeroCliente) );
}


/*****************************************************************************/

int ObtenerCantRegPromedio( identif )
    $PARAMETER long identif;
{
$int cantReg = 0 ;
   RegistraInicioSql("count de promedio ");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count ( unique hisfac.numero_cliente )
         INTO  :cantReg
         FROM  hisfac,
               hisfac_cont_temp
        WHERE  hisfac_cont_temp.numero_cliente = :datosGen.numeroClienteInicial
          AND  hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND  hisfac_cont_temp.sector   = :datosGen.sector
          AND  hisfac_cont_temp.identif_agenda =  :identif
          AND  hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente
          AND  hisfac.corr_facturacion
               BETWEEN hisfac_cont_temp.corr_facturacion -  cant_hisfac ( hisfac_cont_temp.tarifa[3] )
                   AND hisfac_cont_temp.corr_facturacion ;
   }
   else
   {
      $SELECT count ( unique hisfac.numero_cliente )
         INTO :cantReg
         FROM hisfac,
              hisfac_cont_temp
        WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector   = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda =  :identif
          AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente
          AND hisfac.corr_facturacion
              BETWEEN hisfac_cont_temp.corr_facturacion -  cant_hisfac ( hisfac_cont_temp.tarifa[3] )
                  AND hisfac_cont_temp.corr_facturacion ;
   };
   return ( cantReg );
}



/*****************************************************************************/
Tpromedio *ObtenerArrayPromedio( cantRegPromedio , identif )
   long cantRegPromedio ;
   $PARAMETER long identif;
{
$Tpromedio    regPromedio ;
$Tpromedio  * arrayPromedio ;
int           i = 0 ;

   arrayPromedio = (Tpromedio *) malloc ( sizeof (Tpromedio ) * cantRegPromedio );
   if ( arrayPromedio == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayPromedio \n" );
      exit (1);
   };

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT hisfac.numero_cliente , sum(hisfac.consumo_sum), count (*)"
                    "  FROM hisfac,"
                    "       hisfac_cont_temp"
                    " WHERE hisfac_cont_temp.numero_cliente = %ld"
                    "   AND hisfac_cont_temp.sucursal = '%s'"
                    "   AND hisfac_cont_temp.sector = %ld"
                    "   AND hisfac_cont_temp.identif_agenda = %ld"
                    "   AND hisfac.numero_cliente = hisfac_cont_temp.numero_cliente"
                    "   AND hisfac.corr_facturacion"
                    "       BETWEEN hisfac_cont_temp.corr_facturacion - cant_hisfac ( hisfac_cont_temp.tarifa[3] )"
                    "           AND hisfac_cont_temp.corr_facturacion"
                    " GROUP BY hisfac.numero_cliente"
                    " ORDER BY hisfac.numero_cliente",
                    datosGen.numeroClienteInicial,
                    datosGen.sucursal,
                    datosGen.sector,
                    identif );
   }
   else
   {
      sprintf(gstrSql, "SELECT hisfac.numero_cliente , sum(hisfac.consumo_sum), count (*)"
                    "  FROM hisfac,"
                    "       hisfac_cont_temp"
                    " WHERE hisfac_cont_temp.numero_cliente >= %ld"
                    "   AND hisfac_cont_temp.numero_cliente <= %ld"
                    "   AND hisfac_cont_temp.sucursal = '%s'"
                    "   AND hisfac_cont_temp.sector = %ld"
                    "   AND hisfac_cont_temp.identif_agenda = %ld"
                    "   AND hisfac.numero_cliente = hisfac_cont_temp.numero_cliente"
                    "   AND hisfac.corr_facturacion"
                    "       BETWEEN hisfac_cont_temp.corr_facturacion - cant_hisfac ( hisfac_cont_temp.tarifa[3] )"
                    "           AND hisfac_cont_temp.corr_facturacion"
                    " GROUP BY hisfac.numero_cliente"
                    " ORDER BY hisfac.numero_cliente",
                    datosGen.numeroClienteInicial,
                    datosGen.numeroClienteFin,
                    datosGen.sucursal,
                    datosGen.sector,
                    identif );
   };
   RegistraInicioSql("DECLARE curPromedio...de datosgen");
   $PREPARE acPromedioSql FROM $gstrSql;
   $DECLARE curPromedio CURSOR FOR acPromedioSql;
   RegistraInicioSql("OPEN curPromedio");
   $OPEN curPromedio;
   RegistraInicioSql("FETCH NEXT");
   $FETCH NEXT curPromedio into :regPromedio;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
   {
      arrayPromedio [i] = regPromedio;
      $FETCH curPromedio INTO $regPromedio ;
   };
   RegistraInicioSql("CLOSE curPromedio...");
   $CLOSE curPromedio;
   return ( arrayPromedio );
}



/*****************************************************************************/

Tpromedio * ObtenerRegPromedioCliente ( numeroCliente )
    long numeroCliente ;
{

Tpromedio regPromedioABuscar ;
Tpromedio *regPromedio ;

if ( datosGen.cantRegPromedio == 0 )
    return ( NULL );


regPromedioABuscar.numeroCliente = numeroCliente ;

regPromedio = ( Tpromedio *) bsearch ((void*) (  &regPromedioABuscar),
                      (  void * ) datosGen.arrayPromedio ,
                       datosGen.cantRegPromedio,
                       sizeof ( Tpromedio ),
                       ComparaRegPromedio );

return ( regPromedio );

}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de Promedio
 *   Para uso con bsearch .                                                       */

int
ComparaRegPromedio( reg1 , reg2 )
   Tpromedio *reg1;
   Tpromedio *reg2;
{
return ( ( reg1->numeroCliente ) - ( reg2->numeroCliente) );
}


/*****************************************************************************/

/*****************************************************************************/
Tpromedio ObtenerRegPromedioCliente3UltPer ( numeroCliente, identif )
$PARAMETER long numeroCliente ;
$PARAMETER long identif ;
{
$Tpromedio regPromedio ;

   RegistraInicioSql("DECLARE curPromedio...de datosgen");

   $SELECT hisfac.numero_cliente , sum(hisfac.consumo_sum), count (*)
      INTO :regPromedio
      FROM hisfac , hisfac_cont_temp
     WHERE hisfac_cont_temp.numero_cliente = :numeroCliente
       AND hisfac_cont_temp.sucursal = :datosGen.sucursal
       AND hisfac_cont_temp.sector   = :datosGen.sector
       AND hisfac_cont_temp.identif_agenda =  :identif
       AND hisfac.numero_cliente  = hisfac_cont_temp.numero_cliente
       AND hisfac.corr_facturacion
       BETWEEN  hisfac_cont_temp.corr_facturacion -  3
       AND      hisfac_cont_temp.corr_facturacion
     GROUP BY hisfac.numero_cliente ;

    if (sqlca.sqlcode == SQLNOTFOUND )
    {
       regPromedio.numeroCliente = numeroCliente;
       regPromedio.consumoSum = 0;
       regPromedio.cantPerReal = 0;
    }

   return ( regPromedio );
}



/*-------------------------------------------------------------------+
 | FMO :                                                             |
 |    Funciones que trabajan con la estructura de pagos anteriores   |
 +-------------------------------------------------------------------*/
int ObtenerCantRegPagosParaInteresesAnteriores( identif )
   $parameter long identif;
{
$int cantReg = 0 ;

   RegistraInicioSql("count de pagcos ant generico ");

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count (*)
         INTO :cantReg
         FROM pagco,
              cliente,
              hisfac
        WHERE cliente.numero_cliente = :datosGen.numeroClienteInicial
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND fecha_pago >= EXTEND(hisfac.fecha_facturacion, YEAR TO SECOND)
          AND fecha_pago <  EXTEND(hisfac.fecha_vencimiento3, YEAR TO SECOND)
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CUENTA
          AND tipo_pago != TIPO_PAGO_DEPOSITO_GARANTIA
          AND tipo_pago != TIPO_PAGO_ANTICIPO_RETIRO
          AND pagco.numero_cliente = cliente.numero_cliente
          AND hisfac.numero_cliente = cliente.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1
          AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM pagco , cliente , hisfac_cont_temp, hisfac
        WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND fecha_pago >= EXTEND(hisfac.fecha_facturacion, YEAR TO SECOND)
          AND fecha_pago <  EXTEND(hisfac.fecha_vencimiento3, YEAR TO SECOND)
          AND tipo_pago != TIPO_PAGO_ANTICIPO_CUENTA
          AND tipo_pago != TIPO_PAGO_DEPOSITO_GARANTIA
          AND tipo_pago != TIPO_PAGO_ANTICIPO_RETIRO
          AND pagco.numero_cliente = hisfac_cont_temp.numero_cliente
          AND hisfac.numero_cliente = hisfac_cont_temp.numero_cliente
          AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1
          AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact;
   };
   return ( cantReg );
}



/*****************************************************************************/

Tpagco *ObtenerArrayPagosParaInteresesAnteriores( cantRegPagos , identif )
int cantRegPagos ;
$parameter long identif;
{
$Tpagco   regPago ;
$Tpagco * arrayPagos ;
int       i = 0 ;

   arrayPagos = (Tpagco *) malloc ( sizeof (Tpagco) * cantRegPagos );
   if ( arrayPagos == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayPagosParaInteresesAnteriores \n" );
      exit(1);
   };
   finArrayPagosAnt = arrayPagos + cantRegPagos -1 ;

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin  )
   {
      sprintf(gstrSql, " SELECT pagco.numero_cliente,"
                       "        pagco.corr_pagos, "
                       "        pagco.fecha_pago, "
                       "        pagco.tipo_pago, "
                       "        pagco.valor_pago, "
                       "        pagco.fecha_actualiza, "
                       "        pagco.cajero, "
                       "        pagco.oficina, "
                       "        pagco.llave, "
                       "        pagco.nro_docto_asociado, "
                       "        pagco.corr_docto_asocia, "
                       "        pagco.codigo_contable, "
                       "        pagco.valor_pago_suj_int, "
                       "        pagco.sector, "
                       "        pagco.sucursal, "
                       "        pagco.centro_emisor, "
                       "        pagco.tipo_docto "
                       "   FROM pagco, cliente, hisfac "
                       "  WHERE cliente.numero_cliente = %ld "
                       "    AND date (fecha_pago) >= hisfac.fecha_facturacion "
                       "    AND date (fecha_pago) <  hisfac.fecha_vencimiento3 "
                       "    AND tipo_pago != '%s' "
                       "    AND tipo_pago != '%s' "
                       "    AND tipo_pago != '%s' "
                       "    AND pagco.numero_cliente = hisfac.numero_cliente "
                       "    AND hisfac.numero_cliente = cliente.numero_cliente "
                       "    AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       "    AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact "
                       "    ORDER BY pagco.numero_cliente ,fecha_pago; ",
                       datosGen.numeroClienteInicial,
                       TIPO_PAGO_ANTICIPO_CUENTA,
                       TIPO_PAGO_DEPOSITO_GARANTIA,
                       TIPO_PAGO_ANTICIPO_RETIRO );
   }
   else
   {
      sprintf(gstrSql, " SELECT pagco.numero_cliente,"
                       "        pagco.corr_pagos, "
                       "        pagco.fecha_pago, "
                       "        pagco.tipo_pago, "
                       "        pagco.valor_pago, "
                       "        pagco.fecha_actualiza, "
                       "        pagco.cajero, "
                       "        pagco.oficina, "
                       "        pagco.llave, "
                       "        pagco.nro_docto_asociado, "
                       "        pagco.corr_docto_asocia, "
                       "        pagco.codigo_contable, "
                       "        pagco.valor_pago_suj_int, "
                       "        pagco.sector, "
                       "        pagco.sucursal, "
                       "        pagco.centro_emisor, "
                       "        pagco.tipo_docto "
                       "   FROM pagco, cliente, hisfac_cont_temp, hisfac "
                       "  WHERE hisfac_cont_temp.numero_cliente >= %ld "
                       "    AND hisfac_cont_temp.numero_cliente <= %ld "
                       "    AND hisfac_cont_temp.sucursal = '%s' "
                       "    AND hisfac_cont_temp.sector = %d "
                       "    AND hisfac_cont_temp.identif_agenda = %ld "
                       "    AND cliente.sucursal = '%s' "
                       "    AND cliente.sector = %ld "
                       "    AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "    AND fecha_pago >= EXTEND(hisfac.fecha_facturacion, YEAR TO SECOND) "
                       "    AND fecha_pago <  EXTEND(hisfac.fecha_vencimiento3, YEAR TO SECOND) "
                       "    AND tipo_pago != '%s' "
                       "    AND tipo_pago != '%s' "
                       "    AND tipo_pago != '%s' "
                       "    AND pagco.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "    AND hisfac.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "    AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "    AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       "    AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact "
                       "    ORDER BY pagco.numero_cliente ,fecha_pago; ",
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector,
                       identif,
                       datosGen.sucursal,
                       datosGen.sector,
                       TIPO_PAGO_ANTICIPO_CUENTA,
                       TIPO_PAGO_DEPOSITO_GARANTIA,
                       TIPO_PAGO_ANTICIPO_RETIRO );
   };

   $PREPARE acPagosAntSql FROM $gstrSql;
   $DECLARE curPagosAnt CURSOR FOR acPagosAntSql;
   RegistraInicioSql("OPEN curPagosAnt");
   $OPEN curPagosAnt;
   RegistraInicioSql("FETCH curPagosAnt");
   $FETCH curPagosAnt INTO :regPago.numeroCliente,
                           :regPago.corrPagos,
                           :regPago.fechaPago,
                           :regPago.tipoPago,
                           :regPago.valorPago,
                           :regPago.fechaActualiza,
                           :regPago.cajero,
                           :regPago.oficina,
                           :regPago.llave,
                           :regPago.nroDoctoAsociado,
                           :regPago.corrDoctoAsocia,
                           :regPago.codigoContable,
                           :regPago.valorPagoSujInt,
                           :regPago.sector,
                           :regPago.sucursal,
                           :regPago.centroEmisor,
                           :regPago.tipoDocto;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ ) /* la tabla pagco debe estar lockeada en modo exclusivo */
   {
      arrayPagos [i] = regPago;
      $FETCH curPagosAnt INTO :regPago.numeroCliente,
                              :regPago.corrPagos,
                              :regPago.fechaPago,
                              :regPago.tipoPago,
                              :regPago.valorPago,
                              :regPago.fechaActualiza,
                              :regPago.cajero,
                              :regPago.oficina,
                              :regPago.llave,
                              :regPago.nroDoctoAsociado,
                              :regPago.corrDoctoAsocia,
                              :regPago.codigoContable,
                              :regPago.valorPagoSujInt,
                              :regPago.sector,
                              :regPago.sucursal,
                              :regPago.centroEmisor,
                              :regPago.tipoDocto ;
   };
                                                      RegistraInicioSql("CLOSE curPagoAnt...");
   $CLOSE curPagosAnt;
   return ( arrayPagos );
}



/****************************************************************************/

Tpagco * ObtenerPrimerPagoAntCliente ( numeroCliente )
long numeroCliente ;
{

Tpagco regPagoABuscar ;
Tpagco *regPago ;

if ( datosGen.cantRegPagosParaInteresesAnteriores == 0 )
    return ( NULL );


regPagoABuscar.numeroCliente = numeroCliente ;

regPago = ( Tpagco *) bsearch ((void*) (  &regPagoABuscar),
                      (  void * ) datosGen.arrayPagosParaInteresesAnteriores ,
                       datosGen.cantRegPagosParaInteresesAnteriores,
                       sizeof ( Tpagco ),
                       ComparaRegPagco );
pagoAntInicialDelCliente = regPago ;
ultimoPagoAntDelCliente  = regPago ;
direccionProxPagoAnt     = ABAJO  ;


return ( regPago );

}


/****************************************************************************/

Tpagco * ObtenerSiguientePagoAntCliente( numeroCliente )
long numeroCliente ;
{

if ( direccionProxPagoAnt == ABAJO )
{
    if ( ultimoPagoAntDelCliente == finArrayPagosAnt )
    {
        direccionProxPagoAnt = ARRIBA ;
        ultimoPagoAntDelCliente = pagoAntInicialDelCliente ;
    }
    else
    {

        ultimoPagoAntDelCliente = ultimoPagoAntDelCliente + 1;

        if ( ultimoPagoAntDelCliente->numeroCliente != numeroCliente )
        {
            direccionProxPagoAnt = ARRIBA ;
            ultimoPagoAntDelCliente = pagoAntInicialDelCliente ;
        }
    }
}


if ( direccionProxPagoAnt == ARRIBA )
{

    if ( ultimoPagoAntDelCliente == datosGen.arrayPagosParaInteresesAnteriores )
        ultimoPagoAntDelCliente = NULL;
    else
    {
        ultimoPagoAntDelCliente = ultimoPagoAntDelCliente - 1 ;

        if ( ultimoPagoAntDelCliente->numeroCliente != numeroCliente )
            ultimoPagoAntDelCliente = NULL;
    }
}

return ( ultimoPagoAntDelCliente ) ;

}



/*---------------------------------------------------------------------------+
 | FMO                                                                       |
 |   Funciones para cargar y manejar el array de refacturaciones anteriores. |
 +---------------------------------------------------------------------------*/
int ObtenerCantRegRefacAnt(identif)
    $parameter long identif;
{
    $int cantReg = 0 ;

    RegistraInicioSql("count de refacAnt");

    if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin  )
    {
      $SELECT count (*)
         INTO :cantReg
         FROM refac,
              cliente,
              hisfac
        WHERE cliente.numero_cliente = :datosGen.numeroClienteInicial
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector   = :datosGen.sector
          AND refac.numero_cliente = cliente.numero_cliente
          AND fecha_refacturac <= cliente.fecha_ultima_fact
          AND fecha_refacturac > hisfac.fecha_facturacion
          AND hisfac.numero_cliente = cliente.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1;
   }
   else
   {
      $SELECT count (*)
         INTO :cantReg
         FROM refac, cliente, hisfac_cont_temp, hisfac
        WHERE hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector   = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :identif
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector   = :datosGen.sector
          AND refac.numero_cliente = cliente.numero_cliente
          AND refac.numero_cliente = hisfac_cont_temp.numero_cliente
          AND fecha_refacturac <= cliente.fecha_ultima_fact
          AND fecha_refacturac > hisfac.fecha_facturacion
          AND hisfac.numero_cliente = cliente.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1;
   }

   return ( cantReg );
}



/*****************************************************************************/

Trefac *ObtenerArrayRefacAnt( cantRegRefac , identif )
    long cantRegRefac ;
    $parameter long identif;
{
    $Trefac  regRefac ;
    $Trefac *arrayRefac ;
    int      i = 0 ;

    arrayRefac = (Trefac *) malloc ( sizeof (Trefac ) * cantRegRefac );
    if ( arrayRefac == NULL )
    {
        fputs("Error malloc ObtenerArrayRefac\n", stderr);
        exit (1);
    };

    finArrayRefacAnt = arrayRefac + cantRegRefac - 1 ;

    if ( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
    {
      sprintf(gstrSql, "SELECT refac.numero_cliente, "
                       "       refac.corr_refacturacion, "
                       "       refac.fecha_fact_afect, "
                       "       refac.nro_docto_afect, "
                       "       refac.fecha_refacturac, "
                       "       refac.fecha_vencimiento, "
                       "       refac.total_refacturado, "
                       "       refac.tipo_nota, "
                       "       refac.clase_servicio, "
                       "       refac.resp_iva, "
                       "       refac.jurisdiccion, "
                       "       refac.tarifa, "
                       "       refac.kwh, "
                       "       refac.tot_refac_suj_int, "
                       "       refac.numero_nota, "
                       "       refac.orden_ajuste, "
                       "       refac.total_impuestos, "
                       "       refac.partido, "
                       "       refac.centro_emisor, "
                       "       refac.tipo_docto, "
                       "       refac.motivo, "
                       "       refac.rol "
                       "  FROM refac, cliente , hisfac "
                       " WHERE cliente.numero_cliente = %ld "
                       "   AND cliente.sucursal = '%s' "
                       "   AND cliente.sector   = %d "
                       "   AND refac.numero_cliente = cliente.numero_cliente "
                       "   AND fecha_refacturac <=  cliente.fecha_ultima_fact "
                       "   AND fecha_refacturac > hisfac.fecha_facturacion "
                       "   AND hisfac.numero_cliente = cliente.numero_cliente "
                       "   AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       " ORDER BY refac.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.sucursal,
                       datosGen.sector);
    }
    else
    {
      sprintf(gstrSql, "SELECT refac.numero_cliente, "
                       "       refac.corr_refacturacion, "
                       "       refac.fecha_fact_afect, "
                       "       refac.nro_docto_afect, "
                       "       refac.fecha_refacturac, "
                       "       refac.fecha_vencimiento, "
                       "       refac.total_refacturado, "
                       "       refac.tipo_nota, "
                       "       refac.clase_servicio, "
                       "       refac.resp_iva, "
                       "       refac.jurisdiccion, "
                       "       refac.tarifa, "
                       "       refac.kwh, "
                       "       refac.tot_refac_suj_int, "
                       "       refac.numero_nota, "
                       "       refac.orden_ajuste, "
                       "       refac.total_impuestos, "
                       "       refac.partido, "
                       "       refac.centro_emisor, "
                       "       refac.tipo_docto, "
                       "       refac.motivo, "
                       "       refac.rol "
                       "  FROM refac, cliente , hisfac_cont_temp, hisfac "
                       " WHERE hisfac_cont_temp.numero_cliente >= %ld "
                       "   AND hisfac_cont_temp.numero_cliente <= %ld "
                       "   AND hisfac_cont_temp.sucursal = '%s' "
                       "   AND hisfac_cont_temp.sector   = %d "
                       "   AND hisfac_cont_temp.identif_agenda = %d "
                       "   AND cliente.sucursal = '%s' "
                       "   AND cliente.sector   = %d "
                       "   AND refac.numero_cliente = cliente.numero_cliente "
                       "   AND refac.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "   AND fecha_refacturac <=  cliente.fecha_ultima_fact "
                       "   AND fecha_refacturac > hisfac.fecha_facturacion "
                       "   AND hisfac.numero_cliente = cliente.numero_cliente "
                       "   AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       "   ORDER BY refac.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector,
                       identif,
                       datosGen.sucursal,
                       datosGen.sector);
    }

    $PREPARE acSqlRefac FROM $gstrSql;
    $DECLARE filaRefacAnt CURSOR FOR acSqlRefac;

    RegistraInicioSql("OPEN filaRefacAnt");
    $OPEN filaRefacAnt;

    RegistraInicioSql("FETCH NEXT RefacAnt");
   $FETCH filaRefacAnt INTO :regRefac.numeroCliente,
                            :regRefac.corrRefacturacion,
                            :regRefac.fechaFactAfect,
                            :regRefac.nroDoctoAfect,
                            :regRefac.fechaRefacturac,
                            :regRefac.fechaVencimiento,
                            :regRefac.totalRefacturado,
                            :regRefac.tipoNota,
                            :regRefac.claseServicio,
                            :regRefac.respIva,
                            :regRefac.jurisdiccion,
                            :regRefac.tarifa,
                            :regRefac.kwh,
                            :regRefac.totRefacSujInt,
                            :regRefac.numeroNota,
                            :regRefac.ordenAjuste,
                            :regRefac.totalImpuestos,
                            :regRefac.partido,
                            :regRefac.centroEmisor,
                            :regRefac.tipoDocto,
                            :regRefac.motivo,
                            :regRefac.rol;

    /* la tabla refac debe estar lockeada en modo exclusivo */
    for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
    {
        if (i == cantRegRefac)
        {
            fputs("Error: se excedio cant. registros en ObtenerArrayRefacAnt",
                  stderr);
            exit(1);
        }

        arrayRefac[i] = regRefac;

      $FETCH filaRefacAnt INTO :regRefac.numeroCliente,
                               :regRefac.corrRefacturacion,
                               :regRefac.fechaFactAfect,
                               :regRefac.nroDoctoAfect,
                               :regRefac.fechaRefacturac,
                               :regRefac.fechaVencimiento,
                               :regRefac.totalRefacturado,
                               :regRefac.tipoNota,
                               :regRefac.claseServicio,
                               :regRefac.respIva,
                               :regRefac.jurisdiccion,
                               :regRefac.tarifa,
                               :regRefac.kwh,
                               :regRefac.totRefacSujInt,
                               :regRefac.numeroNota,
                               :regRefac.ordenAjuste,
                               :regRefac.totalImpuestos,
                               :regRefac.partido,
                               :regRefac.centroEmisor,
                               :regRefac.tipoDocto,
                               :regRefac.motivo,
                               :regRefac.rol ;
    }

    RegistraInicioSql("CLOSE filaRefac...");
    $CLOSE filaRefacAnt;

    return arrayRefac;
}



/****************************************************************************/

Trefac * ObtenerPrimerRefacAntCliente ( numeroCliente )
    long numeroCliente ;
{

Trefac regRefacABuscar ;
Trefac *regRefac ;

if ( datosGen.cantRegRefacAnt == 0 )
    return ( NULL );


regRefacABuscar.numeroCliente = numeroCliente ;

regRefac = ( Trefac *) bsearch ((void*) (  &regRefacABuscar),
                      (  void * ) datosGen.arrayRefacAnt ,
                       datosGen.cantRegRefacAnt,
                       sizeof ( Trefac ),
                       ComparaRegRefac );
refacAntInicialDelCliente = regRefac ;
ultimoRefacAntDelCliente  = regRefac ;
direccionProxRefacAnt     = ABAJO  ;


return ( regRefac );

}


/****************************************************************************/

Trefac * ObtenerSiguienteRefacAntCliente( numeroCliente )
    long numeroCliente ;
{

if ( direccionProxRefacAnt == ABAJO )
    {
    if ( ultimoRefacAntDelCliente == finArrayRefacAnt )
        {
        direccionProxRefacAnt = ARRIBA ;
        ultimoRefacAntDelCliente = refacAntInicialDelCliente ;
        }
    else
        {

        ultimoRefacAntDelCliente = ultimoRefacAntDelCliente + 1;

        if ( ultimoRefacAntDelCliente->numeroCliente != numeroCliente )
            {
            direccionProxRefacAnt = ARRIBA ;
            ultimoRefacAntDelCliente = refacAntInicialDelCliente ;
            }
        }
    }


if ( direccionProxRefacAnt == ARRIBA )
    {

    if ( ultimoRefacAntDelCliente == datosGen.arrayRefacAnt )
        ultimoRefacAntDelCliente = NULL;
    else
        {
        ultimoRefacAntDelCliente = ultimoRefacAntDelCliente - 1 ;

        if ( ultimoRefacAntDelCliente->numeroCliente != numeroCliente )
            ultimoRefacAntDelCliente = NULL;
        }
    }


return ( ultimoRefacAntDelCliente ) ;

}




/*-----------------------------------------------------------------------+
 | FMO                                                                   |
 |    Estructuras y funciones para convenios vigentes periodo anterior.  |
 +-----------------------------------------------------------------------*/
long *ObtenerClientesConConveAnt()
{
$long   clienteLeido;
$long * arrayClientes;
int     i = 0 ;

   arrayClientes = (long *) malloc ( sizeof (long) * datosGen.cantConveAnt );
   if ( arrayClientes == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerClientesConConveAnt \n" );
      exit(1);
   };

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT conve.numero_cliente "
                       "  FROM conve, "
                       "       cliente, "
                       "       hisfac "
                       " WHERE cliente.numero_cliente = %ld "
                       "   AND cliente.sucursal = '%s' "
                       "   AND cliente.sector = %d "
                       "   AND hisfac.numero_cliente = cliente.numero_cliente "
                       "   AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       "   AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact "
                       "   AND conve.numero_cliente = cliente.numero_cliente "
                       "   AND conve.fecha_vigencia BETWEEN "
                       "       hisfac.fecha_facturacion AND cliente.fecha_ultima_fact "
                       " ORDER BY 1",
                       datosGen.numeroClienteInicial,
                       datosGen.sucursal,
                       datosGen.sector );
   }
   else
   {
      sprintf(gstrSql, "SELECT conve.numero_cliente "
                       "  FROM conve, hisfac_cont_temp, cliente, hisfac "
                       " WHERE hisfac_cont_temp.sucursal = '%s' "
                       "   AND hisfac_cont_temp.sector = %d "
                       "   AND hisfac_cont_temp.identif_agenda = %ld "
                       "   AND hisfac_cont_temp.numero_cliente >= %ld "
                       "   AND hisfac_cont_temp.numero_cliente <= %ld "
                       "   AND cliente.sucursal = '%s' "
                       "   AND cliente.sector = %d "
                       "   AND hisfac.numero_cliente = cliente.numero_cliente "
                       "   AND hisfac.corr_facturacion = cliente.corr_facturacion - 1 "
                       "   AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact "
                       "   AND conve.numero_cliente = hisfac_cont_temp.numero_cliente "
                                             "   AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente "
                       "   AND conve.fecha_vigencia BETWEEN "
                       "       hisfac.fecha_facturacion AND cliente.fecha_ultima_fact "
                       " ORDER BY 1",
                       datosGen.sucursal,
                       datosGen.sector,
                       datosGen.identifAgenda,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector);
   }
   $PREPARE convSql FROM $gstrSql;
   RegistraInicioSql("DECLARE curCliConve");
   $DECLARE curCliConve CURSOR FOR convSql;
   RegistraInicioSql("OPEN curCliConve");
   $OPEN curCliConve;
   RegistraInicioSql("FETCH curCliConve");
   $FETCH curCliConve INTO :clienteLeido;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
   {
      arrayClientes[i] = clienteLeido;
      $FETCH curCliConve INTO :clienteLeido;
   }
   RegistraInicioSql("CLOSE curCliConve..");
   $CLOSE curCliConve;
   return (arrayClientes);
}



/*****************************************************************************/
long ContarClientesConConveAnt()
{
$long clientesLeidos;

   RegistraInicioSql("ContarClientesConConveAnt():Select curCliConve");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count(*)
         INTO :clientesLeidos
         FROM conve,
              cliente,
              hisfac
        WHERE cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND cliente.numero_cliente = :datosGen.numeroClienteInicial
          AND hisfac.numero_cliente = cliente.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1
          AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact
          AND conve.numero_cliente = cliente.numero_cliente
          AND conve.fecha_vigencia BETWEEN
              hisfac.fecha_facturacion AND cliente.fecha_ultima_fact;
   }
   else
   {
      $SELECT count(*)
         INTO :clientesLeidos
         FROM conve,
              hisfac_cont_temp,
              cliente,
              hisfac
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :datosGen.identifAgenda
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND hisfac.numero_cliente = cliente.numero_cliente
          AND hisfac.corr_facturacion = cliente.corr_facturacion - 1
          AND hisfac.fecha_vencimiento3 >= cliente.fecha_ultima_fact
          AND conve.numero_cliente = hisfac_cont_temp.numero_cliente
                    AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente
          AND conve.fecha_vigencia BETWEEN
              hisfac.fecha_facturacion AND cliente.fecha_ultima_fact;
   };
   return (clientesLeidos);
}



/*****************************************************************************/

long * ObtenerPrimerConveAntCliente ( numeroCliente )
long numeroCliente ;
{
long * puntero;

if ( datosGen.cantConveAnt == 0 )
    return ( NULL );

puntero = ( long *) bsearch ((void*) ( &numeroCliente ),
                      ( void * ) datosGen.arrayConveAnt ,
                      datosGen.cantConveAnt,
                      sizeof ( long ),
                      ComparaNumerosCliente );

return ( puntero );

}

/*****************************************************************************/

int ComparaNumerosCliente( num1 , num2 )
long *num1;
long *num2;
{
return ( *num1 - *num2 );
}


/*****************************************************************************/
/*  Funcion para comparacion de dos registros de ConveCaducado
 *   Para uso con bsearch .                                                       */

/*Se modifica por migracion a AIX*/
int ComparaRegConveCaducado(const void *reg1 , const void *reg2 )
{
return ( ( ((TconveCaducado *)reg1)->numeroCliente ) - ( ((TconveCaducado *)reg2)->numeroCliente) );
}


/*****************************************************************************/

TconveCaducado *ObtenerArrayConveCaducado()
{
$TconveCaducado   conveCaducadoLeido;
$TconveCaducado * arrayConvenios;
int               i = 0 ;

   arrayConvenios = (TconveCaducado *) malloc (sizeof (TconveCaducado) * datosGen.cantConveCaducado);
   if ( arrayConvenios == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente .ObtenerArrayConveCaducado \n" );
      exit(1);
   };

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT c.numero_cliente,\n"
                       "       c.saldo_origen,\n"
                       "       c.intacum_origen,\n"
                       "       c.codigo_moneda,\n"
                       "       c.valor_kwh,\n"
                       "       c.deuda_convenida\n"
                       "  FROM conve c,\n"
                       "       cliente\n"
                       " WHERE cliente.sucursal = '%s'\n"
                       "   AND cliente.sector = %d\n"
                       "   AND cliente.numero_cliente = %ld\n"
                       "   AND c.numero_cliente = %ld\n"
                       "   AND c.fecha_termino = cliente.fecha_ultima_fact\n"
                       "   AND c.estado = 'C'\n"
                       " ORDER BY 1",
                       datosGen.sucursal,
                       datosGen.sector,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteInicial );
   }
   else
   {
      sprintf(gstrSql, "SELECT c.numero_cliente,\n"
                       "       c.saldo_origen,\n"
                       "       c.intacum_origen,\n"
                       "       c.codigo_moneda,\n"
                       "       c.valor_kwh,\n"
                       "       c.deuda_convenida\n"
                       "  FROM conve c,\n"
                       "       hisfac_cont_temp,\n"
                       "       cliente\n"
                       " WHERE hisfac_cont_temp.sucursal = '%s'\n"
                       "   AND hisfac_cont_temp.sector = %d\n"
                       "   AND hisfac_cont_temp.identif_agenda = %ld\n"
                       "   AND hisfac_cont_temp.numero_cliente >= %ld\n"
                       "   AND hisfac_cont_temp.numero_cliente <= %ld\n"
                       "   AND cliente.sucursal = '%s'\n"
                       "   AND cliente.sector = %d\n"
                       "   AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente\n"
                       "   AND c.fecha_termino = cliente.fecha_ultima_fact\n"
                       "   AND c.numero_cliente = hisfac_cont_temp.numero_cliente\n"
                       "   AND c.estado = 'C'\n"
                       " ORDER BY 1",
                       datosGen.sucursal,
                       datosGen.sector,
                       datosGen.identifAgenda,
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector );
   };
   $PREPARE convCad FROM $gstrSql;
   RegistraInicioSql("DECLARE curConveCad");
   $DECLARE curConveCad CURSOR FOR convCad;
   RegistraInicioSql("OPEN curConveCad");
   $OPEN curConveCad;
   RegistraInicioSql("FETCH curCliConveCad");
   $FETCH curConveCad INTO :conveCaducadoLeido;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
   {
      arrayConvenios[i] = conveCaducadoLeido;
      $FETCH curConveCad INTO :conveCaducadoLeido;
   };
   RegistraInicioSql("CLOSE curConveCad..");
   $CLOSE curConveCad;
   return (arrayConvenios);
}


/******************************************************************************/

int ObtenerCantRegConveCaducado()
{
$long cuantos;
   RegistraInicioSql("ObtenerCantRegConveCaducado():Select.");
   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      $SELECT count(*)
         INTO :cuantos
         FROM conve,
              cliente
        WHERE cliente.numero_cliente = :datosGen.numeroClienteInicial
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND conve.fecha_termino = cliente.fecha_ultima_fact
          AND conve.numero_cliente = :datosGen.numeroClienteInicial
          AND conve.estado = 'C';
   }
   else
   {
      $SELECT count(*)
         INTO :cuantos
         FROM conve,
              hisfac_cont_temp,
              cliente
        WHERE hisfac_cont_temp.sucursal = :datosGen.sucursal
          AND hisfac_cont_temp.sector = :datosGen.sector
          AND hisfac_cont_temp.identif_agenda = :datosGen.identifAgenda
          AND hisfac_cont_temp.numero_cliente >= :datosGen.numeroClienteInicial
          AND hisfac_cont_temp.numero_cliente <= :datosGen.numeroClienteFin
          AND cliente.numero_cliente = hisfac_cont_temp.numero_cliente
          AND cliente.sucursal = :datosGen.sucursal
          AND cliente.sector = :datosGen.sector
          AND conve.fecha_termino = cliente.fecha_ultima_fact
          AND conve.numero_cliente = hisfac_cont_temp.numero_cliente
          AND conve.estado = 'C';
   };
   return (cuantos);
}


/*****************************************************************************/

double ObtenerValorConveCaducado ( numeroCliente )
long numeroCliente ;
{
double           deudaSujInt = 0.0;
TconveCaducado   regConveABuscar;
TconveCaducado * regConve;

   if( datosGen.cantConveCaducado == 0 ) return ( 0.0 );
   regConveABuscar.numeroCliente = numeroCliente ;
   regConve = (TconveCaducado *) bsearch ((void*) (  &regConveABuscar),
                                          (void *) datosGen.arrayConveCaducado,
                                           datosGen.cantConveCaducado,
                                           sizeof ( TconveCaducado ),
                                           ComparaRegConveCaducado );
   if ( regConve != NULL )
   {
      deudaSujInt = regConve->saldoOrigen + regConve->intacumOrigen ;
      if ( strcmp(regConve->codigoMoneda,"2")==0)
         deudaSujInt *= (regConve->valorKwh);
      if ( deudaSujInt > regConve->deudaConvenida )
         deudaSujInt = regConve->deudaConvenida;
   };
   return ( deudaSujInt );
}

/*****************************************************************************/
/* PDP - OM3245 */
int ObtenerCantRegCliDDI()
{
    $int cantReg = 0 ;

    RegistraInicioSql("count de clientes DDI");
    if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
    {
        $SELECT COUNT (*)
           INTO :cantReg
           FROM cl_res_enre_312011 c, hisfac_cont_temp h
          WHERE h.numero_cliente = :datosGen.numeroClienteInicial
            AND h.sucursal       = :datosGen.sucursal
            AND h.sector         = :datosGen.sector
            AND h.numero_cliente = c.numero_cliente;
    }
    else
    {
        $SELECT COUNT (*)
           INTO :cantReg
           FROM cl_res_enre_312011 c, hisfac_cont_temp h
          WHERE h.numero_cliente >= :datosGen.numeroClienteInicial
            AND h.numero_cliente <= :datosGen.numeroClienteFin
            AND h.sucursal        = :datosGen.sucursal
            AND h.sector          = :datosGen.sector
            AND h.numero_cliente = c.numero_cliente;
    }

    return ( cantReg );
}

TclientesDdi *ObtenerArrayCliDDI(cantRegCliDdi)
   long cantRegCliDdi;
{
    $TclientesDdi  regClientesDdi;
    $TclientesDdi  *arrayClientesDdi;
    int            i = 0 ;

   arrayClientesDdi = (TclientesDdi *) malloc (sizeof(TclientesDdi) * cantRegCliDdi);
   if ( arrayClientesDdi == NULL )
   {
      fprintf ( stderr , "Espacio de memoria insuficiente para clientes DDI \n" );
      exit (1);
   };

   if( datosGen.numeroClienteInicial == datosGen.numeroClienteFin )
   {
      sprintf(gstrSql, "SELECT c.numero_cliente, c.fecha_facturacion, "
                       "       c.corr_facturacion, c.tipo_docto "
                       "       , 0"
                       "  FROM cl_res_enre_312011 c, hisfac_cont_temp h "
                       " WHERE h.numero_cliente = %ld "
                       "   AND h.sucursal       = '%s' "
                       "   AND h.sector         = %d "
                       "   AND h.numero_cliente = c.numero_cliente"
                       " ORDER BY c.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.sucursal,
                       datosGen.sector);
   }
   else
   {
      sprintf(gstrSql, "SELECT c.numero_cliente, c.fecha_facturacion, "
                       "       c.corr_facturacion, c.tipo_docto "
                       "       , 0"
                       "  FROM cl_res_enre_312011 c, hisfac_cont_temp h "
                       " WHERE h.numero_cliente >= %ld "
                       "   AND h.numero_cliente <= %ld "
                       "   AND h.sucursal        = '%s' "
                       "   AND h.sector          = %d "
                       "   AND h.numero_cliente = c.numero_cliente"
                       " ORDER BY c.numero_cliente",
                       datosGen.numeroClienteInicial,
                       datosGen.numeroClienteFin,
                       datosGen.sucursal,
                       datosGen.sector);
   };

   RegistraInicioSql("DECLARE curClientesDdi... de datosgen");
   $PREPARE acClientesDdiSql FROM $gstrSql;
   $DECLARE curClientesDdi CURSOR FOR acClientesDdiSql;

   RegistraInicioSql("OPEN curClientesDdi");
   $OPEN curClientesDdi;

   RegistraInicioSql("FETCH NEXT");
   $FETCH NEXT curClientesDdi INTO :regClientesDdi;
   for ( i = 0 ; SQLCODE != SQLNOTFOUND ; i++ )
   {
      arrayClientesDdi [i] = regClientesDdi;
      $FETCH curClientesDdi INTO $regClientesDdi;
   };

   RegistraInicioSql("CLOSE curClientesDdi...");
   $CLOSE curClientesDdi;

   return ( arrayClientesDdi );
}

/* Evalua si se le devuelve dinero */
int EsClienteDDI(numeroCliente, dTotalAPagar, iCorrFacturacion)
    $PARAMETER long   numeroCliente;
    $PARAMETER double dTotalAPagar;
    $PARAMETER int    iCorrFacturacion;
{
    static int    iPrepCliDdi = 1;
    $char         sTipoDocto[4];
    int           iEsDDI = 0;
    TclientesDdi  regClienteABuscar;
    TclientesDdi *regCliente;

    if (iPrepCliDdi) {
        iPrepCliDdi = 0;

        RegistraInicioSql("PREPARE updCliResEnre");
        EXEC SQL PREPARE updCliResEnre FROM
           "UPDATE cl_res_enre_312011
               SET fecha_facturacion = TODAY,
                   corr_facturacion  = ?,
                   tipo_docto        = ?
             WHERE numero_cliente    = ?";
    }

    /* Para que no cancele el bsearch si no esta definida la estrucutra */
    if ( datosGen.cantClientesDdi <= 0 )
        return iEsDDI;

    regClienteABuscar.numero_cliente = numeroCliente;
    regCliente = (TclientesDdi *) bsearch ((void *) (&regClienteABuscar),
                                           (void *) datosGen.arrayClientesDdi,
                                            datosGen.cantClientesDdi,
                                            sizeof (TclientesDdi),
                                            ComparaRegClienteDDI);

    if (regCliente == NULL) 
        return iEsDDI;

    if (!risnull(CLONGTYPE, (char *) &regCliente->fecha_facturacion))
        return iEsDDI;

    if (dTotalAPagar >= 0.0)
        strcpy(sTipoDocto, "FAE");
    else {
        strcpy(sTipoDocto, "DDI");
        iEsDDI = 1;
    }

    EXEC SQL EXECUTE updCliResEnre
               USING :iCorrFacturacion,
                     :sTipoDocto,
                     :numeroCliente;

    if (sqlca.sqlerrd[2] != 1) {
        fprintf ( stderr , "Error al actualizar CL_RES_ENRE_312011\n" );
        exit (1);
    }

    if (iEsDDI) 
        if (!GrabaLogComprob(numeroCliente, abs((int)dTotalAPagar), &(regCliente->nro_comprob)))
            exit (1);
    
    return iEsDDI;
}

int ComparaRegClienteDDI(const void *reg1 , const void *reg2 )
{
    return ((((TclientesDdi *)reg1)->numero_cliente) - (((TclientesDdi *)reg2)->numero_cliente));
}

int GrabaLogComprob(numeroCliente, iTotalAPagar, iNroComp)
    $PARAMETER long   numeroCliente;
    $PARAMETER int    iTotalAPagar;
    $PARAMETER int    *iNroComp;
{
    static int iPrepLogComp = 1;
    $double dSecuencia;
    $char   sMotivo[3];

    if (iPrepLogComp) {
        iPrepLogComp = 0;

		/*LDV 18/03/2011 Elimino el campo SECUENCIA del insert */
        RegistraInicioSql("PREPARE insLogComprob");
        $PREPARE insLogComprob FROM
            "INSERT INTO log_comprob (
                numero_cliente,
                tipo_comprob,
                nro_comprob,
                monto_comprob,
                sucursal_emision,
                area_emision,
                rol_emisor,
                fecha_emision,
                motivo_devolucion
             ) VALUES (
                ?,
                '09',
                ?,
                ?,
                '0000',
                '0000',
                'FACTURADOR',
                TODAY,
                ?)";
    }

    if (((*iNroComp) = ObtenerNroComprobante()) < 0)
        return 0;
        
/* LDV 18/03/2011 dejamos la secuencia en nulo
    if ((dSecuencia = ObtenerSecuencia()) < 0)
        return 0;
*/

    strcpy(sMotivo, MOTIVO_DEVOLUCION);

    $EXECUTE insLogComprob
       USING :numeroCliente,
             :*iNroComp,
             :iTotalAPagar,
             /*:dSecuencia,*/
             :sMotivo;

    if (SQLCODE != 0 ) {
        printf("Error al grabar en LOG_COMPROB para cliente %ld\n", numeroCliente);
        return 0;
    }

    return 1;
}

int ObtenerNroComprobante()
{
    static int iPrepNroComp = 1;
    $int lValor = 0;
    $char sql[1000];
    char sAux[100];
    
    memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
    if (iPrepNroComp) {
        iPrepNroComp = 0;

        RegistraInicioSql("PREPARE selNroComprob");
        /* LDV 17/03/2011 CAMBIANOS LA SUCURSAL 0000 por la de facturacion */
        $PREPARE selNroComprob FROM
            "SELECT NVL(valor + 1, 1)
               FROM secuen
              WHERE sucursal = ?
                AND codigo   = 'ORDPAG'";


        RegistraInicioSql("PREPARE updNroComprob");
        $PREPARE updNroComprob FROM
            "UPDATE secuen
                SET valor    = ?
              WHERE sucursal = ?
                AND codigo   = 'ORDPAG'";
    }

    $EXECUTE selNroComprob
        INTO :lValor
        	using :datosGen.sucursal;;

    if (SQLCODE != 0) {
        printf("Error al buscar Nro Comprobante en tabla TABLA / SECUEN / ORDPAG\n");
        return -1;
    }

    lValor = lValor % 1000;
    if (lValor == 0)
        lValor = 1;

    $EXECUTE updNroComprob
       USING :lValor, :datosGen.sucursal;

    if (SQLCODE != 0) {
        printf("Error al actualizar Nro Comprobante en tabla TABLA / SECUEN / ORDPAG\n");
        return -1;
    }

    return lValor;
}

double ObtenerSecuencia()
{
    static int iPrepSecuen = 1;
    $double dValor = 0;

    if (iPrepSecuen) {
        iPrepSecuen = 0;

        RegistraInicioSql("PREPARE selSecuenDevol");
        $PREPARE selSecuenDevol FROM
            "SELECT NVL(secuencia + 1, 1)
               FROM secuen_devolucion
              WHERE oficina = '0000'";

        RegistraInicioSql("PREPARE updSecuenDevol");
        $PREPARE updSecuenDevol FROM
            "UPDATE secuen_devolucion
                SET secuencia = ?
              WHERE oficina   = '0000'";
    }

    $EXECUTE selSecuenDevol
        INTO :dValor;

    if (SQLCODE != 0) {
        printf("Error al buscar secuencia de tabla SECUEN_DEVOLUCION\n");
        return -1;
    }

    $EXECUTE updSecuenDevol
       USING :dValor;

    if (SQLCODE != 0) {
        printf("Error al actualizar secuencia de tabla SECUEN_DEVOLUCION\n");
        return -1;
    }

    return dValor;
}

int BuscarNroComprob(numeroCliente)
    long   numeroCliente;
{
    TclientesDdi  regClienteABuscar;
    TclientesDdi *regCliente;

    regClienteABuscar.numero_cliente = numeroCliente;
    regCliente = (TclientesDdi *) bsearch ((void *) (&regClienteABuscar),
                                           (void *) datosGen.arrayClientesDdi,
                                            datosGen.cantClientesDdi,
                                            sizeof (TclientesDdi),
                                            ComparaRegClienteDDI);
    if (regCliente == NULL) {
        printf("Error al buscar Nro Comprobante en estructura de Clientes DDI\n");
        exit (1);
    }

    return (regCliente->nro_comprob);
}

void VerificarCESP(lFechaFacturacion, sCESP, lFechaVigHasta)
EXEC SQL BEGIN DECLARE SECTION;
    PARAMETER long  lFechaFacturacion;
    PARAMETER char  sCESP[15];
    PARAMETER long *lFechaVigHasta;
EXEC SQL END DECLARE SECTION;
{
    /* PDP - OM5504 - Se agrega fecha vigencia */
    EXEC SQL SELECT LPAD(codigo, 14, '0'), fecha_vig_hasta
             INTO :sCESP, :*lFechaVigHasta
             FROM codigo_cesp
             WHERE :lFechaFacturacion BETWEEN fecha_vig_desde AND fecha_vig_hasta
               AND aprobado  = 'S';

    if (SQLCODE == SQLNOTFOUND)
    {
        printf("\nATENCION: la facturación se cancela hasta que se cargue el codigo CESP correspondiente.\n");
        exit (100);
    }
}
