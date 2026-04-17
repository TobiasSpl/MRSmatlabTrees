# -*- coding: utf-8 -*-
"""
Created on Tue Jan 24 18:37:31 2023

@author: Splith.T
"""

import time
import joblib
import multiprocessing



def parfunc(t):
    time.sleep(t)
    
num_cores = multiprocessing.cpu_count()
#joblib.Parallel(n_jobs=num_cores)(joblib.delayed(parfunc)(1) for i in range(1,10))
for i in range(1,10):
    parfunc(1)