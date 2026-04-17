# -*- coding: utf-8 -*-
"""
Created on Mon Jan 23 11:41:53 2023

@author: Splith.T
"""

import numpy as np

import array

import sys
import os
import json

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pyBLOCHUS'))
import pyBLOCHUS
import multiprocess as multiprocessing
from functools import partial
from numbalsoda import lsoda
import time

import matplotlib.pyplot as plt


max_workers = 12

###Translate Matlab2Python object
class obj(object):
    def __init__(self, d):
        for k, v in d.items():
            if isinstance(k, (list, tuple)):
                setattr(self, k, [obj(x) if isinstance(x, dict) else x for x in v])
            else:
                #if isinstance(v,matlab.double) or isinstance(v,array.array) or isinstance(v,list):
                if isinstance(v,array.array) or isinstance(v,list):
                    setattr(self, k, obj(np.array(v)) if isinstance(v, dict) else np.array(v))
                else:
                    setattr(self, k, obj(v) if isinstance(v, dict) else v)

class NumpyEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return json.JSONEncoder.default(self, obj)
   
def rotation_matrix_from_vectors(vec1, vec2):
    """ Find the rotation matrix that aligns vec1 to vec2
    :param vec1: A 3d "source" vector
    :param vec2: A 3d "destination" vector
    :return mat: A transform matrix (3x3) which when applied to vec1, aligns it with vec2.
    """
    a, b = (vec1 / np.linalg.norm(vec1)).reshape(3), (vec2 / np.linalg.norm(vec2)).reshape(3)
    v = np.cross(a, b)
    if any(v): #if not all zeros then 
        c = np.dot(a, b)
        s = np.linalg.norm(v)
        kmat = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
        return np.eye(3) + kmat + kmat.dot(kmat) * ((1 - c) / (s ** 2))

    else:
        return np.eye(3) #cross of all zeros only occurs on identical directions
   
def unit_vector(vector):
    """ Returns the unit vector of the vector.  """
    if vector.ndim == 1:
        return vector / np.linalg.norm(vector) 
    if vector.ndim == 2:
        return vector / np.repeat(np.linalg.norm(vector,axis=1)[:,np.newaxis],3,axis=1)
    if vector.ndim == 3:    
        return vector / np.repeat(np.linalg.norm(vector,axis=2)[:,:,np.newaxis],3,axis=2)
   
def angle_between(v1, v2):
    """ Returns the angle in radians between vectors 'v1' and 'v2'::

            >>> angle_between((1, 0, 0), (0, 1, 0))
            1.5707963267948966
            >>> angle_between((1, 0, 0), (1, 0, 0))
            0.0
            >>> angle_between((1, 0, 0), (-1, 0, 0))
            3.141592653589793
    """
    v1_u = unit_vector(v1)
    v2_u = unit_vector(v2)
    return np.arccos(np.clip(np.dot(v1_u, v2_u), -1.0, 1.0))

def init(queue,tmax,earth,PulseAxis):
    global idx
    global cfunc
    global bloch
    bloch = pyBLOCHUS.BlochusPulse(T1=1, T2=1, t_sim=tmax)
    bloch.B0 = earth.erdt
    bloch.Pulse.larmor_f = -earth.erdt*bloch.gamma/2/np.pi
    bloch.Pulse.fmod.larmor_f = -earth.erdt*bloch.gamma/2/np.pi #hierrüber mal mit Thomas reden
    bloch.Pulse.polarization = 'linpar'
    bloch.Pulse.pulse_type = 'free'
    bloch.Pulse.axis = PulseAxis #'+y' #MRS standart
    cfunc = pyBLOCHUS.fast_solve_fct(pyBLOCHUS.pulse_diffeq, bloch.args_dtype())
    idx = queue.get()

    
def bloch_calc(ir,pick,iq,t,Imax,measure,labB1,M0_array,phase,use_lsoda=False,use_numba=True):
    global idx,cfunc,bloch
    funcptr = cfunc.address
    nphi = pick.shape[0]
    nTT = len(t)
    MM = np.empty((nphi,3,nTT))
    #TT = np.empty((nphi,nTT))
    M = np.empty((nphi,3))
    if hasattr(measure, 'Pulse'):
        if hasattr(measure.Pulse,"t"): #if only one pulse shape is transfered (e.g. for sinusoidal Pulse) this is true
            t_B = np.array(measure.Pulse.t)
        else:    
            t_B = np.array(measure.Pulse[iq]['t'])
        if hasattr(measure.Pulse,"Shape"): #if only one pulse shape is transfered (e.g. for sinusoidal Pulse) this is true
            B1 = np.array(measure.Pulse.Shape)
        else:                               #normal case with multiple Pulse shapes
            B1 = np.array(measure.Pulse[iq]['Shape'])
    else:
        t_B = t# np.linspace(0.0,tmax,nTT*10)
        B1 = np.sin(t*bloch.Pulse.fmod.larmor_f*2*np.pi)*Imax # needs to be reworked
    for iphi in range(nphi):
        B = np.append(B1,[0]) #append single 0
        bloch.Pulse.factor = labB1[iphi,ir,0] / bloch.B0
        bloch.Pulse.parfactor = labB1[iphi,ir,2] / bloch.B0
        arguments = bloch.args(B,t_B)
        if M0_array.ndim > 1:
            M0 = np.array(M0_array[iphi,ir],dtype="float64")
        else:
            M0 = np.array(M0_array,dtype="float64")
                
        magsol, success = lsoda(funcptr, M0, t, data = arguments, atol=1e-9, rtol=1e-9)
        
        bloch.m = magsol.transpose()
        bloch.t = t
        bloch.Pulse.fmod.t_now = t
        bloch.inst_phase = bloch.Pulse.fmod.modulated_phase
        #bloch.calc_m_rot()

        #bloch.solve(m_init=bloch.zunit,use_numba=use_numba,use_lsoda=use_lsoda)
        
        MM[iphi,:]= bloch.m
        #TT[iphi,:]= bloch.t
        M[iphi,:] = bloch.m[:,-1]
        
        

    return M,MM
    #return M

if __name__ == '__main__':
    __spec__ = None
    tic = time.perf_counter()
    input_json = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'BLOCHUS_input.json'))
    BLOCHUSinput=json.load(input_json)
    
    ### objectify everything                
    B1 = obj(BLOCHUSinput['B1'])
    B0 = obj(BLOCHUSinput['B0'])
    iq = BLOCHUSinput['iq']
    Imax = BLOCHUSinput['Imax']  
    earth = obj(BLOCHUSinput['earth'])
    measure = obj(BLOCHUSinput['measure'])
    pick = np.array(BLOCHUSinput['pick'])
    phase = 0 #included in the pulse shapes
    M0 = np.array(BLOCHUSinput['M0'])
    
    PulseAxis="+y";
    #activate to ignore pick
    #pick = np.ones(B1.x.shape)
    
    ###get the vects, calculate labB1
    vecB0 = np.array([B0.x, B0.y, B0.z])
    vecB1 = np.array([B1.x, B1.y, B1.z]).transpose(1,2,0)
    theta = angle_between(vecB1,vecB0)
    n = np.array([0,1,0])
    #sgn = 1 # 
    sgn = np.sign(np.dot(np.cross(vecB0,vecB1),n))
    labB1unit = np.stack([np.sin(theta)*sgn,np.zeros(theta.shape),np.cos(theta)],axis=2)
    labB1 = np.repeat(np.linalg.norm(vecB1,axis=2)[:,:,np.newaxis],3,axis=2)*labB1unit
    
    if hasattr(measure, "parallelM0"):
        if measure.parallelM0:
            M0 = labB1+np.array([0,0,1])*earth.erdt
            M0 = M0/np.stack([np.linalg.norm(M0,2,2),np.linalg.norm(M0,2,2),np.linalg.norm(M0,2,2)],axis=2)
            M0[np.isnan(M0)] = 0 #set M0 to 0 for zero field B1 = -B0
    
    nphi=B1.x.shape[0]
    nr= np.sum(pick[1])
    
    if hasattr(measure, 'Pulse'):
        if hasattr(measure.Pulse,"t"): #if only one pulse shape is transfered (e.g. for sinusoidal Pulse) this is true
            t_B = np.array(measure.Pulse.t)
        else:   
            t_B = np.array(measure.Pulse[iq]['t'])
        tmax = t_B[-1];
        if tmax < measure.taup1:
            print("recorded Pulse is to short, transients might not be included")
    else:
        tmax = measure.taup1
        
    
    fsample = 100
    t = np.linspace(0,tmax,round(earth.w_rf/2/np.pi*tmax*fsample)+1)
    
    ir = np.where(pick[1])[:][0]
    num_workers = min(multiprocessing.cpu_count()-1,np.ceil(len(ir)/4).astype('int'),max_workers)

    manager = multiprocessing.Manager()
    idQueue = manager.Queue()
    
    for i in range(num_workers):
        idQueue.put(i)
    
    if hasattr(measure.Pulse,"t"): #if only one pulse shape is transfered (e.g. for sinusoidal Pulse) this is true
        plt.plot(np.array(measure.Pulse.t),np.array(measure.Pulse.Shape))
    else:
        plt.plot(np.array(measure.Pulse[iq]['t']),np.array(measure.Pulse[iq]['Shape']))
    pool = multiprocessing.Pool(num_workers, init, (idQueue,tmax,earth,PulseAxis))
    bloch_calc_wArgs = partial(bloch_calc, pick = pick, iq = iq, t = t, Imax = Imax, measure = measure, labB1 = labB1, M0_array = M0, phase = phase, use_lsoda=True)
    M,MM = zip(*pool.map(bloch_calc_wArgs, ir))
    #M = pool.map(bloch_calc_wArgs, ir)
    
    pool.close()
    M=np.array(M)
    M=np.transpose(M,(1,0,2))
    
    MM=np.array(MM)
    MM=np.transpose(MM,(1,0,2,3))
    
    
    toc = time.perf_counter()
    #print(f"time elapsed6: {toc - tic:0.4f} seconds")
    
    #output=json.dumps({'M':M}, cls=NumpyEncoder);
    output = {"M":M}

    #write to output
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'BLOCHUS_output.json'), 'w') as f: json.dump(output, f, cls=NumpyEncoder)




