$ifndef SAPPORTION_H;
$define SAPPORTION_H;

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
	char	fecha_generacion[11];
	char	fecha_emision[11];
	char	cod_porcion[11];
	char	desc_porcion[30];
	char	fecha_genera_ampliada[11];
   
   char  sucursal[5];
   int   sector;
   int   zona;
   int   anio_periodo;
   int   periodo;
   
   char  termerst[11];
   char  abrdats[11];
   
   char  fecha_inicio_ventana[11];
   char  fecha_cierre_ventana[11];
}ClsPortion;

$typedef struct{
	char	cod_porcion[9];
	char  cod_ul[9];
	char	desc_ul[30];	
	int	indice_social;
	int	cod_contratista;
	char	area_crisis[2];
	char  fecha_lectura[9];
   
   char  sucursal[5];
   int   sector;
   int   zona;
   int   eper_abl;   
}ClsUnLectu;

$typedef struct{
	char	cod_porcion[9];
   int   diffDias;   
}ClsPortionVentana;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);
short   LeoPortion(ClsPortion *);
void    InicializaPortion(ClsPortion *);
short	LeoUnLectu(ClsUnLectu *);
void    InicializaUnLectu(ClsUnLectu *);
short getFactuAnterior(ClsPortion *);
short getDifFechas(ClsUnLectu *, long);
short getVentanaPortion(ClsPortion *, long);
void  InicializaVector(ClsPortionVentana **);
void  CargaPortion(char *, int, long, ClsPortionVentana **);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
short	GenerarPlanoPortion(FILE *, ClsPortion);
short	GenerarPlanoUL(FILE *, ClsUnLectu);
void	GeneraTE420(FILE *, ClsPortion);
void	GeneraTE422(FILE *, ClsUnLectu);
void	GeneraTE425(FILE *, ClsUnLectu);
void	GeneraENDEpor(FILE *, ClsPortion);
void	GeneraENDEul(FILE *, ClsUnLectu);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
void    InicializaEmail(ClsEmail*);

*/

$endif;
