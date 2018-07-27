$ifndef SAPLECTURAS_H;
$define SAPLECTURAS_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras */

$typedef struct{
	long	numero_cliente;
	long	corr_facturacion;
	char	fecha_lectura[9];
	int		tipo_lectura;
	char	tipo_lectu_sap[11];
	double	lectura_facturac;
	double  consumo;
	char	indica_refact[2];
	long	numero_medidor;
	char	marca_medidor[4];
	char	modelo_medidor[3];
	char 	tipo_medidor[2];
   char  fecha_generacion[9];
}ClsLecturas;

$typedef struct{
	long	numero_cliente;
	long	corr_facturacion;
	char	fecha_lectura[9];
	int		tipo_lectura;
	char	tipo_lectu_sap[11];
	double	lectura_activa;
	double	lectura_reactiva;
	double	consumo_activa;
	double	consumo_reactiva;
	long	numero_medidor;
	char	marca_medidor[4];
	char	modelo_medidor[3];
	char 	tipo_medidor[2];	
}ClsFPLectu;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char *);
void  	CreaPrepare(void);
void	CreaPrepare1(void);
void	CreaPrepare2(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*, long*, long*);
short	RegistraCliente(long, int);

short	LeoClientes(long*, long*);
long	getCorrFactu(long);
short	getTramoFactu(long, long);
short   LeoLecturasActivas(long, ClsLecturas *);
void	InicializaLecturas(ClsLecturas*);
short	GenerarPlano(char*, FILE *, ClsLecturas, long);
void	GeneraIEABLU(char*, FILE *, ClsLecturas, long);
void	GeneraENDE(FILE *, ClsLecturas);
short   getFPLectu(long, ClsFPLectu *);
void	InicializoFPLectu(ClsFPLectu *);
void    CargoLectuFP(char *, ClsFPLectu, ClsLecturas *);
short	getUltimoConsumoActiva(long, long, ClsLecturas *);
short	getUltimoConsumoReactiva(int, long, long, ClsLecturas *);
void	DuplicaRegistro(ClsLecturas, ClsLecturas *);
short	ExisteFactura(long, long);
short	LeoSucursal(char *);
$endif;
