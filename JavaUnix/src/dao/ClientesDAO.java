package dao;
import conectBD.UConnection;
import entidades.ClienteDTO;
import entidades.MoveInDTO;
import entidades.EstadosClienteDTO;
import entidades.FechasDTO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
//import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Vector;
import java.util.Date;

public class ClientesDAO {
	private Date fPivote = null;
	private Date fRti = null;
	private Date fLimInf=null;
	private Date fMac=null;
		
	public Boolean ProcesaMigra() {
		FechasDTO regFechas = new FechasDTO();
		EstadosClienteDTO estados = null;
		String sLimInf = "01-12-2014";
		String sMac="24-09-1995";
		SimpleDateFormat sdf = new SimpleDateFormat("dd-MM-yyyy");
		long iCantCliVuelta;
		long iCantClientes;
		Date dIni = null;

		fPivote = getFPivote();
		fRti = getFRTI();

		try {
			fLimInf = sdf.parse(sLimInf);
			fMac = sdf.parse(sMac);
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}
		
		Connection con = null;
		PreparedStatement pstm0 = null;
		ResultSet rs0 = null;

		ClienteDTO miReg = null;
		String sql = getQuery1();

		iCantCliVuelta=0;
		iCantClientes=0;

		try{
			con = UConnection.getConnection();
			con.setAutoCommit(false);
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm0 = con.prepareStatement(sql, ResultSet.TYPE_SCROLL_INSENSITIVE , ResultSet.CONCUR_READ_ONLY, ResultSet.HOLD_CURSORS_OVER_COMMIT);
			pstm0.setQueryTimeout(120);
			pstm0.setFetchSize(1);
			rs0 = pstm0.executeQuery();
			
			while(rs0.next()){
				miReg = new ClienteDTO();
				
				miReg.numero_cliente = rs0.getLong("numero_cliente");
				miReg.sucursal = rs0.getString("sucursal");
				miReg.sector = rs0.getLong("sector");
				miReg.tarifa = rs0.getString("tarifa");
				miReg.tipo_sum = rs0.getInt("tipo_sum");
				//miReg.corr_facturacion = rs.getInt("corr_facturacion");
				miReg.corr_facturacion = rs0.getInt(6);
				miReg.provincia = rs0.getString("provincia");
				miReg.partido = rs0.getString("partido");
				miReg.comuna = rs0.getString("comuna");
				miReg.tipo_iva = rs0.getString("tipo_iva");
				miReg.tipo_cliente = rs0.getString("tipo_cliente");
				miReg.actividad_economic = rs0.getString("actividad_economic");
				miReg.sNroBeneficiario = rs0.getString("beneficiario");

				//-------------------------------------
				regFechas.dFechaPivote = fPivote;
				regFechas.dFechaLimInf = fLimInf;

				//Fecha Validez de Tarifa
				regFechas.dFechaValTar = getFValTar(miReg);
				//System.out.println("Buscando Alta");
				
				//Fecha Alta Real
				regFechas.dFechaAlta = getFAltaReal(miReg);
				//System.out.println("Buscando Movein");
				
				//Fecha Move In
				regFechas.dFechaMoveIn = getFMoveIn(regFechas, miReg);
				//System.out.println("Buscando Estados");
				
				//Tarifa - UL y Motivo Alta
				estados = getTarifaUl(miReg.numero_cliente, fPivote);

				//Grabar Datos
				if(!setStatus(miReg.numero_cliente, regFechas, estados)) {
					System.out.println("Error al insertar Status y Fechas para cliente " + miReg.numero_cliente);
				}
				
				con.commit();

				iCantCliVuelta++;
				iCantClientes++;
//System.out.println("Va por Cliente: " + miReg.numero_cliente + " " + iCantClientes + " Clientes");				
				if(iCantCliVuelta > 100000) {
					System.out.println("Va por " + iCantClientes + " Clientes");
					dIni = new Date();
					System.out.println("Fecha Hora " + sdf.format(dIni));
					iCantCliVuelta=0;
				}

			}
			//Graba Par General
			regFechas.dFechaPivote = fPivote;
			regFechas.dFechaLimInf = fLimInf;

			if(!SetParam(regFechas)) {
				System.out.println("Error al insertar Parametros grales.");
			}
		}catch(Exception ex){
			System.out.println("revento en la vuelta " + iCantClientes);
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}		
		
		return true;
	}
	
	public Collection<ClienteDTO> getLstClientes(){
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;

		Vector<ClienteDTO> miLista = new Vector<ClienteDTO>();
		ClienteDTO miReg = null;
		String sql = getQuery1();
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(sql);
			rs = pstm.executeQuery();
			
			while(rs.next()){
				miReg = new ClienteDTO();
				
				miReg.numero_cliente = rs.getLong("numero_cliente");
				miReg.sucursal = rs.getString("sucursal");
				miReg.sector = rs.getLong("sector");
				miReg.tarifa = rs.getString("tarifa");
				miReg.tipo_sum = rs.getInt("tipo_sum");
				//miReg.corr_facturacion = rs.getInt("corr_facturacion");
				miReg.corr_facturacion = rs.getInt(6);
				miReg.provincia = rs.getString("provincia");
				miReg.partido = rs.getString("partido");
				miReg.comuna = rs.getString("comuna");
				miReg.tipo_iva = rs.getString("tipo_iva");
				miReg.tipo_cliente = rs.getString("tipo_cliente");
				miReg.actividad_economic = rs.getString("actividad_economic");
				miReg.sNroBeneficiario = rs.getString("beneficiario");
				
				miLista.add(miReg);
			}
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return miLista;
	}

	public Boolean insClientes(Long nroCliente){
		Connection con = null;
		PreparedStatement pstm = null;

		String sql = getQuery2(nroCliente);
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(sql);
			pstm.executeQuery();
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}
		return true;
	}
	
	public ClienteDTO getCliente(Long nroCliente) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		String sql = getQuery3(nroCliente);
		ClienteDTO miReg = null;
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(sql);
			rs = pstm.executeQuery();
			
			while(rs.next()){
				miReg = new ClienteDTO();
				
				miReg.numero_cliente = rs.getLong("numero_cliente");
				miReg.sucursal = rs.getString("sucursal");
				miReg.sector = rs.getLong("sector");
				miReg.tarifa = rs.getString("tarifa");
				miReg.tipo_sum = rs.getInt("tipo_sum");
				miReg.corr_facturacion = rs.getInt("corr_facturacion");
				miReg.provincia = rs.getString("provincia");
				miReg.partido = rs.getString("partido");
				miReg.comuna = rs.getString("comuna");
				miReg.tipo_iva = rs.getString("tipo_iva");
				miReg.tipo_cliente = rs.getString("tipo_cliente");
				miReg.actividad_economic = rs.getString("actividad_economic");
				
			}
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return miReg;
	}
	
	public Collection<MoveInDTO>getLstMoveIn(String Sucursal){
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;

		Vector<MoveInDTO> miLista = new Vector<MoveInDTO>();
		MoveInDTO miReg = null;
		String sql = getQuery4(Sucursal);
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(sql);
			rs = pstm.executeQuery();
			
			while(rs.next()){
				miReg = new MoveInDTO();

				miReg.nroCliente = rs.getLong("numero_cliente");
				miReg.Tarifa = rs.getString("tarifa");
				miReg.Categoria = rs.getString("categoria");
				miReg.CDC = rs.getString("cdc");
				miReg.Sucursal = rs.getString("sucursal");
				miReg.Beneficiario = rs.getLong("beneficiario");
				miReg.CorrFacturacion = rs.getInt("corr_fac");
				miReg.Electro = rs.getString("electro");
				
				miLista.add(miReg);
			}
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return miLista;
		
	}

	public Date getFPivote() {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFecha = null;
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(SQL_SEL_FPIVOTE);
			pstm.setQueryTimeout(120);
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFecha = rs.getDate(1);
			}
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return dFecha;
	}
	
	
	public Date getFRTI() {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFecha = null;
		
		try{
			con = UConnection.getConnection();
			pstm = con.prepareStatement(SQL_SEL_FRTI);
			pstm.setQueryTimeout(120);
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFecha = rs.getDate(1);
			}
			
		}catch(Exception ex){
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return dFecha;
	}
	
	public Date getFValTar1(long lNroCliente, Date dFecha) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFValtar = null;
		java.sql.Date fechaBD = convertJavaDateToSqlDate(dFecha);
		//java.sql.Date fechaBD = (java.sql.Date)dFecha;
		
		try{
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_VIGTARIFA1);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			pstm.setDate(2, fechaBD);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFValtar = rs.getDate(1);
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getFValTar1");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
				
		return dFValtar;
	}
	
	public Date getFValTar2(long lNroCliente) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFValtar = null;
		
		try{
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_VIGTARIFA2);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFValtar = rs.getDate(1);
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getFValTar2");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return dFValtar;
	}

	
	public Date getFRetiro(long lNroCliente) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFValtar = null;
		
		try{
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_RETIRO);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFValtar = rs.getDate(1);
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getFRetiro");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return dFValtar;
	}

	public Date getFInstal(long lNroCliente) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		Date dFInstal = null;
		
		try{
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_FINSTAL);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFInstal = rs.getDate(1);
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getFInstal");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return dFInstal;
	}
	
	public EstadosClienteDTO getTarifaUl(long lNroCliente, Date dFecha) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		java.sql.Date fechaBD = (java.sql.Date)dFecha;
		EstadosClienteDTO estados = new EstadosClienteDTO();
		
		try{
			//Tarifa y UL
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_TARIFA1);
			pstm.setLong(1, lNroCliente);
			pstm.setDate(2, fechaBD);
			pstm.setQueryTimeout(120);
			rs = pstm.executeQuery();
			
			if(rs.next()){
				estados.sTarifa = rs.getString(1);
				estados.sUL = rs.getString(2);
			}else {
				estados.sTarifa=" ";
				estados.sUL=" ";
			}
			
			// Motivo de Alta
			pstm=null;
			rs=null;

			estados.sMotivoAlta="N2";
			pstm = con.prepareStatement(SQL_SEL_MOTALTA);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				String sMotivo = rs.getString(1);
				if(sMotivo != null) {
					if(sMotivo.trim().compareTo("S16")==0) {
						estados.sMotivoAlta="N1";
					}
				}
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getTarifaUl");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return estados;
	}

	public Date getFMoveIn1(long lNroCliente, Date dFecha) {
		Connection con = null;
		PreparedStatement pstm = null;
		ResultSet rs = null;
		java.sql.Date fechaBD = (java.sql.Date)dFecha;
		Date dFMovein = null;
		
		try{
			con = UConnection.getConnection();
			con.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
			pstm = con.prepareStatement(SQL_SEL_FMOVEIN1);
			pstm.setQueryTimeout(120);
			pstm.setLong(1, lNroCliente);
			pstm.setDate(2, fechaBD);
			
			rs = pstm.executeQuery();
			
			if(rs.next()){
				dFMovein = rs.getDate(1);
			}
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO getFMoveIn1");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(rs != null) rs.close();
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return dFMovein;
	}
	
	public boolean setStatus(long lNroCliente, FechasDTO regF, EstadosClienteDTO regE) {
		Connection con = null;
		PreparedStatement pstm = null;
		java.sql.Date fValTar = (java.sql.Date)regF.dFechaValTar;
		java.sql.Date fAlta = (java.sql.Date)regF.dFechaAlta;
		java.sql.Date fMoveIn = (java.sql.Date)regF.dFechaMoveIn;
		java.sql.Date fPivote = (java.sql.Date)regF.dFechaPivote;
		java.sql.Date fLimInf = convertJavaDateToSqlDate(regF.dFechaLimInf);
		
		try{
			con = UConnection.getConnection();
			con.setAutoCommit(false);
			
			pstm = con.prepareStatement(SQL_INS_REG);
			
			pstm.setLong(1, lNroCliente);
			pstm.setDate(2, fValTar);
			pstm.setDate(3, fAlta);
			pstm.setDate(4, fMoveIn);
			pstm.setDate(5, fPivote);
			pstm.setDate(6, fLimInf);
			pstm.setString(7, regE.sTarifa);
			pstm.setString(8, regE.sUL);
			pstm.setString(9, regE.sMotivoAlta);
			
			pstm.executeUpdate();
			
			con.commit();
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO setStatus");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
				
		return true;
	}
	
	public Boolean SetParam(FechasDTO regF) {
		Connection con = null;
		PreparedStatement pstm = null;
		java.sql.Date fPivote = (java.sql.Date)regF.dFechaPivote;
		java.sql.Date fLimInf = (java.sql.Date)regF.dFechaLimInf;
		
		try{
			con = UConnection.getConnection();
			con.setAutoCommit(false);
			
			pstm = con.prepareStatement(SQL_INS_PAR);
			pstm.setDate(1, fPivote);
			pstm.setDate(2, fLimInf);
			
			pstm.executeUpdate();
			
			con.commit();
			
		}catch(Exception ex){
			System.out.println("Fallo ClientesDAO setParam");
			ex.printStackTrace();
			throw new RuntimeException(ex);
		}finally{
			try{
				if(pstm != null) pstm.close();
			}catch(Exception ex){
				ex.printStackTrace();
				throw new RuntimeException(ex);
			}
		}
		
		return true;
	}
	
	public java.sql.Date convertJavaDateToSqlDate(java.util.Date date) {
	    return new java.sql.Date(date.getTime());
	}

	private Date getFValTar(ClienteDTO reg) {
		Date dFecha = null;
		
		if(reg.corr_facturacion > 0) {
			dFecha=getFValTar1(reg.numero_cliente, fLimInf);
			if(dFecha == null) {
				System.out.println("No se encontró fecha Val Tar para cliente " + reg.numero_cliente);
			}else {
				if(fLimInf.compareTo(dFecha) > 0) {
					dFecha=fLimInf;
				}
			}
		}else {
			dFecha= getFValTar2(reg.numero_cliente);
			if(dFecha == null) {
				long nroClienteAntecesor = Long.parseLong(reg.sNroBeneficiario);
				if(nroClienteAntecesor > 0) {
					dFecha = getFRetiro(nroClienteAntecesor);
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

		dFecha= getFValTar2(reg.numero_cliente);
		if(dFecha == null) {
			long nroClienteAntecesor = Long.parseLong(reg.sNroBeneficiario);
			if(nroClienteAntecesor > 0) {
				dFecha = getFRetiro(nroClienteAntecesor);
				if(dFecha == null) {
					dFecha=fMac;
				}					
			}else {
				dFecha = getFInstal(reg.numero_cliente);
				if(dFecha == null){
					dFecha=fMac;
				}
			}
		}
		return dFecha;
	}

	private Date getFMoveIn(FechasDTO rFechas, ClienteDTO rClie) {
		Date dFecha = null;

		dFecha= getFMoveIn1(rClie.numero_cliente, fRti);
		if(dFecha == null) {
			dFecha = rFechas.dFechaAlta;
		}
		return dFecha;
	}
	
	
	private String getQuery1(){
		String sql="";
		
		sql = "SELECT c.numero_cliente, ";
		sql += "c.sucursal, "; 
		sql += "c.sector, ";
		sql += "c.tarifa, ";
		sql += "c.tipo_sum, ";
		sql += "NVL(c.corr_facturacion, 0) corrFac, ";
		sql += "c.provincia, ";
		sql += "c.partido, ";
		sql += "c.comuna, ";
		sql += "c.tipo_iva, ";
		sql += "c.tipo_cliente, ";
		sql += "c.actividad_economic, ";
		sql += "NVL(c.nro_beneficiario, 0) beneficiario ";
		sql += "FROM cliente c ";
		
		sql += ", migra_activos ma ";
		
		sql += "WHERE c.estado_cliente = 0 ";
		sql += "AND c.tipo_sum != 5 ";
		sql += "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ";
		sql += "WHERE cm.numero_cliente = c.numero_cliente ";
		sql += "AND cm.fecha_activacion < TODAY ";
		sql += "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ";
		
		sql += "AND ma.numero_cliente = c.numero_cliente ";
		
		return sql;
		
	}

	private String getQuery2(Long nroCliente){
		String sql;
		
		sql = "INSERT INTO migra_activos (numero_cliente)VALUES(" + nroCliente + ")";
		
		return sql;
	}
	
	private String getQuery3(Long nroCliente){
		String sql="";
		
		sql = "SELECT numero_cliente, ";
		sql += "sucursal, "; 
		sql += "sector, ";
		sql += "tarifa, ";
		sql += "tipo_sum, ";
		sql += "corr_facturacion, ";
		sql += "provincia, ";
		sql += "partido, ";
		sql += "comuna, ";
		sql += "tipo_iva, ";
		sql += "tipo_cliente, ";
		sql += "actividad_economic ";
		sql += "FROM cliente ";
		sql += "WHERE numero_cliente = " + nroCliente;
		
		return sql;
		
	}

	private String getQuery4(String sucursal){
		String sql="";
		
		sql = "SELECT c.numero_cliente, ";
		sql += "NVL(t1.cod_sap, c.tarifa) tarifa, ";
		sql += "t2.cod_sap categoria,";
		sql += "t2.acronimo_sap cdc, ";
		sql += "t3.cod_sap sucursal, ";
		sql += "NVL(c.nro_beneficiario, 0) beneficiario, ";
		sql += "NVL(c.corr_facturacion, 0) corr_fac, ";
		sql += "CASE ";
		sql += "	WHEN cv.numero_cliente IS NOT NULL THEN 'SI' ";
		sql += "	ELSE 'NO' ";
		sql += "END electro ";
		sql += "FROM cliente c, migra_activos ma, OUTER sap_transforma t1, OUTER sap_transforma t2, OUTER clientes_vip cv ";
		sql += ", OUTER sap_transforma t3 ";
		sql += "WHERE c.numero_cliente = ma.numero_cliente ";
		sql += "AND c.sucursal = '%s' ";
		sql += "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ";
		sql += "WHERE cm.numero_cliente = c.numero_cliente ";
		sql += "AND cm.fecha_activacion < TODAY ";
		sql += "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ";
		sql += "AND t1.clave = 'TARIFTYP' ";
		sql += "AND t1.cod_mac = c.tarifa ";
		sql += "AND t2.clave = 'TIPCLI' ";
		sql += "AND t2.cod_mac = c.tipo_cliente ";
		sql += "AND cv.numero_cliente = c.numero_cliente ";
		sql += "AND cv.fecha_activacion <= TODAY ";
		sql += "AND (cv.fecha_desactivac IS NULL OR cv.fecha_desactivac > TODAY) ";
		sql += "AND t3.clave = 'CENTROOP' ";
		sql += "AND t3.cod_mac = c.sucursal ";
		
		return String.format(sql, sucursal.trim());
		
	}
	
	private static String SQL_INS_REG = "INSERT INTO sap_regi_cliente( " +
			"numero_cliente, " +
			"fecha_val_tarifa, " +
			"fecha_alta_real, " +
			"fecha_move_in, " +
			"fecha_pivote, " +
			"fecha_limi_inf, " +
			"tarifa, " +
			"ul, " +
			"motivo_alta " +
			")VALUES( " +
			"?,?,?,?,?,?,?,?,?)";

	private static String SQL_INS_PAR = "INSERT INTO sap_regi_cliente( " +
			"numero_cliente, " +
			"fecha_pivote, " +
			"fecha_limi_inf " +
			")VALUES( " +
			"0,?,?)";
	
	private static String SQL_SEL_FPIVOTE = "SELECT TODAY - 420 FROM dual";
			
	private static String SQL_SEL_FRTI = "SELECT fecha_modificacion " +
			"FROM tabla " +
			"WHERE nomtabla = 'SAPFAC' " +
			"AND sucursal = '0000' " +
			"AND codigo = 'RTI-1' " +
			"AND fecha_activacion <= TODAY " +
			"AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ";
	
	private static String SQL_SEL_VIGTARIFA1 = "SELECT MIN(fecha_lectura) FROM hislec " +
			"WHERE numero_cliente = ? " +
			"AND fecha_lectura > ? " +
			"AND tipo_lectura NOT IN (5, 6, 8) ";

	private static String SQL_SEL_VIGTARIFA2 = "SELECT fecha_terr_puser "+
			"FROM estoc " +
			"WHERE numero_cliente = ? ";
	
	private static String SQL_SEL_RETIRO = "SELECT MAX(m2.fecha_modif) " +
			"FROM modif m2 " +
			"WHERE m2.numero_cliente = ? " +
			"AND m2.codigo_modif = 58 ";

	public static String SQL_SEL_FINSTAL = 	"SELECT MIN(m.fecha_ult_insta) " +
			"FROM medid m " +
			"WHERE m.numero_cliente = ? "; 

	private static String SQL_SEL_TARIFA1 = "SELECT first 1 "+
			"CASE "+
			"	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "+ 
			"	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' "+ 
			"	ELSE t1.cod_sap "+
			"END, "+ 
			"s.cod_ul_sap || "+ 
			"LPAD(CASE WHEN h.sector>60 AND h.sector < 81 THEN h.sector ELSE h.sector END, 2, 0) || "+  
			"LPAD(h.zona,5,0), "+
			"h.corr_facturacion "+
			"FROM cliente c, hisfac h, sap_transforma t1, sucur_centro_op s "+ 
			"WHERE c.numero_cliente = ? "+
			"AND h.numero_cliente = c.numero_cliente "+
			"AND h.fecha_lectura >= ? "+
			"AND t1.clave = 'TARIFTYP' " +
			"AND t1.cod_mac = h.tarifa "+ 
			"AND s.cod_centro_op = h.sucursal "+ 
			"AND s.fecha_activacion <= TODAY "+ 
			"AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "+ 
			"ORDER BY h.corr_facturacion ASC ";
	
	private static String SQL_SEL_MOTALTA = "SELECT e.cod_motivo "+ 
		"FROM solicitud s, est_sol e " +
		"WHERE s.numero_cliente = ? " +
		"AND e.nro_solicitud = s.nro_solicitud ";
			
	
	private static String SQL_SEL_FMOVEIN1 = "SELECT MIN(h1.fecha_lectura) "+
			"FROM hislec h1 "+
			"WHERE h1.numero_cliente = ? "+
			"AND tipo_lectura = 8 "+
			"AND h1.fecha_lectura > (SELECT MIN(h2.fecha_lectura) "+
			"	FROM hislec h2 "+ 
			" 	WHERE h2.numero_cliente = h1.numero_cliente "+
			"  AND h2.tipo_lectura IN (1,2,3,4) "+
			"  AND h2.fecha_lectura > ?) ";
			
			
			
}