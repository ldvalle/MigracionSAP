$ifndef SAPAGENDA_H;
$define SAPAGENDA_H;

#include "ustring.h"
#include "macmath.h"

$include errores.h;
$include mfecha.h;
$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ***/
$typedef struct{
	char  cod_ul[9];
   char	cod_porcion[9];
	long  fecha_generacion;
	char	fecha_lectura_fmt[11];
}ClsAgenda;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
void  InicializaAgenda(ClsAgenda *);
short LeoAgenda(ClsAgenda *);


char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
void  GenerarPlano(FILE *, ClsAgenda);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
void    InicializaEmail(ClsEmail*);

*/

$endif;
