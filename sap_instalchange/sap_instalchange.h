$ifndef SAPINSTALCHANGE_H;
$define SAPINSTALCHANGE_H;

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
	long	corr_facturacion;
   char	tarifa[20];
	char	ramo[20];
	char  cod_ul[9];
   char	codigo_voltaje[3];
   char	catego_electro[7];
}ClsCliente;

$typedef struct{
   long	corr_facturacion;
	long	lFechaFacturacion;
	char	sFechaFacturacion[9];
	char	tarifa[20];
	char  cod_ul[9];
   char  sFechaHasta[9];
}ClsFacturas;

$typedef struct{
	long	numero_cliente;
	char	tarifa_actual[20];
	long	corr_facturacion;
	long	lFechaFacturacion;
	char	sFechaFacturacion[9];
	char	tarifa_factura[20];
	char	ramo[20];
	char  cod_ul[9];
   char	codigo_voltaje[3];
   char	catego_electrodependiente[7];
   char  sSucursal[5];
   int   iSector;
   int   izona;
}ClsInstalacion;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short	GenerarPlano(char *, ClsCliente, ClsFacturas, int);
void	GeneraKEY(ClsCliente, ClsFacturas, int);
void	GeneraDATA(char *, ClsCliente, ClsFacturas, int);
void	GeneraENDE(ClsCliente, int);

short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*, long*, long*, long*);
short	RegistraCliente(long, int);

short	LeoCliente(ClsCliente *);
void  InicializaCliente(ClsCliente *);

short	LeoFacturas(ClsFacturas *);
void  InicializaFacturas(ClsFacturas *);


short getFechaVigTarifa(long, ClsInstalacion *);
void  CopiaAux(ClsFacturas, ClsFacturas *);

char  *getVoltaActual(long);
char  *getElectroActual(long);

/*
char	*getFechaFactura(long, long);
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
