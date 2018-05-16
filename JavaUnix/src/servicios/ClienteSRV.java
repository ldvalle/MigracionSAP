package servicios;

import entidades.ClienteDTO;
import entidades.FechasDTO;
import entidades.EstadosClienteDTO;
import dao.ClientesDAO;
import java.util.Collection;
import java.util.Date;
import java.text.ParseException;
import java.text.SimpleDateFormat;

public class ClienteSRV {
	private Date fPivote = null;
	private Date fRti = null;
	private Date fLimInf=null;
	private Date fMac=null;

	public Boolean getListaClientes(){
		Collection<ClienteDTO> lstClientes = null;
		
		ClientesDAO miDao = new ClientesDAO();
		
		lstClientes = miDao.getLstClientes();
		
		for(ClienteDTO miClie : lstClientes){

		}
		
		return true;
	}
	
	private Boolean ValidacionOK( ClienteDTO miReg){
		
		if(miReg.sucursal != "0004")
			return false;
			
		return true;
	}
	
	public Boolean procClientes2() {
		ClientesDAO miDao = new ClientesDAO();
		
		if(!miDao.ProcesaMigra()) {
			System.out.println("No se pudo procesar la Pre Migración");
		}
		
		return true;
	}
	
	
	public Boolean procClientes() {
		FechasDTO regFechas = new FechasDTO();
		Collection<ClienteDTO> lstClientes = null;
		String sLimInf = "01-12-2014";
		String sMac="24-09-1995";
		SimpleDateFormat sdf = new SimpleDateFormat("dd-MM-yyyy");
		ClientesDAO miDao = new ClientesDAO();
		EstadosClienteDTO estados = null;
		long iCantCliVuelta;
		long iCantClientes;
		Date dIni = null;
		
		fPivote = miDao.getFPivote();
		fRti = miDao.getFRTI();
		
		try {
			fLimInf = sdf.parse(sLimInf);
			fMac = sdf.parse(sMac);
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}
		 
/*	
		System.out.println("Fecha Pivote " + sdf.format(fPivote));
		System.out.println("Fecha Rti " + sdf.format(fRti));
		System.out.println("Fecha Lim Inf " + sdf.format(fLimInf));		
*/
		
		iCantCliVuelta=0;
		iCantClientes=0;
		lstClientes = miDao.getLstClientes();
		
		for(ClienteDTO miClie : lstClientes){
			regFechas.dFechaPivote = fPivote;
			
			//System.out.println("Buscando ValTar");
			//Fecha Validez de Tarifa
			regFechas.dFechaValTar = getFValTar(miClie);
			//System.out.println("Buscando Alta");
			//Fecha Alta Real
			regFechas.dFechaAlta = getFAltaReal(miClie);
			//System.out.println("Buscando Movein");
			//Fecha Move In
			regFechas.dFechaMoveIn = getFMoveIn(regFechas, miClie);
			//System.out.println("Buscando Estados");
			//Tarifa - UL y Motivo Alta
			estados = miDao.getTarifaUl(miClie.numero_cliente, fPivote);
			//System.out.println("Grabando");
			//Grabar Datos
			if(!miDao.setStatus(miClie.numero_cliente, regFechas, estados)) {
				System.out.println("Error al insertar Status y Fechas para cliente " + miClie.numero_cliente);
			}
			iCantCliVuelta++;
			iCantClientes++;
			if(iCantCliVuelta > 100000) {
				System.out.println("Va por " + iCantClientes + " Clientes");
				dIni = new Date();
				System.out.println("Fecha Hora " + sdf.format(dIni));
				iCantCliVuelta=0;
			}
		}
		
		System.out.println("Se procesaron " + iCantClientes + " Clientes");
		dIni = new Date();
		System.out.println("Fecha Hora " + sdf.format(dIni));
		
		return true;
	}
	
	private Date getFValTar(ClienteDTO reg) {
		Date dFecha = null;
		ClientesDAO miDao = new ClientesDAO();
		
		if(reg.corr_facturacion > 0) {
			dFecha=miDao.getFValTar1(reg.numero_cliente, fLimInf);
			if(dFecha == null) {
				System.out.println("No se encontró fecha Val Tar para cliente " + reg.numero_cliente);
			}else {
				if(fLimInf.compareTo(dFecha) > 0) {
					dFecha=fLimInf;
				}
			}
		}else {
			dFecha= miDao.getFValTar2(reg.numero_cliente);
			if(dFecha == null) {
				long nroClienteAntecesor = Long.parseLong(reg.sNroBeneficiario);
				if(nroClienteAntecesor > 0) {
					dFecha = miDao.getFRetiro(nroClienteAntecesor);
					if(fLimInf.compareTo(dFecha) > 0) {
						dFecha=fLimInf;
					}					
				}else {
					dFecha=fLimInf;
				}
			}else {
				if(fLimInf.compareTo(dFecha) > 0) {
					dFecha=fLimInf;
				}
			}
		}
		
		return dFecha;
	}

	private Date getFAltaReal(ClienteDTO reg) {
		Date dFecha = null;
		ClientesDAO miDao = new ClientesDAO();

		dFecha= miDao.getFValTar2(reg.numero_cliente);
		if(dFecha == null) {
			long nroClienteAntecesor = Long.parseLong(reg.sNroBeneficiario);
			if(nroClienteAntecesor > 0) {
				dFecha = miDao.getFRetiro(nroClienteAntecesor);
				if(dFecha == null) {
					dFecha=fMac;
				}					
			}else {
				dFecha = miDao.getFInstal(reg.numero_cliente);
				if(dFecha == null){
					dFecha=fMac;
				}
			}
		}
		return dFecha;
	}

	private Date getFMoveIn(FechasDTO rFechas, ClienteDTO rClie) {
		Date dFecha = null;
		ClientesDAO miDao = new ClientesDAO();

		dFecha= miDao.getFMoveIn1(rClie.numero_cliente, fRti);
		if(dFecha == null) {
			dFecha = rFechas.dFechaAlta;
		}
		return dFecha;
	}
	
}
