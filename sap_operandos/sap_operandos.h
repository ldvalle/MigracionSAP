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
}ClsOperando;

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

short	GenerarPlano(char*, FILE *, ClsOperando, long);
void	GeneraKEY(char *, FILE *, ClsOperando, long);
void	GeneraFFlag(char *, FILE *, ClsOperando, long);
void	GeneraVFlag(char *, FILE *, ClsOperando, long);
void	GeneraENDE(FILE *, ClsOperando, long);
/*
short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
*/


short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(char *, long, int*);
short	RegistraCliente(char*, long, int);
char	*getFechaFactura(long, long);

short getFechaIni(ClsOperando, long*);
short getFechaFin(ClsOperando, long*);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
