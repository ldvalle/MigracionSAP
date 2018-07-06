$ifndef SAPMONTAJE_H;
$define SAPMONTAJE_H;

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
	long	   numero_cliente;
	int	   corr_facturacion;
	long	   numero_medidor;
	char	   marca_medidor[4];
	double	lectura_facturac;
	double	lectura_terreno;
   double   consumo;
	long	   fecha_lectura;
	char	   sFechaLectura[9];
	int	   tipo_lectura;
	char	   modelo_medidor[3];
	char	   tarifa[21];
	char	   indica_refact[2];
	char	   tipo_medidor[2];
	double   lectura_instal_reac;
	double	factor_potencia;
	int		enteros;
	int		decimales;
}ClsLecturas;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short   LeoClientes(long *, long *);

long  getMedidorActual(long , char *, char *);

short   LeoLecturas(ClsLecturas *);
short	LeoPrimeraLectura(long, long, ClsLecturas *);
void    InicializaLecturas(ClsLecturas *);
short	CargaLecturasActivasRefact(ClsLecturas *);
short   CargaLecturasReactivasRefact(ClsLecturas *);
short	CargaLecturasReactivas(ClsLecturas *);

short	GenerarPlanos(ClsLecturas);
void	GeneraDI_INT(FILE *, char *, ClsLecturas);
void	GeneraDI_ZW(FILE *, char *, int, ClsLecturas);
void	GeneraDI_GER(FILE *, char *, ClsLecturas);
void  GeneraDI_CNT(FILE *, ClsLecturas);
void	GeneraENDE(FILE *, ClsLecturas);

void	GeneraMontajeReal(ClsLecturas);

short  EsMedidorVigente(long, char *, char *, ClsLecturas);

short	LeoUltInstalacion(long, ClsLecturas *);
short   GenerarMontaje(ClsLecturas);
short	LeoUltRetiro(long, ClsLecturas *);
short   GenerarDesmontaje(ClsLecturas);

short   LeoInstalacionPuntual(ClsLecturas, ClsLecturas*);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
short	ClienteYaMigrado(long, int*, long*, long*);
short	RegistraCliente(long, int);
char	*getFechaFactura(long, long, long*);
short	LeoPrimerMontajeReal(long, long, ClsLecturas*);
short	EncontroMedid(long);
void	CopiaEstructura(ClsLecturas, ClsLecturas*);
short	LeoSinFactura(ClsLecturas*);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
