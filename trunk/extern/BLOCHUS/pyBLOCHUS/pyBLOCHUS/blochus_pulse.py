# -*- coding: utf-8 -*-
"""
Created on Tue May 26 20:13:33 2020

@author: Hiller.T
"""

from scipy.integrate import solve_ivp
import numpy as np
import numba as nb
from numba import types, carray
import time as timer
import matplotlib.pyplot as plt

from types import SimpleNamespace

from numbalsoda import lsoda_sig, lsoda, dop853, address_as_void_pointer

from blochus_basic import BlochusBasic as basic
from blochus_misc import BlochusMisc as misc

import logging

logger = logging.getLogger(__name__)   

from numba.core.errors import NumbaWarning

import warnings

warnings.simplefilter('ignore', category=NumbaWarning)


@nb.njit(nb.float64[:](nb.float64,nb.float64,nb.float64,nb.float64[:],nb.float64[:],nb.float64[:]))
def _numba_fcn(gamma, T1, T2, M0, b_total, mag):
    """Bloch equation to be solved by the ode-solver."""
    # dM/dt
    dmagdt = gamma *np.cross(mag, b_total) - \
        np.array([mag[0], mag[1], 0.]) / T2 - \
        np.array([0., 0., mag[2] - M0[2]]) / T1
    return dmagdt


def make_lsoda_func(BlochusPulse,m_init):
    larmor_w = BlochusPulse.Pulse.larmor_f*2*np.pi
    T2 = BlochusPulse.T2*1E6
    T1 = BlochusPulse.T2*1E6
    M0z = 1
    gamma = BlochusPulse.gamma
    
    pulse_amp = BlochusPulse.Pulse.factor
    pulse_paramp = BlochusPulse.Pulse.parfactor
    B0 = BlochusPulse.B0
    
    axis_phase = BlochusPulse.Pulse.axis_phase
    ref_phase = BlochusPulse.Pulse.ref_phase
    
    @nb.cfunc(types.void(types.double,
             types.CPointer(types.double),
             types.CPointer(types.double),
             types.CPointer(types.double)))
    def rhs(t, mag, dmagdt, b):
        theta = larmor_w*t
        
        #linpar
        Bx = np.cos(theta + axis_phase + ref_phase)*pulse_amp*B0
        By = 0#-np.cos(larmor_w*t)*pulse_amp*B0
        Bz = B0 + np.cos(theta + axis_phase + ref_phase)*pulse_paramp*B0
        
        dmagdt[0] = gamma * (mag[1]*Bz - mag[2]*By) - mag[0] / T2
        dmagdt[1] = gamma * (mag[2]*Bx - mag[0]*Bz) - mag[1] / T2
        dmagdt[2] = gamma * (mag[0]*By - mag[1]*Bx) - (mag[2]-M0z) / T1
    return rhs


class BlochusPulse(basic):
    """Holds additional routines for excitation pulses."""

    def __init__(self, T1=0.1, T2=0.05, M0=None, B0=5e-5,
                 t_sim=0.01, nucleus='1H'):
        """All attributes of the Basic class are used."""
        super().__init__(T1=T1, T2=T2, M0=M0, B0=B0,
                         t_sim=t_sim, nucleus=nucleus)
        # Pulse parameter class
        self.Pulse = Pulse(B0=B0, gamma=self.gamma, larmor_f=self.larmor_f,
                           t_pulse=t_sim)

    # overwritten larmor_f setter
    @basic.larmor_f.setter
    def larmor_f(self, value):
        """Update larmor frequency and B0."""
        if (value < 0 < self._gamma) or (self._gamma < 0 < value):
            # update basic class attributes
            basic.larmor_f.fset(self, value)
            # update all affected Pulse class attributes
            self.Pulse.larmor_f = value
            self.Pulse.fmod.larmor_f = value
            self.Pulse.B0 = self._B0
            _ = self.Pulse.factor
            _ = self.Pulse.parfactor
        else:
            raise ValueError("Sign of larmor freq. is not correct.")
    
    #ctypes for numba 
    def args_dtype(self):
        args_dtype = types.Record.make_c_struct([
                            ('pulse_factor', types.float64),
                            ('pulse_parfactor', types.float64),
                            ('pulse_axis_phase', types.float64),
                            ('pulse_ref_phase', types.float64),
                            ('pulse_larmor_f', types.float64),
                            ('pulse_t_pulse', types.float64),
                            ('gamma', types.float64),
                            ('B0', types.float64),
                            ('T1', types.float64),
                            ('T2', types.float64),
                            ('larmor_w', types.float64),
                            ('larmor_f', types.float64),
                            ('t_sim', types.float64),
                            ('B_pointer', types.int64),
                            ('B_len', types.int64),
                            ('t_pointer', types.int64),
                            ('t_len', types.int64)])
        return args_dtype
    
    #arguments passed to fastsolve 
    def args(self,B,t):
        array = np.array((
                self.Pulse.factor,
                self.Pulse.parfactor,
                self.Pulse.axis_phase,
                self.Pulse.ref_phase,
                self.Pulse.larmor_f,
                self.Pulse.t_pulse,
                self.gamma,
                self.B0,
                self.T1,
                self.T2,
                self.larmor_w,
                self.larmor_f,
                self.t_sim,
                B.ctypes.data,
                B.shape[0],
                t.ctypes.data,
                t.shape[0]),
                dtype=self.args_dtype())
        return array
    
    def bloch_fcn(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        if time <= self.Pulse.t_pulse:
            # get pulse B-field amplitude
            # the pulse amplitude is just a factor, hence the multiplication
            # with B0 to make it a value in [T]
            bp_amp = self.B0*self.Pulse.get_pulse_amplitude(time)
            # merge both B-fields
            b_total = np.array([bp_amp[0], bp_amp[1], self.B0 + bp_amp[2]])
            # if rdp is off scale the relaxation times and therewith basically
            # switch them off
            if self.Pulse.rdp is True:
                T1 = self.T1
                T2 = self.T2
            else:
                T1 = self.T1*1e6
                T2 = self.T2*1e6
        else:
            # assemble B-field only from B0
            b_total = np.array([0., 0., self.B0])
            T1 = self.T1
            T2 = self.T2

        # dM/dt
        dmagdt = self.gamma * np.cross(mag, b_total) - \
            np.array([mag[0], mag[1], 0.]) / T2 - \
            np.array([0., 0., mag[2] - self.M0[2]]) / T1
        return dmagdt
    
    def bloch_fcn_numba(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        if time <= self.Pulse.t_pulse:
            # get pulse B-field amplitude
            # the pulse amplitude is just a factor, hence the multiplication
            # with B0 to make it a value in [T]
            bp_amp = self.B0*self.Pulse.get_pulse_amplitude(time)
            if self.Pulse.rdp is True:
                T1 = self.T1
                T2 = self.T2
            else:
                T1 = self.T1*1e6
                T2 = self.T2*1e6
        else:
            bp_amp = np.array([0.0, 0.0, 0.0])
            T1 = self.T1
            T2 = self.T2

        b_total = np.array([bp_amp[0], bp_amp[1], self.B0 + bp_amp[2]])

        dmagdt = _numba_fcn(self.gamma, T1, T2, self.M0, b_total, mag)
        return dmagdt

    def solve(self, m_init, info=False, use_numba=False, use_lsoda=False, atol=1e-9, rtol=1e-9):
        """Solve the Bloch equation with scipy 'solve_ivp'.

        Uses ‘RK45’: Explicit Runge-Kutta method of order 5(4) [1].
        The error is controlled assuming accuracy of the fourth-order method,
        but steps are taken using the fifth-order accurate formula (local
        extrapolation is done). A quartic interpolation polynomial is used for
        the dense output [2]. Can be applied in the complex domain.

        References
        ----------
        .. [1] J. R. Dormand, P. J. Prince, “A family of embedded Runge-Kutta
            formulae”, Journal of Computational and Applied Mathematics,
            Vol. 6, No. 1, pp. 19-26, 1980.
        .. [2] L. W. Shampine, “Some Practical Runge-Kutta Formulas”,
            Mathematics of Computation,, Vol. 46, No. 173, pp. 135-150, 1986.
        """
        if use_numba:
            if use_lsoda:
                rhs = make_lsoda_func(self,m_init)
                funcptr = rhs.address
                t_eval = np.linspace(0.0,0.001892425,1000)
                self.solver = SimpleNamespace()
                results,self.solver.success = lsoda(funcptr, m_init, t_eval,rtol=rtol,atol=atol)
                self.solver.y = results.transpose()
                self.solver.t = t_eval
                self.solver.message = 'The lsoda-solver successfully reached the end of the integration interval'
            else:
                self.solver = solve_ivp(self.bloch_fcn_numba, [0, self.t_sim], m_init, rtol=rtol, atol=atol)
        else:
            self.solver = solve_ivp(self.bloch_fcn, [0, self.t_sim], m_init,
                                    rtol=rtol, atol=atol)
        if info:
            print(self.solver.message)
        if self.solver.success:
            self.t = self.solver.t.T
            self.m = self.solver.y
            # transform magnetization into rotating frame of reference
            # therefore calculate the instantaneous phase for all time steps
            # during the pulse
            if self.t_sim > self.Pulse.t_pulse:
                # standard phase
                self.inst_phase = self.larmor_w*self.t
                # auxiliary phase angle = 0
                phi_aux = np.zeros(len(self.t))
                # two logical mask for time steps during pulse (maks1) and
                # time steps after (mask2)
                mask1 = self.t <= self.Pulse.t_pulse
                mask2 = self.t > self.Pulse.t_pulse
                # calculate instantaneous phase during the pulse
                t_pulse = self.t[mask1]
                self.Pulse.fmod.get_modulated_phase(t_now=t_pulse)
                self.inst_phase[mask1] = self.Pulse.fmod.modulated_phase

                # auxiliary phase angle at the end of the pulse is used for
                # all time steps after the pulse
                phi_aux = np.zeros(len(self.t))
                self.Pulse.fmod.get_modulated_phase(t_now=self.Pulse.t_pulse,
                                                    flag=1)
                phi_aux[mask2] = self.Pulse.fmod.modulated_phase

                # now perform rot-frame transformation
                self.calc_m_rot(phi=phi_aux)
                # calculate pulse FFT
                b_pulse = self.Pulse.get_pulse_amplitude(t_pulse)
                freq, spec = misc.get_fft(t_pulse, b_pulse, True)
                self.Pulse.fft_freq = freq
                self.Pulse.fft_spec = spec
            else:
                # perform rot-frame transformation
                self.Pulse.fmod.t_now = self.t
                self.inst_phase = self.Pulse.fmod.modulated_phase
                self.calc_m_rot()
                # calculate pulse FFT
                b_pulse = self.Pulse.get_pulse_amplitude(self.t)
                freq, spec = misc.get_fft(self.t, b_pulse[0:2,:], True)
                self.Pulse.fft_freq = freq
                self.Pulse.fft_spec = spec

            # calculate FFT of lab-frame magnetization
            freq, spec = misc.get_fft(self.t, self.m[[0, 1], :], True)
            self.fft_freq = freq
            self.fft_spec = spec
        else:
            raise ValueError("Something went south during integration.")

    def calc_plot_features(self):
        """Calculate all relevant pulse parameter for plotting."""
        # either use the time steps from the solver
        if self.t is not None:
            mask = self.t <= self.Pulse.t_pulse
            time = self.t[mask]
        else:
            # or create dummy time vector
            fsamp = 64e3  # 64 kHz sampling
            time = np.linspace(0, self.Pulse.t_pulse,
                               int(self.Pulse.t_pulse*fsamp))
        # prepare plot variables
        bp_amp = np.zeros((2, len(time)))
        freq = np.zeros(len(time))
        current = np.zeros(len(time))

        for i in np.arange(0, len(time)):
            # get the PP B-field amplitude
            bp_amp[:, i] = self.Pulse.get_pulse_amplitude(time[i])
            # frequency modulation
            freq[i] = self.Pulse.fmod.modulated_df
            # current modulation
            current[i] = self.Pulse.imod.modulated_i

        self.Pulse.plot_t = time*1e3  # in [ms]
        self.Pulse.plot_pulse = bp_amp
        self.Pulse.plot_freq = freq
        self.Pulse.plot_current = current

    def plot_pulse_all(self):
        """Plot all Pulse components."""
        fig = plt.figure(figsize=(8, 6))
        # create axes all four axes
        ax1 = fig.add_subplot(321)
        ax2 = fig.add_subplot(322)
        ax3 = fig.add_subplot(312)
        ax4 = fig.add_subplot(313)

        # plot the different ramp parameter into the axes
        self.plot_pulse_modulation_single(axis=ax1, version='freq')
        self.plot_pulse_modulation_single(axis=ax2, version='current')
        self.plot_pulse_amplitude(axis=ax3)
        self.plot_fft(axis=ax4, version='pulse')

        # adjust axes position
        low, bot, wid, hei = ax1.get_position().bounds
        ax1.set_position([low*0.9, bot*1.12, wid, hei*0.95])
        low, bot, wid, hei = ax2.get_position().bounds
        ax2.set_position([low*1.05, bot*1.12, wid, hei*0.95])
        low, bot, wid, hei = ax3.get_position().bounds
        ax3.set_position([low*0.9, bot*1.1, wid*1.05, hei*0.9])
        low, bot, wid, hei = ax4.get_position().bounds
        ax4.set_position([low*0.9, bot*0.9, wid*1.05, hei*0.9])

        # adjust titles
        ax1.set_title('frequency modulation')
        ax2.set_title('current modulation')
        ax3.set_title('pulse amplitude')
        ax4.set_title('pulse spectrum')

    def plot_pulse_modulation_single(self, axis=None, version='freq'):
        """Plot pulse modulation."""
        # update the plot data
        self.calc_plot_features()
        # switch between different parameter
        if version == 'freq':
            value = self.Pulse.plot_freq
            ylabel = 'modulated freq [Hz]'
        elif version == 'current':
            value = self.Pulse.plot_current
            ylabel = r'modulated current [$I_0$]'
        else:
            raise NotImplementedError("This plot type is not supported.")

        # calculate ylims
        y_range = np.max(value) - np.min(value)
        if y_range == 0.:  # if min==max
            y_range = 20
        ymin = np.min(value)-y_range/20
        ymax = np.max(value)+y_range/20

        # define color
        pulsec = (100/255, 149/255, 237/255)

        # time already in [ms]
        time = self.Pulse.plot_t
        # if no axes handle was given create figure
        if axis is None:
            fig = plt.figure(figsize=(6, 5))
            # create axes
            axis = fig.add_subplot(111)

        axis.plot(time, value, color=pulsec, label=version)
        axis.set_xlabel('time [ms]')
        axis.set_ylabel(ylabel)
        axis.set_xlim(0, self.Pulse.t_pulse*1e3)
        axis.set_ylim(ymin, ymax)
        axis.grid(color='lightgray')
        return axis

    def plot_pulse_amplitude(self, axis=None):
        """Plot pulse amplitude."""
        # update the plot data
        self.calc_plot_features()
        # switch between different parameter
        value = self.Pulse.plot_pulse
        ylabel = r'B1 [$B_0$]'

        # calculate ylims
        y_range = np.max(value) - np.min(value)
        if y_range == 0.:  # if min==max
            y_range = 20
        ymin = np.min(value)-y_range/20
        ymax = np.max(value)+y_range/20

        # time already in [ms]
        time = self.Pulse.plot_t
        # if no axes handle was given create figure
        if axis is None:
            fig = plt.figure(figsize=(6, 5))
            # create axes
            axis = fig.add_subplot(111)

        axis.plot(time, value[0, :], color='r', label='x')
        axis.plot(time, value[1, :], color='g', label='y')
        axis.set_xlabel('time [ms]')
        axis.set_ylabel(ylabel)
        axis.set_xlim(0, self.Pulse.t_pulse*1e3)
        axis.set_ylim(ymin, ymax)
        axis.grid(color='lightgray')
        return axis


class Pulse:
    """Holds excitation pulse parameter."""

    def __init__(self, B0, gamma, larmor_f, t_pulse=0.01):
        # pulse type [string]
        self.pulse_type = 'pihalf'
        # pulse axis [string]
        self.axis = '+x'
        # pulse axis phase angle [rad]
        self.axis_phase = 0
        # pulse polarization [string]
        self.polarization = 'circ'
        # pulse discretization [string]
        self.discretization = 'cont'
        # relaxation during pulse [logical]
        self.rdp = False
        # Earth's magnetic field in [T]
        self.B0 = B0
        # LGyromagnetic ratio in [rad/s/T]
        self.gamma = gamma
        # Larmor frequency [Hz]
        self.larmor_f = larmor_f
        # pulse length [s]
        self.t_pulse = t_pulse
        # pulse B-field amplitude in units of [B0]
        self._factor = self.factor
        # pulse B-field amplitude parallel to z in units of [B0]
        self._parfactor = 0
        # reference phase due to sign of gyromagnetic ratio [rad]
        self._ref_phase = self.ref_phase  # np.pi
        # frequency modulation
        self.fmod = ModulationFreq(larmor_f=larmor_f, t_end=t_pulse)
        # current modulation
        self.imod = ModulationCurrent(t_end=t_pulse)
        # FFT frequencies
        self.fft_freq = None
        # FFT amplitudes
        self.fft_spec = None
        # plot data which is calculated later (only when needed)
        self.plot_t = None
        self.plot_pulse = None
        self.plot_freq = None
        self.plot_current = None

    def __str__(self):
        """Magic str method for the Pulse class."""
        string = '{}\n'.format(self.__class__)
        string += 'Type: "{}"\n'.format(self.pulse_type)
        string += 'Axis: "{}"\n'.format(self.axis)
        string += 'Polarization: "{}"\n'.format(self.polarization)
        string += 'Discretization: "{}"\n'.format(self.discretization)
        string += 'RDP: {}\n'.format(self.rdp)
        string += 'gamma: {:.3e} [rad/s/T]\n'.format(self.gamma)
        string += 'B0: {} [T]\n'.format(self.B0)
        string += 'Larmor_f: {} [Hz]\n'.format(self.larmor_f)
        string += 'B1 Factor: {} [B0]\n'.format(self._factor)
        string += 'B1 parFactor: {} [B0]\n'.format(self._parfactor)
        string += 't_pulse: {} [s]\n'.format(self.t_pulse)
        return string

    # pulse_type getter/setter
    @property
    def pulse_type(self):
        """Pulse type."""
        return self._pulse_type

    @pulse_type.setter
    def pulse_type(self, value):
        if value in {'pi', 'pihalf', 'free', 'AHP'}:
            self._pulse_type = value
        else:
            raise NotImplementedError('Pulse type "{}" not implemented.'
                                      .format(value))

    # axis getter/setter
    @property
    def axis(self):
        """Pulse axis orientation."""
        return self._axis

    @axis.setter
    def axis(self, value):
        if value in {'+x', '-x', '+y', '-y'}:
            self._axis = value
            if self._axis == '+x':
                self.axis_phase = 0
            elif self._axis == '+y':
                self.axis_phase = np.pi/2.0
            elif self._axis == '-x':
                self.axis_phase = np.pi
            elif self._axis == '-y':
                self.axis_phase = 3.0*np.pi/2.0
        else:
            raise NotImplementedError('Axis "{}" not implemented.'
                                      .format(value))

    # discretization getter/setter
    @property
    def discretization(self):
        """Pulse type."""
        return self._discretization

    @discretization.setter
    def discretization(self, value):
        if value in {'cont', 'disc'}:
            self._discretization = value
        else:
            raise NotImplementedError('Discretization "{}" not implemented.'
                                      .format(value))

    # polarization getter/setter
    @property
    def polarization(self):
        """Pulse type."""
        return self._polarization

    @polarization.setter
    def polarization(self, value):
        if value in {'circ', 'lin', 'linpar'}:
            self._polarization = value
        else:
            raise NotImplementedError('Polarization "{}" not implemented.'
                                      .format(value))

    # ref_phase getter
    @property
    def ref_phase(self):
        """Calculate reference phase due to sign of gyromagnetic ratio."""
        if self.larmor_f < 0:  # and hence gamma is positive
            self._ref_phase = np.pi
        else:  # gamma is negative
            self._ref_phase = 0
        return self._ref_phase

    # factor getter/setter
    @property
    def factor(self):
        """Pulse B-field factor."""
        if self.pulse_type == 'pi':
            self._factor = np.abs(np.pi/self.gamma/self.B0/self.t_pulse)
        elif self.pulse_type == 'pihalf':
            self._factor = np.abs(np.pi/2.0/self.gamma/self.B0/self.t_pulse)
        return self._factor

    @factor.setter
    def factor(self, value):
        if self.pulse_type in {'free', 'AHP'}:
            self._factor = value
        else:
            err_str = 'B1 factor cannot be set freely with the '
            err_str += 'current pulse type "{}".'.format(self.pulse_type)
            raise ValueError(err_str)
    
    # parfactor getter/setter
    @property
    def parfactor(self):
        """Pulse B-field factor parallel."""
        return self._parfactor   
         
    @parfactor.setter
    def parfactor(self, value):
        self._parfactor = value
        
    def get_pulse_amplitude(self, time):
        """Calculate B-field amplitude during pulse."""
        # check if time < t_pulse
        if np.any(time > self.t_pulse):
            raise ValueError('t must be smaller than t_pulse.')

        if self.discretization == 'cont':
            # pulse amplitude in [B0]
            pulse_amp = self.factor
            # pulse amplitude parallel to z in [B0]
            pulse_paramp = self.parfactor
            # trigger frequency modulation at current time step
            self.fmod.t_now = time
            freq_offset = self.fmod.modulated_df
            # trigger current modulation at current time step
            self.imod.t_now = time
            current = self.imod.modulated_i
            # apply quality factor if needed
            if self.imod.qual_fac > 0:
                # get line (band) width
                # -> f_L/Q (simple bandwidth for bandpass)
                lwidth = abs(self.larmor_f)/self.imod.qual_fac
                # apply "Breit-Wigner" formula (here already normalized to 1 by
                # multiplying with pi*lwidth)
                ltmp = 1.0 / (((freq_offset+self.imod.qual_fac_df)**2.0 /
                              lwidth**2)+1.0)
                current = current*ltmp
                self.imod.modulated_i = current

            # instantaneous phase due to frequency modulation
            theta = self.fmod.modulated_phase
            # pulse x and y components
            cos_term = np.cos(theta+self.axis_phase+self.ref_phase)
            sin_term = np.sin(theta+self.axis_phase+self.ref_phase)
            if np.isscalar(time): 
                zero_term = 0
            else:
                zero_term = np.zeros(len(theta))
            
            if self.polarization == 'circ':
                bp_amp = 0.5*current*pulse_amp*np.array([cos_term, sin_term, zero_term])
            elif self.polarization == 'lin':
                bp_amp = current*pulse_amp*np.array([cos_term, zero_term, zero_term])
            elif self.polarization == 'linpar':
                bp_amp = current*np.array([pulse_amp*cos_term, zero_term, pulse_paramp*cos_term])
        else:
            bp_amp = np.array([0.0, 0.0, 0.0])
        return bp_amp


class ModulationFreq:
    """Holds pulse frequency modulation parameter."""

    def __init__(self, larmor_f, t_end=0.01):
        # modulation type [string]
        self.mod_type = 'const'
        # Larmor frequency [Hz]
        self.larmor_f = larmor_f
        # time [s]
        self._t_now = -1.
        # time range [s]
        self.t_range = np.array([0., t_end])
        # frequency range [Hz]
        self.v_range = np.array([0., 0.])
        # modulation parameters A and B
        self.mod_ab = np.array([1., 0.])
        # modulated frequency (output) [Hz]
        self._modulated_df = 0.
        # modulated phase (output) [rad]
        self._modulated_phase = 0.

    def __str__(self):
        """Magic str method for the Modulation class."""
        string = '{}\n'.format(self.__class__)
        string += 'Type: "{}"\n'.format(self.mod_type)
        string += 'larmor_f: {} [Hz]\n'.format(self.larmor_f)
        string += 't_now: {} [s]\n'.format(self.t_now)
        string += 't_start: {} [s]\n'.format(self.t_range[0])
        string += 't_end: {} [s]\n'.format(self.t_range[1])
        string += 'DF start: {} [Hz]\n'.format(self.v_range[0])
        string += 'DF end: {} [Hz]\n'.format(self.v_range[1])
        string += 'A: {} [-]\n'.format(self.mod_ab[0])
        string += 'B: {} [-]\n'.format(self.mod_ab[1])
        return string

    # pulse_type getter/setter
    @property
    def mod_type(self):
        """Frequency modulation type."""
        return self._mod_type

    @mod_type.setter
    def mod_type(self, value):
        if value in {'const', 'lin', 'exp', 'free', 'tanhGMR'}:
            self._mod_type = value
        else:
            raise NotImplementedError('Modulation type "{}" not implemented.'
                                      .format(value))

    # t_now getter/setter
    @property
    def t_now(self):
        """Get current time step."""
        return self._t_now

    @t_now.setter
    def t_now(self, value):
        if np.all(value <= self.t_range[1]):
            self._t_now = value
            self.get_modulated_frequency()
            self.get_modulated_phase()
        else:
            raise ValueError('Time step {} out of range.'.format(value))

    # modulated_df getter
    @property
    def modulated_df(self):
        """Modulated frequency."""
        return self._modulated_df

    # modulated_phase getter
    @property
    def modulated_phase(self):
        """Modulated phase."""
        return self._modulated_phase

    def get_modulated_frequency(self):
        """Get modulated frequency."""
        # pulse duration
        tau = self.t_range[1]-self.t_range[0]
        # modulation range
        delta = self.v_range[1]-self.v_range[0]

        if self.mod_type == 'const':
            out = self.v_range[1]
        elif self.mod_type == 'lin':
            out = self.v_range[0]+self.t_now*delta/tau
        elif self.mod_type == 'exp':
            out = self.v_range[1]-delta*np.exp(self.mod_ab[0] *
                                               (-self.t_now/tau))
        elif self.mod_type == 'free':
            # slope parameter
            n_n = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (self.t_now-self.mod_ab[1]*(tau/2)))
            n_0 = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (self.t_range[0]-self.mod_ab[1]*(tau/2)))
            n_1 = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (tau-self.mod_ab[1]*(tau/2)))
            # sign switch (MMP ;-))
            delta = -delta
            out = self.v_range[1] + delta*(1-((n_n-n_0)/(n_1-n_0)))
        elif self.mod_type == 'tanhGMR':
            # (RD: pers. comm. Grunewald 13.10.2016)
            tau = 3.0*self.t_now/tau
            out = self.v_range[0] + delta*np.tanh(tau)

        self._modulated_df = out

    def get_modulated_phase(self, t_now=-1, flag=0):
        """Provide the instantaneous phase of a pulse.

        This is needed for frequency modulated pulses (e.g. AHP) because the
        frequency is actually modulated via the phase
        NOTE: because f = dphi/dt*2pi, the time domain phase is the integral
        of the frequency:
            phi(t) = phi0 + 2pi*int_0^t f(tau) dtau

        this means e.g. for a linear frequency chirp from f0 to f1 like:
            f(t) = k*t + f0, with slope k = (f1-f0)/(t1-t0)

        the instantaneous phase is given as:
            phi(t) = phi0 + 2pi*(k/2*t^2 + f0*t)
        """
        # this check is need because during runtime t_now is set from outside
        # via "self"; but when the run is complete, this function is called
        # again to calculate the inst. phase as it is needed for the rot-frame
        # transformation
        if np.any(t_now < 0):
            t_now = self.t_now

        delta_f = self.v_range[0]-self.v_range[1]
        delta_t = self.t_range[1]-self.t_range[0]
        if self.mod_type == 'const':
            if flag == 0:
                out = (self.larmor_f-self.modulated_df)*2.0*np.pi*t_now
            else:
                out = -self.v_range[1]*2.0*np.pi*t_now
        elif self.mod_type == 'lin':
            k = delta_f/delta_t
            if flag == 0:
                out = 2.0*np.pi*((self.larmor_f-self.v_range[0])*t_now +
                                 k/2*t_now**2)
            else:
                out = -2.0*np.pi*(self.v_range[1]*t_now + k/2*t_now**2)
        elif self.mod_type == 'exp':
            if flag == 0:
                out = 2.0*np.pi*(self.larmor_f*t_now +
                                 (delta_t*delta_f/self.mod_ab[0]) *
                                 np.exp(self.mod_ab[0]*(-t_now/delta_t)))
            else:
                out = 2.0*np.pi*(self.v_range[1]*t_now +
                                 (delta_t*delta_f/self.mod_ab[0]) *
                                 np.exp(self.mod_ab[0]*(-t_now/delta_t)))
        elif self.mod_type == 'free':
            # auxiliary terms for "ease" of readability :-)
            term_a = 2.0*np.pi*self.mod_ab[0]
            term_b = self.mod_ab[1]
            term_c = np.tanh((term_a/self.t_range[1]) *
                             (self.t_range[0]-term_b*(self.t_range[1]/2)))
            term_d = np.tanh((term_a/self.t_range[1]) *
                             (self.t_range[1]-term_b*(self.t_range[1]/2)))
            term_e = self.v_range[1]
            term_f = -delta_f
            # even more auxiliary terms from a combination of the first set
            term1 = term_a*term_b*term_c*term_f*delta_t
            term2 = 2.0*term_f*delta_t * \
                np.log(np.cosh((term_a*(t_now-(term_b*delta_t/2.0)))/delta_t))
            term3 = 2.0*term_a*t_now*(term_c*term_e-term_d*(term_e+term_f))
            term4 = 2.0*term_a*(term_c-term_d)
            if flag == 0:
                out = 2.0*np.pi*(self.larmor_f*t_now +
                                 ((term1+term2+term3)/term4))
            else:
                out = 2.0*np.pi*(self.v_range[1]*t_now +
                                 ((term1+term2+term3)/term4))
        elif self.mod_type == 'tanhGMR':
            if flag == 0:
                out = 2.0*np.pi*((self.larmor_f-self.v_range[0])*t_now +
                                 (delta_t/3)*delta_f *
                                 np.log(np.cosh(3.0*t_now/delta_t)))
            else:
                out = -2.0*np.pi*(self.v_range[0]*t_now -
                                  (delta_t/3)*delta_f *
                                  np.log(np.cosh(3*t_now/delta_t)))

        self._modulated_phase = out


class ModulationCurrent:
    """Holds current modulation parameter."""

    def __init__(self, mod_type='const', t_end=0.01):
        """All attributes of the Basic class are used."""
        # modulation type [string]
        self.mod_type = mod_type
        # time [s]
        self._t_now = -1.
        # time range [s]
        self.t_range = np.array([0., t_end])
        # current range [A]
        self.v_range = np.array([1., 1.])
        # modulation parameters A and B
        self.mod_ab = np.array([1., 0.])
        # quality factor [-]
        self.qual_fac = 0.
        # quality factor off-resonance [Hz]
        self.qual_fac_df = 0.
        # modulated current (output) [A]
        self.modulated_i = 1.

    def __str__(self):
        """Magic str method for the Modulation class."""
        string = '{}\n'.format(self.__class__)
        string += 'Type: "{}"\n'.format(self.mod_type)
        string += 't_now: {} [s]\n'.format(self.t_now)
        string += 't_start: {} [s]\n'.format(self.t_range[0])
        string += 't_end: {} [s]\n'.format(self.t_range[1])
        string += 'I start: {} [A]\n'.format(self.v_range[0])
        string += 'I end: {} [A]\n'.format(self.v_range[1])
        string += 'Q factor: {} [-]\n'.format(self.qual_fac)
        string += 'A: {} [-]\n'.format(self.mod_ab[0])
        string += 'B: {} [-]\n'.format(self.mod_ab[1])
        return string

    # pulse_type getter/setter
    @property
    def mod_type(self):
        """Frequency modulation type."""
        return self._mod_type

    @mod_type.setter
    def mod_type(self, value):
        if value in {'const', 'lin', 'exp', 'free', 'tanhGMR'}:
            self._mod_type = value
        else:
            raise NotImplementedError('Modulation type "{}" not implemented.'
                                      .format(value))

    # t_now getter/setter
    @property
    def t_now(self):
        """Get current time step."""
        return self._t_now

    @t_now.setter
    def t_now(self, value):
        if np.all(value <= self.t_range[1]):
            # update time step
            self._t_now = value
            self.get_modulated_current()
        else:
            raise ValueError('Time step {} out of range.'.format(value))

    def get_modulated_current(self):
        """Get modulated current."""
        # pulse duration
        tau = self.t_range[1]-self.t_range[0]
        # modulation range
        delta = self.v_range[1]-self.v_range[0]

        if self.mod_type == 'const':
            out = self.v_range[1]
        elif self.mod_type == 'lin':
            out = self.v_range[0]+self.t_now*delta/tau
        elif self.mod_type == 'exp':
            out = self.v_range[1]-delta*np.exp(self.mod_ab[0] *
                                               (-self.t_now/tau))
        elif self.mod_type == 'free':
            # slope parameter
            n_n = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (self.t_now-self.mod_ab[1]*(tau/2)))
            n_0 = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (self.t_range[0]-self.mod_ab[1]*(tau/2)))
            n_1 = np.tanh(((2*np.pi*self.mod_ab[0])/tau) *
                          (tau-self.mod_ab[1]*(tau/2)))
            out = self.v_range[0]+delta*(n_n-n_0)/(n_1-n_0)
        elif self.mod_type == 'tanhGMR':
            # (RD: pi is arbitrary.)
            tau = np.pi*self.t_now/tau
            out = self.v_range[0] + delta*np.tanh(tau)

        self.modulated_i = out


if __name__ == '__main__':
    # test case if the class is called directly

    # initialize pulse pyBLOCHUS class with standard values
    Bloch = BlochusPulse3(t_sim=0.08)
    # show different parameter
    print(Bloch)
    print(Bloch.Pulse)
    # solve ode
    start_time = timer.time()
    Bloch.solve(m_init=Bloch.zunit, use_numba=True)
    end_time = timer.time()
    print(end_time-start_time)
    # plot results
    Bloch.plot_magnetization()
    Bloch.plot_magnetization3d()
    Bloch.plot_magnetization(version='rot')
    Bloch.plot_magnetization3d(version='rot')
    Bloch.plot_pulse_all()
