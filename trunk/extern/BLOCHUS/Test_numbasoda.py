# -*- coding: utf-8 -*-
"""
Created on Tue Feb  7 14:17:56 2023

@author: Splith.T
"""

import numpy as np
import numba as nb
from numba import types
from numbalsoda import lsoda, address_as_void_pointer
from matplotlib import pyplot as plt
import ctypes
import collections

import sys

sys.path.append('C:\\Splith.T\\Eigene Dateien\\MoreSpin2\\BLOCHUS\\pyBLOCHUS')
import pyBLOCHUS

# rhs function takes in two pieces of data p and arr

def rhs(t, mag, dmagdt, user_data):
    
    pulse_amp = user_data.pulse_factor
    pulse_paramp = user_data.pulse_parfactor
    
    larmor_f = user_data.pulse_larmor_f
    larmor_w = larmor_f*2*np.pi
    gamma = user_data.gamma
    axis_phase = user_data.pulse_axis_phase
    ref_phase = user_data.pulse_ref_phase
    B0 = user_data.B0
    theta = larmor_w*t
    Bx = np.cos(theta + axis_phase + ref_phase)*pulse_amp*B0
    By = 0#-np.cos(larmor_w*t)*pulse_amp*B0
    Bz = B0 + np.cos(theta + axis_phase + ref_phase)*pulse_paramp*B0
    T2 = 1000
    T1 = 1000
    M0z=1
    
    dmagdt[0] = gamma * (mag[1]*Bz - mag[2]*By) - mag[0] / T2
    dmagdt[1] = gamma * (mag[2]*Bx - mag[0]*Bz) - mag[1] / T2
    dmagdt[2] = gamma * (mag[0]*By - mag[1]*Bx) - (mag[2]-M0z) / T1
    
    # use numba.types.Record.make_c_struct to build a 
# a c structure.


bloch = pyBLOCHUS.BlochusPulse2(T1=0.001, T2=0.0005, t_sim=0.001892425)
bloch.B0 = 49643.3808E-9
bloch.Pulse.larmor_f = -bloch.B0*bloch.gamma/2/np.pi
bloch.Pulse.B0 = 49643.3808
bloch.Pulse.fmod.larmor_f = -bloch.B0*bloch.gamma/2/np.pi #hierrüber mal mit Thomas reden
bloch.Pulse.polarization = 'linpar'
bloch.Pulse.pulse_type = 'free'
bloch.Pulse.axis = '+y' #MRS standart

bloch.Pulse.factor = 0.6
bloch.Pulse.parfactor = 0.3
    
# 'p' is the value of p 
# 'arr_p' is the memory address of array arr
# 'len_arr' is the length of arrray arr
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
                    ('t_sim', types.float64)])

# this function will create the numba function to pass to lsoda.
def create_jit_rhs(rhs, args_dtype):
    jitted_rhs = nb.njit(rhs)
    @nb.cfunc(types.void(types.double,
             types.CPointer(types.double),
             types.CPointer(types.double),
             types.CPointer(args_dtype)))
    def wrapped(t, u, du, user_data_p):
        # unpack p and arr from user_data_p
        user_data = nb.carray(user_data_p, 1)
        #pulse_amp = user_data[0].pulse_amp
        #pulse_paramp = user_data[0].pulse_paramp 
        #arr = nb.carray(address_as_void_pointer(user_data[0].arr_p),(user_data[0].len_arr), dtype=np.float64)
        
        # then we call the jitted rhs function, passing in data
        jitted_rhs(t, u, du, user_data[0]) 
    return wrapped

rhs_cfunc = create_jit_rhs(rhs, args_dtype)

# args = numpy array of length 1 with the custom type we specified (args_dtype)
pulse_amp = 0.6
pulse_paramp = 0.3
args = np.array((bloch.Pulse.factor,
                 bloch.Pulse.parfactor,
                 bloch.Pulse.axis_phase,
                 bloch.Pulse.ref_phase,
                 bloch.Pulse.larmor_f,
                 bloch.Pulse.t_pulse,
                 bloch.gamma,
                 bloch.B0,
                 bloch.T1,
                 bloch.T2,
                 bloch.larmor_w,
                 bloch.larmor_f,
                 bloch.t_sim),dtype=args_dtype)

#arr = Point(10,20)
#args = np.array((pulse_amp,pulse_paramp,id(arr),arr.shape[0]),dtype=args_dtype)


funcptr = rhs_cfunc.address
u0 = np.array([0.0,0.0,1.0])
t_eval = np.linspace(0.0,0.001892425,1000) 
usol, success = lsoda(funcptr, u0, t_eval, data = args)

plt.rcParams.update({'font.size': 15})
fig,ax = plt.subplots(1,1,figsize=[7,5])

ax.plot(t_eval,usol[:,0],label='u1')
ax.plot(t_eval,usol[:,1],label='u2')
ax.plot(t_eval,usol[:,2],label='u3')
ax.legend()
ax.set_xlabel('t')

plt.show()