$ifndef SAPOPERANDOSBIM_H;
$define SAPOPERANDOSBIM_H;

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
   char  tarifa[11];
}ClsCliente;

$typedef struct{
   long  numero_cliente; 
   int   corr_facturacion; 
   double   consumo_sum; 
   char  tarifa[4];
   char  indica_refact[2];
   long  fdesde; 
   long  fhasta;
   int   difdias;
   double   cons_61;
   long  fecha_facturacion;
   long  numero_factura;
   int   tipo_lectura;
   char  tipo_medidor[2];
   char  porcion[9];
   char  ul[9];
   double   consumo_sum_reactiva;
   double   lectura_reactiva;
   double   cosenoPhi;
   char     leyendaPhi[6];
   long     lFechaEvento;
   char     sFechaEvento[9];
   
   double   consumo_sum2;
   long     lectura_activa;
}ClsFactura;

$typedef struct{
   long     numero_cliente;
   int      corr_fact_act;
   long     lFechaInicio;
   char     sFechaInicio[9];
   long     lFechaFin;
   char     sFechaFin[9];
   double   consumo_61dias_act;
   int      dias_per_act;
}ClsAhorroHist;

$typedef struct{
   long     numero_cliente;
   int      corr_facturacion;
   char     anlage[30];
   char     bis1[30];
   char     auto_inser[30];
   char     operand[30];
   char     ab[30];
   char     bis2[30];
   char     lmenge[30];
   char     tarifart[30];
   char     kondigr[30];
}ClsFacts;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char*, int);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoCliente(ClsCliente * );
void  InicializaCliente(ClsCliente *);
void  getPrimaLectura(long, long *);
short LeoAhorro(ClsAhorroHist *);
void  InicializaAhorro(ClsAhorroHist *);
void  TraspasoDatos(int, ClsCliente, long, ClsAhorroHist, ClsFacts *);
void  TraspasoDatosFactu(int, ClsCliente, ClsFactura, ClsFacts *);
void  InicializaOperandos(ClsFacts *);
short LeoFactura(ClsFactura *);
void  InicializaFactura(ClsFactura *);
short LeoRefac(ClsFactura *);
short getConsuReactiva(ClsFactura *);
short getLectuReactiva(ClsFactura *);
short getLectuReactivaRefac(ClsFactura *);
short getIniVentanaAgenda(ClsFactura *);
short getLeyenda(ClsFactura *, long);


void  GenerarPlanos(FILE*, int, ClsFacts, int);
void  GeneraKey(FILE*, int, ClsFacts);
void  GeneraCuerpo(FILE*, int, ClsFacts);
void  GeneraPie(FILE*, int, ClsFacts);
void  GeneraENDE(FILE*, int, ClsFacts);
void  GeneraENDE2(FILE*, int, long);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(char*, int);
void  MueveArchivos(void);

short	ClienteYaMigrado(long, long*, int*);
short	RegistraCliente(long, long, long, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
