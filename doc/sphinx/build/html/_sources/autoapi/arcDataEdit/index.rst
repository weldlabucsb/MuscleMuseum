arcDataEdit
===========

.. py:module:: arcDataEdit


Classes
-------

.. autoapisummary::

   arcDataEdit.Lithium7
   arcDataEdit.Strontium84


Functions
---------

.. autoapisummary::

   arcDataEdit.getTransitionFrequencyLithium7
   arcDataEdit.getLandegjExactEdit
   arcDataEdit.getLandegfExactEdit
   arcDataEdit.readLiteratureValuesEdit


Module Contents
---------------

.. py:function:: getTransitionFrequencyLithium7(self, n1, l1, j1, n2, l2, j2, s=0.5, s2=None)

.. py:function:: getLandegjExactEdit(self, l, j, s=0.5)

.. py:function:: getLandegfExactEdit(self, l, j, f, s=0.5)

.. py:class:: Lithium7(preferQuantumDefects=True, cpp_numerov=True)

   Bases: :py:obj:`arc.AlkaliAtom`


   Properties of lithium 7 atoms


   .. py:attribute:: alphaC
      :value: 0.1923


      model potential parameters from [#c1]_




   .. py:attribute:: a1
      :value: [2.47718079, 3.45414648, 2.51909839, 2.51909839]


      model potential parameters from [#c1]_




   .. py:attribute:: a2
      :value: [1.84150932, 2.5515108, 2.4371245, 2.4371245]


      model potential parameters from [#c1]_




   .. py:attribute:: a3

      model potential parameters from [#c1]_




   .. py:attribute:: a4

      model potential parameters from [#c1]_




   .. py:attribute:: rc
      :value: [0.61340824, 0.61566441, 2.34126273, 2.34126273]


      model potential parameters from [#c1]_




   .. py:attribute:: Z
      :value: 3



   .. py:attribute:: I
      :value: 1.5



   .. py:attribute:: NISTdataLevels
      :value: 42



   .. py:attribute:: ionisationEnergy
      :value: 5.391719



   .. py:attribute:: gI
      :value: -0.001182213



   .. py:attribute:: quantumDefect

      quantum defects for :math:`nS` and :math:`nP` states are
      from Ref. [#c6]_. Quantum defects for :math:`D_j` and :math:`F_j`
      states are from [#c7]_.




   .. py:attribute:: levelDataFromNIST
      :value: 'li_NIST_level_data.ascii'



   .. py:attribute:: dipoleMatrixElementFile
      :value: 'li7_dipole_matrix_elements.npy'



   .. py:attribute:: quadrupoleMatrixElementFile
      :value: 'li7_quadrupole_matrix_elements.npy'



   .. py:attribute:: minQuantumDefectN
      :value: 4



   .. py:attribute:: precalculatedDB
      :value: 'li7_precalculated.db'



   .. py:attribute:: literatureDMEfilename
      :value: 'lithium7_literature_dme.csv'



   .. py:attribute:: extraLevels
      :value: []



   .. py:attribute:: groundStateN
      :value: 2



   .. py:attribute:: mass


   .. py:attribute:: abundance
      :value: 0.9241



   .. py:attribute:: gL


   .. py:attribute:: scaledRydbergConstant


   .. py:attribute:: elementName
      :value: 'Li7'



   .. py:attribute:: meltingPoint
      :value: 453.68999999999994



   .. py:attribute:: hyperfineStructureData
      :value: 'li7_hfs_data.csv'



   .. py:method:: getPressure(temperature)

      Pressure of atomic vapour at given temperature (in K).

      Uses equation and values from [#c3]_. Values from table 3.
      (accuracy +-1 %) are used for both liquid and solid phase of Li.




.. py:class:: Strontium84(preferQuantumDefects=True, cpp_numerov=True)

   Bases: :py:obj:`arc.divalent_atom_functions.DivalentAtom`


   Properties of Strontium 84 atoms


   .. py:attribute:: alphaC
      :value: 15



   .. py:attribute:: ionisationEnergy


   .. py:attribute:: Z
      :value: 38



   .. py:attribute:: I
      :value: 0.0



   .. py:attribute:: scaledRydbergConstant


   .. py:attribute:: quantumDefect

      Contains list of modified Rydberg-Ritz coefficients for calculating
      quantum defects for
      [[ :math:`^1S_{0},^1P_{1},^1D_{2},^1F_{3}`],
      [ :math:`^3S_{1},^3P_{0},^3D_{1},^3F_{2}`],
      [ :math:`^3S_{1},^3P_{1},^3D_{2},^3F_{3}`],
      [ :math:`^3S_{1},^3P_{2},^3D_{3},^3F_{4}`]].



   .. py:attribute:: groundStateN
      :value: 5



   .. py:attribute:: extraLevels
      :value: [(4, 2, 3, 1), (4, 2, 1, 1), (4, 3, 3, 0), (4, 3, 4, 1), (4, 3, 3, 1), (4, 3, 2, 1), (4, 2, 2, 0)]



   .. py:attribute:: levelDataFromNIST
      :value: 'sr_level_data.csv'



   .. py:attribute:: precalculatedDB
      :value: 'sr88_precalculated.db'



   .. py:attribute:: dipoleMatrixElementFile
      :value: 'sr_dipole_matrix_elements.npy'



   .. py:attribute:: quadrupoleMatrixElementFile
      :value: 'sr_quadrupole_matrix_elements.npy'



   .. py:attribute:: literatureDMEfilename
      :value: 'strontium_literature_dme.csv'



   .. py:attribute:: elementName
      :value: 'Sr84'



   .. py:attribute:: meltingPoint
      :value: 1050.15



   .. py:attribute:: mass


   .. py:attribute:: defectFittingRange


   .. py:method:: getPressure(temperature)

      Pressure of atomic vapour at given temperature.

      Calculates pressure based on Ref. [#pr]_ (accuracy +- 5%).



.. py:function:: readLiteratureValuesEdit(self)

