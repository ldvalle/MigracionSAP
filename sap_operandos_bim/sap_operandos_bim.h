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

void  GenerarPlanos(FILE*, int, ClsFacts);
void  GeneraKey(FILE*, int, ClsFacts);
void  GeneraCuerpo(FILE*, int, ClsFacts);
void  GeneraPie(FILE*, int, ClsFacts);
void  GeneraENDE(FILE*, ClsFacts);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(char*, int);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
