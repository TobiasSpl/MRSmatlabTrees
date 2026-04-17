# -*- coding: utf-8 -*-
"""
Created on Tue May 26 19:58:43 2020

@author: Hiller.T
"""

from scipy.integrate import solve_ivp
import numba as nb
import numpy as np
import time as timer
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import axes3d, Axes3D  # pylint: disable=W0611

from blochus_misc import BlochusMisc as misc


@nb.jit
def _numba_fcn(gamma, T1, T2, M0, b_total, time, mag):
    """Bloch equation to be solved by the ode-solver."""
    # dM/dt
    dmagdt = gamma * np.cross(mag, b_total) - \
        np.array([mag[0], mag[1], 0.]) / T2 - \
        np.array([0., 0., mag[2] - M0[2]]) / T1
    return dmagdt


class BlochusBasic:
    """Holds all basic routines need for the Bloch simulation."""

    def __init__(self, T1=0.005, T2=0.0025, M0=None, B0=5e-5,
                 t_sim=0.01, nucleus='1H'):
        """Init method for the basic class."""
        # direction vectors
        self.xunit = np.array([1.0, 0.0, 0.0])
        self.yunit = np.array([0.0, 1.0, 0.0])
        self.zunit = np.array([0.0, 0.0, 1.0])

        # dict with key = nuclei, value = gamma
        self.known_nuclei = {
            '1H': 42.57747892,
            '2H': 6.536,
            '3He': -32.434,
            '7Li': 16.546,
            '13C': 10.705,
            '14N': 3.077,
            '15N': -4.316,
            '17O': -5.772,
            '19F': 40.053,
            '23Na': 11.262,
            '27Al': 11.103,
            '29Si': -8.465,
            '31P': 17.235,
            '57Fe': 1.382,
            '63Cu': 11.319,
            '67Zn': 2.669,
            '129Xe': -11.777}

        # init value
        # B0 is later set with the setter function of B0 or Larmor freq.
        self._B0 = None

        # if called from init, this will not update B0 to avoid chicken/egg
        self.nucleus = nucleus

        # longitudinal relaxation time T1 in [s]
        self.T1 = T1
        # transversal relaxation time T2 in [s]
        self.T2 = T2

        # equilibrium magnetization M0 in [A/m]
        # short version if you prefer
        self.M0 = M0 or np.array([0., 0., 1.])

        # finally setting B0 and Larmor freq.
        # Earth's magnetic field in [T]
        self.B0 = B0

        # simulation time in [s]
        self.t_sim = t_sim

        # variables that are later need
        # solver parameter / results
        self.solver = None
        # integration time vector
        self.t = None
        # magnetization vector
        self.m = None
        # instantaneous phase
        self.inst_phase = None
        # magnetization (rotating frame of reference) vector
        self.mrot = None
        # FFT frequencies
        self.fft_freq = None
        # FFT amplitudes
        self.fft_spec = None
        # dummy place holder for child classes
        self.Ramp = None
        self.Pulse = None
        
    """    
    def __str__(self):
        #Magic str method for the basic class.
        string = '{}\n'.format(self.__class__)
        string += 'nucleus: "{}"\n'.format(self.nucleus)
        string += 'gamma: {:.3e} [rad/s/T]\n'.format(self.gamma)
        string += 'larmor: {} [Hz]\n'.format(self.larmor_f)
        string += 'T1: {} [s]\n'.format(self.T1)
        string += 'T2: {} [s]\n'.format(self.T2)
        string += 'M0: {}\n'.format(self.M0)
        string += 'B0: {} [T]\n'.format(self.B0)
        string += 't_sim: {} [s]\n'.format(self.t_sim)
        return string
    """
    
    # gamma getter
    @property
    def gamma(self):
        """Gyromagnetic ratio in [rad/s/T]."""
        return self._gamma

    # B0 getter/setter
    @property
    def B0(self):
        """Earth's magnetic field in [T]."""
        return self._B0

    @B0.setter
    def B0(self, value):
        self._B0 = value
        self._larmor_w = -self._gamma*value
        self._larmor_f = self._larmor_w/2.0/np.pi

    # larmor freq. getter/setter
    @property
    def larmor_f(self):
        """Larmor frequency [Hz]."""
        return self._larmor_f

    @larmor_f.setter
    def larmor_f(self, value):
        if (value < 0 < self._gamma) or (self._gamma < 0 < value):
            self._larmor_f = value
            self._larmor_w = self._larmor_f*2.0*np.pi
            self._B0 = np.abs(self._larmor_w/-self._gamma)
        else:
            raise ValueError("Sign of larmor freq. is not correct.")

    # larmor freq. getter
    @property
    def larmor_w(self):
        """Angular Larmor frequency [rad/s]."""
        return self._larmor_w

    # nucleus (proton) getter/setter
    @property
    def nucleus(self):
        """Proton type used in Simulation [string]."""
        return self._nucleus

    @nucleus.setter
    def nucleus(self, value):
        # The gyromagnetic ratio always depends on the nucleus string.
        try:  # check if a known nuclei was selected
            self._nucleus = value
            self._gamma = self.known_nuclei[value] * 2.0 * np.pi * 1e6

        except KeyError:  # if not
            raise NotImplementedError(
                'No entry for nucleus "{}" found. '
                'Known nuclei are {}'
                .format(value, self.known_nuclei.keys()))

        if self._B0 is not None:  # that would be the case in __init__
            # if gamma changes the frequency changes
            self._larmor_w = -self._gamma*self._B0
            self._larmor_f = self._larmor_w/2.0/np.pi

    def bloch_fcn(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        # assemble B field
        b_total = np.array([0., 0., self.B0])
        # dM/dt
        dmagdt = self.gamma * np.cross(mag, b_total) - \
            np.array([mag[0], mag[1], 0.]) / self.T2 - \
            np.array([0., 0., mag[2] - self.M0[2]]) / self.T1
        return dmagdt

    def bloch_fcn_numba(self, time, mag):
        """Bloch equation to be solved by the ode-solver."""
        # assemble B field
        b_total = np.array([0., 0., self.B0])
        # dM/dt
        dmagdt = _numba_fcn(self.gamma, self.T1, self.T2, self.M0, b_total,
                            time, mag)
        return dmagdt

    def calc_m_rot(self, phi=0):
        """Calculate magnetization in rotating frame of reference."""
        # initialize mrot
        self.mrot = np.ones((3, len(self.t)))
        # cos and sin term
        cosp = np.cos(self.inst_phase + phi)
        sinp = np.sin(self.inst_phase + phi)
        # perform the transformation
        self.mrot[0, :] = self.m[0, :]*cosp + self.m[1, :]*sinp
        self.mrot[1, :] = -self.m[0, :]*sinp + self.m[1, :]*cosp
        self.mrot[2, :] = self.m[2, :]

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
                                    m_init, rtol=rtol, atol=atol)
        else:
            self.solver = solve_ivp(self.bloch_fcn, [0, self.t_sim], m_init,
                                    rtol=rtol, atol=atol)
        if info:
            print(self.solver.message)
        if self.solver.success:
            self.t = self.solver.t.T
            self.m = self.solver.y
            # transform magnetization into rotating frame of reference
            self.inst_phase = self.larmor_w*self.t
            self.calc_m_rot()
            # calculate FFT of lab-frame magnetization
            freq, spec = misc.get_fft(self.t, self.m[[0, 1], :], True)
            self.fft_freq = freq
            self.fft_spec = spec
        else:
            raise ValueError("Something went south during integration.")

    def plot_fft(self, axis=None, version='mag'):
        """Plot FFT of lab-frame magnetization or pulse."""
        # if no axes handle was given create figure
        if axis is None:
            fig = plt.figure(figsize=(6, 5))
            # create axes and plot magnetization
            axis = fig.add_subplot(111)

        if version == 'mag':
            freq = self.fft_freq
            spec = np.abs(self.fft_spec)
            labelstr = 'Mxy'
        elif version == 'pulse':
            if (self.Pulse is not None) and hasattr(self.Pulse, 'fft_freq'):
                freq = self.Pulse.fft_freq
                spec = np.abs(self.Pulse.fft_spec)
                labelstr = 'Bxy'
            else:
                raise AttributeError("There is no Pulse attribute.")
        else:
            raise NotImplementedError("This plot type is not supported.")

        axis.plot(freq, spec, 'r', label=labelstr)
        axis.plot([self.larmor_f, self.larmor_f], [0, np.max(np.abs(spec))],
                  '--', color='gray', label=r'$\omega_0$')
        axis.legend(loc='upper right')
        axis.set_xlabel('frequency [Hz]')
        axis.set_ylabel('amplitude')
        axis.set_xlim(-np.abs(self.larmor_f*2), np.abs(self.larmor_f*2))
        axis.set_ylim(0, np.max(np.abs(spec))*1.1)
        axis.grid(color='lightgray')
        return axis

    def plot_magnetization(self, axis=None, version='lab'):
        """Plot magnetization components."""
        # switch between lab and rot frame
        if version == 'lab':
            mag = self.m
            ylabel = r'magnetization - lab frame [$M_0$]'
        elif version == 'rot':
            mag = self.mrot
            ylabel = r'magnetization - rot frame [$M_0$]'
        else:
            raise NotImplementedError("This plot type is not supported.")

        # scale time to [ms]
        time = self.t*1e3
        # get Mxy component
        mag_xy = np.sqrt(mag[0]**2 + mag[1]**2)
        # get norm of magnetization
        mag_n = np.sqrt(mag[0]**2 + mag[1]**2 + mag[2]**2)
        # if no axes handle was given create figure
        if axis is None:
            fig = plt.figure(figsize=(6, 5))
            # create axes and plot magnetization
            axis = fig.add_subplot(111)

        if self.Ramp is not None:
            # if called from prepol class, magnetization needs to be normalized
            mag = mag/self.B0
            mag_xy = mag_xy/self.B0
            mag_n = mag_n/self.B0
            val_range = np.max(np.concatenate((mag, mag_xy), axis=None)) \
                - np.min(np.concatenate((mag, mag_xy), axis=None))
            ymin = np.min(np.concatenate((mag, mag_xy), axis=None)) \
                - val_range/20
            ymax = np.max(np.concatenate((mag, mag_xy), axis=None)) \
                + val_range/20
        else:
            ymin = -1.05
            ymax = 1.05

        axis.plot(time, mag[0], 'r', label='Mx')
        axis.plot(time, mag[1], 'g', label='My')
        axis.plot(time, mag[2], 'b', label='Mz')
        axis.plot(time, mag_xy, 'm', label='Mxy')
        axis.plot(time, mag_n, 'k--', label='|M|')
        axis.legend(loc='lower right')
        axis.set_xlabel('time [ms]')
        axis.set_ylabel(ylabel)
        axis.set_xlim(0, self.t_sim*1e3)
        axis.set_ylim(ymin, ymax)
        axis.grid(color='lightgray')
        return axis

    def plot_magnetization3d(self, axis=None, version='lab', lonlat=(30, 30)):
        """Plot magnetization components on Bloch Sphere."""
        # switch between lab and rot frame
        if version == 'lab':
            mag = self.m
        elif version == 'rot':
            mag = self.mrot
        else:
            raise NotImplementedError("This plot type is not supported.")

        # define colors
        stdc = (143/255, 188/255, 143/255)
        prepolc = (222/255, 184/255, 135/255)
        pulsec = (100/255, 149/255, 237/255)

        if (self.Ramp is not None) and hasattr(self.Ramp, 't_ramp'):
            mask1 = self.t > self.Ramp.t_ramp
            mask2 = self.t <= self.Ramp.t_ramp
            mask3 = self.t > self.t_sim
        elif (self.Pulse is not None) and hasattr(self.Pulse, 't_pulse'):
            mask1 = self.t > self.Pulse.t_pulse
            mask2 = self.t > self.t_sim
            mask3 = self.t <= self.Pulse.t_pulse
        else:
            mask1 = self.t <= self.t_sim
            mask2 = self.t > self.t_sim
            mask3 = self.t > self.t_sim

        # get norm of magnetization
        mag_n = np.sqrt(mag[0]**2 + mag[1]**2 + mag[2]**2)

        # for visualization purposes the magnetization always gets normalized
        # to the maximum (first) value
        mag = mag/mag_n[0]
        if axis is None:
            fig = plt.figure(figsize=(5, 5))
            # create axes and plot magnetization
            axis = fig.add_subplot(111, projection='3d')

        self.plot_bloch_sphere(axis, lonlat)
        axis.plot3D(mag[0, mask1], mag[1, mask1], mag[2, mask1],
                    color=stdc, linewidth=2)
        axis.plot3D(mag[0, mask2], mag[1, mask2], mag[2, mask2],
                    color=prepolc, linewidth=2)
        axis.plot3D(mag[0, mask3], mag[1, mask3], mag[2, mask3],
                    color=pulsec, linewidth=2)
        try:  # someday this will work
            axis.set_aspect('equal')
        except NotImplementedError:
            pass
        return axis

    @staticmethod
    def plot_bloch_sphere(axis, lonlat, radius=1, lon_range=(-180.0, 180.0),
                          lat_range=(-90.0, 90.0)):
        """Draw a unit sized Bloch Sphere."""
        # from the lon and lat increments get the longitudinal and latitudinal
        # circles in xyz coordinates
        lons, lats = misc.get_sphere_grid(lonlat, radius=radius,
                                          lon_range=lon_range,
                                          lat_range=lat_range)
        # first draw the longitudinal circles
        xlin = lons[0]
        ylin = lons[1]
        zlin = lons[2]
        for i in np.arange(0, xlin.shape[0]):
            axis.plot(xlin[i, :], ylin[i, :], zlin[i, :], color='darkgray',
                      linewidth=1)
        # then draw the latitudinal circles
        xlin = lats[0]
        ylin = lats[1]
        zlin = lats[2]
        for i in np.arange(0, xlin.shape[0]):
            axis.plot(xlin[i, :], ylin[i, :], zlin[i, :], color='darkgray',
                      linewidth=1)

        # draw the inner lines
        axis.plot([-radius, radius], [0, 0], [0, 0], color='darkgray',
                  linewidth=1)
        axis.plot([0, 0], [-radius, radius], [0, 0], color='darkgray',
                  linewidth=1)
        axis.plot([0, 0], [0, 0], [-radius, radius], color='darkgray',
                  linewidth=1)
        # draw the main axes
        axis.plot([0, radius*1.2], [0, 0], [0, 0], color='r', linewidth=1.3)
        axis.plot([0, 0], [0, radius*1.2], [0, 0], color='g', linewidth=1.3)
        axis.plot([0, 0], [0, 0], [0, radius*1.2], color='b', linewidth=1.3)
        # draw the axis label
        axis.text(radius*1.3, 0, 0, "X", color='r', ha='center')
        axis.text(0, radius*1.3, 0, "Y", color='g', ha='center')
        axis.text(0, 0, radius*1.3, "Z", color='b', ha='center')
        # set the limits
        axis.set_xlim(-1, 1)
        axis.set_ylim(-1, 1)
        axis.set_zlim(-1, 1)
        # set the view
        axis.view_init(azim=45, elev=30)
        # remove the axis lines
        axis.axis('off')


if __name__ == '__main__':
    # test case if the class is called directly

    # initialize basic pyBLOCHUS class with standard values
    Bloch = BlochusBasic()
    # show Bloch parameter
    print(Bloch)
    # solve ode
    start_time = timer.time()
    Bloch.solve(m_init=Bloch.xunit, use_numba=True)
    end_time = timer.time()
    print(end_time-start_time)
    # plot results
    Bloch.plot_magnetization()
    Bloch.plot_magnetization3d()
    Bloch.plot_magnetization(version='rot')
    Bloch.plot_magnetization3d(version='rot')
    Bloch.plot_fft()
