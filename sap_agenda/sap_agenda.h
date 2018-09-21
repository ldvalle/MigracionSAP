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
   char  tipo_ciclo[2];
   char  sucursal[5];
   int   sector;
   int   zona;
   long  fecha_emision_real;
   int   anio_periodo;
   int   periodo;
   long  identif_agenda;
   long  min_fecha_lectu;
   long  max_fecha_lectu;
   long  fechaAgendaAnterior;
   long  menorMenos3;
}ClsAgenda;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
void  InicializaAgenda(ClsAgenda *);
short Leo417(ClsAgenda *);
short Leo417B(ClsAgenda *);
short Leo418(ClsAgenda *);
long  getMenorMenos3(long);

char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
void  GenerarPlano(FILE *, ClsAgenda);
void  Generar417(FILE *, char*, long, long, long, long);
void  Generar417B(FILE *, ClsAgenda, long);
void  Generar418(FILE *, ClsAgenda, char*, char*, long, long, long);
void  CopiaEstructura(ClsAgenda, ClsAgenda*);

short RegistraAgenda(ClsAgenda, long, long);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
void    InicializaEmail(ClsEmail*);

*/

$endif;
