# -*- coding: utf-8 -*-
"""
Created on Thu May 28 20:20:13 2020

@author: Hiller.T
"""

import numpy as np
import numba as nb
from scipy.fft import fft, fftfreq, fftshift
from numba.experimental import jitclass



class BlochusMisc:
    def __init__(self):
        pass
    """Holds several helper functions."""

    @staticmethod
    def sph2cart(azim, elev, radius=1):
        """Transform spherical into Cartesian coordinates."""
        x_coord = radius * np.cos(elev) * np.cos(azim)
        y_coord = radius * np.cos(elev) * np.sin(azim)
        z_coord = radius * np.sin(elev)
        return x_coord, y_coord, z_coord

    @staticmethod
    def get_angle_between_vectors(vec_1, vec_2):
        """Calculate angle between two vectors."""
        # normalize both vectors
        vec_1 = vec_1/np.linalg.norm(vec_1)
        vec_2 = vec_2/np.linalg.norm(vec_2)
        # angle [rad]
        theta = np.arccos(np.dot(vec_1, vec_2))
        return theta

    @staticmethod
    def get_fft(time, sig, interp=False):
        """Calculate FFT."""
        # do interpolation due to adaptive time stepping
        if interp:
            # find all time step increments
            delta_t = np.diff(time)
            # the minimal step size is 1 MHz
            delta_t = np.maximum(1e-6, np.absolute(delta_t.min()))
            # create equally spaced time vector
            t_interp = np.arange(0, time.max()+delta_t, delta_t)
            t_interp[-1] = time.max()
            n_steps = len(t_interp)
            # if the signal has two components make it a complex signal
            if sig.shape[0] == 2:
                # interpolate each component individually
                sig_interp_x = np.interp(t_interp, time, sig[0])
                sig_interp_y = np.interp(t_interp, time, sig[1])
                # merge the x- and y-component of the magnetization
                # into a complex number
                sig = sig_interp_x + 1j*sig_interp_y
            else:  # otherwise just do the interpolation
                sig_interp_x = np.interp(t_interp, time, sig)
                sig = sig_interp_x
        else:  # no interpolation necessary
            delta_t = time[1] - time[0]
            n_steps = time.shape[0]
            # merge the x- and y-component of the magnetization
            # into a complex number
            if sig.shape[0] == 2:
                sig = sig[0] + 1j*sig[1]

        freqs = fftfreq(n_steps, delta_t)
        spec = fft(sig)
        spec = fftshift(spec)/n_steps
        freqs = fftshift(freqs)
        return freqs, spec

    @staticmethod
    def get_orient_from_angles(theta, phi):
        """Calculate orientation vector from polar and azimuthal angle."""
        yunit = np.array([0.0, 1.0, 0.0])
        zunit = np.array([0.0, 0.0, 1.0])
        rot_mat = BlochusMisc.get_rotmat_from_angle_axis(np.deg2rad(theta),
                                                         yunit)
        orient = rot_mat.dot(zunit)
        rot_mat = BlochusMisc.get_rotmat_from_angle_axis(np.deg2rad(phi),
                                                         zunit)
        orient = rot_mat.dot(orient)
        return orient

    @staticmethod
    def get_rotmat_from_angle_axis(phi, ax_vec):
        """Calculate rotation matrix from angle and axis."""
        # normalize axis vector ax_vec
        ax_vec = ax_vec/np.linalg.norm(ax_vec)
        # get the individual components
        n_x = ax_vec[0]
        n_y = ax_vec[1]
        n_z = ax_vec[2]
        nxnx = ax_vec[0] * ax_vec[0]
        nxny = ax_vec[0] * ax_vec[1]
        nxnz = ax_vec[0] * ax_vec[2]
        nyny = ax_vec[1] * ax_vec[1]
        nynz = ax_vec[1] * ax_vec[2]
        nznz = ax_vec[2] * ax_vec[2]
        # matrix terms
        omcosp = 1-np.cos(phi)
        cosp = np.cos(phi)
        sinp = np.sin(phi)
        # assemble rotation matrix
        rot_mat = np.array([[nxnx*omcosp+cosp, nxny*omcosp-n_z*sinp,
                             nxnz*omcosp+n_y*sinp],
                            [nxny*omcosp+n_z*sinp, nyny*omcosp+cosp,
                             nynz*omcosp-n_x*sinp],
                            [nxnz*omcosp-n_y*sinp, nynz*omcosp+n_x*sinp,
                             nznz*omcosp+cosp]])
        return rot_mat

    @staticmethod
    def get_rotmat_from_vectors(vec_1, vec_2):
        """Calculate rotation matrix from two vectors."""
        # normalize both vectors
        vec_1 = vec_1/np.linalg.norm(vec_1)
        vec_2 = vec_2/np.linalg.norm(vec_2)
        # cross product
        cross = np.cross(vec_1, vec_2)
        # check if vec_1 and vec_2 are parallel / antiparallel
        if np.sum(cross) == 0:
            # check if vec_1 == vec_2 (parallel)
            if np.all(vec_1 == vec_2):
                rot_mat = np.eye(3)
            else:  # vec_1 == -vec_2 (antiparallel)
                rot_mat = -np.eye(3)
        else:
            ssc = np.array([[0, -cross[2], cross[1]],
                            [cross[2], 0, -cross[0]],
                            [-cross[1], cross[0], 0]])
            # rotation matrix
            rot_mat = np.eye(3) + ssc + ssc.dot(ssc)*(1-np.dot(vec_1, vec_2)) \
                / np.linalg.norm(cross)**2
        return rot_mat

    @staticmethod
    def get_sphere_grid(lonlat, radius=1,
                        lon_range=(-180.0, 180.0), lat_range=(-90.0, 90.0)):
        """Calculate grid for Bloch sphere."""
        # lon and lat increments of the sphere
        lonvec = np.arange(lon_range[0], lon_range[1]+lonlat[0], lonlat[0])
        latvec = np.arange(lat_range[0], lat_range[1]+lonlat[1], lonlat[1])
        # gridded points on sphere surface
        lat1, lon1 = np.meshgrid(np.linspace(lat_range[0], lat_range[1], 181),
                                 lonvec)
        lon2, lat2 = np.meshgrid(np.linspace(lon_range[0], lon_range[1], 361),
                                 latvec)
        # spherical to Cartesian coordinate transform
        lons = BlochusMisc.sph2cart(np.deg2rad(lon1),
                                    np.deg2rad(lat1), radius)
        lats = BlochusMisc.sph2cart(np.deg2rad(lon2),
                                    np.deg2rad(lat2), radius)
        return lons, lats
