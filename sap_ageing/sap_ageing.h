EXEC SQL ifndef AGEING;
EXEC SQL define AGEING;

#include <time.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <ustring.h>
#include "macmath.h"
#include "sqlerror.h"
$include "funcdt.h";
$include "amortiza.h";
$include amort.h;
$include mfecha.h;
$include cliente.h;
$include errores.h;
$include sqltypes.h;
$include saldos_cnr.h;


#define TRACE { printf("TRACE - archivo %s   funcion %s   linea %d\n", __FILE__, __FUNCTION__, __LINE__); }

#define ERROR                       0
#define OK                          1
#define CANTIDAD_PARAMETROS         4

EXEC SQL WHENEVER SQLERROR CALL SqlException ;
EXEC SQL ifdef DEBUG ;
    EXEC SQL WHENEVER SQLWARNING CALL SqlException ;
EXEC SQL endif ;


EXEC SQL BEGIN DECLARE SECTION;
    $Tcliente   *rCli;
    char        sBaseSynergia[50];
    char        sSucursal[5];
    int         iSector;
    long        lFechaHoy;
    char        sPath[50];
EXEC SQL END DECLARE SECTION;

FILE    *fArchivo;
char    sArchivo[100];


int    ValidarParametros(int, char **);
int    IniciaAmbiente(void);
void   TerminaAmbiente(int);
int    AbreArchivo(char *, FILE **, char *);
void   PreparaQuerys(void);
int    FetchClientes(Tcliente *);
int    FetchFacturas(Thisfac *);
short  MuestraSaldos(double, long, long, long, TDsaldosImpuestos, char*, char*);
short  MuestraSaldosCnr(long, TsaldosCnr *, int, char*);
void   AplicarProporcion(TDsaldosImpuestos , double, TDsaldosImpuestos *);
void   RestarSaldos(TDsaldosImpuestos *, TDsaldosImpuestos);

void   Obtener_ArrayCodca(void);
double LeeSaldoTasa( long );
void   LlenaArrSaldosImpuestos(TDsaldosImpuestos *, double *, double *);

short delIndexFile(void);
short setIndexFile(long, fpos_t, int);
short AbreOtroArchivo(void);

EXEC SQL endif;
