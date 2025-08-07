Waveform and WaveformList
======================================

Waveform
--------------------------------------

The :class:`Waveform` class handles the software generations of waveforms. We define a waveform as a function of time:

.. math::
    \mathrm{Waveform} = f(t),

where :math:`t` represents time. For every concrete subclass of :class:`Waveform`, a
:meth:`TimeFunc` method is provided, which determines the waveform. The output of :meth:`TimeFunc`
is a `function handle <https://www.mathworks.com/help/matlab/function-handles.html>`_ representing
:math:`f(t)`, which takes a one-dimensional array :math:`t` as the input. Once the :meth:`TimeFunc`
method is provided, the samples of the waveform are calculated every time the :attr:`Sample`
property is called. The waveforms defined by the :class:`Waveform` class are all finite with
definite :attr:`StartTime` and :attr:`Duration`. Meanwhile, A :attr:`SamplingRate` must be given by
users or client apps, from which a dependent property  :attr:`TimeStep` is calculated as
:math:`\mathrm{TimeStep} = 1/\mathrm{SamplingRate}`. The figure below demonstrates their
relationship with :attr:`Sample` and waveform function :math:`f(t)`.

.. image:: waveform_duration.svg

We note that :class:`Waveform` itself is an abstract class. Therefore, it must be inherited by a concrete subclass then be 
constructed.  In the following, we give an example of constructing a :class:`SineWave` (as a subclass of :class:`Waveform`)
object:

.. code-block:: matlab 

    sw = SineWave(...
       amplitude = 20,...
       duration = 1000e-3,...
       startTime = 0e-3,...
       frequency = 100); %Set parameters
    sw.Frequency = 150; %Change parameters after construction
    sw.SamplingRate = 1e4; %Change sampling rate

The function handle of the waveform can be obtained by calling the method :meth:`TimeFunc`. Using the function handle, we can build 
the waveform samples:

.. code-block:: matlab 

    swf = sw.TimeFunc; %Extract the function handle
    t = sw.StartTime : sw.TimeStep : sw.EndTime; %Define the time array
    sample = swf(t); %call the function to calculate the samples
    plot(t,sample) %plot the waveform

Alternatively, we can use the built-in dependent property :attr:`Sample` and the :meth:`plot` method:

.. code-block:: matlab 

    sample = sw.Sample; %call the dependent property to calculate the samples
    sw.plot %plot the waveform using the plot method

In order to handle different types of waveforms, we include a few abstract subclasses of :class:`Waveform`, namely 
:class:`PeriodicWaveform`, :class:`PartialPeriodicWaveform`, :class:`ModulatedWaveform`, and :class:`RandomWaveform`. 
Their inheritance relationship is shown in the following class diagram:

.. image:: waveform.svg

PeriodicWaveform
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

PartialPeriodicWaveform
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

ModulatedWaveform
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

RandomWaveform
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

WaveformList
--------------------------------------