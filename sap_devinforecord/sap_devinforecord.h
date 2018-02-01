$ifndef SAPDEVINFORECORD_H;
$define SAPDEVINFORECORD_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ---*/

$typedef struct{
   long  numero_medidor;
   char  marca_medidor[4];
   char  modelo_medidor[3];
   long  numero_cliente;
   char  tipo_medidor[2];
   int   enteros;
   int   decimales;
   int   med_anio;
   float med_factor;
	char	med_precinto1[8];
	char	med_precinto2[8];
	char	med_clase[6];
	char	med_fase[4];
   
   char	emplazamiento[5];
	char	med_ubic[4]; 
	char	med_codubic[11];
   char  fabricante[31];
   int   cod_fabricante;
}ClsMedidor;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
short AbreArchivosInst(int);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short	CargaEmplazamiento(ClsMedidor *);
char	*getEmplazaSAP(char*);
char	*getEmplazaT23(char*);


short   LeoMedidores(int, ClsMedidor *);
void    InicializaMedidor(ClsMedidor *);

void  GenerarPlanoMed(FILE *, ClsMedidor);
void	GeneraDVMINT(FILE *, ClsMedidor);
void  GeneraDVMDEV(FILE *, ClsMedidor);
void  GeneraDVMDFL(FILE *, ClsMedidor);
void	GeneraDVMREG(FILE *, char *, int, ClsMedidor);
void	GeneraDVMRFL(FILE *, char *, int, ClsMedidor);
void	GeneraDVMABL(FILE *, char *, int, ClsMedidor);
void	GeneraENDE(FILE *, ClsMedidor);

void	GenerarPlanoExt(FILE *, ClsMedidor);
void	GeneraEQUI(FILE *, ClsMedidor);

short DentroRango(ClsMedidor);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
