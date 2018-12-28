$ifndef SAPOPERANDOS_H;
$define SAPOPERANDOS_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras **/

$typedef struct{
	long	numero_cliente;
	char	fecha_vig_tarifa[9];	
	char	sOperando[11];
	char	sFechaInicio[9];
	long	lFechaInicio;
	char	sFechaFin[9];
	long	lFechaFin;
	char	sMotivoVip[7];
	long	corr_facturacion;
	long	nro_beneficiario;
   double   dValor;
   char     sValor[11];
   char     sTarifa[11];
}ClsOperando;

$typedef struct{
   long  numero_cliente;
   char  codigo_tasa[4]; 
   char  partido[4]; 
   char  partida_municipal[13]; 
   char  no_contribuyente[2];
}ClsTasa;

$typedef struct{
   long  numero_cliente;
   long  lFechaActivacion;
   char  sFechaActivacion[9];
   char  sFechaDesactivac[9];
   double   cant_valor_tasa;
}ClsTasaVig;

$typedef struct{
   long  numero_cliente;
   int   corr_facturacion;
   long  fecha_facturacion; 
   long  fecha; 
   double   valor;
   char  codigo_tasa[4];
   char  codigo_sap[11];
}ClsTasaPrecio;

$typedef struct{
   long  numero_cliente; 
   long  lFechaInicio;
   char  sFechaInicio[9];
   char  sFechaFin[9];
}ClsEBP;

$typedef struct{
   long  numero_cliente; 
   char  evento[6];
   long  lFechaEvento;
   char  sTarifa[11];
}ClsFP;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short   LeoElectroDependencia(ClsOperando *);
short   LeoTis(ClsOperando *);
void    InicializaOperando(ClsOperando *);

short   CargaAltaCliente(ClsOperando *);
void	CopiarData(ClsOperando, ClsOperando *);

void  GenerarElectro(void);
void  GenerarTIS(void);
void  GenerarTasa(void);
void  GenerarEBP(void);
void  GenerarFP(void);

short	GenerarPlano(char*, FILE *, ClsOperando, long);
void	GeneraKEY(char *, FILE *, ClsOperando, long);
void	GeneraFFlag(char *, FILE *, ClsOperando, long);
void	GeneraVFlag(char *, FILE *, ClsOperando, long);
void	GeneraENDE(FILE *, ClsOperando, long);

short LeoTasa(ClsTasa *);
void  InicializaTasa(ClsTasa *);
short LeoTasaVig(ClsTasaVig *);
void  InicializaTasaVig(ClsTasaVig *);
void  TraspasoTasa(ClsTasaVig, long, ClsOperando *);
void  TraspasoTasaFactor(ClsTasaVig, long, ClsOperando *);
void  PrintTasaCliente(ClsOperando, int);
void  PrintTasaFactor(ClsOperando, int);
void  GeneraFFact(FILE *, ClsOperando, int);
void  GeneraVFact(FILE *, ClsOperando, int);
short LeoTasaPrecio(ClsTasaPrecio *);
void  InicializaTasaPrecio(ClsTasaPrecio *);
void  TraspasoTasaPrecio(ClsTasaPrecio, long, double, ClsOperando *);
void  PrintTasaPrecio(ClsOperando, int);
void  GeneraFQpri(FILE *, ClsOperando, int);
void  GeneraVQpri(FILE *, ClsOperando, int);

short LeoEBP(ClsEBP *);
void  InicializaEBP(ClsEBP *);
void  TraspasoEBP(ClsEBP, ClsOperando *);
void  PrintEBP(ClsOperando, int);

short LeoFP(ClsFP *);
void  InicializaFP(ClsFP *);
void  TraspasoFP(ClsFP, ClsOperando *);
void  PrintFP(ClsOperando, int);
void  GeneraFQUAN(FILE *, ClsOperando, int);
void  GeneraVQUAN(FILE *, ClsOperando, int);


short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(char *, long, long *,int*);
short	RegistraCliente(char*, long, long, int);
char	*getFechaFactura(long, long);

short getFechaIni(ClsOperando, long*);
short getFechaFin(ClsOperando, long*);

int   getExiste(long);
/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
