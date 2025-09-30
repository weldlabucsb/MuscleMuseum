Installation and Setup
========================================================
To use this toolbox:

#. Install MATLAB. I only tested my code with MATLAB 2023a. MATLAB 2023b is not compatible. Required MATLAB packages:
    * Curve Fitting Toolbox
    * Parallel Computing Toolbox
    * Image Processing Toolbox
    * Database Toolbox
    * Data Acquisition Toolbox (optional, only for onsite experiments)
    * Instrument Control Toolbox (optional, only for onsite experiments)
#. Install `Python <https://www.python.org/downloads/>`_ that is `compatible with your MATLAB version <https://www.mathworks.com/support/requirements/python-compatibility.html>`_. Make sure the Python path is in your environment variable. Check if you can invoke Python in command line.  
#. Install `ARC <https://arc-alkali-rydberg-calculator.readthedocs.io/en/latest/installation.html>`_.
#. Install `PostgreSQL <https://www.postgresql.org/>`_. Set up passwords.
#. Download this package. You can do ``git clone https://github.com/weldlabucsb/MuscleMuseum``. 
#. In MATLAB, go to the main directory of this package.
#. At first setup, run ``init``. Fix the issues if you see any warnings.