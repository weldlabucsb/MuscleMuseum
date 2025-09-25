# MuscleMuseum

MuscleMuseum is a MATLAB package designed for Atomic, Molecular, and Optical (AMO) physics. It serves as an integrated solution for experimental control, data analysis, and numerical simulation. The package has several key features:

- **Object-Oriented Programming (OOP):** Unlike traditional script programming in MATLAB, MuscleMuseum is fully OOP-based. This choice is essential for handling the complexity of such projects.

- **Direct Hardware Control:** Leveraging MATLAB's rich set of hardware communication toolboxes, such as the [Data Acquisition Toolbox](https://www.mathworks.com/products/data-acquisition.html), MuscleMuseum provides seamless integration for automatic hardware control.

- **Data Management with PostgreSQL:** MuscleMuseum employs the robust [PostgreSQL](https://www.postgresql.org/) database system for efficient data management. This ensures reliable storage and retrieval of experimental data.

- **User-Friendly GUIs:** The package offers intuitive Graphical User Interfaces (GUIs) developed using [MATLAB App Designer](https://www.mathworks.com/products/matlab/app-designer.html).

Right now, I have implemented:

- A BEC experimental control and data analysis system (the BecExp class)
- Apps for controlling and browsing BEC experiments (BecControlPanel and BecBrowser)
- Atomic data and atomic structure handling (the Atom class)
- A single-atom master equation simulation tool (the MeSim class)
- A 1D Time-dependent Schrodinger equation (TDSE) simulation tool (the SeSim1D class)
- A 1D lattice dynamics simulation tool (the LatticeSeSim1D class)
- Some lattice band structure calculations (the OpticalLattice class)
- Keysight function generator control

Still under construction:

- Gross-Pitaevskii equation simulation
- Spectrum function generator control

Known issues

- The database functions I wrote are not compatible with MATLAB 2023b. I need to fix this in the future.
- The database may not be accessed through VPN for now.

To use this package:
1. Install MATLAB. I only tested my code with MATLAB 2023a. MATLAB 2023b is not compatible. Required MATLAB toolboxes:
    * Curve Fitting Toolbox
    * Parallel Computing Toolbox
    * Database Toolbox
    * Image Processing Toolbox
    * Data Acquisition Toolbox (optional, only for onsite experiments)
    * Instrument Control Toolbox (optional, only for onsite experiments)
2. Install [Python](https://www.python.org/downloads/) that is [compatible with your MATLAB version](https://www.mathworks.com/support/requirements/python-compatibility.html). Make sure the Python path is in your environment variable. Check if you can invoke Python in command line.  
3. Install [ARC](https://arc-alkali-rydberg-calculator.readthedocs.io/en/latest/installation.html)
4. Install [PostgreSQL](https://www.postgresql.org/). Set up passwords
5. Download this package. You can do `git clone https://github.com/weldlabucsb/MuscleMuseum`
6. In MATLAB, go to the main directory of this package.
7. At first setup, run `init`. Fix the issues if you see any warnings.
8. Run `BecControlPanel` for BEC experimental control and analysis
9. Run `BecBrowser` for reading BEC data. You need to map `BananaStand/ANewStart` as `B:\` drive on your computer.


