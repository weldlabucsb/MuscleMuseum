Manage Cold-atom Experiments Using BecExp
==========================================

The **BecExp** class provides a comprehensive framework for conducting Bose-Einstein condensate (BEC) experiments with real-time data acquisition, analysis, and visualization. Built on the :class:`Trial` foundation, it integrates hardware control, image processing, automated analysis pipelines, and database logging for complete experimental orchestration.

Overview
--------

BecExp serves as the central coordinator for cold-atom experiments, managing:

- **Real-time acquisition**: Camera control and image capture
- **Region of interest (ROI)**: Flexible image analysis regions
- **Analysis pipeline**: Modular, event-driven data processing
- **Hardware integration**: Cicero sequence control and device logging
- **Database persistence**: Automatic data storage and retrieval
- **Visualization**: Real-time figure updates and GUI integration
- **Parameter scanning**: 1D and 2D experimental parameter sweeps

The system is designed for hands-free operation during long experimental sequences while providing comprehensive monitoring and analysis capabilities.

BecExp Architecture
-------------------

.. image:: becexp_architecture.svg
   :width: 100%
   :align: center

Core BecExp Class
-----------------

The :class:`BecExp` class extends :class:`Trial` to provide specialized functionality for cold-atom experiments:

**Essential Components:**

- :attr:`Roi`: Main region of interest for image analysis
- :attr:`SubRoi`: Optional sub-regions for multi-area analysis
- :attr:`Acquisition`: Camera settings and hardware interface
- :attr:`Atom`: Atomic species properties and constants
- :attr:`AnalysisMethod`: Ordered list of analysis modules to execute

**Data Streams:**

- :attr:`CiceroData`: Sequence parameters from Cicero log files
- :attr:`HardwareData`: Device measurements and settings
- :attr:`ScopeData`: Oscilloscope-derived measurements

**Basic Construction:**

.. code-block:: matlab

   % Create BEC experiment with configuration
   becExp = BecExp("MagneticTrap", "BecExpSetting");
   
   % The experiment automatically:
   % 1. Loads atomic species data
   % 2. Configures camera acquisition settings
   % 3. Sets up ROI for image analysis
   % 4. Initializes analysis modules
   % 5. Creates database entries
   % 6. Establishes file monitoring

**Configuration Loading:**

.. code-block:: matlab

   % Load from different configuration sources
   becExp = BecExp("OpticalLattice", "MyCustomConfig");      % Database config
   becExp = BecExp("DipolarGas", configTable);               % Table config
   becExp = BecExp("SpinorBEC", configStruct);              % Struct config

Acquisition System
------------------

**Camera Integration:**

The acquisition system provides seamless camera control:

.. code-block:: matlab

   % Access acquisition settings
   acq = becExp.Acquisition;
   
   % Key properties automatically configured:
   % - ImagePath: Data storage directory
   % - ImageSize: Camera sensor dimensions
   % - ExposureTime: Integration time
   % - ROI: Hardware ROI settings
   % - TriggerMode: External/software triggering

**Automatic vs. Manual Acquisition:**

.. code-block:: matlab

   % Automatic acquisition mode
   becExp.IsAutoAcquire = true;
   becExp.start();  % Begins automatic image capture
   
   % Manual/external acquisition mode  
   becExp.IsAutoAcquire = false;
   becExp.start();  % Monitors for externally saved images

**Image File Management:**

.. code-block:: matlab

   % Standard file naming pattern:
   % run_1_atom.tif   - Atoms + light image
   % run_1_probe.tif  - Probe light only  
   % run_1_bg.tif     - Background (no light)
   
   % Files automatically detected when complete group arrives
   % Triggers NewRunFinished event for analysis

Region of Interest (ROI) System
-------------------------------

**Main ROI Configuration:**

.. code-block:: matlab

   % Configure primary analysis region
   becExp.Roi.Center = [512, 384];      % Pixel coordinates [y, x]
   becExp.Roi.Size = [200, 300];        % [height, width] in pixels
   becExp.Roi.Angle = 0;                % Rotation angle
   
   % ROI automatically applied to all analysis modules

**Sub-ROI Analysis:**

.. code-block:: matlab

   % Multiple analysis regions
   subRoi1 = Roi("Condensate", center=[500, 400], size=[100, 150]);
   subRoi2 = Roi("Thermal", center=[520, 420], size=[150, 200]);
   
   becExp.SubRoi = [subRoi1, subRoi2];
   
   % Analysis automatically performed on all sub-regions

**Dynamic ROI Adjustment:**

.. code-block:: matlab

   % Automatic centering based on previous measurements
   becExp.CloudCenter = [512.3, 384.7];  % From previous fit
   
   % ROI automatically adjusts to follow cloud center

Analysis Pipeline
-----------------

**Modular Analysis System:**

BecExp uses a modular analysis architecture with predefined execution order:

.. code-block:: matlab

   % Configure analysis modules
   becExp.AnalysisMethod = ["Od", "Imaging", "Ad", "DensityFit", "AtomNumber"];
   
   % Analysis modules execute in dependency order:
   % 1. Od: Optical depth calculation
   % 2. Imaging: Image processing and enhancement
   % 3. Ad: Absorption imaging analysis  
   % 4. DensityFit: Gaussian/Thomas-Fermi fitting
   % 5. AtomNumber: Atom counting and statistics

**Analysis Module Details:**

Od (Optical Depth)
^^^^^^^^^^^^^^^^^^

Calculates optical depth from absorption imaging:

.. math::
   \text{OD}(x,y) = -\ln\left(\frac{I_{\text{atom}}(x,y) - I_{\text{bg}}(x,y)}{I_{\text{probe}}(x,y) - I_{\text{bg}}(x,y)}\right)

.. code-block:: matlab

   % Optical depth automatically calculated from image triplets
   % Results stored in becExp.Od.OdData for each run

DensityFit
^^^^^^^^^^

Performs automated density profile fitting:

.. code-block:: matlab

   % Configure fitting method
   becExp.DensityFit.FitMethod = "GaussianFit1D";        % or "BosonicGaussianFit1D"
   
   % Automatic 1D profile fitting in x and y directions
   becExp.DensityFit.buildFit(1:10);  % Fit runs 1-10
   
   % Access fit results
   sigmaX = becExp.DensityFit.getSigmaX();  % Gaussian widths in x
   sigmaY = becExp.DensityFit.getSigmaY();  % Gaussian widths in y

AtomNumber
^^^^^^^^^^

Calculates total atom numbers and statistics:

.. code-block:: matlab

   % Automatic atom number calculation
   % Results include:
   % - Total atom number
   % - Condensate fraction (for bimodal fits)
   % - Statistical uncertainties
   % - Temperature estimates

Experimental Workflow
--------------------

**Complete Experimental Sequence:**

.. code-block:: matlab

   % 1. Setup experiment
   becExp = BecExp("EvaporativeCooling", "StandardBEC");
   becExp.Description = "Magnetic trap evaporation to BEC";
   becExp.NRun = 50;  % 50 evaporation steps
   
   % 2. Configure parameter scan
   becExp.ScannedVariableID = 5;  % Evaporation RF frequency
   becExp.AveragingMethod = "StdErr";
   
   % 3. Start experiment
   becExp.start();
   
   % 4. Monitor progress (automatic)
   % - Images acquired automatically
   % - Analysis runs on each new image set
   % - Figures update in real-time
   % - Database records all results
   
   % 5. Stop and finalize
   becExp.stop();
   becExp.refresh();  % Final analysis pass

**Real-Time Monitoring:**

.. code-block:: matlab

   % Display analysis figures
   becExp.show();  % Show on primary monitor
   becExp.browserShow(2);  % Show browser GUI on monitor 2
   
   % Access real-time data
   currentRun = becExp.NCompletedRun;
   atomNumbers = becExp.AtomNumber.AtomNumberData(1:currentRun);
   temperatures = becExp.Tof.TemperatureData(1:currentRun);

**Parameter Scanning:**

.. code-block:: matlab

   % 1D magnetic field scan
   becExp.ScannedVariableID = 3;  % Magnetic field strength
   fieldValues = linspace(0.5, 5.0, 20);  % 0.5 to 5.0 G
   
   % 2D scan example
   becExp.ScannedVariableID = 3;   % Magnetic field
   becExp.ScannedVariableID2 = 7;  % Hold time
   becExp.Is2dScan = true;
   becExp.NRun = 100;  % 10×10 parameter grid

Hardware Integration
--------------------

**Cicero Sequence Control:**

.. code-block:: matlab

   % Automatic Cicero log processing
   becExp.CiceroLogOrigin = "C:/Cicero/Logs/";
   
   % Log files automatically moved and parsed:
   % - Sequence timing parameters
   % - RF frequencies and powers  
   % - Magnetic field settings
   % - Laser intensities and detunings

**Hardware Device Logging:**

.. code-block:: matlab

   % Configure hardware logging
   becExp.HardwareList = loadHardwareConfig();
   
   % Automatic logging of:
   % - AWG waveform parameters
   % - Lock-in amplifier readings
   % - Temperature controller values
   % - Laser power measurements

**Scope Integration:**

.. code-block:: matlab

   % Oscilloscope data integration
   becExp.ScopeData  % Automatic scope measurement logging
   
   % Common measurements:
   % - Photodiode signals
   % - RF power monitoring
   % - Timing verification
   % - Error signals

Advanced Analysis Features
--------------------------

**Multi-Region Analysis:**

.. code-block:: matlab

   % Define multiple analysis regions
   condensateROI = Roi("Condensate", center=[500, 400], size=[80, 120]);
   thermalROI = Roi("Thermal", center=[500, 400], size=[200, 300]);
   
   becExp.SubRoi = [condensateROI, thermalROI];
   
   % Analysis automatically performed on all regions
   % Results indexed by ROI: becExp.AtomNumber.AtomNumberData{roiIndex}

**Custom Analysis Modules:**

.. code-block:: matlab

   % Add custom analysis to the pipeline
   becExp.addAnalysis("CustomModule");
   
   % Custom modules must inherit from BecAnalysis
   % and implement updateData() and updateFigure()

**Data Export and Visualization:**

.. code-block:: matlab

   % Export results for external analysis
   results = becExp.exportData();
   
   % Generate publication-quality figures
   becExp.generateFigures("publication");
   
   % Save analysis state
   becExp.saveAnalysis();

Error Handling and Recovery
---------------------------

**Robust Data Acquisition:**

.. code-block:: matlab

   % Handle acquisition failures gracefully
   try
       becExp.start();
   catch ME
       becExp.displayLog("Acquisition failed: " + ME.message, "error");
       becExp.fastStop();  % Emergency stop
   end

**Hardware Error Recovery:**

.. code-block:: matlab

   % Monitor hardware status during experiment
   if becExp.checkHardwareStatus()
       becExp.displayLog("All hardware operating normally");
   else
       becExp.displayLog("Hardware error detected", "warning");
       % Implement recovery procedures
   end

**Data Integrity Checking:**

.. code-block:: matlab

   % Validate image data quality
   if becExp.validateImageData(runIndex)
       becExp.processRun(runIndex);
   else
       becExp.displayLog("Bad image data, skipping run " + runIndex, "warning");
   end

Best Practices
--------------

**Experiment Design:**
- Plan appropriate :attr:`NRun` values for statistical significance
- Configure ROI to capture full atomic cloud with margin
- Set reasonable acquisition rates to avoid data bottlenecks

**Analysis Configuration:**
- Enable only necessary analysis modules to improve performance
- Use appropriate averaging methods for your signal-to-noise ratio
- Configure sub-ROIs for detailed spatial analysis

**Hardware Setup:**
- Ensure all hardware devices are properly configured and connected
- Test Cicero sequences before starting long experimental runs
- Verify camera triggering and timing synchronization

**Data Management:**
- Monitor disk space during long experimental sequences
- Implement regular data backup procedures
- Use descriptive trial names and descriptions for future reference

**Performance Optimization:**
- Disable figure updates during acquisition if performance is critical
- Use appropriate image formats and compression
- Configure database connections for your network environment

**Troubleshooting:**
- Use :meth:`fastStop()` for emergency experiment termination
- Check hardware logs for device-specific error messages
- Verify Cicero log parsing for sequence parameter accuracy

The BecExp framework provides a complete solution for modern cold-atom experiments, combining robust hardware control with sophisticated real-time analysis capabilities. Its modular design ensures flexibility while maintaining the reliability required for long-duration experimental sequences.
