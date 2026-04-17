# -*- coding: utf-8 -*-
"""
Created on Tue May 26 20:16:10 2020

@author: Hiller.T
"""

import numpy as np
import numba as nb
import time as timer
from scipy.integrate import solve_ivp
import matplotlib.pyplot as plt

from blochus_basic import BlochusBasic as basic
from blochus_misc import BlochusMisc as misc


@nb.jit
def _numba_fcn(gamma, T1, T2, M0, b_total, mag):
    """Bloch equation to be solved by the ode-solver."""
    # dM/dt
    dmagdt = gamma * np.cross(mag, b_total) - \
        np.array([mag[0], mag[1], 0.]) / T2 - \
        np.array([0., 0., mag[2] - M0[2]]) / T1
    return dmagdt


class BlochusPrepol(basic):
    """Holds additional routines for pre-polarization switch-off ramps."""

    def __init__(self, T1=0.1, T2=0.05, M0=None, B0=5e-5,
                 t_sim=0.01, nucleus='1H'):
        """All attributes of the Basic class are used."""
        super().__init__(T1=T1, T2=T2, M0=M0, B0=B0,
                         t_sim=t_sim, nucleus=nucleus)
        # Ramp parameter class
        self.Ramp = Ramp(t_ramp=t_sim)

    def bloch_fcn(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        if time <= self.Ramp.t_ramp:
            # get PP B-field amplitude
            # the Ramp amplitude is just a factor, hence the multiplication
            # with B0 to make it a value in [T]
            bp_amp = self.B0*self.Ramp.get_ramp_amplitude(time)
            # Earth's magnetic field B0
            b_earth = np.array([0., 0., self.B0])
            # PP magnetic field is the Bp amplitude times the orientation
            # vector
            b_prepol = bp_amp * self.Ramp.orient
            # merge both B-fields
            b_total = b_prepol + b_earth
            # if rds is off scale the relaxation times and therewith basically
            # switch them off
            if self.Ramp.rds is True:
                T1 = self.T1
                T2 = self.T2
            else:
                T1 = self.T1*1e6
                T2 = self.T2*1e6

            # if the B-field vector is not parallel to B0 rotate B and m
            # into z-axis to apply relaxation
            b_total_n = b_total/np.linalg.norm(b_total)
            if np.any(b_total_n is not self.zunit):
                rot_mat = misc.get_rotmat_from_vectors(b_total, self.zunit)
                b_total = rot_mat.dot(b_total)
                mag = rot_mat.dot(mag)
                # dM/dt
                dmagdt = self.gamma * np.cross(mag, b_total) - \
                    np.array([mag[0], mag[1], 0.]) / T2 - \
                    np.array([0., 0., mag[2] - self.M0[2]]) / T1
                rot_mat_transp = rot_mat.T
                dmagdt = rot_mat_transp.dot(dmagdt)

            else:
                # dM/dt
                dmagdt = self.gamma * np.cross(mag, b_total) - \
                    np.array([mag[0], mag[1], 0.]) / T2 - \
                    np.array([0., 0., mag[2] - self.M0[2]]) / T1
        else:
            # assemble B field only from B0
            b_total = np.array([0., 0., self.B0])

            # dM/dt
            dmagdt = self.gamma * np.cross(mag, b_total) - \
                np.array([mag[0], mag[1], 0.]) / self.T2 - \
                np.array([0., 0., mag[2] - self.M0[2]]) / self.T1
        return dmagdt

    def bloch_fcn_numba(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        if time <= self.Ramp.t_ramp:
            # get PP B-field amplitude
            # the Ramp amplitude is just a factor, hence the multiplication
            # with B0 to make it a value in [T]
            bp_amp = self.B0*self.Ramp.get_ramp_amplitude(time)
            # Earth's magnetic field B0
            b_earth = np.array([0., 0., self.B0])
            # PP magnetic field is the Bp amplitude times the orientation
            # vector
            b_prepol = bp_amp * self.Ramp.orient
            # merge both B-fields
            b_total = b_prepol + b_earth
            # if rds is off scale the relaxation times and therewith basically
            # switch them off
            if self.Ramp.rds is True:
                T1 = self.T1
                T2 = self.T2
            else:
                T1 = self.T1*1e6
                T2 = self.T2*1e6

            # if the B-field vector is not parallel to B0 rotate B and m
            # into z-axis to apply relaxation
            b_total_n = b_total/np.linalg.norm(b_total)
            if np.any(b_total_n is not self.zunit):
                rot_mat = misc.get_rotmat_from_vectors(b_total, self.zunit)
                b_total = rot_mat.dot(b_total)
                mag = rot_mat.dot(mag)
                # dM/dt
                dmagdt = _numba_fcn(self.gamma, T1, T2, self.M0, b_total, mag)
                rot_mat_transp = rot_mat.T
                dmagdt = rot_mat_transp.dot(dmagdt)

            else:
                # dM/dt
                dmagdt = _numba_fcn(self.gamma, T1, T2, self.M0, b_total, mag)
        else:
            # assemble B field only from B0
            b_total = np.array([0., 0., self.B0])

            # dM/dt
            dmagdt = _numba_fcn(self.gamma, self.T1, self.T2, self.M0,
                                b_total, mag)
        return dmagdt

    def solve(self, m_init, info=False, use_numba=False, atol=1e-9, rtol=1e-9):
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
            self.solver = solve_ivp(self.bloch_fcn_numba, [0, self.t_sim],
                                    m_init, rtol=rtol, atol=atol,
                                    dense_output=True)
        else:
            self.solver = solve_ivp(self.bloch_fcn, [0, self.t_sim], m_init,
                                    rtol=rtol, atol=atol, dense_output=True)
        if info:
            print(self.solver.message)
        if self.solver.success:
            self.t = self.solver.t.T
            self.m = self.solver.y
            # calculate adiabatic quality at the end of the ramp
            m_aq = self.solver.sol(self.Ramp.t_ramp)
            m_aq_n = m_aq/np.linalg.norm(m_aq)
            self.Ramp.adiab_qual = np.dot(m_aq_n.T, self.zunit)
            string = 'The adiabatic quality indicator of the ramp is'
            string += ' p = {:.3f}'.format(self.Ramp.adiab_qual)
            if info:
                print(string)
        else:
            raise ValueError("Something went south during integration.")

    def calc_plot_features(self):
        """Calculate all relevant ramp parameter for plotting."""
        # create dummy time vector just for plotting
        time = np.linspace(0, self.Ramp.t_ramp, 1001)
        delta_t = time[1]-time[0]
        # prepare plot variables
        bp_amp = np.linspace(0, self.Ramp.t_ramp, 1001)
        alpha = np.linspace(0, self.Ramp.t_ramp, 1001)
        omega = np.linspace(0, self.Ramp.t_ramp, 1001)
        dadt = np.linspace(0, self.Ramp.t_ramp, 1001)

        for i in np.arange(0, len(time)):
            # get the PP B-field amplitude
            bp_amp[i] = self.B0*self.Ramp.get_ramp_amplitude(time[i])
            # Earth's magnetic field B0
            b_earth = np.array([0., 0., self.B0])
            # effective B-field Bp+B0
            b_eff = bp_amp[i] * self.Ramp.orient + b_earth
            # amplitude of the effective B-field [T]
            b_eff_n = np.sqrt(b_eff[0]**2+b_eff[1]**2+b_eff[2]**2)
            # angle between primary and pre-polarization field [rad]
            alpha[i] = misc.get_angle_between_vectors(b_earth, b_eff)
            # angular frequency of the effective B-field [rad/s]
            omega[i] = self.gamma*b_eff_n
            if i > 0:
                # rate of change of the angle alpha [rad/s]
                dadt[i-1] = np.abs((alpha[i]-alpha[i-1])/delta_t)

        self.Ramp.plot_t = time*1e3  # in [ms]
        self.Ramp.plot_amp = bp_amp/self.B0
        self.Ramp.plot_alpha = alpha
        self.Ramp.plot_omega = omega
        self.Ramp.plot_dadt = dadt

    def plot_ramp_all(self):
        """Plot all Ramp components."""
        fig = plt.figure(figsize=(8, 6))
        # create axes all four axes
        ax1 = fig.add_subplot(221)
        ax2 = fig.add_subplot(222)
        ax3 = fig.add_subplot(223)
        ax4 = fig.add_subplot(224)

        # plot the different ramp parameter into the axes
        self.plot_ramp_single(axis=ax1, version='amp')
        self.plot_ramp_single(axis=ax2, version='alpha')
        self.plot_ramp_single(axis=ax3, version='dadt')
        self.plot_ramp_single(axis=ax4, version='adiabatic')

        # adjust axes position
        low, bot, wid, hei = ax1.get_position().bounds
        ax1.set_position([low*0.9, bot*1.1, wid, hei*0.93])
        low, bot, wid, hei = ax2.get_position().bounds
        ax2.set_position([low*1.1, bot*1.1, wid, hei*0.93])
        low, bot, wid, hei = ax3.get_position().bounds
        ax3.set_position([low*0.9, bot, wid, hei*0.93])
        low, bot, wid, hei = ax4.get_position().bounds
        ax4.set_position([low*1.1, bot, wid, hei*0.93])

        # adjust titles
        ax1.set_title('switch-off ramp amplitude')
        ax2.set_title(r'angle $\alpha$ between Bp and B0')
        ax3.set_title(r'time derivative of $\alpha$')
        ax4.set_title(r'$\ll 1 \rightarrow$ adiabatic condition')

    def plot_ramp_single(self, axis=None, version='amp'):
        """Plot single Ramp components."""
        # update the plot data
        self.calc_plot_features()
        # switch between different parameter
        if version == 'amp':
            value = self.Ramp.plot_amp
            ylabel = 'Bp [B0]'
        elif version == 'alpha':
            value = np.rad2deg(self.Ramp.plot_alpha)
            ylabel = r'$\alpha$ [deg]'
        elif version == 'dadt':
            value = self.Ramp.plot_dadt
            ylabel = r'd$\alpha$/dt'
        elif version == 'adiabatic':
            value = self.Ramp.plot_dadt/self.Ramp.plot_omega
            ylabel = r'd$\alpha$/dt / $\gamma$B'
        else:
            raise NotImplementedError("This plot type is not supported.")

        # calculate ylims
        y_range = np.max(value) - np.min(value)
        ymin = np.min(value)-y_range/20
        ymax = np.max(value)+y_range/20

        # define color
        prepolc = (222/255, 184/255, 135/255)

        # scale time to [ms]
        time = self.Ramp.plot_t
        # if no axes handle was given create figure
        if axis is None:
            fig = plt.figure(figsize=(5, 5))
            # create axes
            axis = fig.add_subplot(111)

        axis.plot(time, value, color=prepolc, label=version)
        if version == 'adiabatic':
            axis.plot([0, self.Ramp.t_ramp*1e3], [1, 1], '--', color='gray')
        axis.set_xlabel('time [ms]')
        axis.set_ylabel(ylabel)
        axis.set_xlim(0, self.Ramp.t_ramp*1e3)
        axis.set_ylim(ymin, ymax)
        axis.grid(color='lightgray')
        return axis


class Ramp:
    """Holds pre-polarization switch-off ramp parameter."""

    def __init__(self, shape='exp', theta=90, t_ramp=0.001):
        # ramp shape [string]
        self.shape = shape
        # relaxation during switch-off [logical]
        self.rds = False
        # pre-polarization B-field amplitude in units of [B0]
        self.factor = 100
        # initial orientation between PP and B0 [deg]
        self._theta = theta
        # azimuthal angle of pre-polarization field [deg]
        self._phi = 0
        # pre-polarization B-field switch amplitude in units of [B0]
        self.switch_factor = 1
        # switch-off ramp time [s]
        self.t_ramp = t_ramp
        # switch-off ramp slope time [s]
        self.t_slope = t_ramp/10
        # calculate initial orientation
        self.orient = misc.get_orient_from_angles(self._theta, self._phi)
        # adiabatic quality p
        self.adiab_qual = None
        # plot data which is calculated later (only when needed)
        self.plot_t = None
        self.plot_amp = None
        self.plot_alpha = None
        self.plot_omega = None
        self.plot_dadt = None

    def __str__(self):
        """Magic str method for the Ramp class."""
        string = '{}\n'.format(self.__class__)
        string += 'shape: "{}"\n'.format(self.shape)
        string += 'rds: {}\n'.format(self.rds)
        string += 'factor: {} [B0]\n'.format(self.factor)
        string += 'switch_factor: {} [B0]\n'.format(self.switch_factor)
        string += 'theta: {} [deg]\n'.format(self.theta)
        string += 'phi: {} [deg]\n'.format(self.phi)
        string += 'orient: {} \n'.format(self.orient)
        string += 't_ramp: {} [s]\n'.format(self.t_ramp)
        string += 't_slope: {} [s]\n'.format(self.t_slope)
        return string

    # shape getter/setter
    @property
    def shape(self):
        """Shape of switch-off ramp."""
        return self._shape

    @shape.setter
    def shape(self, value):
        if value in {'exp', 'linexp', 'halfcos', 'lin'}:
            self._shape = value
        else:
            raise NotImplementedError('shape "{}" not implemented.'
                                      .format(value))

    # theta getter/setter
    @property
    def theta(self):
        """Orientation between PP and B0 [deg]."""
        return self._theta

    @theta.setter
    def theta(self, value):
        self._theta = value
        self.orient = misc.get_orient_from_angles(self._theta, self.phi)

    # phi getter/setter
    @property
    def phi(self):
        """Azimuthal angle of PP field [deg]."""
        return self._phi

    @phi.setter
    def phi(self, value):
        self._phi = value
        self.orient = misc.get_orient_from_angles(self.theta, self._phi)

    def get_ramp_amplitude(self, time):
        """Calculate ramp amplitude during switch-off."""
        # check if time < t_ramp
        if time > self.t_ramp:
            raise ValueError('t must be larger than t_ramp.')

        # maximum PP B-field amplitude at beginning of switch-off
        b_max = self.factor
        # calculate PP B-field amplitude at time 'time' for the different
        # available shapes
        if self.shape == 'exp':
            bp_amp = b_max*np.exp(-time/self.t_slope)
        elif self.shape == 'linexp':
            b_star = self.switch_factor
            # linear part
            b_lin = (-b_max/self.t_slope)*time + b_max
            # exponential part
            b_exp = np.exp(-time/(b_star*self.t_slope/b_max))
            # b_star switch-over time t_star
            t_star = (b_star-b_max)/(-b_max/self.t_slope)
            # amplitude at t_star for scaling
            b_t_star = np.exp(-t_star/(b_star*self.t_slope/b_max))
            # apply
            if time < t_star:
                bp_amp = b_lin
            else:
                if b_t_star == 0.0:
                    bp_amp = 0
                else:
                    bp_amp = (b_star/b_t_star)*b_exp

            # if due to division by "0" the value is NaN ... set it to 0
            if np.isnan(bp_amp):
                bp_amp = 0.0

        elif self.shape == 'halfcos':
            bp_amp = b_max*(0.5+(np.cos(np.pi*time/self.t_ramp)/2))
        elif self.shape == 'lin':
            bp_amp = b_max*(1-time/self.t_ramp)
        else:
            raise NotImplementedError('shape "{}" not implemented.'
                                      .format(self.shape))

        return bp_amp


if __name__ == '__main__':
    # test case if the class is called directly

    # initialize prepol pyBLOCHUS class with standard values
    Bloch = BlochusPrepol()
    # initial magnetization as sum of Bp field and B0 field
    b_p = Bloch.Ramp.orient*Bloch.Ramp.factor*Bloch.B0
    b_e = Bloch.B0*Bloch.zunit
    minit = b_p + b_e
    # for simplicity equilibrium magnetization is B0 (obtaining the real
    # magnetization values is simply a multiplication of the magnetic fields
    # with the "Curie" factor)
    Bloch.M0 = Bloch.B0*Bloch.zunit
    # show different parameter
    print(Bloch)
    print(Bloch.Ramp)
    # solve ode
    start_time = timer.time()
    Bloch.solve(m_init=minit, use_numba=False)
    end_time = timer.time()
    print(end_time-start_time)
    # plot results
    Bloch.plot_magnetization()
    Bloch.plot_magnetization3d()
    Bloch.plot_ramp_all()
