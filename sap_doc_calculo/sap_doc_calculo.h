$ifndef SAPDOCCALCULO_H;
$define SAPDOCCALCULO_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ***/
$typedef struct{
   long  numero_cliente;
   int   corr_facturacion;
   char  cod_portion[9];
   char  cod_ul[9];
   char  cdc[11];
   char  tipo_fpago[2];
   char  cod_agrupa[10];
   long  minist_repart;
   char  tipo_cliente[3];
}ClsCliente;


$typedef struct{
   long     numero_cliente;
   int      corr_facturacion;
   char     fecha_lectura[9];
   char     fecha_vencimiento[9];
   char     fecha_facturacion[9];
   long     lFechaFacturacion;
   char     centro_emisor[3];
   char     tipo_docto[3];
   long     numero_factura;
   char     tipo_tarifa[11];
   char     tipo_iva[11];
   double   consumo_sum;
   char     tarifa[4];
   int      subtarifa;
   char     indica_refact[2];
   
   char     fecha_lectura_anterior[9];
   int      dias_periodo;
   double   consumo_normalizado;
   int      corr_refacturacion;
   char     clase_servicio[3];
   char     cdc[11];

   long     lFechaLectura;
   char     cod_ul[9];
   char     cod_porcion[9];
   long     lFechaIniVentana;
   int      iTipoLectura;
   char     sTarifType[11];
   char     sPeriodo[8];
   double   totalAPagar;
   long     lFechaLecturaAnterior;
}ClsHisfac;

$typedef struct{
  char     codigo_cargo[4];
  double   valor_cargo;
  char     unidad[5];
  double   precio_unitario;   
/*  
  char     clase_pos_doc[10];
  char     contrapartida[10];
  char     cte_de_calculo[10];
  char     tipo_precio[10];
  char     tarifa[10];
  char     deriv_contable[10];

  char     tipo_cargo_tarifa[2];
  
  char     ctaContable[9];
  char     gegen_tvorg[5];
  char     mngbasis[2];
*/
   char     tipo_cargo_tarifa[2];

  char      descripcion[51];
  long      vonzone;
  long      biszone;
  char      tariftyp[21];
  char      tarifnr[11];
  char      belzart[11];
  short     preistyp;
  char      massbill[6];
  char      preis[21];
  short     zonennr;
  char      ein01[6];
  char      tvorg[6];
  char      gegen_tvorg[11];
  char      sno[11];
  
  double    preisbtr;
  int       mngbasis;
  char      hvorg[6];
  char      operentrada[20];
  char      opersalida[10];
  
  char      sFechaDesde[9];
  char      sFechaHasta[9];
}ClsDetalle;

$typedef struct{
   char  codigo_cargo[4]; 
   char  codigo_cuenta[5]; 
   char  agrupacion[4];
   char  descripcion[31];
}ClsCtaAgrupa;

$typedef struct{
   int   corr_precio;
   int   duracion_periodo; 
   double   precio_unitario; 
   double   precio_ponderado; 
   int   tipo_cuadro; 
   long  fecha_desde; 
   long  fecha_hasta; 
   long  consumo;
}ClsDetVal;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char*, int);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short CargarCtas(ClsCtaAgrupa **, int *);
short LeoCuenta(ClsCtaAgrupa *);
void  InicializoCta(ClsCtaAgrupa *);
short BuscaCuenta(ClsCliente, ClsHisfac, ClsCtaAgrupa *, int, ClsDetalle *);
char  *getNroCuentaAux(ClsCliente, ClsHisfac, char *);
char  *getClase(char *);
char  *getTarifa(char *);
char  *getSubTarifa(char *, int);
char  *getExigibilidad(char *);

short LeoCliente(ClsCliente * );
void  InicializaCliente(ClsCliente *);
short CorporativoT23(ClsCliente *);
short CorporativoPropio(ClsCliente *);

short LeoFacturasCabe(ClsHisfac *, int);
void  InicializaFacturasCabe(ClsHisfac *);
short getFechaLectuAnterior(ClsHisfac *);
void  Calculos(ClsHisfac *);
short TraeRefacturada(ClsHisfac *);
short TraeNvoTotal(ClsHisfac *);
short LeoFacturasDeta(ClsHisfac, ClsDetalle *, int);
void  InicializaDetalle(ClsDetalle *);
short getPrecioUnitario(ClsHisfac, ClsDetalle *);

int   getCantCuadros(ClsHisfac);
char  *getTipoCargoTarifa(char *);
short LeoDetVal(ClsDetalle *, int);
void  InicializaDetVal(ClsDetVal *);

void  GenerarCabecera(ClsCliente, ClsHisfac);
void  GenerarDetalle(ClsCliente, ClsHisfac, ClsDetalle, int, int);
void  GeneraENDE(ClsHisfac, ClsDetalle, int);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(int);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
