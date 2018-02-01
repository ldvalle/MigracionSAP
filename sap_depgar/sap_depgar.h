$ifndef SAPDEPGAR_H;
$define SAPDEPGAR_H;

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
  long      numero_dg;
  long      numero_cliente;
  char      sFechaDeposito[9];
  long      lFechaDeposito;
  char      sFechaReintegro[9];
  long      lFechaReintegro;
  double    valor_deposito;
  char      estado[2];
  char      estado_dg[2];
  char      origen[2];
  char      motivo[7];
  long      garante;
     
  char      sFechaVigTarifa[9];
  long      lFechaVigTarifa;
  long      numero_comprob;
}ClsDepgar;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoDepgar(ClsDepgar *);
void  InicializaDepgar(ClsDepgar *);

short CargaAltaCliente(ClsDepgar *);

short	GenerarPlano(FILE *, ClsDepgar);
void	GeneraSEC_D(FILE *, ClsDepgar);
void	GeneraSEC_C(FILE *, ClsDepgar);
void	GeneraENDE(FILE *, ClsDepgar);
/*
short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
*/


short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);
char	*getFechaFactura(long, long);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
