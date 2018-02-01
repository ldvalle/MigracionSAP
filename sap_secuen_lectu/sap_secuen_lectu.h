$ifndef SAPSECUENLECTU_H;
$define SAPSECUENLECTU_H;

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
	char	sucursal[5];
	int		sector;
	int		zona;
	long	correlativo_ruta;
	long	numero_cliente;
	char	unidad_lectura[9]; 
	char	aparato[31];
}ClsSecuLectu;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short   LeoSecuencia(ClsSecuLectu *);
void    InicializaSecuencia(ClsSecuLectu *);


short	GenerarPlano(FILE *, ClsSecuLectu);
void	GeneraMRU(FILE *, ClsSecuLectu);
void	GeneraEQUNR(FILE *, ClsSecuLectu);
void	GeneraENDE(FILE *, ClsSecuLectu);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
void    InicializaEmail(ClsEmail*);
*/

$endif;
