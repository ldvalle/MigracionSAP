$ifndef DATOS_GEN;
$define DATOS_GEN;

#include <values.h>

$include tabla.h;
$include codca.h;
$include campos.h;
$include mensajes.h;
$include insta.h;
$include venage.h;
$include pagco.h;
$include refac.h;
$include lectu.h;
$include det_val_tarifas.h;


$define ARRIBA -1 ;

$define ABAJO 1 ;



$typedef struct carcoConIntereses
	{
	long numeroCliente;
	char codigoCargo[4];
	double valorCargo;
	double cantidad;
	long identifAgenda;
	int estadoAgenda;
	char tipoCargo[2];
	char indAfectoInt[2];
	int nivelDeImpresion;   /* PDP - OM1726 - Se agrega orden_impresion */
	char codigoAgrupa[4];   /* PDP - OM3931 - Neteo FE y FEP */

	} TcarcoConInt;


$typedef struct recArrieConInt
	{
	long	numeroCliente ;
	char	codigoCargo[4];
	double	valorCargo;
	float	factorAplicacion ;
	long	fechaActivacion ;
	long	fechaDesactivac ;
	char	indAfectoInt[2];
}TarrieConInt;



$typedef struct recConsumo
	{
	long	numeroCliente ;
	double	consumo;
}Tconsumo;

$typedef struct recPromedio
	{
	long	numeroCliente ;
	double	consumoSum;
	int     cantPerReal;
}Tpromedio;

$typedef struct recConveCaducado
	{
	long    numeroCliente;
	double  saldoOrigen;
	double  intacumOrigen;
	char    codigoMoneda[4];
	double  valorKwh;
	double  deudaConvenida;
}TconveCaducado;

/* PDP - Cargo variable transitorio FONINVEMEM */
$typedef struct recTacar
	{
	char    codigoCargo[4];
}TarrayTacar;

/* PDP - OM3245 - Clientes a los que posiblemente se les devuelva dinero */
$typedef struct recClientesDdi
	{
	long    numero_cliente;
	long    fecha_facturacion;
	int     corr_facturacion;
	char    tipo_docto[4];
	int     nro_comprob;
}TclientesDdi;


$typedef struct datGenerales
	{
	long		identifAgenda;
   long     fechaGeneracion;
	long            numeroClienteInicial;
	long            numeroClienteFin;
	char		sucursal[5];
	long		sector;
	Tinsta		regInsta;
	double		porcentajeRecargo;
	TCcodigoCargo	codigoRecargo;
	TCtipoCargo	tipoCargoRecargo;
	TCtipoCargo	tipoCargoImpuesto;
	long		fechaHoy;
	double		deudaMinNotificacion;
	Tvenage		*arrayVenageProximo;
	int		cantRegVenageProximo;
	Tvenage		*arrayVenage;
	int		cantRegVenage;
	Ttabla		*arrayTablaTarif;
	int		cantRegTablaTarif;
	Ttabla		*arrayTablaTipiva;
	int		cantRegTablaTipiva;
	Ttabla		*arrayTablaSector;
	int		cantRegTablaSector;
	Ttabla		*arrayTablaClalec;
	int		cantRegTablaClalec;
	TCcodigoValor	codigoValorKWHConvenio;
	Tcodca		*arrayCodca;
	int		cantRegCodca;
	Tmensajes	*arrayMensajesFijos;
	int		cantRegMensajesFijos;
	TcarcoConInt    *arrayConceptosPorAplicar;
	int             cantRegConceptosPorAplicar;
	TarrieConInt    *arrayConceptosTemporales;
	int             cantRegConceptosTemporales;
    /* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
	TarrieConInt    *arrayConceptosTemporalesPendientes;
	int             cantRegConceptosTemporalesPendientes;
	TcarcoConInt    *arrayConceptosTarifa;
	int             cantRegConceptosTarifa;
	Tpagco          *arrayPagosParaIntereses;
	int             cantRegPagosParaIntereses;
	Trefac          *arrayRefac;
	int             cantRegRefac;
	Tlectu          *arrayLectu;
	int             cantRegLectu;
	TdetValTarifas  *arrayDetalle;
	int             cantRegDetalle;
	Tconsumo        *arrayConsumo;
	int             cantRegConsumo;
	Tpromedio       *arrayPromedio;
	int             cantRegPromedio;
	Tpagco          *arrayPagosParaInteresesAnteriores;
	int             cantRegPagosParaInteresesAnteriores;
	Trefac          *arrayRefacAnt;
	int             cantRegRefacAnt;
	long            *arrayConveAnt;
	long            cantConveAnt;
	TconveCaducado  *arrayConveCaducado;
	int             cantConveCaducado;
	/* PDP - OM3245 */
	TclientesDdi    *arrayClientesDdi;
	long            cantClientesDdi;
	char			sCESP[15];
	long            lFechaVigHasta; /* PDP - OM5504 */
	}   TdatosGen;

/*
 * Se agrega para que segun de que programa venga busque un prototipo u el otro
 * RECUPFECHA esta defino en calcimpasoc_refac.ec
 * Para migracion AIX
 */
#ifdef RECUPFECHA
void RecuperarDatosGen(TdatosGen *, long);
#else
void RecuperarDatosGen(TdatosGen *, long);
#endif

void AlmacenarIdentifAgenda(long); /*Se agrega el long para migracion a AIX*/               /* esta funcion es fundamental en fact .     */
void AlmacenarRangoClientes(long  numeroClienteInicial , long  numeroClienteFin); /*Se modifica para migracion a AIX*/              /* esta tambien , no pueden faltar           */
void AlmacenarFechaGeneracion(long); /*Se agrego el long para migracion a AIX*/             /* Esta se agrego para modificar la
                                             determinacion periodo segun Res. ENRE 736/99 */

int EsDiaFeriado (long diaAAnalizar ,long hoy );

TcarcoConInt *ObtenerPrimerCPACliente(long); /*Se modifica por migracion a AIX*/

TcarcoConInt *ObtenerSiguienteCPACliente(long); /*Se modifica por migracion a AIX*/

TarrieConInt *ObtenerPrimerTempCliente(long); /*Se modifica por migracion a AIX*/

TarrieConInt *ObtenerSiguienteTempCliente(long); /*Se modifica por migracion a AIX*/

/* PDP - OM1943 - Se cargan registros de ARRIE para facturar CPAs temporales pendientes */
TarrieConInt *ObtenerPrimerTempClientePendientes(long); /*Se modifica por migracion a AIX*/

TarrieConInt *ObtenerSiguienteTempClientePendientes(long); /*Se modifica por migracion a AIX*/

TcarcoConInt *ObtenerPrimerCargoTarifaCliente(long); /*Se agrega el long para migracion a AIX*/

TcarcoConInt *ObtenerSiguienteCargoTarifaCliente(long); /*Se agrega el long para migracion a AIX*/

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tpagco *ObtenerPrimerPagoCliente(long);

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tpagco *ObtenerSiguientePagoCliente(long);

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tpagco *ObtenerPrimerPagoAntCliente(long);

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tpagco *ObtenerSiguientePagoAntCliente(long);

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Trefac *ObtenerPrimerRefacCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Trefac *ObtenerSiguienteRefacCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tlectu *ObtenerPrimerLectuCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tlectu *ObtenerSiguienteLectuCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
TdetValTarifas *ObtenerPrimerDetalleCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
TdetValTarifas *ObtenerSiguienteDetalleCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tconsumo *ObtenerRegConsumoAnteriorCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Tpromedio *ObtenerRegPromedioCliente( long );

Tpromedio ObtenerRegPromedioCliente3UltPer ();

long * ObtenerPrimerConveAntCliente (long);

double ObtenerValorConveCaducado();

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Trefac *ObtenerPrimerRefacAntCliente( long );

/* Se agrego el parametro al prototipo de la funcion para migracion AIX */
Trefac *ObtenerSiguienteRefacAntCliente( long );

void VerificarCESP(long, char*, long*); /* PDP - OM5504 - Se agrega parametro */


$endif;

