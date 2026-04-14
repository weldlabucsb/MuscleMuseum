# MuscleMuseum

MuscleMuseum is a MATLAB package designed for Atomic, Molecular, and Optical (AMO) physics. It serves as an integrated solution for experimental control, data analysis, and numerical simulation. A complete documentation is [here](https://xiaocasd.github.io/MuscleMuseum/).

## Installation and Setup
1. Install [git](https://git-scm.com/). You are required to know basic git operations.
2. Install MATLAB. **Note: I only tested the code in MATLAB 2023a. MATLAB 2023b or any later version is not compatible with MuscleMuseum because of the database API.**
3. Install the required MATLAB toolboxes:
    * Curve Fitting Toolbox
    * Parallel Computing Toolbox
    * Database Toolbox
    * Image Processing Toolbox
    * Statistics and Machine Learning Toolbox
    * Navigation Toolbox (we just need the `eul2rotm` function)
    * Data Acquisition Toolbox (optional, only for onsite experiments)
    * Instrument Control Toolbox (optional, only for onsite experiments)
4. Install [Python](https://www.python.org/downloads/) whose version is [compatible with your MATLAB version](https://www.mathworks.com/support/requirements/python-compatibility.html). Make sure the Python path is in your environment variable. Check if you can invoke Python by typing `python` in your operation system's command line. **Note: Do not install Python from Microsoft Store.**
5. Install [ARC](https://arc-alkali-rydberg-calculator.readthedocs.io/en/latest/installation.html).
6. Install [PostgreSQL](https://www.postgresql.org/) on your computer. Set up passwords and ports. By default, we use the password `SupermassiveBlackHole` for the super user `postgres`. If you wish to run the database on a server, then install PgSQL on it. You are free to change your database password, but please make sure the credential and port settings are consistent with the `mmConfig.m` file in your `MMUser` folder (see below).   
7. Set up the `MMUser` folder that contains all your user configurations and settings. If you are a Weld Lab member, download the `MMUser` folder using `git clone https://github.com/weldlabucsb/MMUser` into your `Documents` folder (e.g., `/Users/username/Documents`), then checkout to your experiments' branch (e.g., `git checkout li`). If you are not a Weld Lab member, skip this step because a new `MMUser` folder will be generated automatically for you.
8. Download this package. You can do `git clone https://github.com/weldlabucsb/MuscleMuseum`.
9. Start MATLAB and open the main directory of this package.
10. Run `init`. Fix the issues if you see any warnings. If you are not a Weld Lab member and you are a new user, open `/MMUser/config/mmConfig.m` and edit the user configurations as per your needs. 
11. Run `BecBrowser` for reading `BecExp` data. If you are a Weld lab member, you need to map `BananaStand/ANewStart` as `B:\` drive on your computer.
12. Run `BecControlPanel` for BEC experimental control and analysis.
13. Run `HardwareControlPanel` for hardware control.

## Features
- Experimental/Simulation meta data managed by [PostgreSQL](https://www.postgresql.org/)
- BEC experimental control and data analysis system (the BecExp class)
- Apps for controlling and browsing BEC experiments (BecControlPanel and BecBrowser)
- Atomic data and atomic structure handling (the Atom class)
- Single-atom master equation simulation tool (the MeSim class)
- 1D Time-dependent Schrodinger equation (TDSE) simulation tool (the SeSim1D class)
- 1D lattice dynamics simulation tool (the LatticeSeSim1D class)
- Lattice band structure calculations (the OpticalLattice class)
- Keysight/Spectrum AWG generator control
- Siglent/TekTronics scope control
- Vescent phase lock control
- Camera control for Basler, PCO, and Andor
