$ifndef SAPHISTOFACTUCNR_H;
$define SAPHISTOFACTUCNR_H;

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
	long	lFechaFacturacion;
	long	lCorrFactura;
	char	id_comprobante[14];
	char	tarifa[11];
	char	sFechaVencimiento1[9];
	char	sFechaFacturacion[9];
	char	sFechaLectuAnterior[9];
	char	sFechaLectuActual[9];
	double	consumo_sum;
	double	suma_impuestos;
	long	nDiasPeriodo;
	char	indica_refact[2];
	long	lNroFactura;
	long	corr_refacturacion;
}ClsHisfac;

$typedef struct{
	char	codigo_cargo[4];
	double	valor_cargo;
	char	tipo_cargo[2];
}ClsDetaHisfac;

$typedef struct{
	double	cargo_fijo;
	double  cargo_variable;
	double  importe_neto;
	double  Res347;
	double  fonimvemen;
	double  subsidios;
	double  bonificacion;
	double  puree_m;
	double  puree_b;
	double  otros;
	double	lectu_terr_activa;
	double	lectu_factu_activa;
	double	consumo_activa;
	double	lectu_terr_reactiva;
	double	lectu_factu_reactiva;
	double	consumo_reactiva;
	long	numero_medidor;
	char	marca_medidor[4];
	char	modelo_medidor[3];
	char	tipo_medidor[2];
	int		porc_factor_potencia;
	double	kwh_facturados;
	double	kwh_condonados;
	double	kwh_totales;
}ClsDetaPlano;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char *, long);
void  	CreaPrepare(void);
void  	CreaPrepare1(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

short	LeoClientes(long *, long *);
void	InicializoHisfac(ClsHisfac *);
short	LeoHisfac(ClsHisfac *);
void	InicializaDetalle(ClsDetaHisfac *);
short	LeoDetalle(ClsHisfac, ClsDetaHisfac *);
void	InicializaDetaPlano(ClsDetaPlano *);
void	CargaDetaPlano(ClsDetaHisfac, ClsDetaPlano *);
void	CargaHislec(ClsHisfac, ClsDetaPlano *);
void	CargaHislecReac(ClsHisfac, ClsDetaPlano *);
void	CargarCondones(ClsHisfac, ClsDetaPlano *);
void	GenerarPlano(FILE *, ClsHisfac, ClsDetaPlano);
void    GeneraHISTOCNR(FILE *, ClsHisfac, ClsDetaPlano);
void	GeneraENDE(FILE *, ClsHisfac);
short	LeoSucursal(char *);

/*
short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
short   CargaAltaCliente(ClsInstalacion *);

short	GenerarPlano(FILE *, ClsInstalacion);
void	GeneraKEY(FILE *, ClsInstalacion);
void	GeneraDATA(FILE *, ClsInstalacion);

*/

$endif;
