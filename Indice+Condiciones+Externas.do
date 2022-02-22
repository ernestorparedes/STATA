

***************************************************
**** GENERANDO EL ÍNDICE DE FRAGILIDAD EXTERNA ****
***************************************************

clear
cd ""


*--------------------------------
******* BASE DE DATOS **********
*--------------------------------


/////// PROLEGÓMENOS /////////

	* Importando base y limpiando
	import excel using Base, sheet("Base") firstrow
	drop if missing(Fecha)
	save basedatos, replace
	gen quart = qofd(Fecha)
	format %tq quart


	* Recodificando variables
	encode Trim, gen(trime)
	gen año = real(Año)

	* Eliminando variables innecesarias
	drop Año
	drop Trim
	rename trime Trim

	*Generación de variables del índice
	gen pprina = PasivosPI/RINA
	gen dpet = DeudaPúblicaExterna/Exportaciones
	gen feacido = (SaldoComercial - IED)/Exportaciones
	gen flujonor = IED/Exportaciones
	gen divexp = ExpPrimarias/Exportaciones
	gen divimp = ImpConsumo/Importaciones
	gen expos = (IED+Remesas)/PIB
	sum expos
	gen exposicion = (expos-r(mean))
	save basedatos, replace
	


/////// LOOP PARA REALIZAR ÍNDICE EN DISTINTOS PERIODOS DE TIEMPO ///////

	* Definiendo tamaños
	sum año
	scalar ultimoaño = r(max)
	scalar  inicialaño = r(min)
	local uaño = ultimoaño
	local paño = inicialaño
	local limiteaño = ultimoaño-5

	* Loop de creación de índices
	forvalues i =  `paño'(1)`limiteaño' {

			
		drop if año<`i'
			
			

					************************************************
					////// ÍNDICE DE VULNERABILIDAD EXTERNA ////////
					************************************************

					* Formula 1
					foreach f1 in pprina dpet feacido divexp divimp Petróleo{
							sum `f1'
							scalar range = r(max) - r(min) 
							gen f1_`f1' = (`f1' - r(min)) / range 
							scalar drop range

													}


					* Formula 2
					foreach f2 in flujonor exposicion{
							sum `f2'
							scalar range = r(max) - r(min) 
							gen f2_`f2' = ((`f2' - r(max)) / range)*-1 
							scalar drop range
													}

					rename f1_Petróleo f1_Petróleove

					* Generando Subíndices del IVE
					gen v1_`i' = f1_pprina 	/*Liquidez*/
					gen v2_`i' = f1_dpet	/*Endeudamiento*/
					gen v3_`i' = f1_feacido	/*Resultado*/ // Déficit comercial ácido sobre expos. Si 0 no hay déficit, si >0 si hay, si <0 hay superavit.
					gen v4_`i' = f2_flujonor	/*Posición*/
					gen v5_`i' = f2_exposicion	/*Exposición*/
					gen v6_`i' = f1_divexp	/*Divesificación de Exportaciones*/
					gen v7_`i' = f1_divimp	/*Importaciones Ociosas*/
					gen v8_`i' = f1_Petróleove	/*Precios*/
					
					
					
					* Invertimos escala de índice
					forvalues j = 1(1)8 {
			
						gen inv_v`j'_`i' = (1-v`j'_`i')*100
					
											}
					
					* Desestacionalizamos índice invertido
					forvalues j = 1(1)8 {
					
						tsset inv_v`j'_`i' quart, quarterly
						tsset quart
						tssmooth ma ma_v`j'`i' = inv_v`j'_`i' , window(3 1) replace
						
											}

					* Generamos índice del año
					egen ive_`i' = rowmean(ma_v*)
					
					

					**********************************************
					////// ÍNDICE DE CONDICIONES EXTERNAS ////////
					**********************************************

					* Formula 1
					foreach f1 in Petróleo VIX InfEEUU BrVTC FED Libor Oro Yen{
							sum `f1'
							scalar range = r(max) - r(min) 
							gen f1_`f1' = (`f1' - r(min)) / range, 
							scalar drop range

																	}

					* Fórmula 2
					foreach f2 in Carne Café Oro Azúcar PIBr  {
							sum `f2'
							scalar range = r(max) - r(min) 
							gen f2_`f2' = ((`f2' - r(max)) / range)*-1 
							scalar drop range
																	}

*
																	
					* Generando Subíndices
					egen c1_`i' = rowmean(f2_Carne f2_Café f2_Oro f2_Azúcar f1_Petróleo) /*Comercio Exterior*/
					egen c2_`i' = rowmean(f1_VIX)								/*Bursátil*/
					egen c3_`i' = rowmean(f1_InfEEUU f1_FED f1_BrVTC)			/*Monetario*/
					egen c4_`i' = rowmean(f1_Libor)					/*Crediticio*/
					egen c5_`i' = rowmean(f1_Oro f1_Yen)			/*Geopolitico*/
					egen c6_`i' = rowmean(f2_PIBr)					/*Crecimiento*/
					
					* Damos vuelta
					forvalues j = 1(1)6 {
			
						gen inv_c`j'_`i' = (1-c`j'_`i')*100
					
											}
					
					* Desestacionalizamos
					forvalues j = 1(1)6 {
					
						tsset inv_c`j'_`i' quart, quarterly
						tsset quart
						tssmooth ma ma_c`j'`i' = inv_c`j'_`i' , window(3 1) replace
						
											}

					egen ice_`i' = rowmean(ma_c*)

			
			
					********************************************
					////// ÍNDICE DE FRAGILIDAD EXTERNA ////////
					********************************************					
					
					egen ife_`i' = rowmean(ice_`i' ive_`i')	
					tsset ife_`i' quart, quarterly
					tsset quart
					

					save basesub_`i', replace
					drop f1_* f2_* ive* c* inv* ice* ma_* ife*
					
			}



/////// LOOP PARA JUNTAR LOS ÍNDICES HISTÓRICOS ///////


	use basedatos, clear
	keep Fecha AñoTrim quart Trim año PIBni RINA 
	
	* Creando serie smooth del PIB real trimestral de Nicaragua
	tsset PIBni quart, quarterly
	tsset quart
	tssmooth ma PIBnis = PIBni , window(3 1) replace
	drop PIBni
	
	tsset RINA quart, quarterly
	tsset quart
	tssmooth ma RINAn = RINA , window(3 1) replace
	drop RINA
	
	gen rina = ln(RINAn)	
	gen rinas = ((rina[_n]-rina[_n-1])*100)
	drop rina
	
	gen lpib = ln(PIBnis)	
	gen pib = ((lpib[_n]-lpib[_n-1])*100)
	drop lpib
	
	
	* Definiendo tamaños
	sum año
	scalar ultimoaño = r(max)
	scalar  inicialaño = r(min)
	local uaño = ultimoaño
	local paño = inicialaño
	local limiteaño = ultimoaño-5


	* Uniendo bases de datos
	forvalues i =  `paño'(1)`limiteaño' {

		merge 1:1 AñoTrim using basesub_`i', keepusing(ice* ive* ife* ma_*)
		drop _merge

										}

	*drop index_ice index_ive

	* Creando índices históricos
	
*	egen index_ive = rowmean(ma_v*)
*	egen index_ice = rowmean(ma_c*)
	
*	egen index_ife = rowmean(index_*)
	
		forvalues i = 1(1)6 {
		
			egen fc`i' = rowmean(ma_c`i'*)
			
		
		}
		
		
		forvalues i = 1(1)8 {
					
			egen fv`i' = rowmean(ma_v`i'*)
		
		}
	
*	egen index_ife_2 = rowmean(fc* fv*)
	
	egen index_ice = rowmean(fc*)
	egen index_ive = rowmean(fv*)
	egen index_ife = rowmean(in*)
	
	
	* Creando series de crecimiento de los indices
	gen life = ln(index_ife)	
		gen lifec = ((life[_n]-life[_n-1])*100)+50
		drop life
	
	gen live = ln(index_ive)	
		gen livec = ((live[_n]-live[_n-1])*100)+50
		drop live
	
	gen lice = ln(index_ice)	
		gen licec = ((lice[_n]-lice[_n-1])*100)+50
		drop lice
	
	save basedatos, replace

/*	
	** Loop para VARs
	
	
	sum año
	scalar ultimoaño = r(max)
	scalar  inicialaño = r(min)
	local uaño = ultimoaño
	local paño = inicialaño
	local limiteaño = ultimoaño-5

	* Loop de creación de vares de  índices
	forvalues i =  `paño'(1)`limiteaño' {
	
			gen life_`i' = ln(index_ife_ma_`i')	
			gen lifec_`i' = ((life_`i'[_n]-life_`i'[_n-1])*100)+50
			drop life_`i'

			var lifec_`i' pib, lags(1)
			irf create IFE_`i', set(results_`i') step(10) replace
			*irf table oirf, impulse(lifec_`i') response(pib)
			
			var lifec_`i' rinas pib, lags(1)
			irf create IFErin_`i', set(resultsr_`i') step(10) replace
			*irf graph oirf, impulse(IFErin_`i') irf(IFErin_`i')
			
			drop lifec_`i'
	
	}
	
	
	*** Creando VAR normal
	
	var lifec pib, lags(1)
	irf create IFE, set(results1) step(10) replace
	irf table oirf, impulse(lifec) response(pib)
	
	*var livec pib, lags(1)
	*irf create IVE, set(results2) step(10) replace
	*irf graph oirf, impulse(livec) response(PIBnis)
	
	*var licec pib, lags(1)
	*irf create ICE, set(results3) step(10) replace
	*irf graph oirf, impulse(licec) response(PIBnis)
	
	
	*** Creando VAR con RINAS

	var lifec rinas pib, lags(1)
	irf create iferin, set(results4) step(10) replace
	irf graph oirf, impulse(lifec rinas pib) irf(iferin)
	
	*tsset index_ife Fecha
	*twoway line index_ife* Fecha
	
