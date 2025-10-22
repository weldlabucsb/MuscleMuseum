classdef Alkali < Atom
    %:class:`Alkali` provides utilities for alkali atoms and D-line transitions.
    %
    % This class extends the base :class:`Atom` class to provide specialized
    % functionality for alkali atoms. On construction, it automatically computes
    % D1 and D2 manifolds, ground and excited state :class:`AtomManifold` objects,
    % and calculates key transition properties including cycling and repumper
    % frequencies, saturation intensities, and absorption cross-sections. The class
    % also provides methods for computing AC Stark shifts and polarizabilities
    % in the large detuning limit.
    %
    % **Example:**
    %
    % .. code-block:: matlab
    %
    %    % Create a lithium-7 atom and access its properties
    %    li = Alkali("Lithium7");
    %    cycFreq = li.CyclerFrequency;           % D2 cycling transition frequency [Hz]
    %    Isat = li.CyclerSaturationIntensity;    % Saturation intensity [W/m^2]
    %    crossSec = li.CyclerCrossSection;       % Absorption cross-section [m^2]
    %
    % **Notes:**
    %
    % The class follows Daniel Steck's conventions for transition matrix elements
    % and uses data from the ARC (Alkali Rydberg Calculator) Python package with
    % custom modifications for improved accuracy.
    
    properties(SetAccess=protected)
        D1 TwoJManifold % D1 line transition manifold: :math:`nS_{1/2} \leftrightarrow nP_{1/2}` with combined ground/excited hyperfine structure
        D2 TwoJManifold % D2 line transition manifold: :math:`nS_{1/2} \leftrightarrow nP_{3/2}` with combined ground/excited hyperfine structure  
        DGround OneJManifold % Ground state manifold: :math:`nS_{1/2}` with hyperfine structure :math:`F,M_F`
        D1Excited OneJManifold % D1 excited state manifold: :math:`nP_{1/2}` with hyperfine structure :math:`F,M_F`
        D2Excited OneJManifold % D2 excited state manifold: :math:`nP_{3/2}` with hyperfine structure :math:`F,M_F`
        Spinor1 OneFManifold % Lower ground hyperfine manifold: :math:`nS_{1/2}, F = |I - J|` with magnetic sublevels :math:`M_F`
        Spinor2 OneFManifold % Upper ground hyperfine manifold: :math:`nS_{1/2}, F = I + J` with magnetic sublevels :math:`M_F`
        CyclerFrequency double % D2 cycling transition frequency :math:`F_g^{\max} \rightarrow F_e^{\max}` at zero field [Hz]
        CyclerSaturationIntensity double % D2 cycling transition saturation intensity :math:`I_{\text{sat}}` [W/m^2]
        CyclerSaturationIntensityLu double % D2 cycling transition saturation intensity :math:`I_{\text{sat}}` [mW/cm^2]
        CyclerCrossSection double % D2 cycling transition resonant absorption cross-section :math:`\sigma_0` [m^2]
        RepumperFrequency double % D2 repumper transition frequency :math:`F_g^{\max-1} \rightarrow F_e^{\max-1}` at zero field [Hz]
        RepumperSaturationIntensity double % D2 repumper transition saturation intensity :math:`I_{\text{sat}}` assuming :math:`\sigma^+` polarization [W/m^2]
        RepumperSaturationIntensityLu double % D2 repumper transition saturation intensity :math:`I_{\text{sat}}` [mW/cm^2]
        RepumperCrossSection double % D2 repumper transition resonant absorption cross-section :math:`\sigma_0` [m^2]
    end
    
    methods
        function obj = Alkali(atomName)
            % Construct an :class:`Alkali` atom and compute D-line manifolds.
            %
            % Creates an alkali atom object, initializes D1/D2 transition manifolds,
            % ground and excited state manifolds, and computes cycling and repumper
            % transition properties including frequencies, saturation intensities,
            % and absorption cross-sections. All calculations are performed at zero
            % magnetic field.
            %
            % :param atomName: Atom/isotope name recognized by ARC, e.g., "Lithium7", "Rubidium87"
            % :type atomName: string

            %% Set atomic properties
            obj@Atom(atomName)
            if obj.Type ~= "Alkali"
                error("Wrong input. [atomName] must be an alkali atom")
            end

            %% Set transition properties
            nG = obj.groundStateN;
            obj.D1 = TwoJManifold(obj,nG,0,1/2,nG,1,1/2);
            obj.D2 = TwoJManifold(obj,nG,0,1/2,nG,1,3/2);
            obj.DGround = OneJManifold(obj,nG,0,1/2);
            obj.D1Excited = OneJManifold(obj,nG,1,1/2);
            obj.D2Excited = OneJManifold(obj,nG,1,3/2);
            FGround = totalAngularMomentum(1/2,obj.I);
            obj.Spinor1 = OneFManifold(obj,nG,0,1/2,min(FGround));
            obj.Spinor2 = OneFManifold(obj,nG,0,1/2,max(FGround));

            %% Set cycler and repumper properties
            fG = obj.D2.FGround;
            fE = obj.D2.FExcited;
            eG = obj.D2.EnergyGround;
            eE = obj.D2.EnergyExcited;
            obj.CyclerFrequency = eE(fE==max(fE)) - eG(fG==max(fG));
            obj.RepumperFrequency = eE(fE==(max(fE)-1)) - eG(fG==(max(fG)-1));
            obj.CyclerSaturationIntensity = obj.D2.SaturationIntensity(max(fG),max(fG),max(fE),max(fE));
            obj.CyclerSaturationIntensityLu = obj.CyclerSaturationIntensity / 10;
            obj.CyclerCrossSection = ...
                Constants.SI("hbar") * (2*pi*obj.CyclerFrequency) *...
                (obj.D2.NaturalLinewidth * 2 * pi) / 2 / obj.CyclerSaturationIntensity;
            obj.RepumperSaturationIntensity = obj.D2.SaturationIntensity(max(fG)-1,max(fG)-1,max(fE)-1,max(fE)-1);
            obj.RepumperSaturationIntensityLu = obj.RepumperSaturationIntensity / 10;
            obj.RepumperCrossSection = ...
                Constants.SI("hbar") * (2*pi*obj.RepumperFrequency) *...
                (obj.D2.NaturalLinewidth * 2 * pi) / 2 / obj.RepumperSaturationIntensity;

        end

        function alpha0 = ScalarPolarizabilityLargeDetuning(obj,fL,n,l,j)
            % Compute scalar polarizability for large detuning limit.
            %
            % Calculates the scalar polarizability :math:`\alpha_0` in the limit where
            % the laser detuning is much larger than the hyperfine splitting. Uses
            % Steck's formulation (Eq. 7.491) with contributions from both D1 and D2
            % transitions for ground states, and single-line contributions for excited states.
            %
            % :param fL: Laser frequency [Hz]
            % :type fL: double
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum quantum number
            % :type l: int32  
            % :param j: Total electronic angular momentum quantum number
            % :type j: double
            % :return: Scalar polarizability :math:`\alpha_0` [Hz/(V/m)^2]
            % :rtype: double
            %
            % **Notes:**
            %
            % The polarizability is computed using:
            %
            % .. math::
            %
            %    \alpha_0 = \frac{2}{3\hbar} \sum_e \frac{\omega_e |\langle g \| d \| e \rangle|^2}{\omega_e^2 - \omega_L^2}
            %
            % where the sum runs over allowed electric dipole transitions.

            hbar = Constants.SI("hbar");
            omegaL = 2 * pi * fL;
            nG = obj.groundStateN;
            omegaD1 = 2 * pi * obj.D1.Frequency;
            omegaD2 = 2 * pi * obj.D2.Frequency;
            dipoleD1 = obj.D1.ReducedDipoleMatrixElement;
            dipoleD2 = obj.D2.ReducedDipoleMatrixElement;
            if n == nG && l == 0 && j == 1/2
                alpha0 = 2/3/hbar * (omegaD1 * abs(dipoleD1)^2 / (omegaD1^2 - omegaL^2) +...
                    omegaD2 * abs(dipoleD2)^2 / (omegaD2^2 - omegaL^2));
            elseif n == nG && l == 1 && j == 1/2
                alpha0 = - 2/3/hbar * omegaD1 * abs(dipoleD1)^2 / (omegaD1^2 - omegaL^2);
            elseif n == nG && l == 1 && j == 3/2
                alpha0 = - 2/3/hbar * omegaD2 * abs(dipoleD2)^2 / (omegaD2^2 - omegaL^2);
                alpha0 = alpha0 * ((-1)^(j - 1/2) * sqrt((2 * 1/2 + 1) / ( 2 * j + 1)))^2; % To conjugate the dipole matrix element
            else
                % Rydberg calculation not implemented yet
                error("Wrong input state quantum numbers.")
            end
            alpha0 = alpha0 / hbar / 2 / pi; % Change unit to Hz/(V/m)^2
        end

        function alpha1 = VectorPolarizabilityLargeDetuning(obj,fL,n,l,j,f)
            % Compute vector polarizability for large detuning limit.
            %
            % Calculates the vector polarizability :math:`\alpha_1` in the limit where
            % the laser detuning is much larger than the hyperfine splitting. Uses
            % Steck's formulation (Eq. 7.491) with Wigner 6j symbols to account for
            % hyperfine coupling. Returns zero for :math:`F=0` states.
            %
            % :param fL: Laser frequency [Hz]
            % :type fL: double
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum quantum number
            % :type l: int32  
            % :param j: Total electronic angular momentum quantum number
            % :type j: double
            % :param f: Total hyperfine angular momentum quantum number
            % :type f: double
            % :return: Vector polarizability :math:`\alpha_1` [Hz/(V/m)^2]
            % :rtype: double
            %
            % **Notes:**
            %
            % The vector polarizability contributes to Zeeman shifts proportional to
            % :math:`M_F` and couples electronic and nuclear angular momenta through
            % the hyperfine interaction.

            if f == 0
                alpha1 = 0;
                return
            end

            hbar = Constants.SI("hbar");
            omegaL = 2 * pi * fL;
            nG = obj.groundStateN;
            I = obj.I;
            omegaD1 = 2 * pi * obj.D1.Frequency;
            omegaD2 = 2 * pi * obj.D2.Frequency;
            dipoleD1 = obj.D1.ReducedDipoleMatrixElement;
            dipoleD2 = obj.D2.ReducedDipoleMatrixElement;
            if n == nG && l == 0 && j == 1/2
                jList = [1/2,3/2];
                omegaList = [omegaD1,omegaD2];
                dipoleList = [dipoleD1,dipoleD2];
                alpha1 = 0;
                for jj = 1:numel(jList)
                    alpha1 = alpha1 + (-1)^(-2 * j - jList(jj) - f - I + 1) * ...
                        sqrt(6 * f * (2 * f + 1) / (f + 1)) * (2 * j + 1) *...
                        omegaList(jj) * abs(dipoleList(jj))^2 / hbar / ...
                        (omegaList(jj)^2 - omegaL^2) * ...
                        wignersixj(1,1,1,j,j,jList(jj)) * wignersixj(j,j,1,f,f,I);
                end
            elseif n == nG && l == 1 && j == 1/2
                alpha1 =  - (-1)^(-2 * j - 1/2 - f - I + 1) * ...
                        sqrt(6 * f * (2 * f + 1) / (f + 1)) * (2 * j + 1) *...
                        omegaD1 * abs(dipoleD1)^2 / hbar / ...
                        (omegaD1^2 - omegaL^2) * ...
                        wignersixj(1,1,1,j,j,1/2) * wignersixj(j,j,1,f,f,I);
            elseif n == nG && l == 1 && j == 3/2
                alpha1 =  - (-1)^(-2 * j - 1/2 - f - I + 1) * ...
                    sqrt(6 * f * (2 * f + 1) / (f + 1)) * (2 * j + 1) *...
                    omegaD2 * abs(dipoleD2)^2 / hbar / ...
                    (omegaD2^2 - omegaL^2) * ...
                    wignersixj(1,1,1,j,j,1/2) * wignersixj(j,j,1,f,f,I);
                alpha1 = alpha1 * ((-1)^(j - 1/2) * sqrt((2 * 1/2 + 1) / ( 2 * j + 1)))^2; % To conjugate the dipole matrix element
            else
                % Rydberg calculation not implemented yet
                error("Wrong input state quantum numbers.")
            end
            alpha1 = alpha1 / hbar / 2 / pi; % Change unit to Hz/(V/m)^2
        end

        function alpha2 = TensorPolarizabilityLargeDetuning(obj,fL,n,l,j,f)
            % Compute tensor polarizability for large detuning limit.
            %
            % Calculates the tensor polarizability :math:`\alpha_2` in the limit where
            % the laser detuning is much larger than the hyperfine splitting. Uses
            % Steck's formulation (Eq. 7.491) with Wigner 6j symbols. Returns zero
            % for :math:`F=0` or :math:`F=1/2` states.
            %
            % :param fL: Laser frequency [Hz]
            % :type fL: double
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum quantum number
            % :type l: int32  
            % :param j: Total electronic angular momentum quantum number
            % :type j: double
            % :param f: Total hyperfine angular momentum quantum number
            % :type f: double
            % :return: Tensor polarizability :math:`\alpha_2` [Hz/(V/m)^2]
            % :rtype: double
            %
            % **Notes:**
            %
            % The tensor polarizability contributes to quadratic Zeeman shifts
            % proportional to :math:`(3M_F^2 - F(F+1))` and is responsible for
            % differential light shifts between magnetic sublevels.
            if f == 0 || f == 1/2
                alpha2 = 0;
                return
            end

            hbar = Constants.SI("hbar");
            omegaL = 2 * pi * fL;
            nG = obj.groundStateN;
            I = obj.I;
            omegaD1 = 2 * pi * obj.D1.Frequency;
            omegaD2 = 2 * pi * obj.D2.Frequency;
            dipoleD1 = obj.D1.ReducedDipoleMatrixElement;
            dipoleD2 = obj.D2.ReducedDipoleMatrixElement;
            if n == nG && l == 0 && j == 1/2
                jList = [1/2,3/2];
                omegaList = [omegaD1,omegaD2];
                dipoleList = [dipoleD1,dipoleD2];
                alpha2 = 0;
                for jj = 1:numel(jList)
                    alpha2 = alpha2 + (-1)^(-2 * j - jList(jj) - f - I) * ...
                        sqrt(40 * f * (2 * f + 1)  * (2 * f - 1) / 3 / (f + 1) / (2*f + 3)) * (2 * j + 1) *...
                        omegaList(jj) * abs(dipoleList(jj))^2 / hbar / ...
                        (omegaList(jj)^2 - omegaL^2) * ...
                        wignersixj(1,1,2,j,j,jList(jj)) * wignersixj(j,j,2,f,f,I);
                end
            elseif n == nG && l == 1 && j == 1/2
                alpha2 =  - (-1)^(-2 * j - 1/2 - f - I) * ...
                    sqrt(40 * f * (2 * f + 1)  * (2 * f - 1) / 3 / (f + 1) / (2*f + 3)) * (2 * j + 1) *...
                    omegaD1 * abs(dipoleD1)^2 / hbar / ...
                    (omegaD1^2 - omegaL^2) * ...
                    wignersixj(1,1,2,j,j,1/2) * wignersixj(j,j,2,f,f,I);
            elseif n == nG && l == 1 && j == 3/2
                alpha2 =  - (-1)^(-2 * j - 1/2 - f - I) * ...
                    sqrt(40 * f * (2 * f + 1)  * (2 * f - 1) / 3 / (f + 1) / (2*f + 3)) * (2 * j + 1) *...
                    omegaD2 * abs(dipoleD2)^2 / hbar / ...
                    (omegaD2^2 - omegaL^2) * ...
                    wignersixj(1,1,2,j,j,1/2) * wignersixj(j,j,2,f,f,I);
                alpha2 = alpha2 * ((-1)^(j - 1/2) * sqrt((2 * 1/2 + 1) / ( 2 * j + 1)))^2; % To conjugate the dipole matrix element
            else
                % Rydberg calculation not implemented yet
                error("Wrong input state quantum numbers.")
            end
            alpha2 = alpha2 / hbar / 2 / pi; % Change unit to Hz/(V/m)^2
        end
    
        function deltaE = AcStarkShiftLargeDetuning(obj,laser,n,l,j,f,mF,qAxisAngle)
            % Compute total AC Stark shift for a hyperfine state.
            %
            % Calculates the complete AC Stark shift including scalar, vector, and
            % tensor contributions for a given hyperfine state in the presence of
            % a laser field. The calculation is valid in the large detuning limit
            % where the detuning is much larger than the hyperfine splitting.
            %
            % :param laser: :class:`Laser` object specifying field parameters
            % :type laser: Laser
            % :param n: Principal quantum number
            % :type n: int32
            % :param l: Orbital angular momentum quantum number
            % :type l: int32
            % :param j: Total electronic angular momentum quantum number
            % :type j: double
            % :param f: Total hyperfine angular momentum quantum number
            % :type f: double
            % :param mF: Magnetic sublevel quantum number
            % :type mF: double
            % :param qAxisAngle: Quantization axis spherical angles :math:`[\theta,\phi]` [rad] (default: laser direction)
            % :type qAxisAngle: double(1,2), optional
            % :return: Total AC Stark shift :math:`\Delta E` [Hz]
            % :rtype: double
            %
            % **Notes:**
            %
            % The total shift is: :math:`\Delta E = \Delta E_0 + \Delta E_1 + \Delta E_2`
            % where :math:`\Delta E_0` is the scalar shift, :math:`\Delta E_1` is the
            % vector shift proportional to :math:`M_F`, and :math:`\Delta E_2` is the
            % tensor shift proportional to :math:`(3M_F^2 - F(F+1))`.
            arguments
                obj
                laser (1,1) Laser
                n int32
                l int32
                j double
                f double
                mF double
                qAxisAngle double = []  % Quantization axis spherical angles :math:`[\theta,\phi]` [rad]
            end

            oldAngle = laser.Angle;
            if isempty(qAxisAngle)
                % if the quantization axis is not given, use the laser axis
                % as the quantization axis z
                laser.rotateToAngle([0,0]);
            else
                % if the quantization axis is given, rotate it to the z
                % axis. Then rotate the laser accordingly.
                rotm = eul2rotm([0,0,0],"ZYZ") * ...
                    (eul2rotm([qAxisAngle(2),qAxisAngle(1),0],"ZYZ"))^(-1);
                dir = laser.Direction;
                dir = dir(:);
                dir = rotm * dir;
                laser.Direction = reshape(dir,size(laser.Direction));
                pol = laser.Polarization;
                pol = pol(:);
                pol = rotm * pol;
                laser.Polarization = reshape(pol,size(laser.Polarization));
            end

            fL = laser.Frequency;
            pol = laser.Polarization;
            E = laser.ElectricFieldAmplitude;
            EPlus = E / 2 * conj(pol); % The definition of polarization is different from Steck
            EMinus = E / 2 * pol;
            cp = 1i * cross(EMinus,EPlus);
            alpha0 = obj.ScalarPolarizabilityLargeDetuning(fL,n,l,j);
            alpha1 = obj.VectorPolarizabilityLargeDetuning(fL,n,l,j,f);
            alpha2 = obj.TensorPolarizabilityLargeDetuning(fL,n,l,j,f);
            deltaE0 = -alpha0 * abs(E)^2 / 4;
            if f == 0
                deltaE1 = 0;
            else
                deltaE1 = - alpha1 * cp(3) * mF / f;
            end
            if f == 0 || f == 1/2
                deltaE2 = 0;
            else
                deltaE2 = - alpha2 * (3 * abs(EPlus(3))^2 - abs(E)^2 / 4) / 2 * ...
                (3 * mF ^ 2 - f * (f + 1)) / f / (2 * f - 1);
            end
            deltaE = deltaE0 + deltaE1 + deltaE2;

            % reset laser angle
            laser.rotateToAngle(oldAngle);
        end
    end

end

