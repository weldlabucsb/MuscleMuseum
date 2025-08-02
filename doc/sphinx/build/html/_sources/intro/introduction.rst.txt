Introduction
==========================
**MuscleMuseum** is a object-oriented MATLAB toolbox designed for Atomic, Molecular, and Optical
(AMO) physics. It serves as an integrated solution for experimental control,
data management, data analysis, and numerical simulation. The toolbox has
several key features:

#. Direct Hardware Control: Leveraging MATLAB's rich set of hardware communication toolboxes, such as the `Data Acquisition Toolbox <https://www.mathworks.com/products/data-acquisition.html>`_, MuscleMuseum provides seamless integration for automatic hardware control.
#. Data Management with `PostgreSQL <https://www.postgresql.org/>`_: MuscleMuseum employs the robust PostgreSQL database system for efficient data management. This ensures reliable storage and retrieval of experimental data.
#. User-Friendly GUIs: The package offers intuitive Graphical User Interfaces (GUIs) developed using `MATLAB App Designer <https://www.mathworks.com/products/matlab/app-designer.html>`_.

Right now, I have implemented:

#. :class:`.BecExp`: A BEC experimental control and data analysis system integrated with `Cicero <https://akeshet.github.io/Cicero-Word-Generator/>`_  
#. :app:`.BecControlPanel` & :app:`.BecBrowser`: Apps for controlling and browsing BEC experiments 
#. :class:`.Atom`: Atomic data and atomic structure handling
#. :class:`.MeSim`: A single-atom master equation simulation tool 
#. :class:`.SeSim1D`: A 1D Time-dependent Schrodinger equation (TDSE) simulation tool 
#. :class:`.LatticeSeSim1D`: A 1D lattice dynamics simulation tool 
#. :class:`.OpticalLattice`: Some lattice band structure calculations 
#. :class:`.KeysightWaveformGenerator`: Keysight function generator control

Still under construction:

#. Gross-Pitaevskii equation simulation
#. Scope talk
#. RF generator control

Known issues: the database functions I wrote are not compatible with MATLAB 2023b or higher. I
need to fix this in the future. The database may not be accessed through VPN
for now.