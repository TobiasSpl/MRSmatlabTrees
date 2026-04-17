# -*- coding: utf-8 -*-
"""
Created on Thu Feb  9 10:25:59 2023

@author: Splith.T
"""
import numpy as np
from numba import types
import numba as nb
import math
from numbalsoda import lsoda, address_as_void_pointer

###function to solve###
def pulse_diffeq(t, mag, dmagdt, user_data,B_arr,t_arr):
    
    pulse_amp = user_data.pulse_factor
    pulse_paramp = user_data.pulse_parfactor
    gamma = user_data.gamma

    B0 = user_data.B0
    
    
    T2 = 1
    T1 = 1
    M0z=1
    
    #if t < max(t_arr):
    pos = t/max(t_arr)*(len(t_arr)-1)
    if t/max(t_arr) <1:
        i = math.floor(pos)
        rem = pos-i
        
        Bx = (B_arr[i] + (B_arr[i+1] - B_arr[i])*rem)*pulse_amp*B0
        By = 0
        Bz = (B_arr[i] + (B_arr[i+1] - B_arr[i])*rem)*pulse_paramp*B0 + B0
    else:
         Bx = 0
         By = 0
         Bz = B0
    
    
    dmagdt[0] = gamma * (mag[1]*Bz - mag[2]*By) - mag[0] / T2
    dmagdt[1] = gamma * (mag[2]*Bx - mag[0]*Bz) - mag[1] / T2
    dmagdt[2] = gamma * (mag[0]*By - mag[1]*Bx) - (mag[2]-M0z) / T1
    

###wrapped for lsoda###
# this function will create the numba function to pass to lsoda.

def fast_solve_fct(rhs, args_dtype):
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
        B = nb.carray(address_as_void_pointer(user_data[0].B_pointer),(user_data[0].B_len), dtype=np.float64)
        tB = nb.carray(address_as_void_pointer(user_data[0].t_pointer),(user_data[0].t_len), dtype=np.float64)
        # then we call the jitted rhs function, passing in data
        jitted_rhs(t, u, du, user_data[0],B,tB) 
    return wrapped