//
//  Copyright 2021 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Libc

/// IAPWS formulations of the thermodynamic properties of water and steam.
public struct WaterSteam: Codable {
  /// The temperature of the water/steam.
  public var temperature: Temperature
  /// The pressure of the water/steam.
  public var pressure: Double
  /// The mass flow rate of the water/steam.
  public var massFlow: Double
  /// The specific enthalpy of the water/steam.
  public var enthalpy: Double

  /// Creates a WaterSteam instance with the provided properties.
  /// - Parameters:
  ///   - temperature: The temperature of the water/steam.
  ///   - pressure: The pressure of the water/steam.
  ///   - massFlow: The mass flow rate of the water/steam.
  ///   - enthalpy: The specific enthalpy of the water/steam.
  public init(
    temperature: Temperature,
    pressure: Double,
    massFlow: Double,
    enthalpy: Double
  ) {
    self.temperature = temperature
    self.pressure = pressure
    self.massFlow = massFlow
    self.enthalpy = enthalpy
  }
  /// Calculates the temperature on the boiling point curve for the given pressure.
  /// - Parameter pressure: The pressure at which to calculate the temperature.
  /// - Returns: The temperature on the boiling point curve.
  public static func temperature(pressure: Double) -> Temperature {
    let p = pressure / 10
    return Temperature(Ts_p(p))
  }

  /// Calculates the specific enthalpy (kJ/kg) on the boiling point curve for the given pressure.
  /// - Parameter pressure: The pressure at which to calculate the specific enthalpy.
  /// - Returns: The specific enthalpy on the boiling point curve.
  public static func enthalpyLiquid(pressure: Double) -> Double {
    let p = pressure / 10
    let t = Ts_p(p)
    return h_pT(p, t, 1)
  }

  /// Calculates the specific enthalpy (kJ/kg) on the dew point curve for the given pressure.
  /// - Parameter pressure: The pressure at which to calculate the specific enthalpy.
  /// - Returns: The specific enthalpy on the dew point curve.
  public static func enthalpyVapor(pressure: Double) -> Double {
    let p = pressure / 10
    let t = Ts_p(p)
    return h_pT(p, t, 2)
  }
  /// Calculates the specific enthalpy (kJ/kg) for the given pressure and temperature.
  /// - Parameters:
  ///   - pressure: The pressure of the water/steam.
  ///   - temperature: The temperature of the water/steam.
  /// - Returns: The specific enthalpy of the water/steam.
  public static func enthalpy(pressure: Double, temperature: Temperature) -> Double {
    let p = pressure / 10
    let t = temperature.kelvin
    let r = region_pT(p, t)
    return h_pT(p, t, r)
  }
  /// Calculates the temperature of the water/steam for the given pressure and specific enthalpy.
  /// - Parameters:
  ///   - pressure: The pressure of the water/steam.
  ///   - enthalpy: The specific enthalpy of the water/steam.
  /// - Returns: The temperature of the water/steam.
  public static func temperature(pressure: Double, enthalpy: Double) -> Temperature {
    let p = pressure / 10
    let h = enthalpy
    return Temperature(T_ph(p, h))
  }
}

extension WaterSteam {
  /// Creates a WaterSteam instance with the provided temperature, pressure, and mass flow rate.
  /// The enthalpy is calculated based on the given pressure and temperature.
  /// - Parameters:
  ///   - temperature: The temperature of the water/steam.
  ///   - pressure: The pressure of the water/steam.
  ///   - massFlow: The mass flow rate of the water/steam.
  public init(temperature: Temperature, pressure: Double, massFlow: Double) {
    self.temperature = temperature
    self.pressure = pressure
    self.massFlow = massFlow
    self.enthalpy = WaterSteam.enthalpy(pressure: pressure, temperature: temperature)
  }
  /// Creates a WaterSteam instance with the provided specific enthalpy, pressure, and mass flow rate.
  /// The temperature is calculated based on the given pressure and specific enthalpy.
  /// - Parameters:
  ///   - enthalpy: The specific enthalpy of the water/steam.
  ///   - pressure: The pressure of the water/steam.
  ///   - massFlow: The mass flow rate of the water/steam.
  public init(enthalpy: Double, pressure: Double, massFlow: Double) {
    self.pressure = pressure
    self.massFlow = massFlow
    self.enthalpy = enthalpy
    self.temperature = WaterSteam.temperature(pressure: pressure, enthalpy: enthalpy)
  }

  public init() {
    self.pressure = 0
    self.massFlow = 0
    self.enthalpy = 0
    self.temperature = Temperature(celsius: 0)
  }
}

// p5 kJ/kg/K   eqs. (1)
fileprivate let SPECIFIC_GAS_CONSTANT = 0.461526

// p6  Table 1
fileprivate let B23 = [0.34805185628969e3, -0.11671859879975e1, 0.10192970039326e-2, 0.57254459862746e3, 0.1391883977887e2]

// p7  Table 2
fileprivate let R1_base: [(Double, Double, Double)] = [(0, -2, 0.14632971213167), (0, -1, -0.84548187169114), (0, 0, -0.3756360367204e1), (0, 1, 0.33855169168385e1), (0, 2, -0.95791963387872), (0, 3, 0.15772038513228), (0, 4, -0.16616417199501e-1), (0, 5, 0.81214629983568e-3), (1, -9, 0.28319080123804e-3), (1, -7, -0.60706301565874e-3), (1, -1, -0.18990068218419e-1), (1, 0, -0.32529748770505e-1), (1, 1, -0.21841717175414e-1), (1, 3, -0.5283835796993e-4), (2, -3, -0.47184321073267e-3), (2, 0, -0.30001780793026e-3), (2, 1, 0.47661393906987e-4), (2, 3, -0.44141845330846e-5), (2, 17, -0.72694996297594e-15), (3, -4, -0.31679644845054e-4), (3, 0, -0.28270797985312e-5), (3, 6, -0.85205128120103e-9), (4, -5, -0.22425281908e-5), (4, -2, -0.65171222895601e-6), (4, 10, -0.14341729937924e-12), (5, -8, -0.40516996860117e-6), (8, -11, -0.12734301741641e-8), (8, -6, -0.17424871230634e-9), (21, -29, -0.68762131295531e-18), (23, -31, 0.14478307828521e-19), (29, -38, 0.26335781662795e-22), (30, -39, -0.11947622640071e-22), (31, -40, 0.18228094581404e-23), (32, -41, -0.93537087292458e-25)]

// p10
fileprivate let R1_back_T_ph: [(Double, Double, Double)] = [(0, 0, -0.23872489924521e3), (0, 1, 0.40421188637945e3), (0, 2, 0.11349746881718e3), (0, 6, -0.58457616048039e1), (0, 22, -0.1528548241314e-3), (0, 32, -0.10866707695377e-5), (1, 0, -0.13391744872602e2), (1, 1, 0.43211039183559e2), (1, 2, -0.54010067170506e2), (1, 3, 0.30535892203916e2), (1, 4, -0.65964749423638e1), (1, 10, 0.93965400878363e-2), (1, 32, 0.1157364750534e-6), (2, 10, -0.25858641282073e-4), (2, 32, -0.40644363084799e-8), (3, 10, 0.66456186191635e-7), (3, 32, 0.80670734103027e-10), (4, 32, -0.93477771213947e-12), (5, 32, 0.58265442020601e-14), (6, 32, -0.15020185953503e-16)]

// p11
fileprivate let R1_back_T_ps: [(Double, Double, Double)] = [(0, 0, 0.17478268058307e3), (0, 1, 0.34806930892873e2), (0, 2, 0.65292584978455e1), (0, 3, 0.33039981775489), (0, 11, -0.19281382923196e-6), (0, 31, -0.24909197244573e-22), (1, 0, -0.26107636489332), (1, 1, 0.22592965981586), (1, 2, -0.64256463395226e-1), (1, 3, 0.78876289270526e-2), (1, 12, 0.35672110607366e-9), (1, 31, 0.17332496994895e-23), (2, 0, 0.56608900654837e-3), (2, 1, -0.32635483139717e-3), (2, 2, 0.44778286690632e-4), (2, 9, -0.51322156908507e-9), (2, 31, -0.42522657042207e-25), (3, 10, 0.26400441360689e-12), (3, 32, 0.78124600459723e-28), (4, 32, -0.30732199903668e-30)]

// p13  Table 10
fileprivate let R2_base_ideal: [(Double, Double)] = [(0, -0.96927686500217e1), (1, 0.10086655968018e2), (-5, -0.5608791128302e-2), (-4, 0.71452738081455e-1), (-3, -0.40710498223928), (-2, 0.14240819171444e1), (-1, -0.4383951131945e1), (2, -0.28408632460772), (3, 0.21268463753307e-1)]

// p14  Table 11
fileprivate let R2_base_res: [(Double, Double, Double)] = [(1, 0, -0.17731742473213e-2), (1, 1, -0.17834862292358e-1), (1, 2, -0.45996013696365e-1), (1, 3, -0.57581259083432e-1), (1, 6, -0.5032527872793e-1), (2, 1, -0.33032641670203e-4), (2, 2, -0.18948987516315e-3), (2, 4, -0.39392777243355e-2), (2, 7, -0.43797295650573e-1), (2, 36, -0.26674547914087e-4), (3, 0, 0.20481737692309e-7), (3, 1, 0.43870667284435e-6), (3, 3, -0.3227767723857e-4), (3, 6, -0.15033924542148e-2), (3, 35, -0.40668253562649e-1), (4, 1, -0.78847309559367e-9), (4, 2, 0.12790717852285e-7), (4, 3, 0.48225372718507e-6), (5, 7, 0.22922076337661e-5), (6, 3, -0.16714766451061e-10), (6, 16, -0.21171472321355e-2), (6, 35, -0.23895741934104e2), (7, 0, -0.5905956432427e-17), (7, 11, -0.12621808899101e-5), (7, 25, -0.38946842435739e-1), (8, 8, 0.11256211360459e-10), (8, 36, -0.82311340897998e1), (9, 13, 0.19809712802088e-7), (10, 4, 0.10406965210174e-18), (10, 10, -0.10234747095929e-12), (10, 14, -0.10018179379511e-8), (16, 29, -0.80882908646985e-10), (16, 50, 0.10693031879409), (18, 57, -0.33662250574171), (20, 20, 0.89185845355421e-24), (20, 35, 0.30629316876232e-12), (20, 48, -0.42002467698208e-5), (21, 21, -0.59056029685639e-25), (22, 53, 0.37826947613457e-5), (23, 39, -0.12768608934681e-14), (24, 26, 0.73087610595061e-28), (24, 40, 0.55414715350778e-16), (24, 58, -0.9436970724121e-6)]

// p22   Table 19
fileprivate let B2bc_back = [0.90584278514723e3, -0.67955786399241, 0.12809002730136e-3, 0.26526571908428e4, 0.45257578905948e1]

// p22
fileprivate let R2a_back_T_ph: [(Double, Double, Double)] = [(0, 0, 0.10898952318288e4), (0, 1, 0.84951654495535e3), (0, 2, -0.10781748091826e3), (0, 3, 0.33153654801263e2), (0, 7, -0.74232016790248e1), (0, 20, 0.11765048724356e2), (1, 0, 0.18445749355790e1), (1, 1, -0.41792700549624e1), (1, 2, 0.62478196935812e1), (1, 3, -0.17344563108114e2), (1, 7, -0.20058176862096e3), (1, 9, 0.27196065473796e3), (1, 11, -0.45511318285818e3), (1, 18, 0.30919688604755e4), (1, 44, 0.25226640357872e6), (2, 0, -0.61707422868339e-2), (2, 2, -0.31078046629583), (2, 7, 0.11670873077107e2), (2, 36, 0.12812798404046e9), (2, 38, -0.98554909623276e9), (2, 40, 0.28224546973002e10), (2, 42, -0.35948971410703e10), (2, 44, 0.17227349913197e10), (3, 24, -0.13551334240775e5), (3, 44, 0.12848734664650e8), (4, 12, 0.13865724283226e1), (4, 32, 0.23598832556514e6), (4, 44, -0.13105236545054e8), (5, 32, 0.73999835474766e4), (5, 36, -0.55196697030060e6), (5, 42, 0.37154085996233e7), (6, 34, 0.19127729239660e5), (6, 44, -0.41535164835634e6), (7, 28, -0.62459855192507e2)]

// p23
fileprivate let R2b_back_T_ph: [(Double, Double, Double)] = [(0, 0, 0.14895041079516e4), (0, 1, 0.74307798314034e3), (0, 2, -0.97708318797837e2), (0, 12, 0.24742464705674e1), (0, 18, -0.63281320016026), (0, 24, 0.11385952129658e1), (0, 28, -0.47811863648625), (0, 40, 0.85208123431544e-2), (1, 0, 0.93747147377932), (1, 2, 0.33593118604916e1), (1, 6, 0.33809355601454e1), (1, 12, 0.16844539671904), (1, 18, 0.73875745236695), (1, 24, -0.47128737436186), (1, 28, 0.15020273139707), (1, 40, -0.21764114219750e-2), (2, 2, -0.21810755324761e-1), (2, 8, -0.10829784403677), (2, 18, -0.46333324635812e-1), (2, 40, 0.71280351959551e-4), (3, 1, 0.11032831789999e-3), (3, 2, 0.18955248387902e-3), (3, 12, 0.30891541160537e-2), (3, 24, 0.13555504554949e-2), (4, 2, 0.28640237477456e-6), (4, 12, -0.10779857357512e-4), (4, 18, -0.76462712454814e-4), (4, 24, 0.14052392818316e-4), (4, 28, -0.31083814331434e-4), (4, 40, -0.10302738212103e-5), (5, 18, 0.28217281635040e-6), (5, 24, 0.12704902271945e-5), (5, 40, 0.73803353468292e-7), (6, 28, -0.11030139238909e-7), (7, 2, -0.81456365207833e-13), (7, 28, -0.25180545682962e-10), (9, 1, -0.17565233969407e-17), (9, 40, 0.86934156344163e-14)]

// p24
fileprivate let R2c_back_T_ph: [(Double, Double, Double)] = [(-7, 0, -0.32368398555242e13), (-7, 4, 0.73263350902181e13), (-6, 0, 0.35825089945447e12), (-6, 2, -0.58340131851590e12), (-5, 0, -0.10783068217470e11), (-5, 2, 0.20825544563171e11), (-2, 0, 0.61074783564516e6), (-2, 1, 0.85977722535580e6), (-1, 0, -0.25745723604170e5), (-1, 2, 0.31081088422714e5), (0, 0, 0.12082315865936e4), (0, 1, 0.48219755109255e3), (1, 4, 0.37966001272486e1), (1, 8, -0.10842984880077e2), (2, 4, -0.45364172676660e-1), (6, 0, 0.14559115658698e-12), (6, 1, 0.11261597407230e-11), (6, 4, -0.17804982240686e-10), (6, 10, 0.12324579690832e-6), (6, 12, -0.11606921130984e-5), (6, 16, 0.27846367088554e-4), (6, 20, -0.59270038474176e-3), (6, 22, 0.12918582991878e-2)]

// p26
fileprivate let R2a_back_T_ps: [(Double, Double, Double)] = [(-1.5, -24, -0.39235983861984e6), (-1.5, -23, 0.51526573827270e6), (-1.5, -19, 0.40482443161048e5), (-1.5, -13, -0.32193790923902e3), (-1.5, -11, 0.96961424218694e2), (-1.5, -10, -0.22867846371773e2), (-1.25, -19, -0.44942914124357e6), (-1.25, -15, -0.50118336020166e4), (-1.25, -6, 0.35684463560015), (-1, -26, 0.44235335848190e5), (-1, -21, -0.13673388811708e5), (-1, -17, 0.42163260207864e6), (-1, -16, 0.22516925837475e5), (-1, -9, 0.47442144865646e3), (-1, -8, -0.14931130797647e3), (-0.75, -15, -0.19781126320452e6), (-0.75, -14, -0.23554399470760e5), (-0.5, -26, -0.19070616302076e5), (-0.5, -13, 0.55375669883164e5), (-0.5, -9, 0.38293691437363e4), (-0.5, -7, -0.60391860580567e3), (-0.25, -27, 0.19363102620331e4), (-0.25, -25, 0.42660643698610e4), (-0.25, -11, -0.59780638872718e4), (-0.25, -6, -0.70401463926862e3), (0.25, 1, 0.33836784107553e3), (0.25, 4, 0.20862786635187e2), (0.25, 8, 0.33834172656196e-1), (0.25, 11, -0.43124428414893e-4), (0.5, 0, 0.16653791356412e3), (0.5, 1, -0.13986292055898e3), (0.5, 5, -0.78849547999872), (0.5, 6, 0.72132411753872e-1), (0.5, 10, -0.59754839398283e-2), (0.5, 14, -0.12141358953904e-4), (0.5, 16, 0.23227096733871e-6), (0.75, 0, -0.10538463566194e2), (0.75, 4, 0.20718925496502e1), (0.75, 9, -0.72193155260427e-1), (0.75, 17, 0.20749887081120e-6), (1, 7, -0.18340657911379e-1), (1, 18, 0.29036272348696e-6), (1.25, 3, 0.21037527893619), (1.25, 15, 0.25681239729999e-3), (1.5, 5, -0.12799002933781e-1), (1.5, 18, -0.82198102652018e-5)]

// p27
fileprivate let R2b_back_T_ps: [(Double, Double, Double)] = [(-6, 0, 0.31687665083497e6), (-6, 11, 0.20864175881858e2), (-5, 0, -0.39859399803599e6), (-5, 11, -0.21816058518877e2), (-4, 0, 0.22369785194242e6), (-4, 1, -0.27841703445817e4), (-4, 11, 0.99207436071480e1), (-3, 0, -0.75197512299157e5), (-3, 1, 0.29708605951158e4), (-3, 11, -0.34406878548526e1), (-3, 12, 0.38815564249115), (-2, 0, 0.17511295085750e5), (-2, 1, -0.14237112854449e4), (-2, 6, 0.10943803364167e1), (-2, 10, 0.89971619308495), (-1, 0, -0.33759740098958e4), (-1, 1, 0.47162885818355e3), (-1, 5, -0.19188241993679e1), (-1, 8, 0.41078580492196), (-1, 9, -0.33465378172097), (-0, 0, 0.13870034777505e4), (-0, 1, -0.40663326195838e3), (0, 2, 0.41727347159610e2), (0, 4, 0.21932549434532e1), (0, 5, -0.10320050009077e1), (0, 6, 0.35882943516703), (0, 9, 0.52511453726066e-2), (1, 0, 0.12838916450705e2), (1, 1, -0.28642437219381e1), (1, 2, 0.56912683664855), (1, 3, -0.99962954584931e-1), (1, 7, -0.32632037778459e-2), (1, 8, 0.23320922576723e-3), (2, 0, -0.15334809857450), (2, 1, 0.29072288239902e-1), (2, 5, 0.37534702741167e-3), (3, 0, 0.17296691702411e-2), (3, 1, -0.38556050844504e-3), (3, 3, -0.35017712292608e-4), (4, 0, -0.14566393631492e-4), (4, 1, 0.56420857267269e-5), (5, 0, 0.41286150074605e-7), (5, 1, -0.20684671118824e-7), (5, 2, 0.16409393674725e-8)]

// p28
fileprivate let R2c_back_T_ps: [(Double, Double, Double)] = [(-2, 0, 0.90968501005365e3), (-2, 1, 0.24045667088420e4), (-1, 0, -0.59162326387130e3), (0, 0, 0.54145404128074e3), (0, 1, -0.27098308411192e3), (0, 2, 0.97976525097926e3), (0, 3, -0.46966772959435e3), (1, 0, 0.14399274604723e2), (1, 1, -0.19104204230429e2), (1, 3, 0.53299167111971e1), (1, 4, -0.21252975375934e2), (2, 0, -0.31147334413760), (2, 1, 0.60334840894623), (2, 2, -0.42764839702509e-1), (3, 0, 0.58185597255259e-2), (3, 1, -0.14597008284753e-1), (3, 5, 0.56631175631027e-2), (4, 0, -0.76155864584577e-4), (4, 1, 0.22440342919332e-3), (4, 4, -0.12561095013413e-4), (5, 0, 0.63323132660934e-6), (5, 1, -0.20541989675375e-5), (5, 2, 0.36405370390082e-7), (6, 0, -0.29759897789215e-8), (6, 1, 0.10136618529763e-7), (7, 0, 0.59925719692351e-11), (7, 1, -0.20677870105164e-10), (7, 3, -0.20874278181886e-10), (7, 4, 0.10162166825089e-9), (7, 5, -0.16429828281347e-9)]

// p34
fileprivate let sat = [0.11670521452767e4, -0.72421316703206e6, -0.17073846940092e2, 0.1202082470247e5, -0.32325550322333e7, 0.1491510861353e2, -0.48232657361591e4, 0.40511340542057e6, -0.23855557567849, 0.65017534844798e3]

// p40
fileprivate let B34_ps_h: [(Double, Double, Double)] = [(0, 0, 0.600073641753024), (1, 1, -0.936203654849857e1), (1, 3, 0.246590798594147e2), (1, 4, -0.107014222858224e3), (1, 36, -0.915821315805768e14), (5, 3, -0.862332011700662e4), (7, 0, -0.235837344740032e2), (8, 24, 0.252304969384128e18), (14, 16, -0.389718771997719e19), (20, 16, -0.333775713645296e23), (22, 3, 0.356499469636328e11), (24, 18, -0.148547544720641e27), (28, 8, 0.330611514838798e19), (36, 24, 0.813641294467829e38)]

// p56
fileprivate let B34_ps_s: [(Double, Double, Double)] = [(0, 0, 0.639767553612785), (1, 1, -0.129727445396014e2), (1, 32, -0.224595125848403e16), (4, 7, 0.177466741801846e7), (12, 4, 0.717079349571538e10), (12, 14, -0.378829107169011e18), (16, 36, -0.955586736431328e35), (24, 10, 0.187269814676188e24), (28, 0, 0.119254746466473e12), (32, 18, 0.110649277244882e37)]

// p152
fileprivate let viscosity_in_the_ideal_gas_limit = [0.167752e-1, 0.220462e-1, 0.6366564e-2, -0.241605e-2]

// p152
fileprivate let viscosity_2: [(Double, Double, Double)] = [(0, 0, 0.520094), (0, 1, 0.850895e-1), (0, 2, -0.108374e1), (0, 3, -0.289555), (1, 0, 0.222531), (1, 1, 0.999115), (1, 2, 0.188797e1), (1, 3, 0.126613e1), (1, 5, 0.120573), (2, 0, -0.281378), (2, 1, -0.906851), (2, 2, -0.772479), (2, 3, -0.489837), (2, 4, -0.25704), (3, 0, 0.161913), (3, 1, 0.257399), (4, 0, -0.325372e-1), (4, 3, 0.698452e-1), (5, 4, 0.872102e-2), (6, 3, -0.435673e-2), (6, 5, -0.593264e-3)]

//p6 eqs.(6)
fileprivate func B23_T_p(_ pi: Double) -> Double { return B23[3] + sqrt((pi - B23[4]) / B23[2]) }

//p6  λ:Mpa,K  eqs.(7)
fileprivate func gamma_R1(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<34 { sum += R1_base[i].2 * pow(7.1 - pi, R1_base[i].0) * pow(tau - 1.222, R1_base[i].1) }
  return sum
}

//p8  λ:Mpa,K
fileprivate func gamma_tau_R1(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<34 { sum += R1_base[i].2 * pow(7.1 - pi, R1_base[i].0) * R1_base[i].1 * pow(tau - 1.222, R1_base[i].1 - 1) }
  return sum
}

//p8  λ:Mpa,K
fileprivate func gamma_pi_R1(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<34 { sum += -R1_base[i].2 * R1_base[i].0 * pow(7.1 - pi, R1_base[i].0 - 1) * pow(tau - 1.222, R1_base[i].1) }
  return sum
}

//p13  λ:Mpa,K  eqs.(16)
fileprivate func gamma_ideal_R2(_ pi: Double, _ tau: Double) -> Double {
  var sum = log(pi)
  for i in 0..<9 { sum += R2_base_ideal[i].1 * pow(tau, R2_base_ideal[i].0) }
  return sum
}

//p13 λ:Mpa,K   eqs.(17)
fileprivate func gamma_res_R2(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<43 { sum += R2_base_res[i].2 * pow(pi, R2_base_res[i].0) * pow(tau - 0.5, R2_base_res[i].1) }
  return sum
}

//p16 λ:Mpa
fileprivate func gamma_pi_ideal_R2(_ pi: Double) -> Double { return 1 / pi }

//p16  λ:Mpa,K
fileprivate func gamma_pi_res_R2(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<43 { sum += R2_base_res[i].2 * R2_base_res[i].0 * pow(pi, R2_base_res[i].0 - 1) * pow(tau - 0.5, R2_base_res[i].1) }
  return sum
}

//p16 λ:K
fileprivate func gamma_tau_ideal_R2(_ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<9 { sum += R2_base_ideal[i].1 * R2_base_ideal[i].0 * pow(tau, R2_base_ideal[i].0 - 1) }
  return sum
}

//p16  λ:Mpa,K
fileprivate func gamma_tau_res_R2(_ pi: Double, _ tau: Double) -> Double {
  var sum: Double = .zero
  for i in 0..<43 { sum += R2_base_res[i].2 * pow(pi, R2_base_res[i].0) * R2_base_res[i].1 * pow(tau - 0.5, R2_base_res[i].1 - 1) }
  return sum
}

//p40_book
fileprivate func B34_ps_h_eq(_ h: Double) -> Double {
  var sum: Double = .zero
  let eta = h / 2600
  for i in 0..<14 { sum += B34_ps_h[i].2 * pow(eta - 1.02, B34_ps_h[i].0) * pow(eta - 0.608, B34_ps_h[i].1) }
  return sum * 22
}

//p56_book
fileprivate func B34_ps_s_eq(_ s: Double) -> Double {
  var sum: Double = .zero
  let sigma = s / 5.2
  for i in 0..<10 { sum += B34_ps_s[i].2 * pow(sigma - 1.03, B34_ps_s[i].0) * pow(sigma - 0.699, B34_ps_s[i].1) }
  return sum * 22
}

//p21  eqs.(21)
fileprivate func R2_Bbc_h_p(_ pi: Double) -> Double { return B2bc_back[3] + sqrt((pi - B2bc_back[4]) / B2bc_back[2]) }

//p33   eqs.(30) siedelinie
fileprivate func ps_T(_ T: Double) -> Double {
  if T >= 273.15 && T <= 647.096 {
    let theta = T + sat[8] / (T - sat[9])
    let tmp = theta * theta
    let A = tmp + sat[0] * theta + sat[1]
    let B = sat[2] * tmp + sat[3] * theta + sat[4]
    let C = sat[5] * tmp + sat[6] * theta + sat[7]
    let temp = 2 * C / (sqrt(B * B - 4 * A * C) - B)
    return temp * temp * temp * temp
  } else {
    return 0
  }
}

//p35    eqs.(31) Siedetemperaturlinie
fileprivate func Ts_p(_ p: Double) -> Double {
  if p >= 611.213e-6 && p <= 22.064 {
    let beta = pow(p, 0.25)
    let temp = beta * beta
    let E = temp + sat[2] * beta + sat[5]
    let F = sat[0] * temp + sat[3] * beta + sat[6]
    let G = sat[1] * temp + sat[4] * beta + sat[7]
    let D = 2 * G / (-sqrt(F * F - 4 * E * G) - F)
    return (sat[9] + D - sqrt((sat[9] + D) * (sat[9] + D) - 4 * (sat[8] + sat[9] * D))) / 2
  } else {
    return 0
  }
}

//p11_book
fileprivate func region_pT(_ p: Double, _ T: Double) -> Int {
  if p < 100 && p > 0 && T <= 1073.15 && T >= ((p >= 16.5292) ? B23_T_p(p) : Ts_p(p)) { return 2 }
  else if T <= 623.15 && T >= 273.15 && p < 100 && p > ps_T(T) { return 1 }
  else if T <= 647.096 && T >= 273.15 && fabs(p - ps_T(T)) < 5e-6 { return 4 }
  else { return 0 }
}

fileprivate func v_pT(_ p: Double, _ T: Double, _ region: Int) -> Double {
  var result: Double = .zero
  switch (region == 0) ? region_pT(p, T) : region {
  case 1:
    //p8
    let pi = p / 16.53
    let tau = 1386 / T
    result = pi * SPECIFIC_GAS_CONSTANT * T * gamma_pi_R1(pi, tau) / p / 1000
  case 2:
    //p15
    let tau = 540 / T
    result = p * (gamma_pi_ideal_R2(p) + gamma_pi_res_R2(p, tau)) * SPECIFIC_GAS_CONSTANT * T / p / 1000
  default: break
  }
  return result
}

fileprivate func s_pT(_ p: Double, _ T: Double, _ region: Int) -> Double {
  switch (region == 0) ? region_pT(p, T) : region {
  case 1:
    //p8
    let pi = p / 16.53
    let tau = 1386 / T
    return SPECIFIC_GAS_CONSTANT * (tau * gamma_tau_R1(pi, tau) - gamma_R1(pi, tau))
  case 2:
    //p15
    let tau = 540 / T
    return SPECIFIC_GAS_CONSTANT * (tau * (gamma_tau_ideal_R2(tau) + gamma_tau_res_R2(p, tau)) - gamma_ideal_R2(p, tau) - gamma_res_R2(p, tau))
  default: return .zero
  }
}

fileprivate func h_pT(_ p: Double, _ T: Double, _ region: Int) -> Double {
  switch (region == 0) ? region_pT(p, T) : region {
  case 1:
    //p8
    let pi = p / 16.53
    let tau = 1386 / T
    return tau * SPECIFIC_GAS_CONSTANT * T * gamma_tau_R1(pi, tau)
  case 2:
    //p15
    let tau = 540 / T
    return SPECIFIC_GAS_CONSTANT * T * tau * (gamma_tau_ideal_R2(tau) + gamma_tau_res_R2(p, tau))
  default: return .zero
  }
}

//p37_book
fileprivate func region_ph(_ p: Double, _ h: Double) -> Int {
  if p < 100 && p >= 0.000611212677 && h >= h_pT(p, 273.15, 1) && h <= ((p >= 16.5292) ? h_pT(p, 623.15, 1) : h_pT(p, Ts_p(p), 1)) { return 1 }
  else if (p >= 0.000611212677 && p <= 16.5292 && h < h_pT(p, Ts_p(p), 2) && h > h_pT(p, Ts_p(p), 1)) || (h < 2563.592 && h > 1670.858 && p > 16.5292 && p < B34_ps_h_eq(h)) { return 4 }
  else if p < 100 && p >= 6.546699678 && h >= ((p >= 16.5292) ? h_pT(p, B23_T_p(p), 2) : h_pT(p, Ts_p(p), 2)) && h < R2_Bbc_h_p(p) { return 23 }
  else if p < 100 && p >= 4 && h <= h_pT(p, 1073.15, 2) && h >= ((p >= 6.546699678) ? R2_Bbc_h_p(p) : h_pT(p, Ts_p(p), 2)) { return 22 }
  else if p < 4 && p >= 0.000611212677 && h <= h_pT(p, 1073.15, 2) && h >= h_pT(p, Ts_p(p), 2) { return 21 } else { return 0 }
}

//p53_book
fileprivate func region_ps(_ p: Double, _ s: Double) -> Int {
  if p < 100 && p >= 0.000611212677 && s >= s_pT(p, 273.15, 1) && s <= ((p >= 16.5292) ? s_pT(p, 623.15, 1) : s_pT(p, Ts_p(p), 1)) { return 1 }
  else if (p >= 0.000611212677 && p <= 16.5292 && s < s_pT(p, Ts_p(p), 2) && s > s_pT(p, Ts_p(p), 1)) || (s < 5.210887825 && s > 3.77828134 && p > 16.5292 && p < B34_ps_s_eq(s)) { return 4 }
  else if p < 100 && p >= 6.5201 && s >= ((p >= 16.5292) ? s_pT(p, B23_T_p(p), 2) : s_pT(p, Ts_p(p), 2)) && s < 5.85 { return 23 }
  else if p < 100 && p >= 4 && s <= s_pT(p, 1073.15, 2) && s >= ((p >= 6.5201) ? 5.85 : s_pT(p, Ts_p(p), 2)) { return 22 }
  else if p < 4 && p >= 0.000611212677 && s <= s_pT(p, 1073.15, 2) && s >= s_pT(p, Ts_p(p), 2) { return 21 } else { return 0 }
}

fileprivate func T_ph(_ p: Double, _ h: Double) -> Double {
  var result: Double = .zero
  switch region_ph(p, h) {
  case 1:
    //p10
    let eta = h / 2500
    for i in 0..<20 { result += R1_back_T_ph[i].2 * pow(p, R1_back_T_ph[i].0) * pow(eta + 1, R1_back_T_ph[i].1) }
  case 21:
    //p22
    let eta = h / 2000
    for i in 0..<34 { result += R2a_back_T_ph[i].2 * pow(p, R2a_back_T_ph[i].0) * pow(eta - 2.1, R2a_back_T_ph[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 22:
    //p23
    let eta = h / 2000
    for i in 0..<38 { result += R2b_back_T_ph[i].2 * pow(p - 2, R2b_back_T_ph[i].0) * pow(eta - 2.6, R2b_back_T_ph[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 23:
    //p23
    let eta = h / 2000
    for i in 0..<23 { result += R2c_back_T_ph[i].2 * pow(p + 25, R2c_back_T_ph[i].0) * pow(eta - 1.8, R2c_back_T_ph[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 4: result = Ts_p(p)
  default: return .zero
  }
  return result

}

fileprivate func T_ps(_ p: Double, _ s: Double) -> Double {
  var result: Double = .zero
  switch region_ps(p, s) {
  case 1:
    //p11
    for i in 0..<20 { result += R1_back_T_ps[i].2 * pow(p, R1_back_T_ps[i].0) * pow(s + 2, R1_back_T_ps[i].1) }
  case 21:
    //p25
    let sigma = s / 2
    for i in 0..<46 { result += R2a_back_T_ps[i].2 * pow(p, R2a_back_T_ps[i].0) * pow(sigma - 2, R2a_back_T_ps[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 22:
    //p26
    let sigma = s / 0.7853
    for i in 0..<44 { result += R2b_back_T_ps[i].2 * pow(p, R2b_back_T_ps[i].0) * pow(10 - sigma, R2b_back_T_ps[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 23:
    //p27
    let sigma = s / 2.9251
    for i in 0..<30 { result += R2c_back_T_ps[i].2 * pow(p, R2c_back_T_ps[i].0) * pow(2 - sigma, R2c_back_T_ps[i].1) }
    if p <= ps_T(623.15) && result < Ts_p(p) { result = Ts_p(p) }
  case 4: result = Ts_p(p)
  default: break
  }
  return result
}

//p152 book
fileprivate func viscosity_ideal(_ theta: Double) -> Double {
  var result: Double = .zero
  for i in 0..<4 {
    result += viscosity_in_the_ideal_gas_limit[i] * pow(theta, Double(-i))
  }
  return sqrt(theta) / result
}

//p152 book
fileprivate func viscosity_second(_ delta: Double, _ theta: Double) -> Double {
  var result: Double = .zero
  for i in 0..<21 { result += viscosity_2[i].2 * pow(delta - 1, viscosity_2[i].0) * pow(1 / theta - 1, viscosity_2[i].1) }
  return exp(delta * result)
}

//p152 book
fileprivate func eta_vT(_ v: Double, _ T: Double) -> Double {
  //bool validity =false
  //if(p>0&&p<0.000611657)
  return viscosity_ideal(T / 647.096) * viscosity_second(1 / v / 322, T / 647.096) * 1e-6
}

